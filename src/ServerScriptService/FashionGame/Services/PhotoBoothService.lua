--!strict
-- 인생네컷 photo booth (PHOTO_BOOTH.md, P1 + group shooting), server side.
--
-- Booths are Models tagged "PhotoBooth" (graybox 08_PhotoBooth) with:
--   Stand        invisible box where people pose; its CFrame (looking at the
--                camera) is the origin every shot is stored against
--   CameraPoint  the photo camera's CFrame
--   Backdrop     photo background (its colour is stored with the photo)
--
-- Flow (server-owned, D-063):
--   1. "사진 찍기" prompt → client chooses layout (1×4 / 2×2) and who may join
--      (혼자만 / 친구와 / 모두와) → Open. Waiting 3 s (solo) / 10 s; others
--      near the booth get "같이 찍기" (Join), up to 4 people. The host may
--      start early.
--   2. Shooting: everyone is placed on the stand facing the camera; 8 photos,
--      one every 10 s (first one 8 s). People can move, pick poses (the club
--      dances, allowed on PhotoStage) and props. Each photo stores, per
--      person: position/yaw on the stand, dance key + clip time, props.
--      Outfits are captured once when shooting starts (OutfitSnapshot).
--   3. Picking: every participant gets the 8 shots ("Shots" event), picks 4
--      and a frame → Save → their own copy goes to their album
--      (PlayerDataService.SavePhoto, max 30). The session ends when everyone
--      saved or left, or after PhotoConfig.PickSeconds.
--
-- Public booth attributes (clients follow them):
--   Phase "idle"|"waiting"|"shooting"|"picking", Host, Layout, Mode,
--   People (JSON userIds), WaitUntil, ShotIndex, NextShotAt.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local PhotoConfig = require(Shared:WaitForChild("PhotoConfig"))
local PhotoProps = require(Shared:WaitForChild("PhotoProps"))
local OutfitSnapshot = require(Shared:WaitForChild("OutfitSnapshot"))

local PhotoBoothService = {}

type Session = {
	id: string,
	booth: Model,
	host: Player,
	layout: string,
	mode: string,
	phase: string,
	people: {Player},
	names: {[number]: string},
	outfits: {[number]: any},
	shots: {any},
	saved: {[Player]: boolean},
	startNow: boolean,
}

local sessions: {[Model]: Session} = {}
local byPlayer: {[Player]: Session} = {}
local playerData: any = nil
local event: RemoteEvent? = nil
local lastCall: {[Player]: number} = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function toast(player: Player, message: string)
	local remotes = FashionGame:FindFirstChild("Remotes")
	local notify = remotes and remotes:FindFirstChild("ClubNotify")
	if notify and notify:IsA("RemoteEvent") then notify:FireClient(player, "Toast", message) end
end

local function part(booth: Model, name: string): BasePart?
	local found = booth:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return nil end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(player: Player, booth: Model, distance: number): boolean
	local root = rootOf(player)
	local stand = part(booth, "Stand")
	return root ~= nil and stand ~= nil and (root.Position - stand.Position).Magnitude <= distance
end

local function publish(session: Session?, booth: Model)
	if not session then
		booth:SetAttribute("Phase", "idle")
		booth:SetAttribute("Host", 0)
		booth:SetAttribute("People", "[]")
		booth:SetAttribute("ShotIndex", 0)
		booth:SetAttribute("NextShotAt", 0)
		booth:SetAttribute("WaitUntil", 0)
	else
		local ids = {}
		for _, person in ipairs(session.people) do table.insert(ids, person.UserId) end
		booth:SetAttribute("Phase", session.phase)
		booth:SetAttribute("Host", session.host.UserId)
		booth:SetAttribute("Layout", session.layout)
		booth:SetAttribute("Mode", session.mode)
		booth:SetAttribute("People", HttpService:JSONEncode(ids))
	end
	local stand = part(booth, "Stand")
	if stand then
		local start = stand:FindFirstChild("PhotoPrompt") :: ProximityPrompt?
		local join = stand:FindFirstChild("JoinPrompt") :: ProximityPrompt?
		if start then start.Enabled = session == nil end
		if join then
			join.Enabled = session ~= nil and session.phase == "waiting" and session.mode ~= "solo"
				and #session.people < PhotoConfig.MaxPeople
		end
	end
end

local function clearProps(player: Player)
	local character = player.Character
	if not character then return end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child:GetAttribute("PhotoProp") then child:Destroy() end
	end
	character:SetAttribute("PhotoBooth", nil)
end

local function endSession(session: Session, reason: string?)
	if sessions[session.booth] ~= session then return end
	sessions[session.booth] = nil
	for _, person in ipairs(session.people) do
		if byPlayer[person] == session then byPlayer[person] = nil end
		clearProps(person)
		if event and person.Parent then event:FireClient(person, "Ended", reason) end
	end
	publish(nil, session.booth)
end

local function removePerson(session: Session, player: Player, reason: string?)
	local index = table.find(session.people, player)
	if not index then return end
	if session.phase == "waiting" and player == session.host then
		endSession(session, "호스트가 나가서 촬영이 취소되었어요.")
		return
	end
	if session.phase == "picking" then
		-- Keep them in the list (their shots are already captured); just done.
		session.saved[player] = true
	else
		table.remove(session.people, index)
	end
	byPlayer[player] = nil
	clearProps(player)
	if event and player.Parent then event:FireClient(player, "Ended", reason) end
	publish(session, session.booth)
end

--------------------------------------------------
-- Shots
--------------------------------------------------

local function captureShot(session: Session, stand: BasePart, at: number): any
	local people = {}
	for _, person in ipairs(session.people) do
		local character = person.Character
		local root = rootOf(person)
		if character and root then
			local rel = stand.CFrame:ToObjectSpace(root.CFrame)
			local look = rel.LookVector
			local entry: {[string]: any} = {
				u = person.UserId,
				x = math.floor(rel.X * 100 + 0.5) / 100,
				y = math.floor(rel.Y * 100 + 0.5) / 100,
				z = math.floor(rel.Z * 100 + 0.5) / 100,
				r = math.floor(math.atan2(-look.X, -look.Z) * 1000 + 0.5) / 1000,
				p = PhotoProps.worn(character),
			}
			local key = character:GetAttribute("DanceKey")
			local start = character:GetAttribute("DanceStart")
			local speed = character:GetAttribute("DanceSpeed")
			if typeof(key) == "string" and typeof(start) == "number" and typeof(speed) == "number" then
				entry.k = key
				entry.t = math.floor(math.max(0, at - start) * speed * 1000 + 0.5) / 1000
			end
			table.insert(people, entry)
		end
	end
	return { people = people }
end

local function boothInfo(booth: Model, stand: BasePart): any
	local camera = part(booth, "CameraPoint")
	local backdrop = part(booth, "Backdrop")
	local color = if backdrop then backdrop.Color else Color3.fromRGB(230, 230, 235)
	return {
		key = booth:GetAttribute("BoothKey") or booth.Name,
		back = { math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255) },
		cam = if camera then { stand.CFrame:ToObjectSpace(camera.CFrame):GetComponents() } else nil,
	}
end

local function placeOnStand(session: Session, stand: BasePart)
	local count = #session.people
	for index, person in ipairs(session.people) do
		local character = person.Character
		if character then
			local offset = (index - (count + 1) / 2) * 2.8
			local floorY = -stand.Size.Y / 2 + 3.1
			character:PivotTo(stand.CFrame * CFrame.new(offset, floorY, 0))
			character:SetAttribute("PhotoBooth", session.booth:GetAttribute("BoothKey"))
		end
	end
end

local function runSession(session: Session)
	local booth = session.booth
	local stand = part(booth, "Stand")
	if not stand then
		endSession(session, "부스를 찾을 수 없어요.")
		return
	end
	-- Waiting for friends.
	local waitUntil = now() + (if session.mode == "solo" then PhotoConfig.SoloWaitSeconds else PhotoConfig.WaitSeconds)
	booth:SetAttribute("WaitUntil", waitUntil)
	while sessions[booth] == session and now() < waitUntil and not session.startNow do
		task.wait(0.2)
	end
	if sessions[booth] ~= session then return end

	-- Shooting.
	session.phase = "shooting"
	for _, person in ipairs(session.people) do
		local character = person.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local ok, snapshot = pcall(function()
				return OutfitSnapshot.encode(humanoid:GetAppliedDescription())
			end)
			if ok then session.outfits[person.UserId] = snapshot end
		end
		session.names[person.UserId] = person.DisplayName
	end
	placeOnStand(session, stand)
	publish(session, booth)
	for index = 1, PhotoConfig.ShotCount do
		local at = now() + (if index == 1 then PhotoConfig.FirstShotSeconds else PhotoConfig.ShotSeconds)
		booth:SetAttribute("ShotIndex", index)
		booth:SetAttribute("NextShotAt", at)
		while sessions[booth] == session and now() < at do
			task.wait(0.1)
			-- Walking away from the booth during the shoot = leaving.
			for i = #session.people, 1, -1 do
				local person = session.people[i]
				if not person.Parent or not near(person, booth, PhotoConfig.LeaveDistance) then
					removePerson(session, person, "부스에서 멀어져 촬영에서 나왔어요.")
				end
			end
			if #session.people == 0 then
				endSession(session, nil)
			end
		end
		if sessions[booth] ~= session then return end
		table.insert(session.shots, captureShot(session, stand, at))
		for _, person in ipairs(session.people) do
			if event then event:FireClient(person, "Shot", index) end
		end
	end

	-- Picking: every participant gets the shots.
	session.phase = "picking"
	booth:SetAttribute("ShotIndex", 0)
	booth:SetAttribute("NextShotAt", 0)
	booth:SetAttribute("WaitUntil", now() + PhotoConfig.PickSeconds)
	publish(session, booth)
	for _, person in ipairs(session.people) do clearProps(person) end
	local peopleInfo = {}
	for userId, name in pairs(session.names) do
		table.insert(peopleInfo, { u = userId, n = name, o = session.outfits[userId] })
	end
	local payload = {
		session = session.id,
		layout = session.layout,
		booth = boothInfo(booth, stand),
		people = peopleInfo,
		shots = session.shots,
	}
	for _, person in ipairs(session.people) do
		if event then event:FireClient(person, "Shots", payload) end
	end
	local deadline = now() + PhotoConfig.PickSeconds
	while sessions[booth] == session and now() < deadline do
		local allDone = true
		for _, person in ipairs(session.people) do
			if person.Parent and not session.saved[person] then allDone = false end
		end
		if allDone then break end
		task.wait(0.5)
	end
	endSession(session, nil)
end

--------------------------------------------------
-- Requests
--------------------------------------------------

local function boothFrom(value: any): Model?
	if typeof(value) == "Instance" and value:IsA("Model") and CollectionService:HasTag(value, "PhotoBooth") then
		return value
	end
	return nil
end

local function open(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" then return false, "잘못된 요청입니다." end
	local booth = boothFrom(payload.booth)
	if not booth then return false, "부스를 찾을 수 없어요." end
	if byPlayer[player] then return false, "이미 촬영 중이에요." end
	if sessions[booth] then return false, "다른 사람이 쓰고 있는 부스예요. 잠시 기다려 주세요." end
	if not PhotoConfig.findLayout(payload.layout) or not PhotoConfig.isMode(payload.mode) then
		return false, "사진 유형을 골라 주세요."
	end
	if not near(player, booth, PhotoConfig.OpenDistance) then return false, "부스 가까이에서 시작하세요." end
	local session: Session = {
		id = HttpService:GenerateGUID(false),
		booth = booth,
		host = player,
		layout = payload.layout,
		mode = payload.mode,
		phase = "waiting",
		people = { player },
		names = {},
		outfits = {},
		shots = {},
		saved = {},
		startNow = false,
	}
	sessions[booth] = session
	byPlayer[player] = session
	publish(session, booth)
	task.spawn(runSession, session)
	return true, nil
end

local function isFriend(a: Player, b: Player): boolean
	local ok, value = pcall(function() return a:IsFriendsWith(b.UserId) end)
	return ok and value == true
end

local function join(player: Player, payload: any): (boolean, string?)
	local booth = boothFrom(if typeof(payload) == "table" then payload.booth else payload)
	local session = booth and sessions[booth]
	if not booth or not session or session.phase ~= "waiting" then return false, "지금은 함께할 수 없어요." end
	if byPlayer[player] then return false, "이미 촬영 중이에요." end
	if session.mode == "solo" then return false, "혼자 찍는 중이에요." end
	if session.mode == "friends" and not isFriend(player, session.host) then
		return false, session.host.DisplayName .. "님의 친구만 함께할 수 있어요."
	end
	if #session.people >= PhotoConfig.MaxPeople then return false, "자리가 다 찼어요 (최대 4명)." end
	if not near(player, booth, PhotoConfig.OpenDistance) then return false, "부스 가까이 가 주세요." end
	table.insert(session.people, player)
	byPlayer[player] = session
	publish(session, booth)
	toast(session.host, player.DisplayName .. "님이 함께 찍어요!")
	return true, nil
end

local function toggleProp(player: Player, key: any): (boolean, string?)
	local session = byPlayer[player]
	if not session or session.phase ~= "shooting" then return false, nil end
	if not PhotoConfig.isProp(key) then return false, nil end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then return false, nil end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child:GetAttribute("PhotoProp") == key then
			child:Destroy()
			return true, nil
		end
	end
	if #PhotoProps.worn(character) >= PhotoConfig.MaxProps then
		return false, string.format("소품은 %d개까지 쓸 수 있어요.", PhotoConfig.MaxProps)
	end
	local accessory = PhotoProps.build(key)
	if not accessory then return false, nil end
	humanoid:AddAccessory(accessory)
	return true, nil
end

-- picks: PickCount distinct shot numbers (order = order in the photo).
local function save(player: Player, payload: any): (boolean, any)
	local session = byPlayer[player]
	if not session or session.phase ~= "picking" or session.saved[player] then
		return false, "저장할 촬영이 없어요."
	end
	if typeof(payload) ~= "table" or typeof(payload.picks) ~= "table" then return false, "사진을 골라 주세요." end
	local frame = PhotoConfig.findFrame(payload.frame)
	if not frame then return false, "프레임을 골라 주세요." end
	local picks = {}
	local seen = {}
	for _, index in ipairs(payload.picks) do
		if typeof(index) ~= "number" or index % 1 ~= 0 or not session.shots[index] or seen[index] then
			return false, "사진 선택이 올바르지 않아요."
		end
		seen[index] = true
		table.insert(picks, index)
	end
	if #picks ~= PhotoConfig.PickCount then
		return false, string.format("사진을 %d장 골라 주세요.", PhotoConfig.PickCount)
	end
	local stand = part(session.booth, "Stand")
	if not stand then return false, "부스를 찾을 수 없어요." end
	-- Only the people who appear in the picked shots are stored.
	local shots = {}
	local who: {[number]: boolean} = {}
	for _, index in ipairs(picks) do
		local shot = session.shots[index]
		table.insert(shots, shot)
		for _, entry in ipairs(shot.people) do who[entry.u] = true end
	end
	local people = {}
	for userId in pairs(who) do
		table.insert(people, { u = userId, n = session.names[userId] or "?", o = session.outfits[userId] })
	end
	local photo = {
		id = HttpService:GenerateGUID(false),
		v = 1,
		createdAt = os.time(),
		layout = session.layout,
		frame = frame.key,
		booth = boothInfo(session.booth, stand),
		people = people,
		shots = shots,
	}
	local ok, result = playerData.SavePhoto(player, photo)
	if not ok then return false, result end
	session.saved[player] = true
	return true, { photo = photo, count = #result.photos, max = result.max, persistent = result.persistent, note = result.note }
end

local function handle(player: Player, action: any, payload: any): (boolean, any)
	local t = os.clock()
	if action ~= "Leave" and lastCall[player] and t - lastCall[player] < 0.2 then
		return false, "잠시 후 다시 시도하세요."
	end
	lastCall[player] = t
	if action == "Open" then
		return open(player, payload)
	elseif action == "Join" then
		return join(player, payload)
	elseif action == "Start" then
		local session = byPlayer[player]
		if session and session.host == player and session.phase == "waiting" then
			session.startNow = true
			return true, nil
		end
		return false, nil
	elseif action == "Leave" then
		local session = byPlayer[player]
		if session then removePerson(session, player, nil) end
		return true, nil
	elseif action == "Prop" then
		return toggleProp(player, payload)
	elseif action == "Save" then
		return save(player, payload)
	elseif action == "GetAlbum" then
		return playerData.GetPhotos(player)
	elseif action == "DeletePhoto" then
		return playerData.DeletePhoto(player, payload)
	end
	return false, "잘못된 요청입니다."
end

--------------------------------------------------

local function setupBooth(booth: Instance)
	if not booth:IsA("Model") then return end
	local stand = part(booth, "Stand")
	if not stand or stand:FindFirstChild("PhotoPrompt") then return end
	local start = Instance.new("ProximityPrompt")
	start.Name = "PhotoPrompt"
	start.ActionText = "사진 찍기"
	start.ObjectText = tostring(booth:GetAttribute("BoothName") or "인생네컷")
	start.MaxActivationDistance = 14
	start.RequiresLineOfSight = false
	start.Parent = stand
	local joinPrompt = Instance.new("ProximityPrompt")
	joinPrompt.Name = "JoinPrompt"
	joinPrompt.ActionText = "같이 찍기"
	joinPrompt.ObjectText = tostring(booth:GetAttribute("BoothName") or "인생네컷")
	joinPrompt.KeyboardKeyCode = Enum.KeyCode.F
	joinPrompt.MaxActivationDistance = 14
	joinPrompt.RequiresLineOfSight = false
	joinPrompt.Enabled = false
	joinPrompt.Parent = stand
	-- Both prompts are handled by the client (setup window / join request).
	publish(nil, booth)
end

function PhotoBoothService.Start(dataService: any)
	playerData = dataService
	local remotes = FashionGame:WaitForChild("Remotes")
	event = remotes:WaitForChild("PhotoBoothEvent") :: RemoteEvent
	local remote = remotes:WaitForChild("PhotoBooth") :: RemoteFunction
	remote.OnServerInvoke = function(player, action, payload)
		local ok, a, b = pcall(handle, player, action, payload)
		if not ok then
			warn("[PhotoBoothService]", a)
			return false, "잠시 후 다시 시도하세요."
		end
		return a, b
	end
	for _, booth in ipairs(CollectionService:GetTagged("PhotoBooth")) do setupBooth(booth) end
	CollectionService:GetInstanceAddedSignal("PhotoBooth"):Connect(setupBooth)
	Players.PlayerRemoving:Connect(function(player)
		local session = byPlayer[player]
		if session then removePerson(session, player, nil) end
		lastCall[player] = nil
	end)
end

return PhotoBoothService

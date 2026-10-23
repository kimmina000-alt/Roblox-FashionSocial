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
--      Starting or joining puts the person inside the booth; until they save
--      (or press 나가기) they cannot walk out, and nobody else can walk in
--      (D-064, user 2026-10-20: "안 보이는 결계").
--   2. Shooting: everyone is placed on the stand facing the camera; 8 photos,
--      one every 10 s (first one 8 s). People can move, pick poses (the club
--      dances, allowed on PhotoStage) and props. Each photo stores, per
--      person: position/yaw on the stand, dance key + clip time, props.
--      Outfits are captured once when shooting starts (OutfitSnapshot).
--   3. Picking (user, 2026-10-22): everyone gets the 8 shots ("Shots"), but
--      only the picker (the host) picks 4 and a frame; every change is sent
--      to the others live ("PickState") so they watch. "Confirm" → copies.
--   4. Copies: each person chooses how many prints to keep ("Copies"; 1
--      free, PhotoConfig.ExtraCopyCoins each after) → "SaveCopies" → album
--      (PlayerDataService.SavePhoto) and out of the booth. Time up → 1 free
--      print each ("AutoSaved"). Poses stop when the shooting ends.
--   5. Album extras: "TakeOut" gives the photo as a Tool (inventory item);
--      "WallPost" sticks it on a photo wall (tag "PhotoWall") and removes it
--      from the album (it is used up, like a real print). Wall photos may
--      overlap; the newest PhotoConfig.MaxWallPhotos stay (this server only).
--
-- Public booth attributes (clients follow them):
--   Phase "idle"|"waiting"|"shooting"|"picking"|"copies", Host, Picker,
--   Layout, Mode,
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
local EconomyService = require(script.Parent.EconomyService)
local ClubService = require(script.Parent.ClubService)

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
	-- Picking (user, 2026-10-22): only the picker (the host; the next person
	-- if the host leaves) chooses the shots and the frame; the others watch
	-- live. Then everyone chooses how many copies to keep.
	picker: Player?,
	pickState: { picks: {number}, frame: string, stage: string },
	final: { picks: {number}, frame: string }?,
}

local sessions: {[Model]: Session} = {}
local byPlayer: {[Player]: Session} = {}
local playerData: any = nil
local event: RemoteEvent? = nil
local lastCall: {[Player]: number} = {}
local lastPush: {[Player]: number} = {}

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

--------------------------------------------------
-- Booth space (the invisible barrier)
--------------------------------------------------

-- Box of the booth's inside: the studio floor footprint, 12 studs high.
local function insideBox(booth: Model): (CFrame?, Vector3?)
	local floor = part(booth, "StudioFloor") or part(booth, "Stand")
	if not floor then return nil, nil end
	local size = Vector3.new(floor.Size.X, 12, floor.Size.Z)
	return floor.CFrame * CFrame.new(0, 6 - floor.Size.Y / 2, 0), size
end

local function isInside(booth: Model, position: Vector3): boolean
	local cf, size = insideBox(booth)
	if not cf or not size then return false end
	local p = cf:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 + 0.5 and math.abs(p.Z) <= size.Z / 2 + 0.5 and math.abs(p.Y) <= size.Y / 2 + 2
end

-- Where person `index` of `count` stands (facing the camera).
local function spotFor(stand: BasePart, index: number, count: number): CFrame
	local offset = (index - (count + 1) / 2) * 2.8
	return stand.CFrame * CFrame.new(offset, -stand.Size.Y / 2 + 3.1, 0)
end

-- Just outside the open side, behind the camera, facing the booth.
local function exitFor(booth: Model): CFrame?
	-- a booth whose opening is not behind the camera marks its way out
	local exitPoint = part(booth, "ExitPoint")
	if exitPoint then return exitPoint.CFrame end
	local stand = part(booth, "Stand")
	local camera = part(booth, "CameraPoint")
	if not stand or not camera then return nil end
	local away = camera.Position - stand.Position
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.1 then return nil end
	away = away.Unit
	local base = Vector3.new(camera.Position.X, stand.Position.Y - stand.Size.Y / 2 + 3.1, camera.Position.Z) + away * 4
	return CFrame.lookAt(base, base - away)
end

local function sitUp(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then humanoid.Sit = false end
end

local function moveInside(session: Session, player: Player)
	local stand = part(session.booth, "Stand")
	local character = player.Character
	if not stand or not character then return end
	local index = table.find(session.people, player) or 1
	sitUp(character)
	character:PivotTo(spotFor(stand, index, #session.people))
end

local function moveOutside(booth: Model, player: Player)
	local character = player.Character
	local root = rootOf(player)
	local exit = exitFor(booth)
	if character and root and exit and isInside(booth, root.Position) then
		sitUp(character)
		character:PivotTo(exit)
	end
end

local function active(session: Session, player: Player): boolean
	return table.find(session.people, player) ~= nil and not session.saved[player] and byPlayer[player] == session
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
		-- Only people still in the booth flow (saved people are released, so
		-- their client does not follow this booth any more).
		local ids = {}
		for _, person in ipairs(session.people) do
			if active(session, person) then table.insert(ids, person.UserId) end
		end
		booth:SetAttribute("Phase", session.phase)
		booth:SetAttribute("Host", session.host.UserId)
		booth:SetAttribute("Picker", if session.picker then session.picker.UserId else 0)
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
end

-- The person is done with the booth: out of the barrier, props off.
local function release(session: Session, player: Player)
	if byPlayer[player] == session then byPlayer[player] = nil end
	clearProps(player)
	local character = player.Character
	if character then character:SetAttribute("PhotoBooth", nil) end
	moveOutside(session.booth, player)
end

local function endSession(session: Session, reason: string?)
	if sessions[session.booth] ~= session then return end
	sessions[session.booth] = nil
	for _, person in ipairs(session.people) do
		if byPlayer[person] == session then
			release(session, person)
			if event and person.Parent then event:FireClient(person, "Ended", reason) end
		end
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
	if session.phase == "picking" or session.phase == "copies" then
		-- Keep them in the list (their shots are already captured); just done.
		session.saved[player] = true
		if session.picker == player and session.phase == "picking" then
			-- The next person still here takes over picking.
			session.picker = nil
			for _, person in ipairs(session.people) do
				if person ~= player and active(session, person) then session.picker = person break end
			end
			for _, person in ipairs(session.people) do
				if active(session, person) and event then event:FireClient(person, "PickState", session.pickState) end
			end
		end
	else
		table.remove(session.people, index)
	end
	release(session, player)
	if event and player.Parent then event:FireClient(player, "Ended", reason) end
	publish(session, session.booth)
end

-- Every 0.25 s: people in a booth flow stay inside; others cannot walk in.
local function guardBooths()
	for booth, session in pairs(sessions) do
		for _, person in ipairs(session.people) do
			local root = rootOf(person)
			if root and active(session, person) and not isInside(booth, root.Position) then
				moveInside(session, person)
			end
		end
		for _, other in ipairs(Players:GetPlayers()) do
			local root = rootOf(other)
			if root and not active(session, other) and isInside(booth, root.Position) then
				moveOutside(booth, other)
				local t = os.clock()
				if not lastPush[other] or t - lastPush[other] > 4 then
					lastPush[other] = t
					toast(other, "지금 촬영 중인 부스예요. 잠시 기다려 주세요.")
				end
			end
		end
	end
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
			local paused = character:GetAttribute("DancePause")
			if typeof(key) == "string" and typeof(start) == "number" and typeof(speed) == "number" then
				entry.k = key
				local t = if typeof(paused) == "number" then paused else math.max(0, at - start) * speed
				entry.t = math.floor(t * 1000 + 0.5) / 1000
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

local function placeOnStand(session: Session)
	for _, person in ipairs(session.people) do
		moveInside(session, person)
	end
end

-- The picker's current choice made complete: missing picks are filled with
-- the first unused shots, a frame the picker does not own falls back to white.
local function completeChoice(session: Session): { picks: {number}, frame: string }
	local picks = table.clone(session.pickState.picks)
	for index = 1, #session.shots do
		if #picks >= PhotoConfig.PickCount then break end
		if not table.find(picks, index) then table.insert(picks, index) end
	end
	local frame = session.pickState.frame
	if not PhotoConfig.findFrame(frame) or (session.picker and not EconomyService.OwnsFrame(session.picker, frame)) then
		frame = "white"
	end
	return { picks = picks, frame = frame }
end

-- One photo (data) from the final choice. Only people who appear in the
-- picked shots are stored.
local function makePhoto(session: Session, choice: { picks: {number}, frame: string }): any?
	local stand = part(session.booth, "Stand")
	if not stand then return nil end
	local shots = {}
	local who: {[number]: boolean} = {}
	for _, index in ipairs(choice.picks) do
		local shot = session.shots[index]
		if shot then
			table.insert(shots, shot)
			for _, entry in ipairs(shot.people) do who[entry.u] = true end
		end
	end
	local people = {}
	for userId in pairs(who) do
		table.insert(people, { u = userId, n = session.names[userId] or "?", o = session.outfits[userId] })
	end
	return {
		id = HttpService:GenerateGUID(false),
		v = 1,
		createdAt = os.time(),
		layout = session.layout,
		frame = choice.frame,
		booth = boothInfo(session.booth, stand),
		people = people,
		shots = shots,
	}
end

-- How many copies this person may still keep (album space, MaxCopies).
local function copyLimit(player: Player): number
	local count, max = playerData.PhotoCapacity(player)
	return math.clamp(max - count, 0, PhotoConfig.MaxCopies)
end

-- Saves `copies` prints of the final photo for one person (1 free, the rest
-- PhotoConfig.ExtraCopyCoins each), then releases them from the booth.
local function saveCopies(session: Session, player: Player, copies: number): (boolean, any)
	local choice = session.final
	if not choice or session.phase ~= "copies" or session.saved[player] or not active(session, player) then
		return false, "저장할 사진이 없어요."
	end
	if typeof(copies) ~= "number" or copies % 1 ~= 0 or copies < 1 then return false, "장수를 골라 주세요." end
	local limit = copyLimit(player)
	if limit < 1 then return false, "사진첩이 가득 찼어요." end
	copies = math.min(copies, limit)
	local cost = (copies - 1) * PhotoConfig.ExtraCopyCoins
	if cost > 0 and not EconomyService.Spend(player, cost) then
		return false, string.format("코인이 부족해요 (%d 필요).", cost)
	end
	local last: any = nil
	local firstPhoto: any = nil
	for _ = 1, copies do
		local photo = makePhoto(session, choice)
		if not photo then break end
		local ok, result = playerData.SavePhoto(player, photo)
		if not ok then
			if not last then return false, result end
			break
		end
		last = result
		firstPhoto = firstPhoto or photo
	end
	session.saved[player] = true
	-- Saved → out of the booth (user, 2026-10-20).
	release(session, player)
	publish(session, session.booth)
	EconomyService.Award(player, "PhotoSaved")
	if firstPhoto and #firstPhoto.people > 1 then EconomyService.Award(player, "PhotoGroup") end
	return true, { photo = firstPhoto, copies = copies, count = #last.photos, max = last.max, persistent = last.persistent, note = last.note }
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
	placeOnStand(session)
	publish(session, booth)
	for index = 1, PhotoConfig.ShotCount do
		local at = now() + (if index == 1 then PhotoConfig.FirstShotSeconds else PhotoConfig.ShotSeconds)
		booth:SetAttribute("ShotIndex", index)
		booth:SetAttribute("NextShotAt", at)
		while sessions[booth] == session and now() < at do
			task.wait(0.1)
			for i = #session.people, 1, -1 do
				local person = session.people[i]
				if not person.Parent then
					removePerson(session, person, nil)
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

	-- Picking: every participant gets the shots; only the picker chooses,
	-- the others watch (PickState). Poses and props stop (user, 2026-10-20:
	-- after the last photo everyone is back to idle).
	session.phase = "picking"
	session.picker = if active(session, session.host) then session.host else nil
	if not session.picker then
		for _, person in ipairs(session.people) do
			if active(session, person) then session.picker = person break end
		end
	end
	booth:SetAttribute("ShotIndex", 0)
	booth:SetAttribute("NextShotAt", 0)
	booth:SetAttribute("WaitUntil", now() + PhotoConfig.PickSeconds)
	publish(session, booth)
	for _, person in ipairs(session.people) do
		clearProps(person)
		pcall(ClubService.StopDance, person)
	end
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
	local function anyoneLeft(): boolean
		for _, person in ipairs(session.people) do
			if person.Parent and active(session, person) then return true end
		end
		return false
	end
	local deadline = now() + PhotoConfig.PickSeconds
	while sessions[booth] == session and now() < deadline and not session.final do
		if not anyoneLeft() then break end
		task.wait(0.25)
	end
	if sessions[booth] ~= session then return end
	if not anyoneLeft() then endSession(session, nil) return end

	-- Copies: everyone chooses how many prints to keep (1 free).
	session.final = session.final or completeChoice(session)
	session.phase = "copies"
	booth:SetAttribute("WaitUntil", now() + PhotoConfig.CopySeconds)
	publish(session, booth)
	for _, person in ipairs(session.people) do
		if active(session, person) and event then
			event:FireClient(person, "Copies", {
				picks = (session.final :: any).picks,
				frame = (session.final :: any).frame,
				free = 1,
				price = PhotoConfig.ExtraCopyCoins,
				max = copyLimit(person),
			})
		end
	end
	local copyDeadline = now() + PhotoConfig.CopySeconds
	while sessions[booth] == session and now() < copyDeadline do
		if not anyoneLeft() then break end
		task.wait(0.25)
	end
	if sessions[booth] ~= session then return end
	-- Time is up: whoever did not choose keeps one free print.
	for _, person in ipairs(session.people) do
		if person.Parent and active(session, person) then
			local ok, result = saveCopies(session, person, 1)
			if ok and event then event:FireClient(person, "AutoSaved", result) end
		end
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

local function albumFull(player: Player): string?
	local count, max = playerData.PhotoCapacity(player)
	if count >= max then
		return string.format("사진첩이 가득 찼어요 (%d/%d). 사진첩에서 지우거나 포토월에 붙인 뒤 찍어 주세요.", count, max)
	end
	return nil
end

local function enter(session: Session, player: Player)
	byPlayer[player] = session
	local character = player.Character
	if character then character:SetAttribute("PhotoBooth", session.booth:GetAttribute("BoothKey")) end
	moveInside(session, player)
end

local function open(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" then return false, "잘못된 요청입니다." end
	local booth = boothFrom(payload.booth)
	if not booth then return false, "부스를 찾을 수 없어요." end
	local previous = byPlayer[player]
	if previous then
		-- A finished session (picking, already saved) never blocks a new one.
		if (previous.phase == "picking" or previous.phase == "copies") and previous.saved[player] then
			byPlayer[player] = nil
		else
			return false, "이미 촬영 중이에요."
		end
	end
	if sessions[booth] then return false, "다른 사람이 쓰고 있는 부스예요. 잠시 기다려 주세요." end
	if not PhotoConfig.findLayout(payload.layout) or not PhotoConfig.isMode(payload.mode) then
		return false, "사진 유형을 골라 주세요."
	end
	if not near(player, booth, PhotoConfig.OpenDistance) then return false, "부스 가까이에서 시작하세요." end
	local full = albumFull(player)
	if full then return false, full end
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
		picker = nil,
		pickState = { picks = {}, frame = "white", stage = "picking" },
		final = nil,
	}
	sessions[booth] = session
	enter(session, player)
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
	local full = albumFull(player)
	if full then return false, full end
	table.insert(session.people, player)
	enter(session, player)
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
	local accessory = PhotoProps.build(key, PhotoProps.liftFor(character))
	if not accessory then return false, nil end
	humanoid:AddAccessory(accessory)
	return true, nil
end

-- The picker's choice so far: picks (≤ PickCount distinct shot numbers, in
-- photo order), frame key, stage ("picking" | "frame"). Shown live to the
-- others (user, 2026-10-22).
local function readChoice(session: Session, payload: any): ({ picks: {number}, frame: string, stage: string }?, string?)
	if typeof(payload) ~= "table" or typeof(payload.picks) ~= "table" then return nil, "사진을 골라 주세요." end
	local picks = {}
	local seen = {}
	for _, index in ipairs(payload.picks) do
		if typeof(index) ~= "number" or index % 1 ~= 0 or not session.shots[index] or seen[index] then
			return nil, "사진 선택이 올바르지 않아요."
		end
		seen[index] = true
		table.insert(picks, index)
	end
	if #picks > PhotoConfig.PickCount then return nil, "사진 선택이 올바르지 않아요." end
	local frame = if PhotoConfig.findFrame(payload.frame) then payload.frame else "white"
	local stage = if payload.stage == "frame" then "frame" else "picking"
	return { picks = picks, frame = frame, stage = stage }, nil
end

local function pickUpdate(player: Player, payload: any): (boolean, any)
	local session = byPlayer[player]
	if not session or session.phase ~= "picking" or session.picker ~= player then return false, nil end
	local choice, message = readChoice(session, payload)
	if not choice then return false, message end
	session.pickState = choice
	for _, person in ipairs(session.people) do
		if person ~= player and active(session, person) and event then event:FireClient(person, "PickState", choice) end
	end
	return true, nil
end

-- The picker is done: 4 shots + a frame they own → everyone chooses copies.
local function confirm(player: Player, payload: any): (boolean, any)
	local session = byPlayer[player]
	if not session or session.phase ~= "picking" or session.picker ~= player then
		return false, "사진은 처음 찍기를 시작한 사람이 골라요."
	end
	local choice, message = readChoice(session, payload)
	if not choice then return false, message end
	if #choice.picks ~= PhotoConfig.PickCount then
		return false, string.format("사진을 %d장 골라 주세요.", PhotoConfig.PickCount)
	end
	if not EconomyService.OwnsFrame(player, choice.frame) then return false, "아직 가지고 있지 않은 프레임이에요." end
	session.pickState = choice
	session.final = { picks = choice.picks, frame = choice.frame }
	return true, nil
end
--------------------------------------------------
-- Photo items (Tool) and the photo wall
--------------------------------------------------

local function photoTools(player: Player): {Tool}
	local list = {}
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and typeof(child:GetAttribute("PhotoId")) == "string" then table.insert(list, child) end
			end
		end
	end
	return list
end

local function buildPhotoTool(photo: any): Tool
	local frame = PhotoConfig.findFrame(photo.frame) or PhotoConfig.Frames[2]
	local layout = PhotoConfig.findLayout(photo.layout) or PhotoConfig.Layouts[1]
	local tool = Instance.new("Tool")
	tool.Name = "인생네컷"
	tool.ToolTip = "인생네컷 " .. os.date("%m.%d", photo.createdAt or os.time())
	tool.CanBeDropped = false
	tool:SetAttribute("PhotoId", photo.id)
	tool.Grip = CFrame.new(0, -0.9, 0) * CFrame.Angles(0, math.rad(180), 0)
	local w, h = if layout.cols == 1 then 0.9 else 1.6, if layout.cols == 1 then 2.7 else 1.4
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(w, h, 0.06)
	handle.Color = frame.color
	handle.Material = if frame.style == "gloss" then Enum.Material.Glass elseif frame.style == "glitter" then Enum.Material.Foil else Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local cellW = (w - 0.12 * (layout.cols + 1)) / layout.cols
	local cellH = (h - 0.25 - 0.12 * (layout.rows + 1)) / layout.rows
	for row = 0, layout.rows - 1 do
		for col = 0, layout.cols - 1 do
			local cell = Instance.new("Part")
			cell.Name = "Cell"
			cell.Size = Vector3.new(cellW, cellH, 0.02)
			cell.Color = Color3.fromRGB(235, 225, 230)
			cell.CanCollide = false
			cell.Massless = true
			local x = -w / 2 + 0.12 + cellW / 2 + col * (cellW + 0.12)
			local y = h / 2 - 0.12 - cellH / 2 - row * (cellH + 0.12)
			cell.CFrame = handle.CFrame * CFrame.new(x, y, -0.04)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = cell
			weld.Parent = cell
			cell.Parent = tool
		end
	end
	return tool
end

local function takeOut(player: Player, id: any): (boolean, string?)
	local photo = playerData.FindPhoto(player, id)
	if not photo then return false, "사진을 찾을 수 없어요." end
	local tools = photoTools(player)
	for _, tool in ipairs(tools) do
		if tool:GetAttribute("PhotoId") == id then return true, "이미 가방에 있는 사진이에요." end
	end
	if #tools >= 3 then
		-- Keep at most 3 photos in the backpack: the oldest goes back.
		tools[1]:Destroy()
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, "가방을 찾을 수 없어요." end
	buildPhotoTool(photo).Parent = backpack
	return true, "사진을 가방에 넣었어요! 아래 아이템 칸에서 꺼내 들 수 있어요."
end

type WallEntry = { id: string, wall: string, u: number, v: number, by: string, at: number, photo: any }
local wallEntries: {WallEntry} = {}

local function wallFrom(value: any): BasePart?
	if typeof(value) == "Instance" and value:IsA("BasePart") and CollectionService:HasTag(value, "PhotoWall") then
		return value
	end
	return nil
end

local function wallKey(wall: BasePart): string
	return tostring(wall:GetAttribute("WallKey") or wall:GetFullName())
end

local function wallPost(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" then return false, "잘못된 요청입니다." end
	local wall = wallFrom(payload.wall)
	if not wall then return false, "포토월을 찾을 수 없어요." end
	local root = rootOf(player)
	if not root or (root.Position - wall.Position).Magnitude > math.max(wall.Size.X, wall.Size.Y) / 2 + 18 then
		return false, "포토월 가까이에서 붙여 주세요."
	end
	local u, v = payload.u, payload.v
	if typeof(u) ~= "number" or typeof(v) ~= "number" or u ~= u or v ~= v then return false, "붙일 자리를 골라 주세요." end
	local photo = playerData.FindPhoto(player, payload.id)
	if not photo then return false, "사진을 찾을 수 없어요." end
	-- The print is used up: it leaves the album and the backpack.
	local ok, message = playerData.DeletePhoto(player, photo.id)
	if not ok then return false, message end
	for _, tool in ipairs(photoTools(player)) do
		if tool:GetAttribute("PhotoId") == photo.id then tool:Destroy() end
	end
	local entry: WallEntry = {
		id = photo.id,
		wall = wallKey(wall),
		u = math.clamp(u, 0, 1),
		v = math.clamp(v, 0, 1),
		by = player.DisplayName,
		at = now(),
		photo = photo,
	}
	table.insert(wallEntries, entry)
	while #wallEntries > PhotoConfig.MaxWallPhotos do table.remove(wallEntries, 1) end
	if event then event:FireAllClients("WallAdd", entry) end
	EconomyService.Award(player, "WallPost")
	return true, "포토월에 붙였어요!"
end

local function setupWall(wall: Instance)
	if not wall:IsA("BasePart") or wall:FindFirstChild("WallPrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WallPrompt"
	prompt.ActionText = "사진 붙이기"
	prompt.ObjectText = "포토월"
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = wall
	-- The client opens the album picker and the placement mode.
end

local function handle(player: Player, action: any, payload: any): (boolean, any)
	local t = os.clock()
	-- PickUpdate carries the whole choice each time, so it is not throttled
	-- (a dropped one would leave the watchers out of date).
	if action ~= "Leave" and action ~= "GetWall" and action ~= "PickUpdate" and lastCall[player] and t - lastCall[player] < 0.2 then
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
	elseif action == "PickUpdate" then
		return pickUpdate(player, payload)
	elseif action == "Confirm" then
		return confirm(player, payload)
	elseif action == "SaveCopies" then
		local session = byPlayer[player]
		if not session then return false, "저장할 사진이 없어요." end
		return saveCopies(session, player, payload)
	elseif action == "GetAlbum" then
		return playerData.GetPhotos(player)
	elseif action == "DeletePhoto" then
		local ok, result = playerData.DeletePhoto(player, payload)
		if ok then
			for _, tool in ipairs(photoTools(player)) do
				if tool:GetAttribute("PhotoId") == payload then tool:Destroy() end
			end
		end
		return ok, result
	elseif action == "TakeOut" then
		return takeOut(player, payload)
	elseif action == "WallPost" then
		return wallPost(player, payload)
	elseif action == "GetWall" then
		return true, wallEntries
	elseif action == "BuyFrame" then
		return EconomyService.BuyFrame(player, payload)
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
	for _, wall in ipairs(CollectionService:GetTagged("PhotoWall")) do setupWall(wall) end
	CollectionService:GetInstanceAddedSignal("PhotoWall"):Connect(setupWall)
	Players.PlayerRemoving:Connect(function(player)
		local session = byPlayer[player]
		if session then removePerson(session, player, nil) end
		lastCall[player] = nil
		lastPush[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(guardBooths)
			if not ok then warn("[PhotoBoothService] guard", err) end
		end
	end)
end

return PhotoBoothService

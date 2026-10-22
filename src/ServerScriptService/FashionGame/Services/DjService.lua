--!strict
-- DJ booth time (D-052). One DJ per server at a time.
--
-- Buying "DJ" (Developer Product) gives MonetizationConfig.DJMinutes of DJ
-- time. If nobody is DJing the time starts now; the current DJ buying again
-- extends their time; anyone else is put in the queue and starts when the slot
-- frees up (time is never lost: it starts when the turn begins).
--
-- The current DJ may extend only while nobody is waiting (user, 2026-10-20);
-- a DJ who still buys while others wait goes to the back of the queue, so a
-- purchase is never lost.
--
-- DJ zone guests: besides the DJ, only players the DJ invites may enter the
-- DJ zone (user, 2026-10-20). Invites end when the DJ changes.
--
-- Public state (ReplicatedStorage.FashionGame attributes):
--   ClubDJ       userId of the DJ, 0 when nobody
--   ClubDJUntil  server time the current DJ's time ends
--   ClubDJQueue  number of people waiting
--   ClubDJGuests JSON list of invited userIds
--   ClubLights   lights on (nil/true) or off; ClubLightColor = ClubConfig.LightColors key
-- Character attribute "Djing" = true while the DJ stands at the turntable
-- after "디제잉하기" (clients show the DJ hand motion, DJMotionController).
--
-- DJ abilities live in ClubService (music) today. Future DJ features (lights,
-- effects, announcements, crowd votes) hook in through DjService.IsDJ and the
-- DjService.Actions table — see docs/01_SYSTEMS/DJ_SYSTEM.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local CollectionService = game:GetService("CollectionService")

local DjService = {}

type Slot = { userId: number, seconds: number }

local current: Slot? = nil
local fromQueue = false
local currentUntil = 0
local queue: {Slot} = {}
local guests: {[number]: boolean} = {}
local changed = Instance.new("BindableEvent")
DjService.Changed = changed.Event

local HttpService = game:GetService("HttpService")
local MAX_GUESTS = 6

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	FashionGame:SetAttribute("ClubDJ", if current then current.userId else 0)
	FashionGame:SetAttribute("ClubDJUntil", if current then currentUntil else 0)
	FashionGame:SetAttribute("ClubDJQueue", #queue)
	local list = {}
	for userId in pairs(guests) do table.insert(list, userId) end
	FashionGame:SetAttribute("ClubDJGuests", HttpService:JSONEncode(list))
	changed:Fire()
end

local function startNext()
	current = nil
	currentUntil = 0
	table.clear(guests)
	FashionGame:SetAttribute("ClubLights", true)
	FashionGame:SetAttribute("ClubLightColor", "rainbow")
	FashionGame:SetAttribute("ClubDJScreen", true)
	while #queue > 0 do
		local slot = table.remove(queue, 1) :: Slot
		if Players:GetPlayerByUserId(slot.userId) then
			current = slot
			currentUntil = now() + slot.seconds
			fromQueue = true
			break
		end
	end
	publish()
end

function DjService.IsDJ(player: Player): boolean
	return current ~= nil and current.userId == player.UserId and now() < currentUntil
end

-- True when the current DJ's turn started from the queue (not right after
-- buying), so ClubAccessService asks them before anything happens.
function DjService.StartedFromQueue(): boolean
	return current ~= nil and fromQueue
end

function DjService.CurrentDJ(): number
	return if current then current.userId else 0
end

function DjService.IsGuest(player: Player): boolean
	return current ~= nil and guests[player.UserId] == true
end

-- The current DJ can buy more time only while nobody is waiting.
function DjService.CanExtend(player: Player): boolean
	return current ~= nil and current.userId == player.UserId and #queue == 0
end

-- The current DJ gives up their turn (DJ 차례 확인창 → NO, user 2026-10-20).
-- The time is not refunded; the next person in the queue starts.
function DjService.Pass(player: Player): boolean
	if not current or current.userId ~= player.UserId then return false end
	startNext()
	return true
end

-- Adds DJ time for the player. Returns (true, message for the buyer, kind)
-- where kind is "start" (DJ now), "extend" or "queue".
function DjService.AddTime(player: Player): (boolean, string?, string?)
	local seconds = MonetizationConfig.DJMinutes * 60
	if current and current.userId == player.UserId then
		if #queue == 0 then
			currentUntil += seconds
			publish()
			return true, string.format("DJ 시간이 %d분 연장되었습니다.", MonetizationConfig.DJMinutes), "extend"
		end
		-- Others are waiting (the client hides 연장 then; this covers a race):
		-- the bought time becomes a new turn at the back of the queue.
		table.insert(queue, { userId = player.UserId, seconds = seconds })
		publish()
		return true, string.format("기다리는 DJ가 있어 연장 대신 대기 %d번째로 넣었어요.", #queue), "queue"
	end
	for _, slot in ipairs(queue) do
		if slot.userId == player.UserId then
			slot.seconds += seconds
			publish()
			return true, "대기 중인 DJ 시간이 늘어났습니다.", "queue"
		end
	end
	if current and now() >= currentUntil then
		-- The slot just expired (the 1 s sweep has not run yet).
		startNext()
	end
	if not current then
		current = { userId = player.UserId, seconds = seconds }
		currentUntil = now() + seconds
		fromQueue = false
		publish()
		return true, string.format("지금부터 %d분 동안 DJ입니다! DJ 턴테이블 앞에서 '디제잉하기'를 누르세요.", MonetizationConfig.DJMinutes), "start"
	end
	table.insert(queue, { userId = player.UserId, seconds = seconds })
	publish()
	return true, string.format("DJ 대기 %d번째입니다. 차례가 되면 이동할지 물어볼게요.", #queue), "queue"
end

-- Future DJ abilities register here: DjService.Actions[name] = function(player, payload) ... end
-- ClubService routes Music remote calls whose action is not a music action to this table.
DjService.Actions = {} :: {[string]: (Player, any) -> (boolean, any)}

local function notify(player: Player, message: string)
	local remotes = FashionGame:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("ClubNotify")
	if remote and remote:IsA("RemoteEvent") then remote:FireClient(player, "Toast", message) end
end

-- "Invite" / "Uninvite" (payload = userId): DJ zone guests. Only the DJ gets
-- here (ClubService checks IsDJ before calling an action).
DjService.Actions.Invite = function(dj: Player, userId: any): (boolean, any)
	local target = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not target or target == dj then return false, "초대할 수 없는 사람이에요." end
	if guests[target.UserId] then
		notify(dj, target.DisplayName .. "님은 이미 초대했어요.")
		return true, nil
	end
	local count = 0
	for _ in pairs(guests) do count += 1 end
	if count >= MAX_GUESTS then return false, string.format("DJ 존 초대는 %d명까지예요.", MAX_GUESTS) end
	guests[target.UserId] = true
	publish()
	notify(target, dj.DisplayName .. " DJ님이 DJ 존에 초대했어요! 무대로 올라오세요.")
	notify(dj, target.DisplayName .. "님을 DJ 존에 초대했어요.")
	return true, nil
end

-- "Lights" (payload = true/false): club lasers and beat lights on/off.
-- Public attribute ClubLights (true when nil). Reset to on for each new DJ.
DjService.Actions.Lights = function(_dj: Player, on: any): (boolean, any)
	FashionGame:SetAttribute("ClubLights", on == true)
	return true, if on == true then "조명을 켰어요." else "조명을 껐어요."
end

-- "Screen" (payload = true/false): show the DJ on the big LED screen behind
-- the booth (DJScreenController). Attribute ClubDJScreen, on for each new DJ.
DjService.Actions.Screen = function(_dj: Player, on: any): (boolean, any)
	FashionGame:SetAttribute("ClubDJScreen", on == true)
	return true, if on == true then "전광판에 내 모습을 보여 줘요." else "전광판에서 내 모습을 껐어요."
end

-- "LightColor" (payload = ClubConfig.LightColors key): colour of the lasers and
-- beat lights; picking a colour also switches the lights on.
DjService.Actions.LightColor = function(_dj: Player, key: any): (boolean, any)
	local entry = ClubConfig.findLightColor(key)
	if not entry then return false, "없는 조명 색이에요." end
	FashionGame:SetAttribute("ClubLightColor", entry.key)
	FashionGame:SetAttribute("ClubLights", true)
	return true, "조명: " .. entry.name
end

-- "Djing" (payload = true): the DJ starts DJing at the turntable — moved to the
-- DJ spot facing the crowd, character attribute Djing for the hand motion.
-- It ends when they walk away from the spot or their DJ time ends.
local function djSpot(): BasePart?
	for _, spot in ipairs(CollectionService:GetTagged("DJSpot")) do
		if spot:IsA("BasePart") and spot:IsDescendantOf(workspace) then return spot end
	end
	return nil
end
-- DJ lift (user, 2026-10-22: small avatars disappeared behind the turntable).
-- A platform under the DJ spot rises so the DJ's hips are level with the desk
-- top (user, 2026-10-22: "엉덩이 위치를 턴테이블 상단 높이에 맞춰"), whatever
-- the body size; tall avatars stay at floor level (the IK reaches down). It
-- sinks back when DJing ends.
local TweenService = game:GetService("TweenService")
local LIFT_MAX = 8
local liftParts: {BasePart} = {}
local function deskTop(): number?
	for _, console in ipairs(CollectionService:GetTagged("DJConsole")) do
		if console:IsDescendantOf(workspace) then
			local desk = console:FindFirstChild("DeskTop", true)
			if desk and desk:IsA("BasePart") then return desk.Position.Y + desk.Size.Y / 2 end
		end
	end
	return nil
end
local function setLift(spot: BasePart, height: number)
	local floorY = spot.Position.Y - spot.Size.Y / 2
	if #liftParts == 0 then
		local base = Instance.new("Part")
		base.Name = "DJLift"
		base.Anchored = true
		base.Size = Vector3.new(5, 8, 5)
		base.Color = Color3.fromRGB(30, 30, 38)
		base.Material = Enum.Material.DiamondPlate
		local glow = Instance.new("Part")
		glow.Name = "DJLiftGlow"
		glow.Anchored = true
		glow.CanCollide = false
		glow.Size = Vector3.new(5.3, 0.25, 5.3)
		glow.Color = Color3.fromRGB(255, 80, 200)
		glow.Material = Enum.Material.Neon
		base.CFrame = CFrame.new(spot.Position.X, floorY - 4 - 0.05, spot.Position.Z)
		glow.CFrame = CFrame.new(spot.Position.X, floorY - 0.2, spot.Position.Z)
		base.Parent = spot.Parent
		glow.Parent = spot.Parent
		liftParts = { base, glow }
	end
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(liftParts[1], info, { CFrame = CFrame.new(spot.Position.X, floorY + height - 4, spot.Position.Z) }):Play()
	TweenService:Create(liftParts[2], info, { CFrame = CFrame.new(spot.Position.X, floorY + height - 0.1, spot.Position.Z) }):Play()
end

DjService.Actions.Djing = function(dj: Player, on: any): (boolean, any)
	local character = dj.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then return false, nil end
	local spot = djSpot()
	if on ~= true then
		character:SetAttribute("Djing", nil)
		return true, nil
	end
	if not spot then return false, "DJ 자리를 찾을 수 없어요." end
	if (root.Position - spot.Position).Magnitude > 24 then return false, "턴테이블 앞으로 가 주세요." end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then humanoid.Sit = false end
	-- lift height for this body: hips (top of the upper legs) at the desk top
	local floorY = spot.Position.Y - spot.Size.Y / 2
	local rootHeight = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	local feetY = root.Position.Y - rootHeight
	local hipY: number? = nil
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg and leg:IsA("BasePart") then
			local legTop = leg.Position.Y + leg.Size.Y / 2
			hipY = if hipY then math.max(hipY, legTop) else legTop
		end
	end
	local hipHeight = if hipY then hipY - feetY else (if humanoid then humanoid.HipHeight else 2)
	local top = deskTop()
	local height = if top then math.clamp(top - floorY - hipHeight, 0, LIFT_MAX) else 0
	character:PivotTo(spot.CFrame + Vector3.new(0, rootHeight - spot.Size.Y / 2 + 0.2, 0))
	setLift(spot, height)
	task.delay(0.85, function()
		if character.Parent and character:GetAttribute("Djing") then
			character:PivotTo(spot.CFrame + Vector3.new(0, height + rootHeight - spot.Size.Y / 2 + 0.2, 0))
		end
	end)
	if character:GetAttribute("Djing") then return true, nil end
	character:SetAttribute("Djing", true)
	character:SetAttribute("DjLift", height)
	task.spawn(function()
		while character.Parent and character:GetAttribute("Djing") do
			task.wait(0.5)
			local r = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local flat = r and Vector3.new(r.Position.X - spot.Position.X, 0, r.Position.Z - spot.Position.Z).Magnitude
			if not r or not DjService.IsDJ(dj) or (flat :: number) > 5 then
				character:SetAttribute("Djing", nil)
			end
		end
		character:SetAttribute("DjLift", nil)
		setLift(spot, 0)
	end)
	return true, "🎧 디제잉 시작! 곡을 고르고 조명을 바꿔 보세요."
end

DjService.Actions.Uninvite = function(dj: Player, userId: any): (boolean, any)
	if typeof(userId) ~= "number" or not guests[userId] then return true, nil end
	guests[userId] = nil
	publish()
	local target = Players:GetPlayerByUserId(userId)
	if target then
		notify(target, "DJ 존 초대가 취소되었어요.")
		notify(dj, target.DisplayName .. "님 초대를 취소했어요.")
	end
	return true, nil
end

function DjService.Start()
	publish()
	Players.PlayerRemoving:Connect(function(player)
		if guests[player.UserId] then
			guests[player.UserId] = nil
		end
		for index = #queue, 1, -1 do
			if queue[index].userId == player.UserId then
				table.remove(queue, index)
			end
		end
		if current and current.userId == player.UserId then
			startNext()
		else
			publish()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if current and now() >= currentUntil then
				startNext()
			end
		end
	end)
end

return DjService

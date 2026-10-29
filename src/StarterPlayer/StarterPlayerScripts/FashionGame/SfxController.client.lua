--!strict
-- Sound effects for small actions everywhere, and the background ambience
-- (user 2026-10-30: "a sound for every feature and every small action").
-- Ids: Shared/SoundConfig. List: docs/04_ART/SOUNDS.md §3.
--   - any button on screen: a soft click (not the piano keys, not the shop
--     counter menu, where only the till's ding plays)
--   - a Robux purchase that goes through: a short chime
--   - anyone sitting down: a cushion; anyone's clothes changing: a rustle
--   - the own character jumping far at once (🏠, bus): a sweep; after a
--     subway trip only the first seconds of a train
--   - ambience by where the camera is: waves near the sea, birds in the
--     parks and the hanok village, and a soft street hum everywhere else (off
--     in the club, which has its own music)
-- (user 2026-10-30 (2): no prompt pop, no window whoosh, no coin sounds, no
-- indoor crowd; waves 70 % quieter, birds and street at half)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SoundConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("SoundConfig"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local function asset(id: number): string return "rbxassetid://" .. id end

--------------------------------------------------
-- buttons
--------------------------------------------------
local NO_CLICK_GUIS = { PianoKeyboard = true, SnackGui = true } -- (the keys play notes; the counter has its till ding)
local hooked: {[Instance]: boolean} = setmetatable({}, { __mode = "k" }) :: any
local BUTTON_CLICKS = false -- (no click on buttons, user 2026-10-30)
local function hookButton(b: Instance)
	if not BUTTON_CLICKS then return end
	if hooked[b] or not b:IsA("GuiButton") then return end
	local screen = b:FindFirstAncestorWhichIsA("LayerCollector")
	if screen and NO_CLICK_GUIS[screen.Name] then return end
	if b:GetAttribute("NoClickSound") then return end
	hooked[b] = true
	b.Activated:Connect(function() Sfx.play("click") end)
end
for _, d in ipairs(playerGui:GetDescendants()) do hookButton(d) end
playerGui.DescendantAdded:Connect(function(d)
	-- a new key is parented before its gui has its name: wait one frame
	if d:IsA("GuiButton") then task.defer(hookButton, d) end
end)

--------------------------------------------------
-- purchases
--------------------------------------------------
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _id: number, bought: boolean)
	if bought and userId == player.UserId then Sfx.play("success") end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who: Player, _id: number, bought: boolean)
	if bought and who == player then Sfx.play("success") end
end)

--------------------------------------------------
-- sitting and clothes, for every character (3D, heard nearby)
--------------------------------------------------
local function oneShot(parent: Instance, id: number, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = asset(id)
	s.Volume = volume
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 40
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 5)
end

local CLOTHES = { Accessory = true, Shirt = true, Pants = true, ShirtGraphic = true }
local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root then return end
	humanoid.Seated:Connect(function(active: boolean)
		if active then oneShot(root, SoundConfig.Body.sit, 0.5) end
	end)
	-- the outfit loads right after spawning: only changes after that count
	local quietUntil = os.clock() + 4
	local lastRustle = 0
	character.ChildAdded:Connect(function(child)
		if not CLOTHES[child.ClassName] then return end
		local now = os.clock()
		if now < quietUntil or now - lastRustle < 0.8 then return end
		lastRustle = now
		oneShot(root, SoundConfig.Body.outfit, 0.6)
	end)
end
local function watchPlayer(p: Player)
	if p.Character then task.spawn(watchCharacter, p.Character) end
	p.CharacterAdded:Connect(watchCharacter)
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

--------------------------------------------------
-- far jumps of the own character
--------------------------------------------------
local subwayClip = Instance.new("Sound")
subwayClip.Name = "SubwayArrive"
subwayClip.SoundId = asset(SoundConfig.Subway)
subwayClip.Parent = SoundService

local function nearSubway(pos: Vector3): boolean
	for _, exit in ipairs(CollectionService:GetTagged("SubwayExit")) do
		if exit:IsDescendantOf(workspace) then
			local at = if exit:IsA("BasePart") then exit.Position elseif exit:IsA("Model") then exit:GetPivot().Position else nil
			if at and (at - pos).Magnitude < 30 then return true end
		end
	end
	return false
end

local function playSubway()
	subwayClip.Volume = 0.5
	subwayClip.TimePosition = 0
	subwayClip:Play()
	task.delay(3, function()
		for i = 1, 10 do
			subwayClip.Volume = 0.5 * (1 - i / 10)
			task.wait(0.1)
		end
		subwayClip:Stop()
	end)
end

local lastPos: Vector3? = nil
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then lastPos = nil return end
	local pos = root.Position
	if lastPos and (pos - lastPos).Magnitude > 30 then
		local quietAt = player:GetAttribute("QuietJumpAt") -- (the 🏠 button: no sound, user 2026-10-30)
		if nearSubway(lastPos) then playSubway()
		elseif not (typeof(quietAt) == "number" and os.clock() - quietAt < 1.5) then Sfx.play("teleport") end
	end
	lastPos = pos
end)

--------------------------------------------------
-- ambience
--------------------------------------------------
-- boxes are x0, x1, z0, z1 in studs (map v8, 2026-10-30)
type Box = { number }
local SHORE_X = -280 -- sand meets the sea along this line, the sea is west
local BIRD_BOXES: {Box} = {
	{ -150, -46, -229, -47 }, -- pocket park
	{ -135, -53, -496, -254 }, -- park playground
	{ -15, 345, 21, 423 }, -- 광화문 and the hanok village
}
local CLUB_BOX: Box = { 29, 193, -289, -131 }

-- 1 inside the box, down to 0 at `fade` studs outside it
local function weight(box: Box, pos: Vector3, fade: number): number
	local dx = math.max(box[1] - pos.X, 0, pos.X - box[2])
	local dz = math.max(box[3] - pos.Z, 0, pos.Z - box[4])
	return math.clamp(1 - math.sqrt(dx * dx + dz * dz) / fade, 0, 1)
end
local function most(boxes: {Box}, pos: Vector3, fade: number): number
	local w = 0
	for _, b in ipairs(boxes) do w = math.max(w, weight(b, pos, fade)) end
	return w
end

local folder = Instance.new("Folder")
folder.Name = "FashionAmbience"
folder.Parent = SoundService
local loops: {[string]: Sound} = {}
for name, id in pairs(SoundConfig.Ambience :: {[string]: number}) do
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = asset(id)
	s.Looped = true
	s.Volume = 0
	s.Parent = folder
	loops[name] = s
end

local MAX = { waves = 0.0825, birds = 0.175, city = 0.09 }
local current = { waves = 0, birds = 0, city = 0 }
local nextAt = 0
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local now = os.clock()
	if now < nextAt then return end
	nextAt = now + 0.2
	local pos = camera.CFrame.Position
	local inClub = weight(CLUB_BOX, pos, 1) > 0 and pos.Y < 120
	local waves = math.clamp(1 - math.max(0, pos.X - SHORE_X) / 220, 0, 1)
	local birds = most(BIRD_BOXES, pos, 50)
	local target = {
		waves = waves,
		birds = birds,
		city = if inClub then 0 else (1 - waves) * (1 - 0.5 * birds),
	}
	for name, s in pairs(loops) do
		local goal = (target :: any)[name] * (MAX :: any)[name]
		local v = (current :: any)[name]
		v += (goal - v) * 0.25 -- ease over about a second
		;(current :: any)[name] = v
		s.Volume = v
		if v > 0.005 and not s.IsPlaying then s:Play() elseif v <= 0.005 and s.IsPlaying then s:Pause() end
	end
end)

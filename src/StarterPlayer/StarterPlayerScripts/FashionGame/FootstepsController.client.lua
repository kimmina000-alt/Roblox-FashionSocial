--!strict
-- Footsteps by floor material (user 2026-10-27, replaces the sand-only
-- SandStepsController of 2026-10-26). Roblox's own footstep (RbxCharacterSounds
-- "Running") is one plastic loop for every floor, sped up and slowed down
-- with the walk speed, which is why walking and running sounded odd: it is
-- muted, and every character near the camera makes one step sound per stride
-- instead, picked by the floor under it: grass rustles on grass and ground,
-- sand, wood on decks and stairs, hard soles on stone, tiles, asphalt and the
-- rest. Walking (16, or slower with the phone stick half tilted) = soft
-- steps, running (SprintController, 26) = heavier, quicker steps. Landing from a jump plays a firmer step. Jumping,
-- falling, climbing and swimming keep Roblox's own sounds.
-- Sound list: docs/04_ART/SOUNDS.md.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- several takes per surface, picked in turn so the steps do not repeat
-- (user 2026-10-29: one step sound for every floor except sand and water,
-- 132221529613537; sand keeps its own)
local SETS: {[string]: { ids: {string}, volume: number }} = {
	sand = { volume = 0.55, ids = { "rbxassetid://98912102275037" } }, -- "Sand Footstep" (Creator Store)
	ground = { volume = 0.5, ids = { "rbxassetid://132221529613537" } }, -- the user's footstep
}
local SURFACE: {[Enum.Material]: string} = {
	[Enum.Material.Sand] = "sand",
}local NEAR = 60
local STRIDE = 5.2 -- studs a step (full speed 16 → about 3 steps a second)
local RUN_SPEED = 20 -- at or above this the steps are a run (SprintController: walk 16, run 26)

type Walker = { nextAt: number, turn: number, sounds: {[string]: Sound}, running: Sound?, wasAir: boolean }
local walkers: {[Model]: Walker} = {}

local function soundFor(w: Walker, root: BasePart, key: string): Sound
	local s = w.sounds[key]
	if s and s.Parent == root then return s end
	local made = Instance.new("Sound")
	made.Name = "Step_" .. key
	made.RollOffMaxDistance = 45
	made.RollOffMinDistance = 6
	made.Parent = root
	w.sounds[key] = made
	return made
end

local function step(w: Walker, root: BasePart, surface: string, loud: number)
	local set = SETS[surface]
	w.turn += 1
	local id = set.ids[(w.turn - 1) % #set.ids + 1]
	-- at least two sound objects a surface, so a step never cuts off the one before
	local s = soundFor(w, root, surface .. ((w.turn - 1) % math.max(#set.ids, 2) + 1))
	if s.SoundId ~= id then s.SoundId = id end
	s.Volume = set.volume * loud
	s.PlaybackSpeed = 0.92 + math.random() * 0.16
	s.TimePosition = 0
	s:Play()
end

RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not humanoid or not root or not root:IsA("BasePart") then continue end
		local w = walkers[character]
		if not w then
			w = { nextAt = 0, turn = math.random(1, 4), sounds = {}, wasAir = false }
			walkers[character] = w
			character.Destroying:Connect(function() walkers[character] = nil end)
		end
		-- Roblox's one-for-all footstep loop stays silent
		local running = w.running or root:FindFirstChild("Running")
		if running and running:IsA("Sound") then
			w.running = running
			if running.Volume ~= 0 then running.Volume = 0 end
		end
		if (root.Position - camera.CFrame.Position).Magnitude > NEAR then continue end
		local floor = humanoid.FloorMaterial
		local inAir = floor == Enum.Material.Air
		local surface = SURFACE[floor] or "ground"
		-- landing: one firm step on whatever is underneath
		if w.wasAir and not inAir and humanoid:GetState() ~= Enum.HumanoidStateType.Swimming and floor ~= Enum.Material.Water then
			step(w, root, surface, 1.5)
			w.nextAt = now + 0.25
		end
		w.wasAir = inAir
		if inAir or floor == Enum.Material.Water then continue end
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed < 2 or humanoid:GetState() ~= Enum.HumanoidStateType.Running then continue end
		if now >= w.nextAt then
			local run = speed >= RUN_SPEED
			w.nextAt = now + math.clamp(STRIDE / speed, 0.22, 0.65)
			step(w, root, surface, if run then 1.15 else 0.75)
		end
	end
end)

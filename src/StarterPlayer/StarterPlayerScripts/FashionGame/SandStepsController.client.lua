--!strict
-- Footsteps in the sand (user 2026-10-26): anyone walking or running on Sand
-- (the beach terrain and sand parts) makes a soft sand step at each stride,
-- faster when running, instead of the default footstep sound. Each client
-- plays the steps of the characters near its camera. Sound list: docs/04_ART/SOUNDS.md.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SAND_STEP = "rbxassetid://98912102275037" -- "Sand Footstep" (Creator Store, temporary pick)
local NEAR = 60
local STRIDE = 5.2 -- studs a step (walk 16 → about 3 steps a second)

type Walker = { nextAt: number, sound: Sound?, running: Sound?, runningVolume: number? }
local walkers: {[Model]: Walker} = {}

local function stepSound(root: BasePart): Sound
	local s = Instance.new("Sound")
	s.Name = "SandStep"
	s.SoundId = SAND_STEP
	s.Volume = 0.55
	s.RollOffMaxDistance = 45
	s.RollOffMinDistance = 6
	s.Parent = root
	return s
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
			w = { nextAt = 0 }
			walkers[character] = w
			character.Destroying:Connect(function() walkers[character] = nil end)
		end
		local near = (root.Position - camera.CFrame.Position).Magnitude < NEAR
		local onSand = near and humanoid.FloorMaterial == Enum.Material.Sand
		-- the default footstep sound (RbxCharacterSounds "Running") is muted on sand
		local running = w.running or root:FindFirstChild("Running")
		if running and running:IsA("Sound") then
			w.running = running
			if onSand then
				if not w.runningVolume then w.runningVolume = running.Volume end
				running.Volume = 0
			elseif w.runningVolume then
				running.Volume = w.runningVolume
				w.runningVolume = nil
			end
		end
		if not onSand then continue end
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed < 2 or humanoid:GetState() ~= Enum.HumanoidStateType.Running then continue end
		if now >= w.nextAt then
			w.nextAt = now + math.clamp(STRIDE / speed, 0.18, 0.6)
			local sound = w.sound
			if not sound or sound.Parent ~= root then
				sound = stepSound(root)
				w.sound = sound
			end
			sound.PlaybackSpeed = 0.9 + math.random() * 0.2
			sound.TimePosition = 0
			sound:Play()
		end
	end
end)

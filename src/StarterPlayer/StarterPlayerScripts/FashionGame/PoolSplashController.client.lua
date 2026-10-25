--!strict
-- Splashing in the cafe's 물멍 channel (user 2026-10-25): anyone landing a
-- jump in it makes a big splash, running through it makes small splashy
-- steps. The water area is an invisible part tagged "SplashZone". Each
-- client plays the sounds for every character it sees (3D, at the feet).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local SPLASH_ID = "rbxassetid://9117940837" -- "Puddle Impact Big Puddle Splash Footsteps 6" (Pro Sound Effects)
local STEP_ID = "rbxassetid://9119293555" -- "Small Splash Shallow Water Fountain Pool 1" (Pro Sound Effects)
local STEP_EVERY = 0.32

local function inZone(position: Vector3): boolean
	for _, zone in ipairs(CollectionService:GetTagged("SplashZone")) do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(position)
			local h = zone.Size / 2
			if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then return true end
		end
	end
	return false
end

local function play(id: string, at: BasePart, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = 0.9 + math.random() * 0.25
	sound.RollOffMaxDistance = 60
	sound.Parent = at
	sound:Play()
	Debris:AddItem(sound, 3)
end

type Track = { wasAir: boolean, lastStep: number }
local tracks: { [Humanoid]: Track } = {}

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.05 then return end
	acc = 0
	local now = os.clock()
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") then
			local track = tracks[humanoid]
			if not track then
				track = { wasAir = false, lastStep = 0 }
				tracks[humanoid] = track
				humanoid.Destroying:Connect(function() tracks[humanoid] = nil end)
			end
			local state = humanoid:GetState()
			-- other players' humanoid states do not reach this client: their
			-- vertical speed shows a jump (2P test 2026-10-25)
			local air = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
				or math.abs(root.AssemblyLinearVelocity.Y) > 4
			if inZone(root.Position) then
				if track.wasAir and not air then
					play(SPLASH_ID, root, 0.9)
					track.lastStep = now
				elseif not air and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 4 and now - track.lastStep > STEP_EVERY then
					play(STEP_ID, root, 0.45)
					track.lastStep = now
				end
			end
			track.wasAir = air
		end
	end
end)

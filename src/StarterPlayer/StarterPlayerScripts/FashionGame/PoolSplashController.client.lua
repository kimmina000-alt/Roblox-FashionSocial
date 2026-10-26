--!strict
-- Splashing in the cafe's 물멍 channel (user 2026-10-25): anyone landing a
-- jump in it makes a big splash, running through it makes small splashy
-- steps. The water area is an invisible part tagged "SplashZone". The beach
-- 세족장 steps (tag "FootWashZone", user 2026-10-26) make a foot-washing
-- swish while someone walks on them. Each client plays the sounds for every
-- character it sees (3D, at the feet).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local SPLASH_ID = "rbxassetid://9117940837" -- "Puddle Impact Big Puddle Splash Footsteps 6" (Pro Sound Effects)
local STEP_ID = "rbxassetid://9119293555" -- "Small Splash Shallow Water Fountain Pool 1" (Pro Sound Effects)
local WASH_ID = "rbxassetid://9117941569" -- "Puddle Impact Big Puddle Splash Footsteps 12" (Pro Sound Effects)
local STEP_EVERY = 0.32
local WASH_EVERY = 0.55

-- (zones are looked up every time: with streaming they come and go)
local function inZone(tag: string, position: Vector3): boolean
	for _, zone in ipairs(CollectionService:GetTagged(tag)) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(workspace) then
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
			local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 4
			if inZone("SplashZone", root.Position) then
				if track.wasAir and not air then
					play(SPLASH_ID, root, 0.9)
					track.lastStep = now
				elseif not air and moving and now - track.lastStep > STEP_EVERY then
					play(STEP_ID, root, 0.45)
					track.lastStep = now
				end
			elseif inZone("FootWashZone", root.Position) then
				if not air and (moving or track.wasAir) and now - track.lastStep > WASH_EVERY then
					play(WASH_ID, root, 0.5)
					track.lastStep = now
				end
			end
			track.wasAir = air
		end
	end
end)

--!strict
-- Staff NPCs that walk about (D-1055, user 2026-11-09: "불꽃 판매원이랑 바텐더도
-- 안내원처럼 주변 배회하는 것처럼 만들어 줘"), the way the guide does
-- (GuideService): a random spot in their box, a few seconds' rest, again; anyone
-- close makes them stop and turn to that player (their order prompt is on them).
-- The box is in the space of the part they belong to (DrinkService's
-- BartenderSpot), so it follows the club if the map moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuideConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("GuideConfig"))

local NpcWander = {}

local STOP_DISTANCE = 7 -- studs: a player this close, the NPC stays and looks at them

local function walkTrack(humanoid: Humanoid): AnimationTrack?
	local id = GuideConfig.Npc.walkAnimation
	if not id then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(id)
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok or not track then return nil end
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	return track
end

-- box: { min, max } in base's space (Y ignored); speed: walk speed
function NpcWander.run(model: Model, humanoid: Humanoid, root: BasePart, base: BasePart, box: { min: Vector3, max: Vector3, speed: number? })
	humanoid.WalkSpeed = box.speed or 5
	root.Anchored = false
	pcall(function() root:SetNetworkOwner(nil) end)
	local walk = walkTrack(humanoid)
	humanoid.Running:Connect(function(speed)
		if not walk then return end
		if speed > 0.5 and not walk.IsPlaying then walk:Play(0.2) elseif speed <= 0.5 and walk.IsPlaying then walk:Stop(0.2) end
	end)
	local random = Random.new()
	local lo = Vector3.new(math.min(box.min.X, box.max.X), 0, math.min(box.min.Z, box.max.Z))
	local hi = Vector3.new(math.max(box.min.X, box.max.X), 0, math.max(box.min.Z, box.max.Z))
	local function world(x: number, z: number): Vector3
		local p = base.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
		return Vector3.new(p.X, root.Position.Y, p.Z)
	end
	local function inside(p: Vector3): Vector3
		local l = base.CFrame:PointToObjectSpace(p)
		return world(math.clamp(l.X, lo.X, hi.X), math.clamp(l.Z, lo.Z, hi.Z))
	end
	local function nearest(): Vector3?
		local best, bestDistance = nil, STOP_DISTANCE
		for _, player in ipairs(Players:GetPlayers()) do
			local other = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if other then
				local d = (other.Position - root.Position).Magnitude
				if d < bestDistance then best, bestDistance = other.Position, d end
			end
		end
		return best
	end
	-- (start inside the box)
	humanoid:MoveTo(inside(root.Position))
	while model.Parent do
		local someone = nearest()
		if someone then
			humanoid:MoveTo(root.Position)
			local flat = Vector3.new(someone.X, root.Position.Y, someone.Z)
			if (flat - root.Position).Magnitude > 0.5 then
				root.CFrame = CFrame.lookAt(root.Position, flat)
			end
			task.wait(0.5)
		else
			local goal = world(random:NextNumber(lo.X, hi.X), random:NextNumber(lo.Z, hi.Z))
			humanoid:MoveTo(goal)
			local started = os.clock()
			while model.Parent and os.clock() - started < 8 do
				if (Vector3.new(goal.X, root.Position.Y, goal.Z) - root.Position).Magnitude < 1.5 or nearest() then break end
				task.wait(0.25)
			end
			humanoid:MoveTo(root.Position)
			-- (pushed out by a player: back into the box)
			local back = inside(root.Position)
			if (back - root.Position).Magnitude > 0.5 then humanoid:MoveTo(back) end
			local rest = os.clock() + random:NextNumber(2, 5)
			while model.Parent and os.clock() < rest and not nearest() do task.wait(0.25) end
		end
	end
end

return NpcWander

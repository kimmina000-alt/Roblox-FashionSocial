--!strict
-- (D-1421, player feedback "밤에 무섭다" → docs/04_ART/NIGHT_SEOUL.md option 5, user: "4랑 5도 적용")
-- People on the streets at night: from 19:00 to 05:00 (the game clock) a few passers-by walk up
-- and down the main sidewalks, stop for a moment now and then and turn back at the ends. They
-- wear the catalog's recommended Marketplace looks (RecommendedLooks, their outfits), have no
-- name tag and nothing to click; at dawn they go. Server NPCs (like the cafe customers), in
-- Workspace.NightWalkers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared")
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))
local RecommendedLooks = require(Shared:WaitForChild("RecommendedLooks"))
local GuideConfig = require(Shared:WaitForChild("GuideConfig"))

local NightWalkerService = {}

local NIGHT_FROM, NIGHT_TO = 19, 5
-- the sidewalks' middle lines (ground top 0.6): a walker goes from a to b and back
local ROUTES = {
	{ a = Vector3.new(-150, 1, -36), b = Vector3.new(-54, 1, -36) },
	{ a = Vector3.new(-150, 1, 36), b = Vector3.new(-60, 1, 36) },
	{ a = Vector3.new(60, 1, -36), b = Vector3.new(300, 1, -36) },
	{ a = Vector3.new(60, 1, 36), b = Vector3.new(300, 1, 36) },
	{ a = Vector3.new(36, 1, -80), b = Vector3.new(36, 1, -300) },
	{ a = Vector3.new(-36, 1, 60), b = Vector3.new(-36, 1, 300) },
	{ a = Vector3.new(60, 1, -122), b = Vector3.new(185, 1, -122) },
	{ a = Vector3.new(-40, 1, -60), b = Vector3.new(-40, 1, -250) },
}
local WALK_SPEED = 6

local folder: Folder? = nil
local walkers: {Model} = {}
local descriptions: {HumanoidDescription} = {}
local random = Random.new()

local function isNight(): boolean
	local t = DayNightConfig.clockNow()
	return t >= NIGHT_FROM or t < NIGHT_TO
end

local function loadLooks()
	for _, look in ipairs(RecommendedLooks.list) do
		local ok, d = pcall(function() return Players:GetHumanoidDescriptionFromOutfitId(look.outfitId) end)
		if ok and d then table.insert(descriptions, d) end
	end
end

local function walk(model: Model, humanoid: Humanoid, root: BasePart, route: { a: Vector3, b: Vector3 })
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(GuideConfig.Npc.walkAnimation)
	local ok, track = pcall(function() return (animator :: Animator):LoadAnimation(animation) end)
	local walkTrack = if ok then track else nil
	if walkTrack then
		walkTrack.Looped = true
		walkTrack.Priority = Enum.AnimationPriority.Movement
	end
	humanoid.Running:Connect(function(speed)
		if not walkTrack then return end
		if speed > 0.5 and not walkTrack.IsPlaying then walkTrack:Play(0.2)
		elseif speed <= 0.5 and walkTrack.IsPlaying then walkTrack:Stop(0.2) end
	end)
	local toB = random:NextNumber() < 0.5
	while model.Parent and humanoid.Health > 0 do
		local goal = if toB then route.b else route.a
		-- a little to the side each time, so two walkers on one line do not walk in step
		local side = Vector3.new(goal.Z - (if toB then route.a else route.b).Z, 0, -(goal.X - (if toB then route.a else route.b).X))
		if side.Magnitude > 0 then side = side.Unit * random:NextNumber(-3, 3) end
		local target = goal + side
		-- walk in steps of up to 20 studs (MoveTo gives up after 8 s)
		local stuck = 0
		while model.Parent and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude > 3 do
			local here = root.Position
			local dir = Vector3.new(target.X - here.X, 0, target.Z - here.Z)
			local step = if dir.Magnitude > 20 then dir.Unit * 20 else dir
			humanoid:MoveTo(here + step)
			local reached = humanoid.MoveToFinished:Wait()
			if not reached or (root.Position - here).Magnitude < 1 then
				stuck += 1
				if stuck >= 2 then break end -- (something in the way: turn back)
			else
				stuck = 0
			end
			-- now and then a short stop, like looking at a shop
			if random:NextNumber() < 0.08 then task.wait(random:NextNumber(1.5, 4)) end
		end
		toB = not toB
		task.wait(random:NextNumber(0.5, 2.5))
	end
end

local function spawnWalker(index: number)
	if #descriptions == 0 or not folder then return end
	local route = ROUTES[(index - 1) % #ROUTES + 1]
	local description = descriptions[random:NextInteger(1, #descriptions)]
	local ok, npc = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not npc then return end
	npc.Name = "NightWalker" .. index
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then npc:Destroy() return end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = WALK_SPEED
	local at = route.a:Lerp(route.b, random:NextNumber())
	npc:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3, 0), route.b + Vector3.new(0, 3, 0)))
	npc.Parent = folder
	pcall(function() root:SetNetworkOwner(nil) end)
	table.insert(walkers, npc)
	task.spawn(walk, npc, humanoid, root, route)
end

local function clear()
	for _, w in ipairs(walkers) do w:Destroy() end
	table.clear(walkers)
end

function NightWalkerService.Start()
	local f = Instance.new("Folder")
	f.Name = "NightWalkers"
	f.Parent = workspace
	folder = f
	task.spawn(function()
		loadLooks()
		local on = false
		while true do
			local night = isNight()
			if night and not on then
				on = true
				for i = 1, #ROUTES do
					spawnWalker(i)
					task.wait(0.3)
				end
			elseif not night and on then
				on = false
				clear()
			end
			task.wait(10)
		end
	end)
end

return NightWalkerService

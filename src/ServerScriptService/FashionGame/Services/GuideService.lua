--!strict
-- First-visit tutorial, first-time tips and the guide NPC (D-712, D-713;
-- Shared/GuideConfig, client GuideController / GuideTips).
--   * The place tour is shown once: wallet.tutorial is saved when it ends or
--     is skipped. Player attribute TutorialDone (true / false), set once the
--     player's data has loaded.
--   * Tips (catalog, bag, dance, 국밥집, club, cafe, 알바 ...): each shown once;
--     wallet.tips[key] = true. Player attribute TipsSeen = the keys, JSON.
--   * Remote Guide (RemoteFunction): "TutorialDone"; "TipSeen", key;
--     "TipsReset" (the 다시 보기 question: every tip comes back).
--   * The guide NPC walks about a box of the square by the ranking boards
--     (GuideConfig.Npc), stops and turns to anyone close; its prompt
--     "GuidePrompt" opens the 무엇이든 물어보세요 window on the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local GuideConfig = require(Shared:WaitForChild("GuideConfig"))
local NpcLooks = require(Shared:WaitForChild("NpcLooks"))

local GuideService = {}

local data: any = nil -- PlayerDataService

local function loop(humanoid: Humanoid, animationId: number, priority: Enum.AnimationPriority): AnimationTrack?
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(animationId)
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok or not track then return nil end
	track.Looped = true
	track.Priority = priority
	return track
end

-- Walks about the zone: a random spot, a few seconds' rest, again. Anyone
-- within stopDistance makes it stop and face them.
local function wander(model: Model, humanoid: Humanoid, root: BasePart)
	local spec = GuideConfig.Npc
	local walk = loop(humanoid, spec.walkAnimation, Enum.AnimationPriority.Movement)
	humanoid.Running:Connect(function(speed)
		if not walk then return end
		if speed > 0.5 and not walk.IsPlaying then walk:Play(0.2) elseif speed <= 0.5 and walk.IsPlaying then walk:Stop(0.2) end
	end)
	local random = Random.new()
	local function nearest(): Vector3?
		local best, bestDistance = nil, spec.stopDistance
		for _, player in ipairs(Players:GetPlayers()) do
			local other = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if other then
				local d = (other.Position - root.Position).Magnitude
				if d < bestDistance then best, bestDistance = other.Position, d end
			end
		end
		return best
	end
	local function inside(p: Vector3): Vector3
		return Vector3.new(math.clamp(p.X, spec.zoneMin.X, spec.zoneMax.X), p.Y, math.clamp(p.Z, spec.zoneMin.Z, spec.zoneMax.Z))
	end
	while model.Parent do
		local someone = nearest()
		if someone then
			-- stay and look at them
			humanoid:MoveTo(root.Position)
			local flat = Vector3.new(someone.X, root.Position.Y, someone.Z)
			if (flat - root.Position).Magnitude > 0.5 then
				root.CFrame = CFrame.lookAt(root.Position, flat)
			end
			task.wait(0.5)
		else
			local goal = Vector3.new(
				random:NextNumber(spec.zoneMin.X, spec.zoneMax.X), root.Position.Y,
				random:NextNumber(spec.zoneMin.Z, spec.zoneMax.Z))
			humanoid:MoveTo(goal)
			local started = os.clock()
			while model.Parent and os.clock() - started < 8 do
				if (Vector3.new(goal.X, root.Position.Y, goal.Z) - root.Position).Magnitude < 1.5 or nearest() then break end
				task.wait(0.25)
			end
			humanoid:MoveTo(root.Position)
			-- (pushed out by a player: back into the zone)
			local back = inside(root.Position)
			if (back - root.Position).Magnitude > 0.5 then humanoid:MoveTo(back) end
			local rest = os.clock() + random:NextNumber(2.5, 6)
			while model.Parent and os.clock() < rest and not nearest() do task.wait(0.25) end
		end
	end
end

local function spawnGuide()
	local spec = GuideConfig.Npc
	if workspace:FindFirstChild("GuideNPC") then return end
	local description = NpcLooks.describe(spec.look)
	local ok, model = pcall(function()
		if description then
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end
		local plain = Instance.new("HumanoidDescription")
		plain.TorsoColor = Color3.fromRGB(255, 220, 90)
		return Players:CreateHumanoidModelFromDescription(plain, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[GuideService] Could not create the guide:", model)
		return
	end
	model.Name = "GuideNPC"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		model:Destroy()
		return
	end
	humanoid.DisplayName = spec.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.WalkSpeed = spec.walkSpeed
	-- placed anchored, the look applied again in Workspace for its body
	-- scales (as the bar staff, DrinkService), then set free to walk
	root.Anchored = true
	local at = spec.position
	model:PivotTo(CFrame.lookAt(at + Vector3.new(0, 4, 0), at + Vector3.new(0, 4, 0) + spec.facing))
	model.Parent = workspace
	if description then
		pcall(function() humanoid:ApplyDescription(description) end)
		task.wait(0.5)
	end
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, at.Y + 0.1 - (box.Position.Y - size.Y / 2), 0))
	local look = NpcLooks.Looks[spec.look]
	if look and look.pose then
		local idle = loop(humanoid, look.pose, Enum.AnimationPriority.Idle)
		if idle then idle:Play() end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GuidePrompt"
	prompt.ActionText = "무엇이든 물어보세요"
	prompt.ObjectText = spec.name
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	-- (no "?" over the head since D-749, user; it was a 23 px orange disc)
	-- (D-716) a still copy for the tip cards' speaker picture (GuideController /
	-- Coach show it on the left of the card): in ReplicatedStorage, so every
	-- client has it wherever the NPC itself is streamed
	do
		model.Archivable = true
		local copy = model:Clone()
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Sound") then d:Destroy()
			elseif d:IsA("BasePart") then d.Anchored = true end
		end
		copy.Name = "GuidePortrait"
		local old = FashionGame:FindFirstChild("GuidePortrait")
		if old then old:Destroy() end
		copy.Parent = FashionGame
	end
	root.Anchored = false
	pcall(function() root:SetNetworkOwner(nil) end)
	task.spawn(wander, model, humanoid, root)
end

local function publishTips(player: Player, wallet: any)
	local keys = {}
	for key in pairs(wallet.tips or {}) do table.insert(keys, key) end
	player:SetAttribute("TipsSeen", HttpService:JSONEncode(keys))
end

local function tell(player: Player)
	task.spawn(function()
		local wallet = data.Wallet(player) -- (waits for the player's data)
		if not player.Parent then return end
		publishTips(player, wallet)
		player:SetAttribute("TutorialDone", wallet.tutorial == true)
	end)
end

function GuideService.Start(playerData: any)
	data = playerData
	local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, key: any)
		local wallet = data.Wallet(player)
		if action == "TutorialDone" then
			if not wallet.tutorial then
				wallet.tutorial = true
				data.MarkDirty(player)
			end
			player:SetAttribute("TutorialDone", true)
			return true
		elseif action == "TipSeen" then
			if typeof(key) ~= "string" or #key > 24 then return false end
			wallet.tips = wallet.tips or {}
			if not wallet.tips[key] then
				wallet.tips[key] = true
				data.MarkDirty(player)
				publishTips(player, wallet)
			end
			return true
		elseif action == "TipsReset" then
			wallet.tips = {}
			data.MarkDirty(player)
			publishTips(player, wallet)
			return true
		end
		return false
	end
	Players.PlayerAdded:Connect(tell)
	for _, player in ipairs(Players:GetPlayers()) do tell(player) end
	task.spawn(spawnGuide)
end

return GuideService

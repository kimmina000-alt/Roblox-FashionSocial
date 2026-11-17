--!strict
-- 튜브 들고 가기 (D-1576, user 2026-11-17: "해변 종합안내도 옆에 튜브 쌓아 놓고 들고 갈 수 있도록 수정").
-- The heap of rings by the beach map (Workspace.Hongdae_Layout.BeachTubePile, tag "TubePile",
-- tools/graybox/beach_tube_pile_1117.lua) gets a prompt. It gives a ring to carry: a Tool "🛟 튜브"
-- held at the hand (free, one each).
-- (D-1591, user 2026-11-17: "바다에서 타기 / 내려놓기·다시 들기 / 친구에게 주기 / 반납하기 전부 구현";
-- changed by D-1654 / D-1655, user 2026-11-17)
--   * 띄우기: holding the ring, a tap on the sea (TubeCarryController, "PutDown" with the tapped point)
--     puts it on the water there as a floating tube (tag FloatTube, the beach tubes' code: bobbing,
--     paddling, bumping) that anyone rides with "튜브 타기". Only on the water, only by a tap.
--   * no "튜브 들기" on a ring put down (D-1655).
--   * 친구에게 주기: GiveService hands the ring over like the other items (CarryTube).
--   * 반납하기: at the heap, holding a ring, the prompt reads "튜브 반납" (TubeCarryController) and takes it.
-- A player has one ring at most (carried or put down): taking another puts the old one away. Rings put
-- down go when their owner leaves. Not kept across a rejoin.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TubeRentService = {}

local TOOL_NAME = "🛟 튜브"
local YELLOW = Color3.fromRGB(255, 205, 20)

local placed: {[Player]: Model} = {} -- the ring each player put down

local function ringTemplate(): BasePart?
	local art = ServerStorage:FindFirstChild("ArtAssets")
	local ring = art and art:FindFirstChild("TubeMint")
	if not ring then return nil end
	return if ring:IsA("BasePart") then ring else ring:FindFirstChildWhichIsA("BasePart", true)
end

local function owned(player: Player): Tool?
	for _, holder in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") } :: {Instance?}) do
		local tool = holder and holder:FindFirstChild(TOOL_NAME)
		if tool and tool:IsA("Tool") then return tool end
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function cleanRing(part: BasePart): BasePart
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("Script") or c:IsA("LocalScript") or c:IsA("ModuleScript") then c:Destroy() end
	end
	part.Color = YELLOW
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	return part
end

local function makeTool(player: Player): Tool?
	local template = ringTemplate()
	if not template then return nil end
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "튜브 (바다를 누르면 띄워요)"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("CarryTube", true)
	local handle = cleanRing(template:Clone())
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool
	-- held by the rim at the hand
	local r = math.max(handle.Size.X, handle.Size.Z) / 2
	tool.Grip = CFrame.new(0, 0, r - 0.35) * CFrame.Angles(0, 0, math.rad(90))
	-- (a tap is read by TubeCarryController: on a person it is GiveController's, elsewhere "PutDown")
	tool.ManualActivationOnly = true
	return tool
end

local function removePlaced(player: Player)
	local model = placed[player]
	placed[player] = nil
	if model and model.Parent then model:Destroy() end
end

-- give `player` a ring to carry (their put-down one goes away), in the hand
local function give(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	local tool = owned(player)
	if not tool then
		removePlaced(player)
		tool = makeTool(player)
		if not tool then return false end
		tool.Parent = player:FindFirstChildOfClass("Backpack") or character
	end
	humanoid:EquipTool(tool)
	return true
end

-- the water surface under / around `at`, or nil (terrain water only)
local function waterAt(at: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(at + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), params)
	if hit and hit.Material == Enum.Material.Water then return hit.Position.Y end
	return nil
end

-- (D-1655, user 2026-11-17: "튜브 들기 삭제") a ring put down is not picked up again: no "튜브 들기"
-- prompt on it (it stays until its owner takes another ring at the heap or leaves)

-- a ring put down by `player`: floating at `waterY`, or lying at `ground`
local function place(player: Player, at: Vector3, waterY: number?): Model?
	local template = ringTemplate()
	if not template then return nil end
	removePlaced(player)
	local model = Instance.new("Model")
	model.Name = "RentTube"
	local ring = cleanRing(template:Clone())
	ring.Name = "TubeMesh"
	ring.Anchored = true
	ring.CanQuery = true
	model.PrimaryPart = ring
	model:SetAttribute("RentTube", true)
	model:SetAttribute("Owner", player.UserId)
	if waterY then
		local base = Vector3.new(at.X, waterY, at.Z)
		ring.CFrame = CFrame.new(base)
		ring.Parent = model
		model:SetAttribute("Base", base)
		model:SetAttribute("Drift", 0.6)
		model:SetAttribute("Period", 50)
		model:SetAttribute("Phase", math.random() * 6.28)
		CollectionService:AddTag(model, "FloatTube")
	else
		ring.CFrame = CFrame.new(at + Vector3.new(0, ring.Size.Y / 2, 0)) * CFrame.Angles(0, math.random() * 6.28, 0)
		ring.Parent = model
	end
	model.Parent = workspace
	placed[player] = model
	return model
end

-- (D-1654, user 2026-11-17: "튜브 들고 바다 가서 물 클릭해야 튜브 놔지게 수정") the ring goes down only
-- where the holder taps the sea: a tapped point on the water within TAP_REACH studs of them; it floats
-- there (a FloatTube anyone may ride, "튜브 타기"). Nothing happens on sand or anywhere else, and
-- walking into the sea no longer puts it on the water by itself.
local TAP_REACH = 30
local function putDown(player: Player, tool: Tool, at: any): (boolean, string?)
	local root = rootOf(player)
	if not root or owned(player) ~= tool then return false, nil end
	if typeof(at) ~= "Vector3" or (at - root.Position).Magnitude > TAP_REACH then
		return false, "바다(물)를 눌러 튜브를 띄워요."
	end
	local waterY = waterAt(at)
	if not waterY then return false, "바다(물)를 눌러 튜브를 띄워요." end
	if place(player, at, waterY) then
		tool:Destroy()
		return true, nil
	end
	return false, nil
end

local function addPile(pile: Instance)
	if not pile:IsDescendantOf(workspace) then return end
	local at = pile:FindFirstChild("PromptPart")
	if not at or not at:IsA("BasePart") or at:FindFirstChild("TubePrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TubePrompt"
	prompt.ActionText = "튜브 들기" -- (TubeCarryController shows "튜브 반납" to whoever holds one)
	prompt.ObjectText = "튜브"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = at
	prompt.Triggered:Connect(function(player: Player)
		local tool = owned(player)
		if tool then
			tool:Destroy() -- 반납
		else
			give(player)
		end
	end)
end

function TubeRentService.Start()
	for _, pile in ipairs(CollectionService:GetTagged("TubePile")) do addPile(pile) end
	CollectionService:GetInstanceAddedSignal("TubePile"):Connect(function(pile) task.defer(addPile, pile) end)
	local remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("TubeRent")
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = "TubeRent"
		remote.Parent = remotes
	end
	(remote :: RemoteFunction).OnServerInvoke = function(player: Player, action: any, payload: any)
		if action == "PutDown" then
			local tool = owned(player)
			if tool and player.Character and tool.Parent == player.Character then return putDown(player, tool, payload) end
			return false, nil
		end
		return false, nil
	end
	Players.PlayerRemoving:Connect(removePlaced)
end

TubeRentService.owned = owned

return TubeRentService

--!strict
-- 튜브 들고 가기 (D-1576, user 2026-11-17: "해변 종합안내도 옆에 튜브 쌓아 놓고 들고 갈 수 있도록 수정").
-- The heap of rings by the beach map (Workspace.Hongdae_Layout.BeachTubePile, tag "TubePile",
-- tools/graybox/beach_tube_pile_1117.lua) gets a "튜브 들기" prompt. It gives a ring to carry: a Tool
-- "🛟 튜브" held at the side by its rim (free, one each: a second press just puts yours back in the
-- hand). It is the same ring as the heap's, in the heap's yellow.
-- Not kept across a rejoin (BagService keeps its own items only); gone when the holder dies.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local TubeRentService = {}

local TOOL_NAME = "🛟 튜브"
local YELLOW = Color3.fromRGB(255, 205, 20)

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

local function give(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local tool = owned(player)
	if not tool then
		local template = ringTemplate()
		if not template then return end
		tool = Instance.new("Tool")
		tool.Name = TOOL_NAME
		tool.ToolTip = "튜브"
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool:SetAttribute("CarryTube", true)
		local handle = template:Clone()
		for _, c in ipairs(handle:GetChildren()) do
			if c:IsA("Script") or c:IsA("LocalScript") or c:IsA("ModuleScript") then c:Destroy() end
		end
		handle.Name = "Handle"
		handle.Color = YELLOW
		handle.Material = Enum.Material.SmoothPlastic
		handle.Anchored = false
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
		handle.Parent = tool
		-- held by the rim at the hand, the ring standing up beside the leg (its flat side along the body)
		local r = math.max(handle.Size.X, handle.Size.Z) / 2
		tool.Grip = CFrame.new(0, 0, r - 0.35) * CFrame.Angles(0, 0, math.rad(90))
		tool.Parent = player:FindFirstChildOfClass("Backpack") or character
	end
	humanoid:EquipTool(tool)
end

local function addPile(pile: Instance)
	if not pile:IsDescendantOf(workspace) then return end
	local at = pile:FindFirstChild("PromptPart")
	if not at or not at:IsA("BasePart") or at:FindFirstChild("TubePrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TubePrompt"
	prompt.ActionText = "튜브 들기"
	prompt.ObjectText = "튜브"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = at
	prompt.Triggered:Connect(give)
end

function TubeRentService.Start()
	for _, pile in ipairs(CollectionService:GetTagged("TubePile")) do addPile(pile) end
	CollectionService:GetInstanceAddedSignal("TubePile"):Connect(function(pile) task.defer(addPile, pile) end)
end

return TubeRentService

--!strict
-- Cafes and snack stands (SnackConfig, CAFE.md §8): the order → item → sit
-- and eat/drink loop shared by every cafe and the beach ice cream truck.
--
--   * Parts tagged "SnackShop" (attribute Shop) get an "주문하기" prompt (E).
--     Triggering it tells the client (SnackNotify "Open") to show the menu.
--   * Remote Snack (RemoteFunction) "Buy", shopKey, itemKey: checks distance
--     and coins, then gives a hand-held cup / ice cream cone tool.
--   * Clicking (tapping) the tool takes a sip / lick (SnackConfig.Bites).
--     Works standing or sitting at a table (seats are "PromptSeat").

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local SnackConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("SnackConfig"))
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local EconomyConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local SnackService = {}
local economy: any = nil
-- cafe job (CafeJobService): takes orders while staff is on duty, and hears
-- about finished drinks (empty cup on the table)
local orderHandler: ((Player, SnackConfig.Shop, SnackConfig.Item) -> (boolean, string?))? = nil
local finishedHandler: ((Model, SnackConfig.Item) -> ())? = nil

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Extra piece fixed to the handle with a Weld (C0 offset; works before the
-- tool is in the world, unlike a WeldConstraint).
local function attach(handle: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = handle.CFrame * offset
	piece.Parent = handle
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.C0 = offset
	weld.Parent = piece
end

local function countSnacks(player: Player): number
	local count = 0
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("Snack") then count += 1 end
			end
		end
	end
	return count
end

local function mouthGrip(character: Model, lift: number): CFrame?
	local head = character:FindFirstChild("Head") :: BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local attachment = hand and hand:FindFirstChild("RightGripAttachment") :: Attachment?
	if not head or not attachment then return nil end
	local target = head.CFrame * CFrame.new(0.2, -0.35 + lift, -0.8) * CFrame.Angles(math.rad(50), 0, 0)
	return target:Inverse() * attachment.WorldCFrame
end

local function bite(tool: Tool, item: SnackConfig.Item)
	-- a cup the cafe staff is carrying to a customer is not theirs to drink
	if tool:GetAttribute("Busy") or tool:GetAttribute("CafeOrder") then return end
	local character = tool.Parent
	if not character or not character:IsA("Model") then return end
	tool:SetAttribute("Busy", true)
	local original = tool.Grip
	local up = mouthGrip(character, if item.kind == "cone" then -0.2 else 0)
	if up then TweenService:Create(tool, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Grip = up }):Play() end
	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("Sip") :: Sound?
	if sound then sound:Play() end
	task.wait(1.4)
	if tool.Parent then TweenService:Create(tool, TweenInfo.new(0.3), { Grip = original }):Play() end
	task.wait(0.3)
	local left = ((tool:GetAttribute("Bites") :: number?) or SnackConfig.Bites) - 1
	tool:SetAttribute("Bites", left)
	-- the drink / scoop gets smaller with every bite
	local fill = handle and handle:FindFirstChild("Fill") :: BasePart?
	if fill and left > 0 then fill.Size *= (0.4 + 0.6 * left / SnackConfig.Bites) / (0.4 + 0.6 * (left + 1) / SnackConfig.Bites) end
	tool:SetAttribute("Busy", nil)
	if left <= 0 then
		if finishedHandler and tool.Parent and tool.Parent:IsA("Model") then
			task.spawn(finishedHandler, tool.Parent :: Model, item)
		end
		tool:Destroy()
	end
end

local function makeTool(item: SnackConfig.Item): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = "클릭(터치)해서 " .. (if item.kind == "cone" then "먹기" else "마시기")
	tool.CanBeDropped = false
	tool:SetAttribute("Snack", item.key)
	tool:SetAttribute("Bites", SnackConfig.Bites)
	if item.kind == "cone" then
		-- waffle cone (pointing down) with a scoop on top
		local handle = part("Handle", Vector3.new(0.45, 0.9, 0.45), Color3.fromRGB(215, 160, 90), Enum.Material.SmoothPlastic)
		handle.Parent = tool
		local scoop = part("Fill", Vector3.new(0.75, 0.75, 0.75), item.color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		attach(handle, scoop, CFrame.new(0, 0.62, 0))
		if item.topping then
			for k = 0, 2 do
				local chip = part("Chip", Vector3.new(0.12, 0.12, 0.12), item.topping)
				attach(handle, chip, CFrame.new(math.cos(k * 2.1) * 0.3, 0.8, math.sin(k * 2.1) * 0.3))
			end
		end
		tool.Grip = CFrame.new(0, -0.1, 0)
	else
		local handle = part("Handle", Vector3.new(0.6, 0.85, 0.6), Color3.fromRGB(250, 250, 255), Enum.Material.Glass)
		handle.Transparency = 0.35
		handle.Parent = tool
		local fill = part("Fill", Vector3.new(0.5, 0.65, 0.5), item.color)
		attach(handle, fill, CFrame.new(0, -0.05, 0))
		local straw = part("Straw", Vector3.new(0.08, 0.7, 0.08), Color3.fromRGB(255, 255, 255))
		attach(handle, straw, CFrame.new(0.1, 0.5, 0) * CFrame.Angles(0, 0, math.rad(-10)))
		local sip = Instance.new("Sound")
		sip.Name = "Sip"
		sip.SoundId = "rbxassetid://" .. tostring(ClubConfig.GulpSoundId)
		sip.Volume = 0.7
		sip.RollOffMaxDistance = 40
		sip.Parent = handle
		tool.Grip = CFrame.new(0, -0.2, 0)
	end
	tool.Activated:Connect(function() bite(tool, item) end)
	return tool
end

local function nearShop(player: Player, shopKey: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end
	for _, shopPart in ipairs(CollectionService:GetTagged("SnackShop")) do
		if shopPart:IsA("BasePart") and shopPart:GetAttribute("Shop") == shopKey
			and (shopPart.Position - root.Position).Magnitude <= SnackConfig.ShopDistance then
			return true
		end
	end
	return false
end

local function buy(player: Player, shopKey: any, itemKey: any): (boolean, string?)
	local shop, item = SnackConfig.find(shopKey, itemKey)
	if not shop or not item then return false, "없는 메뉴예요." end
	if not nearShop(player, shop.key) then return false, "카운터 가까이에서 주문해 주세요." end
	if countSnacks(player) >= SnackConfig.MaxCarried then
		return false, string.format("손에 %d개까지 들 수 있어요. 먼저 드세요!", SnackConfig.MaxCarried)
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, "잠시 후 다시 시도해 주세요." end
	if orderHandler and not item.coins then
		local handled, message = orderHandler(player, shop, item)
		if handled then return true, message end
	end
	local price = item.coins or 0
	if price > 0 then
		if not economy or not economy.Spend(player, price) then
			local balance = if economy then economy.Balance(player) else 0
			return false, string.format("%s이 부족해요 (%d 필요, 지금 %d).", EconomyConfig.CurrencyName, price, balance)
		end
	end
	local tool = makeTool(item)
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	local verb = if item.kind == "cone" then "먹어요" else "마셔요"
	return true, string.format("%s 나왔어요! 클릭(터치)해서 %s. 자리에 앉아서 즐겨도 돼요.", item.name, verb)
end

local function addPrompt(shopPart: Instance)
	if not shopPart:IsA("BasePart") or shopPart:FindFirstChild("SnackPrompt") then return end
	local shop = SnackConfig.Shops[shopPart:GetAttribute("Shop") :: any]
	if not shop then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SnackPrompt"
	prompt.ActionText = if shop.key == "IceCream" then "아이스크림 사기" else "음료 주문하기"
	prompt.ObjectText = shop.title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = shopPart
	prompt.Triggered:Connect(function(player)
		local notify = Remotes:FindFirstChild("SnackNotify") :: RemoteEvent?
		if notify then notify:FireClient(player, "Open", shop.key) end
	end)
end

-- Gives a ready drink / snack (cafe job: the staff hands it over).
function SnackService.Give(player: Player, item: SnackConfig.Item): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return nil end
	local tool = makeTool(item)
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	return tool
end

-- A drink tool for anyone (an NPC customer, the cup the staff carries).
SnackService.MakeTool = function(item: SnackConfig.Item): Tool return makeTool(item) end

function SnackService.SetOrderHandler(handler: (Player, SnackConfig.Shop, SnackConfig.Item) -> (boolean, string?))
	orderHandler = handler
end

function SnackService.SetFinishedHandler(handler: (Model, SnackConfig.Item) -> ())
	finishedHandler = handler
end

function SnackService.Start(economyService: any)
	economy = economyService
	local remote = Remotes:WaitForChild("Snack") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, shopKey: any, itemKey: any)
		if action == "Buy" then return buy(player, shopKey, itemKey) end
		return false, nil
	end
	for _, shopPart in ipairs(CollectionService:GetTagged("SnackShop")) do addPrompt(shopPart) end
	CollectionService:GetInstanceAddedSignal("SnackShop"):Connect(addPrompt)
end

return SnackService

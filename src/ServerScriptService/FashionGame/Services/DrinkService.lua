--!strict
-- Club drinks (non-alcoholic, D-043): bartender orders, bottles on tables,
-- cups, drinking.
--
-- Flow:
--   1. Bartender (NPC at the part tagged "BartenderSpot") → client opens the
--      menu → free drink: ClubShop "Order"; paid drink: Roblox purchase
--      window → ProcessReceipt → same grant.
--   2. The player receives a bottle tool (max ClubConfig.MaxBottlesCarried).
--   3. At a table (parts tagged "DrinkTable", with Attachments named "Slot"),
--      the "병 놓기" prompt → client asks 모든 사람 / 친구만 / 나만 →
--      ClubShop "Place".
--   4. The placed bottle has "컵에 따르기" (allowed players get a cup tool)
--      and "치우기" (owner only: a bottle with cups left goes back to the
--      owner's inventory with that count). It disappears when empty, after
--      ClubConfig.BottleLifetime, or when the owner leaves.
--   5. Using the cup plays the drink motion and a gulp sound, then the cup
--      is gone.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local MonetizationService = require(script.Parent.MonetizationService)
local EconomyService = require(script.Parent.EconomyService)
local DrinkBucket = require(script.Parent.DrinkBucket)

local DrinkService = {}

local notify: RemoteEvent? = nil
local friendCache: {[string]: {value: boolean, at: number}} = {}

local function toast(player: Player, message: string)
	if notify then notify:FireClient(player, "Toast", message) end
end

local function countTools(player: Player, attribute: string): number
	local count = 0
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute(attribute) ~= nil then
					count += 1
				end
			end
		end
	end
	return count
end

local function makeHandle(size: Vector3, color: Color3, transparency: number?): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = Enum.Material.Glass
	handle.Transparency = transparency or 0.15
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	return handle
end

--------------------------------------------------
-- Bottles (carried)
--------------------------------------------------

-- Name and colour of a drink with its flavour / can colour (variants).
local function drinkLook(drink: ClubConfig.Drink, variantKey: any): (string, Color3, string?)
	local variant = ClubConfig.findVariant(drink, variantKey)
	if variant then
		return drink.name .. " · " .. variant.name, variant.color, variant.key
	end
	return drink.name, drink.color, nil
end

local function isVip(player: Player): boolean
	return MonetizationService.HasPass(player, "VIP")
end

-- `servings` = cups left (a bottle taken back from a table keeps its count).
local function giveBottle(player: Player, drinkKey: string, servings: number?, variantKey: any?): (boolean, string?)
	local drink = ClubConfig.findDrink(drinkKey)
	if not drink then return false, "없는 음료입니다." end
	if countTools(player, "Bottle") >= ClubConfig.MaxBottlesCarried then
		return false, string.format("병은 %d개까지 들 수 있어요. 테이블에 먼저 놓아 주세요.", ClubConfig.MaxBottlesCarried)
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, "잠시 후 다시 시도하세요." end
	local name, color, variant = drinkLook(drink, variantKey)
	local cups = math.clamp(servings or ClubConfig.BottleServings, 1, ClubConfig.BottleServings)
	local tool = Instance.new("Tool")
	tool.Name = if cups < ClubConfig.BottleServings
		then string.format("병 · %s (%d잔)", name, cups)
		else "병 · " .. name
	tool.ToolTip = string.format("%d잔 남음 · 테이블의 '병 놓기'로 올려놓으세요", cups)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Bottle", drink.key)
	tool:SetAttribute("Variant", variant)
	tool:SetAttribute("Servings", cups)
	local handle = makeHandle(Vector3.new(0.7, 1.8, 0.7), color)
	handle.Parent = tool
	tool.Grip = CFrame.new(0, -0.3, 0)
	tool.Parent = backpack
	return true, name .. " 병을 받았어요! 테이블에 놓고 함께 마셔요."
end
DrinkService.GiveBottle = giveBottle

--------------------------------------------------
-- Cups
--------------------------------------------------

-- Brings the cup up to the mouth and tilts it, then back. Avatars with the
-- new joint system have read-only shoulder joints (QA 2026-10-20), so the
-- motion moves the tool grip instead of the arm. Replace with a published
-- drink animation later (DJ/Club doc, open item).
local function mouthGrip(tool: Tool, character: Model): CFrame?
	local head = character:FindFirstChild("Head") :: BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local attachment = hand and hand:FindFirstChild("RightGripAttachment") :: Attachment?
	if not head or not attachment then return nil end
	local target = head.CFrame * CFrame.new(0.25, -0.35, -0.75) * CFrame.Angles(math.rad(55), 0, 0)
	return target:Inverse() * attachment.WorldCFrame
end

local function drinkFrom(tool: Tool)
	if tool:GetAttribute("Drinking") then return end
	local character = tool.Parent
	if not character or not character:IsA("Model") then return end
	tool:SetAttribute("Drinking", true)
	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("Gulp") :: Sound?
	local original = tool.Grip
	local up = mouthGrip(tool, character)
	if up then
		TweenService:Create(tool, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Grip = up }):Play()
	end
	if sound then sound:Play() end
	task.wait(ClubConfig.DrinkSeconds)
	if tool.Parent then
		TweenService:Create(tool, TweenInfo.new(0.3), { Grip = original }):Play()
	end
	task.wait(0.3)
	tool:Destroy()
end

local function giveCup(player: Player, drinkKey: string, variantKey: any?): (boolean, string?)
	local drink = ClubConfig.findDrink(drinkKey)
	if not drink then return false, nil end
	if countTools(player, "Cup") >= ClubConfig.MaxCupsCarried then
		return false, "컵을 먼저 마셔 주세요."
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, nil end
	local name, color = drinkLook(drink, variantKey)
	local tool = Instance.new("Tool")
	tool.Name = "컵 · " .. name
	tool.ToolTip = "클릭(터치)해서 마시기"
	tool.CanBeDropped = false
	tool:SetAttribute("Cup", drink.key)
	local handle = makeHandle(Vector3.new(0.6, 0.8, 0.6), color, 0.05)
	handle.Parent = tool
	local gulp = Instance.new("Sound")
	gulp.Name = "Gulp"
	gulp.SoundId = "rbxassetid://" .. tostring(ClubConfig.GulpSoundId)
	gulp.Volume = 0.8
	gulp.RollOffMaxDistance = 40
	gulp.Parent = handle
	tool.Activated:Connect(function()
		drinkFrom(tool)
	end)
	tool.Parent = backpack
	-- Equip right away so one more tap drinks it.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	return true, nil
end

DrinkService.GiveCup = giveCup -- (SparkleService: cans from a sparkler bucket)

--------------------------------------------------
-- Tables and placed bottles
--------------------------------------------------

local function isFriend(player: Player, ownerId: number): boolean
	local key = player.UserId .. ":" .. ownerId
	local cached = friendCache[key]
	if cached and os.clock() - cached.at < 300 then return cached.value end
	local ok, value = pcall(function()
		return player:IsFriendsWith(ownerId)
	end)
	local result = ok and value == true
	friendCache[key] = { value = result, at = os.clock() }
	return result
end

local function mayPour(player: Player, bottle: BasePart): boolean
	local owner = bottle:GetAttribute("Owner")
	if owner == player.UserId then return true end
	local visibility = bottle:GetAttribute("Visibility")
	if visibility == "all" then return true end
	if visibility == "friends" and typeof(owner) == "number" then
		return isFriend(player, owner)
	end
	return false
end

local function visibilityName(key: any): string
	for _, entry in ipairs(ClubConfig.Visibility) do
		if entry.key == key then return entry.name end
	end
	return "?"
end

local function refreshBottleLabel(bottle: BasePart)
	local info = bottle:FindFirstChild("Info")
	local label = info and info:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = string.format("%s · %s님 · %s · %d잔",
			tostring(bottle:GetAttribute("DrinkName")), tostring(bottle:GetAttribute("OwnerName")),
			visibilityName(bottle:GetAttribute("Visibility")), bottle:GetAttribute("Servings") or 0)
	end
end

-- Sign above a table with the Roblox ID (@username) of whoever put a bought
-- bottle on it (user, 2026-10-22). Gone when the table has no bottles.
local function refreshTableSign(tablePart: Instance)
	if not tablePart:IsA("BasePart") then return end
	local names = {}
	for _, child in ipairs(tablePart:GetChildren()) do
		local owner = child:IsA("Attachment") and child:GetAttribute("OwnerName")
		if typeof(owner) == "string" and not table.find(names, owner) then table.insert(names, owner) end
	end
	-- VIP booth tables (user 2026-10-25): the owner's nickname glows on the
	-- neon VIP sign on the wall above the booth (ObjectValue "WallSign" → its
	-- name label), empty when nobody has a bottle there; no floating sign
	local wallSign = tablePart:FindFirstChild("WallSign")
	if wallSign and wallSign:IsA("ObjectValue") then
		local label = wallSign.Value
		if label and label:IsA("TextLabel") then
			local shown = {}
			for _, name in ipairs(names) do table.insert(shown, "@" .. name) end
			label.Text = table.concat(shown, " · ")
			-- the red glow copy of the name (graybox "GlowGui" on the same board) follows it
			local glowGui = label.Parent and label.Parent.Parent and label.Parent.Parent:FindFirstChild("GlowGui")
			local glow = glowGui and glowGui:FindFirstChild("Glow")
			if glow and glow:IsA("TextLabel") then glow.Text = label.Text end
		end
		return
	end
	local sign = tablePart:FindFirstChild("TableOwnerSign")
	if #names == 0 then
		if sign then sign:Destroy() end
		return
	end
	if not sign then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TableOwnerSign"
		billboard.Size = UDim2.fromOffset(220, 34)
		billboard.StudsOffset = Vector3.new(0, 4.5, 0)
		billboard.MaxDistance = 70
		billboard.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(20, 12, 30)
		label.BackgroundTransparency = 0.25
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = label
		billboard.Parent = tablePart
		sign = billboard
	end
	local shown = {}
	for _, name in ipairs(names) do table.insert(shown, "@" .. name) end
	(sign :: any).Text.Text = "🍾 " .. table.concat(shown, " · ") .. " 테이블"
end

local function removeBottle(bottle: BasePart)
	local slot = bottle:FindFirstChild("SlotRef") :: ObjectValue?
	local tablePart = slot and slot.Value and (slot.Value :: Instance).Parent
	if slot and slot.Value then
		(slot.Value :: Instance):SetAttribute("Occupied", nil);
		(slot.Value :: Instance):SetAttribute("OwnerName", nil)
	end
	bottle:Destroy()
	if tablePart then refreshTableSign(tablePart) end
end

local function freeSlot(tablePart: BasePart): Attachment?
	for _, child in ipairs(tablePart:GetChildren()) do
		if child:IsA("Attachment") and child.Name == "Slot" and not child:GetAttribute("Occupied") then
			return child
		end
	end
	return nil
end

local function placeBottle(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" then return false, "잘못된 요청입니다." end
	local tablePart = payload.table
	local visibility = payload.visibility
	if typeof(tablePart) ~= "Instance" or not tablePart:IsA("BasePart") or not CollectionService:HasTag(tablePart, "DrinkTable") then
		return false, "테이블을 찾을 수 없습니다."
	end
	if visibility ~= "all" and visibility ~= "friends" and visibility ~= "me" then
		return false, "공개 범위를 골라 주세요."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - tablePart.Position).Magnitude > math.max(tablePart.Size.X, tablePart.Size.Z) / 2 + 14 then
		return false, "테이블 가까이 가서 놓아 주세요."
	end
	-- Use the equipped bottle first, otherwise any carried bottle.
	local bottleTool: Tool? = nil
	for _, container in ipairs({ character, player:FindFirstChildOfClass("Backpack") }) do
		if container and not bottleTool then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("Bottle") then
					bottleTool = item
					break
				end
			end
		end
	end
	if not bottleTool then return false, "들고 있는 병이 없어요. 바텐더에게 주문하세요." end
	local slot = freeSlot(tablePart)
	if not slot then return false, "테이블이 가득 찼어요." end
	local drink = ClubConfig.findDrink(bottleTool:GetAttribute("Bottle"))
	if not drink then return false, nil end
	local servings = bottleTool:GetAttribute("Servings")
	servings = if typeof(servings) == "number" then math.clamp(servings, 1, ClubConfig.BottleServings) else ClubConfig.BottleServings
	local variantKey = bottleTool:GetAttribute("Variant")
	local drinkName, drinkColor = drinkLook(drink, variantKey)
	bottleTool:Destroy()
	slot:SetAttribute("Occupied", true)
	slot:SetAttribute("OwnerName", player.Name)
	refreshTableSign(tablePart)

	local bottle = Instance.new("Part")
	bottle.Name = "PlacedBottle"
	bottle.Size = Vector3.new(0.9, 2, 0.9)
	bottle.Color = drinkColor
	bottle.Material = Enum.Material.Glass
	bottle.Transparency = 0.1
	bottle.Anchored = true
	bottle.CanCollide = false
	bottle.CFrame = CFrame.new(slot.WorldPosition + Vector3.new(0, 1, 0))
	bottle:SetAttribute("Owner", player.UserId)
	bottle:SetAttribute("OwnerName", player.DisplayName)
	bottle:SetAttribute("Visibility", visibility)
	bottle:SetAttribute("DrinkKey", drink.key)
	bottle:SetAttribute("Variant", variantKey)
	bottle:SetAttribute("DrinkName", drinkName)
	bottle:SetAttribute("Servings", servings)
	local ref = Instance.new("ObjectValue")
	ref.Name = "SlotRef"
	ref.Value = slot
	ref.Parent = bottle

	-- The look on the table follows the tier (D-323, temporary design until the
	-- bucket art pass): the part above stays as the invisible holder of the
	-- prompts and the label.
	local kind: DrinkBucket.Kind = if isVip(player) then (if drink.key == "golmok" then "golmok" else "vip")
		elseif drink.tier >= 3 then "acrylic"
		elseif drink.tier == 2 then "steel"
		else "bottle"
	local bucket = DrinkBucket.build(kind, { drinkColor }, CFrame.new(slot.WorldPosition))
	if kind == "vip" or kind == "golmok" then
		bucket:ScaleTo(0.6) -- (a table slot is about 1.6 studs wide)
	elseif kind ~= "bottle" then
		bucket:ScaleTo(0.8)
	end
	bucket:PivotTo(bucket:GetPivot() + (slot.WorldPosition.Y - bucket:GetBoundingBox().Position.Y + bucket:GetExtentsSize().Y / 2) * Vector3.yAxis)
	bucket.Parent = bottle
	bottle.Transparency = 1

	local info = Instance.new("BillboardGui")
	info.Name = "Info"
	info.Size = UDim2.fromOffset(170, 22)
	-- labels of bottles on the same table stack instead of covering each other
	-- (2P phone test 2026-10-26)
	local onTable = 0
	for _, other in ipairs(tablePart:GetChildren()) do
		if other.Name == "PlacedBottle" then onTable += 1 end
	end
	info.StudsOffset = Vector3.new(0, 1.8 + onTable * 0.9, 0)
	info.MaxDistance = 30
	info.Parent = bottle
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 0.35
	text.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = info
	refreshBottleLabel(bottle)

	local pour = Instance.new("ProximityPrompt")
	pour.Name = "PourPrompt"
	pour.ActionText = "컵에 따르기"
	pour.ObjectText = drinkName
	pour.MaxActivationDistance = 9
	pour.RequiresLineOfSight = false
	pour.Parent = bottle
	pour.Triggered:Connect(function(who)
		if not bottle.Parent then return end
		if not mayPour(who, bottle) then
			toast(who, string.format("%s님이 놓은 병이에요 (공개: %s).", tostring(bottle:GetAttribute("OwnerName")), visibilityName(bottle:GetAttribute("Visibility"))))
			return
		end
		local ok, message = giveCup(who, drink.key, variantKey)
		if not ok then
			if message then toast(who, message) end
			return
		end
		local left = (bottle:GetAttribute("Servings") or 1) - 1
		bottle:SetAttribute("Servings", left)
		if left <= 0 then
			removeBottle(bottle)
		else
			refreshBottleLabel(bottle)
		end
	end)

	local clear = Instance.new("ProximityPrompt")
	clear.Name = "ClearPrompt"
	clear.ActionText = "치우기"
	clear.ObjectText = "내 병"
	clear.KeyboardKeyCode = Enum.KeyCode.R
	clear.UIOffset = Vector2.new(0, 70)
	clear.MaxActivationDistance = 9
	clear.RequiresLineOfSight = false
	clear.Parent = bottle
	clear.Triggered:Connect(function(who)
		if who.UserId ~= bottle:GetAttribute("Owner") or not bottle.Parent then return end
		-- Cups still left: the bottle goes back to the owner with that count
		-- (user, 2026-10-20). If their hands are full it stays on the table.
		local left = bottle:GetAttribute("Servings") or 0
		if left > 0 then
			local ok, message = giveBottle(who, drink.key, left, variantKey)
			if not ok then
				toast(who, message or "병을 받을 수 없어요.")
				return
			end
			toast(who, string.format("%s 병을 다시 챙겼어요 (%d잔 남음).", drinkName, left))
		end
		removeBottle(bottle)
	end)

	bottle.Parent = tablePart
	task.delay(ClubConfig.BottleLifetime, function()
		if bottle.Parent then removeBottle(bottle) end
	end)
	return true, nil
end

--------------------------------------------------
-- Bartender NPC
--------------------------------------------------

local function spawnBartender(spot: Instance)
	if not spot:IsA("BasePart") or spot:FindFirstChild("Bartender") then return end
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = Color3.fromRGB(234, 184, 146)
		description.TorsoColor = Color3.fromRGB(30, 30, 36)
		description.LeftArmColor = Color3.fromRGB(234, 184, 146)
		description.RightArmColor = Color3.fromRGB(234, 184, 146)
		description.LeftLegColor = Color3.fromRGB(30, 30, 36)
		description.RightLegColor = Color3.fromRGB(30, 30, 36)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[DrinkService] Could not create bartender:", model)
		return
	end
	model.Name = "Bartender"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = "바텐더"
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = true end
	end
	model:PivotTo(spot.CFrame + Vector3.new(0, 3, 0))
	local root = model:FindFirstChild("HumanoidRootPart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BartenderPrompt"
	prompt.ActionText = "음료 주문"
	prompt.ObjectText = "바텐더"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root or model.PrimaryPart
	model.Parent = spot
end

local function addTablePrompt(tablePart: Instance)
	if not tablePart:IsA("BasePart") or tablePart:FindFirstChild("PlacePrompt") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlacePrompt"
	prompt.ActionText = "병 놓기"
	prompt.ObjectText = "테이블"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = math.max(tablePart.Size.X, tablePart.Size.Z) / 2 + 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = tablePart
	-- The client opens the 공개 범위 dialog (it only shows when carrying a bottle).
end

--------------------------------------------------

-- The flavour / can colour a player picked before a Robux purchase; the
-- product handler only gets the player (userId → drink key → variant key).
local pendingVariant: {[number]: {[string]: string}} = {}

-- payload: a drink key, or { drink = key, variant = key }.
local function readOrder(payload: any): (ClubConfig.Drink?, any)
	if typeof(payload) == "table" then
		return ClubConfig.findDrink(payload.drink), payload.variant
	end
	return ClubConfig.findDrink(payload), nil
end

-- Pays a coin price (VIP discount) and hands over the bottle.
local function buyWithCoins(player: Player, drink: ClubConfig.Drink, variantKey: any): (boolean, string?)
	local price = ClubConfig.coinPrice(drink, isVip(player))
	if not price then return false, "코인으로 살 수 없는 음료예요." end
	if EconomyService.Balance(player) < price then
		return false, string.format("코인이 부족해요 (%d 필요, 지금 %d).", price, EconomyService.Balance(player))
	end
	local ok, message = giveBottle(player, drink.key, nil, variantKey)
	if not ok then return false, message end
	EconomyService.Spend(player, price)
	return true, message
end

function DrinkService.Handle(player: Player, action: string, payload: any): (boolean, any)
	if action == "Order" then
		-- tier 1: free, or a few coins
		local drink, variantKey = readOrder(payload)
		if not drink then return false, "없는 음료입니다." end
		if drink.product then
			return false, "유료 음료는 구매 창에서 구매하세요."
		end
		if drink.coins then return buyWithCoins(player, drink, variantKey) end
		return giveBottle(player, drink.key, nil, variantKey)
	elseif action == "OrderCoins" then
		-- tier 2 bought with coins instead of Robux (CLUB_SHOP_PRICING.md §3)
		local drink, variantKey = readOrder(payload)
		if not drink or not drink.coins then return false, "코인으로 살 수 없는 음료예요." end
		return buyWithCoins(player, drink, variantKey)
	elseif action == "SetVariant" then
		-- picked before the Robux window opens
		local drink, variantKey = readOrder(payload)
		local variant = drink and ClubConfig.findVariant(drink, variantKey)
		if not drink or not variant then return false, nil end
		pendingVariant[player.UserId] = pendingVariant[player.UserId] or {}
		pendingVariant[player.UserId][drink.key] = variant.key
		return true, nil
	elseif action == "Place" then
		return placeBottle(player, payload)
	end
	return false, "잘못된 요청입니다."
end

function DrinkService.Start()
	notify = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubNotify") :: RemoteEvent
	local function grant(player: Player, drink: ClubConfig.Drink): (boolean, string?)
		-- (a VIP-only drink bought by someone who lost VIP is still given: it was paid)
		local picked = pendingVariant[player.UserId] and pendingVariant[player.UserId][drink.key]
		local ok, message = giveBottle(player, drink.key, nil, picked)
		if ok then
			toast(player, message or "")
			return true, nil
		end
		-- Hands full: still grant (the purchase went through) by
		-- clearing room is not possible, so tell the player and let
		-- Roblox retry later.
		toast(player, message or "병을 받을 수 없어요.")
		return false, message
	end
	for _, drink in ipairs(ClubConfig.Drinks) do
		for _, key in ipairs({ drink.product, drink.vipProduct }) do
			MonetizationService.RegisterProduct(key, function(player)
				return grant(player, drink)
			end)
		end
	end
	for _, spot in ipairs(CollectionService:GetTagged("BartenderSpot")) do spawnBartender(spot) end
	CollectionService:GetInstanceAddedSignal("BartenderSpot"):Connect(spawnBartender)
	for _, t in ipairs(CollectionService:GetTagged("DrinkTable")) do addTablePrompt(t) end
	CollectionService:GetInstanceAddedSignal("DrinkTable"):Connect(addTablePrompt)
	Players.PlayerRemoving:Connect(function(player)
		pendingVariant[player.UserId] = nil
		for _, t in ipairs(CollectionService:GetTagged("DrinkTable")) do
			for _, child in ipairs(t:GetChildren()) do
				if child.Name == "PlacedBottle" and child:GetAttribute("Owner") == player.UserId then
					removeBottle(child :: BasePart)
				end
			end
		end
	end)
end

return DrinkService

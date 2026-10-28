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
local BottleShapes = require(FashionGame:WaitForChild("Shared"):WaitForChild("BottleShapes"))

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
	tool.Name = string.format("병 · %s (%d/%d)", name, cups, ClubConfig.BottleServings)
	tool.ToolTip = if drink.tier == 1 and not isVip(player)
		then "테이블을 누르면 올려놓기 · 다른 곳을 누르면 병째 마시기"
		else "손에 들고 테이블을 누르면 버킷으로 올라가요"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Bottle", drink.key)
	tool:SetAttribute("Variant", variant)
	tool:SetAttribute("Servings", cups)
	local handle = makeHandle(Vector3.new(0.7, 1.8, 0.7), color)
	handle.Parent = tool
	-- the drink's own bottle shape on the (invisible) handle (BottleShapes, 2026-10-27)
	handle.Transparency = 1
	-- size in the hand per drink (user 2026-10-28 (15)): tier 2 half, 스택 하이드로
	-- half, 스컬 앤 워터 85 %, 파스텔 스플래시 2/3, VIP 골목 공방 110 %
	local handScale = if drink.key == "stack_hydro" then 0.5 elseif drink.key == "skull_water" then 0.85
		elseif drink.key == "pastel_splash" then 2 / 3 elseif drink.key == "golmok" then 1.1 elseif drink.tier == 2 then 0.5 else 1
	local scale = 1.9 / BottleShapes.height(drink.key) * handScale
	BottleShapes.add(tool, handle.CFrame * CFrame.new(0, -0.9, 0), drink.key, color, scale, handle)
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

-- A sip: on R15 the arm bends and brings the cup up to the mouth
-- (EatMotionController IK on every client, attribute "Eating"; user
-- 2026-10-28: hold the cup and bend the arm to drink) and the cup tilts in the
-- hand; R6 has no IK chain, there the cup still moves up in the hand.
-- Returns the call that lowers it again.
local SIP_TILT = CFrame.Angles(math.rad(-35), 0, 0)
local function sipUp(tool: Tool, character: Model): () -> ()
	local original = tool.Grip
	if character:FindFirstChild("RightUpperArm") then
		character:SetAttribute("Eating", true)
		TweenService:Create(tool, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Grip = original * SIP_TILT }):Play()
	else
		local up = mouthGrip(tool, character)
		if up then TweenService:Create(tool, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Grip = up }):Play() end
	end
	return function()
		character:SetAttribute("Eating", nil)
		if tool.Parent then TweenService:Create(tool, TweenInfo.new(0.3), { Grip = original }):Play() end
	end
end

local function drinkFrom(tool: Tool)
	if tool:GetAttribute("Drinking") then return end
	local character = tool.Parent
	if not character or not character:IsA("Model") then return end
	tool:SetAttribute("Drinking", true)
	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("Gulp") :: Sound?
	local down = sipUp(tool, character)
	if sound then sound:Play() end
	task.wait(ClubConfig.DrinkSeconds)
	down()
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
	-- a clear plastic club tumbler (user 2026-10-28 (3)): wide at the top,
	-- narrow at the foot (stacked rings), the drink inside, ice on top
	local handle = makeHandle(Vector3.new(0.5, 0.85, 0.5), color, 1)
	handle.Parent = tool
	local function ring(name: string, y0: number, y1: number, d: number, c: Color3, material: Enum.Material, transparency: number)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(y1 - y0, d, d)
		p.Color = c
		p.Material = material
		p.Transparency = transparency
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = handle.CFrame * CFrame.new(0, (y0 + y1) / 2 - 0.425, 0) * CFrame.Angles(0, 0, math.rad(90))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Parent = handle
		return p
	end
	local CLEAR = Color3.fromRGB(235, 245, 255)
	-- (2026-10-28 (4)) the plain store cup mesh (ServerStorage.ArtAssets.ClubCup,
	-- 3478283525) when it is there: one clear cup and a smaller copy as the drink
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local cupMesh = art and art:FindFirstChild("ClubCup")
	if cupMesh and cupMesh:IsA("BasePart") then
		local function shell(name: string, size: Vector3, y: number, c: Color3, transparency: number, material: Enum.Material)
			local p = cupMesh:Clone()
			p.Name = name
			p.Size = size
			p.Color = c
			p.Transparency = transparency
			p.Material = material
			p.Anchored = false
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			p.Massless = true
			p.CFrame = handle.CFrame * CFrame.new(0, y, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
			p.Parent = handle
		end
		shell("CupWall", Vector3.new(0.58, 0.85, 0.58), 0, CLEAR, 0.5, Enum.Material.Glass)
		shell("CupDrink", Vector3.new(0.5, 0.66, 0.5), -0.08, color, 0.08, Enum.Material.Glass)
		ring("CupIce", 0.62, 0.68, 0.46, Color3.fromRGB(245, 250, 255), Enum.Material.Ice, 0.25)
	end
	local steps = if cupMesh then 0 else 4
	for i = 1, steps do
		local y0, y1 = (i - 1) * 0.85 / steps, i * 0.85 / steps
		local d = 0.42 + 0.16 * (i - 0.5) / steps
		ring("CupWall" .. i, y0, y1, d, CLEAR, Enum.Material.Glass, 0.55)
		if y1 <= 0.7 then ring("CupDrink" .. i, math.max(y0, 0.04), y1, d - 0.06, color, Enum.Material.Glass, 0.1) end
	end
	if not cupMesh then
		ring("CupRim", 0.82, 0.86, 0.6, CLEAR, Enum.Material.SmoothPlastic, 0.2)
		ring("CupIce", 0.66, 0.72, 0.46, Color3.fromRGB(245, 250, 255), Enum.Material.Ice, 0.25)
	end
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
		label.Text = string.format("%d/%d", bottle:GetAttribute("Servings") or 0, ClubConfig.BottleServings)
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

-- What a bottle of this drink becomes on a table (D-323, temporary design
-- until the bucket art pass): "bottle" = tier 1 (no VIP), else a bucket.
local function kindFor(player: Player, drink: ClubConfig.Drink): DrinkBucket.Kind
	-- (tier-1 cans always get the ice bucket, VIP or not: user 2026-10-28 (4))
	if drink.tier == 1 then return "bottle" end
	return if isVip(player) then (if drink.key == "golmok" then "golmok" else "vip")
		elseif drink.tier >= 3 then "acrylic"
		elseif drink.tier == 2 then "steel"
		else "bottle"
end

local function hasBucket(tablePart: BasePart): boolean
	for _, child in ipairs(tablePart:GetChildren()) do
		if (child.Name == "PlacedBottle" and child:GetAttribute("Bucket")) or child.Name == "SparklerBucket" then return true end
	end
	return false
end
DrinkService.HasBucket = hasBucket -- (SparkleService: sparkler bucket sets)

-- The middle of a table top: where a bucket goes (an Attachment "CenterSlot",
-- so the owner sign and removeBottle treat it like the edge slots).
local function centerSlot(tablePart: BasePart): Attachment
	local existing = tablePart:FindFirstChild("CenterSlot")
	if existing and existing:IsA("Attachment") then return existing end
	local top = tablePart.Size.Y / 2
	for _, child in ipairs(tablePart:GetChildren()) do
		if child:IsA("Attachment") and child.Name == "Slot" then top = child.Position.Y break end
	end
	local slot = Instance.new("Attachment")
	slot.Name = "CenterSlot"
	slot.Position = Vector3.new(0, top, 0)
	slot.Parent = tablePart
	return slot
end
DrinkService.CenterSlot = centerSlot

local function equippedTool(player: Player, attribute: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return if tool and tool:GetAttribute(attribute) ~= nil then tool else nil
end

local function near(player: Player, position: Vector3, distance: number): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and (root.Position - position).Magnitude <= distance
end

-- Small "4/6" over a bottle or bucket: cups left (no buttons, user 2026-10-26).
local function countLabel(holder: BasePart, height: number)
	local info = Instance.new("BillboardGui")
	info.Name = "Info"
	info.Size = UDim2.fromOffset(46, 20)
	info.StudsOffset = Vector3.new(0, height, 0)
	info.MaxDistance = 30
	info.LightInfluence = 0
	info.Parent = holder
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 0.35
	text.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = info
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = text
	refreshBottleLabel(holder)
end

-- New table rules (user 2026-10-26, CLUB.md §22):
--   * hold a bottle and tap a table to put it down; nothing to choose
--   * a bucket drink (tier 2–3, any VIP drink) is one bucket in the middle of
--     the table, it never comes back to the hand; nothing more goes on a
--     table with a bucket
--   * tier-1 bottles stand on the edge slots (as many as there are), the
--     owner can tap one to take it back; no cups, drunk from the bottle
local function placeBottle(player: Player, payload: any): (boolean, string?)
	if typeof(payload) ~= "table" then return false, "잘못된 요청입니다." end
	local tablePart = payload.table
	if typeof(tablePart) ~= "Instance" or not tablePart:IsA("BasePart") or not CollectionService:HasTag(tablePart, "DrinkTable") then
		return false, "테이블을 찾을 수 없습니다."
	end
	-- 공개 범위 is asked again (user 2026-10-26)
	local visibility = payload.visibility
	if visibility ~= "all" and visibility ~= "friends" and visibility ~= "me" then
		return false, "공개 범위를 골라 주세요."
	end
	if not near(player, tablePart.Position, math.max(tablePart.Size.X, tablePart.Size.Z) / 2 + 14) then
		return false, "테이블 가까이 가서 놓아 주세요."
	end
	local bottleTool = equippedTool(player, "Bottle")
	if not bottleTool then return false, "병을 손에 들고 테이블을 눌러 주세요." end
	local drink = ClubConfig.findDrink(bottleTool:GetAttribute("Bottle"))
	if not drink then return false, nil end
	if hasBucket(tablePart) then return false, "버킷이 놓인 테이블에는 더 올릴 수 없어요." end
	local kind = kindFor(player, drink)
	-- (every placed drink is an ice bucket now, tier 1 too: a tap pours a cup,
	-- it is not taken back, user 2026-10-28 (13))
	local isBucket = true
	local slot = if isBucket then centerSlot(tablePart) else freeSlot(tablePart)
	if not slot then return false, "테이블이 가득 찼어요." end
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
	bottle.Transparency = 1
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
	bottle:SetAttribute("Bucket", isBucket)
	local ref = Instance.new("ObjectValue")
	ref.Name = "SlotRef"
	ref.Value = slot
	ref.Parent = bottle

	-- the look (the part above stays as the invisible holder of the label)
	local bucket = DrinkBucket.build(kind, { drinkColor }, CFrame.new(slot.WorldPosition), drink.key)
	if kind == "vip" or kind == "golmok" or kind == "bottle" then -- (tier 1 is a small pail now, on an edge slot: 2026-10-27)
		bucket:ScaleTo(0.8)
	elseif isBucket then
		bucket:ScaleTo(0.9)
	end
	bucket:PivotTo(bucket:GetPivot() + (slot.WorldPosition.Y - bucket:GetBoundingBox().Position.Y + bucket:GetExtentsSize().Y / 2) * Vector3.yAxis)
	bucket.Parent = bottle
	countLabel(bottle, bucket:GetExtentsSize().Y - 0.5 + (if isBucket then 0 else 0.5))

	bottle.Parent = tablePart
	task.delay(ClubConfig.BottleLifetime, function()
		if bottle.Parent then removeBottle(bottle) end
	end)
	return true, nil
end

-- A tap on something on a table (bottle or bucket) with no sparkler in hand.
local function tapPlaced(player: Player, target: any): (boolean, string?)
	if typeof(target) ~= "Instance" then return false, nil end
	local bottle = if target.Name == "PlacedBottle" then target else target:FindFirstAncestor("PlacedBottle")
	if not bottle or not bottle:IsA("BasePart") or not bottle:IsDescendantOf(workspace) then return false, nil end
	if not near(player, bottle.Position, 12) then return false, "조금 더 가까이 가 주세요." end
	local drink = ClubConfig.findDrink(bottle:GetAttribute("DrinkKey"))
	if not drink then return false, nil end
	local variantKey = bottle:GetAttribute("Variant")
	if not bottle:GetAttribute("Bucket") then
		-- tier 1: only its owner takes it back (to drink from the bottle)
		if bottle:GetAttribute("Owner") ~= player.UserId then
			return false, string.format("%s님의 병이에요.", tostring(bottle:GetAttribute("OwnerName")))
		end
		local left = bottle:GetAttribute("Servings") or 0
		local ok, message = giveBottle(player, drink.key, left, variantKey)
		if not ok then return false, message end
		removeBottle(bottle)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local backpack = player:FindFirstChildOfClass("Backpack")
		if humanoid and backpack then
			for _, item in ipairs(backpack:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("Bottle") == drink.key then humanoid:EquipTool(item) break end
			end
		end
		return true, nil
	end
	if not mayPour(player, bottle) then
		return false, string.format("%s님이 놓은 병이에요 (공개: %s).", tostring(bottle:GetAttribute("OwnerName")), visibilityName(bottle:GetAttribute("Visibility")))
	end
	local ok, message = giveCup(player, drink.key, variantKey)
	if not ok then return false, message end
	local left = (bottle:GetAttribute("Servings") or 1) - 1
	bottle:SetAttribute("Servings", left)
	if left <= 0 then removeBottle(bottle) else refreshBottleLabel(bottle) end
	return true, nil
end

-- Tier-1 bottle in hand: a drink straight from the bottle (no cups).
local function swig(player: Player): (boolean, string?)
	local tool = equippedTool(player, "Bottle")
	if not tool or tool:GetAttribute("Drinking") then return false, nil end
	local drink = ClubConfig.findDrink(tool:GetAttribute("Bottle"))
	if not drink then return false, nil end
	if kindFor(player, drink) ~= "bottle" then
		return false, "버킷 음료예요. 테이블을 눌러 올려놓고 컵으로 마셔요."
	end
	local left = ((tool:GetAttribute("Servings") :: number?) or ClubConfig.BottleServings) - 1
	local character = tool.Parent :: Model
	tool:SetAttribute("Drinking", true)
	local handle = tool:FindFirstChild("Handle")
	if handle and not handle:FindFirstChild("Gulp") then
		local gulp = Instance.new("Sound")
		gulp.Name = "Gulp"
		gulp.SoundId = "rbxassetid://" .. tostring(ClubConfig.GulpSoundId)
		gulp.Volume = 0.8
		gulp.RollOffMaxDistance = 40
		gulp.Parent = handle
	end
	local sound = handle and handle:FindFirstChild("Gulp") :: Sound?
	local down = sipUp(tool, character)
	if sound then sound:Play() end
	task.wait(ClubConfig.DrinkSeconds)
	down()
	task.wait(0.3)
	if left <= 0 then
		tool:Destroy()
		return true, "다 마셨어요!"
	end
	local name = drinkLook(drink, tool:GetAttribute("Variant"))
	tool:SetAttribute("Servings", left)
	tool:SetAttribute("Drinking", nil)
	tool.Name = string.format("병 · %s (%d/%d)", name, left, ClubConfig.BottleServings)
	return true, nil
end

--------------------------------------------------
-- Bartender NPC
--------------------------------------------------

-- Staff behind the bar: the bartender (drinks) and, next to them, the item
-- seller (sparklers, sparkler bucket sets, stage cold spark; user 2026-10-26).
local function spawnStaff(spot: BasePart, name: string, title: string, offset: CFrame, shirt: Color3, promptName: string, action: string)
	if spot:FindFirstChild(name) then return end
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = Color3.fromRGB(234, 184, 146)
		description.TorsoColor = shirt
		description.LeftArmColor = Color3.fromRGB(234, 184, 146)
		description.RightArmColor = Color3.fromRGB(234, 184, 146)
		description.LeftLegColor = Color3.fromRGB(30, 30, 36)
		description.RightLegColor = Color3.fromRGB(30, 30, 36)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[DrinkService] Could not create " .. name .. ":", model)
		return
	end
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = title
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = true end
	end
	model:PivotTo(spot.CFrame * offset + Vector3.new(0, 3, 0))
	local root = model:FindFirstChild("HumanoidRootPart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = promptName
	prompt.ActionText = action
	prompt.ObjectText = title
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root or model.PrimaryPart
	model.Parent = spot
end

local function spawnBartender(spot: Instance)
	if not spot:IsA("BasePart") then return end
	spawnStaff(spot, "Bartender", "바텐더", CFrame.new(), Color3.fromRGB(30, 30, 36), "BartenderPrompt", "음료 주문")
	-- (spot's +X runs along the bar)
	spawnStaff(spot, "ItemSeller", "불꽃 판매원", CFrame.new(8, 0, 0), Color3.fromRGB(150, 40, 110), "ItemShopPrompt", "불꽃 · 아이템")
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
	elseif action == "Tap" then
		return tapPlaced(player, payload)
	elseif action == "Swig" then
		return swig(player)
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

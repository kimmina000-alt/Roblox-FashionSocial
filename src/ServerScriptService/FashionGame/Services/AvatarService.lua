--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OutfitSnapshot = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("OutfitSnapshot"))

local AvatarService = {}

local MAX_ACCESSORIES = 20

--------------------------------------------------
-- RIGID ACCESSORY TYPES
--------------------------------------------------

local RIGID_ACCESSORY_TYPES = {
	Hat = true,
	Hair = true,
	Face = true,
	Neck = true,
	Shoulder = true,
	Front = true,
	Back = true,
	Waist = true,
}

--------------------------------------------------
-- LAYERED ACCESSORY TYPES
--------------------------------------------------

local LAYERED_ACCESSORY_TYPES = {
	Eyebrow = true,
	Eyelash = true,
	TShirt = true,
	Shirt = true,
	Pants = true,
	Jacket = true,
	Sweater = true,
	Shorts = true,
	LeftShoe = true,
	RightShoe = true,
	DressSkirt = true,
}

--------------------------------------------------
-- DEFAULT LAYER ORDER (WrapLayer.Order: higher = drawn on top)
-- Used when a layered item is first worn. The player can reorder
-- afterwards from the worn-items strip (SetLayerOrder).
--------------------------------------------------

local DEFAULT_LAYER_ORDER = {
	Eyebrow = 1,
	Eyelash = 1,
	LeftShoe = 2,
	RightShoe = 2,
	Pants = 4,
	Shorts = 5,
	TShirt = 6,
	Shirt = 7,
	DressSkirt = 8,
	Sweater = 9,
	Jacket = 10,
}

-- Only one shoe per side can be worn; a new shoe replaces the old one.
local SINGLE_SLOT_LAYERED = {
	LeftShoe = true,
	RightShoe = true,
}

--------------------------------------------------
-- ASSET TYPE → ACCESSORY TYPE
--------------------------------------------------

local ASSET_TYPE_TO_ACCESSORY_TYPE = {
	-- Classic
	[8] = "Hat",

	-- Rigid accessories
	[41] = "Hair",
	[42] = "Face",
	[43] = "Neck",
	[44] = "Shoulder",
	[45] = "Front",
	[46] = "Back",
	[47] = "Waist",
	[76] = "Eyebrow",
	[77] = "Eyelash",

	-- Layered clothing
	[64] = "TShirt",
	[65] = "Shirt",
	[66] = "Pants",
	[67] = "Jacket",
	[68] = "Sweater",
	[69] = "Shorts",
	[70] = "LeftShoe",
	[71] = "RightShoe",
	[72] = "DressSkirt",
}

--------------------------------------------------
-- CLASSIC CLOTHING
--------------------------------------------------

local CLASSIC_ASSET_TYPES = {
	[2] = "TShirt",
	[11] = "Shirt",
	[12] = "Pants",
}

local ANIMATION_ASSET_TYPES = {
	[Enum.AvatarAssetType.ClimbAnimation.Value] = "ClimbAnimation",
	[Enum.AvatarAssetType.FallAnimation.Value] = "FallAnimation",
	[Enum.AvatarAssetType.IdleAnimation.Value] = "IdleAnimation",
	[Enum.AvatarAssetType.JumpAnimation.Value] = "JumpAnimation",
	[Enum.AvatarAssetType.RunAnimation.Value] = "RunAnimation",
	[Enum.AvatarAssetType.SwimAnimation.Value] = "SwimAnimation",
	[Enum.AvatarAssetType.WalkAnimation.Value] = "WalkAnimation",
	[Enum.AvatarAssetType.MoodAnimation.Value] = "MoodAnimation",
}

local EMOTE_ASSET_TYPE = Enum.AvatarAssetType.EmoteAnimation.Value
local MAKEUP_ASSET_TYPES = {
	[Enum.AvatarAssetType.FaceMakeup.Value] = Enum.MakeupType.Face,
	[Enum.AvatarAssetType.LipMakeup.Value] = Enum.MakeupType.Lip,
	[Enum.AvatarAssetType.EyeMakeup.Value] = Enum.MakeupType.Eye,
}

local function getMakeupDescriptions(description: HumanoidDescription)
	local result = {}
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("MakeupDescription") then
			table.insert(result, child)
		end
	end
	return result
end

--------------------------------------------------
-- HUMANOID
--------------------------------------------------

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

--------------------------------------------------
-- ASSET INFO
--------------------------------------------------

local function getAssetInfo(assetId: number)
	local success, result = pcall(function()
		return AvatarEditorService:GetItemDetailsAsync(
			assetId,
			Enum.AvatarItemType.Asset
		)
	end)

	if not success then
		warn(
			"[AvatarService] GetItemDetails failed:",
			result
		)

		return nil
	end

	return result
end

--------------------------------------------------
-- REMOVE SAME ACCESSORY TYPE
--------------------------------------------------

local function removeAccessoryType(
	description: HumanoidDescription,
	accessoryType: Enum.AccessoryType
)
	local accessories = description:GetAccessories(true)

	local filtered = {}

	for _, accessory in ipairs(accessories) do
		if accessory.AccessoryType ~= accessoryType then
			table.insert(filtered, accessory)
		end
	end

	description:SetAccessories(
		filtered,
		true
	)
end

--------------------------------------------------
-- APPLY DESCRIPTION
--------------------------------------------------

local function applyDescription(
	humanoid: Humanoid,
	description: HumanoidDescription
): (boolean, string)

	print("========== APPLY DESCRIPTION ==========")

	local before = description:GetAccessories(true)

	print("[AvatarService] BEFORE count:", #before)

	for _, accessory in ipairs(before) do
		print(
			"[AvatarService] BEFORE:",
			accessory.AssetId,
			accessory.AccessoryType.Name,
			"Layered:",
			accessory.IsLayered
		)
	end

	
	--------------------------------------------------
	-- AFTER CONFORM
	--------------------------------------------------

	local afterConform = description:GetAccessories(true)

	print(
		"[AvatarService] AFTER CONFORM count:",
		#afterConform
	)

	for _, accessory in ipairs(afterConform) do
		print(
			"[AvatarService] AFTER CONFORM:",
			accessory.AssetId,
			accessory.AccessoryType.Name,
			"Layered:",
			accessory.IsLayered
		)
	end

	--------------------------------------------------
	-- APPLY
	--------------------------------------------------

	local success, err = pcall(function()
		humanoid:ApplyDescriptionResetAsync(
			description,
			Enum.AssetTypeVerification.Default
		)
	end)

	if not success then
		warn(
			"[AvatarService] ApplyDescription failed:",
			err
		)

		return false, "Failed to apply item."
	end

	--------------------------------------------------
	-- VERIFY
	--------------------------------------------------

	local applied = humanoid:GetAppliedDescription()
	local appliedAccessories = applied:GetAccessories(true)

	print(
		"[AvatarService] AFTER APPLY count:",
		#appliedAccessories
	)

	for _, accessory in ipairs(appliedAccessories) do
		print(
			"[AvatarService] AFTER APPLY:",
			accessory.AssetId,
			accessory.AccessoryType.Name,
			"Layered:",
			accessory.IsLayered
		)
	end

	print("========================================")

	return true, "Item equipped."
end
--------------------------------------------------
-- GET CURRENT ITEMS
--------------------------------------------------

function AvatarService.GetCurrentItems(
	player: Player
)
	local humanoid = getHumanoid(player)

	if not humanoid then
		return {}
	end

	local description = humanoid:GetAppliedDescription()

	local result = {}

	--------------------------------------------------
	-- Classic clothing
	--------------------------------------------------

	if description.GraphicTShirt ~= 0 then
		table.insert(result, {
			AssetId = description.GraphicTShirt,
			Category = "TShirt",
		})
	end

	if description.Shirt ~= 0 then
		table.insert(result, {
			AssetId = description.Shirt,
			Category = "Shirt",
		})
	end

	if description.Pants ~= 0 then
		table.insert(result, {
			AssetId = description.Pants,
			Category = "Pants",
		})
	end

	--------------------------------------------------
	-- Makeup
	--------------------------------------------------

	for _, makeup in ipairs(getMakeupDescriptions(description)) do
		table.insert(result, {
			AssetId = makeup.AssetId,
			Category = makeup.MakeupType.Name .. "Makeup",
			IsMakeup = true,
		})
	end

	--------------------------------------------------
	-- Emotes
	--------------------------------------------------

	for _, ids in pairs(description:GetEmotes()) do
		for _, id in ipairs(ids) do
			table.insert(result, {
				AssetId = id,
				Category = "Emote",
				IsEmote = true,
			})
		end
	end

	--------------------------------------------------
	-- Animations
	--------------------------------------------------

	for assetTypeId, propertyName in pairs(ANIMATION_ASSET_TYPES) do
		local animationId = description[propertyName]
		if typeof(animationId) == "number" and animationId ~= 0 then
			table.insert(result, {
				AssetId = animationId,
				Category = propertyName,
				AssetTypeId = assetTypeId,
			})
		end
	end

	--------------------------------------------------
	-- Accessories
	--------------------------------------------------

	for _, accessory in ipairs(
		description:GetAccessories(true)
		) do
		table.insert(result, {
			AssetId = accessory.AssetId,
			Category = accessory.AccessoryType.Name,
			IsLayered = accessory.IsLayered,
			Order = if accessory.IsLayered then accessory.Order else nil,
		})
	end

	return result
end

--------------------------------------------------
-- WEAR ITEM
--------------------------------------------------

local function tryOnItemInner(
	player: Player,
	assetId: number
): (boolean, string)
	--------------------------------------------------
	-- Validate ID
	--------------------------------------------------

	if typeof(assetId) ~= "number" then
		return false, "Invalid asset ID."
	end

	if assetId <= 0 or assetId % 1 ~= 0 then
		return false, "Invalid asset ID."
	end

	--------------------------------------------------
	-- Character
	--------------------------------------------------

	local humanoid = getHumanoid(player)

	if not humanoid then
		return false, "Character is not ready."
	end

	--------------------------------------------------
	-- Asset information
	--------------------------------------------------

	local info = getAssetInfo(assetId)

	if not info then
		return false, "Unable to load item information."
	end

	local assetTypeName = info.AssetType

	if typeof(assetTypeName) ~= "string" then
		return false, "Invalid asset type."
	end

	local avatarAssetType = Enum.AvatarAssetType[assetTypeName]
	local assetTypeId = avatarAssetType and avatarAssetType.Value or nil

	--------------------------------------------------
	-- Makeup
	--------------------------------------------------

	local makeupType = MAKEUP_ASSET_TYPES[assetTypeId]
	if makeupType then
		local description = humanoid:GetAppliedDescription()
		local makeupList = getMakeupDescriptions(description)
		for _, makeup in ipairs(makeupList) do
			if makeup.AssetId == assetId then
				return true, "Item already equipped."
			end
		end
		if #makeupList >= 6 then
			return false, "Maximum 6 makeup items equipped."
		end
		local makeupDescription = Instance.new("MakeupDescription")
		makeupDescription.AssetId = assetId
		makeupDescription.MakeupType = makeupType
		makeupDescription.Order = #makeupList + 1
		makeupDescription.Parent = description
		return applyDescription(humanoid, description)
	end

	--------------------------------------------------
	-- Emote
	--------------------------------------------------

	if assetTypeId == EMOTE_ASSET_TYPE then
		local description = humanoid:GetAppliedDescription()
		local emoteName = typeof(info.Name) == "string" and info.Name or ("Emote_" .. tostring(assetId))
		local emotes = description:GetEmotes()
		for _, ids in pairs(emotes) do
			for _, id in ipairs(ids) do
				if id == assetId then
					return true, "Emote already equipped."
				end
			end
		end
		emotes[emoteName] = {assetId}
		description:SetEmotes(emotes)
		local equipped = description:GetEquippedEmotes()
		if #equipped < 8 then
			table.insert(equipped, emoteName)
			description:SetEquippedEmotes(equipped)
		end
		return applyDescription(humanoid, description)
	end

	--------------------------------------------------
	-- Animations
	--------------------------------------------------

	local animationProperty = ANIMATION_ASSET_TYPES[assetTypeId]
	if animationProperty then
		local description = humanoid:GetAppliedDescription()
		description[animationProperty] = assetId
		return applyDescription(humanoid, description)
	end

	--------------------------------------------------
	-- Classic clothing
	--------------------------------------------------

	local classicType = CLASSIC_ASSET_TYPES[assetTypeId]

	if classicType then
		local description = humanoid:GetAppliedDescription()

		if assetTypeId == 2 then
			description.GraphicTShirt = assetId

		elseif assetTypeId == 11 then
			description.Shirt = assetId

		elseif assetTypeId == 12 then
			description.Pants = assetId
		end

		return applyDescription(
			humanoid,
			description
		)
	end

	--------------------------------------------------
	-- Accessory type
	--------------------------------------------------

	local accessoryTypeName =
		ASSET_TYPE_TO_ACCESSORY_TYPE[assetTypeId]

	if not accessoryTypeName then
		return false, "This item type is not supported yet."
	end

	--------------------------------------------------
	-- Determine rigid / layered
	--------------------------------------------------

	local isRigid =
		RIGID_ACCESSORY_TYPES[accessoryTypeName] == true

	local isLayered =
		LAYERED_ACCESSORY_TYPES[accessoryTypeName] == true

	if not isRigid and not isLayered then
		return false, "Unsupported accessory type."
	end

	--------------------------------------------------
	-- Enum.AccessoryType
	--------------------------------------------------

	local accessoryType =
		Enum.AccessoryType[accessoryTypeName]

	if not accessoryType then
		return false, "Invalid accessory type."
	end

	--------------------------------------------------
	-- Current description
	--------------------------------------------------

	local description =
		humanoid:GetAppliedDescription()



	--------------------------------------------------
	-- Existing accessories
	--------------------------------------------------

	local accessories =
		description:GetAccessories(true)

	--------------------------------------------------
	-- Already wearing this exact item?
	--------------------------------------------------

	for _, accessory in ipairs(accessories) do
		if accessory.AssetId == assetId then
			return true, "Item already equipped."
		end
	end

	if #accessories >= MAX_ACCESSORIES then
		return false, "Too many accessories."
	end

	--------------------------------------------------
	-- ADD NEW ACCESSORY
	--
	-- VERY IMPORTANT:
	--
	-- RIGID:
	--     AssetId
	--     AccessoryType
	--
	-- LAYERED:
	--     AssetId
	--     AccessoryType
	--     IsLayered = true
	--     Order
	--------------------------------------------------

	if isRigid then

		table.insert(
			accessories,
			{
				AssetId = assetId,
				AccessoryType = accessoryType,
			}
		)

	elseif isLayered then

		if SINGLE_SLOT_LAYERED[accessoryTypeName] then
			for i = #accessories, 1, -1 do
				if accessories[i].AccessoryType == accessoryType then
					table.remove(accessories, i)
				end
			end
		end

		table.insert(
			accessories,
			{
				AssetId = assetId,
				AccessoryType = accessoryType,
				IsLayered = true,
				Order = DEFAULT_LAYER_ORDER[accessoryTypeName] or 1,
			}
		)

	end

	--------------------------------------------------
	-- Apply accessory list
	--------------------------------------------------

	description:SetAccessories(
		accessories,
		true
	)

	--------------------------------------------------
	-- Apply to character
	--------------------------------------------------

	return applyDescription(
		humanoid,
		description
	)
end

-- Public wear: apply, then confirm the requested item is really on the avatar
-- (ISSUE-AUDIT-003). A silent engine rejection is reported as a failure.
function AvatarService.TryOnItem(player: Player, assetId: number): (boolean, string)
	local ok, message = tryOnItemInner(player, assetId)
	if not ok then
		return ok, message
	end
	for _, item in ipairs(AvatarService.GetCurrentItems(player)) do
		if item.AssetId == assetId then
			return true, message
		end
	end
	return false, "Roblox did not apply this item to the avatar."
end

--------------------------------------------------
-- REMOVE ITEM
--------------------------------------------------

function AvatarService.RemoveItem(
	player: Player,
	assetId: number
): (boolean, string)

	if typeof(assetId) ~= "number" then
		return false, "Invalid asset ID."
	end

	local humanoid = getHumanoid(player)

	if not humanoid then
		return false, "Character is not ready."
	end

	local description =
		humanoid:GetAppliedDescription()

	--------------------------------------------------
	-- Makeup
	--------------------------------------------------

	for _, makeup in ipairs(getMakeupDescriptions(description)) do
		if makeup.AssetId == assetId then
			makeup:Destroy()
			return applyDescription(humanoid, description)
		end
	end

	--------------------------------------------------
	-- Emotes
	--------------------------------------------------

	local emotes = description:GetEmotes()
	for name, ids in pairs(emotes) do
		for _, id in ipairs(ids) do
			if id == assetId then
				description:RemoveEmote(name)
				local equipped = {}
				for _, entry in ipairs(description:GetEquippedEmotes()) do
					if entry.Name ~= name then
						table.insert(equipped, entry)
					end
				end
				description:SetEquippedEmotes(equipped)
				return applyDescription(humanoid, description)
			end
		end
	end

	--------------------------------------------------
	-- Animations
	--------------------------------------------------

	for _, propertyName in pairs(ANIMATION_ASSET_TYPES) do
		if description[propertyName] == assetId then
			description[propertyName] = 0
			return applyDescription(humanoid, description)
		end
	end

	--------------------------------------------------
	-- Classic T-Shirt
	--------------------------------------------------

	if description.GraphicTShirt == assetId then

		description.GraphicTShirt = 0

		return applyDescription(
			humanoid,
			description
		)
	end

	--------------------------------------------------
	-- Shirt
	--------------------------------------------------

	if description.Shirt == assetId then

		description.Shirt = 0

		return applyDescription(
			humanoid,
			description
		)
	end

	--------------------------------------------------
	-- Pants
	--------------------------------------------------

	if description.Pants == assetId then

		description.Pants = 0

		return applyDescription(
			humanoid,
			description
		)
	end

	--------------------------------------------------
	-- Accessories
	--------------------------------------------------

	local accessories =
		description:GetAccessories(true)

	local filtered = {}

	local removed = false

	for _, accessory in ipairs(accessories) do

		if accessory.AssetId == assetId then
			removed = true
		else
			table.insert(
				filtered,
				accessory
			)
		end

	end

	if not removed then
		return false, "Item is not currently worn."
	end

	description:SetAccessories(
		filtered,
		true
	)

	return applyDescription(
		humanoid,
		description
	)
end

--------------------------------------------------
-- WEAR SHOE BUNDLE (left + right in one apply)
--------------------------------------------------

local SHOE_ASSET_TYPES = {
	LeftShoeAccessory = Enum.AccessoryType.LeftShoe,
	RightShoeAccessory = Enum.AccessoryType.RightShoe,
}

function AvatarService.GetShoeBundleAssets(bundleId: number): {{AssetId: number, AccessoryType: Enum.AccessoryType}}?
	if typeof(bundleId) ~= "number" or bundleId <= 0 or bundleId % 1 ~= 0 then
		return nil
	end
	local ok, details = pcall(function()
		return AssetService:GetBundleDetailsAsync(bundleId)
	end)
	if not ok or typeof(details) ~= "table" or details.BundleType ~= "Shoes" or typeof(details.Items) ~= "table" then
		return nil
	end
	local shoes = {}
	for _, item in ipairs(details.Items) do
		if typeof(item) == "table" and item.Type == "Asset" and typeof(item.Id) == "number" then
			local accessoryType = SHOE_ASSET_TYPES[item.AssetType]
			if not accessoryType then
				local info = getAssetInfo(item.Id)
				accessoryType = info and SHOE_ASSET_TYPES[info.AssetType]
			end
			if accessoryType then
				table.insert(shoes, { AssetId = item.Id, AccessoryType = accessoryType })
			end
		end
	end
	if #shoes == 0 then
		return nil
	end
	return shoes
end

function AvatarService.WearShoeBundle(player: Player, bundleId: number): (boolean, string)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local shoes = AvatarService.GetShoeBundleAssets(bundleId)
	if not shoes then
		return false, "This bundle has no wearable shoes."
	end
	local description = humanoid:GetAppliedDescription()
	local accessories = description:GetAccessories(true)
	local replaceTypes = {}
	for _, shoe in ipairs(shoes) do
		replaceTypes[shoe.AccessoryType] = true
	end
	for i = #accessories, 1, -1 do
		if replaceTypes[accessories[i].AccessoryType] then
			table.remove(accessories, i)
		end
	end
	for _, shoe in ipairs(shoes) do
		table.insert(accessories, {
			AssetId = shoe.AssetId,
			AccessoryType = shoe.AccessoryType,
			IsLayered = true,
			Order = DEFAULT_LAYER_ORDER[shoe.AccessoryType.Name] or 1,
		})
	end
	description:SetAccessories(accessories, true)
	local ok, message = applyDescription(humanoid, description)
	if not ok then
		return false, message
	end
	return true, "Shoes equipped."
end

--------------------------------------------------
-- REMOVE SEVERAL ACCESSORIES IN ONE APPLY (e.g. both shoes)
--------------------------------------------------

function AvatarService.RemoveItems(player: Player, assetIds: any): (boolean, string)
	if typeof(assetIds) ~= "table" or #assetIds == 0 or #assetIds > 10 then
		return false, "Invalid item list."
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local wanted = {}
	for _, id in ipairs(assetIds) do
		if typeof(id) == "number" then
			wanted[id] = true
		end
	end
	local description = humanoid:GetAppliedDescription()
	local accessories = description:GetAccessories(true)
	local filtered = {}
	local removed = 0
	for _, accessory in ipairs(accessories) do
		if wanted[accessory.AssetId] then
			removed += 1
		else
			table.insert(filtered, accessory)
		end
	end
	if removed == 0 then
		return false, "Items are not currently worn."
	end
	description:SetAccessories(filtered, true)
	return applyDescription(humanoid, description)
end

--------------------------------------------------
-- LAYER ORDER
-- orderedIds: layered asset IDs, OUTERMOST FIRST (matches the worn strip,
-- where the left-most card is drawn on top). Converted to WrapLayer.Order
-- where a higher value is drawn on top.
--------------------------------------------------

function AvatarService.SetLayerOrder(player: Player, orderedIds: any): (boolean, string)
	if typeof(orderedIds) ~= "table" or #orderedIds == 0 or #orderedIds > MAX_ACCESSORIES then
		return false, "Invalid layer order."
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local description = humanoid:GetAppliedDescription()
	local accessories = description:GetAccessories(true)
	local layeredById = {}
	local layeredCount = 0
	for _, accessory in ipairs(accessories) do
		if accessory.IsLayered then
			layeredById[accessory.AssetId] = accessory
			layeredCount += 1
		end
	end
	local seen = {}
	local count = 0
	for _, id in ipairs(orderedIds) do
		if typeof(id) ~= "number" or not layeredById[id] or seen[id] then
			return false, "Layer list does not match worn items."
		end
		seen[id] = true
		count += 1
	end
	if count ~= layeredCount then
		return false, "Layer list does not match worn items."
	end
	for index, id in ipairs(orderedIds) do
		layeredById[id].Order = count - index + 1
	end
	description:SetAccessories(accessories, true)
	return applyDescription(humanoid, description)
end

--------------------------------------------------
-- AVATAR EDITOR (Stage 1.5)
-- Official limits come from AvatarEditorService:GetAvatarRules():
--   AccessoryRefinementTypes / Lower/UpperBounds  (rigid accessory Position/Rotation/Scale)
--   Scales                                       (BodyType, Head, Height, Proportion, Width)
--   BasicBodyColorsPalette / BodyColorsPalette   (skin colours)
-- The client edits a draft and previews it on a local clone; nothing changes on
-- the live character until ApplyEdit succeeds and is read back.
--------------------------------------------------

local cachedRules: any = nil
local function getAvatarRules(): any
	if cachedRules then return cachedRules end
	local ok, rules = pcall(function()
		return AvatarEditorService:GetAvatarRules()
	end)
	if ok and typeof(rules) == "table" then
		cachedRules = rules
		return rules
	end
	warn("[AvatarService] GetAvatarRules failed:", rules)
	return nil
end

-- AccessoryType → asset type name used as the key of the refinement bounds.
local REFINE_BOUNDS_KEY = {
	Hat = "Hat",
	Face = "FaceAccessory",
	Neck = "NeckAccessory",
	Shoulder = "ShoulderAccessory",
	Front = "FrontAccessory",
	Back = "BackAccessory",
	Hair = "HairAccessory",
	Waist = "WaistAccessory",
}

-- Editor scale name → HumanoidDescription property. Depth is not in the official
-- rules, so it is not editable.
local SCALE_PROPERTIES = {
	Height = "HeightScale",
	Width = "WidthScale",
	Head = "HeadScale",
	Proportion = "ProportionScale",
	BodyType = "BodyTypeScale",
}

local BODY_COLOR_PROPERTIES = {
	Head = "HeadColor",
	Torso = "TorsoColor",
	LeftArm = "LeftArmColor",
	RightArm = "RightArmColor",
	LeftLeg = "LeftLegColor",
	RightLeg = "RightLegColor",
}

local function refinementInfo(rules: any, accessoryType: Enum.AccessoryType)
	if not rules then return nil end
	local key = REFINE_BOUNDS_KEY[accessoryType.Name]
	if not key then return nil end
	local avatarAssetType = Enum.AvatarAssetType[key]
	local allowed = false
	for _, typeId in ipairs(rules.AccessoryRefinementTypes or {}) do
		if avatarAssetType and typeId == avatarAssetType.Value then
			allowed = true
		end
	end
	if not allowed then return nil end
	local lower = rules.AccessoryRefinementLowerBounds and rules.AccessoryRefinementLowerBounds[key]
	local upper = rules.AccessoryRefinementUpperBounds and rules.AccessoryRefinementUpperBounds[key]
	if typeof(lower) ~= "table" or typeof(upper) ~= "table" then return nil end
	local function range(group: string, prefix: string)
		local lo = lower[group] or {}
		local hi = upper[group] or {}
		return {
			Min = Vector3.new(lo["X" .. prefix] or 0, lo["Y" .. prefix] or 0, lo["Z" .. prefix] or 0),
			Max = Vector3.new(hi["X" .. prefix] or 0, hi["Y" .. prefix] or 0, hi["Z" .. prefix] or 0),
		}
	end
	return {
		Position = range("Position", "Position"),
		Rotation = range("Rotation", "Rotation"),
		Scale = range("Scale", "Scale"),
	}
end

local function clampVector(value: any, bounds: any): Vector3?
	if typeof(value) ~= "Vector3" or not bounds then return nil end
	return Vector3.new(
		math.clamp(value.X, bounds.Min.X, bounds.Max.X),
		math.clamp(value.Y, bounds.Min.Y, bounds.Max.Y),
		math.clamp(value.Z, bounds.Min.Z, bounds.Max.Z)
	)
end

local function paletteHexSet(rules: any): {[string]: boolean}
	local set = {}
	if not rules then return set end
	for _, list in ipairs({ rules.BasicBodyColorsPalette or {}, rules.BodyColorsPalette or {} }) do
		for _, entry in ipairs(list) do
			if typeof(entry) == "table" and typeof(entry.HexColor) == "string" then
				set[string.upper(entry.HexColor)] = true
			end
		end
	end
	return set
end

local function colorToHex(color: Color3): string
	return "#" .. string.upper(color:ToHex())
end

function AvatarService.GetEditState(player: Player)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local rules = getAvatarRules()
	local description = humanoid:GetAppliedDescription()

	local accessories = {}
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("AccessoryDescription") then
			local info = if child.IsLayered then nil else refinementInfo(rules, child.AccessoryType)
			table.insert(accessories, {
				AssetId = child.AssetId,
				AccessoryType = child.AccessoryType.Name,
				IsLayered = child.IsLayered,
				Position = child.Position,
				Rotation = child.Rotation,
				Scale = child.Scale,
				Refinable = info ~= nil,
				Bounds = info,
				Reason = if child.IsLayered then "layered"
					elseif info == nil then "notInRules"
					else nil,
			})
		end
	end

	local scales = {}
	local scaleRules = rules and rules.Scales or {}
	for name, property in pairs(SCALE_PROPERTIES) do
		local rule = scaleRules[name]
		scales[name] = {
			Value = description[property],
			Min = if rule then rule.Min else nil,
			Max = if rule then rule.Max else nil,
			Increment = if rule then rule.Increment else nil,
		}
	end

	local colors = {}
	for part, property in pairs(BODY_COLOR_PROPERTIES) do
		colors[part] = description[property]
	end

	local makeup = {}
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("MakeupDescription") then
			table.insert(makeup, { AssetId = child.AssetId, MakeupType = child.MakeupType.Name, Order = child.Order })
		end
	end

	local palette = {}
	if rules then
		for _, entry in ipairs(rules.BasicBodyColorsPalette or {}) do
			if typeof(entry) == "table" and typeof(entry.HexColor) == "string" then
				table.insert(palette, { Name = entry.Name, Color = Color3.fromHex(entry.HexColor) })
			end
		end
	end

	return true, {
		RigType = humanoid.RigType.Name,
		RulesLoaded = rules ~= nil,
		Accessories = accessories,
		Scales = scales,
		Colors = colors,
		Makeup = makeup,
		Palette = palette,
	}
end

-- draft = {
--   transforms = { ["<assetId>"] = { Position = Vector3, Rotation = Vector3, Scale = Vector3 } },
--   scales     = { Height = number, ... },
--   colors     = { Head = Color3, ... },
--   makeupOrder = { assetId, ... }   -- top-most first
-- }
function AvatarService.ApplyEdit(player: Player, draft: any)
	if typeof(draft) ~= "table" then
		return false, "Invalid edit."
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local rules = getAvatarRules()
	if not rules then
		return false, "Avatar rules are unavailable. Try again."
	end
	local description = humanoid:GetAppliedDescription()
	local skipped = {}

	if typeof(draft.transforms) == "table" then
		for key, values in pairs(draft.transforms) do
			local assetId = tonumber(key)
			local target: AccessoryDescription? = nil
			for _, child in ipairs(description:GetChildren()) do
				if child:IsA("AccessoryDescription") and child.AssetId == assetId then
					target = child
				end
			end
			local info = target and not target.IsLayered and refinementInfo(rules, target.AccessoryType)
			if target and info and typeof(values) == "table" then
				target.Position = clampVector(values.Position, info.Position) or target.Position
				target.Rotation = clampVector(values.Rotation, info.Rotation) or target.Rotation
				target.Scale = clampVector(values.Scale, info.Scale) or target.Scale
			else
				table.insert(skipped, tostring(key))
			end
		end
	end

	if typeof(draft.scales) == "table" then
		if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			return false, "Body scales apply to R15 avatars only."
		end
		for name, value in pairs(draft.scales) do
			local property = SCALE_PROPERTIES[name]
			local rule = rules.Scales and rules.Scales[name]
			if property and rule and typeof(value) == "number" then
				description[property] = math.clamp(value, rule.Min, rule.Max)
			end
		end
	end

	if typeof(draft.colors) == "table" then
		local allowed = paletteHexSet(rules)
		for part, color in pairs(draft.colors) do
			local property = BODY_COLOR_PROPERTIES[part]
			if property and typeof(color) == "Color3" then
				if not allowed[colorToHex(color)] then
					return false, "That skin colour is not in the Roblox palette."
				end
				description[property] = color
			end
		end
	end

	if typeof(draft.makeupOrder) == "table" then
		local byId = {}
		local count = 0
		for _, child in ipairs(description:GetChildren()) do
			if child:IsA("MakeupDescription") then
				byId[child.AssetId] = child
				count += 1
			end
		end
		if #draft.makeupOrder ~= count then
			return false, "Makeup list does not match worn makeup."
		end
		for index, id in ipairs(draft.makeupOrder) do
			local child = byId[id]
			if not child then
				return false, "Makeup list does not match worn makeup."
			end
			child.Order = count - index + 1
		end
	end

	local ok, message = applyDescription(humanoid, description)
	if not ok then
		return false, message
	end

	-- Read back what Roblox actually applied and return it as the new baseline.
	local stateOk, state = AvatarService.GetEditState(player)
	if not stateOk then
		return false, state
	end
	state.Skipped = skipped
	return true, state
end

--------------------------------------------------
-- WARDROBE SNAPSHOT / RESTORE (Stage 2)
-- Save reads the server-confirmed applied description (never a client list).
-- Restore replaces the whole appearance with the saved one, then reads the
-- result back: items that did not survive (deleted, off-sale-moderated, invalid)
-- are reported as skipped while everything else stays applied. If the apply
-- itself errors, the pre-restore baseline is re-applied.
--------------------------------------------------

function AvatarService.CaptureSnapshot(player: Player): (boolean, any)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	return true, OutfitSnapshot.encode(humanoid:GetAppliedDescription())
end

function AvatarService.RestoreSnapshot(player: Player, snapshot: any): (boolean, any)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local description = OutfitSnapshot.decode(snapshot)
	if not description then
		return false, "Saved outfit data is not readable."
	end
	local baseline = humanoid:GetAppliedDescription()
	local ok, err = pcall(function()
		humanoid:ApplyDescriptionResetAsync(description, Enum.AssetTypeVerification.Default)
	end)
	if not ok then
		warn("[AvatarService] Outfit restore failed, restoring baseline:", err)
		local recovered = pcall(function()
			humanoid:ApplyDescriptionResetAsync(baseline, Enum.AssetTypeVerification.Default)
		end)
		return false, if recovered
			then "Could not restore this outfit. Your previous look was kept."
			else "Restore failed. Your avatar will be reloaded."
	end
	local present = OutfitSnapshot.presentAssetIds(humanoid:GetAppliedDescription())
	local skipped = {}
	for _, ref in ipairs(OutfitSnapshot.itemRefs(snapshot)) do
		if not present[ref.id] then
			table.insert(skipped, ref.id)
		end
	end
	return true, { skipped = skipped }
end

--------------------------------------------------
-- ANIMATION PREVIEW
-- The catalog preview plays a worn animation/emote once on its client clone.
-- Catalog asset IDs are packages (a Model with Animation objects), not playable
-- AnimationIds, so the server loads the package and returns the first Animation's
-- AnimationId. Only assets the player is currently wearing can be looked up.
--------------------------------------------------

local ANIMATION_PROPERTIES = {
	"IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation",
	"FallAnimation", "ClimbAnimation", "SwimAnimation", "MoodAnimation",
}
-- assetId -> playable AnimationId (packages never change, so cache for the server lifetime).
local animationPreviewCache: {[number]: string} = {}

function AvatarService.GetAnimationPreview(player: Player, assetId: any): (boolean, any)
	if typeof(assetId) ~= "number" or assetId <= 0 or assetId % 1 ~= 0 then
		return false, "Invalid item."
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local description = humanoid:GetAppliedDescription()
	local worn = false
	for _, property in ipairs(ANIMATION_PROPERTIES) do
		if (description :: any)[property] == assetId then worn = true end
	end
	if not worn then
		for _, ids in pairs(description:GetEmotes()) do
			if table.find(ids, assetId) then worn = true end
		end
	end
	if not worn then
		return false, "Animation is not worn."
	end
	local cached = animationPreviewCache[assetId]
	if cached then
		return true, cached
	end
	local ok, model = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not model then
		return false, "Animation could not be loaded."
	end
	local chosen: Animation? = nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Animation") and descendant.AnimationId ~= "" then
			-- Prefer the main clip ("Animation1") over pose/variation clips.
			if not chosen or descendant.Name == "Animation1" then
				chosen = descendant
			end
		end
	end
	local animationId = if chosen then chosen.AnimationId else nil
	model:Destroy()
	if not animationId then
		return false, "Animation has no playable clip."
	end
	animationPreviewCache[assetId] = animationId
	return true, animationId
end

return AvatarService

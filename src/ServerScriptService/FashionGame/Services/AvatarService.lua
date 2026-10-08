--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")

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
		return MarketplaceService:GetProductInfoAsync(
			assetId,
			Enum.InfoType.Asset
		)
	end)

	if not success then
		warn(
			"[AvatarService] GetProductInfo failed:",
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

	local makeupType = MAKEUP_ASSET_TYPES[assetTypeId]
	if makeupType then
		local description = humanoid:GetAppliedDescription()
		local makeupList = getMakeupDescriptions(description)
		if #makeupList >= 6 then
			return false, "Maximum 6 makeup items equipped."
		end
		for _, makeup in ipairs(makeupList) do
			if makeup.AssetId == assetId then
				return true, "Item already equipped."
			end
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
		local infoName = typeof(info.Name) == "string" and info.Name or ("Emote_" .. tostring(assetId))
		local emotes = description:GetEmotes()
		for _, ids in pairs(emotes) do
			for _, id in ipairs(ids) do
				if id == assetId then
					return true, "Emote already equipped."
				end
			end
		end
		emotes[infoName] = {assetId}
		description:SetEmotes(emotes)
		local equipped = description:GetEquippedEmotes()
		if #equipped < 8 then
			table.insert(equipped, infoName)
			description:SetEquippedEmotes(equipped)
		end
		return applyDescription(humanoid, description)
	end

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
	-- Emote
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
	-- Accessories
	--------------------------------------------------

	for _, accessory in ipairs(
		description:GetAccessories(true)
		) do
		table.insert(result, {
			AssetId = accessory.AssetId,
			Category = accessory.AccessoryType.Name,
			IsLayered = accessory.IsLayered,
		})
	end

	return result
end

--------------------------------------------------
-- WEAR ITEM
--------------------------------------------------

function AvatarService.TryOnItem(
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

	local assetTypeId = info.AssetTypeId

	if typeof(assetTypeId) ~= "number" then
		return false, "Invalid asset type."
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

		table.insert(
			accessories,
			{
				AssetId = assetId,
				AccessoryType = accessoryType,
				IsLayered = true,
				Order = 1,
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

return AvatarService
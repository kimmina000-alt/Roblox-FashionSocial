--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatalogConfig = require(
	ReplicatedStorage
		:WaitForChild("FashionGame")
		:WaitForChild("Shared")
		:WaitForChild("CatalogConfig")
)

local AvatarService = {}

local MAX_ACCESSORIES = 20
local MAX_EQUIPPED_EMOTES = 8

local BODY_PROPERTIES = {
	Head = "Head",
	DynamicHead = "Head",
	Torso = "Torso",
	RightArm = "RightArm",
	LeftArm = "LeftArm",
	RightLeg = "RightLeg",
	LeftLeg = "LeftLeg",
	Face = "Face",
}

local ANIMATION_PROPERTIES = {
	ClimbAnimation = "ClimbAnimation",
	FallAnimation = "FallAnimation",
	IdleAnimation = "IdleAnimation",
	JumpAnimation = "JumpAnimation",
	RunAnimation = "RunAnimation",
	SwimAnimation = "SwimAnimation",
	MoodAnimation = "MoodAnimation",
}

local CLASSIC_PROPERTIES = {
	[2] = "GraphicTShirt",
	[11] = "Shirt",
	[12] = "Pants",
}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getAssetInfo(assetId: number)
	local success, result = pcall(function()
		return MarketplaceService:GetProductInfoAsync(
			assetId,
			Enum.InfoType.Asset
		)
	end)

	if not success then
		warn("[AvatarService] GetProductInfo failed:", result)
		return nil
	end

	return result
end

local function getAssetDefinition(assetTypeId: number)
	local assetType = Enum.AssetType:GetEnumItems()

	for _, enumItem in ipairs(assetType) do
		if enumItem.Value == assetTypeId then
			local avatarAssetType = Enum.AvatarAssetType[enumItem.Name]

			if avatarAssetType then
				return avatarAssetType, CatalogConfig.GetDefinition(avatarAssetType)
			end

			break
		end
	end

	return nil, nil
end

local function applyDescription(
	humanoid: Humanoid,
	description: HumanoidDescription
): (boolean, string)
	local success, err = pcall(function()
		humanoid:ApplyDescriptionResetAsync(
			description,
			Enum.AssetTypeVerification.Default
		)
	end)

	if not success then
		warn("[AvatarService] ApplyDescription failed:", err)
		return false, "Failed to apply item."
	end

	return true, "Item equipped."
end

local function addAccessory(
	description: HumanoidDescription,
	assetId: number,
	assetType: Enum.AvatarAssetType
): (boolean, string)
	local accessoryType = AvatarEditorService:GetAccessoryType(assetType)

	if accessoryType == Enum.AccessoryType.Unknown then
		return false, "Unsupported accessory type."
	end

	local accessories = description:GetAccessories(true)

	for _, accessory in ipairs(accessories) do
		if accessory.AssetId == assetId then
			return true, "Item already equipped."
		end
	end

	if #accessories >= MAX_ACCESSORIES then
		return false, "Too many accessories."
	end

	local isLayered =
		assetType == Enum.AvatarAssetType.TShirtAccessory
		or assetType == Enum.AvatarAssetType.ShirtAccessory
		or assetType == Enum.AvatarAssetType.PantsAccessory
		or assetType == Enum.AvatarAssetType.JacketAccessory
		or assetType == Enum.AvatarAssetType.SweaterAccessory
		or assetType == Enum.AvatarAssetType.ShortsAccessory
		or assetType == Enum.AvatarAssetType.LeftShoeAccessory
		or assetType == Enum.AvatarAssetType.RightShoeAccessory
		or assetType == Enum.AvatarAssetType.DressSkirtAccessory
		or assetType == Enum.AvatarAssetType.EyebrowAccessory
		or assetType == Enum.AvatarAssetType.EyelashAccessory

	if isLayered then
		table.insert(accessories, {
			AssetId = assetId,
			AccessoryType = accessoryType,
			IsLayered = true,
			Order = 1,
		})
	else
		table.insert(accessories, {
			AssetId = assetId,
			AccessoryType = accessoryType,
		})
	end

	description:SetAccessories(accessories, true)

	return true, "Item equipped."
end

local function setBodyPart(
	description: HumanoidDescription,
	assetId: number,
	assetType: Enum.AvatarAssetType
): (boolean, string)
	local propertyName = BODY_PROPERTIES[assetType.Name]

	if not propertyName then
		return false, "Unsupported body part."
	end

	(description :: any)[propertyName] = assetId

	return true, "Item equipped."
end

local function setAnimation(
	description: HumanoidDescription,
	assetId: number,
	assetType: Enum.AvatarAssetType
): (boolean, string)
	local propertyName = ANIMATION_PROPERTIES[assetType.Name]

	if not propertyName then
		return false, "Unsupported animation."
	end

	(description :: any)[propertyName] = assetId

	return true, "Item equipped."
end

local function addEmote(
	description: HumanoidDescription,
	assetId: number,
	name: string
): (boolean, string)
	local emotes = description:GetEmotes()

	local existingIds = 0
	for _, ids in pairs(emotes) do
		if typeof(ids) == "table" then
			existingIds += #ids
			for _, existingId in ipairs(ids) do
				if existingId == assetId then
					return true, "Item already equipped."
				end
			end
		end
	end

	if existingIds >= MAX_EQUIPPED_EMOTES then
		return false, "Too many emotes."
	end

	local safeName = if name == "" then "Emote_" .. tostring(assetId) else name
	description:AddEmote(safeName, assetId)

	local equipped = description:GetEquippedEmotes()
	if #equipped < MAX_EQUIPPED_EMOTES then
		local names = {}
		for _, entry in ipairs(equipped) do
			table.insert(names, entry.Name)
		end

		table.insert(names, safeName)
		description:SetEquippedEmotes(names)
	end

	return true, "Item equipped."
end

--------------------------------------------------
-- GET CURRENT ITEMS
--------------------------------------------------

function AvatarService.GetCurrentItems(player: Player)
	local humanoid = getHumanoid(player)

	if not humanoid then
		return {}
	end

	local description = humanoid:GetAppliedDescription()
	local result = {}

	local function addProperty(assetId: number, category: string, assetTypeName: string)
		if assetId ~= 0 then
			table.insert(result, {
				AssetId = assetId,
				Category = category,
				AssetType = assetTypeName,
			})
		end
	end

	addProperty(description.GraphicTShirt, "Clothing", "TShirt")
	addProperty(description.Shirt, "Clothing", "Shirt")
	addProperty(description.Pants, "Clothing", "Pants")

	addProperty(description.Head, "Body", "Head")
	addProperty(description.Torso, "Body", "Torso")
	addProperty(description.RightArm, "Body", "RightArm")
	addProperty(description.LeftArm, "Body", "LeftArm")
	addProperty(description.RightLeg, "Body", "RightLeg")
	addProperty(description.LeftLeg, "Body", "LeftLeg")
	addProperty(description.Face, "Face", "Face")

	addProperty(description.ClimbAnimation, "Animations", "ClimbAnimation")
	addProperty(description.FallAnimation, "Animations", "FallAnimation")
	addProperty(description.IdleAnimation, "Animations", "IdleAnimation")
	addProperty(description.JumpAnimation, "Animations", "JumpAnimation")
	addProperty(description.RunAnimation, "Animations", "RunAnimation")
	addProperty(description.SwimAnimation, "Animations", "SwimAnimation")
	addProperty(description.MoodAnimation, "Animations", "MoodAnimation")

	for _, accessory in ipairs(description:GetAccessories(true)) do
		table.insert(result, {
			AssetId = accessory.AssetId,
			Category = "Accessory",
			AssetType = accessory.AccessoryType.Name,
			IsLayered = accessory.IsLayered,
		})
	end

	for name, ids in pairs(description:GetEmotes()) do
		for _, assetId in ipairs(ids) do
			table.insert(result, {
				AssetId = assetId,
				Category = "Animations",
				AssetType = "EmoteAnimation",
				EmoteName = name,
			})
		end
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
	if typeof(assetId) ~= "number"
		or assetId <= 0
		or assetId % 1 ~= 0 then
		return false, "Invalid asset ID."
	end

	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end

	local info = getAssetInfo(assetId)
	if not info then
		return false, "Unable to load item information."
	end

	local assetTypeId = info.AssetTypeId
	if typeof(assetTypeId) ~= "number" then
		return false, "Invalid asset type."
	end

	local assetType, definition = getAssetDefinition(assetTypeId)

	if not assetType or not definition then
		return false, "This item type is not supported yet."
	end

	if definition.WearMode == "Unsupported" then
		return false, "This item type is catalog-searchable but not wearable through the current Roblox avatar API."
	end

	local description = humanoid:GetAppliedDescription()

	if definition.WearMode == "ClassicClothing" then
		local propertyName = CLASSIC_PROPERTIES[assetTypeId]

		if not propertyName then
			return false, "Unsupported classic clothing."
		end

		(description :: any)[propertyName] = assetId

	elseif definition.WearMode == "BodyPart" then
		local ok, message = setBodyPart(description, assetId, assetType)

		if not ok then
			return false, message
		end

	elseif definition.WearMode == "Accessory" then
		local ok, message = addAccessory(
			description,
			assetId,
			assetType
		)

		if not ok then
			return false, message
		end

	elseif definition.WearMode == "Animation" then
		local ok, message = setAnimation(
			description,
			assetId,
			assetType
		)

		if not ok then
			return false, message
		end

	elseif definition.WearMode == "Emote" then
		local ok, message = addEmote(
			description,
			assetId,
			tostring(info.Name or "")
		)

		if not ok then
			return false, message
		end
	else
		return false, "Unsupported wear mode."
	end

	return applyDescription(humanoid, description)
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

	local description = humanoid:GetAppliedDescription()

	local classicProperties = {
		"GraphicTShirt",
		"Shirt",
		"Pants",
		"Head",
		"Torso",
		"RightArm",
		"LeftArm",
		"RightLeg",
		"LeftLeg",
		"Face",
		"ClimbAnimation",
		"FallAnimation",
		"IdleAnimation",
		"JumpAnimation",
		"RunAnimation",
		"SwimAnimation",
		"MoodAnimation",
	}

	for _, propertyName in ipairs(classicProperties) do
		if (description :: any)[propertyName] == assetId then
			(description :: any)[propertyName] = 0
			return applyDescription(humanoid, description)
		end
	end

	local accessories = description:GetAccessories(true)
	local filtered = {}
	local removed = false

	for _, accessory in ipairs(accessories) do
		if accessory.AssetId == assetId then
			removed = true
		else
			table.insert(filtered, accessory)
		end
	end

	if removed then
		description:SetAccessories(filtered, true)
		return applyDescription(humanoid, description)
	end

	local emotes = description:GetEmotes()
	local equipped = description:GetEquippedEmotes()
	local removedEmoteName: string? = nil

	for name, ids in pairs(emotes) do
		for _, existingId in ipairs(ids) do
			if existingId == assetId then
				removedEmoteName = name
				break
			end
		end

		if removedEmoteName then
			break
		end
	end

	if removedEmoteName then
		description:RemoveEmote(removedEmoteName)

		local newEquipped = {}
		for _, entry in ipairs(equipped) do
			if entry.Name ~= removedEmoteName then
				table.insert(newEquipped, entry.Name)
			end
		end

		description:SetEquippedEmotes(newEquipped)

		return applyDescription(humanoid, description)
	end

	return false, "Item is not currently worn."
end

return AvatarService

--!strict

local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local AppearanceCodec = require(FashionGame:WaitForChild("Shared"):WaitForChild("AppearanceCodec"))

local AvatarService = {}

local RIGID_TRANSFORM_TYPES = {
	Hat = true,
	Hair = true,
	Face = true,
	Neck = true,
	Shoulder = true,
	Front = true,
	Back = true,
	Waist = true,
}

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

	local transformById: {[number]: any} = {}
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("AccessoryDescription") then
			transformById[child.AssetId] = {
				Position = { child.Position.X, child.Position.Y, child.Position.Z },
				Rotation = { child.Rotation.X, child.Rotation.Y, child.Rotation.Z },
				Scale = { child.Scale.X, child.Scale.Y, child.Scale.Z },
				Order = child.Order,
				IsLayered = child.IsLayered,
				SupportsTransform = child.IsLayered ~= true and RIGID_TRANSFORM_TYPES[child.AccessoryType.Name] == true,
			}
		end
	end

	for _, accessory in ipairs(
		description:GetAccessories(true)
		) do
		local extra = transformById[accessory.AssetId]
		table.insert(result, {
			AssetId = accessory.AssetId,
			Category = accessory.AccessoryType.Name,
			IsLayered = accessory.IsLayered,
			Order = if extra then extra.Order else accessory.Order,
			Position = if extra then extra.Position else nil,
			Rotation = if extra then extra.Rotation else nil,
			Scale = if extra then extra.Scale else nil,
			SupportsTransform = if extra then extra.SupportsTransform else (accessory.IsLayered ~= true and RIGID_TRANSFORM_TYPES[accessory.AccessoryType.Name] == true),
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

function AvatarService.SerializeAppearance(player: Player): (boolean, any)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local description = humanoid:GetAppliedDescription()
	local payload = AppearanceCodec.Serialize(description)
	payload.rigType = humanoid.RigType.Name
	return true, payload
end

function AvatarService.ApplyAppearance(player: Player, data: any): (boolean, any)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	if typeof(data) ~= "table" then
		return false, "Invalid outfit data."
	end

	local description = AppearanceCodec.Deserialize(data)
	local ok, message = applyDescription(humanoid, description)
	local applied = humanoid:GetAppliedDescription()
	local expected = AppearanceCodec.CollectWornIds(data)
	local appliedSet: {[number]: boolean} = {}
	for _, item in ipairs(AvatarService.GetCurrentItems(player)) do
		if typeof(item.AssetId) == "number" then
			appliedSet[item.AssetId] = true
		end
	end
	local failed = {}
	for _, assetId in ipairs(expected) do
		if not appliedSet[assetId] then
			table.insert(failed, assetId)
		end
	end
	if not ok then
		return false, {
			message = message,
			failed = failed,
			items = AvatarService.GetCurrentItems(player),
		}
	end
	return true, {
		message = if #failed > 0 then "Outfit restored with missing items." else "Outfit restored.",
		failed = failed,
		items = AvatarService.GetCurrentItems(player),
		appearance = AppearanceCodec.Serialize(applied),
	}
end

local function findAccessoryDescription(description: HumanoidDescription, assetId: number): AccessoryDescription?
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("AccessoryDescription") and child.AssetId == assetId then
			return child
		end
	end
	return nil
end

function AvatarService.SetAccessoryTransform(player: Player, assetId: number, fields: any): (boolean, string)
	if typeof(assetId) ~= "number" or typeof(fields) ~= "table" then
		return false, "Invalid transform request."
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local description = humanoid:GetAppliedDescription()
	local accessory = findAccessoryDescription(description, assetId)
	if not accessory then
		return false, "Item is not currently worn."
	end
	if accessory.IsLayered or not RIGID_TRANSFORM_TYPES[accessory.AccessoryType.Name] then
		return false, "Position, rotation, and scale only apply to rigid accessories."
	end
	if typeof(fields.Position) == "table" then
		accessory.Position = Vector3.new(fields.Position[1] or 0, fields.Position[2] or 0, fields.Position[3] or 0)
	end
	if typeof(fields.Rotation) == "table" then
		accessory.Rotation = Vector3.new(fields.Rotation[1] or 0, fields.Rotation[2] or 0, fields.Rotation[3] or 0)
	end
	if typeof(fields.Scale) == "table" then
		local sx = math.max(0.05, fields.Scale[1] or 1)
		local sy = math.max(0.05, fields.Scale[2] or 1)
		local sz = math.max(0.05, fields.Scale[3] or 1)
		accessory.Scale = Vector3.new(sx, sy, sz)
	end
	return applyDescription(humanoid, description)
end

function AvatarService.ResetAccessoryTransform(player: Player, assetId: number): (boolean, string)
	return AvatarService.SetAccessoryTransform(player, assetId, {
		Position = { 0, 0, 0 },
		Rotation = { 0, 0, 0 },
		Scale = { 1, 1, 1 },
	})
end

function AvatarService.SetBodyScales(player: Player, scales: any): (boolean, string)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return false, "Body scales apply to R15 avatars."
	end
	if typeof(scales) ~= "table" then
		return false, "Invalid scale values."
	end
	local description = humanoid:GetAppliedDescription()
	local ranges = {
		WidthScale = { 0.75, 1.25 },
		HeightScale = { 0.75, 1.25 },
		DepthScale = { 0.75, 1.25 },
		HeadScale = { 0.75, 1.5 },
		BodyTypeScale = { 0, 1 },
		ProportionScale = { 0, 1 },
	}
	for name, range in pairs(ranges) do
		if typeof(scales[name]) == "number" then
			description[name] = math.clamp(scales[name], range[1], range[2])
		end
	end
	return applyDescription(humanoid, description)
end

function AvatarService.SetBodyColors(player: Player, colors: any): (boolean, string)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	if typeof(colors) ~= "table" then
		return false, "Invalid color values."
	end
	local description = humanoid:GetAppliedDescription()
	for _, name in ipairs(AppearanceCodec.ColorProps) do
		local value = colors[name]
		if typeof(value) == "table" then
			description[name] = Color3.new(
				math.clamp(value[1] or 1, 0, 1),
				math.clamp(value[2] or 1, 0, 1),
				math.clamp(value[3] or 1, 0, 1)
			)
		end
	end
	return applyDescription(humanoid, description)
end

function AvatarService.SetLayerOrder(player: Player, orderedIds: any): (boolean, string)
	if typeof(orderedIds) ~= "table" then
		return false, "Invalid layer order."
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local description = humanoid:GetAppliedDescription()
	local indexById: {[number]: number} = {}
	for index, assetId in ipairs(orderedIds) do
		if typeof(assetId) == "number" then
			indexById[assetId] = index
		end
	end
	local changed = false
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("AccessoryDescription") and child.IsLayered and indexById[child.AssetId] then
			child.Order = indexById[child.AssetId]
			changed = true
		end
	end
	if not changed then
		local accessories = description:GetAccessories(true)
		for _, accessory in ipairs(accessories) do
			if accessory.IsLayered and indexById[accessory.AssetId] then
				accessory.Order = indexById[accessory.AssetId]
				changed = true
			end
		end
		if changed then
			description:SetAccessories(accessories, true)
		end
	end
	if not changed then
		return false, "No layered clothing items were found to reorder."
	end
	return applyDescription(humanoid, description)
end

function AvatarService.SetMakeupOrder(player: Player, orderedIds: any): (boolean, string)
	if typeof(orderedIds) ~= "table" then
		return false, "Invalid makeup order."
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	local description = humanoid:GetAppliedDescription()
	local indexById: {[number]: number} = {}
	for index, assetId in ipairs(orderedIds) do
		if typeof(assetId) == "number" then
			indexById[assetId] = index
		end
	end
	local changed = false
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("MakeupDescription") and indexById[child.AssetId] then
			child.Order = indexById[child.AssetId]
			changed = true
		end
	end
	if not changed then
		return false, "No makeup items were found to reorder."
	end
	return applyDescription(humanoid, description)
end

function AvatarService.SwitchRig(player: Player, rigName: string): (boolean, string)
	if rigName ~= "R6" and rigName ~= "R15" then
		return false, "Choose R6 or R15."
	end
	local humanoid = getHumanoid(player)
	if not humanoid then
		return false, "Character is not ready."
	end
	if humanoid.RigType.Name == rigName then
		return true, "Already using " .. rigName .. "."
	end
	local description = humanoid:GetAppliedDescription()
	local currentCFrame = player.Character and player.Character:GetPivot() or CFrame.new()
	local ok, modelOrErr = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			Enum.HumanoidRigType[rigName],
			Enum.AssetTypeVerification.Default
		)
	end)
	if not ok or typeof(modelOrErr) ~= "Instance" then
		return false, "Could not rebuild the avatar as " .. rigName .. "."
	end
	local model = modelOrErr :: Model
	model.Name = player.Name
	model:PivotTo(currentCFrame)
	player.Character = model
	model.Parent = workspace
	return true, "Switched to " .. rigName .. "."
end

function AvatarService.HandleEdit(player: Player, action: string, payload: any)
	if action == "GetAppearance" then
		return AvatarService.SerializeAppearance(player)
	end
	if action == "ApplyAppearance" then
		return AvatarService.ApplyAppearance(player, payload)
	end
	if action == "SetTransform" then
		if typeof(payload) ~= "table" then
			return false, "Invalid transform payload."
		end
		return AvatarService.SetAccessoryTransform(player, payload.assetId, payload)
	end
	if action == "ResetTransform" then
		if typeof(payload) ~= "table" then
			return false, "Invalid reset payload."
		end
		return AvatarService.ResetAccessoryTransform(player, payload.assetId)
	end
	if action == "SetScales" then
		return AvatarService.SetBodyScales(player, payload)
	end
	if action == "SetColors" then
		return AvatarService.SetBodyColors(player, payload)
	end
	if action == "SetLayerOrder" then
		return AvatarService.SetLayerOrder(player, payload)
	end
	if action == "SetMakeupOrder" then
		return AvatarService.SetMakeupOrder(player, payload)
	end
	if action == "SwitchRig" then
		if typeof(payload) ~= "table" then
			return false, "Invalid rig payload."
		end
		return AvatarService.SwitchRig(player, payload.rigType)
	end
	return false, "Invalid avatar edit action."
end

return AvatarService

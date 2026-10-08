--!strict

local CatalogConfig = {}

-- SearchCatalogAsync currently accepts these catalog limits.
CatalogConfig.SearchLimit = 28
CatalogConfig.DefaultKeyword = ""

export type WearMode =
	"BodyPart"
	| "ClassicClothing"
	| "Accessory"
	| "Animation"
	| "Emote"
	| "Unsupported"

export type AssetDefinition = {
	Category: string,
	Label: string,
	WearMode: WearMode,
	Searchable: boolean,
}

export type CategoryDefinition = {
	Name: string,
	AssetTypes: {Enum.AvatarAssetType},
}

-- =========================================================
-- AvatarAssetType -> game UI category / wear mode
--
-- This is the single source of truth for Avatar Studio.
-- Roblox's current AvatarAssetType enum is used directly.
-- =========================================================

local Definitions: {[Enum.AvatarAssetType]: AssetDefinition} = {}

local function define(
	assetType: Enum.AvatarAssetType,
	category: string,
	label: string,
	wearMode: WearMode,
	searchable: boolean?
)
	Definitions[assetType] = {
		Category = category,
		Label = label,
		WearMode = wearMode,
		Searchable = if searchable == nil then true else searchable,
	}
end

-- BODY
define(Enum.AvatarAssetType.Head, "Body", "Head", "BodyPart")
define(Enum.AvatarAssetType.DynamicHead, "Body", "Dynamic Head", "BodyPart")
define(Enum.AvatarAssetType.Torso, "Body", "Torso", "BodyPart")
define(Enum.AvatarAssetType.RightArm, "Body", "Right Arm", "BodyPart")
define(Enum.AvatarAssetType.LeftArm, "Body", "Left Arm", "BodyPart")
define(Enum.AvatarAssetType.RightLeg, "Body", "Right Leg", "BodyPart")
define(Enum.AvatarAssetType.LeftLeg, "Body", "Left Leg", "BodyPart")

-- FACE
define(Enum.AvatarAssetType.Face, "Face", "Face", "BodyPart")
define(Enum.AvatarAssetType.FaceAccessory, "Face", "Face Accessory", "Accessory")

-- HAIR
define(Enum.AvatarAssetType.HairAccessory, "Hair", "Hair", "Accessory")

-- MAKEUP
-- Roblox exposes these AvatarAssetTypes, but HumanoidDescription has
-- no corresponding FaceMakeup/LipMakeup/EyeMakeup properties.
-- Keep them searchable, but do not pretend they are wearable yet.
define(Enum.AvatarAssetType.FaceMakeup, "Makeup", "Face Makeup", "Unsupported")
define(Enum.AvatarAssetType.LipMakeup, "Makeup", "Lip Makeup", "Unsupported")
define(Enum.AvatarAssetType.EyeMakeup, "Makeup", "Eye Makeup", "Unsupported")

-- EYES & BROWS
define(Enum.AvatarAssetType.EyebrowAccessory, "EyesBrows", "Eyebrow", "Accessory")
define(Enum.AvatarAssetType.EyelashAccessory, "EyesBrows", "Eyelash", "Accessory")

-- CLOTHING
define(Enum.AvatarAssetType.TShirt, "Clothing", "Classic T-Shirt", "ClassicClothing")
define(Enum.AvatarAssetType.Shirt, "Clothing", "Classic Shirt", "ClassicClothing")
define(Enum.AvatarAssetType.Pants, "Clothing", "Classic Pants", "ClassicClothing")
define(Enum.AvatarAssetType.TShirtAccessory, "Clothing", "T-Shirt", "Accessory")
define(Enum.AvatarAssetType.ShirtAccessory, "Clothing", "Shirt", "Accessory")
define(Enum.AvatarAssetType.PantsAccessory, "Clothing", "Pants", "Accessory")
define(Enum.AvatarAssetType.JacketAccessory, "Clothing", "Jacket", "Accessory")
define(Enum.AvatarAssetType.SweaterAccessory, "Clothing", "Sweater", "Accessory")
define(Enum.AvatarAssetType.ShortsAccessory, "Clothing", "Shorts", "Accessory")
define(Enum.AvatarAssetType.DressSkirtAccessory, "Clothing", "Dress / Skirt", "Accessory")

-- SHOES
define(Enum.AvatarAssetType.LeftShoeAccessory, "Shoes", "Left Shoe", "Accessory")
define(Enum.AvatarAssetType.RightShoeAccessory, "Shoes", "Right Shoe", "Accessory")

-- ACCESSORIES
define(Enum.AvatarAssetType.Hat, "Accessories", "Hat", "Accessory")
define(Enum.AvatarAssetType.NeckAccessory, "Accessories", "Neck", "Accessory")
define(Enum.AvatarAssetType.ShoulderAccessory, "Accessories", "Shoulder", "Accessory")
define(Enum.AvatarAssetType.FrontAccessory, "Accessories", "Front", "Accessory")
define(Enum.AvatarAssetType.BackAccessory, "Accessories", "Back", "Accessory")
define(Enum.AvatarAssetType.WaistAccessory, "Accessories", "Waist", "Accessory")

-- ANIMATIONS
define(Enum.AvatarAssetType.IdleAnimation, "Animations", "Idle", "Animation")
define(Enum.AvatarAssetType.WalkAnimation, "Animations", "Walk", "Animation")
define(Enum.AvatarAssetType.RunAnimation, "Animations", "Run", "Animation")
define(Enum.AvatarAssetType.JumpAnimation, "Animations", "Jump", "Animation")
define(Enum.AvatarAssetType.FallAnimation, "Animations", "Fall", "Animation")
define(Enum.AvatarAssetType.ClimbAnimation, "Animations", "Climb", "Animation")
define(Enum.AvatarAssetType.SwimAnimation, "Animations", "Swim", "Animation")
define(Enum.AvatarAssetType.MoodAnimation, "Animations", "Mood", "Animation")
define(Enum.AvatarAssetType.EmoteAnimation, "Animations", "Emote", "Emote")

-- OTHER
-- Gear is an avatar catalog type but is not a HumanoidDescription
-- accessory/body/animation slot.
define(Enum.AvatarAssetType.Gear, "Other", "Gear", "Unsupported")
-- AvatarBackground is for avatar/profile/thumbnail background surfaces,
-- not the in-world character appearance.
define(Enum.AvatarAssetType.AvatarBackground, "Other", "Avatar Background", "Unsupported")

CatalogConfig.AssetDefinitions = Definitions

CatalogConfig.Categories = {
	{
		Name = "All",
		AssetTypes = nil,
	},
	{
		Name = "Body",
		AssetTypes = {
			Enum.AvatarAssetType.Head,
			Enum.AvatarAssetType.DynamicHead,
			Enum.AvatarAssetType.Torso,
			Enum.AvatarAssetType.RightArm,
			Enum.AvatarAssetType.LeftArm,
			Enum.AvatarAssetType.RightLeg,
			Enum.AvatarAssetType.LeftLeg,
		},
	},
	{
		Name = "Hair",
		AssetTypes = {
			Enum.AvatarAssetType.HairAccessory,
		},
	},
	{
		Name = "Face",
		AssetTypes = {
			Enum.AvatarAssetType.Face,
			Enum.AvatarAssetType.FaceAccessory,
		},
	},
	{
		Name = "Makeup",
		AssetTypes = {
			Enum.AvatarAssetType.FaceMakeup,
			Enum.AvatarAssetType.LipMakeup,
			Enum.AvatarAssetType.EyeMakeup,
		},
	},
	{
		Name = "EyesBrows",
		AssetTypes = {
			Enum.AvatarAssetType.EyebrowAccessory,
			Enum.AvatarAssetType.EyelashAccessory,
		},
	},
	{
		Name = "Clothing",
		AssetTypes = {
			Enum.AvatarAssetType.TShirt,
			Enum.AvatarAssetType.Shirt,
			Enum.AvatarAssetType.Pants,
			Enum.AvatarAssetType.TShirtAccessory,
			Enum.AvatarAssetType.ShirtAccessory,
			Enum.AvatarAssetType.PantsAccessory,
			Enum.AvatarAssetType.JacketAccessory,
			Enum.AvatarAssetType.SweaterAccessory,
			Enum.AvatarAssetType.ShortsAccessory,
			Enum.AvatarAssetType.DressSkirtAccessory,
		},
	},
	{
		Name = "Shoes",
		AssetTypes = {
			Enum.AvatarAssetType.LeftShoeAccessory,
			Enum.AvatarAssetType.RightShoeAccessory,
		},
	},
	{
		Name = "Accessories",
		AssetTypes = {
			Enum.AvatarAssetType.Hat,
			Enum.AvatarAssetType.NeckAccessory,
			Enum.AvatarAssetType.ShoulderAccessory,
			Enum.AvatarAssetType.FrontAccessory,
			Enum.AvatarAssetType.BackAccessory,
			Enum.AvatarAssetType.WaistAccessory,
		},
	},
	{
		Name = "Animations",
		AssetTypes = {
			Enum.AvatarAssetType.IdleAnimation,
			Enum.AvatarAssetType.WalkAnimation,
			Enum.AvatarAssetType.RunAnimation,
			Enum.AvatarAssetType.JumpAnimation,
			Enum.AvatarAssetType.FallAnimation,
			Enum.AvatarAssetType.ClimbAnimation,
			Enum.AvatarAssetType.SwimAnimation,
			Enum.AvatarAssetType.MoodAnimation,
			Enum.AvatarAssetType.EmoteAnimation,
		},
	},
	{
		Name = "Other",
		AssetTypes = {
			Enum.AvatarAssetType.Gear,
			Enum.AvatarAssetType.AvatarBackground,
		},
	},
}


-- =========================================================
-- ANIMATION SUBCATEGORIES
-- =========================================================

CatalogConfig.AnimationCategories = {
	{
		Name = "Idle",
		DisplayName = "Idle",
		AssetTypes = {
			Enum.AvatarAssetType.IdleAnimation,
		},
	},
	{
		Name = "Walk",
		DisplayName = "Walk",
		AssetTypes = {
			Enum.AvatarAssetType.WalkAnimation,
		},
	},
	{
		Name = "Run",
		DisplayName = "Run",
		AssetTypes = {
			Enum.AvatarAssetType.RunAnimation,
		},
	},
	{
		Name = "Jump",
		DisplayName = "Jump",
		AssetTypes = {
			Enum.AvatarAssetType.JumpAnimation,
		},
	},
	{
		Name = "Fall",
		DisplayName = "Fall",
		AssetTypes = {
			Enum.AvatarAssetType.FallAnimation,
		},
	},
	{
		Name = "Climb",
		DisplayName = "Climb",
		AssetTypes = {
			Enum.AvatarAssetType.ClimbAnimation,
		},
	},
	{
		Name = "Swim",
		DisplayName = "Swim",
		AssetTypes = {
			Enum.AvatarAssetType.SwimAnimation,
		},
	},
	{
		Name = "Mood",
		DisplayName = "Mood",
		AssetTypes = {
			Enum.AvatarAssetType.MoodAnimation,
		},
	},
	{
		Name = "Emote",
		DisplayName = "Emote",
		AssetTypes = {
			Enum.AvatarAssetType.EmoteAnimation,
		},
	},
}

-- Search across all AvatarAssetTypes represented by this editor.
CatalogConfig.AllowedAssetTypes = {
	Enum.AvatarAssetType.Head,
	Enum.AvatarAssetType.DynamicHead,
	Enum.AvatarAssetType.Torso,
	Enum.AvatarAssetType.RightArm,
	Enum.AvatarAssetType.LeftArm,
	Enum.AvatarAssetType.RightLeg,
	Enum.AvatarAssetType.LeftLeg,

	Enum.AvatarAssetType.Face,
	Enum.AvatarAssetType.FaceAccessory,
	Enum.AvatarAssetType.HairAccessory,

	Enum.AvatarAssetType.FaceMakeup,
	Enum.AvatarAssetType.LipMakeup,
	Enum.AvatarAssetType.EyeMakeup,

	Enum.AvatarAssetType.EyebrowAccessory,
	Enum.AvatarAssetType.EyelashAccessory,

	Enum.AvatarAssetType.TShirt,
	Enum.AvatarAssetType.Shirt,
	Enum.AvatarAssetType.Pants,
	Enum.AvatarAssetType.TShirtAccessory,
	Enum.AvatarAssetType.ShirtAccessory,
	Enum.AvatarAssetType.PantsAccessory,
	Enum.AvatarAssetType.JacketAccessory,
	Enum.AvatarAssetType.SweaterAccessory,
	Enum.AvatarAssetType.ShortsAccessory,
	Enum.AvatarAssetType.DressSkirtAccessory,

	Enum.AvatarAssetType.LeftShoeAccessory,
	Enum.AvatarAssetType.RightShoeAccessory,

	Enum.AvatarAssetType.Hat,
	Enum.AvatarAssetType.NeckAccessory,
	Enum.AvatarAssetType.ShoulderAccessory,
	Enum.AvatarAssetType.FrontAccessory,
	Enum.AvatarAssetType.BackAccessory,
	Enum.AvatarAssetType.WaistAccessory,

	Enum.AvatarAssetType.IdleAnimation,
	Enum.AvatarAssetType.WalkAnimation,
	Enum.AvatarAssetType.RunAnimation,
	Enum.AvatarAssetType.JumpAnimation,
	Enum.AvatarAssetType.FallAnimation,
	Enum.AvatarAssetType.ClimbAnimation,
	Enum.AvatarAssetType.SwimAnimation,
	Enum.AvatarAssetType.MoodAnimation,
	Enum.AvatarAssetType.EmoteAnimation,

	Enum.AvatarAssetType.Gear,
	Enum.AvatarAssetType.AvatarBackground,
}

function CatalogConfig.GetAnimationCategory(name: string)
	for _, category in ipairs(CatalogConfig.AnimationCategories) do
		if category.Name == name then
			return category
		end
	end

	return nil
end

function CatalogConfig.GetDefinition(
	assetType: Enum.AvatarAssetType
): AssetDefinition?
	return Definitions[assetType]
end

function CatalogConfig.GetDefinitionByName(
	assetTypeName: string
): AssetDefinition?
	local assetType = Enum.AvatarAssetType[assetTypeName]

	if not assetType then
		return nil
	end

	return Definitions[assetType]
end

function CatalogConfig.GetCategoryAssetTypes(
	categoryName: string
): {Enum.AvatarAssetType}?
	for _, category in ipairs(CatalogConfig.Categories) do
		if category.Name == categoryName then
			return category.AssetTypes
		end
	end

	return nil
end

return CatalogConfig

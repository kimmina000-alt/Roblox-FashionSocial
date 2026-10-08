--!strict

local CatalogConfig = {}

--------------------------------------------------
-- SEARCH
--------------------------------------------------

-- Roblox CatalogSearchParams.Limit accepts:
-- 10 / 28 / 30 / 60 / 120
CatalogConfig.SearchLimit = 30
CatalogConfig.DefaultKeyword = ""

--------------------------------------------------
-- ALL AVATAR ASSET TYPES
--------------------------------------------------

CatalogConfig.AllowedAssetTypes = {
	-- Classic / body
	Enum.AvatarAssetType.TShirt,
	Enum.AvatarAssetType.Hat,
	Enum.AvatarAssetType.Shirt,
	Enum.AvatarAssetType.Pants,
	Enum.AvatarAssetType.Head,
	Enum.AvatarAssetType.Face,
	Enum.AvatarAssetType.Gear,
	Enum.AvatarAssetType.Torso,
	Enum.AvatarAssetType.RightArm,
	Enum.AvatarAssetType.LeftArm,
	Enum.AvatarAssetType.LeftLeg,
	Enum.AvatarAssetType.RightLeg,

	-- Rigid accessories
	Enum.AvatarAssetType.HairAccessory,
	Enum.AvatarAssetType.FaceAccessory,
	Enum.AvatarAssetType.NeckAccessory,
	Enum.AvatarAssetType.ShoulderAccessory,
	Enum.AvatarAssetType.FrontAccessory,
	Enum.AvatarAssetType.BackAccessory,
	Enum.AvatarAssetType.WaistAccessory,

	-- Animations
	Enum.AvatarAssetType.ClimbAnimation,
	Enum.AvatarAssetType.FallAnimation,
	Enum.AvatarAssetType.IdleAnimation,
	Enum.AvatarAssetType.JumpAnimation,
	Enum.AvatarAssetType.RunAnimation,
	Enum.AvatarAssetType.SwimAnimation,
	Enum.AvatarAssetType.WalkAnimation,
	Enum.AvatarAssetType.EmoteAnimation,
	Enum.AvatarAssetType.MoodAnimation,

	-- Layered clothing
	Enum.AvatarAssetType.TShirtAccessory,
	Enum.AvatarAssetType.ShirtAccessory,
	Enum.AvatarAssetType.PantsAccessory,
	Enum.AvatarAssetType.JacketAccessory,
	Enum.AvatarAssetType.SweaterAccessory,
	Enum.AvatarAssetType.ShortsAccessory,
	Enum.AvatarAssetType.LeftShoeAccessory,
	Enum.AvatarAssetType.RightShoeAccessory,
	Enum.AvatarAssetType.DressSkirtAccessory,

	-- Layered face
	Enum.AvatarAssetType.EyebrowAccessory,
	Enum.AvatarAssetType.EyelashAccessory,

	-- Makeup
	Enum.AvatarAssetType.FaceMakeup,
	Enum.AvatarAssetType.LipMakeup,
	Enum.AvatarAssetType.EyeMakeup,

	-- Dynamic avatar
	Enum.AvatarAssetType.DynamicHead,

	-- Avatar profile background
	Enum.AvatarAssetType.AvatarBackground,
}

--------------------------------------------------
-- CATEGORY DEFINITIONS
--------------------------------------------------

CatalogConfig.Categories = {
	{
		Name = "All",
		AssetTypes = CatalogConfig.AllowedAssetTypes,
	},

	-- Accessories
	{Name = "Hair", AssetTypes = {Enum.AvatarAssetType.HairAccessory}},
	{Name = "Hats", AssetTypes = {Enum.AvatarAssetType.Hat}},
	{Name = "Face Accessories", AssetTypes = {Enum.AvatarAssetType.FaceAccessory}},
	{Name = "Neck", AssetTypes = {Enum.AvatarAssetType.NeckAccessory}},
	{Name = "Shoulder", AssetTypes = {Enum.AvatarAssetType.ShoulderAccessory}},
	{Name = "Front", AssetTypes = {Enum.AvatarAssetType.FrontAccessory}},
	{Name = "Back", AssetTypes = {Enum.AvatarAssetType.BackAccessory}},
	{Name = "Waist", AssetTypes = {Enum.AvatarAssetType.WaistAccessory}},

	-- Classic clothing
	{Name = "Classic T-Shirt", AssetTypes = {Enum.AvatarAssetType.TShirt}},
	{Name = "Classic Shirt", AssetTypes = {Enum.AvatarAssetType.Shirt}},
	{Name = "Classic Pants", AssetTypes = {Enum.AvatarAssetType.Pants}},

	-- Layered clothing
	{Name = "Layered T-Shirt", AssetTypes = {Enum.AvatarAssetType.TShirtAccessory}},
	{Name = "Layered Shirt", AssetTypes = {Enum.AvatarAssetType.ShirtAccessory}},
	{Name = "Layered Pants", AssetTypes = {Enum.AvatarAssetType.PantsAccessory}},
	{Name = "Jacket", AssetTypes = {Enum.AvatarAssetType.JacketAccessory}},
	{Name = "Sweater", AssetTypes = {Enum.AvatarAssetType.SweaterAccessory}},
	{Name = "Shorts", AssetTypes = {Enum.AvatarAssetType.ShortsAccessory}},
	{
		Name = "Shoes",
		AssetTypes = {
			Enum.AvatarAssetType.LeftShoeAccessory,
			Enum.AvatarAssetType.RightShoeAccessory,
		},
	},
	{Name = "Dress / Skirt", AssetTypes = {Enum.AvatarAssetType.DressSkirtAccessory}},

	-- Head / face
	{Name = "Head", AssetTypes = {Enum.AvatarAssetType.Head}},
	{Name = "Dynamic Head", AssetTypes = {Enum.AvatarAssetType.DynamicHead}},
	{Name = "Face", AssetTypes = {Enum.AvatarAssetType.Face}},
	{Name = "Eyebrow", AssetTypes = {Enum.AvatarAssetType.EyebrowAccessory}},
	{Name = "Eyelash", AssetTypes = {Enum.AvatarAssetType.EyelashAccessory}},
	{Name = "Face Makeup", AssetTypes = {Enum.AvatarAssetType.FaceMakeup}},
	{Name = "Lip Makeup", AssetTypes = {Enum.AvatarAssetType.LipMakeup}},
	{Name = "Eye Makeup", AssetTypes = {Enum.AvatarAssetType.EyeMakeup}},

	-- Animation
	{
		Name = "Animations",
		AssetTypes = {
			Enum.AvatarAssetType.ClimbAnimation,
			Enum.AvatarAssetType.FallAnimation,
			Enum.AvatarAssetType.IdleAnimation,
			Enum.AvatarAssetType.JumpAnimation,
			Enum.AvatarAssetType.RunAnimation,
			Enum.AvatarAssetType.SwimAnimation,
			Enum.AvatarAssetType.WalkAnimation,
		},
	},
	{Name = "Emotes", AssetTypes = {Enum.AvatarAssetType.EmoteAnimation}},
	{Name = "Mood", AssetTypes = {Enum.AvatarAssetType.MoodAnimation}},

	-- Other avatar assets
	{Name = "Body Parts", AssetTypes = {
		Enum.AvatarAssetType.Torso,
		Enum.AvatarAssetType.RightArm,
		Enum.AvatarAssetType.LeftArm,
		Enum.AvatarAssetType.LeftLeg,
		Enum.AvatarAssetType.RightLeg,
	}},
	{Name = "Gear", AssetTypes = {Enum.AvatarAssetType.Gear}},
	{Name = "Avatar Background", AssetTypes = {Enum.AvatarAssetType.AvatarBackground}},
}

--------------------------------------------------
-- SORT OPTIONS
--------------------------------------------------

CatalogConfig.SortOptions = {
	{Name = "Relevance", Value = Enum.CatalogSortType.Relevance},
	{Name = "Price: Low → High", Value = Enum.CatalogSortType.PriceLowToHigh},
	{Name = "Price: High → Low", Value = Enum.CatalogSortType.PriceHighToLow},
	{Name = "Most Favorited", Value = Enum.CatalogSortType.MostFavorited},
	{Name = "Recently Created", Value = Enum.CatalogSortType.RecentlyCreated},
	{Name = "Bestselling", Value = Enum.CatalogSortType.Bestselling},
}

CatalogConfig.SortAggregation = Enum.CatalogSortAggregation.AllTime

--------------------------------------------------
-- DEFAULT SEARCH FILTERS
--------------------------------------------------

CatalogConfig.MinPrice = 0
CatalogConfig.MaxPrice = 0
CatalogConfig.IncludeOffSale = false

CatalogConfig.CategoryFilter = Enum.CatalogCategoryFilter.None
CatalogConfig.SalesTypeFilter = Enum.SalesTypeFilter.All
CatalogConfig.CreatorType = Enum.CreatorTypeFilter.All

return CatalogConfig

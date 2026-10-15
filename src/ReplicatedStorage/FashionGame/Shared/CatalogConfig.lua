--!strict

local CatalogConfig = {}

--------------------------------------------------
-- SEARCH
--------------------------------------------------

CatalogConfig.SearchLimit = 30
CatalogConfig.DefaultKeyword = ""

--------------------------------------------------
-- ALL AVATAR ASSET TYPES
--------------------------------------------------

CatalogConfig.AllowedAssetTypes = {
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

	Enum.AvatarAssetType.HairAccessory,
	Enum.AvatarAssetType.FaceAccessory,
	Enum.AvatarAssetType.NeckAccessory,
	Enum.AvatarAssetType.ShoulderAccessory,
	Enum.AvatarAssetType.FrontAccessory,
	Enum.AvatarAssetType.BackAccessory,
	Enum.AvatarAssetType.WaistAccessory,

	Enum.AvatarAssetType.ClimbAnimation,
	Enum.AvatarAssetType.FallAnimation,
	Enum.AvatarAssetType.IdleAnimation,
	Enum.AvatarAssetType.JumpAnimation,
	Enum.AvatarAssetType.RunAnimation,
	Enum.AvatarAssetType.SwimAnimation,
	Enum.AvatarAssetType.WalkAnimation,
	Enum.AvatarAssetType.EmoteAnimation,
	Enum.AvatarAssetType.MoodAnimation,

	Enum.AvatarAssetType.TShirtAccessory,
	Enum.AvatarAssetType.ShirtAccessory,
	Enum.AvatarAssetType.PantsAccessory,
	Enum.AvatarAssetType.JacketAccessory,
	Enum.AvatarAssetType.SweaterAccessory,
	Enum.AvatarAssetType.ShortsAccessory,
	Enum.AvatarAssetType.LeftShoeAccessory,
	Enum.AvatarAssetType.RightShoeAccessory,
	Enum.AvatarAssetType.DressSkirtAccessory,

	Enum.AvatarAssetType.EyebrowAccessory,
	Enum.AvatarAssetType.EyelashAccessory,

	Enum.AvatarAssetType.FaceMakeup,
	Enum.AvatarAssetType.LipMakeup,
	Enum.AvatarAssetType.EyeMakeup,

	Enum.AvatarAssetType.DynamicHead,
	Enum.AvatarAssetType.AvatarBackground,
}

--------------------------------------------------
-- CATEGORY GROUPS
--
-- Roblox's AvatarAssetType is the actual API filter.
-- The names below are the player-facing catalog organization.
--------------------------------------------------

CatalogConfig.CategoryGroups = {
	{
		Name = "신체",
		Categories = {
			{Name = "전신", AssetTypes = {
				Enum.AvatarAssetType.Torso,
				Enum.AvatarAssetType.RightArm,
				Enum.AvatarAssetType.LeftArm,
				Enum.AvatarAssetType.LeftLeg,
				Enum.AvatarAssetType.RightLeg,
			}},
			{Name = "헤어", AssetTypes = {
				Enum.AvatarAssetType.HairAccessory,
			}},
			{Name = "머리", AssetTypes = {
				Enum.AvatarAssetType.Head,
				Enum.AvatarAssetType.DynamicHead,
			}},
			{Name = "얼굴", AssetTypes = {
				Enum.AvatarAssetType.Face,
			}},
		},
	},

	{
		Name = "복장",
		Categories = {
			{Name = "셔츠", AssetTypes = {Enum.AvatarAssetType.ShirtAccessory}},
			{Name = "티셔츠", AssetTypes = {Enum.AvatarAssetType.TShirtAccessory}},
			{Name = "스웨터", AssetTypes = {Enum.AvatarAssetType.SweaterAccessory}},
			{Name = "재킷", AssetTypes = {Enum.AvatarAssetType.JacketAccessory}},
			{Name = "바지", AssetTypes = {Enum.AvatarAssetType.PantsAccessory}},
			{Name = "원피스 및 치마", AssetTypes = {Enum.AvatarAssetType.DressSkirtAccessory}},
			-- Roblox AvatarAssetType에는 별도의 BodysuitAccessory가 없으므로
			-- 실제 API 필터는 제공되지 않는다.
			{Name = "바디수트", AssetTypes = {}},
			{Name = "반바지", AssetTypes = {Enum.AvatarAssetType.ShortsAccessory}},
			{Name = "신발", AssetTypes = {
				Enum.AvatarAssetType.LeftShoeAccessory,
				Enum.AvatarAssetType.RightShoeAccessory,
			}},
			{Name = "클래식 셔츠", AssetTypes = {Enum.AvatarAssetType.Shirt}},
			{Name = "클래식 티셔츠", AssetTypes = {Enum.AvatarAssetType.TShirt}},
			{Name = "클래식 바지", AssetTypes = {Enum.AvatarAssetType.Pants}},
		},
	},

	{
		Name = "액세서리",
		Categories = {
			{Name = "모자", AssetTypes = {Enum.AvatarAssetType.Hat}},
			{Name = "얼굴 액세서리", AssetTypes = {Enum.AvatarAssetType.FaceAccessory}},
			{Name = "목", AssetTypes = {Enum.AvatarAssetType.NeckAccessory}},
			{Name = "어깨", AssetTypes = {Enum.AvatarAssetType.ShoulderAccessory}},
			{Name = "앞", AssetTypes = {Enum.AvatarAssetType.FrontAccessory}},
			{Name = "뒤", AssetTypes = {Enum.AvatarAssetType.BackAccessory}},
			{Name = "허리", AssetTypes = {Enum.AvatarAssetType.WaistAccessory}},
		},
	},

	{
		Name = "얼굴 꾸미기",
		Categories = {
			{Name = "눈썹", AssetTypes = {Enum.AvatarAssetType.EyebrowAccessory}},
			{Name = "속눈썹", AssetTypes = {Enum.AvatarAssetType.EyelashAccessory}},
			{Name = "얼굴 메이크업", AssetTypes = {Enum.AvatarAssetType.FaceMakeup}},
			{Name = "입술 메이크업", AssetTypes = {Enum.AvatarAssetType.LipMakeup}},
			{Name = "눈 메이크업", AssetTypes = {Enum.AvatarAssetType.EyeMakeup}},
		},
	},

	{
		Name = "애니메이션",
		Categories = {
			{Name = "애니메이션 팩", AssetTypes = {}, IncludeOffSale = true, BundleTypes = {Enum.BundleType.Animations}},
			{Name = "대기", AssetTypes = {Enum.AvatarAssetType.IdleAnimation}},
			{Name = "걷기", AssetTypes = {Enum.AvatarAssetType.WalkAnimation}},
			{Name = "달리기", AssetTypes = {Enum.AvatarAssetType.RunAnimation}},
			{Name = "점프", AssetTypes = {Enum.AvatarAssetType.JumpAnimation}},
			{Name = "낙하", AssetTypes = {Enum.AvatarAssetType.FallAnimation}},
			{Name = "오르기", AssetTypes = {Enum.AvatarAssetType.ClimbAnimation}},
			{Name = "수영", AssetTypes = {Enum.AvatarAssetType.SwimAnimation}},
			{Name = "이모트", AssetTypes = {Enum.AvatarAssetType.EmoteAnimation}},
			{Name = "표정 / 무드", AssetTypes = {Enum.AvatarAssetType.MoodAnimation}},
		},
	},

	{
		Name = "기타",
		Categories = {
			{Name = "기어", AssetTypes = {Enum.AvatarAssetType.Gear}},
			{Name = "아바타 배경", AssetTypes = {Enum.AvatarAssetType.AvatarBackground}},
		},
	},
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

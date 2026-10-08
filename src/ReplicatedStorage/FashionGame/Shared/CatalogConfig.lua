--!strict

local CatalogConfig = {}

-- Roblox CatalogSearchParams.Limit 허용값:
-- 10, 28, 30, 60, 120
CatalogConfig.SearchLimit = 28

CatalogConfig.DefaultKeyword = ""

CatalogConfig.AllowedAssetTypes = {
	Enum.AvatarAssetType.Hat,
	Enum.AvatarAssetType.HairAccessory,
	Enum.AvatarAssetType.FaceAccessory,
	Enum.AvatarAssetType.NeckAccessory,
	Enum.AvatarAssetType.ShoulderAccessory,
	Enum.AvatarAssetType.FrontAccessory,
	Enum.AvatarAssetType.BackAccessory,
	Enum.AvatarAssetType.WaistAccessory,

	Enum.AvatarAssetType.Shirt,
	Enum.AvatarAssetType.Pants,
	Enum.AvatarAssetType.TShirt,
}

return CatalogConfig

--!strict
-- NPC looks built from catalog items (D-656, docs/04_ART/characters/CHARACTERS.md).
-- NpcLooks.describe(key) → a HumanoidDescription (server: it may yield for the
-- body outfit), or nil when the key is unknown or the outfit cannot load.

local Players = game:GetService("Players")

export type Look = {
	bodyOutfit: number, -- the body bundle's outfit id (body parts + colours)
	head: number?,
	hair: number?,
	layered: {{id: number, kind: Enum.AccessoryType}}, -- inside → outside
	shirt: number?,
	pants: number?,
	scales: {[string]: number}?, -- HumanoidDescription scale properties
}

local NpcLooks = {}

NpcLooks.Looks = {
	-- Character A (user's pick 2026-10-31): the club bartender
	CharacterA = {
		bodyOutfit = 5367685064154827, -- bundle 93826326052944 가장 키가 큰 근육 베미맨
		head = 119054363847542, -- 블랙 스컬 헤드
		hair = 136998073184295, -- 블랙 슬릭 백 울프 컷 헤어
		layered = {
			{ id = 93816036884228, kind = Enum.AccessoryType.TShirt }, -- 어깨 패드
			{ id = 88241801880611, kind = Enum.AccessoryType.Pants }, -- 블랙
			{ id = 94019726091658, kind = Enum.AccessoryType.Sweater }, -- 스웨터 / 은색 체인
			{ id = 114076548170981, kind = Enum.AccessoryType.Jacket }, -- 바이커 가죽 재킷
		},
		shirt = 138090188090311, -- 클리어
		pants = 133566828283173, -- 클리어
		-- (user: the body as long as it goes)
		scales = { HeightScale = 1.05, BodyTypeScale = 1, ProportionScale = 1, WidthScale = 1, DepthScale = 1 },
	},
} :: {[string]: Look}

function NpcLooks.describe(key: string): HumanoidDescription?
	local look = NpcLooks.Looks[key]
	if not look then return nil end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromOutfitId(look.bodyOutfit)
	end)
	if not ok or not description then return nil end
	if look.head then description.Head = look.head end
	if look.shirt then description.Shirt = look.shirt end
	if look.pants then description.Pants = look.pants end
	for name, value in pairs(look.scales or {}) do
		(description :: any)[name] = value
	end
	-- (SetAccessories(..., true) replaces every accessory: the hair goes in the same list)
	local list = {}
	if look.hair then
		table.insert(list, { AssetId = look.hair, AccessoryType = Enum.AccessoryType.Hair, IsLayered = false })
	end
	for i, item in ipairs(look.layered) do
		table.insert(list, { AssetId = item.id, AccessoryType = item.kind, IsLayered = true, Order = i })
	end
	description:SetAccessories(list, true)
	return description
end

return NpcLooks

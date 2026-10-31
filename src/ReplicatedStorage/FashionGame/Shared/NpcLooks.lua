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
	pose: number?, -- animation id played on a loop (an emote's Animation)
	holds: string?, -- a prop in the right hand: "sparkler", or "bottle:<drink key>"
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
		-- (user 2026-10-31) emote 92480837999507 "벽 마른 아우라 농장 자세":
		-- its Animation, read with InsertService:LoadAsset
		pose = 85700383015225,
		holds = "sparkler", -- a lit hand sparkler (user 2026-10-31)
	},
} :: {[string]: Look}

-- The bartender (user 2026-10-31, later): Character A without the biker
-- jacket, a drink bottle in the hand instead of the sparkler (the item seller
-- keeps Character A). The new top and the apron wait for their asset ids:
-- the id the user sent for both, 92480837999507, is the pose emote.
do
	local a = NpcLooks.Looks.CharacterA
	local layered = {}
	for _, item in ipairs(a.layered) do
		if item.kind ~= Enum.AccessoryType.Jacket then table.insert(layered, item) end
	end
	NpcLooks.Looks.Bartender = {
		bodyOutfit = a.bodyOutfit, head = a.head, hair = a.hair, layered = layered,
		shirt = a.shirt, pants = a.pants, scales = a.scales, pose = a.pose,
		holds = "bottle:skull_water",
	}
end

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

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
	extras: {{id: number, kind: Enum.AccessoryType}}?, -- rigid accessories (a mask, a hat)
	shirt: number?,
	pants: number?,
	scales: {[string]: number}?, -- HumanoidDescription scale properties
	skin: Color3?, -- every body part's colour (instead of the body outfit's)
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

-- The bartender (user 2026-10-31, later): Character A's body, head and pants
-- with a white shirt instead of the sweater, a restaurant apron instead of the
-- biker jacket, its own hair and pose, a drink bottle in the hand (the item
-- seller keeps Character A).
do
	local a = NpcLooks.Looks.CharacterA
	NpcLooks.Looks.Bartender = {
		bodyOutfit = a.bodyOutfit,
		-- face: bundle 142347556296633 (소년 얼굴 … 한국 남성 실감적, a dynamic head)
		head = 112433260004346,
		hair = 137811933417350, -- 지저분한 아이돌 웨이브 헤어 (블랙 화이트; off and back on, 2026-10-31)
		extras = { { id = 12897844075, kind = Enum.AccessoryType.Face } }, -- 마스크 (was 97755745317658 until D-664)
		layered = {
			{ id = 93816036884228, kind = Enum.AccessoryType.TShirt }, -- 어깨 패드
			{ id = 130442955983043, kind = Enum.AccessoryType.TShirt }, -- 주름진 오피스 버튼업 셔츠 화이트
			{ id = 88241801880611, kind = Enum.AccessoryType.Pants }, -- 블랙
			{ id = 12271645343, kind = Enum.AccessoryType.Jacket }, -- 블랙 레스토랑 앞치마
		},
		shirt = a.shirt,
		pants = a.pants,
		scales = a.scales,
		-- emote 94499750241713 "귀여운 머리머리 스트리트웨어 배디 포즈": its Animation
		pose = 126073867043223,
		holds = "bottle:skull_water",
	}
	-- the item seller: Character A with its own pose (user 2026-10-31):
	-- emote 85369612310951 "장엄한 소환 포즈"
	local seller = table.clone(a)
	seller.pose = 100249604916626
	seller.skin = Color3.fromRGB(150, 95, 58) -- bronze (user 2026-10-31)
	-- (user 2026-10-31, later: without the biker jacket)
	seller.layered = {}
	for _, item in ipairs(a.layered) do
		if item.kind ~= Enum.AccessoryType.Jacket then table.insert(seller.layered, item) end
	end
	NpcLooks.Looks.ItemSeller = seller
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
	if look.skin then
		for _, part in ipairs({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }) do
			(description :: any)[part .. "Color"] = look.skin
		end
	end
	for name, value in pairs(look.scales or {}) do
		(description :: any)[name] = value
	end
	-- (SetAccessories(..., true) replaces every accessory: the hair goes in the same list)
	local list = {}
	if look.hair then
		table.insert(list, { AssetId = look.hair, AccessoryType = Enum.AccessoryType.Hair, IsLayered = false })
	end
	for _, item in ipairs(look.extras or {}) do
		table.insert(list, { AssetId = item.id, AccessoryType = item.kind, IsLayered = false })
	end
	for i, item in ipairs(look.layered) do
		table.insert(list, { AssetId = item.id, AccessoryType = item.kind, IsLayered = true, Order = i })
	end
	description:SetAccessories(list, true)
	return description
end

return NpcLooks

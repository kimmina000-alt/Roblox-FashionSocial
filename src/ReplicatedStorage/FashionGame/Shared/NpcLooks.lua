--!strict
-- NPC looks built from catalog items (D-656, docs/04_ART/characters/CHARACTERS.md).
-- NpcLooks.describe(key) → a HumanoidDescription (server: it may yield for the
-- body outfit), or nil when the key is unknown or the outfit cannot load.

local Players = game:GetService("Players")

export type Look = {
	bodyOutfit: number?, -- the body bundle's outfit id (body parts + colours)
	-- (D-1055) or a whole outfit the user saved in the game's 옷장 (OutfitSnapshot
	-- JSON: assets, accessories, colours, scales), copied here
	snapshot: string?,
	-- walks about a box (NpcWander), in the coordinates of the part it stands on
	wander: { min: Vector3, max: Vector3, speed: number?, walk: number? }?, -- walk: its walk animation
	nod: boolean?, -- nods its head to a beat while it walks (NpcNodController)
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
		-- face: bundle 24649319209591 얼굴 없는 인형 머리 (a dynamic head; D-669,
		-- after 142347556296633 → 112433260004346)
		head = 110649251725469,
		hair = 137811933417350, -- 지저분한 아이돌 웨이브 헤어 (블랙 화이트; off and back on, 2026-10-31)
		-- (no mask: 97755745317658, then 12897844075, taken off D-668)
		layered = {
			{ id = 93816036884228, kind = Enum.AccessoryType.TShirt }, -- 어깨 패드
			{ id = 130442955983043, kind = Enum.AccessoryType.TShirt }, -- 주름진 오피스 버튼업 셔츠 화이트
			{ id = 88241801880611, kind = Enum.AccessoryType.Pants }, -- 블랙
			{ id = 12271645343, kind = Enum.AccessoryType.Jacket }, -- 블랙 레스토랑 앞치마
		},
		shirt = a.shirt,
		pants = a.pants,
		scales = a.scales,
		-- (D-671) the idle of animation pack bundle 155758204354290 실감나는 남성 01
		-- (Idle Animation asset 114822686413694 → Animation1); before: emote
		-- 94499750241713 → 126073867043223
		pose = 128667162266929,
		holds = "bottle:skull_water",
	}
	-- the item seller: Character A with its own pose (user 2026-10-31):
	-- emote 85369612310951 "장엄한 소환 포즈"
	local seller = table.clone(a)
	-- (the bartender's pose since 2026-11-01; before: emote 85369612310951 → 100249604916626)
	seller.pose = NpcLooks.Looks.Bartender.pose
	seller.skin = Color3.fromRGB(105, 62, 36) -- dark bronze (user 2026-10-31: bronze, then darker)
	seller.head = NpcLooks.Looks.Bartender.head -- the bartender's face, not the skull
	seller.extras = { { id = 18991656628, kind = Enum.AccessoryType.Face } } -- 얼굴 가면 (검정), D-671
	-- (user 2026-10-31, later: without the biker jacket)
	seller.layered = {}
	for _, item in ipairs(a.layered) do
		if item.kind ~= Enum.AccessoryType.Jacket then table.insert(seller.layered, item) end
	end
	NpcLooks.Looks.ItemSeller = seller
end

-- The guide by the ranking boards (user 2026-11-01, D-713): bundle
-- 170950066963813 "노란색 귀여운 토끼" (its outfit 4205246513673697, the bunny
-- hair put back: SetAccessories replaces the outfit's accessories). The
-- bartender's look before (D-712).
NpcLooks.Looks.Guide = {
	bodyOutfit = 4205246513673697,
	hair = 119121044324572, -- Yellow Cute Bunny - Hair
	layered = {},
	pose = 507766388, -- the standard R15 idle
}

-- (D-1055) a HumanoidDescription from a saved 옷장 outfit (OutfitSnapshot form)
local function fromSnapshot(json: string): HumanoidDescription?
	local ok, snap = pcall(function() return game:GetService("HttpService"):JSONDecode(json) end)
	if not ok or typeof(snap) ~= "table" then return nil end
	local d = Instance.new("HumanoidDescription")
	for property, id in pairs(snap.assets or {}) do
		pcall(function() (d :: any)[property] = id end)
	end
	for property, hex in pairs(snap.colors or {}) do
		pcall(function() (d :: any)[property] = Color3.fromHex(hex) end)
	end
	for property, value in pairs(snap.scales or {}) do
		pcall(function() (d :: any)[property] = value end)
	end
	local list = {}
	for _, a in ipairs(snap.accessories or {}) do
		local kind = (Enum.AccessoryType :: any)[a.t]
		if kind then
			table.insert(list, { AssetId = a.id, AccessoryType = kind, IsLayered = a.l == true, Order = if a.l then a.o else nil })
		end
	end
	pcall(function() d:SetAccessories(list, true) end)
	return d
end

function NpcLooks.describe(key: string): HumanoidDescription?
	local look = NpcLooks.Looks[key]
	if not look then return nil end
	if look.snapshot then return fromSnapshot(look.snapshot) end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromOutfitId(look.bodyOutfit :: number)
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

-- (D-1055, user 2026-11-09: "카탈로그에 있는 \"아랄\", \"마노\" 아바타를 npc로 만들어 줘.
-- 마노는 불꽃 판매원 npc로 쓰고 아랄은 바텐더로 사용해. 불꽃 판매원이랑 바텐더도
-- 안내원처럼 주변 배회하는 것처럼 만들어 줘. 바텐더는 바 안에서만 왔다갔다 하고
-- 불꽃판매원은 박자 타는 것처럼 고개 까딱거리면서 걸어다니게 해") the two outfits
-- the user saved in the game's 옷장 (Vantablack_Dev), as saved 2026-11-09.
-- The old looks (Character A based) stay above for the record.
-- Wander boxes, in BartenderSpot's space (its -Z looks to world +X): the
-- bartender in the corridor behind the bar (world x 71.5..77.5, z -194..-165),
-- the seller on the floor before the VIP stair hall door (x 120..136, z -268..-258).
local MANO = [[{"scales":{"BodyTypeScale":1,"DepthScale":1,"HeadScale":1,"HeightScale":1.05,"WidthScale":1,"ProportionScale":0},"assets":{"RightLeg":78612455851057,"RightArm":99893444151857,"Shirt":79181697649041,"Head":127877713775017,"MoodAnimation":14618207727,"Torso":96849800222415,"LeftArm":119615240551922,"LeftLeg":87648388126478},"accessories":[{"l":false,"id":81925899554541,"t":"Hair","o":0},{"l":false,"id":113547626506365,"t":"Hair","o":0},{"l":true,"id":124097620724692,"t":"Shirt","o":7},{"l":true,"id":89712522411590,"t":"Shirt","o":7},{"l":true,"id":102661930700515,"t":"Pants","o":4},{"l":true,"id":109327049739669,"t":"LeftShoe","o":2},{"l":true,"id":99148738190585,"t":"RightShoe","o":2},{"l":false,"id":83090048744955,"t":"Hat","o":0},{"l":true,"id":95607422794942,"t":"Jacket","o":10},{"l":false,"id":140396507416761,"t":"Hat","o":0},{"l":false,"id":17840354692,"t":"Neck","o":0}],"colors":{"HeadColor":"564236","TorsoColor":"564236","LeftArmColor":"564236","RightLegColor":"564236","LeftLegColor":"564236","RightArmColor":"564236"}}]]
local ARAL = [[{"scales":{"BodyTypeScale":1,"DepthScale":1,"HeadScale":1,"HeightScale":1.05,"WidthScale":1,"ProportionScale":0},"assets":{"RightLeg":78612455851057,"RightArm":99893444151857,"Shirt":99334947837858,"Head":101658325697467,"MoodAnimation":14618207727,"Torso":96849800222415,"LeftArm":119615240551922,"LeftLeg":87648388126478},"accessories":[{"l":false,"id":89616122151377,"t":"Face","o":0},{"l":false,"id":134721172715164,"t":"Face","o":0},{"l":true,"id":75973424534143,"t":"Shirt","o":4},{"l":false,"id":13905362287,"t":"Neck","o":0},{"l":false,"id":13580738522,"t":"Hair","o":0},{"l":false,"id":107966977497481,"t":"Hat","o":0},{"l":false,"id":109192743730128,"t":"Face","o":0},{"l":true,"id":90193253096556,"t":"TShirt","o":3},{"l":true,"id":120447811356556,"t":"Jacket","o":5},{"l":true,"id":73476274706538,"t":"Pants","o":2},{"l":true,"id":99674854011177,"t":"Shorts","o":1},{"l":false,"id":115502408928745,"t":"Face","o":0}],"colors":{"HeadColor":"eab892","TorsoColor":"eab892","LeftArmColor":"eab892","RightLegColor":"eab892","LeftLegColor":"eab892","RightArmColor":"eab892"}}]]
-- (D-1059, user 2026-11-09: "마노 아랄한테 순서대로 애니메이션팩 적용해서 걷는 모션
-- 다르게 해", with two packs shown in the catalog, in this order) 마노 = "무감정한"
-- (Nonchalant by 55Epaa, bundle 113981103573113), 아랄 = "무감정한 학교 소년"
-- (Nonchalant School Boy by Benere & Chenere's UGC, bundle 198542201057320):
-- their Walk and Idle animations (read with InsertService from the pack's assets)
NpcLooks.Looks.Bartender = {
	snapshot = ARAL,
	pose = 138428331917859, -- School Boy idle (asset 137455194395454)
	holds = NpcLooks.Looks.Bartender.holds,
	wander = { min = Vector3.new(-16, 0, -1.5), max = Vector3.new(13, 0, 4.5), speed = 5, walk = 80970435798081 }, -- School Boy walk (asset 114762832908181)
}
NpcLooks.Looks.ItemSeller = {
	snapshot = MANO,
	pose = 103551093140086, -- Nonchalant idle (asset 89470439129000)
	holds = NpcLooks.Looks.ItemSeller.holds,
	-- (D-1289: with the seller, world x 146..162, z -270..-260)
	wander = { min = Vector3.new(-92, 0, -86), max = Vector3.new(-82, 0, -70), speed = 6, walk = 76458754461389 }, -- Nonchalant walk (asset 89554541453975)
	nod = true,
}

return NpcLooks

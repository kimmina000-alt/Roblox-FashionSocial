--!strict
-- (D-888, user 2026-11-05: ClubConfig split up, one file per kind) Club drinks (non-alcoholic only, D-043), prices, bottles, who may pour.
-- ClubConfig re-exports every field below, so ClubConfig.Drinks keeps working.

--------------------------------------------------
-- Drinks (non-alcoholic only, D-043). Test list from the user (2026-10-20):
-- free drinks first, paid drinks below. `product` = MonetizationConfig key.
-- NOTE: 사이다/콜라/환타 are placeholder names for testing; before release
-- replace brand names (환타) with generic ones (e.g. 오렌지 소다).
--------------------------------------------------

export type DrinkVariant = {
	key: string,
	name: string,
	color: Color3,
}

-- tier 1 = free or a few coins, 2 = coins or Robux, 3 = Robux only
-- (docs/01_SYSTEMS/CLUB_SHOP_PRICING.md §4, D-270..D-274).
--   coins       coin price (VIP pays ClubConfig.VipCoinRate of it)
--   product     MonetizationConfig.Products key (Robux)
--   vipProduct  the same drink at the VIP price (a product of its own)
--   vipOnly     only VIP pass owners can buy it
--   variants    flavours / can colours picked before buying
--   look        what the bottle or can looks like (shown in the menu)
export type Drink = {
	key: string,
	name: string,
	color: Color3,
	tier: number,
	product: string?,
	vipProduct: string?,
	vipOnly: boolean?,
	coins: number?,
	variants: {DrinkVariant}?,
	look: string?,
}

local M = {}

-- Names and looks follow real drinks without using their brand names
-- (user list 2026-10-25; reference brand in the comment). Bottle shapes:
-- BottleShapes (user sheet 2026-10-27).
M.Drinks = {
	-- tier 1
	{ key = "water", name = "물", tier = 1, color = Color3.fromRGB(190, 230, 255), look = "생수 페트병 · 파란 라벨" },
	{ key = "cider", name = "사이다", tier = 1, coins = 1, color = Color3.fromRGB(200, 255, 200), look = "초록 사이다 페트병" },
	{ key = "cola", name = "콜라", tier = 1, coins = 1, color = Color3.fromRGB(70, 35, 20), look = "사이다 페트병 · 빨간 라벨" },
	{ key = "orange", name = "오렌지 소다", tier = 1, coins = 5, color = Color3.fromRGB(255, 140, 0), look = "사이다 페트병 · 주황" },
	{ key = "lemonade", name = "레몬에이드", tier = 1, coins = 5, color = Color3.fromRGB(255, 232, 110), look = "사이다 페트병 · 노랑" },
	{ key = "blueade", name = "블루에이드", tier = 1, coins = 5, color = Color3.fromRGB(70, 160, 255), look = "사이다 페트병 · 파랑" },
	-- tier 2: 💰100 or 10 R$
	{ key = "ginger_brew", name = "진저 브루", tier = 2, coins = 100, product = "Drink_GingerBrew", -- Bundaberg
		color = Color3.fromRGB(240, 135, 75), look = "피치 오렌지 병 · 흰 글씨" }, -- (D-458: colours from the user's bottle photos)
	{ key = "monte", name = "몬테 스파클링", tier = 2, coins = 100, product = "Drink_Monte", -- San Pellegrino
		color = Color3.fromRGB(105, 165, 40), look = "라임 초록 병 · 연두 글씨" },
	{ key = "french_lemonade", name = "프렌치 레모네이드", tier = 2, coins = 100, product = "Drink_FrenchLemonade", -- Lorina
		color = Color3.fromRGB(242, 214, 70), look = "시트론 노랑 병 · 흰 글씨" },
	{ key = "golden_apple", name = "골든 애플 스파클링", tier = 2, coins = 100, product = "Drink_GoldenApple", -- Martinelli's
		color = Color3.fromRGB(238, 160, 40), look = "만다린 황금 병 · 흰 글씨" },
	{ key = "zzang_pop", name = "쨍팝", tier = 2, coins = 100, product = "Drink_ZzangPop", -- Poppi
		color = Color3.fromRGB(255, 90, 170), look = "가늘고 긴 반투명 병",
		variants = {
			{ key = "pink", name = "딸기", color = Color3.fromRGB(200, 30, 95) },
			{ key = "lime", name = "라임", color = Color3.fromRGB(170, 240, 60) },
			{ key = "orange", name = "오렌지", color = Color3.fromRGB(255, 150, 40) },
		} },
	-- tier 2: 💰150 or 15 R$ (energy drinks)
	{ key = "hot_boost", name = "핫부스트", tier = 2, coins = 150, product = "Drink_HotBoost", -- Hot6
		color = Color3.fromRGB(225, 45, 60), look = "워터멜론 빨강 병 · 노랑 글씨" },
	{ key = "green_claw", name = "그린 클로", tier = 2, coins = 150, product = "Drink_GreenClaw", -- Monster
		color = Color3.fromRGB(120, 175, 55), look = "페어 초록 병 · 연두 글씨" },
	{ key = "blue_wing", name = "블루 윙", tier = 2, coins = 150, product = "Drink_BlueWing", -- Red Bull
		color = Color3.fromRGB(120, 185, 245), look = "투명 병 · 연한 파랑 · 파란 글씨" },
	-- tier 3: Robux only (VIP price products: 20% off)
	{ key = "stack_hydro", name = "스택 하이드로", tier = 3, product = "Drink_StackHydro", vipProduct = "Drink_StackHydro_VIP", -- Cadence
		color = Color3.fromRGB(196, 120, 40), look = "호박색 병 · 크림 라벨 · 꿀벌" },
	{ key = "pastel_splash", name = "파스텔 스플래시", tier = 3, product = "Drink_PastelSplash", vipProduct = "Drink_PastelSplash_VIP", -- La Croix
		color = Color3.fromRGB(245, 125, 60), look = "반투명 오렌지 병 · 흰 P · 은은한 빛" },
	{ key = "skull_water", name = "스컬 캔 워터", tier = 3, product = "Drink_SkullWater", vipProduct = "Drink_SkullWater_VIP", -- Liquid Death
		color = Color3.fromRGB(18, 18, 20), look = "검정 스윙탑 병 · 은박 · 금색 해골 라벨" },
	-- VIP only (D-274)
	-- (user 2026-10-30: renamed in the spirit of the metallic champagne it was
	-- drawn from, a name of our own; non-alcoholic sparkling)
	{ key = "golmok", name = "메종 드 루미에르", tier = 3, vipOnly = true, product = "Drink_Golmok",
		-- (user photo 2026-10-27: the metallic champagne set's colours)
		color = Color3.fromRGB(212, 168, 70), look = "메탈 병 · 스페이드 엠블럼",
		variants = {
			{ key = "lavender", name = "레몬 라벤더", color = Color3.fromRGB(212, 168, 70) }, -- gold
			{ key = "rose", name = "생강 장미", color = Color3.fromRGB(232, 150, 185) }, -- pink
			{ key = "omija", name = "오미자 히비스커스", color = Color3.fromRGB(165, 35, 85) }, -- rose red
			{ key = "mulberry", name = "오디", color = Color3.fromRGB(95, 100, 112) }, -- dark silver
		} },
} :: {Drink}

-- VIP pays this share of a coin price (20% off, D-270).
M.VipCoinRate = 0.8
M.TierNames = { "1단계 · 무료 / 코인", "2단계 · 코인 또는 Robux", "3단계 · 프리미엄 (Robux)" }

function M.findVariant(drink: Drink, key: any): DrinkVariant?
	if not drink.variants then return nil end
	for _, variant in ipairs(drink.variants) do
		if variant.key == key then return variant end
	end
	return drink.variants[1]
end

-- Coin price for this player (VIP discount when vip is true).
function M.coinPrice(drink: Drink, vip: boolean): number?
	if not drink.coins then return nil end
	if vip and drink.coins >= 10 then
		return math.floor(drink.coins * M.VipCoinRate + 0.5)
	end
	return drink.coins
end

-- Bottles: carried as a tool, placed on a table, poured into cups.
-- (no real carry limit for guests, user 2026-10-27, D-430: extra items wait
-- in the backpack; only cafe staff on shift keep a two-in-hand limit)
M.MaxBottlesCarried = 99
M.BottleServings = 6        -- cups per bottle
M.BottleLifetime = 600      -- seconds on a table before it is cleared (tier 1)
-- (user 2026-10-30) the dearer the drink, the longer it stays: tier 1 10 min,
-- tier 2 20, tier 3 30, VIP drinks 1 hour (still gone when the owner leaves)
function M.bottleLifetime(drink: any): number
	if drink and drink.vipOnly then return 60 * 60 end
	local tier = drink and drink.tier or 1
	return if tier >= 3 then 30 * 60 elseif tier == 2 then 20 * 60 else M.BottleLifetime
end
M.MaxCupsCarried = 99
M.DrinkSeconds = 2.6
M.GulpSoundId = 9114172296   -- "Drinking Cu Gulping 9 (SFX)", Pro Sound Effects (Roblox licensed)

-- Who may pour from a placed bottle.
M.Visibility = {
	{ key = "all", name = "모든 사람" },
	{ key = "friends", name = "친구만" },
	{ key = "me", name = "나만" },
}

function M.findDrink(key: any): Drink?
	if typeof(key) ~= "string" then return nil end
	for _, drink in ipairs(M.Drinks) do
		if drink.key == key then return drink end
	end
	return nil
end


return M

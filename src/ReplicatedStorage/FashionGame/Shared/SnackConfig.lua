--!strict
-- Shared shop system for cafes, snack stands, the OH24 convenience store and
-- the 국밥집 (CAFE.md §8, D-072, prices D-310..D-312, CAFE_PHOTO_PRICING.md):
-- one order → hand-held item → eat/drink loop, different menus per place.
--
-- Map: parts tagged "SnackShop" with attribute Shop = a key below (the
-- counter / truck window). The server puts an order prompt (E) on them; the
-- client shows the menu, grouped by `section`.
-- Price of an item: free, `coins`, or `product` (a Robux developer product,
-- MonetizationConfig.Products). `share` = a plate of that many portions that
-- is put on the nearest table and everyone may take one (like the club
-- bottles). Non-alcoholic only (D-043).

export type Item = {
	key: string,
	name: string,
	-- how it is held: "cup" | "cone" | "bar" | "bread" | "cake" | "bowl" |
	-- "bag" | "rice" (삼각김밥) | "ricebowl" | "noodle" | "bottle" | "parfait" | "plate"
	kind: string,
	color: Color3,
	topping: Color3?,
	coins: number?,
	product: string?,
	share: number?,
	bites: number?,
	section: string?,
	cake: string?, -- whole cake drawn from slice meshes: a key of SnackConfig.Cakes
}
export type Shop = { key: string, title: string, prompt: string, hint: string?, items: {Item} }

local SnackConfig = {}

SnackConfig.MaxCarried = 2
SnackConfig.Bites = 3 -- sips / licks before the item is finished
SnackConfig.ShopDistance = 16
SnackConfig.PlateSeconds = 600 -- a shared plate stays this long on the table
SnackConfig.PlateDistance = 30 -- the bought plate goes on a table this close

local FREE, T2, T3, RB = "무료", "💰 10", "💰 20", "Robux · 함께 나눠 먹기"

-- the cafe menu (D-310): the same tiers in the beach cafe
local CAFE_ITEMS: {Item} = {
	{ key = "water", name = "물", kind = "cup", color = Color3.fromRGB(205, 230, 245), section = FREE },
	{ key = "iceamericano", name = "아이스 아메리카노", kind = "cup", color = Color3.fromRGB(70, 40, 25), section = FREE },
	{ key = "latte", name = "카페라테", kind = "cup", color = Color3.fromRGB(210, 175, 135), coins = 10, section = T2 },
	{ key = "caramel", name = "카라멜 마끼아또", kind = "cup", color = Color3.fromRGB(200, 140, 80), coins = 10, section = T2 },
	{ key = "cappuccino", name = "카푸치노", kind = "cup", color = Color3.fromRGB(190, 150, 115), coins = 10, section = T2 },
	{ key = "saltbread", name = "소금빵", kind = "bread", color = Color3.fromRGB(215, 160, 95), coins = 10, section = T2 },
	{ key = "bagel", name = "베이글", kind = "bread", color = Color3.fromRGB(200, 150, 90), coins = 10, section = T2 },
	{ key = "tea", name = "얼그레이 티", kind = "cup", color = Color3.fromRGB(150, 90, 45), coins = 20, section = T3 },
	{ key = "smoothie", name = "딸기 스무디", kind = "cup", color = Color3.fromRGB(240, 110, 140), coins = 20, section = T3 },
	{ key = "frappe", name = "자바칩 프라푸치노", kind = "cup", color = Color3.fromRGB(120, 85, 65), topping = Color3.fromRGB(250, 250, 250), coins = 20, section = T3 },
	{ key = "bluelemonade", name = "블루 레몬에이드", kind = "cup", color = Color3.fromRGB(90, 190, 255), coins = 20, section = T3 },
	{ key = "croissant", name = "딸기 크림 크루아상", kind = "bread", color = Color3.fromRGB(220, 165, 90), topping = Color3.fromRGB(240, 90, 110), coins = 20, section = T3 },
	-- (strawberry cream cake: coins or Robux, at the end of tier 2, priced like
	-- the club's shared tier-2 bottles, user 2026-10-26)
	{ key = "cake_strawberry", name = "딸기생크림 케이크 (6조각)", kind = "cake", color = Color3.fromRGB(252, 248, 242), topping = Color3.fromRGB(230, 40, 60), coins = 100, product = "Cafe_CakeStrawberry", share = 6, cake = "strawberry", section = T2 },
	{ key = "honeybread", name = "허니카라멜브레드", kind = "cake", color = Color3.fromRGB(225, 170, 90), topping = Color3.fromRGB(250, 245, 235), coins = 20, section = T3 },
	{ key = "parfait", name = "딸기 파르페", kind = "parfait", color = Color3.fromRGB(245, 140, 165), topping = Color3.fromRGB(250, 245, 240), product = "Cafe_Parfait", bites = 5, section = "Robux" },
	{ key = "cake_vintage", name = "빈티지 레터링 케이크 (6조각)", kind = "cake", color = Color3.fromRGB(245, 170, 185), topping = Color3.fromRGB(252, 248, 240), product = "Cafe_CakeVintage", share = 6, cake = "vintage", section = RB },
	{ key = "cake_tiramisu", name = "티라미수 케이크 (6조각)", kind = "cake", color = Color3.fromRGB(150, 110, 80), topping = Color3.fromRGB(240, 230, 210), product = "Cafe_CakeTiramisu", share = 6, cake = "tiramisu", section = RB },
	{ key = "cake_basque", name = "바스크 치즈케이크 (6조각)", kind = "cake", color = Color3.fromRGB(240, 205, 140), topping = Color3.fromRGB(110, 60, 30), product = "Cafe_CakeBasque", share = 6, cake = "basque", section = RB },
}

SnackConfig.Shops = {
	BeachCafe = {
		key = "BeachCafe",
		title = "OHU CAFE · Sunset",
		prompt = "주문하기",
		items = CAFE_ITEMS,
	},
	HanokCafe = {
		key = "HanokCafe",
		title = "OHU 한옥카페",
		prompt = "주문하기",
		items = {
			{ key = "water", name = "물", kind = "cup", color = Color3.fromRGB(205, 230, 245), section = FREE },
			{ key = "barleytea", name = "보리차", kind = "cup", color = Color3.fromRGB(170, 110, 60), section = FREE },
			{ key = "sikhye", name = "식혜", kind = "cup", color = Color3.fromRGB(240, 225, 190), coins = 10, section = T2 },
			{ key = "yuja", name = "유자차", kind = "cup", color = Color3.fromRGB(255, 200, 60), coins = 10, section = T2 },
			{ key = "yakgwa", name = "약과", kind = "bread", color = Color3.fromRGB(165, 95, 40), coins = 10, section = T2 },
			{ key = "omija", name = "오미자에이드", kind = "cup", color = Color3.fromRGB(235, 70, 100), coins = 20, section = T3 },
			{ key = "greentea", name = "녹차라떼", kind = "cup", color = Color3.fromRGB(140, 190, 110), coins = 20, section = T3 },
			{ key = "injeolmi", name = "인절미 토스트", kind = "bread", color = Color3.fromRGB(225, 195, 120), coins = 20, section = T3 },
		},
	},
	IceCream = {
		key = "IceCream",
		title = "OHU 아이스크림 트럭",
		prompt = "아이스크림 사기",
		items = {
			{ key = "strawberry", name = "딸기", kind = "cone", color = Color3.fromRGB(255, 160, 190), coins = 15 },
			{ key = "vanilla", name = "바닐라", kind = "cone", color = Color3.fromRGB(255, 245, 215), coins = 15 },
			{ key = "mintchoco", name = "민트초코", kind = "cone", color = Color3.fromRGB(160, 235, 210), topping = Color3.fromRGB(70, 45, 30), coins = 15 },
			{ key = "chocolate", name = "초코", kind = "cone", color = Color3.fromRGB(120, 75, 50), coins = 15 },
		},
	},
	-- OH24 convenience store (D-311): cheap snacks, coins only, no alcohol / tobacco
	OH24 = {
		key = "OH24",
		title = "OH24 편의점",
		prompt = "계산하기",
		hint = "고른 상품을 바로 손에 들려 줘요. 컵라면은 창가 테이블에서 드세요!",
		items = {
			{ key = "water", name = "생수", kind = "bottle", color = Color3.fromRGB(190, 225, 250), coins = 1, section = "💰 1" },
			{ key = "icebar", name = "아이스크림 바", kind = "bar", color = Color3.fromRGB(255, 200, 215), topping = Color3.fromRGB(110, 70, 45), coins = 3, section = "💰 3" },
			{ key = "chips", name = "감자칩", kind = "bag", color = Color3.fromRGB(250, 205, 50), coins = 3, section = "💰 3" },
			{ key = "chocosnack", name = "초코 과자", kind = "bag", color = Color3.fromRGB(150, 60, 50), coins = 3, section = "💰 3" },
			{ key = "bananamilk", name = "바나나우유", kind = "bottle", color = Color3.fromRGB(255, 225, 110), coins = 3, section = "💰 3" },
			{ key = "soda", name = "탄산음료 캔", kind = "bottle", color = Color3.fromRGB(220, 50, 60), coins = 3, section = "💰 3" },
			{ key = "samgak", name = "삼각김밥", kind = "rice", color = Color3.fromRGB(250, 250, 245), coins = 3, section = "💰 3" },
			{ key = "cupnoodle", name = "컵라면", kind = "noodle", color = Color3.fromRGB(240, 80, 50), coins = 4, bites = 5, section = "💰 4" },
		},
	},
	-- 국밥집 "오후 돼지국밥" (D-311, D-314): a bowl to eat at the table
	Gukbap = {
		key = "Gukbap",
		title = "오후 돼지국밥",
		prompt = "주문하기",
		hint = "뚝배기를 들고 자리에 앉아서 드세요. 공깃밥·김치는 무료예요.",
		items = {
			{ key = "water", name = "물", kind = "cup", color = Color3.fromRGB(205, 230, 245), section = FREE },
			{ key = "rice", name = "공깃밥", kind = "ricebowl", color = Color3.fromRGB(252, 252, 248), section = FREE },
			{ key = "pork", name = "돼지국밥", kind = "bowl", color = Color3.fromRGB(235, 225, 205), coins = 20, bites = 6, section = T3 },
			{ key = "sundae", name = "순대국밥", kind = "bowl", color = Color3.fromRGB(205, 160, 130), coins = 20, bites = 6, section = T3 },
			{ key = "beef", name = "소고기국밥", kind = "bowl", color = Color3.fromRGB(190, 60, 40), coins = 20, bites = 6, section = T3 },
			{ key = "suyuk", name = "수육 한 접시 (6점)", kind = "plate", color = Color3.fromRGB(235, 205, 185), topping = Color3.fromRGB(150, 90, 70), product = "Gukbap_Suyuk", share = 6, section = RB },
		},
	},
} :: {[string]: Shop}

-- Whole cakes made of 6 slice meshes (ServerStorage.ArtAssets.CakeSlice, from
-- docs/04_ART/models/cake_slice.obj). textures: one is picked per cake (the
-- vintage cake comes in 4 colours, user photo 2026-10-26); deco: what sits on
-- the rim of each slice; lettering: text across the top while the cake is whole.
-- Atlases: docs/04_ART/textures/cake_*.png (scratchpad cake_tex.ps1).
export type Cake = { textures: {string}, deco: string?, decoColor: Color3?, lettering: {string}? }
SnackConfig.Cakes = {
	vintage = {
		textures = { "rbxassetid://0", "rbxassetid://0", "rbxassetid://0", "rbxassetid://0" }, -- pink / sky / teal / blue
		deco = "cherry",
		lettering = { "Happy Day", "HAPPY OHU DAY", "Sweet Day", "Thank you" },
	},
	strawberry = { textures = { "rbxassetid://0" }, deco = "strawberry" },
	tiramisu = { textures = { "rbxassetid://0" } },
	basque = { textures = { "rbxassetid://0" } },
} :: {[string]: Cake}

function SnackConfig.find(shopKey: any, itemKey: any): (Shop?, Item?)
	if typeof(shopKey) ~= "string" then return nil, nil end
	local shop = SnackConfig.Shops[shopKey]
	if not shop then return nil, nil end
	for _, item in ipairs(shop.items) do
		if item.key == itemKey then return shop, item end
	end
	return shop, nil
end

-- The shop and item a Robux product gives.
function SnackConfig.findProduct(productKey: string): (Shop?, Item?)
	for _, shop in pairs(SnackConfig.Shops) do
		for _, item in ipairs(shop.items) do
			if item.product == productKey then return shop, item end
		end
	end
	return nil, nil
end

return SnackConfig

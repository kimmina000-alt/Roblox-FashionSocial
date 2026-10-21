--!strict
-- Shared shop system for cafes and snack stands (CAFE.md §8, D-072): one
-- order → hand-held item → eat/drink loop, different menus per place.
--
-- Map: parts tagged "SnackShop" with attribute Shop = a key below (the
-- counter / truck window). The server puts an "주문하기" prompt (E) on them;
-- the client shows the menu. Items are free unless `coins` is set.
-- Non-alcoholic only (D-043).

export type Item = {
	key: string,
	name: string,
	kind: string, -- "cup" | "cone"
	color: Color3,
	topping: Color3?,
	coins: number?,
}
export type Shop = { key: string, title: string, items: {Item} }

local SnackConfig = {}

SnackConfig.MaxCarried = 2
SnackConfig.Bites = 3 -- sips / licks before the item is finished
SnackConfig.ShopDistance = 16

SnackConfig.Shops = {
	BeachCafe = {
		key = "BeachCafe",
		title = "OHU CAFE · Sunset",
		items = {
			{ key = "iceamericano", name = "아이스 아메리카노", kind = "cup", color = Color3.fromRGB(70, 40, 25) },
			{ key = "latte", name = "카페라떼", kind = "cup", color = Color3.fromRGB(210, 175, 135) },
			{ key = "bluelemonade", name = "블루 레몬에이드", kind = "cup", color = Color3.fromRGB(90, 190, 255) },
			{ key = "mango", name = "망고 스무디", kind = "cup", color = Color3.fromRGB(255, 190, 60) },
		},
	},
	HanokCafe = {
		key = "HanokCafe",
		title = "OHU 한옥카페",
		items = {
			{ key = "sikhye", name = "식혜", kind = "cup", color = Color3.fromRGB(240, 225, 190) },
			{ key = "omija", name = "오미자에이드", kind = "cup", color = Color3.fromRGB(235, 70, 100) },
			{ key = "yuja", name = "유자차", kind = "cup", color = Color3.fromRGB(255, 200, 60) },
			{ key = "greentea", name = "녹차라떼", kind = "cup", color = Color3.fromRGB(140, 190, 110) },
		},
	},
	IceCream = {
		key = "IceCream",
		title = "OHU 아이스크림 트럭",
		items = {
			{ key = "strawberry", name = "딸기", kind = "cone", color = Color3.fromRGB(255, 160, 190), coins = 15 },
			{ key = "vanilla", name = "바닐라", kind = "cone", color = Color3.fromRGB(255, 245, 215), coins = 15 },
			{ key = "mintchoco", name = "민트초코", kind = "cone", color = Color3.fromRGB(160, 235, 210), topping = Color3.fromRGB(70, 45, 30), coins = 15 },
			{ key = "chocolate", name = "초코", kind = "cone", color = Color3.fromRGB(120, 75, 50), coins = 15 },
		},
	},
} :: {[string]: Shop}

function SnackConfig.find(shopKey: any, itemKey: any): (Shop?, Item?)
	if typeof(shopKey) ~= "string" then return nil, nil end
	local shop = SnackConfig.Shops[shopKey]
	if not shop then return nil, nil end
	for _, item in ipairs(shop.items) do
		if item.key == itemKey then return shop, item end
	end
	return shop, nil
end

return SnackConfig

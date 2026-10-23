--!strict
-- OH24 convenience store goods (user 2026-10-23, docs/02_WORLDS/OH24_STORE.md).
-- One entry per product design. The store shelves (tools/graybox/
-- build_hongdae_layout.lua, "OH24 convenience store") place these in rows.
--
--   id     stable key (used in the design list and later for buying)
--   name   name printed on the placeholder pack
--   shape  pack shape (sizes in SHAPES below)
--   color  main pack colour of the placeholder
--   image  rbxassetid of the front artwork; "" until it is designed. When
--          set, the shelves show this image on the pack front instead of the
--          placeholder. Artwork size per shape: see SHAPES.art.
--
-- Names are made up on purpose: real brand packs and logos are trademarks and
-- can't be used in the game.

export type Product = { id: string, name: string, shape: string, color: Color3, image: string }

local OH24Products = {}

-- size = studs (width, height, depth); art = front artwork pixel size
OH24Products.SHAPES = {
	bag = { size = Vector3.new(1.25, 1.65, 0.5), art = "512x680" }, -- chip bags
	tube = { size = Vector3.new(0.75, 1.85, 0.75), art = "300x740" }, -- tube chips (front label)
	box = { size = Vector3.new(1.3, 1.05, 0.55), art = "512x420" }, -- biscuit / chocolate boxes
	candy = { size = Vector3.new(0.7, 0.85, 0.35), art = "280x340" }, -- gum, candy, jelly
	cup = { size = Vector3.new(1.05, 1.05, 1.05), art = "420x420" }, -- cup noodles
	bread = { size = Vector3.new(1.4, 0.9, 0.7), art = "560x360" }, -- bakery bags
	bottle = { size = Vector3.new(0.6, 1.6, 0.6), art = "240x300" }, -- PET bottles (label band)
	can = { size = Vector3.new(0.55, 1, 0.55), art = "220x260" }, -- drink cans (label)
	tri = { size = Vector3.new(1.1, 0.95, 0.4), art = "440x380" }, -- 삼각김밥 (triangle)
	lunch = { size = Vector3.new(1.6, 0.55, 1.1), art = "640x220" }, -- 도시락 (label on the lid front)
	milk = { size = Vector3.new(0.55, 1.1, 0.55), art = "220x440" }, -- milk / yogurt
	icecream = { size = Vector3.new(0.9, 0.3, 0.6), art = "360x240" }, -- ice cream (seen from above)
	goods = { size = Vector3.new(0.9, 1.3, 0.25), art = "360x520" }, -- gift cards, cables, hot packs
}

local function p(id: string, name: string, shape: string, r: number, g: number, b: number): Product
	return { id = id, name = name, shape = shape, color = Color3.fromRGB(r, g, b), image = "" }
end

-- category → products (the shelves cycle through a category's list)
OH24Products.CATEGORIES = {
	snack_bag = {
		p("chip_original", "바삭감자\n오리지널", "bag", 214, 40, 40),
		p("chip_sourcream", "바삭감자\n사워크림", "bag", 60, 150, 70),
		p("chip_honey", "바삭감자\n허니버터", "bag", 240, 190, 40),
		p("corn_butter", "콘스낵\n버터구이", "bag", 245, 170, 30),
		p("shrimp_snack", "새우스낵", "bag", 235, 110, 40),
		p("onion_ring", "양파링", "bag", 40, 120, 60),
		p("nacho_cheese", "나쵸\n치즈맛", "bag", 30, 30, 40),
		p("sweet_potato", "고구마칩", "bag", 120, 60, 140),
		p("popcorn_caramel", "팝콘\n카라멜", "bag", 200, 140, 60),
		p("tortilla_spicy", "토르티야\n매운맛", "bag", 180, 30, 30),
	},
	snack_tube = {
		p("tube_original", "튜브칩\n오리지널", "tube", 200, 40, 40),
		p("tube_sourcream", "튜브칩\n사워어니언", "tube", 50, 150, 70),
		p("tube_cheese", "튜브칩\n치즈", "tube", 240, 180, 30),
		p("tube_bbq", "튜브칩\n바베큐", "tube", 60, 40, 30),
		p("tube_pizza", "튜브칩\n피자", "tube", 240, 120, 40),
	},
	sweets_box = {
		p("choco_cake", "초코\n케이크", "box", 140, 30, 40),
		p("butter_cookie", "버터\n쿠키", "box", 60, 100, 200),
		p("choco_biscuit", "초코\n비스킷", "box", 90, 50, 30),
		p("strawberry_wafer", "딸기\n웨하스", "box", 240, 120, 150),
		p("salt_cracker", "소금\n크래커", "box", 230, 210, 140),
		p("pepero_stick", "초코\n스틱", "box", 220, 40, 50),
		p("energy_bar", "에너지바", "box", 120, 60, 160),
	},
	candy = {
		p("xylitol_gum", "자일껌", "candy", 40, 150, 80),
		p("mint_candy", "민트\n캔디", "candy", 40, 120, 220),
		p("fruit_jelly", "과일\n젤리", "candy", 240, 90, 120),
		p("bear_jelly", "곰젤리", "candy", 250, 190, 30),
		p("chewy_candy", "츄잉\n캔디", "candy", 150, 60, 190),
		p("sour_worm", "새콤\n지렁이", "candy", 60, 190, 200),
		p("lolipop", "막대\n사탕", "candy", 250, 120, 40),
	},
	noodle = {
		p("cup_spicy", "컵라면\n매운맛", "cup", 210, 30, 30),
		p("cup_mild", "컵라면\n순한맛", "cup", 240, 170, 40),
		p("cup_udon", "우동컵", "cup", 40, 90, 170),
		p("cup_jjajang", "짜장컵", "cup", 60, 40, 30),
		p("cup_kimchi", "김치\n컵라면", "cup", 200, 60, 40),
		p("cup_seafood", "해물\n컵라면", "cup", 40, 140, 170),
	},
	bread = {
		p("bread_milk", "우유식빵", "bread", 245, 235, 210),
		p("bread_cream", "크림빵", "bread", 250, 210, 150),
		p("bread_red_bean", "단팥빵", "bread", 160, 80, 60),
		p("bread_castella", "카스테라", "bread", 250, 200, 80),
	},
	drink_bottle = {
		p("water", "생수", "bottle", 120, 190, 240),
		p("ion_drink", "이온음료", "bottle", 40, 110, 210),
		p("cola", "콜라", "bottle", 60, 20, 20),
		p("cider", "사이다", "bottle", 60, 170, 80),
		p("orange_juice", "오렌지\n주스", "bottle", 250, 150, 30),
		p("green_tea", "녹차", "bottle", 90, 160, 60),
		p("barley_tea", "보리차", "bottle", 170, 120, 60),
		p("latte", "카페\n라떼", "bottle", 150, 100, 70),
		p("energy", "에너지\n드링크", "bottle", 30, 30, 40),
		p("peach_tea", "복숭아\n아이스티", "bottle", 250, 160, 140),
	},
	drink_can = {
		p("can_lemon", "레몬\n탄산", "can", 240, 220, 60),
		p("can_coffee", "캔커피", "can", 110, 70, 40),
		p("can_grape", "포도\n탄산", "can", 120, 50, 140),
		p("can_soda", "소다", "can", 80, 170, 230),
	},
	milk = {
		p("banana_milk", "바나나\n우유", "milk", 250, 220, 90),
		p("choco_milk", "초코\n우유", "milk", 120, 70, 40),
		p("strawberry_milk", "딸기\n우유", "milk", 250, 150, 170),
		p("white_milk", "흰우유", "milk", 240, 245, 250),
		p("yogurt", "요거트", "milk", 200, 220, 250),
	},
	fresh = {
		p("tri_tuna", "삼각김밥\n참치마요", "tri", 240, 240, 235),
		p("tri_bulgogi", "삼각김밥\n불고기", "tri", 240, 240, 235),
		p("tri_kimchi", "삼각김밥\n김치볶음", "tri", 240, 240, 235),
		p("sandwich", "샌드위치", "box", 250, 230, 200),
		p("kimbap", "김밥", "bread", 40, 60, 40),
	},
	lunch = {
		p("lunch_bulgogi", "불고기\n도시락", "lunch", 200, 80, 40),
		p("lunch_pork", "제육\n도시락", "lunch", 220, 60, 40),
		p("lunch_chicken", "치킨\n도시락", "lunch", 230, 150, 50),
	},
	icecream = {
		p("ice_bar_choco", "초코바", "icecream", 90, 50, 30),
		p("ice_bar_melon", "메론바", "icecream", 120, 200, 90),
		p("ice_cone", "콘 아이스", "icecream", 230, 60, 60),
		p("ice_fish", "붕어\n아이스", "icecream", 230, 180, 90),
		p("ice_cup", "컵 아이스", "icecream", 250, 170, 200),
	},
	goods = {
		p("gift_card", "기프트\n카드", "goods", 40, 40, 50),
		p("charge_cable", "충전\n케이블", "goods", 240, 240, 245),
		p("earphone", "이어폰", "goods", 30, 30, 35),
		p("hot_pack", "핫팩", "goods", 230, 80, 40),
		p("tissue", "휴대용\n티슈", "goods", 120, 190, 230),
		p("mask", "마스크", "goods", 245, 245, 250),
		p("battery", "건전지", "goods", 230, 160, 30),
	},
}

-- One picture per shelf row (user 2026-10-23: a whole row is one image, like
-- a shelf photo). Category → rbxassetid of a row image ("" = placeholder).
-- Size: 30 px per stud → a 16-stud gondola row ≈ 480 × 57 px; draw it wider
-- (e.g. 1600 × 190) for sharpness, products standing on the bottom edge.
OH24Products.ROW_IMAGES = {
	snack_bag = "", snack_tube = "", sweets_box = "", candy = "", noodle = "",
	bread = "", drink_bottle = "", drink_can = "", milk = "", fresh = "",
	lunch = "", goods = "",
}

return OH24Products

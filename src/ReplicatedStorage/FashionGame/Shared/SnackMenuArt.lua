--!strict
-- Pictures, one-line descriptions and window themes for the picture order
-- windows (ShopMenuUI; user 2026-10-31, from the user's cafe menu mock-up).
-- Pictures: our own drawings, tools/art/icons/dashboard_icons.html (menu_*),
-- docs/04_ART/menu_icons/, uploaded at 256 px.

local SnackMenuArt = {}

SnackMenuArt.Icons = {
	water = "rbxassetid://82620910785563",
	iceamericano = "rbxassetid://97098907105324",
	latte = "rbxassetid://80191139845473",
	caramel = "rbxassetid://127186253534571",
	cappuccino = "rbxassetid://112756956489595",
	saltbread = "rbxassetid://138957411859000",
	bagel = "rbxassetid://124397089041204",
	tea = "rbxassetid://92908390129194",
	smoothie = "rbxassetid://91161970033284",
	frappe = "rbxassetid://73772465186891",
	bluelemonade = "rbxassetid://140609360592357",
	croissant = "rbxassetid://113885586029710",
	cake_strawberry = "rbxassetid://138173379638460",
	honeybread = "rbxassetid://136759119745135",
	parfait = "rbxassetid://123581181009053",
	cake_vintage = "rbxassetid://114951080986976",
	cake_tiramisu = "rbxassetid://85809810617380",
	cake_basque = "rbxassetid://97565545800412",
	barleytea = "rbxassetid://102987503183254",
	sikhye = "rbxassetid://90326004267979",
	yuja = "rbxassetid://111075121554895",
	yakgwa = "rbxassetid://74425490587225",
	omija = "rbxassetid://121495335081297",
	greentea = "rbxassetid://124472440536755",
	injeolmi = "rbxassetid://136612208449015",
	rice = "rbxassetid://121528714601846",
	pork = "rbxassetid://129225504092655",
	sundae = "rbxassetid://134665477374241",
	beef = "rbxassetid://130774465841494",
	suyuk = "rbxassetid://86722270080544",
}

SnackMenuArt.Descriptions = {
	water = "시원한 물 한 잔",
	iceamericano = "깔끔하고 진한 커피의 맛!",
	latte = "부드러운 우유 거품 라테",
	caramel = "달콤한 카라멜이 듬뿍",
	cappuccino = "폭신한 거품 위 시나몬 향",
	saltbread = "겉바속촉 버터 소금빵",
	bagel = "쫄깃한 참깨 베이글",
	tea = "향긋한 베르가못 홍차",
	smoothie = "생딸기를 갈아 만든 스무디",
	frappe = "초코칩이 씹히는 시원한 한 잔",
	bluelemonade = "톡 쏘는 바다색 에이드",
	croissant = "딸기 크림을 채운 크루아상",
	cake_strawberry = "6조각 · 테이블에 놓고 함께 먹어요",
	honeybread = "카라멜 시럽에 생크림 한 스쿱",
	parfait = "딸기와 크림을 층층이 쌓은 파르페",
	cake_vintage = "6조각 · 레터링이 들어간 케이크",
	cake_tiramisu = "6조각 · 코코아 가득 티라미수",
	cake_basque = "6조각 · 겉은 탄 듯 속은 촉촉",
	barleytea = "구수한 보리차",
	sikhye = "밥알 동동 시원한 식혜",
	yuja = "새콤달콤 따뜻한 유자차",
	yakgwa = "꿀 바른 전통 약과",
	omija = "다섯 가지 맛 오미자 에이드",
	greentea = "쌉싸름한 녹차와 우유",
	injeolmi = "고소한 콩고물 듬뿍 토스트",
	rice = "갓 지은 공깃밥",
	pork = "뽀얀 사골 국물에 돼지고기 듬뿍",
	sundae = "순대와 머릿고기가 든 국밥",
	beef = "얼큰한 소고기 국밥",
	suyuk = "6점 · 테이블에 놓고 함께 먹어요",
}

-- the window looks. (2026-10-31, later) the windows are the club shop's dark
-- neon ones (NeonShopUI, ShopMenuUI): only accent, icon, subtitle and tabs
-- are used now; the pastel fields stay for the drawings' own pages.
export type Theme = {
	accent: Color3,
	icon: string,
	header: {Color3}, -- gradient left → right
	headerIcon: string,
	subtitle: string,
	body: {Color3}, -- gradient top → bottom
	edge: Color3,
	card: Color3,
	cardEdge: Color3,
	pick: Color3, -- picked card edge, tab and buy button
	pickText: Color3,
	tab: Color3,
	text: Color3,
	sub: Color3,
	price: Color3,
	tabs: {{ name: string, icon: string, kinds: {string} }},
}

local CAFE_TABS = {
	{ name = "음료", icon = "☕", kinds = { "cup" } },
	{ name = "디저트", icon = "🍰", kinds = { "cake", "parfait", "bread" } },
}

SnackMenuArt.Themes = {
	cafe = {
		accent = Color3.fromRGB(255, 130, 190), -- (rose pink next to the club's cyan / magenta)
		icon = "☕",
		header = { Color3.fromRGB(150, 98, 168), Color3.fromRGB(214, 140, 190) },
		headerIcon = "rbxassetid://71544648981150",
		subtitle = "음료와 디저트를 골라 자리에서 즐겨 보세요",
		body = { Color3.fromRGB(253, 240, 248), Color3.fromRGB(242, 224, 242) },
		edge = Color3.fromRGB(255, 190, 222),
		card = Color3.fromRGB(255, 248, 252),
		cardEdge = Color3.fromRGB(246, 214, 232),
		pick = Color3.fromRGB(240, 108, 160),
		pickText = Color3.new(1, 1, 1),
		tab = Color3.fromRGB(246, 230, 240),
		text = Color3.fromRGB(70, 46, 64),
		sub = Color3.fromRGB(150, 120, 140),
		price = Color3.fromRGB(70, 46, 64),
		tabs = CAFE_TABS,
	},
	gukbap = {
		accent = Color3.fromRGB(255, 140, 70), -- (warm orange, the 국밥집's red sign)
		icon = "🍲",
		header = { Color3.fromRGB(150, 32, 26), Color3.fromRGB(196, 72, 44) },
		headerIcon = "rbxassetid://87087800953873",
		subtitle = "뜨끈한 국밥 한 그릇, 자리에서 드세요",
		body = { Color3.fromRGB(252, 246, 232), Color3.fromRGB(242, 230, 206) },
		edge = Color3.fromRGB(214, 170, 120),
		card = Color3.fromRGB(255, 251, 242),
		cardEdge = Color3.fromRGB(232, 210, 176),
		pick = Color3.fromRGB(196, 56, 36),
		pickText = Color3.new(1, 1, 1),
		tab = Color3.fromRGB(244, 232, 210),
		text = Color3.fromRGB(70, 44, 30),
		sub = Color3.fromRGB(140, 110, 84),
		price = Color3.fromRGB(70, 44, 30),
		tabs = {
			{ name = "국밥", icon = "🍲", kinds = { "bowl" } },
			{ name = "곁들임", icon = "🍚", kinds = { "ricebowl", "plate", "cup" } },
		},
	},
} :: {[string]: Theme}

-- which shops open the picture window, with which look
SnackMenuArt.ShopTheme = {
	BeachCafe = "cafe",
	HanokCafe = "cafe",
	Gukbap = "gukbap",
}

return SnackMenuArt

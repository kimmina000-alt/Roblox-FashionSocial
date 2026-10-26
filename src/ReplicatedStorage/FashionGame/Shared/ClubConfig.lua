--!strict
-- Club MVP data (Stage 4): dance list, tempo range, club music.
--
-- Dances are Roblox-made catalog emotes (creator "Roblox"), so any experience
-- may play them. Each animationId below is the clip inside the emote package,
-- resolved once with InsertService:LoadAsset in Studio (2026-10-20) and checked
-- to load on a character. Branded emotes (artists, films, TV) are left out.
--
-- Music: free Creator Store audio from the licensed distributors
-- (DistrokidOfficial, APMOfficial), checked to load in Studio (2026-10-20).
-- Lengths are rounded down from Sound.TimeLength; the server advances tracks
-- by these lengths.

export type Dance = {
	key: string,
	name: string,
	category: string,
	animationId: number,
	looped: boolean,
}

export type Track = {
	channel: string,
	title: string,
	soundId: number,
	length: number,
}

local ClubConfig = {}

ClubConfig.Categories = { "댄스", "포즈·응원" }

ClubConfig.Dances = {
	{ key = "shuffle", name = "셔플", category = "댄스", animationId = 10714371274, looped = true },
	{ key = "line", name = "라인 댄스", category = "댄스", animationId = 10714383856, looped = true },
	{ key = "break", name = "브레이크", category = "댄스", animationId = 10714003221, looped = true },
	{ key = "floss", name = "플로스", category = "댄스", animationId = 10714340543, looped = true },
	{ key = "dorky", name = "코믹 댄스", category = "댄스", animationId = 10714069471, looped = true },
	{ key = "dolphin", name = "돌고래", category = "댄스", animationId = 10714068222, looped = true },
	{ key = "air", name = "에어 댄스", category = "댄스", animationId = 10713957138, looped = true },
	{ key = "swan", name = "스완", category = "댄스", animationId = 10714352930, looped = true },
	{ key = "baby", name = "베이비", category = "댄스", animationId = 10713983178, looped = true },
	{ key = "sandwich", name = "샌드위치", category = "댄스", animationId = 10714384494, looped = true },
	{ key = "samba", name = "삼바", category = "댄스", animationId = 10714386947, looped = true },
	{ key = "chacha", name = "차차", category = "댄스", animationId = 6862001787, looped = true },
	{ key = "toprock", name = "톱록", category = "댄스", animationId = 10714336041, looped = true },
	{ key = "sidetoside", name = "사이드 투 사이드", category = "댄스", animationId = 10714366910, looped = true },
	{ key = "aroundtown", name = "흔들흔들", category = "댄스", animationId = 10713981723, looped = true },
	{ key = "robot", name = "로봇", category = "댄스", animationId = 10714392151, looped = true },
	{ key = "rockon", name = "락 온", category = "댄스", animationId = 10714403700, looped = true },
	{ key = "idol", name = "아이돌", category = "댄스", animationId = 10714372526, looped = true },
	{ key = "hyper5g", name = "초고속 무브", category = "댄스", animationId = 10714371264, looped = true },
	{ key = "blockparty", name = "블록 파티", category = "댄스", animationId = 10713988674, looped = true },
	{ key = "twirl", name = "빙그르르", category = "댄스", animationId = 10714293450, looped = true },
	{ key = "fashionable", name = "패셔니스타", category = "포즈·응원", animationId = 10714091938, looped = true },
	{ key = "iceskate", name = "패션 스핀", category = "포즈·응원", animationId = 131669256082047, looped = true },
	{ key = "greatest", name = "내가 제일 잘 나가", category = "포즈·응원", animationId = 10714349037, looped = false },
	{ key = "heisman", name = "하이즈먼 포즈", category = "포즈·응원", animationId = 10714357129, looped = false },
	{ key = "jumpcheer", name = "환호 점프", category = "포즈·응원", animationId = 5895324424, looped = true },
	{ key = "applaud", name = "박수", category = "포즈·응원", animationId = 10713966026, looped = true },
	{ key = "hello", name = "안녕", category = "포즈·응원", animationId = 10714359093, looped = false },
	{ key = "highwave", name = "크게 손 흔들기", category = "포즈·응원", animationId = 10714362852, looped = true },
	{ key = "curtsy", name = "인사", category = "포즈·응원", animationId = 10714061912, looped = false },
	{ key = "celebrate", name = "축하", category = "포즈·응원", animationId = 10714016223, looped = true },
} :: {Dance}

ClubConfig.TempoMin = 0.5
ClubConfig.TempoMax = 2.0
ClubConfig.TempoStep = 0.1

-- How far away another player can be to show up under 같이 추기 (the panel
-- list). Clicking a player works anywhere inside the club.
ClubConfig.JoinRadius = 90

-- Shared club music. One track plays for everyone; the channel name is shown.
ClubConfig.Playlist = {
	{ channel = "EDM", title = "EDM Club Night", soundId = 136689162723802, length = 218 },
	{ channel = "POP", title = "Tomorrow Starts Now", soundId = 124325173394473, length = 205 },
	{ channel = "HIP-HOP", title = "Free", soundId = 128563409090413, length = 129 },
	{ channel = "EDM", title = "Run the Night", soundId = 129158012324844, length = 155 },
	{ channel = "POP", title = "Light It Up", soundId = 103356166395852, length = 187 },
	{ channel = "HIP-HOP", title = "Future Legend", soundId = 115846580489388, length = 189 },
	{ channel = "EDM", title = "Skyline Bounce", soundId = 132588706181756, length = 175 },
	{ channel = "POP", title = "No Gravity Tonight", soundId = 84501429041638, length = 200 },
	{ channel = "HIP-HOP", title = "Gomood", soundId = 92774322259700, length = 121 },
	{ channel = "EDM", title = "Midnight Frequency", soundId = 75257760347020, length = 156 },
	{ channel = "POP", title = "Under the Starlight", soundId = 101328005557095, length = 217 },
} :: {Track}

-- Music volume inside the club; it fades out over FadeDistance studs outside
-- the club zone (parts tagged "ClubZone").
ClubConfig.MusicVolume = 0.55
-- Short fade: outside the club building it is silent (user, 2026-10-20:
-- music starts in the narrow corridor, quiet on the stairs, full in the hall).
ClubConfig.FadeDistance = 6
-- Volume per club zone (ClubZone part attribute "Zone"). Inside a zone that
-- zone's level is used (the quietest when zones overlap); outside, the loudest
-- fade wins. The rooftop is quieter, like music coming up from below.
ClubConfig.ZoneVolumes = { Hall = 1, Corridor = 0.45, Stairs = 0.12, Rooftop = 0.3 }

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

-- Club light colours the DJ can pick (user, 2026-10-22: "보통 클럽에서 쓰는
-- 조명 색"). Lasers and beat lights use the colour; "rainbow" = colour cycle.
ClubConfig.LightColors = {
	{ key = "rainbow", name = "무지개", color = nil :: Color3? },
	{ key = "magenta", name = "마젠타", color = Color3.fromRGB(255, 40, 200) },
	{ key = "uv", name = "UV 보라", color = Color3.fromRGB(140, 60, 255) },
	{ key = "blue", name = "딥 블루", color = Color3.fromRGB(40, 80, 255) },
	{ key = "cyan", name = "시안", color = Color3.fromRGB(40, 230, 255) },
	{ key = "red", name = "레드", color = Color3.fromRGB(255, 40, 60) },
	{ key = "green", name = "그린 레이저", color = Color3.fromRGB(60, 255, 90) },
	{ key = "white", name = "화이트 스트로브", color = Color3.fromRGB(255, 255, 255) },
}
function ClubConfig.findLightColor(key: any)
	for _, entry in ipairs(ClubConfig.LightColors) do
		if entry.key == key then return entry end
	end
	return nil
end

-- Names and looks follow real drinks without using their brand names
-- (user list 2026-10-25; reference brand in the comment).
ClubConfig.Drinks = {
	-- tier 1
	{ key = "water", name = "물", tier = 1, color = Color3.fromRGB(190, 230, 255), look = "투명 페트병" },
	{ key = "cider", name = "사이다", tier = 1, coins = 1, color = Color3.fromRGB(200, 255, 200), look = "초록 라벨 페트병" },
	{ key = "cola", name = "콜라", tier = 1, coins = 1, color = Color3.fromRGB(70, 35, 20), look = "빨간 라벨 페트병" },
	{ key = "orange", name = "오렌지 소다", tier = 1, coins = 5, color = Color3.fromRGB(255, 140, 0), look = "주황 투명 병" },
	{ key = "lemonade", name = "레몬에이드", tier = 1, coins = 5, color = Color3.fromRGB(255, 232, 110), look = "노랑 투명 병" },
	{ key = "blueade", name = "블루에이드", tier = 1, coins = 5, color = Color3.fromRGB(70, 160, 255), look = "파랑 투명 병" },
	-- tier 2: 💰100 or 10 R$
	{ key = "ginger_brew", name = "진저 브루", tier = 2, coins = 100, product = "Drink_GingerBrew", -- Bundaberg
		color = Color3.fromRGB(150, 92, 40), look = "짧고 통통한 갈색 유리병" },
	{ key = "monte", name = "몬테 스파클링", tier = 2, coins = 100, product = "Drink_Monte", -- San Pellegrino
		color = Color3.fromRGB(40, 125, 65), look = "초록 유리병 · 빨간 별 라벨" },
	{ key = "french_lemonade", name = "프렌치 레모네이드", tier = 2, coins = 100, product = "Drink_FrenchLemonade", -- Lorina
		color = Color3.fromRGB(250, 238, 165), look = "철사 마개 유리병" },
	{ key = "golden_apple", name = "골든 애플 스파클링", tier = 2, coins = 100, product = "Drink_GoldenApple", -- Martinelli's
		color = Color3.fromRGB(232, 172, 48), look = "사과 모양 유리병" },
	{ key = "zzang_pop", name = "쨍팝", tier = 2, coins = 100, product = "Drink_ZzangPop", -- Poppi
		color = Color3.fromRGB(255, 90, 170), look = "쨍한 원색 캔",
		variants = {
			{ key = "pink", name = "핑크", color = Color3.fromRGB(255, 90, 170) },
			{ key = "lime", name = "라임", color = Color3.fromRGB(170, 240, 60) },
			{ key = "orange", name = "오렌지", color = Color3.fromRGB(255, 150, 40) },
		} },
	-- tier 2: 💰150 or 15 R$ (energy drinks)
	{ key = "hot_boost", name = "핫부스트", tier = 2, coins = 150, product = "Drink_HotBoost", -- Hot6
		color = Color3.fromRGB(255, 105, 30), look = "주황·빨강 불꽃 캔" },
	{ key = "green_claw", name = "그린 클로", tier = 2, coins = 150, product = "Drink_GreenClaw", -- Monster
		color = Color3.fromRGB(28, 30, 28), look = "검은 톨캔 · 초록 발톱" },
	{ key = "blue_wing", name = "블루 윙", tier = 2, coins = 150, product = "Drink_BlueWing", -- Red Bull
		color = Color3.fromRGB(60, 95, 200), look = "가늘고 긴 은색·파랑 캔" },
	-- tier 3: Robux only (VIP price products: 20% off)
	{ key = "stack_hydro", name = "스택 하이드로", tier = 3, product = "Drink_StackHydro", vipProduct = "Drink_StackHydro_VIP", -- Cadence
		color = Color3.fromRGB(232, 232, 238), look = "미니멀 단색 캔" },
	{ key = "pastel_splash", name = "파스텔 스플래시", tier = 3, product = "Drink_PastelSplash", vipProduct = "Drink_PastelSplash_VIP", -- La Croix
		color = Color3.fromRGB(250, 190, 222), look = "파스텔 물감 무늬 캔" },
	{ key = "skull_water", name = "스컬 캔 워터", tier = 3, product = "Drink_SkullWater", vipProduct = "Drink_SkullWater_VIP", -- Liquid Death
		color = Color3.fromRGB(18, 18, 20), look = "검정 톨캔 · 흰 해골" },
	-- VIP only (D-274)
	{ key = "golmok", name = "골목 공방 소다", tier = 3, vipOnly = true, product = "Drink_Golmok", -- On A Lark
		color = Color3.fromRGB(190, 160, 230), look = "작은 갈색 병 · 금색 왕관",
		variants = {
			{ key = "lavender", name = "레몬 라벤더", color = Color3.fromRGB(190, 160, 230) },
			{ key = "rose", name = "생강 장미", color = Color3.fromRGB(230, 160, 120) },
			{ key = "omija", name = "오미자 히비스커스", color = Color3.fromRGB(200, 40, 55) },
			{ key = "mulberry", name = "오디", color = Color3.fromRGB(80, 30, 92) },
		} },
} :: {Drink}

-- VIP pays this share of a coin price (20% off, D-270).
ClubConfig.VipCoinRate = 0.8
ClubConfig.TierNames = { "1단계 · 무료 / 코인", "2단계 · 코인 또는 Robux", "3단계 · 프리미엄 (Robux)" }

function ClubConfig.findVariant(drink: Drink, key: any): DrinkVariant?
	if not drink.variants then return nil end
	for _, variant in ipairs(drink.variants) do
		if variant.key == key then return variant end
	end
	return drink.variants[1]
end

-- Coin price for this player (VIP discount when vip is true).
function ClubConfig.coinPrice(drink: Drink, vip: boolean): number?
	if not drink.coins then return nil end
	if vip and drink.coins >= 10 then
		return math.floor(drink.coins * ClubConfig.VipCoinRate + 0.5)
	end
	return drink.coins
end

-- Bottles: carried as a tool, placed on a table, poured into cups.
ClubConfig.MaxBottlesCarried = 3
ClubConfig.BottleServings = 6        -- cups per bottle
ClubConfig.BottleLifetime = 600      -- seconds on a table before it is cleared
ClubConfig.MaxCupsCarried = 2
ClubConfig.DrinkSeconds = 2.6
ClubConfig.GulpSoundId = 9114172296   -- "Drinking Cu Gulping 9 (SFX)", Pro Sound Effects (Roblox licensed)

-- Who may pour from a placed bottle.
ClubConfig.Visibility = {
	{ key = "all", name = "모든 사람" },
	{ key = "friends", name = "친구만" },
	{ key = "me", name = "나만" },
}

function ClubConfig.findDrink(key: any): Drink?
	if typeof(key) ~= "string" then return nil end
	for _, drink in ipairs(ClubConfig.Drinks) do
		if drink.key == key then return drink end
	end
	return nil
end

function ClubConfig.findDance(key: any): Dance?
	if typeof(key) ~= "string" then return nil end
	for _, dance in ipairs(ClubConfig.Dances) do
		if dance.key == key then return dance end
	end
	return nil
end

function ClubConfig.clampTempo(speed: any): number
	if typeof(speed) ~= "number" or speed ~= speed then return 1 end
	local stepped = math.floor(speed / ClubConfig.TempoStep + 0.5) * ClubConfig.TempoStep
	return math.clamp(stepped, ClubConfig.TempoMin, ClubConfig.TempoMax)
end

local function insideTagged(tag: string, position: Vector3): boolean
	for _, box in ipairs(game:GetService("CollectionService"):GetTagged(tag)) do
		if box:IsA("BasePart") then
			local p = box.CFrame:PointToObjectSpace(position)
			local half = box.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- Inside the club (hall or rooftop): boxes tagged "ClubInterior" by the
-- graybox script. The 💃 button and tapping players only work in here.
-- Club entry only at night (CLUB.md §20, D-264 / D-267, code D-320). It is on
-- by itself once the game clock flows (DayNightConfig.FixedClockTime = nil);
-- while the clock is pinned for building, the club stays open.
ClubConfig.NightEntry = {
	Enabled = true,
	OpenHour = 18, -- 18:00 .. 06:00
	CloseHour = 6,
	-- where someone who walks in by day is put back: the sidewalk in front of the door
	ExitPosition = Vector3.new(41, 3.6, -186),
	DoorPosition = Vector3.new(46.5, 8, -186), -- the "opens in n min" sign
}

function ClubConfig.isNightOpen(clock: number): boolean
	local n = ClubConfig.NightEntry
	return clock >= n.OpenHour or clock < n.CloseHour
end

function ClubConfig.isInClub(position: Vector3): boolean
	return insideTagged("ClubInterior", position)
end

-- Dancing is allowed in the club and on photo booth stages ("PhotoStage"
-- boxes), where the 인생네컷 pose panel uses the same dances.
function ClubConfig.canDance(position: Vector3): boolean
	return insideTagged("ClubInterior", position) or insideTagged("PhotoStage", position)
end

-- How long a player must stay outside before their dance stops (doorways,
-- the rooftop elevator ride).
ClubConfig.OutsideGrace = 1.5

return ClubConfig

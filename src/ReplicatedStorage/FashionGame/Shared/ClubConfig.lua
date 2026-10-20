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
ClubConfig.FadeDistance = 45
-- Volume per club zone (ClubZone part attribute "Zone"). Inside a zone that
-- zone's level is used; outside, the loudest fade wins. The rooftop is
-- quieter, like music coming up from below (user, 2026-10-20).
ClubConfig.ZoneVolumes = { Hall = 1, Rooftop = 0.3 }

--------------------------------------------------
-- Drinks (non-alcoholic only, D-043). Test list from the user (2026-10-20):
-- free drinks first, paid drinks below. `product` = MonetizationConfig key.
-- NOTE: 사이다/콜라/환타 are placeholder names for testing; before release
-- replace brand names (환타) with generic ones (e.g. 오렌지 소다).
--------------------------------------------------

export type Drink = {
	key: string,
	name: string,
	color: Color3,
	product: string?,
}

ClubConfig.Drinks = {
	{ key = "water", name = "물", color = Color3.fromRGB(190, 230, 255) },
	{ key = "cider", name = "사이다", color = Color3.fromRGB(200, 255, 200) },
	{ key = "cola", name = "콜라", color = Color3.fromRGB(70, 35, 20) },
	{ key = "fanta", name = "환타", color = Color3.fromRGB(255, 140, 0), product = "Drink_Fanta" },
} :: {Drink}

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

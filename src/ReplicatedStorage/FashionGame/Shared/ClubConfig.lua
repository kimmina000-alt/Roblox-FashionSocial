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
	length: number, -- seconds of audio at x1
	baseSpeed: number?, -- its normal playback speed (default 1)
	volume: number?, -- its own music volume instead of MusicVolume (past 10: an equalizer boost)
	octave: number?, -- a PitchShiftSoundEffect octave on it (1 = none)
	-- the values the user tuned by ear in the turntable lab (test place
	-- 86558282086977, tools/test_places/turntable_lab, DataStore
	-- TurntableLabSettings "v1"; D-680). When set it replaces baseSpeed /
	-- volume / octave. humHz / hissHz / gate only work on the lab's "audio"
	-- engine and are kept for the record; the club plays a Sound.
	lab: Lab?,
	-- the song's choreography (D-689): animation ids played one after another
	-- from the start of the song, each danced to the song as heard in the club
	-- (so at x1; the DJ's speed carries over). Players in the club get a
	-- "안무 따라하기" button while it plays (ChoreoController). An entry is an
	-- animation id (it starts where the one before ends) or { id = .., at = .. }
	-- (it starts `at` seconds into the song, as heard in the club). `stop` (D-804)
	-- ends that one early, `stop` seconds into the song: the dancer stands still
	-- and the next one starts on time, as if this one had played to its end.
	-- `blend` (D-807) = seconds to ease into this one from the pose before
	-- (0.25 if not given; tools/choreo/choreo_check.lua suggests it).
	-- `from` (D-810) = seconds into the animation to start from (skips its
	-- start; with `stop` on the entry before, this cuts a stretch out).
	choreo: {any}?,
	-- (D-726) dance the choreography by itself: everyone in the club standing
	-- still (not seated, not in a menu dance) follows it while the song plays
	autoChoreo: boolean?,
}
export type Lab = {
	speed: number, tempo: number, volume: number, boost: number, octave: number,
	low: number, mid: number, high: number,
	humHz: number?, hissHz: number?, gate: number?, engine: string?,
}

local ClubConfig = {}

-- (D-811, user: "미세하게 바들바들 떨리는 부분 보정 … 멀쩡한 안무까지 수정하지
-- 말고") the choreography animations are captured at 24 keyframes a second
-- with small back-and-forth zigzags in the joints. ChoreoSmooth eases only
-- the keyframes where a joint goes back and forth by less than `maxStep`
-- degrees (`passes` times); the rest of the dance stays exactly as made.
-- nil = off.
ClubConfig.ChoreoSmoothing = { maxStep = 8, passes = 4 } :: { maxStep: number, passes: number }?

-- (D-817) a dancer following a choreography walks its dance path (D-813),
-- and is eased back toward where the dance began over about this many
-- seconds, so the drift the pieces add up to does not carry them off the
-- floor. nil = no easing back.
ClubConfig.ChoreoDriftReturn = 8 :: number?

-- Skip vote (user 2026-11-01, D-694): votes needed to skip the song while
-- there is no DJ = half the people in the club, rounded up, and at least 2
-- once two or more are there (alone: your own vote is enough)
function ClubConfig.skipVotesNeeded(peopleInClub: number): number
	if peopleInClub <= 1 then return 1 end
	return math.max(2, math.ceil(peopleInClub / 2))
end

-- 🧪 (user 2026-11-01) the "Bubble Pop 틀기" test button in the club, for
-- trying the choreography on a phone: shown in Studio and, on live servers,
-- to the experience owner's account only. Set to false before the launch.
ClubConfig.TestChoreoButton = false -- (off 2026-11-01, user: "아래 테스트 삭제")
function ClubConfig.canTestChoreo(player: Player): boolean
	if not ClubConfig.TestChoreoButton then return false end
	if game:GetService("RunService"):IsStudio() then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- The lab's apply(): the PlaybackSpeed really sent (speed × tempo, Roblox
-- stops at 20) and the PitchShift octave (octave ÷ the tempo that got
-- through: tempo is speed with the pitch put back, 1/32..32)
function ClubConfig.labEffective(lab: Lab): (number, number)
	local playSpeed = math.min(lab.speed * lab.tempo, 20)
	local tempo = playSpeed / lab.speed
	return playSpeed, math.clamp(lab.octave / tempo, 1 / 32, 32)
end

-- One PitchShiftSoundEffect reaches 0.5..2: a bigger octave is split into n
-- equal parts, n = ceil(|log2 octave|), at most 5 (the lab's octaveParts)
function ClubConfig.octaveParts(t: number): {number}
	if t >= 0.5 and t <= 2 then return { t } end
	local n = math.clamp(math.ceil(math.abs(math.log(t, 2)) - 1e-6), 1, 5)
	local part = t ^ (1 / n)
	local list = {}
	for i = 1, n do list[i] = part end
	return list
end

-- the name shown for a track: a 🎵 when its choreography is danced
-- (autoChoreo; Bubble Pop's older one is kept but not danced) (D-731).
-- (D-756, user: in front of the title and smaller) Rich text: the label needs
-- RichText = true; textSize = the label's TextSize (the mark is 70 % of it).
local function escape(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
ClubConfig.escapeRich = escape
function ClubConfig.showTitle(track: Track, textSize: number?): string
	local title = escape(track.title)
	if not (track.choreo and track.autoChoreo) then return title end
	return string.format('<font size="%d">🎵</font> %s', math.floor((textSize or 14) * 0.7 + 0.5), title)
end

-- how fast a track's audio runs: its own base speed (or its lab
-- PlaybackSpeed) times the DJ's speed
function ClubConfig.trackRate(track: Track?, djSpeed: any): number
	local base = if track and track.lab then (ClubConfig.labEffective(track.lab))
		elseif track and track.baseSpeed then track.baseSpeed else 1
	return base * (if typeof(djSpeed) == "number" then djSpeed else 1)
end

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

-- (D-745, user: "숨겨 놔, 나중에 쓸 거임") the lab values the user tuned by ear
-- for their own sped-up uploads (docs/04_ART/OLD_CLUB_PLAYLIST.md). Used again
-- by the user's K-POP uploads since D-755.
-- (D-765, user 2026-11-03: boost 3, no EQ; was boost 6, low -6 / mid 0.5 / high -7)
ClubConfig.SavedLabs = {
	userUpload = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" },
} :: {[string]: Lab}
local UP = ClubConfig.SavedLabs.userUpload

-- Shared club music. One track plays for everyone; the channel name is shown.
-- (user 2026-11-02, D-739: only Roblox's own licensed music — DistroKid on the
-- Creator Store, offered by Roblox — every K-POP upload before taken out; the
-- Bubble Pop / Get A Guitar choreographies went with them; D-755: the user's
-- K-POP uploads back after them, with the saved lab values.)
-- (D-745, user: default sound, no lab values: they play as uploaded at
-- ClubConfig.MusicVolume, the DJ's 🔊 slider on top)
ClubConfig.Playlist = {
	{ channel = "K-POP", title = "K-Pop Party", soundId = 135361546383974, length = 145 },
	{ channel = "K-POP", title = "K-pop Cute Crush", soundId = 121416896999522, length = 108 },
	{ channel = "K-POP", title = "K-Pop Uprising", soundId = 72966738276299, length = 130 },
	{ channel = "K-POP", title = "Push & Pull (밀당의 고수)", soundId = 132502088493185, length = 140 },
	{ channel = "K-POP", title = "Secret Party", soundId = 75682100037866, length = 146 },
	{ channel = "K-POP", title = "Luminous Dance", soundId = 123336690588412, length = 163 },
	{ channel = "EDM", title = "LIGHT UP THE NIGHT", soundId = 102534983754242, length = 235 },
	{ channel = "EDM", title = "RUN THE NIGHT", soundId = 123336998544849, length = 218 },
	{ channel = "EDM", title = "ECHOES OF THE BASS", soundId = 134070050316863, length = 203 },
	{ channel = "DISCO", title = "Disco Inferno", soundId = 87243738678545, length = 135 },
	{ channel = "EDM", title = "Festival Fever", soundId = 136228548293465, length = 103 },
	{ channel = "EDM", title = "Euphoria Dance", soundId = 76814968175069, length = 99 },
	-- (D-755, user 2026-11-02: "음원도 추가해라", the saved lab values on all of
	-- them) the user's K-POP uploads: the 9 from before D-739 with their
	-- choreographies, and 20 new. length = seconds at x1 (heard: ÷ 0.335).
	-- (D-766: the user's per-track lab values on 10; D-767: 16 uploads taken out,
	-- 13 left)
	{ channel = "K-POP", title = "ATEEZ-BAD", soundId = 134942349436280, length = 51, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 2.5, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "소녀시대-소원을 말해봐(Genie)", soundId = 128270208751659, length = 76, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 2.5, octave = 0.5, low = -5, mid = 2, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "현아-Bubble Pop", soundId = 76388700698178, length = 71, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 2.5, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" }, choreo = { 100736920067826, 133384041896194, 83466816721074, 133279932519664, 106558407160210, 80189218624271, 74977996210534, 128213782788357, 133713883432071, 79851078896686, 85867632664929 } },
	{ channel = "K-POP", title = "RIIZE-Get A Guitar", soundId = 91762270038050, length = 54, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -7, mid = -3, high = 1.5, engine = "sound" }, choreo = {
		-- (D-807, user: "이음새도 맞춰") blend = seconds to ease from the last pose
		-- into this one, from tools/choreo/choreo_check.lua (0.25 if not given)
		119819611123433, { id = 97097804325917, blend = 0.7 }, { id = 119200924904137, blend = 0.45 }, 77403973851668,
		{ id = 73939357849033, blend = 0.45 }, { id = 137390866303201, blend = 0.7 }, { id = 121969021575883, blend = 0.45 },
		{ id = 92148657532352, blend = 0.8 }, { id = 96742563282745, stop = 70, blend = 0.4 },
		{ id = 96742563282745, at = 70, from = 5.17, blend = 0.9 }, { id = 88430566939812, blend = 0.9 },
		{ id = 108795638313983, blend = 0.7 }, { id = 95813030011960, blend = 0.45 }, { id = 135272998171625, blend = 0.4 },
		129447992418977, { id = 82252722293006, blend = 0.55 }, 108611133102309, 117244778152210, 113505968174557, 112498417388469,
		{ id = 80874196383963, blend = 0.45 } }, autoChoreo = true }, -- (D-810, user: 2 s of 9 cut at 1:10, the rest moved up 2 s)
	{ channel = "K-POP", title = "RIIZE-Love 119", soundId = 119473981131981, length = 58, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -7, mid = -3, high = 1.5, engine = "sound" } },
	{ channel = "K-POP", title = "YENA-Catch Catch", soundId = 80583279340768, length = 61, lab = { speed = 1, tempo = 0.34, volume = 10, boost = 3, octave = 0.5, low = -13, mid = 2.5, high = 4, engine = "sound" } },
	{ channel = "K-POP", title = "Hearts2Hearts-Lemon Tang", soundId = 97032815457241, length = 54, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "aespa-Lemonade", soundId = 132067415333401, length = 62, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -11, mid = 0, high = -2.5, engine = "sound" } },
	{ channel = "K-POP", title = "IVE-Mirror", soundId = 139326796173276, length = 67, lab = { speed = 1, tempo = 0.332, volume = 10, boost = 3, octave = 0.5, low = -10.5, mid = 5, high = 4.5, engine = "sound" } },
	-- (D-779, user 2026-11-03: new uploads "다섯시…분1102"; tempo = x1 length ÷ heard length, boost 3, -3/2/0)
	{ channel = "K-POP", title = "A2O LITE-NEON", soundId = 97511700575810, length = 74, lab = { speed = 1, tempo = 0.332, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" }, choreo = {
		-- (D-809, user: 22 pieces, blends from tools/choreo/choreo_check.lua)
		118329772913374, { id = 95449015545787, blend = 0.64 }, { id = 84806571273074, blend = 0.92 }, { id = 99868719395147, blend = 0.5 },
		{ id = 93933273398995, blend = 0.96 }, 128256391320572, { id = 114466589507598, blend = 0.79 }, { id = 84027575690735, blend = 1 },
		{ id = 100410498984971, blend = 0.76 }, { id = 124518142645731, blend = 0.59 }, { id = 126736648781925, blend = 0.42 },
		{ id = 76437753036430, blend = 0.56 }, { id = 136355327951443, blend = 0.67 }, { id = 117451819045051, blend = 0.47 },
		{ id = 111932052760637, blend = 0.74 }, { id = 133401623277764, blend = 0.7 }, { id = 96973609514230, blend = 0.55 },
		{ id = 106546379406531, blend = 1 }, { id = 73851407273132, blend = 1 }, { id = 71570705300325, blend = 1 },
		{ id = 121393866689759, blend = 0.54 }, 114419952125075 }, autoChoreo = true }, -- (D-795 / D-796 old single piece removed)
	{ channel = "K-POP", title = "SOYEON-퇴사할게여", soundId = 96358497474432, length = 71, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "ILLIT-체포하겠어", soundId = 139044453511745, length = 61, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = -1.5, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "RESCENE-LOVE-ATTACK", soundId = 71873496902418, length = 61, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = -11, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "MY:RAKL-오색 낙원", soundId = 108027306922001, length = 61, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "Darla Jean-Dam Da Dee", soundId = 78077595750886, length = 73, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "머무르-꿈꾸던 어른이 되었나요", soundId = 120160897793669, length = 69, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "IVE-Looks Can Kill", soundId = 135553051649506, length = 64, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, choreo = {
		-- (D-826, user: the first 7 pieces, more later; blends from tools/choreo/choreo_check.lua)
		104472985141273, { id = 100762274305324, blend = 0.8 }, { id = 92352840963540, blend = 0.83 }, { id = 73035150280152, blend = 0.98 },
		{ id = 77509133314202, blend = 0.31 }, { id = 109736190348459, blend = 0.84 }, { id = 120841071882545, blend = 1 } }, autoChoreo = true },
	{ channel = "K-POP", title = "IOI-갑자기", soundId = 73546697163709, length = 65, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 2.4, octave = 0.5, low = -9.5, mid = 6, high = 0, engine = "sound" } },
	-- (D-768, user 2026-11-03: new uploads; tempo = x1 length ÷ heard length 3:20 / 3:05)
	{ channel = "K-POP", title = "NMIXX-긴 소원(Birthday Wish)", soundId = 107782871991364, length = 67, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "NCT WISH-I SPY", soundId = 90694654380166, length = 62, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	-- (D-782, user 2026-11-03: new uploads "여섯시…분1102", the same way as D-779; 여섯시이분 TAEYEON-만찬가 103785084548518 does not load yet;
	-- D-794: IU-이 별로부터 96396723842714 removed, user)
	{ channel = "K-POP", title = "CORTIS-REDRED", soundId = 125703446596781, length = 54, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "BIG Naughty-노스탈지아", soundId = 116539470869444, length = 65, lab = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "BIGBANG-BiiiG", soundId = 113809029583519, length = 55, lab = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
	{ channel = "K-POP", title = "BOYNEXTDOOR-ANIMAL", soundId = 130804487358433, length = 48, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" } },
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
ClubConfig.ZoneVolumes = { Hall = 1, Corridor = 0.45, Stairs = 0.12, Rooftop = 0.3, Locker = 0.5 }
-- (D-834, user) more music zones as world boxes, beside the tagged ClubZone
-- parts: the locker room and its passage (tools/graybox/club_locker_1103.lua,
-- under the 국밥집 lot, x 131.6..231, z -365..-289.9, floor -24, ceiling -3)
ClubConfig.ExtraZones = {
	{ zone = "Locker", min = Vector3.new(130, -24, -366.6), max = Vector3.new(232.6, -3, -289.9) },
}
-- (D-834, user) silent boxes: no club music inside them, even a fade from a
-- zone next door (the 국밥집 stands right over the locker room and by the club's
-- north wall). From y -2: the locker room's ceiling is at -3.
ClubConfig.QuietBoxes = {
	{ min = Vector3.new(39, -2, -377), max = Vector3.new(159, 46, -291) }, -- 국밥집 (Hongdae_Layout.Gukbap)
}

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
-- (user list 2026-10-25; reference brand in the comment). Bottle shapes:
-- BottleShapes (user sheet 2026-10-27).
ClubConfig.Drinks = {
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
-- (no real carry limit for guests, user 2026-10-27, D-430: extra items wait
-- in the backpack; only cafe staff on shift keep a two-in-hand limit)
ClubConfig.MaxBottlesCarried = 99
ClubConfig.BottleServings = 6        -- cups per bottle
ClubConfig.BottleLifetime = 600      -- seconds on a table before it is cleared (tier 1)
-- (user 2026-10-30) the dearer the drink, the longer it stays: tier 1 10 min,
-- tier 2 20, tier 3 30, VIP drinks 1 hour (still gone when the owner leaves)
function ClubConfig.bottleLifetime(drink: any): number
	if drink and drink.vipOnly then return 60 * 60 end
	local tier = drink and drink.tier or 1
	return if tier >= 3 then 30 * 60 elseif tier == 2 then 20 * 60 else ClubConfig.BottleLifetime
end
ClubConfig.MaxCupsCarried = 99
ClubConfig.DrinkSeconds = 2.6
ClubConfig.GulpSoundId = 9114172296   -- "Drinking Cu Gulping 9 (SFX)", Pro Sound Effects (Roblox licensed)

-- DJ sound controls (user 2026-10-30): the playback speed, cycled by a
-- button like the laser speed, and the pitch, up / down in the same steps
-- (user 2026-10-30, in place of the treble / bass boosts). The pitch is the
-- one heard: a PitchShiftSoundEffect makes up for what the speed does to it
-- (its octave = pitch / speed, 0.25..4 with two effects in a row).
-- (user 2026-10-30, later) finer steps: speed x0.25..x2 by 0.05, pitch
-- x0.5..x2 by 0.1, both with − / + buttons.
local function steps(from: number, to: number, step: number): {number}
	local list = {}
	for i = 0, math.floor((to - from) / step + 0.5) do
		table.insert(list, math.floor((from + i * step) * 100 + 0.5) / 100)
	end
	return list
end
-- (user 2026-11-01, later: all three up to x5)
ClubConfig.MusicSpeeds = steps(0.25, 5, 0.05)
ClubConfig.MusicPitches = steps(0.5, 5, 0.1)
-- (user 2026-11-01) the DJ's mixer on the turntable: speed, volume and the
-- PitchShift octave, each with − / +. The volume is a multiplier on the
-- track's own volume (0 = silent .. x2); the pitch is now the octave itself
-- (times the track's own octave), no longer made up for the speed.
ClubConfig.MusicVolumes = steps(0, 5, 0.1)

-- the place in a list nearest to a value (an old setting between two steps)
function ClubConfig.nearestStep(list: {number}, value: any): number
	local v = if typeof(value) == "number" then value else 1
	local best, bestDiff = 1, math.huge
	for i, x in ipairs(list) do
		if math.abs(x - v) < bestDiff then best, bestDiff = i, math.abs(x - v) end
	end
	return best
end

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
	-- (on again, user 2026-10-30: the club opens only at night; was off for testing since 2026-10-27)
	Enabled = true,
	OpenHour = 18, -- 18:00 .. 06:00
	CloseHour = 6,
	-- where someone who walks in by day is put back: the sidewalk in front of the door
	-- (layout v8, 2026-10-27: the club moved 24 north, door z -186 → -210)
	ExitPosition = Vector3.new(41, 3.6, -210),
	DoorPosition = Vector3.new(46.5, 8, -210), -- the "opens in n min" sign
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

-- Where the 불꽃 판매원 stands, from the BartenderSpot (its +X runs along the
-- bar, its look faces the room). D-750, user's live screenshot: by the north
-- wall, just east of the hall doorway to the VIP stairs (world about 128,
-- -270), facing into the room. Before: 8 along the bar (76, -170).
ClubConfig.ItemSellerOffset = CFrame.new(-92, 0, -52) * CFrame.Angles(0, -math.pi / 2, 0)

-- A table (bottles, sparkler bucket) stays this long after its owner leaves the
-- game, so a quick rejoin finds it still theirs (D-770, user: 2-3 min, not
-- cleared at once). DrinkService / SparkleService.
ClubConfig.TableKeepSeconds = 180

return ClubConfig

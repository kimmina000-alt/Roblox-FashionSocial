--!strict
-- (D-888, user 2026-11-05: ClubConfig split up, one file per kind) The dance menu: categories, dances, tempo range, join radius.
-- ClubConfig re-exports every field below, so ClubConfig.Dances keeps working.

export type Dance = {
	key: string,
	name: string,
	category: string,
	animationId: number,
	looped: boolean,
}

local M = {}

-- (D-1341, user 2026-11-13: more dances from the catalog: 9 Roblox emotes and every
-- official K-POP emote, played in Studio first; each loads in this experience)
M.Categories = { "댄스", "K-POP", "포즈·응원" }

M.Dances = {
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
	-- (D-1341) Roblox emotes (catalog 3934988903 / 4272351660 / 7466046574 / 3570649048 /
	-- 4646306072 / 79312439851071 / 7422841700 / 7422843994)
	{ key = "fancyfeet", name = "팬시 피트", category = "댄스", animationId = 10714076981, looped = true },
	{ key = "fasthands", name = "빠른 손", category = "댄스", animationId = 10714100539, looped = true },
	{ key = "quietwaves", name = "잔잔한 물결", category = "댄스", animationId = 10714390497, looped = true },
	{ key = "jacks", name = "점핑 잭", category = "댄스", animationId = 10714375667, looped = true },
	{ key = "keepingtime", name = "박자 타기", category = "댄스", animationId = 10714380563, looped = true },
	{ key = "hottogo", name = "HOT TO GO!", category = "댄스", animationId = 85267023718407, looped = true },
	{ key = "outside", name = "온 더 아웃사이드", category = "댄스", animationId = 10714392953, looped = true },
	{ key = "updown", name = "업 앤 다운", category = "댄스", animationId = 10714174918, looped = true },
	-- (D-1341) official K-POP emotes, made by the agencies (SMTOWN: NCT 127 catalog
	-- 12259888240 / 12804173616 / 12259885838 / 12259890638; JYP: TWICE 103776063641440;
	-- the mic drop 14024722653)
	{ key = "nct_kickit", name = "NCT 127 Kick It", category = "K-POP", animationId = 12259826609, looped = true },
	{ key = "nct_ayyo", name = "NCT 127 Ay-Yo", category = "K-POP", animationId = 12804157977, looped = true },
	{ key = "nct_sticker", name = "NCT 127 Sticker", category = "K-POP", animationId = 12259825026, looped = true },
	{ key = "nct_2baddies", name = "NCT 127 2 Baddies", category = "K-POP", animationId = 12259828678, looped = true },
	{ key = "twice_knock", name = "TWICE Knock Knock", category = "K-POP", animationId = 114440548313112, looped = true },
	{ key = "micdrop", name = "마이크 드롭", category = "K-POP", animationId = 14024642130, looped = false },
	{ key = "fashionable", name = "패셔니스타", category = "포즈·응원", animationId = 10714091938, looped = true },
	{ key = "iceskate", name = "패션 스핀", category = "포즈·응원", animationId = 131669256082047, looped = true },
	{ key = "greatest", name = "내가 제일 잘 나가", category = "포즈·응원", animationId = 10714349037, looped = false },
	{ key = "heisman", name = "하이즈먼 포즈", category = "포즈·응원", animationId = 10714357129, looped = false },
	{ key = "louder", name = "더 크게", category = "포즈·응원", animationId = 10714385204, looped = true }, -- (D-1341, catalog 3576751796)
	{ key = "jumpcheer", name = "환호 점프", category = "포즈·응원", animationId = 5895324424, looped = true },
	{ key = "applaud", name = "박수", category = "포즈·응원", animationId = 10713966026, looped = true },
	{ key = "hello", name = "안녕", category = "포즈·응원", animationId = 10714359093, looped = false },
	{ key = "highwave", name = "크게 손 흔들기", category = "포즈·응원", animationId = 10714362852, looped = true },
	{ key = "curtsy", name = "인사", category = "포즈·응원", animationId = 10714061912, looped = false },
	{ key = "celebrate", name = "축하", category = "포즈·응원", animationId = 10714016223, looped = true },
} :: {Dance}

-- (D-1343, user 2026-11-13: "모두 넣어") a phrase of each club song's choreography as its
-- own dance in the 안무 tab: the pieces from `from` to `to` (seconds of the original song,
-- the clock of ClubPlaylist's `at`) played by ChoreoController with all its fixes, over and
-- over, without the music. First guesses around each song's first chorus: change from / to
-- here (Lemonade-aespa is left out: its choreography is hidden, D-1338)
M.PhraseTab = "안무"
M.ChoreoPhrases = {
	{ key = "phrase_134942349436280", name = "BAD", soundId = 134942349436280, from = 45.78, to = 68 }, -- BAD-ATEEZ 0:45.8-1:08.0
	{ key = "phrase_128270208751659", name = "소원을 말해봐", soundId = 128270208751659, from = 58.39, to = 81.85 }, -- 0:58.4-1:21.8
	{ key = "phrase_70738014182544", name = "Get A Guitar", soundId = 70738014182544, from = 47.92, to = 64.75 }, -- 0:47.9-1:04.8
	{ key = "phrase_85204387077332", name = "Love 119", soundId = 85204387077332, from = 46.37, to = 62.44 }, -- 0:46.4-1:02.4
	{ key = "phrase_80583279340768", name = "Catch Catch", soundId = 80583279340768, from = 48.27, to = 66.27 }, -- 0:48.3-1:06.3
	{ key = "phrase_97032815457241", name = "Lemon Tang", soundId = 97032815457241, from = 49.8, to = 65 }, -- 0:49.8-1:05.0
	{ key = "phrase_140713297574648", name = "NEON", soundId = 140713297574648, from = 72.27, to = 87.58 }, -- 1:12.3-1:27.6
	{ key = "phrase_139044453511745", name = "체포하겠어", soundId = 139044453511745, from = 48.52, to = 66.52 }, -- 0:48.5-1:06.5
	{ key = "phrase_139330220515727", name = "LOVE ATTACK", soundId = 139330220515727, from = 46.68, to = 64.68 }, -- 0:46.7-1:04.7
	{ key = "phrase_135553051649506", name = "Looks Can Kill", soundId = 135553051649506, from = 57.08, to = 75.23 }, -- 0:57.1-1:15.2
	{ key = "phrase_75344866720031", name = "갑자기", soundId = 75344866720031, from = 56.4, to = 74.7 }, -- 0:56.4-1:14.7
	{ key = "phrase_98124521559769", name = "I SPY", soundId = 98124521559769, from = 49.27, to = 72.27 }, -- 0:49.3-1:12.3
	{ key = "phrase_76034005809699", name = "REDRED", soundId = 76034005809699, from = 48.43, to = 65.27 }, -- 0:48.4-1:05.3
	{ key = "phrase_94774089824958", name = "ANIMAL", soundId = 94774089824958, from = 39.86, to = 63.36 }, -- 0:39.9-1:03.4
	{ key = "phrase_89634330677538", name = "Pretty Girl", soundId = 89634330677538, from = 58.03, to = 79.58 }, -- 0:58.0-1:19.6
	{ key = "phrase_131620527618857", name = "Pop Off", soundId = 131620527618857, from = 45.3, to = 63.3 }, -- 0:45.3-1:03.3
	{ key = "phrase_112509101263761", name = "With", soundId = 112509101263761, from = 59.04, to = 78.99 }, -- 0:59.0-1:19.0
	{ key = "phrase_86115718533153", name = "CRASH", soundId = 86115718533153, from = 51.62, to = 73.91 }, -- 0:51.6-1:13.9
	{ key = "phrase_94024099429072", name = "SHOCK", soundId = 94024099429072, from = 43.68, to = 62.13 }, -- 0:43.7-1:02.1
	{ key = "phrase_74619423082896", name = "백화요란", soundId = 74619423082896, from = 60.21, to = 77.71 }, -- 1:00.2-1:17.7
} :: { { key: string, name: string, soundId: number, from: number, to: number } }

M.TempoMin = 0.5
M.TempoMax = 2.0
M.TempoStep = 0.1

-- How far away another player can be to show up under 같이 추기 (the panel
-- list). Clicking a player works anywhere inside the club.
M.JoinRadius = 90

return M

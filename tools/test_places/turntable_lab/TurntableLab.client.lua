-- Turntable sound lab (test place "Place1", user 2026-11-01): the 오후 DJ
-- console with no lights, only a track that plays / stops, and fine controls
-- for PlaybackSpeed, Volume and the PitchShiftSoundEffect octave, each from
-- x1/5 (−) to x5 (+), to tune a track by ear. Plays locally (2D, SoundService).
-- Built into the place by tools/test_places/turntable_lab/build_lab.lua.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- 오후 club playlist (ClubConfig.Playlist, 37 songs, 2026-11-03 D-782;
-- docs/04_ART/CLUB_PLAYLIST.md). The 12 Roblox tracks play as uploaded; each
-- of the 25 uploads has its own club value, `club` = { tempo, boost, low,
-- mid, high } on top of speed 1, volume 10, octave 0.5, engine "sound".
-- Per-track lab values live in the lab's DataStore.
local TRACKS = {
	-- Roblox music (no lab values)
	{ title = "K-Pop Party", id = 135361546383974 },
	{ title = "K-pop Cute Crush", id = 121416896999522 },
	{ title = "K-Pop Uprising", id = 72966738276299 },
	{ title = "Push & Pull (밀당의 고수)", id = 132502088493185 },
	{ title = "Secret Party", id = 75682100037866 },
	{ title = "Luminous Dance", id = 123336690588412 },
	{ title = "LIGHT UP THE NIGHT", id = 102534983754242 },
	{ title = "RUN THE NIGHT", id = 123336998544849 },
	{ title = "ECHOES OF THE BASS (EDM 버튼 곡)", id = 134070050316863 },
	{ title = "Disco Inferno", id = 87243738678545 },
	{ title = "Festival Fever", id = 136228548293465 },
	{ title = "Euphoria Dance", id = 76814968175069 },
	-- the user's uploads, each with its club value
	{ title = "ATEEZ-BAD", id = 134942349436280, club = { 0.333, 2.5, 0, 0, 0 } },
	{ title = "소녀시대-소원을 말해봐(Genie)", id = 128270208751659, club = { 0.334, 2.5, -5, 2, 0 } },
	{ title = "소원2", id = 100752194799727 }, -- user 2026-11-06, song 3:48
	{ title = "현아-Bubble Pop", id = 76388700698178, club = { 0.333, 2.5, -6, 0.5, -7 } },
	-- (user 2026-11-06) chosen upload, replaces 133586602463513 / 91762270038050
	{ title = "RIIZE-Get A Guitar", id = 70738014182544 }, -- file 153.0 s, song 2:40
	-- (user 2026-11-06) new upload, replaces 119473981131981 (a 3× file)
	{ title = "RIIZE-Love 119", id = 85204387077332 }, -- file 157.7 s, song 2:54
	{ title = "YENA-Catch Catch", id = 80583279340768, club = { 0.34, 3, -13, 2.5, 4 } },
	{ title = "Hearts2Hearts-Lemon Tang", id = 97032815457241, club = { 0.333, 3, -3, 2, 0 } },
	{ title = "Hearts2Hearts-Next Chapter", id = 113170325006427 }, -- user 2026-11-06, x1 file, song 2:52
	{ title = "aespa-Lemonade", id = 132067415333401, club = { 0.333, 3, -11, 0, -2.5 } },
	{ title = "IVE-Mirror", id = 139326796173276, club = { 0.332, 3, -10.5, 5, 4.5 } },
	{ title = "A2O LITE-NEON", id = 140713297574648 }, -- new upload (user 2026-11-06, file 210.8 s, song 3:41); was 74988982712396, 97511700575810
	{ title = "SOYEON-퇴사할게여", id = 96358497474432, club = { 0.334, 3, -3, 2, 0 } },
	{ title = "ILLIT-체포하겠어", id = 102827134450527 }, -- new upload (user 2026-11-06, file 173.3 s, song 3:01); was 139044453511745
	{ title = "RESCENE-LOVE-ATTACK", id = 139330220515727 }, -- new upload (user 2026-11-06, file 173.0 s, song 3:01); was 71873496902418
	{ title = "MY:RAKL-오색 낙원", id = 108027306922001, club = { 0.333, 3, -3, 2, 0 } },
	{ title = "Darla Jean-Dam Da Dee", id = 78077595750886, club = { 0.335, 3, -3, 2, 0 } },
	{ title = "머무르-꿈꾸던 어른이 되었나요", id = 120160897793669, club = { 0.334, 3, -3, 2, 0 } },
	{ title = "IVE-Looks Can Kill", id = 135553051649506, club = { 0.333, 3, -3, 2, 0 } },
	{ title = "IOI-갑자기", id = 75344866720031 }, -- new upload (user 2026-11-06, file 185.8 s, song 3:15); was 73546697163709
	{ title = "NMIXX-긴 소원(Birthday Wish)", id = 107782871991364, club = { 0.333, 3, -3, 2, 0 } },
	{ title = "NCT WISH-I SPY", id = 98124521559769 }, -- new upload (user 2026-11-06, file 176.3 s, song 3:05); was 90694654380166
	{ title = "IU-이 별로부터", id = 96396723842714, club = { 0.333, 3, -3, 2, 0 } },
	{ title = "CORTIS-REDRED", id = 76034005809699 }, -- new upload (user 2026-11-06, file 153.8 s, song 2:43); was 125703446596781
	{ title = "BIG Naughty-노스탈지아", id = 116539470869444, club = { 0.333, 3, -3, 2, 0 } },
	{ title = "BIGBANG-BiiiG", id = 113809029583519, club = { 0.334, 3, -3, 2, 0 } },
	{ title = "BOYNEXTDOOR-ANIMAL", id = 94774089824958 }, -- new upload (user 2026-11-06, file 136.1 s, song 2:22); was 130804487358433
	-- joined songs (user 2026-11-03): one song uploaded as clips cut by
	-- tools/audio/split_for_crossfade.ps1, played as one by JoinedSongPlayer
	{ title = "녹음본 (8구간 이어 붙임)", joined = { parts = { 81568082292649, 130739295576800, 136055998058951, 101406045735531, 115474783735573, 101362036297281, 107766734212525, 139626977220244 }, segLen = 30, tail = 4, total = 225.05, lead = 0.09 } },
	-- the same clips one by one again (user 2026-11-04), to play or crossfade
	-- each on its own (30 s + the next clip's first 4 s: use 꼬리 4초)
	{ title = "녹음 구간 1 (0~30초)", id = 81568082292649, seg = 1 },
	{ title = "녹음 구간 2 (30~60초)", id = 130739295576800, seg = 2 },
	{ title = "녹음 구간 3 (60~90초)", id = 136055998058951, seg = 3 },
	{ title = "녹음 구간 4 (90~120초)", id = 101406045735531, seg = 4 },
	{ title = "녹음 구간 5 (120~150초)", id = 115474783735573, seg = 5 },
	{ title = "녹음 구간 6 (150~180초)", id = 101362036297281, seg = 6 },
	{ title = "녹음 구간 7 (180~210초)", id = 107766734212525, seg = 7 },
	{ title = "녹음 구간 8 (210~225초)", id = 139626977220244, seg = 8 },
	-- user 2026-11-05: 30 uploads (3× files); tempo = x1 length ÷ song length,
	-- saved per track in the DataStore
	{ title = "ALLDAY-PROJECT-올데이-프로젝트-CRASH", id = 104827635407586 },
	{ title = "RESCENE-리센느-Pretty-Girl", id = 89634330677538 },
	{ title = "KiiiKiii-키키-Pop-Off-Pop-Off", id = 129996145931101 },
	{ title = "CAR-THE-GARDEN-카더가든-Stay", id = 105952476684202 },
	{ title = "이하이-손을-잡아줘요", id = 103445673482116 },
	{ title = "Even-if-it-s-slightly-off", id = 133127589723955 },
	{ title = "Lee-Mujin-이무진-Come-Rest-With-Me-그대-잠시-내게", id = 129938231085858 }, -- the old "B" upload (user 2026-11-05)
	{ title = "kennytheking-케니더킹-morae", id = 84098562212174 },
	{ title = "When-We-re-Together", id = 137002175061093 },
	{ title = "송유진-I-Miss-You-지금-헤어지는-중입니다-OST-Part-5", id = 130599662472578 },
	{ title = "20-Years-of-Age-스무살-Your-Season-너라는-계절", id = 75344952904705 },
	{ title = "거리-어반자카파-URBAN-ZAKAPA", id = 133185418054871 },
	{ title = "이민혁-보라미유-사랑일지도-몰라 (지금 헤어지는 중입니다 OST Part 7)", id = 72768669123530 },
	{ title = "정승환-푸르른-계절도-내겐-의미-없어요 (지금 헤어지는 중입니다 OST Part 4)", id = 86350230390947 },
	{ title = "백호-나는 너라서", id = 136466157907135 },
	{ title = "Davichi-다비치-The-Only-Reason-오로지-그대", id = 78526138384885 },
	{ title = "Avril-Ask-You-Out", id = 103787057077249 },
	{ title = "Just-Another-Love-Song", id = 80301177020545 },
	{ title = "EVAN-에반-Ride-or-Die", id = 133999600898465 },
	{ title = "YOHAN-요한-Song-for-you", id = 103541991193404 },
	{ title = "nia-becoming-a-star", id = 86981648186781 },
	{ title = "&TEAM-Run Wild", id = 70916137137443 },
	{ title = "아이엠발라더-그사람", id = 126452182135370 },
	{ title = "Isla Hart-All On Me", id = 108408461588260 },
	{ title = "Jace Monroe-Runaway Light", id = 76499736085724 },
	{ title = "Jace Monroe-Small Town Ghost", id = 120750538041422 },
	{ title = "Kai-Secrtet Us", id = 128723787907471 },
	{ title = "Leo Hart-Can't Slow Down", id = 70590746014828 },
	{ title = "Luna-Run the night", id = 126980667502605 },
	{ title = "Noah Blaze-Light it Up", id = 125858610081422 },
	{ title = "잠자기전", id = 83921467202322 }, -- user 2026-11-06
	-- (user 2026-11-06) new tracks go at the bottom, in the order given
	{ title = "AND2BLE-French Kissing", id = 120866427099057 }, -- x1 file 177.4 s, song 3:15
	{ title = "RESCENE-With", id = 120039092597099 }, -- x1 file 171.7 s, song 3:09
	{ title = "K/DA - FIRESTARTER (Feat. Sophie Powers, MIYEON, SOYEON)", id = 102216920231649 },
	{ title = "K/DA - NEVER GOING BACK (Feat. SOYEON, MIYEON)", id = 113680653484321 }, -- song 3:16
	{ title = "LISA - Tarantino", id = 102033386205095 }, -- x1 file 151.8 s, song 2:47
	{ title = "K/DA - GIRLS (Feat. Sorana, Royal & the Serpent)", id = 127811970673239 }, -- file 112.3 s, song 2:16
	{ title = "izna - ROCK, PAPER, SCISSORS", id = 132951659748689 }, -- file 105.5 s, song 2:21
	{ title = "LISA - Cobra", id = 95502375387883 }, -- file 131.6 s, song 2:25
	{ title = "ALLDAY PROJECT - NO 한도", id = 81251273866025 }, -- file 131.7 s, song 2:25
}
-- a track's club value as a full lab table (nil for the Roblox tracks)
local function clubValues(t: any): any
	local c = t.club
	if not c then return nil end
	return { speed = 1, tempo = c[1], volume = 10, boost = c[2], octave = 0.5, low = c[3], mid = c[4], high = c[5], engine = "sound" }
end

-- speed and octave on log sliders (x1 in the middle); volume is the raw
-- Sound.Volume
-- EQ (user 2026-11-01): EqualizerSoundEffect gains in dB, 0 = as recorded
-- (Roblox takes −80..10; below −40 is as good as silent), 0.5 dB a press
local PARAMS = {
	-- (user 2026-11-01, later: up to what Roblox takes uncut: speed 20, volume
	-- 10; the octave x1/20..x20 with five effects in a row)
	{ key = "speed", name = "PlaybackSpeed", sub = "속도 · 템포와 음높이 같이", min = 0.05, max = 20, log = true, default = 1, prefix = "x" },
	-- tempo only (user 2026-11-01): Roblox has no time-stretch, so the speed
	-- goes up by the tempo and the pitch shifters bring the pitch back down
	{ key = "tempo", name = "Tempo (템포만)", sub = "빠르기만 · 음높이 그대로 (PitchShift로 되돌림)", min = 0.05, max = 20, log = true, default = 1, prefix = "x" },
	{ key = "volume", name = "Volume", sub = "볼륨", min = 0, max = 10, log = false, default = 1, prefix = "" },
	-- (user 2026-11-01) Volume stops at 10 even from code; a SoundGroup (an
	-- AudioFader on the new engine) multiplies it: up to 10 × 10 = 100
	{ key = "boost", name = "볼륨 부스트", sub = "Volume에 곱해요 (SoundGroup) · 합계 최대 100", min = 0, max = 10, log = false, default = 1, prefix = "x" },
	-- (user 2026-11-05) 오후's lab.boost2 (D-892): a second SoundGroup above
	-- the first, so heard = volume × boost × boost2 (up to 1000)
	{ key = "boost2", name = "볼륨 부스트 2", sub = "부스트에 한 번 더 곱해요 (위 SoundGroup) · 오후 lab.boost2", min = 0, max = 10, log = false, default = 1, prefix = "x" },
	-- (user 2026-11-06) two more groups stacked on top the same way:
	-- heard = volume × boost × boost2 × boost3 × boost4
	{ key = "boost3", name = "볼륨 부스트 3", sub = "부스트 2에 한 번 더 곱해요 (그 위 SoundGroup)", min = 0, max = 10, log = false, default = 1, prefix = "x" },
	{ key = "boost4", name = "볼륨 부스트 4", sub = "부스트 3에 한 번 더 곱해요 (맨 위 SoundGroup)", min = 0, max = 10, log = false, default = 1, prefix = "x" },
	{ key = "octave", name = "PitchShift Octave", sub = "음높이만 (템포 그대로)", min = 0.05, max = 20, log = true, default = 1, prefix = "x" },
	{ key = "low", name = "EQ Low", sub = "저음 (~400 Hz)", min = -40, max = 10, default = 0, fixedStep = 0.5, unit = " dB",
		header = "🎚 EQ (EqualizerSoundEffect) · 한 번에 0.5 dB" },
	{ key = "mid", name = "EQ Mid", sub = "중음 (400~4000 Hz)", min = -40, max = 10, default = 0, fixedStep = 0.5, unit = " dB" },
	{ key = "high", name = "EQ High", sub = "고음 (4000 Hz~)", min = -40, max = 10, default = 0, fixedStep = 0.5, unit = " dB" },
	-- denoise (user 2026-11-01): Roblox has no real noise cancelling. The
	-- closest are the new audio API's AudioFilter (cut below / above a
	-- frequency) and AudioGate (silence under a level); they only take an
	-- AudioPlayer, not a Sound (EqualizerSoundEffect has no MidRange either),
	-- so they work on the new engine only. Each is off at its end value.
	{ key = "humHz", name = "험 컷 (Highpass)", sub = "이 주파수 아래 '우웅-' 깎기 · 20 = 끔", min = 20, max = 500, log = true, default = 20, fixedStep = 5, unit = " Hz",
		header = "🔇 디노이즈 · 새 엔진(AudioPlayer)에서만" },
	{ key = "hissHz", name = "히스 컷 (Lowpass)", sub = "이 주파수 위 '치이-' 깎기 · 20000 = 끔", min = 2000, max = 20000, log = true, default = 20000, fixedStep = 100, unit = " Hz" },
	{ key = "gate", name = "노이즈 게이트", sub = "이보다 작은 소리는 묵음 · −80 = 끔", min = -80, max = -10, default = -80, fixedStep = 1, unit = " dB" },
}
local STEPS = { 0.005, 0.01, 0.05, 0.1, 0.5 } -- (0.005: user 2026-11-03)
local values = { speed = 1, tempo = 1, volume = 1, boost = 1, boost2 = 1, boost3 = 1, boost4 = 1, octave = 1, low = 0, mid = 0, high = 0, humHz = 20, hissHz = 20000, gate = -80 }
-- "sound" = Sound with SoundEffects (what 오후 uses); "audio" = the new API:
-- AudioPlayer → pitch shifters → EQ → filters → gate → device output
local engine = "sound"
-- test switch (user 2026-11-01): the whole octave on one effect, unsplit, to
-- hear whether an Octave above 2 does anything (the property takes 100)
local rawOctave = false
local step = 0.05
local trackIndex = 1
local customId: number? = nil
local looped = true

--------------------------------------------------------------------------
-- sound: a deck = one Sound with its own SoundGroup (the boost), five
-- PitchShift effects in a row (one effect only reaches 0.5..2, so a bigger
-- octave is split into equal parts) and an EQ. Two decks take turns for the
-- crossfade test (user 2026-11-03): `deck` plays (its parts are `snd`,
-- `boostGroup`, `shifters`, `eq`), `otherDeck` waits with the next song.
-- `gain` is the crossfade level (0..1) on top of the track's volume.
--------------------------------------------------------------------------
local function makeDeck(name: string, groupName: string): any
	-- boost2 = a second group above the boost group (as in 오후);
	-- boost3 / boost4 = two more above that (user 2026-11-06)
	local group4 = Instance.new("SoundGroup")
	group4.Name = groupName .. "4"
	group4.Parent = SoundService
	local group3 = Instance.new("SoundGroup")
	group3.Name = groupName .. "3"
	group3.Parent = group4
	local group2 = Instance.new("SoundGroup")
	group2.Name = groupName .. "2"
	group2.Parent = group3
	local group = Instance.new("SoundGroup")
	group.Name = groupName
	group.Parent = group2
	local s = Instance.new("Sound")
	s.Name = name
	s.Looped = looped
	s.SoundGroup = group
	s.Parent = SoundService
	local fxs = {}
	for i = 1, 5 do
		local fx = Instance.new("PitchShiftSoundEffect")
		fx.Name = "PitchShift" .. i
		fx.Priority = i
		fx.Enabled = false
		fx.Parent = s
		fxs[i] = fx
	end
	local e = Instance.new("EqualizerSoundEffect")
	e.Name = "EQ"
	e.Priority = 10
	e.LowGain, e.MidGain, e.HighGain = 0, 0, 0
	e.Enabled = false
	e.Parent = s
	return { snd = s, group = group, group2 = group2, group3 = group3, group4 = group4, shifters = fxs, eq = e, gain = 1 }
end
local deck = makeDeck("LabTrack", "LabBoost")
local otherDeck = makeDeck("LabTrackNext", "LabBoostNext")
otherDeck.gain = 0
local snd, boostGroup, shifters, eq = deck.snd, deck.group, deck.shifters, deck.eq
local function swapDecks()
	deck, otherDeck = otherDeck, deck
	snd, boostGroup, shifters, eq = deck.snd, deck.group, deck.shifters, deck.eq
end

-- the new-API chain, wired in a row
local chain = Instance.new("Folder")
chain.Name = "LabAudio"
local function mkAudio(class: string, name: string): any
	local inst = Instance.new(class)
	inst.Name = name
	inst.Parent = chain
	return inst
end
local ap = mkAudio("AudioPlayer", "Player")
local apShifters = {}
for i = 1, 5 do apShifters[i] = mkAudio("AudioPitchShifter", "PitchShift" .. i) end
local apEq = mkAudio("AudioEqualizer", "EQ")
local humFilter = mkAudio("AudioFilter", "HumCut")
humFilter.FilterType = Enum.AudioFilterType.Highpass24dB
local hissFilter = mkAudio("AudioFilter", "HissCut")
hissFilter.FilterType = Enum.AudioFilterType.Lowpass24dB
local gate = mkAudio("AudioGate", "Gate")
local boostFader = mkAudio("AudioFader", "Boost")
local boostFader2 = mkAudio("AudioFader", "Boost2")
local boostFader3 = mkAudio("AudioFader", "Boost3")
local boostFader4 = mkAudio("AudioFader", "Boost4")
local out = mkAudio("AudioDeviceOutput", "Out")
do
	local nodes = { ap }
	for _, s in ipairs(apShifters) do table.insert(nodes, s) end
	for _, n in ipairs({ apEq, humFilter, hissFilter, gate, boostFader, boostFader2, boostFader3, boostFader4, out }) do table.insert(nodes, n) end
	for i = 1, #nodes - 1 do
		local w = Instance.new("Wire")
		w.SourceInstance = nodes[i]
		w.TargetInstance = nodes[i + 1]
		w.Parent = nodes[i + 1]
	end
end
ap.Looping = looped
chain.Parent = SoundService

-- a joined song (clips played as one) runs on its own player
-- (ReplicatedStorage.JoinedSongPlayer, the same module 오후 gets)
local JoinedSongPlayer = require(game:GetService("ReplicatedStorage"):WaitForChild("JoinedSongPlayer"))
local joined = JoinedSongPlayer.new(SoundService)
local joinedActive = false
-- boost2 for a joined song: its two clip groups go under one more group
local joinedBoost4 = Instance.new("SoundGroup")
joinedBoost4.Name = "LabJoinedBoost4"
joinedBoost4.Parent = SoundService
local joinedBoost3 = Instance.new("SoundGroup")
joinedBoost3.Name = "LabJoinedBoost3"
joinedBoost3.Parent = joinedBoost4
local joinedBoost2 = Instance.new("SoundGroup")
joinedBoost2.Name = "LabJoinedBoost2"
joinedBoost2.Parent = joinedBoost3
for _, d in ipairs(joined.decks) do d.group.Parent = joinedBoost2 end

-- one face for both engines: the transport code below talks to `sound` as
-- if it were a Sound; on the new engine Pause / Resume are Stop / Play
-- keeping the time, and the loop region is LoopRegion with no switch.
-- A joined song answers with its whole length and song time.
local JOINED_GET = {
	IsLoaded = function() return true end,
	IsPlaying = function() return joined:IsPlaying() end,
	TimePosition = function() return joined:GetTime() end,
	TimeLength = function() return joined:GetLength() end,
	Looped = function() return false end,
	PlaybackRegionsEnabled = function() return false end,
	LoopRegion = function() return NumberRange.new(0, 60000) end,
	-- a jump made while stopped (pendingAt) is where the next play starts
	Play = function() return function() joined:Play(joined.pendingAt or joined:GetTime()) joined.pendingAt = nil end end,
	Resume = function() return function()
		if joined.pendingAt then joined:Play(joined.pendingAt) joined.pendingAt = nil else joined:Resume() end
	end end,
	Pause = function() return function() joined:Pause() end end,
	Stop = function() return function() joined:Stop() end end,
}
local regionsOn = false
local AUDIO_GET = {
	IsLoaded = function() return ap.IsReady end,
	Looped = function() return ap.Looping end,
	PlaybackRegionsEnabled = function() return regionsOn end,
	Play = function() return function() ap:Play() end end,
	Resume = function() return function() ap:Play() end end,
	Pause = function() return function() local t = ap.TimePosition ap:Stop() ap.TimePosition = t end end,
	Stop = function() return function() ap:Stop() ap.TimePosition = 0 end end,
}
local AUDIO_SET = {
	SoundId = function(v) ap.AssetId = v end,
	Looped = function(v) ap.Looping = v end,
	PlaybackRegionsEnabled = function(v)
		regionsOn = v
		if not v then ap.LoopRegion = NumberRange.new(0, 60000) end
	end,
}
local sound: any = setmetatable({}, {
	__index = function(_, k)
		if joinedActive then
			local get = JOINED_GET[k]
			return if get then get() else nil
		end
		if engine == "sound" then
			local v = (snd :: any)[k]
			if typeof(v) == "function" then return function(_, ...) return v(snd, ...) end end
			return v
		end
		local get = AUDIO_GET[k]
		if get then return get() end
		return (ap :: any)[k]
	end,
	__newindex = function(_, k, v)
		if joinedActive then
			-- a jump on the time bar; the loop settings do not apply
			if k == "TimePosition" then
				if joined:IsPlaying() then joined:Play(v) else joined.pendingAt = v end
			end
			return
		end
		if engine == "sound" then (snd :: any)[k] = v return end
		local set = AUDIO_SET[k]
		if set then set(v) else (ap :: any)[k] = v end
	end,
})

local function octaveParts(t: number): {number}
	if t >= 0.5 and t <= 2 then return { t } end
	local n = math.clamp(math.ceil(math.abs(math.log(t, 2)) - 1e-6), 1, 5)
	local part = t ^ (1 / n)
	local list = {}
	for i = 1, n do list[i] = part end
	return list
end

-- what is really sent: speed × tempo (Roblox stops at 20), and the octave
-- divided by the tempo that got through (five shifters reach 1/32..32)
local function effectiveOf(v: any): (number, number)
	local playSpeed = math.min(v.speed * v.tempo, 20)
	local tempo = playSpeed / v.speed
	return playSpeed, math.clamp(v.octave / tempo, 1 / 32, 32)
end
local function effective(): (number, number)
	return effectiveOf(values)
end

-- a deck gets a track's values (the next song's while it waits)
local function applyDeck(d: any, v: any)
	local playSpeed, octave = effectiveOf(v)
	d.snd.PlaybackSpeed = playSpeed
	d.snd.Volume = v.volume * d.gain
	d.group.Volume = v.boost
	d.group2.Volume = v.boost2 or 1
	d.group3.Volume = v.boost3 or 1
	d.group4.Volume = v.boost4 or 1
	local split = if math.abs(octave - 1) < 1e-4 then {} else octaveParts(octave)
	-- the raw test is for PitchShiftSoundEffect only (AudioPitchShifter cuts at 2)
	local parts = if rawOctave and #split > 0 then { octave } else split
	for i, fx in ipairs(d.shifters) do
		fx.Octave = parts[i] or 1
		fx.Enabled = parts[i] ~= nil
	end
	d.eq.LowGain, d.eq.MidGain, d.eq.HighGain = v.low, v.mid, v.high
	d.eq.Enabled = v.low ~= 0 or v.mid ~= 0 or v.high ~= 0
end

-- both engines get every value, so switching keeps the sound
local function apply()
	local playSpeed, octave = effective()
	applyDeck(deck, values)
	if joinedActive then joined:SetLab(values) end
	ap.PlaybackSpeed = playSpeed
	ap.Volume = values.volume
	boostFader.Volume = values.boost
	boostFader2.Volume = values.boost2
	joinedBoost2.Volume = values.boost2
	boostFader3.Volume = values.boost3
	joinedBoost3.Volume = values.boost3
	boostFader4.Volume = values.boost4
	joinedBoost4.Volume = values.boost4
	local split = if math.abs(octave - 1) < 1e-4 then {} else octaveParts(octave)
	for i, fx in ipairs(apShifters) do
		fx.Pitch = split[i] or 1
		fx.Bypass = split[i] == nil
	end
	apEq.LowGain, apEq.MidGain, apEq.HighGain = values.low, values.mid, values.high
	apEq.Bypass = not eq.Enabled
	humFilter.Frequency = values.humHz
	humFilter.Bypass = values.humHz <= 20
	hissFilter.Frequency = values.hissHz
	hissFilter.Bypass = values.hissHz >= 20000
	gate.Threshold = NumberRange.new(values.gate - 6, values.gate) -- opens above, closes 6 dB under
	gate.Bypass = values.gate <= -80
end
apply()

--------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------
local BG = Color3.fromRGB(16, 16, 22)
local CARD = Color3.fromRGB(30, 30, 40)
local PINK = Color3.fromRGB(255, 80, 200)
local CYAN = Color3.fromRGB(80, 230, 255)
local TEXT = Color3.fromRGB(240, 240, 248)
local DIM = Color3.fromRGB(150, 150, 165)

local function mk(class: string, props: {[string]: any}, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in pairs(props) do (inst :: any)[k] = v end
	if parent then inst.Parent = parent end
	return inst
end
local function corner(parent: Instance, r: number?)
	mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end
local function button(parent: Instance, text: string, size: UDim2, color: Color3?): TextButton
	local b = mk("TextButton", {
		Size = size, BackgroundColor3 = color or CARD, Text = text, TextColor3 = TEXT,
		Font = Enum.Font.GothamBold, TextSize = 15, AutoButtonColor = true,
	}, parent)
	corner(b, 6)
	return b
end
local function fmt(v: number): string
	local s = string.format("%.3f", v)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return s
end

local gui = mk("ScreenGui", { Name = "TurntableLab", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local scale = mk("UIScale", {}, gui)
local function rescale()
	local cam = workspace.CurrentCamera
	local h = if cam then cam.ViewportSize.Y else 800
	scale.Scale = math.clamp(h / 760, 0.55, 1)
end
rescale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

local toggle = button(gui, "🎧 믹서", UDim2.fromOffset(96, 40), PINK)
toggle.Position = UDim2.new(0, 12, 0, 60)

local panel = mk("ScrollingFrame", {
	Name = "Panel", Size = UDim2.new(0, 400, 1, -24), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = BG, BackgroundTransparency = 0.05, BorderSizePixel = 0, ScrollBarThickness = 6,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, gui)
corner(panel, 12)
mk("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 16) }, panel)
mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
toggle.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)

local order = 0
local function row(height: number): Frame
	order += 1
	return mk("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = order }, panel)
end
local function label(parent: Instance, text: string, size: UDim2, pos: UDim2?, props: {[string]: any}?): TextLabel
	local l = mk("TextLabel", {
		Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, Text = text, TextColor3 = TEXT,
		Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	if props then for k, v in pairs(props) do (l :: any)[k] = v end end
	return l
end

label(row(24), "🎧 턴테이블 음원 테스트", UDim2.fromScale(1, 1), nil, { Font = Enum.Font.GothamBold, TextSize = 18 })

-- track picker
local trackRow = row(36)
local prevB = button(trackRow, "◀", UDim2.fromOffset(36, 36))
local nextB = button(trackRow, "▶", UDim2.fromOffset(36, 36))
nextB.Position = UDim2.new(1, -36, 0, 0)
local trackLabel = label(trackRow, "", UDim2.new(1, -84, 1, 0), UDim2.fromOffset(42, 0), { TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold })

local idRow = row(32)
local idBox = mk("TextBox", {
	Size = UDim2.new(1, -96, 1, 0), BackgroundColor3 = CARD, Text = "", PlaceholderText = "음원 ID 직접 입력 (rbxassetid 숫자)",
	TextColor3 = TEXT, PlaceholderColor3 = DIM, Font = Enum.Font.Gotham, TextSize = 14, ClearTextOnFocus = false,
}, idRow)
corner(idBox, 6)
local idLoad = button(idRow, "불러오기", UDim2.fromOffset(88, 32))
idLoad.Position = UDim2.new(1, -88, 0, 0)

-- song list (user 2026-11-01): every track, tap one to load it; the 오후
-- values on the right
local listRow = row(180)
local list = mk("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = CARD, BorderSizePixel = 0, ScrollBarThickness = 5,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, listRow)
corner(list, 8)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }, list)
mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local listButtons: {TextButton} = {}
local listTags: {TextLabel} = {} -- the 오후 values, or 💾 when saved here
for i, t in ipairs(TRACKS) do
	local b = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = BG, BackgroundTransparency = 1, Text = "", AutoButtonColor = true, LayoutOrder = i,
	}, list)
	corner(b, 5)
	label(b, string.format("%d.  %s", i, t.title), UDim2.new(1, -96, 1, 0), UDim2.fromOffset(8, 0), { TextSize = 13 })
	listTags[i] = label(b, "", UDim2.fromOffset(92, 28), UDim2.new(1, -92, 0, 0), { TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right })
	listButtons[i] = b
end

-- transport
local tRow = row(40)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tRow)
local playB = button(tRow, "▶ 재생", UDim2.new(0.34, -4, 1, 0), Color3.fromRGB(40, 140, 90))
local stopB = button(tRow, "⏹ 끄기", UDim2.new(0.33, -4, 1, 0), Color3.fromRGB(150, 50, 60))
local repeatB = button(tRow, "", UDim2.new(0.33, -4, 1, 0))
local engineB = button(row(32), "", UDim2.fromScale(1, 1))
engineB.TextSize = 13

-- crossfade test (user 2026-11-03): song → song on two decks; wired up
-- further down with the transport
label(row(20), "🔀 크로스페이드 (곡 → 곡)", UDim2.fromScale(1, 1), nil, { Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = CYAN })
local xfNextRow = row(32)
local xfPrev = button(xfNextRow, "◀", UDim2.fromOffset(32, 32))
local xfNext = button(xfNextRow, "▶", UDim2.fromOffset(32, 32))
xfNext.Position = UDim2.new(1, -32, 0, 0)
local xfNextLabel = label(xfNextRow, "", UDim2.new(1, -76, 1, 0), UDim2.fromOffset(38, 0), { TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13 })
local xfLenRow = row(32)
label(xfLenRow, "겹침", UDim2.fromOffset(40, 32), nil, { TextColor3 = DIM, TextSize = 13 })
local xfMinus = button(xfLenRow, "−", UDim2.fromOffset(36, 32), Color3.fromRGB(60, 60, 80))
xfMinus.Position = UDim2.fromOffset(44, 0)
local xfLenBox = mk("TextBox", {
	Size = UDim2.new(1, -128, 1, 0), Position = UDim2.fromOffset(84, 0), BackgroundColor3 = BG,
	Text = "", TextColor3 = CYAN, Font = Enum.Font.GothamBold, TextSize = 16, ClearTextOnFocus = false,
}, xfLenRow)
corner(xfLenBox, 6)
local xfPlus = button(xfLenRow, "+", UDim2.fromOffset(36, 32), Color3.fromRGB(60, 60, 80))
xfPlus.Position = UDim2.new(1, -36, 0, 0)
local xfBar = mk("TextButton", { Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = CARD, Text = "", AutoButtonColor = false, LayoutOrder = 0 }, row(10))
corner(xfBar, 5)
local xfFill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = PINK, BorderSizePixel = 0 }, xfBar)
corner(xfFill, 5)
local xfOptRow = row(32)
local xfCurveB = button(xfOptRow, "", UDim2.new(1 / 3, -4, 1, 0))
local xfAutoB = button(xfOptRow, "", UDim2.new(1 / 3, -4, 1, 0))
xfAutoB.Position = UDim2.new(1 / 3, 2, 0, 0)
local xfTailB = button(xfOptRow, "", UDim2.new(1 / 3, -4, 1, 0))
xfTailB.Position = UDim2.new(2 / 3, 4, 0, 0)
for _, b in ipairs({ xfCurveB, xfAutoB, xfTailB }) do b.TextSize = 12 end
local xfLeadB = button(row(28), "", UDim2.fromScale(1, 1))
xfLeadB.TextSize = 12
local xfGoRow = row(36)
local xfGoB = button(xfGoRow, "🔀 지금 전환", UDim2.new(0.4, -4, 1, 0), Color3.fromRGB(120, 50, 150))
local xfStatus = label(xfGoRow, "", UDim2.new(0.6, -4, 1, 0), UDim2.new(0.4, 4, 0, 0), { TextColor3 = DIM, TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None })

-- time bar (click to jump)
local timeRow = row(34)
local timeLabel = label(timeRow, "0:00 / 0:00", UDim2.new(1, 0, 0, 16), nil, { TextColor3 = DIM, TextSize = 13 })
local statusLabel = label(timeRow, "", UDim2.new(1, 0, 0, 16), nil, { TextColor3 = DIM, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right })
local seekBar = mk("TextButton", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 20), BackgroundColor3 = CARD, Text = "", AutoButtonColor = false }, timeRow)
corner(seekBar, 5)
local seekFill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, BorderSizePixel = 0 }, seekBar)
corner(seekFill, 5)
-- the A-B loop on the bar
local regionBand = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 210, 60), BackgroundTransparency = 0.45, BorderSizePixel = 0, Visible = false, ZIndex = 2 }, seekBar)

-- A-B loop (user 2026-11-01): Sound.LoopRegion between two marks, each
-- set from where it is now and nudged by 0.1 s
local loopA: number?, loopB: number? = nil, nil
local regionOn = false
local refreshRegion: () -> () -- below, with the transport
local function markRow(name: string): (TextButton, TextLabel, TextButton, TextButton)
	local r = row(32)
	local setB = button(r, name .. " = 지금", UDim2.fromOffset(96, 32), Color3.fromRGB(110, 90, 30))
	setB.TextSize = 13
	local lab = label(r, name .. "  —", UDim2.new(1, -206, 1, 0), UDim2.fromOffset(104, 0), { TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold })
	local back = button(r, "−0.1s", UDim2.fromOffset(48, 32))
	back.Position = UDim2.new(1, -100, 0, 0)
	back.TextSize = 12
	local fwd = button(r, "+0.1s", UDim2.fromOffset(48, 32))
	fwd.Position = UDim2.new(1, -48, 0, 0)
	fwd.TextSize = 12
	return setB, lab, back, fwd
end
local setA, aLabel, aBack, aFwd = markRow("A")
local setBm, bLabel, bBack, bFwd = markRow("B")
local regionRow = row(32)
local regionB = button(regionRow, "", UDim2.new(0.6, -4, 1, 0))
local regionClear = button(regionRow, "A·B 지우기", UDim2.new(0.4, -4, 1, 0))
regionClear.Position = UDim2.new(0.6, 4, 0, 0)

-- step size
local stepRow = row(30)
label(stepRow, "한 번에", UDim2.fromOffset(60, 30), nil, { TextColor3 = DIM })
local stepButtons = {}
for i, s in ipairs(STEPS) do
	local n = #STEPS -- the buttons share the row right of the label (64 px)
	local b = button(stepRow, fmt(s), UDim2.new(1 / n, -64 / n - 4, 1, 0))
	b.Position = UDim2.new((i - 1) / n, 64 - (i - 1) * 64 / n, 0, 0)
	b.TextSize = 13
	stepButtons[s] = b
	b.MouseButton1Click:Connect(function()
		step = s
		for v, bb in pairs(stepButtons) do bb.BackgroundColor3 = if v == step then PINK else CARD end
	end)
end
stepButtons[step].BackgroundColor3 = PINK

-- the three controls
local refreshers = {}
local copyBox: TextBox
local infoLabel: TextLabel
local paintSave: (() -> ())? = nil -- the save button, set further down

local function toFrac(p, v: number): number
	if p.log then return math.log(v / p.min) / math.log(p.max / p.min) end
	return (v - p.min) / (p.max - p.min)
end
local function fromFrac(p, f: number): number
	f = math.clamp(f, 0, 1)
	if p.log then return p.min * (p.max / p.min) ^ f end
	return p.min + (p.max - p.min) * f
end

local function refreshAll()
	for _, r in pairs(refreshers) do r() end
	if paintSave then paintSave() end
	-- the lab's raw values as one ClubConfig Track field (user 2026-11-01:
	-- 오후 plays them the way this lab does, see HANDOFF_PROMPT.md); the
	-- denoise only when it is heard (new engine)
	local parts = {}
	for _, k in ipairs({ "speed", "tempo", "volume", "boost", "boost2", "boost3", "boost4", "octave", "low", "mid", "high" }) do
		-- boost2..4 only when not x1 (오후 leaves them out then)
		if (k ~= "boost2" and k ~= "boost3" and k ~= "boost4") or math.abs(values[k] - 1) > 1e-6 then
			table.insert(parts, k .. " = " .. fmt(values[k]))
		end
	end
	table.insert(parts, 'engine = "' .. engine .. '"')
	if engine == "audio" then
		for _, k in ipairs({ "humHz", "hissHz", "gate" }) do table.insert(parts, k .. " = " .. fmt(values[k])) end
	end
	copyBox.Text = "lab = { " .. table.concat(parts, ", ") .. " },"
	local playSpeed, octave = effective()
	local split = if math.abs(octave - 1) < 1e-4 then {} else octaveParts(octave)
	local parts = if rawOctave and engine == "sound" and #split > 0 then { octave } else split
	local partText = {}
	for i, v in ipairs(parts) do partText[i] = fmt(v) end
	infoLabel.Text = string.format("들리는 템포 x%s (실제 PlaybackSpeed) · 들리는 음높이 x%s · 볼륨 합계 %s\n%s 효과: %s",
		fmt(playSpeed), fmt(playSpeed * octave), fmt(values.volume * values.boost * values.boost2 * values.boost3 * values.boost4),
		if engine == "sound" then "PitchShift" else "AudioPitchShifter",
		if #parts == 0 then "꺼짐" else table.concat(partText, " × ") .. string.format(" (%d개)", #parts))
end

local function set(key: string, v: number)
	local p
	for _, q in ipairs(PARAMS) do if q.key == key then p = q end end
	if typeof(v) ~= "number" or v ~= v then return end
	values[key] = math.clamp(math.floor(v * 1000 + 0.5) / 1000, p.min, p.max) -- to 0.001, under the 0.005 step
	apply()
	refreshAll()
end

-- − / + : one step a press, faster while held
local function holdRepeat(b: TextButton, fn: () -> ())
	local holding = 0
	b.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		holding += 1
		local my = holding
		fn()
		task.delay(0.4, function()
			while holding == my do
				fn()
				task.wait(0.06)
			end
		end)
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then holding += 1 end
	end)
	b.MouseLeave:Connect(function() holding += 1 end)
end

local dragging: any = nil
for _, p in ipairs(PARAMS) do
	if p.header then
		label(row(22), p.header, UDim2.fromScale(1, 1), nil, { Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = CYAN })
	end
	local card = row(104)
	card.BackgroundTransparency = 0
	card.BackgroundColor3 = CARD
	corner(card, 10)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8) }, card)
	label(card, p.name, UDim2.new(1, -90, 0, 18), nil, { Font = Enum.Font.GothamBold, TextSize = 15 })
	label(card, p.sub .. string.format("  ·  %s ~ %s", fmt(p.min), fmt(p.max)), UDim2.new(1, -90, 0, 14), UDim2.fromOffset(0, 19), { TextColor3 = DIM, TextSize = 12 })
	-- back to the untouched value (x1, 0 dB, filter off)
	local resetB = button(card, "초기화", UDim2.fromOffset(56, 26))
	resetB.Position = UDim2.new(1, -resetB.Size.X.Offset, 0, 0)
	resetB.TextSize = 13

	local minus = button(card, "−", UDim2.fromOffset(44, 34), Color3.fromRGB(60, 60, 80))
	minus.Position = UDim2.fromOffset(0, 38)
	minus.TextSize = 22
	local plus = button(card, "+", UDim2.fromOffset(44, 34), Color3.fromRGB(60, 60, 80))
	plus.Position = UDim2.new(1, -44, 0, 38)
	plus.TextSize = 22
	local box = mk("TextBox", {
		Size = UDim2.new(1, -100, 0, 34), Position = UDim2.fromOffset(50, 38), BackgroundColor3 = BG,
		Text = "", TextColor3 = CYAN, Font = Enum.Font.GothamBold, TextSize = 20, ClearTextOnFocus = false,
	}, card)
	corner(box, 6)

	local bar = mk("TextButton", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 80), BackgroundColor3 = BG, Text = "", AutoButtonColor = false }, card)
	corner(bar, 6)
	local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = PINK, BorderSizePixel = 0 }, bar)
	corner(fill, 6)
	if p.min < p.default and p.max > p.default then -- a tick at x1 / 0 dB
		mk("Frame", { Size = UDim2.new(0, 2, 1, 6), Position = UDim2.new(toFrac(p, p.default), -1, 0, -3), BackgroundColor3 = TEXT, BorderSizePixel = 0, ZIndex = 3 }, bar)
	end

	local function stepOf(): number return p.fixedStep or step end
	refreshers[p.key] = function()
		local v = values[p.key]
		box.Text = if p.unit then (if v > 0 and p.unit == " dB" then "+" else "") .. fmt(v) .. p.unit else p.prefix .. fmt(v)
		fill.Size = UDim2.fromScale(math.clamp(toFrac(p, v), 0, 1), 1)
	end
	holdRepeat(minus, function() set(p.key, values[p.key] - stepOf()) end)
	holdRepeat(plus, function() set(p.key, values[p.key] + stepOf()) end)
	resetB.MouseButton1Click:Connect(function() set(p.key, p.default) end)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text:match("%-?[%d%.]+") or "")
		if n then set(p.key, n) else refreshers[p.key]() end
	end)
	local function fromInput(x: number)
		local f = (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
		local v = fromFrac(p, f)
		set(p.key, math.floor(v / stepOf() + 0.5) * stepOf())
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = fromInput
			fromInput(input.Position.X)
		end
	end)
	if p.key == "octave" then
		local rawB = button(row(32), "", UDim2.fromScale(1, 1))
		rawB.TextSize = 13
		local function paint()
			rawB.Text = if rawOctave then "🧪 효과 1개에 Octave 그대로: 켬 (나누지 않음)" else "🧪 효과 1개에 Octave 그대로: 끔 (2 넘으면 나눠 걸기)"
			rawB.BackgroundColor3 = if rawOctave then Color3.fromRGB(150, 60, 40) else CARD
		end
		paint()
		rawB.MouseButton1Click:Connect(function()
			rawOctave = not rawOctave
			paint()
			apply()
			refreshAll()
		end)
	end
end
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		dragging(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = nil end
end)

local infoRow = row(36)
infoLabel = label(infoRow, "", UDim2.fromScale(1, 1), nil, { TextColor3 = DIM, TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top })

local presetRow = row(36)
local ohuB = button(presetRow, "오후 설정값 불러오기", UDim2.new(0.6, -4, 1, 0))
local allB = button(presetRow, "전체 초기화", UDim2.new(0.4, -4, 1, 0))
allB.Position = UDim2.new(0.6, 4, 0, 0)

-- per-track save (user 2026-11-01): the values and the engine, kept in a
-- DataStore by the TurntableLabStore server script, back on the next Play
local saveRow = row(40)
local saveB = button(saveRow, "", UDim2.new(0.62, -4, 1, 0), Color3.fromRGB(40, 110, 70))
local unsaveB = button(saveRow, "저장 지우기", UDim2.new(0.38, -4, 1, 0))
unsaveB.Position = UDim2.new(0.62, 4, 0, 0)
unsaveB.TextSize = 13
local saveStatus = label(row(16), "", UDim2.fromScale(1, 1), nil, { TextColor3 = DIM, TextSize = 12 })
-- copy another track's saved values onto this one (user 2026-11-01); they
-- stay unsaved here until 💾
local copyFromB = button(row(36), "📋 다른 곡 설정 가져오기", UDim2.fromScale(1, 1))
copyFromB.TextSize = 13
local pickerRow = row(150)
pickerRow.Visible = false
local picker = mk("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = CARD, BorderSizePixel = 0, ScrollBarThickness = 5,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, pickerRow)
corner(picker, 8)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }, picker)
mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, picker)

local copyRow = row(84)
label(copyRow, "오후 ClubConfig 곡 줄에 붙여 넣을 값 (눌러서 Ctrl+A, Ctrl+C)", UDim2.new(1, 0, 0, 16), nil, { TextColor3 = DIM, TextSize = 12 })
copyBox = mk("TextBox", {
	Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 18), BackgroundColor3 = CARD, TextColor3 = TEXT,
	Font = Enum.Font.Code, TextSize = 13, ClearTextOnFocus = false, TextEditable = false, Text = "", TextWrapped = true,
}, copyRow)
corner(copyBox, 6)

--------------------------------------------------------------------------
-- tracks and transport
--------------------------------------------------------------------------
-- (a joined song saves its values under its first clip's id)
local function currentId(): number
	if customId then return customId end
	local t = TRACKS[trackIndex]
	return if t.joined then t.joined.parts[1] else t.id
end

-- saved settings, by sound id (string keys, as the DataStore keeps them)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local storeRemote = ReplicatedStorage:WaitForChild("TurntableLabStore", 10) :: RemoteFunction?
local saved: {[string]: any} = {}
local storeError: string? = nil
if storeRemote then
	local ok, okServer, data = pcall(storeRemote.InvokeServer, storeRemote, "load")
	if ok and okServer then saved = data else storeError = tostring(if ok then data else okServer) end
else
	storeError = "서버 스크립트(TurntableLabStore)가 없어요"
end
local function savedFor(id: number): any
	return saved[tostring(id)]
end

local function refreshTrack()
	trackLabel.Text = if customId then ("ID " .. customId) else string.format("%d/%d  %s", trackIndex, #TRACKS, TRACKS[trackIndex].title)
	repeatB.Text = if looped then "🔁 반복 켬" else "🔁 반복 끔"
	repeatB.BackgroundColor3 = if looped then Color3.fromRGB(70, 70, 130) else CARD
	for i, b in ipairs(listButtons) do
		local on = customId == nil and i == trackIndex
		b.BackgroundTransparency = if on then 0 else 1
		b.BackgroundColor3 = if on then Color3.fromRGB(110, 40, 95) else BG
		local t = TRACKS[i]
		local key = if t.joined then t.joined.parts[1] else t.id
		local tags = {}
		if t.joined then table.insert(tags, "🔗 " .. #t.joined.parts .. "구간") end
		if savedFor(key) then
			table.insert(tags, "💾 저장됨")
		elseif not t.joined then
			table.insert(tags, if t.club then "클럽 값 있음" elseif t.seg then "녹음 구간" else "클럽: 기본")
		end
		listTags[i].Text = table.concat(tags, " · ")
		listTags[i].TextColor3 = if savedFor(key) then Color3.fromRGB(120, 230, 150) else DIM
	end
	ohuB.AutoButtonColor = customId == nil
	ohuB.TextTransparency = if customId then 0.6 else 0
end

-- engine switch: the other engine picks up at the same time, playing or not
local function paintEngine()
	engineB.Text = if engine == "sound" then "엔진: Sound (오후와 같음) · 누르면 새 엔진" else "엔진: AudioPlayer (새 API · 디노이즈 됨) · 누르면 Sound"
	engineB.BackgroundColor3 = if engine == "sound" then CARD else Color3.fromRGB(40, 90, 140)
end
local function setEngine(e: string)
	if e == engine then return end
	local t, playing = sound.TimePosition, sound.IsPlaying
	sound:Pause()
	engine = e
	sound.Looped = looped
	sound.TimePosition = t
	refreshRegion()
	if playing and not sound.IsPlaying then
		sound.TimePosition = t
		sound:Play() -- from the time set just before
	end
	paintEngine()
	refreshAll()
end

-- a track's saved values, or the untouched ones when it has none
-- (a joined song starts at volume 10 and always plays as Sounds)
local function valuesFor(id: number, isJoined: boolean?): any
	local entry = savedFor(id)
	local v = {}
	for _, p in ipairs(PARAMS) do
		local x = entry and entry[p.key]
		v[p.key] = if typeof(x) == "number" then math.clamp(x, p.min, p.max) elseif isJoined and p.key == "volume" then 10 else p.default
	end
	v.engine = if entry and entry.engine == "audio" and not isJoined then "audio" else "sound"
	return v
end
local function applySaved()
	local v = valuesFor(currentId(), joinedActive)
	for _, p in ipairs(PARAMS) do values[p.key] = v[p.key] end
	setEngine(v.engine)
	apply()
	refreshAll()
end

function paintSave()
	local entry = savedFor(currentId())
	local same = (if entry and entry.engine == "audio" then "audio" else "sound") == engine
	for _, p in ipairs(PARAMS) do
		local base = if entry and typeof(entry[p.key]) == "number" then entry[p.key] else p.default
		if math.abs(values[p.key] - base) > 1e-6 then same = false end
	end
	saveB.Text = if entry and same then "💾 이 곡 저장됨" elseif entry then "💾 바뀐 값 저장하기" else "💾 이 곡 설정 저장"
	saveB.BackgroundColor3 = if entry and same then Color3.fromRGB(40, 70, 55) else Color3.fromRGB(40, 140, 80)
	unsaveB.TextTransparency = if entry then 0 else 0.6
	if storeError then
		saveStatus.Text = "⚠ 저장소를 못 써요: " .. storeError
	elseif entry and not same then
		saveStatus.Text = "저장된 값과 달라요 (안 누르면 다음 플레이 때 저장된 값으로 돌아가요)"
	elseif entry then
		saveStatus.Text = "다음 플레이 때도 이 값으로 시작해요"
	else
		saveStatus.Text = "저장 안 됨: 다음 플레이 때 원본 값으로 시작해요"
	end
end

local cancelFade: () -> () -- the crossfade, below
local prepareNext: (number?) -> ()

local loadToken = 0
local function load(playNow: boolean)
	loadToken += 1
	local my = loadToken
	cancelFade()
	local wasPlaying = sound.IsPlaying or playNow
	sound:Stop()
	joined:Stop()
	joinedActive = false
	loopA, loopB, regionOn = nil, nil, false -- marks belong to one track
	refreshRegion()
	-- both engines hold the track, ready for a switch
	snd.SoundId = "rbxassetid://" .. currentId()
	ap.AssetId = "rbxassetid://" .. currentId()
	snd.TimePosition, ap.TimePosition = 0, 0
	-- a joined song: its player takes over the transport
	local t = if customId then nil else TRACKS[trackIndex]
	if t and t.joined then
		joinedActive = true
		joined.pendingAt = nil
		joined:Load({ title = t.title, joined = t.joined })
	end
	statusLabel.Text = "불러오는 중…"
	pickerRow.Visible = false -- its list is for the track it was opened on
	applySaved()
	refreshTrack()
	prepareNext(nil) -- the next deck takes the song after this one
	task.spawn(function()
		local t0 = os.clock()
		while not sound.IsLoaded and os.clock() - t0 < 8 do task.wait(0.1) end
		if my ~= loadToken then return end
		if not sound.IsLoaded then
			statusLabel.Text = "⚠ 음원을 못 불러왔어요 (권한 / ID 확인)"
			return
		end
		if wasPlaying then sound:Play() end
	end)
end

--------------------------------------------------------------------------
-- crossfade test (user 2026-11-03): the next song waits on the other deck,
-- loaded, with its own saved values and volume 0. At the switch it starts
-- and the two levels cross over `xfLen` seconds (equal-power: cos / sin, or
-- straight lines), then the decks change roles. Time left = (length −
-- position) ÷ the real playback speed; the automatic switch starts one
-- frame early. "꼬리" is for clips cut with a few seconds of the next clip
-- at their end (the 2026-11-03 recording: 30 s + 4 s): the next clip then
-- starts `tail − overlap` in, so the overlapping sound lines up.
-- The decks are Sounds, so a track saved on the new engine plays here
-- without its denoise.
--------------------------------------------------------------------------
local XF_MIN, XF_MAX = 0.1, 8
local xfLen = 2
local xfCurve = "power" -- or "linear"
local xfAuto = false
local xfTail = 0 -- seconds of the next clip at the end of each clip
-- (user 2026-11-03) a Sound sits still for a moment after Play, so with a
-- tail the next clip starts that much further in to stay in line. Measured
-- in Studio: no lead = 0.10 s behind, 0.1 = 0.037 ahead, so 0.05 is closest
local XF_LEADS = { 0, 0.05, 0.1, 0.15, 0.2 }
local xfLead = 0.05
local nextIndex = 1
local nextVals: any = valuesFor(TRACKS[1].id)
local fading: any = nil
local lastDt = 1 / 60
local lastGains = { 1, 0 }

local function curveGains(f: number): (number, number)
	if xfCurve == "linear" then return 1 - f, f end
	return math.cos(f * math.pi / 2), math.sin(f * math.pi / 2)
end

local function paintXf()
	xfNextLabel.Text = "다음: " .. nextIndex .. ". " .. TRACKS[nextIndex].title
	xfLenBox.Text = fmt(xfLen) .. "초"
	xfFill.Size = UDim2.fromScale((xfLen - XF_MIN) / (XF_MAX - XF_MIN), 1)
	xfCurveB.Text = if xfCurve == "power" then "곡선: equal-power" else "곡선: 직선"
	xfAutoB.Text = if xfAuto then "곡 끝 자동: 켬" else "곡 끝 자동: 끔"
	xfAutoB.BackgroundColor3 = if xfAuto then Color3.fromRGB(120, 50, 150) else CARD
	xfTailB.Text = if xfTail > 0 then ("꼬리 " .. xfTail .. "초 (녹음 구간)") else "꼬리 없음 (곡)"
	xfTailB.BackgroundColor3 = if xfTail > 0 then Color3.fromRGB(110, 90, 30) else CARD
	xfLeadB.Text = string.format("시작 보정 %s초 (꼬리 모드에서 다음 구간을 그만큼 앞당겨요 · 누르면 바뀜)", fmt(xfLead))
	xfLeadB.TextTransparency = if xfTail > 0 then 0 else 0.5
end

function prepareNext(index: number?)
	if fading then return end
	nextIndex = index or (trackIndex % #TRACKS + 1)
	-- a joined song is not a single Sound: the song → song test skips it
	for _ = 1, #TRACKS do
		if not TRACKS[nextIndex].joined then break end
		nextIndex = nextIndex % #TRACKS + 1
	end
	local t = TRACKS[nextIndex]
	nextVals = valuesFor(t.id)
	local d = otherDeck
	d.snd:Stop()
	d.gain = 0
	d.snd.SoundId = "rbxassetid://" .. t.id
	d.snd.Looped = false
	d.snd.PlaybackRegionsEnabled = false
	d.snd.TimePosition = 0
	applyDeck(d, nextVals)
	paintXf()
end

function cancelFade()
	if not fading then return end
	fading.to.snd:Stop()
	fading.to.gain = 0
	fading.from.gain = 1
	fading = nil
	apply()
end

-- the overlap in real seconds; with a tail it may not run past the tail
local function overlapNow(): number
	if xfTail <= 0 then return xfLen end
	return math.min(xfLen, xfTail / effective())
end

local function startTransition()
	if fading then return end
	if joinedActive then
		xfStatus.Text = "이어 붙인 곡은 구간끼리 저절로 이어져요"
		return
	end
	local d = otherDeck
	if not d.snd.IsLoaded then
		xfStatus.Text = "다음 곡을 아직 불러오는 중이에요"
		return
	end
	if engine ~= "sound" then setEngine("sound") end -- the decks are Sounds
	if regionOn then
		regionOn = false
		refreshRegion()
	end
	local len = overlapNow()
	d.gain = 0
	applyDeck(d, nextVals)
	-- the next clip starts where the end of this one overlaps it (file seconds)
	local lead = if xfTail > 0 then xfLead * effectiveOf(nextVals) else 0
	d.snd.TimePosition = math.max(0, xfTail - len * effective()) + lead
	d.snd:Play()
	fading = { t0 = os.clock(), len = len, from = deck, to = d, index = nextIndex, vals = nextVals }
end

local function finishFade()
	local f = fading
	fading = nil
	f.from.snd:Stop()
	f.from.gain = 0
	f.to.gain = 1
	swapDecks()
	-- the next song is now the one on the mixer, with its own values
	customId = nil
	trackIndex = f.index
	for _, p in ipairs(PARAMS) do values[p.key] = f.vals[p.key] end
	loopA, loopB, regionOn = nil, nil, false
	ap.AssetId = "rbxassetid://" .. currentId() -- the new engine holds it too, for a switch
	apply()
	refreshAll()
	refreshTrack()
	refreshRegion()
	prepareNext(nil)
end

local function setXfLen(v: number)
	xfLen = math.clamp(math.floor(v * 10 + 0.5) / 10, XF_MIN, XF_MAX)
	paintXf()
end
holdRepeat(xfMinus, function() setXfLen(xfLen - 0.1) end)
holdRepeat(xfPlus, function() setXfLen(xfLen + 0.1) end)
xfLenBox.FocusLost:Connect(function()
	local n = tonumber(xfLenBox.Text:match("[%d%.]+") or "")
	if n then setXfLen(n) else paintXf() end
end)
local function xfFromInput(x: number)
	local f = math.clamp((x - xfBar.AbsolutePosition.X) / xfBar.AbsoluteSize.X, 0, 1)
	setXfLen(XF_MIN + f * (XF_MAX - XF_MIN))
end
xfBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = xfFromInput
		xfFromInput(input.Position.X)
	end
end)
xfCurveB.MouseButton1Click:Connect(function()
	xfCurve = if xfCurve == "power" then "linear" else "power"
	paintXf()
end)
xfAutoB.MouseButton1Click:Connect(function()
	xfAuto = not xfAuto
	paintXf()
end)
xfTailB.MouseButton1Click:Connect(function()
	xfTail = if xfTail > 0 then 0 else 4
	paintXf()
end)
xfLeadB.MouseButton1Click:Connect(function()
	xfLead = XF_LEADS[(table.find(XF_LEADS, xfLead) or 0) % #XF_LEADS + 1]
	paintXf()
end)
xfPrev.MouseButton1Click:Connect(function()
	if not fading then prepareNext((nextIndex - 2) % #TRACKS + 1) end
end)
xfNext.MouseButton1Click:Connect(function()
	if not fading then prepareNext(nextIndex % #TRACKS + 1) end
end)
xfGoB.MouseButton1Click:Connect(startTransition)

RunService.Heartbeat:Connect(function(dt)
	lastDt = dt
	if fading then
		local f = math.clamp((os.clock() - fading.t0) / fading.len, 0, 1)
		local gOut, gIn = curveGains(f)
		fading.from.gain, fading.to.gain = gOut, gIn
		fading.from.snd.Volume = values.volume * gOut
		fading.to.snd.Volume = fading.vals.volume * gIn
		lastGains = { gOut, gIn }
		xfStatus.Text = string.format("전환 중 %.1f / %.1f초\n지금 곡 %.2f · 다음 곡 %.2f", os.clock() - fading.t0, fading.len, gOut, gIn)
		if f >= 1 then finishFade() end
		return
	end
	local left = if sound.TimeLength > 0 then (sound.TimeLength - sound.TimePosition) / effective() else 0
	if joinedActive then
		xfStatus.Text = string.format("이어 붙인 곡 · 구간 %d / %d\n남은 %d:%02d", joined:GetPart(), #TRACKS[trackIndex].joined.parts, left // 60, math.floor(left % 60))
		return
	end
	if xfAuto and not regionOn and sound.IsPlaying and sound.TimeLength > 0 and left <= overlapNow() + lastDt then
		startTransition()
		return
	end
	if not otherDeck.snd.IsLoaded then
		xfStatus.Text = "다음 곡 불러오는 중…"
	else
		xfStatus.Text = string.format("다음 곡 준비됨%s\n지금 곡 남은 %d:%02d",
			if nextVals.engine == "audio" then " (디노이즈 빠짐)" else "", left // 60, math.floor(left % 60))
	end
end)

engineB.MouseButton1Click:Connect(function()
	if fading or joinedActive then return end -- a joined song plays as Sounds
	setEngine(if engine == "sound" then "audio" else "sound")
end)
paintEngine()
paintXf()

local function store(action: string)
	if not storeRemote then return end
	local id = currentId()
	local entry: any = nil
	if action == "save" then
		entry = { engine = engine }
		for _, p in ipairs(PARAMS) do entry[p.key] = values[p.key] end
	end
	saveStatus.Text = if action == "save" then "저장하는 중…" else "지우는 중…"
	local ok, okServer, err = pcall(storeRemote.InvokeServer, storeRemote, action, id, entry)
	if ok and okServer then
		storeError = nil
		saved[tostring(id)] = entry
	else
		storeError = tostring(if ok then err else okServer)
	end
	refreshTrack()
	paintSave()
end
saveB.MouseButton1Click:Connect(function() store("save") end)

local function titleOf(id: number): string
	for _, t in ipairs(TRACKS) do
		if t.id == id then return t.title end
	end
	return "ID " .. id
end
local function openPicker()
	for _, c in ipairs(picker:GetChildren()) do
		if c:IsA("GuiButton") or (c:IsA("TextLabel")) then c:Destroy() end
	end
	local n = 0
	for key, entry in pairs(saved) do
		local id = tonumber(key)
		if id and id ~= currentId() and typeof(entry) == "table" then
			n += 1
			local b = mk("TextButton", {
				Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = BG, Text = "", AutoButtonColor = true, LayoutOrder = n,
			}, picker)
			corner(b, 5)
			label(b, titleOf(id), UDim2.new(1, -150, 1, 0), UDim2.fromOffset(8, 0), { TextSize = 13 })
			label(b, string.format("x%s · 템포 x%s · vol %s", fmt(entry.speed or 1), fmt(entry.tempo or 1), fmt((entry.volume or 1) * (entry.boost or 1) * (entry.boost2 or 1) * (entry.boost3 or 1) * (entry.boost4 or 1))),
				UDim2.fromOffset(140, 28), UDim2.new(1, -144, 0, 0), { TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right })
			b.MouseButton1Click:Connect(function()
				for _, p in ipairs(PARAMS) do
					local v = entry[p.key]
					values[p.key] = if typeof(v) == "number" then math.clamp(v, p.min, p.max) else p.default
				end
				setEngine(if entry.engine == "audio" then "audio" else "sound")
				apply()
				refreshAll()
				pickerRow.Visible = false
				saveStatus.Text = "「" .. titleOf(id) .. "」 설정을 가져왔어요 · 💾를 눌러야 이 곡에 저장돼요"
			end)
		end
	end
	if n == 0 then
		label(picker, "가져올 수 있는 저장된 곡이 없어요", UDim2.new(1, 0, 0, 28), nil, { TextColor3 = DIM, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center })
	end
	pickerRow.Visible = true
end
copyFromB.MouseButton1Click:Connect(function()
	if pickerRow.Visible then pickerRow.Visible = false else openPicker() end
end)
unsaveB.MouseButton1Click:Connect(function()
	if savedFor(currentId()) then store("clear") end
end)

prevB.MouseButton1Click:Connect(function()
	customId = nil
	trackIndex = (trackIndex - 2) % #TRACKS + 1
	load(false)
end)
nextB.MouseButton1Click:Connect(function()
	customId = nil
	trackIndex = trackIndex % #TRACKS + 1
	load(false)
end)
for i, b in ipairs(listButtons) do
	b.MouseButton1Click:Connect(function()
		customId = nil
		trackIndex = i
		load(true) -- picked from the list: play it
	end)
end
idLoad.MouseButton1Click:Connect(function()
	local n = tonumber((idBox.Text:gsub("%D", "")))
	if n and n > 0 then
		customId = n
		load(false)
	end
end)
playB.MouseButton1Click:Connect(function()
	if sound.IsPlaying then
		sound:Pause()
	elseif sound.TimePosition > 0 then
		sound:Resume()
	else
		sound:Play()
	end
end)
stopB.MouseButton1Click:Connect(function()
	cancelFade()
	sound:Stop()
	sound.TimePosition = 0
end)
repeatB.MouseButton1Click:Connect(function()
	looped = not looped
	if not regionOn then sound.Looped = looped end
	refreshTrack()
end)
seekBar.MouseButton1Down:Connect(function(x)
	if sound.TimeLength > 0 then
		local f = math.clamp((x - seekBar.AbsolutePosition.X) / seekBar.AbsoluteSize.X, 0, 1)
		sound.TimePosition = f * sound.TimeLength
	end
end)
ohuB.MouseButton1Click:Connect(function()
	if customId then return end
	-- what the club plays it with now: its own club value for the uploads, as uploaded
	-- at the club volume (ClubConfig.MusicVolume 0.55) for the Roblox tracks
	local t = TRACKS[trackIndex]
	local club = clubValues(t)
	for _, p in ipairs(PARAMS) do
		local v = club and club[p.key]
		values[p.key] = if typeof(v) == "number" then v else p.default
	end
	if not club then values.volume = 0.55 end
	setEngine("sound")
	set("speed", values.speed)
end)
allB.MouseButton1Click:Connect(function()
	for _, p in ipairs(PARAMS) do values[p.key] = p.default end
	set("speed", 1)
end)

-- A-B loop: the marks live in track seconds (TimePosition), so they hold
-- at any speed
local function mmss10(s: number): string
	return string.format("%d:%04.1f", s // 60, s % 60)
end
function refreshRegion()
	aLabel.Text = "A  " .. (if loopA then mmss10(loopA) else "—")
	bLabel.Text = "B  " .. (if loopB then mmss10(loopB) else "—")
	local ready = loopA ~= nil and loopB ~= nil and loopB > loopA + 0.05
	if not ready then regionOn = false end
	regionB.Text = if regionOn then "🔂 구간 반복 켬" elseif ready then "🔂 구간 반복 끔" else "A와 B를 먼저 찍어요"
	regionB.BackgroundColor3 = if regionOn then Color3.fromRGB(150, 120, 30) else CARD
	if regionOn then
		sound.LoopRegion = NumberRange.new(loopA :: number, loopB :: number)
		sound.PlaybackRegionsEnabled = true
		sound.Looped = true
		-- a new LoopRegion only takes hold on a Pause / Resume (Studio 2026-11-01)
		local t = math.clamp(sound.TimePosition, loopA :: number, loopB :: number)
		if t >= (loopB :: number) - 0.05 then t = loopA :: number end
		local playing = sound.IsPlaying
		sound:Pause()
		sound.TimePosition = t
		if playing then sound:Resume() end
	else
		sound.PlaybackRegionsEnabled = false
		sound.Looped = looped
	end
	local len = sound.TimeLength
	regionBand.Visible = ready and len > 0
	if ready and len > 0 then
		regionBand.Position = UDim2.fromScale((loopA :: number) / len, 0)
		regionBand.Size = UDim2.fromScale(((loopB :: number) - (loopA :: number)) / len, 1)
	end
end
local function mark(which: string, t: number)
	t = math.clamp(math.floor(t * 10 + 0.5) / 10, 0, math.max(sound.TimeLength, 0))
	if which == "A" then loopA = t else loopB = t end
	if loopA and loopB and loopA > loopB then loopA, loopB = loopB, loopA end
	refreshRegion()
end
setA.MouseButton1Click:Connect(function() mark("A", sound.TimePosition) end)
setBm.MouseButton1Click:Connect(function() mark("B", sound.TimePosition) end)
holdRepeat(aBack, function() if loopA then mark("A", loopA - 0.1) end end)
holdRepeat(aFwd, function() if loopA then mark("A", loopA + 0.1) end end)
holdRepeat(bBack, function() if loopB then mark("B", loopB - 0.1) end end)
holdRepeat(bFwd, function() if loopB then mark("B", loopB + 0.1) end end)
regionB.MouseButton1Click:Connect(function()
	if loopA and loopB and loopB > loopA + 0.05 then
		regionOn = not regionOn
		if regionOn then sound.TimePosition = loopA :: number end
		refreshRegion()
		if regionOn and not sound.IsPlaying then sound:Resume() end
	end
end)
regionClear.MouseButton1Click:Connect(function()
	loopA, loopB, regionOn = nil, nil, false
	refreshRegion()
end)

local function mmss(s: number): string
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- the console's platters turn with the speed while it plays
local console = workspace:WaitForChild("TurntableLab", 10)
local spinners = {}
if console then
	for _, d in ipairs(console:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Platter" or d.Name == "RecordLabel" or d.Name == "PlatterRing") then
			table.insert(spinners, d)
		end
	end
	local deskTop = console:FindFirstChild("DeskTop")
	local prompt = deskTop and deskTop:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt.Triggered:Connect(function() panel.Visible = true end) end
end

RunService.RenderStepped:Connect(function(dt)
	local len = sound.TimeLength
	timeLabel.Text = string.format("%s / %s", mmss(sound.TimePosition), mmss(len))
	seekFill.Size = UDim2.fromScale(if len > 0 then math.clamp(sound.TimePosition / len, 0, 1) else 0, 1)
	playB.Text = if sound.IsPlaying then "⏸ 일시정지" else "▶ 재생"
	if sound.IsLoaded and statusLabel.Text == "불러오는 중…" then statusLabel.Text = "" end
	if sound.IsPlaying then
		statusLabel.Text = "재생 중"
		local turn = CFrame.Angles(dt * math.pi * 2 * 0.55 * snd.PlaybackSpeed, 0, 0) -- 33 rpm at x1
		for _, part in ipairs(spinners) do part.CFrame = part.CFrame * turn end
	elseif statusLabel.Text == "재생 중" then
		statusLabel.Text = "정지"
	end
end)

refreshTrack()
refreshAll()
load(false)
refreshRegion()

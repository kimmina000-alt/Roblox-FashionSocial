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

-- 오후 club playlist (ClubConfig.Playlist, 2026-11-01) with its own values
local TRACKS = {
	{ title = "EDM Club Night", id = 136689162723802 },
	{ title = "Tomorrow Starts Now", id = 124325173394473 },
	{ title = "Free", id = 128563409090413 },
	{ title = "Run the Night", id = 129158012324844 },
	{ title = "Light It Up", id = 103356166395852 },
	{ title = "Future Legend", id = 115846580489388 },
	{ title = "Skyline Bounce", id = 132588706181756 },
	{ title = "No Gravity Tonight", id = 84501429041638 },
	{ title = "Gomood", id = 92774322259700 },
	{ title = "Midnight Frequency", id = 75257760347020 },
	{ title = "Under the Starlight", id = 101328005557095 },
	{ title = "SAN FRANCISCO · DOM DOLLA", id = 113497657842744, speed = 0.5, octave = 2 },
	{ title = "LOVE LOVE LOVE · EPIC HIGH", id = 100033043291152, speed = 0.5, octave = 2 },
	{ title = "TANI TANI · TANI", id = 131058655527940, speed = 0.5, octave = 2 },
	{ title = "LOVE ATTACK · RESCENE", id = 103905057186427, speed = 0.5, octave = 2 },
	{ title = "GRIT X DIET COKE", id = 106119256110919, speed = 0.5, octave = 2 },
	{ title = "CASH OUT", id = 140111630417316, speed = 0.5, octave = 2 },
	{ title = "MY MIND", id = 106804146862342, speed = 0.5, octave = 2 },
	{ title = "PLAIN JANE · A$AP FERG", id = 78832462526893, speed = 0.5, octave = 2 },
	{ title = "PUMP IT UP", id = 125479000346000, speed = 0.5, octave = 2 },
	{ title = "404 (New Era) · KiiiKiii", id = 74181572220193, speed = 0.5, octave = 2 },
	{ title = "BANG BANG · IVE", id = 126421508146335, speed = 2, volume = 20, octave = 0.5 },
	-- lab only (user 2026-11-01)
	{ title = "소원을 말해 봐 / 소녀시대", id = 128410308180471 },
	{ title = "Love 119 / RIIZE", id = 106367625479063 },
	-- K-POP (user 2026-11-01)
	{ title = "BAD / ATEEZ", id = 89023892900416 },
	{ title = "Lemon Tang / 하츠투하츠", id = 99550529874718 },
	{ title = "Catch Catch / 최예나", id = 100968974338230 },
	{ title = "Get A Guitar / RIIZE", id = 100035331158760 },
	{ title = "Bubble Pop / HyunA", id = 117125823291884 },
	-- the user's own edits (2026-11-01)
	{ title = "Mirror / IVE", id = 139326796173276 }, -- (first added as "피치 후 증폭"; named by the user 2026-11-01)
	{ title = "증폭 후 피치", id = 88451163103580 },
	-- K-POP, new uploads (user 2026-11-01)
	{ title = "BAD / ATEEZ (새 음원)", id = 134942349436280 },
	{ title = "소원을 말해봐(Genie) / 소녀시대 (새 음원)", id = 128270208751659 },
	{ title = "Bubble Pop / 현아 (새 음원)", id = 76388700698178 },
	{ title = "Get A Guitar / RIIZE (새 음원)", id = 91762270038050 },
	{ title = "Love 119 / RIIZE (새 음원)", id = 119473981131981 },
	{ title = "Catch Catch / YENA (새 음원)", id = 80583279340768 },
	{ title = "Lemon Tang / Hearts2Hearts (새 음원)", id = 97032815457241 },
	{ title = "Lemonade / aespa", id = 132067415333401 },
}

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
local STEPS = { 0.01, 0.05, 0.1, 0.5 }
local values = { speed = 1, tempo = 1, volume = 1, boost = 1, octave = 1, low = 0, mid = 0, high = 0, humHz = 20, hissHz = 20000, gate = -80 }
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
-- sound: one Sound and five PitchShift effects in a row. One effect only
-- reaches 0.5..2, so a bigger octave is split into equal parts.
--------------------------------------------------------------------------
local boostGroup = Instance.new("SoundGroup")
boostGroup.Name = "LabBoost"
boostGroup.Parent = SoundService
local snd = Instance.new("Sound")
snd.Name = "LabTrack"
snd.Looped = looped
snd.SoundGroup = boostGroup
snd.Parent = SoundService
local shifters = {}
for i = 1, 5 do
	local fx = Instance.new("PitchShiftSoundEffect")
	fx.Name = "PitchShift" .. i
	fx.Priority = i
	fx.Enabled = false
	fx.Parent = snd
	shifters[i] = fx
end
local eq = Instance.new("EqualizerSoundEffect")
eq.Name = "EQ"
eq.Priority = 10
eq.LowGain, eq.MidGain, eq.HighGain = 0, 0, 0
eq.Enabled = false
eq.Parent = snd

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
local out = mkAudio("AudioDeviceOutput", "Out")
do
	local nodes = { ap }
	for _, s in ipairs(apShifters) do table.insert(nodes, s) end
	for _, n in ipairs({ apEq, humFilter, hissFilter, gate, boostFader, out }) do table.insert(nodes, n) end
	for i = 1, #nodes - 1 do
		local w = Instance.new("Wire")
		w.SourceInstance = nodes[i]
		w.TargetInstance = nodes[i + 1]
		w.Parent = nodes[i + 1]
	end
end
ap.Looping = looped
chain.Parent = SoundService

-- one face for both engines: the transport code below talks to `sound` as
-- if it were a Sound; on the new engine Pause / Resume are Stop / Play
-- keeping the time, and the loop region is LoopRegion with no switch
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
local function effective(): (number, number)
	local playSpeed = math.min(values.speed * values.tempo, 20)
	local tempo = playSpeed / values.speed
	return playSpeed, math.clamp(values.octave / tempo, 1 / 32, 32)
end

-- both engines get every value, so switching keeps the sound
local function apply()
	local playSpeed, octave = effective()
	snd.PlaybackSpeed, ap.PlaybackSpeed = playSpeed, playSpeed
	snd.Volume, ap.Volume = values.volume, values.volume
	boostGroup.Volume, boostFader.Volume = values.boost, values.boost
	local split = if math.abs(octave - 1) < 1e-4 then {} else octaveParts(octave)
	-- the raw test is for PitchShiftSoundEffect only (AudioPitchShifter cuts at 2)
	local parts = if rawOctave and #split > 0 then { octave } else split
	for i, fx in ipairs(shifters) do
		fx.Octave = parts[i] or 1
		fx.Enabled = parts[i] ~= nil
	end
	for i, fx in ipairs(apShifters) do
		fx.Pitch = split[i] or 1
		fx.Bypass = split[i] == nil
	end
	eq.LowGain, eq.MidGain, eq.HighGain = values.low, values.mid, values.high
	eq.Enabled = values.low ~= 0 or values.mid ~= 0 or values.high ~= 0
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
	local s = string.format("%.2f", v)
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
	local tags = {}
	if t.speed then table.insert(tags, "x" .. fmt(t.speed)) end
	if t.octave then table.insert(tags, "oct " .. fmt(t.octave)) end
	if t.volume then table.insert(tags, "vol " .. fmt(t.volume)) end
	listTags[i] = label(b, table.concat(tags, " · "), UDim2.fromOffset(92, 28), UDim2.new(1, -92, 0, 0), { TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right })
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
	local b = button(stepRow, fmt(s), UDim2.new(0.25, -20, 1, 0))
	b.Position = UDim2.new((i - 1) * 0.25, 64 - (i - 1) * 16, 0, 0)
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
	for _, k in ipairs({ "speed", "tempo", "volume", "boost", "octave", "low", "mid", "high" }) do
		table.insert(parts, k .. " = " .. fmt(values[k]))
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
		fmt(playSpeed), fmt(playSpeed * octave), fmt(values.volume * values.boost),
		if engine == "sound" then "PitchShift" else "AudioPitchShifter",
		if #parts == 0 then "꺼짐" else table.concat(partText, " × ") .. string.format(" (%d개)", #parts))
end

local function set(key: string, v: number)
	local p
	for _, q in ipairs(PARAMS) do if q.key == key then p = q end end
	if typeof(v) ~= "number" or v ~= v then return end
	values[key] = math.clamp(math.floor(v * 100 + 0.5) / 100, p.min, p.max)
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
local function currentId(): number
	return customId or TRACKS[trackIndex].id
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
		local tags = {}
		if savedFor(t.id) then
			table.insert(tags, "💾 저장됨")
		else
			if t.speed then table.insert(tags, "x" .. fmt(t.speed)) end
			if t.octave then table.insert(tags, "oct " .. fmt(t.octave)) end
			if t.volume then table.insert(tags, "vol " .. fmt(t.volume)) end
		end
		listTags[i].Text = table.concat(tags, " · ")
		listTags[i].TextColor3 = if savedFor(t.id) then Color3.fromRGB(120, 230, 150) else DIM
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

-- the track's saved values, or the untouched ones when it has none
local function applySaved()
	local entry = savedFor(currentId())
	for _, p in ipairs(PARAMS) do
		local v = entry and entry[p.key]
		values[p.key] = if typeof(v) == "number" then math.clamp(v, p.min, p.max) else p.default
	end
	setEngine(if entry and entry.engine == "audio" then "audio" else "sound")
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

local loadToken = 0
local function load(playNow: boolean)
	loadToken += 1
	local my = loadToken
	local wasPlaying = sound.IsPlaying or playNow
	sound:Stop()
	loopA, loopB, regionOn = nil, nil, false -- marks belong to one track
	refreshRegion()
	-- both engines hold the track, ready for a switch
	snd.SoundId = "rbxassetid://" .. currentId()
	ap.AssetId = "rbxassetid://" .. currentId()
	snd.TimePosition, ap.TimePosition = 0, 0
	statusLabel.Text = "불러오는 중…"
	pickerRow.Visible = false -- its list is for the track it was opened on
	applySaved()
	refreshTrack()
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

engineB.MouseButton1Click:Connect(function()
	setEngine(if engine == "sound" then "audio" else "sound")
end)
paintEngine()

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
			label(b, string.format("x%s · 템포 x%s · vol %s", fmt(entry.speed or 1), fmt(entry.tempo or 1), fmt((entry.volume or 1) * (entry.boost or 1))),
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
	local t = TRACKS[trackIndex]
	values.speed = t.speed or 1
	values.octave = t.octave or 1
	values.volume = math.min(t.volume or 1, 10)
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

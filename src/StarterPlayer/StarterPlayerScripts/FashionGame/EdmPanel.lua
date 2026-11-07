--!strict
-- The DJ's music controls in the turntable window (D-733 → D-735, user
-- 2026-11-01: kick / pump / drop / echo out; an EDM button and three sliders).
-- ClubMusicController places it; EdmController plays the EDM track for everyone.
--   [🎛 EDM 1][🎛 EDM 2][🎛 EDM 3][🔄 초기화]   (D-759: a button per track, the
--                                               lit one plays; D-736: 초기화 = sliders back to x1)
--   ⚡ EDM 속도   ━━━●━━ x1.00     (the EDM track's speed)
--   🔉 EDM 볼륨   ━━━●━━ x1.0      (the EDM track alone, D-764)
--   🎵 노래 속도  ━━━●━━ x1.00     (the song: the old "MusicSpeed" action)
--   🔊 볼륨       ━━━●━━ x1.0      (the old "MusicVolume" action)
-- Sliders send while dragging (a few times a second) and on release.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local EdmConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EdmConfig"))
local Music = FashionGame:WaitForChild("Remotes"):WaitForChild("Music") :: RemoteFunction

local EdmPanel = {}

local ON = Color3.fromRGB(255, 70, 210)
local OFF = Color3.fromRGB(20, 27, 56)
local TEXT = Color3.fromRGB(255, 255, 255)
local SUB = Color3.fromRGB(170, 182, 214)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, r: number)
	create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function call(action: string, payload: any)
	task.spawn(function()
		pcall(function() Music:InvokeServer(action, payload) end)
	end)
end

local function readState(): {[string]: any}
	local raw = FashionGame:GetAttribute("ClubEdm")
	if typeof(raw) ~= "string" then return {} end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

local function snap(v: number, range: { min: number, max: number, step: number }): number
	local n = math.floor((v - range.min) / range.step + 0.5)
	return math.clamp(math.floor((range.min + n * range.step) * 100 + 0.5) / 100, range.min, range.max)
end

export type Panel = { frame: Frame, place: (y: number, width: number, compact: boolean) -> number }

function EdmPanel.new(parent: Instance): Panel
	local frame = create("Frame", { Name = "EdmPanel", BackgroundTransparency = 1, Visible = false }, parent) :: Frame

	-- (D-759) a button per EDM track (EdmConfig.Tracks): on that track, a tap on
	-- the one playing turns it off, a tap on another switches to it
	local edmButtons: {TextButton} = {}
	for i, spec in ipairs(EdmConfig.Tracks) do
		local button = create("TextButton", {
			Name = "EdmButton" .. i, BackgroundColor3 = OFF, Text = "🎛 " .. spec.name, TextColor3 = TEXT, TextScaled = true,
			Font = Enum.Font.GothamBold, AutoButtonColor = true,
		}, frame)
		corner(button, 8)
		create("UITextSizeConstraint", { MaxTextSize = 13 }, button)
		create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, button)
		button.Activated:Connect(function()
			local st = readState()
			local playing = st.on == true and (st.track or 1) == i
			call("Edm", { k = "edm", v = if playing then false else i })
		end)
		edmButtons[i] = button
	end
	-- ↺ every slider back to x1 (D-736, user)
	local resetButton = create("TextButton", {
		-- (🔄: ↺ is not in the font, it showed as a box)
		Name = "ResetButton", BackgroundColor3 = OFF, Text = "🔄 초기화", TextColor3 = TEXT, TextScaled = true,
		Font = Enum.Font.GothamBold, AutoButtonColor = true,
	}, frame)
	corner(resetButton, 8)
	create("UITextSizeConstraint", { MaxTextSize = 13 }, resetButton)
	create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, resetButton)
	resetButton.Activated:Connect(function()
		call("Edm", { k = "speed", v = 1 })
		call("Edm", { k = "volume", v = EdmConfig.EdmVolumeDefault or 1 }) -- (D-940: 0.5)
		call("MusicSpeed", 1)
		call("MusicVolume", 1)
	end)

	type Slider = { name: TextLabel?, bar: Frame, fill: Frame, knob: Frame, value: TextLabel, dragging: boolean,
		range: { min: number, max: number, step: number }, format: string }
	local sliders: {[string]: Slider} = {}
	local function slider(key: string, label: string?, range: { min: number, max: number, step: number }, format: string,
		sendValue: (number) -> ())
		local name = if label then create("TextLabel", {
			Name = "Label_" .. key, BackgroundTransparency = 1, Text = label, TextColor3 = TEXT, Font = Enum.Font.GothamBold,
			TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		}, frame) else nil
		if name then create("UITextSizeConstraint", { MaxTextSize = 13 }, name) end
		local bar = create("Frame", { Name = "Slider_" .. key, BackgroundColor3 = OFF, Active = true }, frame)
		corner(bar, 6)
		local fill = create("Frame", { Name = "Fill", BackgroundColor3 = ON, Size = UDim2.fromScale(0, 1) }, bar)
		corner(fill, 6)
		local knob = create("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = TEXT }, bar)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
		local value = create("TextLabel", {
			Name = "Value_" .. key, BackgroundTransparency = 1, Text = "", TextColor3 = SUB, Font = Enum.Font.GothamBold,
			TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
		}, frame)
		create("UITextSizeConstraint", { MaxTextSize = 12 }, value)
		local s: Slider = { name = name, bar = bar, fill = fill, knob = knob, value = value, dragging = false, range = range, format = format }
		sliders[key] = s
		local lastSent, lastValue = 0, -1
		local function setFrom(x: number, final: boolean)
			local t = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			local v = snap(range.min + t * (range.max - range.min), range)
			local shown = (v - range.min) / (range.max - range.min)
			fill.Size = UDim2.fromScale(shown, 1)
			knob.Position = UDim2.fromScale(shown, 0.5)
			value.Text = string.format(format, v)
			if v ~= lastValue and (final or os.clock() - lastSent > 0.15) then
				lastSent, lastValue = os.clock(), v
				sendValue(v)
			end
		end
		bar.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			s.dragging = true
			lastValue = -1
			setFrom(input.Position.X, false)
			local moved, ended
			moved = UserInputService.InputChanged:Connect(function(change)
				if change.UserInputType == Enum.UserInputType.MouseMovement or change == input then setFrom(change.Position.X, false) end
			end)
			ended = UserInputService.InputEnded:Connect(function(done)
				if done == input or done.UserInputType == Enum.UserInputType.MouseButton1 then
					s.dragging = false
					setFrom(done.Position.X, true)
					moved:Disconnect()
					ended:Disconnect()
				end
			end)
		end)
	end
	slider("edm", "⚡ EDM 속도", EdmConfig.EdmSpeed, "x%.2f", function(v) call("Edm", { k = "speed", v = v }) end)
	slider("edmVolume", "🔉 EDM 볼륨", EdmConfig.EdmVolume, "x%.1f", function(v) call("Edm", { k = "volume", v = v }) end) -- (D-764)
	slider("song", "🎵 노래 속도", EdmConfig.SongSpeed, "x%.2f", function(v) call("MusicSpeed", v) end)
	slider("volume", "🔊 노래 볼륨", EdmConfig.Volume, "x%.1f", function(v) call("MusicVolume", v) end) -- (name: user's picture, D-737)

	local function showSlider(key: string, v: number)
		local s = sliders[key]
		if s.dragging then return end
		local shown = math.clamp((v - s.range.min) / (s.range.max - s.range.min), 0, 1)
		s.fill.Size = UDim2.fromScale(shown, 1)
		s.knob.Position = UDim2.fromScale(shown, 0.5)
		s.value.Text = string.format(s.format, v)
	end
	local function num(name: string, default: number): number
		local v = FashionGame:GetAttribute(name)
		return if typeof(v) == "number" then v else default
	end
	local function refresh()
		local st = readState()
		local on = st.on == true
		for i, button in ipairs(edmButtons) do
			button.BackgroundColor3 = if on and (st.track or 1) == i then ON else OFF
		end
		showSlider("edm", if typeof(st.speed) == "number" then st.speed else 1)
		showSlider("edmVolume", if typeof(st.volume) == "number" then st.volume else EdmConfig.EdmVolumeDefault or 1)
		showSlider("song", num("ClubMusicSpeed", 1))
		showSlider("volume", num("ClubMusicVolume", 1))
	end
	FashionGame:GetAttributeChangedSignal("ClubEdm"):Connect(refresh)
	FashionGame:GetAttributeChangedSignal("ClubMusicSpeed"):Connect(refresh)
	FashionGame:GetAttributeChangedSignal("ClubMusicVolume"):Connect(refresh)
	refresh()

	-- lays itself out from y in its parent; returns the height used
	local function place(y: number, width: number, compact: boolean): number
		-- (phones: 20 / 2 since D-764's fifth row, to stay inside the window)
		local h = if compact then 20 else 28
		local gap = if compact then 2 else 6
		local leftW = math.floor(width * 0.3) -- (the EDM button / a slider's name)
		local valueW = if compact then 40 else 46
		frame.Position = UDim2.fromOffset(0, y)
		-- [🎛 EDM 1][🎛 EDM 2][🎛 EDM 3][🔄 초기화], then a row per slider
		local n = #edmButtons
		local resetW = math.floor(width * 0.22)
		local each = math.floor((width - resetW - n * gap) / math.max(n, 1))
		for i, button in ipairs(edmButtons) do
			button.Position = UDim2.fromOffset((i - 1) * (each + gap), 0)
			button.Size = UDim2.fromOffset(each, h)
		end
		resetButton.Position = UDim2.fromOffset(n * (each + gap), 0)
		resetButton.Size = UDim2.fromOffset(width - n * (each + gap), h)
		for i, key in ipairs({ "edm", "edmVolume", "song", "volume" }) do
			local s = sliders[key]
			local rowY = i * (h + gap)
			if s.name then
				s.name.Position = UDim2.fromOffset(2, rowY)
				s.name.Size = UDim2.fromOffset(leftW - 2, h)
			end
			s.bar.Position = UDim2.fromOffset(leftW + 10, rowY + h / 2 - 6)
			s.bar.Size = UDim2.fromOffset(width - leftW - valueW - 20, 12)
			s.knob.Size = UDim2.fromOffset(18, 18)
			s.value.Position = UDim2.fromOffset(width - valueW, rowY)
			s.value.Size = UDim2.fromOffset(valueW, h)
		end
		local total = 5 * h + 4 * gap
		frame.Size = UDim2.fromOffset(width, total)
		return total
	end

	return { frame = frame, place = place }
end

return EdmPanel

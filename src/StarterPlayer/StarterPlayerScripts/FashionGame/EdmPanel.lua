--!strict
-- The DJ's music controls in the turntable window (D-733 → D-735, user
-- 2026-11-01: kick / pump / drop / echo out; an EDM button and three sliders).
-- ClubMusicController places it; EdmController plays the EDM track for everyone.
--   [🎛 EDM OFF]  ━━━●━━ x1.00     (the EDM track's speed)
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

	local edmButton = create("TextButton", {
		Name = "EdmButton", BackgroundColor3 = OFF, Text = "🎛 EDM OFF", TextColor3 = TEXT, TextScaled = true,
		Font = Enum.Font.GothamBold, AutoButtonColor = true,
	}, frame)
	corner(edmButton, 8)
	create("UITextSizeConstraint", { MaxTextSize = 13 }, edmButton)
	create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, edmButton)
	edmButton.Activated:Connect(function()
		call("Edm", { k = "edm", v = readState().on ~= true })
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
	slider("edm", nil, EdmConfig.EdmSpeed, "x%.2f", function(v) call("Edm", { k = "speed", v = v }) end)
	slider("song", "🎵 노래 속도", EdmConfig.SongSpeed, "x%.2f", function(v) call("MusicSpeed", v) end)
	slider("volume", "🔊 볼륨", EdmConfig.Volume, "x%.1f", function(v) call("MusicVolume", v) end)

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
		edmButton.Text = if on then "🎛 EDM ON" else "🎛 EDM OFF"
		edmButton.BackgroundColor3 = if on then ON else OFF
		showSlider("edm", if typeof(st.speed) == "number" then st.speed else 1)
		showSlider("song", num("ClubMusicSpeed", 1))
		showSlider("volume", num("ClubMusicVolume", 1))
	end
	FashionGame:GetAttributeChangedSignal("ClubEdm"):Connect(refresh)
	FashionGame:GetAttributeChangedSignal("ClubMusicSpeed"):Connect(refresh)
	FashionGame:GetAttributeChangedSignal("ClubMusicVolume"):Connect(refresh)
	refresh()

	-- lays itself out from y in its parent; returns the height used
	local function place(y: number, width: number, compact: boolean): number
		local h = if compact then 22 else 28
		local gap = if compact then 4 else 6
		local leftW = math.floor(width * 0.3) -- (the EDM button / a slider's name)
		local valueW = if compact then 40 else 46
		frame.Position = UDim2.fromOffset(0, y)
		for i, key in ipairs({ "edm", "song", "volume" }) do
			local s = sliders[key]
			local rowY = (i - 1) * (h + gap)
			if key == "edm" then
				edmButton.Position = UDim2.fromOffset(0, rowY)
				edmButton.Size = UDim2.fromOffset(leftW, h)
			elseif s.name then
				s.name.Position = UDim2.fromOffset(2, rowY)
				s.name.Size = UDim2.fromOffset(leftW - 2, h)
			end
			s.bar.Position = UDim2.fromOffset(leftW + 10, rowY + h / 2 - 6)
			s.bar.Size = UDim2.fromOffset(width - leftW - valueW - 20, 12)
			s.knob.Size = UDim2.fromOffset(18, 18)
			s.value.Position = UDim2.fromOffset(width - valueW, rowY)
			s.value.Size = UDim2.fromOffset(valueW, h)
		end
		local total = 3 * h + 2 * gap
		frame.Size = UDim2.fromOffset(width, total)
		return total
	end

	return { frame = frame, place = place }
end

return EdmPanel

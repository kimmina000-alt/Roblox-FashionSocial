--!strict
-- The DJ's EDM controls in the turntable window (D-733, Shared/EdmConfig;
-- ClubMusicController places it, EdmController plays it for everyone):
--   [🥁 킥] [💓 펌핑] [🚀 드롭]
--   [🌀 플랜저] [🔁 에코] [👆 박자 124]
--   🎚 필터 ━━━●   🔊 베이스 ●━━━
-- Each change goes to the server ("Edm" on the Music remote, DJ only).
-- 👆 박자: tap it on the beat (4 taps or more) to set the song's beat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local EdmConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EdmConfig"))
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
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

local function send(k: string, v: any)
	task.spawn(function()
		pcall(function() Music:InvokeServer("Edm", { k = k, v = v }) end)
	end)
end

local function readState(): {[string]: any}
	local raw = FashionGame:GetAttribute("ClubEdm")
	if typeof(raw) ~= "string" then return {} end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

export type Panel = { frame: Frame, place: (y: number, width: number, compact: boolean) -> number }

function EdmPanel.new(parent: Instance): Panel
	local frame = create("Frame", { Name = "EdmPanel", BackgroundTransparency = 1, Visible = false }, parent) :: Frame
	local title = create("TextLabel", {
		Name = "Title", BackgroundTransparency = 1, Text = "🎛 EDM 효과", TextColor3 = SUB, Font = Enum.Font.GothamBold,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)

	local buttons: {[string]: TextButton} = {}
	local function button(key: string, text: string): TextButton
		local b = create("TextButton", {
			Name = "Edm_" .. key, BackgroundColor3 = OFF, Text = text, TextColor3 = TEXT, TextScaled = true,
			Font = Enum.Font.GothamBold, AutoButtonColor = true,
		}, frame)
		corner(b, 8)
		create("UITextSizeConstraint", { MaxTextSize = 13 }, b)
		create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, b)
		buttons[key] = b
		return b
	end
	local order = { "kick", "pump", "drop", "flange", "echo", "tap" }
	button("kick", "🥁 킥")
	button("pump", "💓 펌핑")
	button("drop", "🚀 드롭")
	button("flange", "🌀 플랜저")
	button("echo", "🔁 에코")
	button("tap", "👆 박자")
	for _, key in ipairs({ "kick", "pump", "flange", "echo" }) do
		buttons[key].Activated:Connect(function()
			send(key, readState()[key] ~= true)
		end)
	end
	buttons.drop.Activated:Connect(function() send("drop", true) end)

	-- tap tempo: 4+ taps, each less than 2 s apart
	local taps: {number} = {}
	buttons.tap.Activated:Connect(function()
		local now = workspace:GetServerTimeNow()
		if #taps > 0 and now - taps[#taps] > 2 then table.clear(taps) end
		table.insert(taps, now)
		if #taps > 8 then table.remove(taps, 1) end
		if #taps >= 4 then
			local span = (taps[#taps] - taps[1]) / (#taps - 1)
			if span > 0 then send("tap", { bpm = 60 / span, phase = taps[#taps] }) end
		end
	end)

	-- sliders: the value is sent while dragging (a few times a second) and on release
	type Slider = { bar: Frame, fill: Frame, knob: Frame, label: TextLabel, dragging: boolean, value: number }
	local sliders: {[string]: Slider} = {}
	local function slider(key: string, text: string)
		local label = create("TextLabel", {
			Name = "Label_" .. key, BackgroundTransparency = 1, Text = text, TextColor3 = TEXT, Font = Enum.Font.GothamBold,
			TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		}, frame)
		create("UITextSizeConstraint", { MaxTextSize = 12 }, label)
		local bar = create("Frame", { Name = "Slider_" .. key, BackgroundColor3 = OFF, Active = true }, frame)
		corner(bar, 6)
		local fill = create("Frame", { Name = "Fill", BackgroundColor3 = ON, Size = UDim2.fromScale(0, 1) }, bar)
		corner(fill, 6)
		local knob = create("Frame", {
			Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = TEXT,
		}, bar)
		create("UIAspectRatioConstraint", {}, knob)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
		local s: Slider = { bar = bar, fill = fill, knob = knob, label = label, dragging = false, value = 0 }
		sliders[key] = s
		local lastSent = 0
		local function setFrom(x: number, final: boolean)
			local v = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			s.value = v
			fill.Size = UDim2.fromScale(v, 1)
			knob.Position = UDim2.fromScale(v, 0.5)
			if final or os.clock() - lastSent > 0.15 then
				lastSent = os.clock()
				send(key, v)
			end
		end
		bar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				s.dragging = true
				setFrom(input.Position.X, false)
				local moved, ended
				moved = UserInputService.InputChanged:Connect(function(change)
					if change.UserInputType == Enum.UserInputType.MouseMovement or change == input then
						setFrom(change.Position.X, false)
					end
				end)
				ended = UserInputService.InputEnded:Connect(function(done)
					if done == input or done.UserInputType == Enum.UserInputType.MouseButton1 then
						s.dragging = false
						setFrom(done.Position.X, true)
						moved:Disconnect()
						ended:Disconnect()
					end
				end)
			end
		end)
	end
	slider("filter", "🎚 필터")
	slider("bass", "🔊 베이스")

	local function refresh()
		local st = readState()
		for _, key in ipairs({ "kick", "pump", "flange", "echo" }) do
			buttons[key].BackgroundColor3 = if st[key] == true then ON else OFF
		end
		local now = workspace:GetServerTimeNow()
		local building = typeof(st.dropAt) == "number" and now < st.dropAt
		buttons.drop.BackgroundColor3 = if building then ON else OFF
		buttons.drop.Text = if building then string.format("🚀 %d", math.ceil(st.dropAt - now)) else "🚀 드롭"
		local bpm = st.bpm
		if typeof(bpm) ~= "number" then
			local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
			bpm = (track and EdmConfig.Bpm[track.soundId]) or EdmConfig.Default
		end
		buttons.tap.Text = string.format("👆 박자 %d", math.floor(bpm + 0.5))
		buttons.tap.BackgroundColor3 = if typeof(st.bpm) == "number" then ON else OFF
		for key, s in pairs(sliders) do
			if not s.dragging then
				local v = st[key]
				v = if typeof(v) == "number" then v elseif key == "filter" then 1 else 0
				s.value = v
				s.fill.Size = UDim2.fromScale(v, 1)
				s.knob.Position = UDim2.fromScale(v, 0.5)
			end
		end
	end
	FashionGame:GetAttributeChangedSignal("ClubEdm"):Connect(refresh)
	FashionGame:GetAttributeChangedSignal("ClubTrack"):Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if frame.Visible then refresh() end -- (the drop countdown)
		end
	end)
	refresh()

	-- lays itself out from y in its parent; returns the height used
	local function place(y: number, width: number, compact: boolean): number
		-- (phones: no title and lower rows, the window is only ~280 px tall)
		local h = if compact then 22 else 28
		local gap = if compact then 4 else 5
		local titleH = if compact then 0 else 16
		title.Visible = not compact
		frame.Position = UDim2.fromOffset(0, y)
		title.Position = UDim2.fromOffset(0, 0)
		title.Size = UDim2.fromOffset(width, titleH)
		local bw = (width - gap * 2) / 3
		for i, key in ipairs(order) do
			local row = math.floor((i - 1) / 3)
			local col = (i - 1) % 3
			local b = buttons[key]
			b.Position = UDim2.fromOffset(col * (bw + gap), titleH + 2 + row * (h + gap))
			b.Size = UDim2.fromOffset(bw, h)
		end
		local sy = titleH + 2 + 2 * (h + gap)
		local half = (width - gap) / 2
		local labelW = if compact then 52 else 64
		for i, key in ipairs({ "filter", "bass" }) do
			local s = sliders[key]
			local x = (i - 1) * (half + gap)
			s.label.Position = UDim2.fromOffset(x, sy)
			s.label.Size = UDim2.fromOffset(labelW, h)
			s.bar.Position = UDim2.fromOffset(x + labelW + 2, sy + h / 2 - 6)
			s.bar.Size = UDim2.fromOffset(half - labelW - 8, 12)
			s.knob.Size = UDim2.fromOffset(18, 18)
		end
		local total = sy + h
		frame.Size = UDim2.fromOffset(width, total)
		return total
	end

	return { frame = frame, place = place }
end

return EdmPanel

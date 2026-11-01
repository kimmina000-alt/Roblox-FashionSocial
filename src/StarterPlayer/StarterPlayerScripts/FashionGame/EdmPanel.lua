--!strict
-- The DJ's EDM controls in the turntable window (D-733; D-734 user: 박자 탭,
-- 플랜저, 필터, 베이스 out, a tempo slider by 킥, 배속 in). Shared/EdmConfig;
-- ClubMusicController places it, EdmController plays it for everyone:
--   [🥁 킥 ON]  ━━━━●━━ 124 BPM      (the kick's tempo)
--   [💓 펌핑] [🚀 드롭] [🔁 에코] [⏩ x1]
-- Each change goes to the server ("Edm" on the Music remote, DJ only; ⏩ is
-- the old "MusicSpeed" action, cycling EdmConfig.Speeds).

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

local function call(action: string, payload: any)
	task.spawn(function()
		pcall(function() Music:InvokeServer(action, payload) end)
	end)
end
local function send(k: string, v: any) call("Edm", { k = k, v = v }) end

local function readState(): {[string]: any}
	local raw = FashionGame:GetAttribute("ClubEdm")
	if typeof(raw) ~= "string" then return {} end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- the song's own tempo as heard (the kick slider's starting place)
local function songBpm(): number
	local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
	local speed = FashionGame:GetAttribute("ClubMusicSpeed")
	return ((track and EdmConfig.Bpm[track.soundId]) or EdmConfig.Default) * (if typeof(speed) == "number" then speed else 1)
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
	button("kick", "🥁 킥 OFF")
	local row2 = { "pump", "drop", "echo", "speed" }
	button("pump", "💓 펌핑")
	button("drop", "🚀 드롭")
	button("echo", "🔁 에코")
	button("speed", "⏩ x1")
	for _, key in ipairs({ "kick", "pump", "echo" }) do
		buttons[key].Activated:Connect(function() send(key, readState()[key] ~= true) end)
	end
	buttons.drop.Activated:Connect(function() send("drop", true) end) -- (again while it runs = off)
	buttons.speed.Activated:Connect(function()
		local now = FashionGame:GetAttribute("ClubMusicSpeed")
		local list = EdmConfig.Speeds
		local i = table.find(list, if typeof(now) == "number" then now else 1) or table.find(list, 1) or 1
		call("MusicSpeed", list[i % #list + 1])
	end)

	-- the kick's tempo: a slider MinBpm..MaxBpm, sent while dragging (a few
	-- times a second) and on release
	local bar = create("Frame", { Name = "KickTempo", BackgroundColor3 = OFF, Active = true }, frame)
	corner(bar, 6)
	local fill = create("Frame", { Name = "Fill", BackgroundColor3 = ON, Size = UDim2.fromScale(0, 1) }, bar)
	corner(fill, 6)
	local knob = create("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = TEXT }, bar)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	local bpmLabel = create("TextLabel", {
		Name = "Bpm", BackgroundTransparency = 1, Text = "", TextColor3 = TEXT, Font = Enum.Font.GothamBold,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
	}, frame)
	create("UITextSizeConstraint", { MaxTextSize = 12 }, bpmLabel)
	local span = EdmConfig.MaxBpm - EdmConfig.MinBpm
	local dragging = false
	local function show(bpm: number)
		local v = math.clamp((bpm - EdmConfig.MinBpm) / span, 0, 1)
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		bpmLabel.Text = string.format("%d BPM", math.floor(bpm + 0.5))
	end
	local lastSent = 0
	local function setFrom(x: number, final: boolean)
		local v = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local bpm = EdmConfig.MinBpm + v * span
		show(bpm)
		if final or os.clock() - lastSent > 0.15 then
			lastSent = os.clock()
			send("bpm", bpm)
		end
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging = true
		setFrom(input.Position.X, false)
		local moved, ended
		moved = UserInputService.InputChanged:Connect(function(change)
			if change.UserInputType == Enum.UserInputType.MouseMovement or change == input then setFrom(change.Position.X, false) end
		end)
		ended = UserInputService.InputEnded:Connect(function(done)
			if done == input or done.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
				setFrom(done.Position.X, true)
				moved:Disconnect()
				ended:Disconnect()
			end
		end)
	end)

	local function refresh()
		local st = readState()
		buttons.kick.Text = if st.kick == true then "🥁 킥 ON" else "🥁 킥 OFF"
		for _, key in ipairs({ "kick", "pump", "echo" }) do
			buttons[key].BackgroundColor3 = if st[key] == true then ON else OFF
		end
		local now = workspace:GetServerTimeNow()
		local running = typeof(st.dropAt) == "number"
		local building = running and now < st.dropAt
		buttons.drop.BackgroundColor3 = if running then ON else OFF
		buttons.drop.Text = if building then string.format("🚀 %d (끄기)", math.ceil(st.dropAt - now))
			elseif running then "🚀 드롭 끄기" else "🚀 드롭"
		local speed = FashionGame:GetAttribute("ClubMusicSpeed")
		speed = if typeof(speed) == "number" then speed else 1
		buttons.speed.Text = "⏩ x" .. tostring(speed)
		buttons.speed.BackgroundColor3 = if speed ~= 1 then ON else OFF
		if not dragging then show(if typeof(st.bpm) == "number" then st.bpm else songBpm()) end
	end
	FashionGame:GetAttributeChangedSignal("ClubEdm"):Connect(refresh)
	FashionGame:GetAttributeChangedSignal("ClubTrack"):Connect(refresh)
	FashionGame:GetAttributeChangedSignal("ClubMusicSpeed"):Connect(refresh)
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
		title.Size = UDim2.fromOffset(width, titleH)
		local y1 = titleH + (if compact then 0 else 2)
		local kickW = math.floor((width - gap * 3) / 4)
		buttons.kick.Position = UDim2.fromOffset(0, y1)
		buttons.kick.Size = UDim2.fromOffset(kickW, h)
		local labelW = if compact then 50 else 58
		bar.Position = UDim2.fromOffset(kickW + gap + 6, y1 + h / 2 - 6)
		bar.Size = UDim2.fromOffset(width - kickW - gap - labelW - 16, 12)
		knob.Size = UDim2.fromOffset(18, 18)
		bpmLabel.Position = UDim2.fromOffset(width - labelW, y1)
		bpmLabel.Size = UDim2.fromOffset(labelW, h)
		local y2 = y1 + h + gap
		for i, key in ipairs(row2) do
			buttons[key].Position = UDim2.fromOffset((i - 1) * (kickW + gap), y2)
			buttons[key].Size = UDim2.fromOffset(kickW, h)
		end
		local total = y2 + h
		frame.Size = UDim2.fromOffset(width, total)
		return total
	end

	return { frame = frame, place = place }
end

return EdmPanel

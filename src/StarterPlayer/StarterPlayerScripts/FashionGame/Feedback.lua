--!strict
-- 💬 의견 보내기 window (D-725, Shared/FeedbackConfig, server FeedbackService).
-- Built on the first require: the window, and the 💬 button in the top row
-- (FeedbackConfig.TopButton). Feedback.open() from the guide's question list
-- and the one-time ask (GuideTips). The game's owner (attribute
-- FeedbackAdmin) also gets a 📥 tab with what players sent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local FeedbackConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("FeedbackConfig"))
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Feedback") :: RemoteFunction
local Popups = require(script.Parent:WaitForChild("Popups"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))

local player = Players.LocalPlayer

local Feedback = {}

-- the guide window's colours (GuideController)
-- (D-1114, user 2026-11-09: "의견 보내기 ui도 블랙앤화이트") the guide's black and
-- white (D-1088): a near-black window with a white edge, white letters, dark
-- grey chips / boxes; white buttons carry dark letters (INK)
local PEACH = Color3.fromRGB(14, 14, 18) -- (the window)
local ORANGE = Color3.fromRGB(255, 255, 255) -- (edges, the picked chip, the main button)
local BROWN = Color3.fromRGB(240, 240, 245) -- (text)
local GREY = Color3.fromRGB(150, 150, 158)
local CHIP = Color3.fromRGB(30, 30, 36)
local EDGE = Color3.fromRGB(70, 70, 80)
local INK = Color3.fromRGB(14, 14, 18) -- (letters on white)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, r: number)
	create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end
local function button(parent: Instance, text: string, color: Color3, textColor: Color3): TextButton
	local b = create("TextButton", {
		BackgroundColor3 = color, Text = text, TextColor3 = textColor, Font = Enum.Font.GothamBold,
		TextSize = 15, AutoButtonColor = true,
	}, parent)
	corner(b, 12)
	return b
end

local gui = create("ScreenGui", { Name = "FashionFeedbackGui", ResetOnSpawn = false, DisplayOrder = 41, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

local window = create("Frame", {
	Name = "FeedbackWindow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54),
	Size = UDim2.new(1, -40, 1, -110), BackgroundColor3 = PEACH, Visible = false,
}, gui)
corner(window, 18)
create("UISizeConstraint", { MaxSize = Vector2.new(520, 400) }, window)
create("UIStroke", { Color = ORANGE, Thickness = 2 }, window)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -150, 0, 26), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 19, TextColor3 = BROWN, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "💬 의견 보내기",
}, window)
local closeButton = button(window, "X", CHIP, BROWN)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 10)
closeButton.Size = UDim2.fromOffset(34, 34)
corner(closeButton, 17)
local inboxButton = button(window, "📥 받은 의견", CHIP, BROWN)
inboxButton.AnchorPoint = Vector2.new(1, 0)
inboxButton.Position = UDim2.new(1, -52, 0, 12)
inboxButton.Size = UDim2.fromOffset(96, 30)
inboxButton.TextSize = 13
inboxButton.Visible = false

-- the form
local form = create("Frame", { Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -28, 1, -58), BackgroundTransparency = 1 }, window)
create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14,
	TextColor3 = GREY, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	-- (D-1013) the reward, said where people write
	Text = string.format("버그, 불편한 점, 바라는 것 무엇이든 적어 주세요. 좋은 의견은 확인 후 %d코인을 드려요! 🎁", FeedbackConfig.RewardCoins or 0),
}, form)
local chips = create("Frame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 }, form)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, chips)
local kind = FeedbackConfig.Kinds[2].key -- (개선 first: most of what we hope to hear)
local chipButtons: {[string]: TextButton} = {}
local function paintChips()
	for key, b in pairs(chipButtons) do
		b.BackgroundColor3 = if key == kind then ORANGE else CHIP
		b.TextColor3 = if key == kind then INK else BROWN
	end
end
for i, k in ipairs(FeedbackConfig.Kinds) do
	local b = button(chips, k.label, CHIP, BROWN)
	b.LayoutOrder = i
	b.Size = UDim2.new(1 / #FeedbackConfig.Kinds, -5, 1, 0)
	b.TextSize = 14
	chipButtons[k.key] = b
	b.Activated:Connect(function() kind = k.key paintChips() end)
end
paintChips()

local boxFrame = create("Frame", { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 1, -136), BackgroundColor3 = CHIP }, form)
corner(boxFrame, 12)
create("UIStroke", { Color = EDGE, Thickness = 1 }, boxFrame)
local box = create("TextBox", {
	Name = "FeedbackText", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 1, -16), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = BROWN, PlaceholderColor3 = GREY,
	PlaceholderText = "예) 카페 알바 주문이 너무 빨리 사라져요 / 클럽에 노래가 더 있었으면 좋겠어요",
	Text = "", ClearTextOnFocus = false, MultiLine = true, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, boxFrame)
local counter = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.5, 0, 0, 42), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true, Text = "",
}, form)
local sendButton = button(form, "보내기 ▶", ORANGE, INK)
sendButton.AnchorPoint = Vector2.new(1, 1)
sendButton.Position = UDim2.new(1, 0, 1, 0)
sendButton.Size = UDim2.new(0.38, 0, 0, 42)

local status = "" -- a message from the server, shown in the counter's place for a while
local function refreshCounter()
	local n = utf8.len(box.Text) or #box.Text
	counter.Text = if status ~= "" then status else string.format("%d / %d자", n, FeedbackConfig.MaxLength)
	counter.TextColor3 = if status ~= "" then ORANGE elseif n > FeedbackConfig.MaxLength then Color3.fromRGB(220, 60, 60) else GREY
end
box:GetPropertyChangedSignal("Text"):Connect(function()
	status = ""
	refreshCounter()
end)
refreshCounter()

-- (D-769, user) a sent message: the server's thanks on a card over the form for 1 s
local sentCard = create("TextLabel", {
	Name = "SentCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.86, 0, 0, 64), BackgroundColor3 = ORANGE, Font = Enum.Font.GothamBold, TextSize = 16,
	TextColor3 = INK, TextWrapped = true, Text = "", Visible = false, ZIndex = 5,
}, window)
corner(sentCard, 14)
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, sentCard)
local sentShown = 0
local function showSent(message: string)
	sentShown += 1
	local mine = sentShown
	sentCard.Text = message
	sentCard.Visible = true
	task.delay(1, function()
		if sentShown == mine then sentCard.Visible = false end
	end)
end

local sending = false
sendButton.Activated:Connect(function()
	if sending then return end
	sending = true
	sendButton.Text = "보내는 중…"
	task.spawn(function()
		local ok, sent, message = pcall(function() return remote:InvokeServer("Send", { kind = kind, text = box.Text }) end)
		sending = false
		sendButton.Text = "보내기 ▶"
		if ok and sent then
			player:SetAttribute("FeedbackSentThisVisit", true) -- (D-1031: no 20-minute ask after this)
			box.Text = ""
			showSent(if typeof(message) == "string" then message else "소중한 의견이 잘 접수되었어요.")
			return
		end
		status = if ok and typeof(message) == "string" then message else "지금은 보낼 수 없어요."
		refreshCounter()
	end)
end)

-- the owner's inbox
local inbox = create("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 1, -64), BackgroundTransparency = 1, Visible = false,
	BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ScrollBarImageColor3 = ORANGE,
}, window)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, inbox)

local KIND_LABEL: {[string]: string} = {}
for _, k in ipairs(FeedbackConfig.Kinds) do KIND_LABEL[k.key] = k.label end

local function fillInbox()
	for _, child in ipairs(inbox:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local ok, rows = pcall(function() return remote:InvokeServer("List") end)
	if not ok or typeof(rows) ~= "table" or #rows == 0 then
		create("TextLabel", {
			Size = UDim2.new(1, -6, 0, 40), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 15,
			TextColor3 = GREY, Text = if ok then "아직 받은 의견이 없어요." else "불러오지 못했어요.",
		}, inbox)
		return
	end
	for i, row in ipairs(rows) do
		local card = create("Frame", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CHIP }, inbox)
		corner(card, 10)
		create("UIStroke", { Color = EDGE, Thickness = 1 }, card)
		create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, card)
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, card)
		local when = if typeof(row.at) == "number" then os.date("%m/%d %H:%M", row.at) else ""
		local where = if typeof(row.x) == "number" then string.format(" · (%d, %d)", row.x, row.z or 0) else ""
		local head = create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 }, card)
		create("TextLabel", {
			Size = UDim2.new(1, -130, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = ORANGE, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Text = string.format("%s · %s · %s%s", KIND_LABEL[row.k] or "", tostring(row.n), when, where),
		}, head)
		create("TextLabel", {
			LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = BROWN, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(row.t),
		}, card)
		-- handled: off the list for good
		local doneButton = button(head, "✔ 처리", CHIP, BROWN)
		doneButton.AnchorPoint = Vector2.new(1, 0)
		doneButton.Position = UDim2.fromScale(1, 0)
		doneButton.Size = UDim2.fromOffset(60, 22)
		doneButton.TextSize = 12
		doneButton.Activated:Connect(function()
			task.spawn(function()
				pcall(function() remote:InvokeServer("Done", row.key) end)
				card:Destroy()
			end)
		end)
		-- (D-1013) 🎁 the sender's coins, once per message
		local given = row.r == true
		local giftButton = button(head, if given then "지급됨" else string.format("🎁 %d", FeedbackConfig.RewardCoins or 0),
			if given then CHIP else ORANGE, if given then GREY else INK)
		giftButton.AnchorPoint = Vector2.new(1, 0)
		giftButton.Position = UDim2.new(1, -64, 0, 0)
		giftButton.Size = UDim2.fromOffset(60, 22)
		giftButton.TextSize = 12
		local busy = false
		giftButton.Activated:Connect(function()
			if given or busy then return end
			busy = true
			giftButton.Text = "…"
			task.spawn(function()
				local ok, sent, message = pcall(function() return remote:InvokeServer("Reward", row.key) end)
				busy = false
				if ok and sent then
					given = true
					giftButton.Text = "지급됨"
					giftButton.BackgroundColor3 = CHIP
					giftButton.TextColor3 = GREY
				else
					giftButton.Text = string.format("🎁 %d", FeedbackConfig.RewardCoins or 0)
				end
				if ok and typeof(message) == "string" then showSent(message) end
			end)
		end)
	end
end

local function showForm()
	inbox.Visible = false
	form.Visible = true
	title.Text = "💬 의견 보내기"
	inboxButton.Text = "📥 받은 의견"
end
local function showInbox()
	form.Visible = false
	inbox.Visible = true
	title.Text = "📥 받은 의견"
	inboxButton.Text = "✏️ 쓰기"
	task.spawn(fillInbox)
end
inboxButton.Activated:Connect(function()
	if inbox.Visible then showForm() else showInbox() end
end)

local function close()
	window.Visible = false
	Popups.closed("Feedback")
end
closeButton.Activated:Connect(close)

function Feedback.open()
	inboxButton.Visible = player:GetAttribute("FeedbackAdmin") == true
	showForm()
	window.Visible = true
	Popups.opened("Feedback", close)
end

-- the 💬 button in the top row: a white speech bubble, drawn
if FeedbackConfig.TopButton then
	local topButton = create("TextButton", {
		Name = "FeedbackButton", Text = "", AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(18, 18, 21), BackgroundTransparency = 0.5,
	}, gui)
	local bubble = create("Frame", {
		Name = "Bubble", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.52, 0.4), BackgroundTransparency = 1,
	}, topButton)
	corner(bubble, 5)
	create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, bubble)
	create("Frame", { -- the tail
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.3, 0, 1, 2), Size = UDim2.fromOffset(5, 5),
		Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, bubble)
	for i = -1, 1 do
		local dot = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, i * 5, 0.5, 0), Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		}, bubble)
		corner(dot, 2)
	end
	TopBar.add(topButton, 2)
	topButton.Activated:Connect(function()
		if window.Visible then close() else Feedback.open() end
	end)
end

-- (D-1031, user 2026-11-09: "20분 지나면 의견 묻는 창 다시 띄워" / "처음 접속했을
-- 때 한 번만 띄우고 안 보내도 다음 접속 때 또 띄우지 마") after
-- FeedbackConfig.NudgeMinutes of a visit the window opens by itself ONCE per
-- player, ever: saved as the tip "feedbackAsk" (GuideService wallet.tips, player
-- attribute TipsSeen; the old D-725 tip used the same key, so players who saw
-- that one are not asked again). Sending anything also counts. It waits while
-- another window is open.
local ASK_KEY = "feedbackAsk"
local guideRemote = FashionGame:WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction
local function asked(): boolean
	local raw = player:GetAttribute("TipsSeen")
	if typeof(raw) ~= "string" then return false end
	local ok, keys = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
	return ok and typeof(keys) == "table" and table.find(keys, ASK_KEY) ~= nil
end
local function markAsked()
	task.spawn(function() pcall(function() guideRemote:InvokeServer("TipSeen", ASK_KEY) end) end)
end
player:GetAttributeChangedSignal("FeedbackSentThisVisit"):Connect(function()
	if not asked() then markAsked() end
end)

-- (user: "그냥 끄기 누르면 오른쪽 상단에 있는 버튼 아래 텍스트 안내 문구 띄워 짧게
-- 활동은 막지 말고") closing the asked window without sending: a short line
-- under the 💬 button for a few seconds; it takes no taps or clicks
local function hintUnderButton()
	local topButton = TopBar.button and TopBar.button(2)
	local holder = topButton and topButton:FindFirstAncestorOfClass("ScreenGui")
	if not topButton or not holder then return end
	local at = topButton.AbsolutePosition - holder.AbsolutePosition
	local hint = create("TextLabel", {
		Name = "FeedbackHint", AnchorPoint = Vector2.new(1, 0), Active = false, Interactable = false,
		Position = UDim2.fromOffset(at.X + topButton.AbsoluteSize.X, at.Y + topButton.AbsoluteSize.Y + 6),
		Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(18, 18, 21), BackgroundTransparency = 0.25,
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
		Text = "의견은 언제든 💬 버튼으로 보낼 수 있어요", ZIndex = 50,
	}, holder)
	corner(hint, 13)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, hint)
	task.delay(3.5, function() hint:Destroy() end)
end

if (FeedbackConfig.NudgeMinutes or 0) > 0 then
	task.delay(FeedbackConfig.NudgeMinutes * 60, function()
		while Popups.anyOpen() do task.wait(5) end
		if asked() or player:GetAttribute("FeedbackSentThisVisit") or window.Visible then return end
		markAsked()
		Feedback.open()
		-- closed without sending → the hint
		local sentBefore = player:GetAttribute("FeedbackSentThisVisit") == true
		window:GetPropertyChangedSignal("Visible"):Once(function()
			if not window.Visible and not (player:GetAttribute("FeedbackSentThisVisit") == true and not sentBefore) then
				hintUnderButton()
			end
		end)
	end)
end

return Feedback

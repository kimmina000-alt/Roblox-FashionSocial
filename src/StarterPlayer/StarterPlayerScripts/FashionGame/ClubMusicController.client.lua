--!strict
-- Club music panel (client): 🎵 button next to 💃.
--   * No DJ: anyone can request one song at a time (queue, server-checked).
--   * DJ: 지금 틀기 / 다음 곡 / 건너뛰기, remaining time, and the DJ console
--     placeholders for future abilities (DJ_SYSTEM.md).
--   * "DJ 되기" opens the Roblox purchase window (DJ time, D-052).
-- State comes from ReplicatedStorage.FashionGame attributes set by the server
-- (ClubTrack, ClubTrackBy, ClubRequests, ClubDJ, ClubDJUntil, ClubDJQueue).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local Music = Remotes:WaitForChild("Music") :: RemoteFunction
local ClubShop = Remotes:WaitForChild("ClubShop") :: RemoteFunction

local COLORS = {
	panel = Color3.fromRGB(18, 18, 24),
	card = Color3.fromRGB(38, 38, 50),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(190, 190, 205),
	accent = Color3.fromRGB(255, 80, 200),
	dj = Color3.fromRGB(80, 200, 255),
	robux = Color3.fromRGB(0, 176, 111),
}

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if parent then instance.Parent = parent end
	return instance
end
local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local gui = create("ScreenGui", {
	Name = "FashionMusicGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 19,
}, playerGui)

local musicButton = create("TextButton", {
	Name = "MusicButton",
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.2,
	Text = "🎵",
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.text,
}, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, musicButton)

-- Left of the 💃 button (which sits left of the catalog C button).
local function positionButton()
	local inset = GuiService.TopbarInset
	local centerY, rightX, size = 34, -16, 44
	if inset.Height > 0 then
		centerY = inset.Min.Y + inset.Height / 2
		size = math.clamp(inset.Height - 12, 32, 44)
		local camera = workspace.CurrentCamera
		if camera and inset.Width > 0 then
			rightX = -(camera.ViewportSize.X - inset.Max.X) - 8
		end
	end
	musicButton.Size = UDim2.fromOffset(size, size)
	musicButton.Position = UDim2.new(1, rightX - 2 * (size + 8), 0, centerY)
end
positionButton()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(positionButton)

local panel = create("Frame", {
	Name = "MusicPanel",
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	Visible = false,
}, gui)
corner(panel, 15)
create("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, panel)

create("TextLabel", {
	Name = "Header",
	Size = UDim2.new(1, -40, 0, 26),
	BackgroundTransparency = 1,
	Text = "음악",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.text,
	TextSize = 22,
	Font = Enum.Font.GothamBold,
}, panel)
local closeButton = create("TextButton", {
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = COLORS.card,
	Text = "X",
	TextColor3 = COLORS.text,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
}, panel)
corner(closeButton, 14)

local nowLabel = create("TextLabel", {
	Name = "NowLabel",
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = COLORS.text,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
}, panel)

-- DJ status row
local djRow = create("Frame", {
	Name = "DJRow",
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = COLORS.card,
}, panel)
corner(djRow, 10)
local djLabel = create("TextLabel", {
	Name = "DJLabel",
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.new(1, -120, 1, 0),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	TextColor3 = COLORS.dj,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, djRow)
local djButton = create("TextButton", {
	Name = "BecomeDJ",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.fromOffset(104, 30),
	BackgroundColor3 = COLORS.robux,
	Text = string.format("DJ %d분 · R$%d", MonetizationConfig.DJMinutes, MonetizationConfig.Products.DJ.price),
	TextColor3 = COLORS.text,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
}, djRow)
corner(djButton, 15)

-- DJ tools (only for the DJ)
local djTools = create("Frame", {
	Name = "DJTools",
	Position = UDim2.fromOffset(0, 104),
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Visible = false,
}, panel)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, djTools)
local djToolCount = 0
local function djToolButton(name: string, text: string, enabled: boolean): TextButton
	djToolCount += 1
	local button = create("TextButton", {
		Name = name,
		LayoutOrder = djToolCount,
		Size = UDim2.fromOffset(78, 30),
		BackgroundColor3 = if enabled then COLORS.dj else COLORS.card,
		Text = text,
		TextColor3 = if enabled then COLORS.text else COLORS.sub,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = enabled,
	}, djTools)
	corner(button, 8)
	return button
end
local skipButton = djToolButton("Skip", "⏭ 건너뛰기", true)
-- Future DJ console (DJ_SYSTEM.md §4): shown so the DJ sees what is coming.
djToolButton("Lights", "조명 (준비 중)", false)
djToolButton("Effects", "효과 (준비 중)", false)

local listTitle = create("TextLabel", {
	Name = "ListTitle",
	Position = UDim2.fromOffset(0, 104),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COLORS.sub,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
}, panel)
local trackList = create("ScrollingFrame", {
	Name = "Tracks",
	Position = UDim2.fromOffset(0, 128),
	Size = UDim2.new(1, 0, 1, -128 - 74),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, trackList)
local queueLabel = create("TextLabel", {
	Name = "QueueLabel",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 70),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	TextColor3 = COLORS.sub,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
}, panel)

local toastLabel = create("TextLabel", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -160),
	Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.25,
	TextColor3 = COLORS.text,
	TextSize = 16,
	TextWrapped = true,
	Font = Enum.Font.GothamBold,
	Visible = false,
}, gui)
corner(toastLabel, 12)
local toastToken = 0
local function toast(message: any)
	if typeof(message) ~= "string" or message == "" then return end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(3, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

local function layout()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local top = math.max(GuiService.TopbarInset.Max.Y, 36) + 8
	local width = math.clamp(math.floor(viewport.X * 0.3), 270, 340)
	local height = math.clamp(viewport.Y - top - 24, 300, 560)
	panel.Position = UDim2.new(1, -width - 12, 0, top)
	panel.Size = UDim2.fromOffset(width, height)
end
layout()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

--------------------------------------------------
-- State → UI
--------------------------------------------------

local function nameOf(userId: any): string
	if typeof(userId) ~= "number" or userId == 0 then return "" end
	local other = Players:GetPlayerByUserId(userId)
	return if other then other.DisplayName else "?"
end

local function isDJ(): boolean
	local untilTime = FashionGame:GetAttribute("ClubDJUntil")
	return FashionGame:GetAttribute("ClubDJ") == player.UserId
		and typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

local function requests(): {{i: number, u: number}}
	local raw = FashionGame:GetAttribute("ClubRequests")
	if typeof(raw) ~= "string" then return {} end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

local function call(action: string, payload: any)
	local ok, result, message = pcall(function()
		return Music:InvokeServer(action, payload)
	end)
	if not ok then
		toast("잠시 후 다시 시도하세요.")
	elseif typeof(message) == "string" then
		toast(message)
	end
	return ok and result
end

local function renderTracks()
	for _, child in ipairs(trackList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local dj = isDJ()
	local otherDJ = (FashionGame:GetAttribute("ClubDJ") or 0) ~= 0 and not dj
	local current = FashionGame:GetAttribute("ClubTrack")
	for index, track in ipairs(ClubConfig.Playlist) do
		local row = create("Frame", {
			Name = "Track_" .. index,
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 40),
			BackgroundColor3 = if index == current then COLORS.accent else COLORS.card,
		}, trackList)
		corner(row, 8)
		create("TextLabel", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, if dj then -150 else -86, 1, 0),
			BackgroundTransparency = 1,
			Text = track.title .. "  ·  " .. track.channel,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = COLORS.text,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
		}, row)
		local function rowButton(name: string, text: string, x: number, color: Color3, onClick: () -> ())
			local button = create("TextButton", {
				Name = name,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, x, 0.5, 0),
				Size = UDim2.fromOffset(64, 28),
				BackgroundColor3 = color,
				Text = text,
				TextColor3 = COLORS.text,
				TextSize = 13,
				Font = Enum.Font.GothamBold,
			}, row)
			corner(button, 14)
			button.MouseButton1Click:Connect(onClick)
		end
		if dj then
			rowButton("Play", "지금", -72, COLORS.dj, function() call("Play", index) end)
			rowButton("Queue", "다음", -4, COLORS.card, function() call("Queue", index) end)
		elseif not otherDJ then
			rowButton("Request", "신청", -4, COLORS.accent, function() call("Request", index) end)
		end
	end
end

local function refresh()
	local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
	local by = nameOf(FashionGame:GetAttribute("ClubTrackBy"))
	nowLabel.Text = if track
		then "♪ " .. track.title .. (if by ~= "" then "  ·  " .. by .. "님 선곡" else "")
		else "♪ -"
	local djId = FashionGame:GetAttribute("ClubDJ") or 0
	local untilTime = FashionGame:GetAttribute("ClubDJUntil") or 0
	local waiting = FashionGame:GetAttribute("ClubDJQueue") or 0
	local dj = isDJ()
	if dj then
		local left = math.max(0, untilTime - workspace:GetServerTimeNow())
		djLabel.Text = string.format("🎧 내가 DJ! 남은 시간 %d:%02d", math.floor(left / 60), math.floor(left % 60))
		djButton.Text = "시간 연장"
	elseif djId ~= 0 then
		local left = math.max(0, untilTime - workspace:GetServerTimeNow())
		djLabel.Text = string.format("🎧 DJ %s · %d분 남음 · 대기 %d명", nameOf(djId), math.ceil(left / 60), waiting)
		djButton.Text = "DJ 대기 구매"
	else
		djLabel.Text = "DJ 없음 · 누구나 한 곡씩 신청"
		djButton.Text = string.format("DJ %d분 · R$%d", MonetizationConfig.DJMinutes, MonetizationConfig.Products.DJ.price)
	end
	djTools.Visible = dj
	listTitle.Position = UDim2.fromOffset(0, if dj then 140 else 104)
	trackList.Position = UDim2.fromOffset(0, if dj then 164 else 128)
	trackList.Size = UDim2.new(1, 0, 1, (if dj then -164 else -128) - 74)
	listTitle.Text = if dj then "곡 고르기 (지금 / 다음)" elseif djId ~= 0 then "DJ가 곡을 고르는 중" else "곡 신청 (한 번에 한 곡)"
	local lines = {}
	for position, entry in ipairs(requests()) do
		local queued = ClubConfig.Playlist[entry.i]
		if queued and position <= 4 then
			table.insert(lines, string.format("%d. %s · %s", position, queued.title, nameOf(entry.u)))
		end
	end
	queueLabel.Text = if #lines > 0 then "다음 곡\n" .. table.concat(lines, "\n") else "다음 곡: 자동 재생"
end

local function refreshAll()
	refresh()
	if panel.Visible then renderTracks() end
end

for _, name in ipairs({ "ClubTrack", "ClubTrackBy", "ClubRequests", "ClubDJ", "ClubDJUntil", "ClubDJQueue" }) do
	FashionGame:GetAttributeChangedSignal(name):Connect(refreshAll)
end

musicButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	musicButton.BackgroundColor3 = if panel.Visible then COLORS.accent else Color3.fromRGB(0, 0, 0)
	if panel.Visible then
		layout()
		refreshAll()
	end
end)
closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
	musicButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
end)
skipButton.MouseButton1Click:Connect(function() call("Skip", nil) end)
djButton.MouseButton1Click:Connect(function()
	local product = MonetizationConfig.Products.DJ
	if product.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif RunService:IsStudio() then
		local ok, message = ClubShop:InvokeServer("StudioTestBuy", { kind = "product", key = "DJ" })
		if not ok then toast(message) end
	else
		toast("준비 중인 상품입니다.")
	end
end)

-- Countdown text while the panel is open.
task.spawn(function()
	while true do
		task.wait(1)
		if panel.Visible then refresh() end
	end
end)
refresh()

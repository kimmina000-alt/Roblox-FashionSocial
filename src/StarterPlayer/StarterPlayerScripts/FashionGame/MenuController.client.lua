--!strict
-- (D-1377, user 2026-11-13: "메뉴 버튼 안에 닉네임 숨기기 칭호 숨기기 기부하기 버튼 넣기")
-- The ☰ button's menu (TopBar order 20, TopBar.OpenChanged): a small dark card under it with
--   닉네임 표시    (D-1380) everyone's name tags on this screen only, on by default (HideName
--                  = off): "내 화면에서만 모두의 닉네임을 끄고 켜는 기능"
--   내 칭호 표시   (D-1378) a switch for each of my badges: FOUNDING MEMBER / 알바생 / GUARD /
--                  VIP / DJ (HideBadge_<role> = off)
--   Switches show what is shown (D-1380, user: on by default = pink, off = grey).
--   🙈 UI 숨기기   (D-1594) hides the whole UI on this screen; 👁 brings it back (HideUi)
--   💝 기부하기    the supporter window (UiBus.OpenSupport → BannerController)
-- The switches are saved on the server (ClubShop "HideName" / "HideBadge",
-- PlayerPrefsService) and show the player attributes, so they come back on the next visit.
-- A tap outside the card, ☰ again or any window opening closes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubShop") :: RemoteFunction
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))

local PINK = Color3.fromRGB(255, 110, 170)
local OFF = Color3.fromRGB(70, 70, 82)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end

local gui = create("ScreenGui", { Name = "FashionMenuGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 31, Enabled = false }, playerGui)
-- a tap anywhere else closes the menu (the ☰ button itself sits above this, DisplayOrder 30 vs 31:
-- it is left out by the gap around it)
local catcher = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, gui)
catcher.Activated:Connect(function() TopBar.setOpen(false) end)

-- (D-1720, user 2026-11-18: "메뉴 길어서 아래 안 보이는 곳 드래그해서 올릴 수 있도록 수정") the window (panel) is as
-- high as its rows but never past the screen's bottom; the rows sit in a ScrollingFrame (card) inside it,
-- so on a short phone screen a drag brings the lower rows up
local panel = create("Frame", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(210, 0), BackgroundColor3 = Color3.fromRGB(18, 18, 22), BackgroundTransparency = 0.05, ClipsDescendants = true }, gui)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
create("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.75, Thickness = 1 }, panel)
local card = create("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.new(1, 1, 1), ScrollBarImageTransparency = 0.5,
}, panel)
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, card)
local listLayout = create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, card)

local function row(order: number, height: number?): TextButton
	local b = create("TextButton", { Size = UDim2.new(1, 0, 0, height or 42), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = order }, card)
	return b
end

-- a switch row: label left, a pill switch right; send(want) tells the server
-- (D-1380) a switch is pink while the thing is SHOWN (the attribute says hidden)
local function switchRow(order: number, label: string, attribute: string, send: (boolean) -> (), small: boolean?)
	local b = row(order, if small then 34 else 42)
	create("TextLabel", {
		Position = UDim2.fromOffset(if small then 12 else 0, 0), Size = UDim2.new(1, if small then -66 else -54, 1, 0),
		BackgroundTransparency = 1, Text = label, Font = if small then Enum.Font.GothamMedium else Enum.Font.GothamBold,
		TextSize = if small then 13 else 15, TextColor3 = if small then Color3.fromRGB(215, 215, 225) else Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	local track = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(44, 24), BackgroundColor3 = OFF }, b)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local knob = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.new(1, 1, 1) }, track)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	local function paint()
		local on = player:GetAttribute(attribute) ~= true
		track.BackgroundColor3 = if on then PINK else OFF
		knob.Position = if on then UDim2.new(1, -21, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
	end
	paint()
	player:GetAttributeChangedSignal(attribute):Connect(paint)
	local busy = false
	b.Activated:Connect(function()
		if busy then return end
		busy = true
		local hide = player:GetAttribute(attribute) ~= true
		-- (shown at once; the server's attribute confirms it)
		track.BackgroundColor3 = if hide then OFF else PINK
		knob.Position = if hide then UDim2.new(0, 3, 0.5, 0) else UDim2.new(1, -21, 0.5, 0)
		pcall(send, hide)
		busy = false
		paint()
	end)
end

switchRow(1, "닉네임 표시", "HideName", function(hide) remote:InvokeServer("HideName", hide) end)
-- (D-1378) 내 칭호 표시: one switch per badge
create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "내 칭호 표시", Font = Enum.Font.GothamBold, TextSize = 15,
	TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2,
}, card)
-- (D-1874) + WINTER 2026 (the winter attendance event's title)
for i, badge in ipairs({ { "Founding", "FOUNDING MEMBER" }, { "Staff", "알바생" }, { "GUARD", "GUARD" }, { "VIP", "VIP" }, { "DJ", "DJ" } }) do
	switchRow(2 + i, badge[2], "HideBadge_" .. badge[1], function(hide)
		remote:InvokeServer("HideBadge", { role = badge[1], on = hide })
	end, true)
end
-- (D-1709, user 2026-11-18: "환호성 끄기 버튼 추가") 놀이기구 환호성: the vikings' / jumping star's cheer
-- (RideWindController) on this screen; pink = heard (attribute MuteCheer = off), saved like the others
-- (D-1729: the park's firework bangs too, so the row says so)
switchRow(20, "🎢 환호성 · 폭죽 소리", "MuteCheer", function(mute) remote:InvokeServer("MuteCheer", mute) end)
-- (D-1985, user 2026-11-22: "켜기/끄기 버튼도 넣어") 📳 진동: the buzz on 오늘의 곡 도전 hits; pink = on (NoVibrate = off)
switchRow(19, "📳 진동", "NoVibrate", function(off) remote:InvokeServer("NoVibrate", off) end)
-- (D-1594, user 2026-11-17: "ui 숨기기 버튼 추가") 🙈 UI 숨기기: everything on the screen goes (HideUi), a 👁
-- button at the top right brings it back
do
	local HideUi = require(script.Parent:WaitForChild("HideUi"))
	local b = row(21)
	create("TextLabel", {
		-- (D-1721, user 2026-11-18: "UI 숨기기 앞에 원숭이 말고 눈 이모지로 수정") 🙈 → 👁
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "👁 UI 숨기기", Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	b.Activated:Connect(function()
		TopBar.setOpen(false)
		task.defer(HideUi.hide)
	end)
end
do
	local b = row(22)
	create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "💝 기부하기", Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 190, 215), TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	b.Activated:Connect(function()
		TopBar.setOpen(false)
		UiBus.OpenSupport:Fire()
	end)
end
-- (D-1878) 🎅 미니 산타 앨범: the Santa hunt's album (shown once the hunt has started; kept after it)
do
	local SantaHuntConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("SantaHuntConfig"))
	local b = row(23)
	create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "🎅 미니 산타 앨범", Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 200, 200), TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	b.Visible = SantaHuntConfig.started()
	task.spawn(function()
		while not b.Visible do
			task.wait(30)
			b.Visible = SantaHuntConfig.started()
		end
	end)
	b.Activated:Connect(function()
		TopBar.setOpen(false)
		UiBus.OpenSantaAlbum:Fire()
	end)
end

local function place()
	local button = TopBar.menuButton()
	-- (AbsolutePosition leaves out the top bar inset: add it, D-1138)
	local inset = GuiService:GetGuiInset()
	local camera = workspace.CurrentCamera
	local vpX = if camera then camera.ViewportSize.X else 1000
	local right = button.AbsolutePosition.X + button.AbsoluteSize.X
	local top = button.AbsolutePosition.Y + inset.Y + button.AbsoluteSize.Y + 8
	panel.Position = UDim2.new(0, math.min(right, vpX - 8), 0, top)
	-- (D-1720) all the rows, or down to 10 px over the screen's bottom (the rest scrolls)
	local vpY = if camera then camera.ViewportSize.Y else 700
	local content = listLayout.AbsoluteContentSize.Y + 16
	panel.Size = UDim2.fromOffset(210, math.max(80, math.min(content, vpY - top - 10)))
end
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	if gui.Enabled then place() end
end)

-- (D-1380) 닉네임 표시 off: every name tag (OHUNameTag, NameTagService) is off on this screen
-- only; tags made later (spawns, a new Head) follow
local function applyNames()
	local show = player:GetAttribute("HideName") ~= true
	for _, other in ipairs(Players:GetPlayers()) do
		local head = other.Character and other.Character:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("OHUNameTag")
		if tag and tag:IsA("BillboardGui") then tag.Enabled = show end
	end
end
player:GetAttributeChangedSignal("HideName"):Connect(applyNames)
local function watchCharacter(character: Model)
	character.DescendantAdded:Connect(function(d)
		if d.Name == "OHUNameTag" and d:IsA("BillboardGui") and player:GetAttribute("HideName") == true then
			d.Enabled = false
		end
	end)
end
local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then watchCharacter(other.Character) end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
applyNames()

TopBar.OpenChanged:Connect(function(on: boolean)
	if on then
		card.CanvasPosition = Vector2.zero
		place()
	end
	gui.Enabled = on
end)

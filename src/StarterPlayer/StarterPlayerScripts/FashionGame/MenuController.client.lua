--!strict
-- (D-1377, user 2026-11-13: "메뉴 버튼 안에 닉네임 숨기기 칭호 숨기기 기부하기 버튼 넣기")
-- The ☰ button's menu (TopBar order 20, TopBar.OpenChanged): a small dark card under it with
--   닉네임 표시    (D-1380) everyone's name tags on this screen only, on by default (HideName
--                  = off): "내 화면에서만 모두의 닉네임을 끄고 켜는 기능"
--   내 칭호 표시   (D-1378) a switch for each of my badges: FOUNDING MEMBER / 알바생 / GUARD /
--                  VIP / DJ (HideBadge_<role> = off)
--   Switches show what is shown (D-1380, user: on by default = pink, off = grey).
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

local card = create("Frame", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(210, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(18, 18, 22), BackgroundTransparency = 0.05 }, gui)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
create("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.75, Thickness = 1 }, card)
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, card)
create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, card)

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
for i, badge in ipairs({ { "Founding", "FOUNDING MEMBER" }, { "Staff", "알바생" }, { "GUARD", "GUARD" }, { "VIP", "VIP" }, { "DJ", "DJ" } }) do
	switchRow(2 + i, badge[2], "HideBadge_" .. badge[1], function(hide)
		remote:InvokeServer("HideBadge", { role = badge[1], on = hide })
	end, true)
end
do
	local b = row(10)
	create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "💝 기부하기", Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 190, 215), TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	b.Activated:Connect(function()
		TopBar.setOpen(false)
		UiBus.OpenSupport:Fire()
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
	card.Position = UDim2.new(0, math.min(right, vpX - 8), 0, top)
end

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
	if on then place() end
	gui.Enabled = on
end)

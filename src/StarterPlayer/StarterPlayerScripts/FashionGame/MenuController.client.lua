--!strict
-- (D-1377, user 2026-11-13: "메뉴 버튼 안에 닉네임 숨기기 칭호 숨기기 기부하기 버튼 넣기")
-- The ☰ button's menu (TopBar order 20, TopBar.OpenChanged): a small dark card under it with
--   닉네임 숨기기  switch: the name tag over the head off for everyone (HideName)
--   칭호 숨기기    switch: the FOUNDING MEMBER title badge off (HideTitle)
--   💝 기부하기    the supporter window (UiBus.OpenSupport → BannerController)
-- The switches are saved on the server (ClubShop "HideName" / "HideTitle",
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

local card = create("Frame", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(200, 152), BackgroundColor3 = Color3.fromRGB(18, 18, 22), BackgroundTransparency = 0.05 }, gui)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
create("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.75, Thickness = 1 }, card)
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, card)
create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, card)

local function row(order: number): TextButton
	local b = create("TextButton", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = order }, card)
	return b
end

-- a switch row: label left, a pill switch right
local function switchRow(order: number, label: string, attribute: string)
	local b = row(order)
	create("TextLabel", {
		Size = UDim2.new(1, -54, 1, 0), BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
	}, b)
	local track = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(44, 24), BackgroundColor3 = OFF }, b)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local knob = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.new(1, 1, 1) }, track)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	local function paint()
		local on = player:GetAttribute(attribute) == true
		track.BackgroundColor3 = if on then PINK else OFF
		knob.Position = if on then UDim2.new(1, -21, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
	end
	paint()
	player:GetAttributeChangedSignal(attribute):Connect(paint)
	local busy = false
	b.Activated:Connect(function()
		if busy then return end
		busy = true
		local want = player:GetAttribute(attribute) ~= true
		-- (shown at once; the server's attribute confirms it)
		track.BackgroundColor3 = if want then PINK else OFF
		knob.Position = if want then UDim2.new(1, -21, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
		pcall(function() remote:InvokeServer(attribute, want) end)
		busy = false
		paint()
	end)
end

switchRow(1, "닉네임 숨기기", "HideName")
switchRow(2, "칭호 숨기기", "HideTitle")
do
	local b = row(3)
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

TopBar.OpenChanged:Connect(function(on: boolean)
	if on then place() end
	gui.Enabled = on
end)

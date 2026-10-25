--!strict
-- A small window that asks for a short message (max 30 characters) before a
-- purchase whose banner shows it to everyone (stage cold spark, supporter
-- gifts). The server filters the text; it is never shown unfiltered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Popups = require(script.Parent:WaitForChild("Popups"))
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local ClubShop = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubShop") :: RemoteFunction

local MessagePrompt = {}

local MAX = 30
local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local frame: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local box: TextBox? = nil
local okButton: TextButton? = nil
local onDone: ((string?) -> ())? = nil

local function build()
	if gui then return end
	local g = Instance.new("ScreenGui")
	g.Name = "FashionMessagePrompt"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 40
	g.Parent = player:WaitForChild("PlayerGui")
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(340, 196)
	f.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	f.Visible = false
	f.Parent = g
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 16)
	local t = Instance.new("TextLabel")
	t.Position = UDim2.fromOffset(16, 10)
	t.Size = UDim2.new(1, -32, 0, 28)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = f
	Instance.new("UITextSizeConstraint", t).MaxTextSize = 20
	local b = Instance.new("TextLabel")
	b.Position = UDim2.fromOffset(16, 40)
	b.Size = UDim2.new(1, -32, 0, 36)
	b.BackgroundTransparency = 1
	b.TextColor3 = Color3.fromRGB(190, 190, 205)
	b.TextSize = 14
	b.TextWrapped = true
	b.Font = Enum.Font.GothamMedium
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextYAlignment = Enum.TextYAlignment.Top
	b.Parent = f
	local tb = Instance.new("TextBox")
	tb.Name = "Message"
	tb.Position = UDim2.fromOffset(16, 82)
	tb.Size = UDim2.new(1, -32, 0, 40)
	tb.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
	tb.TextColor3 = Color3.new(1, 1, 1)
	tb.PlaceholderText = "한마디 (30자, 비워도 돼요)"
	tb.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
	tb.ClearTextOnFocus = false
	tb.TextSize = 16
	tb.Font = Enum.Font.GothamMedium
	tb.Text = ""
	tb.Parent = f
	Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 10)
	tb:GetPropertyChangedSignal("Text"):Connect(function()
		local text = tb.Text
		local length = utf8.len(text)
		if length and length > MAX then
			tb.Text = string.sub(text, 1, (utf8.offset(text, MAX + 1) :: number) - 1)
		end
	end)
	local function button(name: string, text: string, color: Color3, x: number): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.AnchorPoint = Vector2.new(0, 1)
		btn.Position = UDim2.new(x, if x == 0 then 16 else 4, 1, -14)
		btn.Size = UDim2.new(0.5, -20, 0, 40)
		btn.BackgroundColor3 = color
		btn.Text = text
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = f
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
		Instance.new("UITextSizeConstraint", btn).MaxTextSize = 16
		return btn
	end
	local cancel = button("Cancel", "취소", Color3.fromRGB(38, 38, 50), 0)
	local ok = button("Ok", "확인", Color3.fromRGB(0, 176, 111), 0.5)
	local function finish(value: string?)
		f.Visible = false
		Popups.closed("MessagePrompt")
		local callback = onDone
		onDone = nil
		if callback then callback(value) end
	end
	cancel.MouseButton1Click:Connect(function() finish(nil) end)
	ok.MouseButton1Click:Connect(function() finish(tb.Text) end)
	gui, frame, titleLabel, bodyLabel, box, okButton = g, f, t, b, tb, ok
end

-- callback(text) after 확인, callback(nil) after 취소.
function MessagePrompt.ask(title: string, body: string, confirmText: string, callback: (string?) -> ())
	build()
	local f = frame :: Frame
	Popups.opened("MessagePrompt", function()
		f.Visible = false
		onDone = nil
	end)
	local t, b, ok, tb = titleLabel :: TextLabel, bodyLabel :: TextLabel, okButton :: TextButton, box :: TextBox
	t.Text = title
	b.Text = body
	ok.Text = confirmText
	tb.Text = ""
	onDone = callback
	f.Visible = true
end

-- Asks for the message, sends it to the server to be filtered, then opens the
-- Robux purchase (a [Studio 테스트] purchase while the product id is 0).
function MessagePrompt.buy(key: string, title: string)
	local product = MonetizationConfig.Products[key]
	if not product then return end
	local studioTest = product.id == 0 and RunService:IsStudio()
	if product.id == 0 and not studioTest then
		StarterGui:SetCore("SendNotification", { Title = title, Text = "준비 중인 상품입니다.", Duration = 3 })
		return
	end
	local body = "모두의 화면 위에 내 이름과 이 한마디가 떠요."
		.. (if studioTest then string.format("\n[Studio 테스트] 결제 없이 %d R$ 상품을 시험해요.", product.price) else "")
	MessagePrompt.ask(title, body, string.format("R$ %d", product.price), function(text)
		if text == nil then return end
		ClubShop:InvokeServer("SetMessage", text)
		if studioTest then
			ClubShop:InvokeServer("StudioTestBuy", { kind = "product", key = key })
		else
			MarketplaceService:PromptProductPurchase(player, product.id)
		end
	end)
end

return MessagePrompt

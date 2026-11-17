--!strict
-- 🎁 선물하기 on another player's card (D-1768, user 2026-11-18: "다른 플레이어 눌렀을 때 따라추기 아이템 주기처럼
-- 가드권 주기 vip권 주기 dj권 주기 추가"): a title line and three buttons — 🛡 가드권 / 💎 VIP권 / 🎧 DJ권. A tap tells
-- the server who gets it ("GiftTarget", GiftPassService) and then opens the Robux purchase of the gift
-- product (GiftGuard / GiftVIP / GiftDJ); in Studio, while a product has no id yet, a test buy. A pass the
-- player already has shows as "보유" and cannot be bought. DanceController's card calls layout() each
-- refresh with the y where the rows go and gets back the y below them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local ClubShop = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubShop") :: RemoteFunction

local GiftPassCard = {}

local KINDS = {
	{ key = "Guard", product = "GiftGuard", label = "🛡 가드권", color = Color3.fromRGB(150, 30, 40) },
	{ key = "VIP", product = "GiftVIP", label = "💎 VIP권", color = Color3.fromRGB(170, 120, 20) },
	{ key = "DJ", product = "GiftDJ", label = "🎧 DJ권", color = Color3.fromRGB(0, 120, 160) },
}
local GREY = Color3.fromRGB(70, 70, 80)

type Row = { frame: Frame, buttons: {[string]: TextButton}, target: Player? }
local rows: {[Frame]: Row} = {}

local busy = false
local function gift(row: Row, kind: any)
	local target = row.target
	if busy or not target or not target.Parent then return end
	busy = true
	local ok = pcall(function()
		-- (a refusal comes back as a toast from the server, ClubNotify)
		local fine = ClubShop:InvokeServer("GiftTarget", { key = kind.key, to = target.UserId })
		if not fine then return end
		local product = MonetizationConfig.Products[kind.product]
		if product and product.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.id)
		elseif RunService:IsStudio() then
			ClubShop:InvokeServer("StudioTestBuy", { kind = "product", key = kind.product })
		end
	end)
	if not ok then warn("[GiftPassCard] gift failed") end
	busy = false
end

local function build(card: Frame): Row
	local frame = Instance.new("Frame")
	frame.Name = "GiftRow"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -20, 0, 56)
	frame.Parent = card
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(230, 230, 236)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "🎁 선물하기"
	title.Parent = frame
	local row: Row = { frame = frame, buttons = {}, target = nil }
	for i, kind in ipairs(KINDS) do
		local b = Instance.new("TextButton")
		b.Name = "Gift_" .. kind.key
		b.Position = UDim2.new((i - 1) / 3, if i == 1 then 0 else 3, 0, 22)
		b.Size = UDim2.new(1 / 3, -4, 0, 32)
		b.BackgroundColor3 = kind.color
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = kind.label
		b.AutoButtonColor = true
		b.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = b
		b.Activated:Connect(function()
			if b:GetAttribute("Owned") then return end
			gift(row, kind)
		end)
		row.buttons[kind.key] = b
	end
	rows[card] = row
	return row
end

-- puts the rows at y on the card for this target; returns the y below them
function GiftPassCard.layout(card: Frame, target: Player, y: number): number
	local row = rows[card] or build(card)
	row.target = target
	row.frame.Position = UDim2.fromOffset(10, y)
	row.frame.Visible = true
	for _, kind in ipairs(KINDS) do
		local b = row.buttons[kind.key]
		local owned = kind.key ~= "DJ" and target:GetAttribute("Pass_" .. kind.key) == true
		b:SetAttribute("Owned", owned or nil)
		b.Text = if owned then kind.label .. " 보유" else kind.label
		b.BackgroundColor3 = if owned then GREY else kind.color
		b.AutoButtonColor = not owned
	end
	return y + 60
end

return GiftPassCard

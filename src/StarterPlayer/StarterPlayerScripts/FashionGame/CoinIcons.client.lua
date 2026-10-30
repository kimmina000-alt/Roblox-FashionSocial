--!strict
-- Every coin amount shows the gold ₩ coin picture (user 2026-10-30: "코인은
-- 이 아이콘으로 모두 통일"). The texts keep writing 💰 (EconomyConfig.Icon,
-- shop buttons, menus); this script watches every text on screen and on the
-- world's signs, swaps each 💰 for a gap and lays the coin picture in it.
-- Explicit lines ("\n") are followed; RichText tags are ignored for measuring.

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local COIN = require(script.Parent:WaitForChild("Icons")).coin
local MARK = "💰"
local GAP = "\u{2003}" -- an em space holds the picture's place

type Entry = { raw: string, set: string, icons: {ImageLabel} }
local tracked: {[TextLabel | TextButton]: Entry} = {}

local function plain(s: string): string
	return (string.gsub(s, "<[^>]->", ""))
end

local function width(s: string, font: Enum.Font): number
	return TextService:GetTextSize(plain(s), 100, font, Vector2.new(1e6, 1e6)).X
end

local function place(obj: TextLabel | TextButton, entry: Entry)
	for _, icon in ipairs(entry.icons) do icon:Destroy() end
	entry.icons = {}
	local text = obj.Text
	if not string.find(text, GAP, 1, true) then return end
	local lines = string.split(text, "\n")
	local font = if obj.Font == Enum.Font.Unknown then Enum.Font.GothamBold else obj.Font
	-- the size the text is drawn at: from the drawn block against the widest line at 100
	local widest = 0
	for _, line in ipairs(lines) do widest = math.max(widest, width(line, font)) end
	local bounds = obj.TextBounds
	if widest <= 0 or bounds.X <= 0 then return end
	local k = bounds.X / widest
	local lineH = bounds.Y / #lines
	local pad = obj:FindFirstChildOfClass("UIPadding")
	local padL = if pad then pad.PaddingLeft.Offset + pad.PaddingLeft.Scale * obj.AbsoluteSize.X else 0
	local padR = if pad then pad.PaddingRight.Offset + pad.PaddingRight.Scale * obj.AbsoluteSize.X else 0
	local padT = if pad then pad.PaddingTop.Offset + pad.PaddingTop.Scale * obj.AbsoluteSize.Y else 0
	local padB = if pad then pad.PaddingBottom.Offset + pad.PaddingBottom.Scale * obj.AbsoluteSize.Y else 0
	local innerW, innerH = obj.AbsoluteSize.X - padL - padR, obj.AbsoluteSize.Y - padT - padB
	local top = padT + (if obj.TextYAlignment == Enum.TextYAlignment.Top then 0
		elseif obj.TextYAlignment == Enum.TextYAlignment.Bottom then innerH - bounds.Y
		else (innerH - bounds.Y) / 2)
	local gapW = width(GAP, font) * k
	local size = math.min(lineH * 0.92, gapW * 1.25)
	for i, line in ipairs(lines) do
		local lineW = width(line, font) * k
		local left = padL + (if obj.TextXAlignment == Enum.TextXAlignment.Left then 0
			elseif obj.TextXAlignment == Enum.TextXAlignment.Right then innerW - lineW
			else (innerW - lineW) / 2)
		local from = 1
		while true do
			local at = string.find(line, GAP, from, true)
			if not at then break end
			local x = left + width(string.sub(line, 1, at - 1), font) * k + gapW / 2
			local icon = Instance.new("ImageLabel")
			icon.Name = "CoinIcon"
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromOffset(x, top + (i - 0.5) * lineH)
			icon.Size = UDim2.fromOffset(size, size)
			icon.BackgroundTransparency = 1
			icon.Image = COIN
			icon.ImageTransparency = obj.TextTransparency
			icon.ZIndex = obj.ZIndex
			icon.Parent = obj
			table.insert(entry.icons, icon)
			from = at + #GAP
		end
	end
end

local function refresh(obj: TextLabel | TextButton)
	local entry = tracked[obj]
	if not entry then return end
	if obj.Text ~= entry.set then
		-- a new text from its script
		entry.raw = obj.Text
		entry.set = (string.gsub(entry.raw, MARK .. " ?", GAP))
		obj.Text = entry.set
	end
	task.defer(function()
		if obj.Parent then place(obj, entry) end
	end)
end

local function watch(obj: Instance)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
	local t = obj :: TextLabel | TextButton
	if tracked[t] then return end
	local started = false
	local function start()
		if started then return end
		started = true
		tracked[t] = { raw = "", set = "", icons = {} }
		refresh(t)
		for _, prop in ipairs({ "AbsoluteSize", "TextBounds" }) do
			t:GetPropertyChangedSignal(prop):Connect(function() refresh(t) end)
		end
		t.Destroying:Connect(function() tracked[t] = nil end)
	end
	if string.find(t.Text, MARK, 1, true) then start() end
	-- a text that gets a 💰 later
	t:GetPropertyChangedSignal("Text"):Connect(function()
		if tracked[t] then refresh(t) elseif string.find(t.Text, MARK, 1, true) then start() end
	end)
end

local playerGui = player:WaitForChild("PlayerGui")
for _, d in ipairs(playerGui:GetDescendants()) do watch(d) end
playerGui.DescendantAdded:Connect(watch)
-- signs and menus in the world (SurfaceGuis on parts): checked a bit at a time
task.spawn(function()
	local all = workspace:GetDescendants()
	for i, d in ipairs(all) do
		watch(d)
		if i % 4000 == 0 then task.wait() end
	end
end)
workspace.DescendantAdded:Connect(watch)

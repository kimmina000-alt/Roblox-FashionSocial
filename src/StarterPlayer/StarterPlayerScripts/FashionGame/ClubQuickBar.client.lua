--!strict
-- Club buttons (user 2026-11-01, D-694 / D-695), shown inside the club only:
--   ≡ list       inside the "NOW PLAYING" banner, left end: the music window, to
--                see the playlist and queue a song (ClubMusicController)
--   › skip       inside the banner, right end: vote the song away (ClubService
--                "VoteSkip"; hidden while a DJ plays), the count beside it

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local musicRemote = FashionGame:WaitForChild("Remotes"):WaitForChild("Music") :: RemoteFunction
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "ClubQuickBar"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Enabled = false
gui.Parent = playerGui

-- (D-730, user 2026-11-01: the ♪ button at the left edge is gone; the top
-- row's ♪ opens the dances everywhere)

-- the two small round buttons at the banner's two ends, inside it (beside it
-- until 2026-11-01; user: "노래 제목 프레임 안으로")
local SIDE = 24
local function sideButton(name: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(SIDE, SIDE)
	-- (no circle behind them since 2026-11-01, user: only the white marks)
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Visible = false
	return b
end
-- ≡ : three white bars, drawn like the top bar's ☰
local listButton = sideButton("ClubList")
for i = -1, 1 do
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5 + i * 0.17)
	bar.Size = UDim2.fromScale(0.46, 0.08)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Parent = listButton
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
end
-- › : a chevron of two bars
local skipButton = sideButton("ClubSkip")
for _, sign in ipairs({ -1, 1 }) do
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.54, 0.5 + sign * 0.11)
	bar.Size = UDim2.fromScale(0.34, 0.085)
	bar.Rotation = -sign * 45 -- (top bar ＼, bottom bar ／)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Parent = skipButton
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
end
-- 💃 right of ≡ (D-837, user; in the dance window in D-835): switched on, the
-- player dances the choreography of every song that has one, in time with it,
-- while standing in the club (ChoreoController reads the LocalPlayer
-- attribute ChoreoOn). Off by default; a pink circle while on.
local choreoButton = sideButton("ClubChoreo")
choreoButton.Text = "💃"
choreoButton.TextSize = 15
choreoButton.TextColor3 = Color3.new(1, 1, 1)
choreoButton.BackgroundColor3 = Color3.fromRGB(255, 70, 170)
Instance.new("UICorner", choreoButton).CornerRadius = UDim.new(1, 0)
local function paintChoreo()
	local on = player:GetAttribute("ChoreoOn") == true
	choreoButton.BackgroundTransparency = if on then 0 else 1
	choreoButton.TextTransparency = if on then 0 else 0.35
end
player:GetAttributeChangedSignal("ChoreoOn"):Connect(paintChoreo)
paintChoreo()
-- the vote count right of ›
local skipCount = Instance.new("TextLabel")
skipCount.Name = "SkipCount"
skipCount.Size = UDim2.fromOffset(34, 18)
skipCount.BackgroundColor3 = Color3.fromRGB(255, 70, 170)
skipCount.TextColor3 = Color3.new(1, 1, 1)
skipCount.Font = Enum.Font.GothamBold
skipCount.TextSize = 11
skipCount.Visible = false
Instance.new("UICorner", skipCount).CornerRadius = UDim.new(1, 0)

listButton.Activated:Connect(function() UiBus.OpenMusic:Fire() end)

-- a short line under the banner for the vote's answer
local toast = Instance.new("TextLabel")
toast.Name = "ClubToast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.fromOffset(240, 22)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextSize = 12
toast.Visible = false
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)
local toastId = 0
local function showToast(text: string)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(2.5, function() if toastId == id then toast.Visible = false end end)
end

choreoButton.Activated:Connect(function()
	local on = not (player:GetAttribute("ChoreoOn") == true)
	player:SetAttribute("ChoreoOn", on)
	showToast(if on then "💃 안무 켜짐: 안무 있는 노래에 맞춰 춰요" else "💃 안무 꺼짐")
end)

skipButton.Activated:Connect(function()
	local ok, message = musicRemote:InvokeServer("VoteSkip", nil)
	if typeof(message) == "string" then showToast(message) elseif not ok then showToast("지금은 투표할 수 없어요.") end
end)

local inClub = false
RunService.RenderStepped:Connect(function()
	local danceGui = playerGui:FindFirstChild("FashionDanceGui")
	local banner = danceGui and danceGui:FindFirstChild("NowPlaying") :: TextLabel?
	if not danceGui or not banner then return end
	for _, item in ipairs({ skipCount, toast } :: {GuiObject}) do
		if item.Parent ~= danceGui then item.Parent = danceGui end
	end
	-- (inside the banner: its UIPadding (62 left, 34 right) leaves room; 4 px in)
	if listButton.Parent ~= banner then
		listButton.Parent = banner
		listButton.AnchorPoint = Vector2.new(0, 0.5)
		listButton.Position = UDim2.new(0, -58, 0.5, 0)
		choreoButton.Parent = banner
		choreoButton.AnchorPoint = Vector2.new(0, 0.5)
		choreoButton.Position = UDim2.new(0, -32, 0.5, 0)
		skipButton.Parent = banner
		skipButton.AnchorPoint = Vector2.new(1, 0.5)
		skipButton.Position = UDim2.new(1, 30, 0.5, 0)
	end
	local shown = inClub and banner.Visible
	local djOn = (FashionGame:GetAttribute("ClubDJ") or 0) ~= 0
	local votes = FashionGame:GetAttribute("ClubSkipVotes")
	listButton.Visible = shown
	choreoButton.Visible = shown
	skipButton.Visible = shown and not djOn
	skipCount.Visible = skipButton.Visible and typeof(votes) == "string" and votes:sub(1, 2) ~= "0/"
	skipCount.Text = if typeof(votes) == "string" then votes else ""
	-- (AbsolutePosition leaves out the top bar inset; this ScreenGui ignores it)
	local inset = game:GetService("GuiService"):GetGuiInset()
	local p, s = banner.AbsolutePosition + inset, banner.AbsoluteSize
	skipCount.Position = UDim2.fromOffset(p.X + s.X + 6, p.Y + (s.Y - 18) / 2)
	toast.Position = UDim2.fromOffset(p.X + s.X / 2, p.Y + s.Y + 6)
end)

-- inside the club only
task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		inClub = root ~= nil and ClubConfig.isInClub(root.Position)
		gui.Enabled = inClub
		task.wait(0.5)
	end
end)

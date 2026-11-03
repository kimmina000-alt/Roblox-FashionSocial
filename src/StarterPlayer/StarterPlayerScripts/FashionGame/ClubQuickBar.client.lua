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
-- 🎵 in front of the title of a song with a choreography (D-839, user: "그
-- 음표를 안무 버튼으로 하자"; the 💃 of D-837 is gone): tap to dance the
-- choreography or stop it (back to the dance before, ChoreoController).
-- (D-841, user) the note itself shows it, no circle: blue like the old 🎵 while
-- dancing it (LocalPlayer attribute ChoreoFollowing), white when not. A white
-- ♫ drawn from small shapes like the ≡ and › (an emoji keeps its own colours),
-- no background (user: "흰색 음표 아이콘 … 누르면 거기 색을 넣어 … 배경 깔지 마").
local CHOREO_ON = Color3.fromRGB(90, 175, 255)
local choreoButton = sideButton("ClubChoreo")
choreoButton.Size = UDim2.fromOffset(22, 22)
local noteParts: {Frame} = {}
for _, s in ipairs({
	{ 0.25, 0.79, 0.36, 0.26, -20, true }, -- the two note heads
	{ 0.73, 0.69, 0.36, 0.26, -20, true },
	{ 0.40, 0.49, 0.08, 0.60, 0, false }, -- their stems
	{ 0.88, 0.39, 0.08, 0.60, 0, false },
	{ 0.64, 0.19, 0.58, 0.13, -12, false }, -- the beam
}) do
	local part = Instance.new("Frame")
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.Position = UDim2.fromScale(s[1], s[2])
	part.Size = UDim2.fromScale(s[3], s[4])
	part.Rotation = s[5]
	part.BorderSizePixel = 0
	part.Parent = choreoButton
	if s[6] then Instance.new("UICorner", part).CornerRadius = UDim.new(1, 0) end
	table.insert(noteParts, part)
end
local function paintChoreo()
	local color = if player:GetAttribute("ChoreoFollowing") then CHOREO_ON else Color3.new(1, 1, 1)
	for _, part in ipairs(noteParts) do part.BackgroundColor3 = color end
end
player:GetAttributeChangedSignal("ChoreoFollowing"):Connect(paintChoreo)
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
	local was = player:GetAttribute("ChoreoFollowing") == true
	UiBus.ChoreoTap:Fire()
	showToast(if was then "🎵 안무 멈춤" else "🎵 안무 따라 추기")
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
	-- (inside the banner: its UIPadding (34 at both ends) leaves room; 4 px in)
	if listButton.Parent ~= banner then
		listButton.Parent = banner
		listButton.AnchorPoint = Vector2.new(0, 0.5)
		listButton.Position = UDim2.new(0, -30, 0.5, 0)
		choreoButton.Parent = banner
		choreoButton.AnchorPoint = Vector2.new(1, 0.5)
		skipButton.Parent = banner
		skipButton.AnchorPoint = Vector2.new(1, 0.5)
		skipButton.Position = UDim2.new(1, 30, 0.5, 0)
	end
	local shown = inClub and banner.Visible
	local djOn = (FashionGame:GetAttribute("ClubDJ") or 0) ~= 0
	local votes = FashionGame:GetAttribute("ClubSkipVotes")
	listButton.Visible = shown
	-- the 🎵 sits just in front of the title (centred in the banner; the title
	-- of a choreography song is shown without its ♪, DanceController)
	local track = ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
	choreoButton.Visible = shown and track ~= nil and track.choreo ~= nil
	if choreoButton.Visible then
		local inner = banner.AbsoluteSize.X - 68
		local textLeft = math.max((inner - banner.TextBounds.X) / 2, 31)
		choreoButton.Position = UDim2.new(0, textLeft - 8, 0.5, 0)
	end
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

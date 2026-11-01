--!strict
-- Club buttons (user 2026-11-01, D-694): inside the club three round buttons
-- stand at the right edge of the screen, so nobody has to find them in the
-- ☰ menu or at the turntable:
--   💃 춤        the dance window (DanceController)
--   🎵 신청      the music window: queue a song (ClubMusicController)
--   ⏭ 스킵 n/m   vote the song away (ClubService "VoteSkip"; none while a DJ plays)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local musicRemote = FashionGame:WaitForChild("Remotes"):WaitForChild("Music") :: RemoteFunction
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "ClubQuickBar"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local column = Instance.new("Frame")
column.Name = "Column"
column.AnchorPoint = Vector2.new(1, 0.5)
column.Position = UDim2.new(1, -10, 0.45, 0)
column.Size = UDim2.fromOffset(58, 3 * 62)
column.BackgroundTransparency = 1
column.Parent = gui
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Parent = column

local function roundButton(name: string, icon: string, label: string, order: number, color: Color3): (TextButton, TextLabel)
	local b = Instance.new("TextButton")
	b.Name = name
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(56, 56)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.1
	b.Text = ""
	b.AutoButtonColor = true
	b.Parent = column
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.new(1, 1, 1)
	edge.Transparency = 0.4
	edge.Thickness = 1.5
	edge.Parent = b
	local i = Instance.new("TextLabel")
	i.Name = "Icon"
	i.BackgroundTransparency = 1
	i.Size = UDim2.new(1, 0, 0.62, 0)
	i.Position = UDim2.fromScale(0, 0.06)
	i.Text = icon
	i.TextScaled = true
	i.Font = Enum.Font.GothamBold
	i.TextColor3 = Color3.new(1, 1, 1)
	i.Parent = b
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.Position = UDim2.new(0.5, 0, 1, -5)
	l.Size = UDim2.new(1, -6, 0, 13)
	l.Text = label
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = b
	return b, l
end

local danceButton = roundButton("Dance", "💃", "춤", 1, Color3.fromRGB(255, 70, 170))
local requestButton = roundButton("Request", "🎵", "신청", 2, Color3.fromRGB(110, 70, 255))
local skipButton, skipLabel = roundButton("Skip", "⏭", "스킵", 3, Color3.fromRGB(40, 40, 52))

danceButton.Activated:Connect(function() UiBus.OpenDance:Fire() end)
requestButton.Activated:Connect(function() UiBus.OpenMusic:Fire() end)

-- a short line under the bar for the vote's answer
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(1, 0)
toast.Position = UDim2.new(1, -10, 0.45, 3 * 62 / 2 + 6)
toast.Size = UDim2.fromOffset(200, 22)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextSize = 12
toast.Visible = false
toast.Parent = gui
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)
local toastId = 0
local function showToast(text: string)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(2.5, function() if toastId == id then toast.Visible = false end end)
end

skipButton.Activated:Connect(function()
	local ok, message = musicRemote:InvokeServer("VoteSkip", nil)
	if typeof(message) == "string" then showToast(message) elseif not ok then showToast("지금은 투표할 수 없어요.") end
end)

local function refreshSkip()
	local djOn = (FashionGame:GetAttribute("ClubDJ") or 0) ~= 0
	skipButton.Visible = not djOn
	local votes = FashionGame:GetAttribute("ClubSkipVotes")
	skipLabel.Text = if typeof(votes) == "string" and votes:sub(1, 2) ~= "0/" then "스킵 " .. votes else "스킵"
end
FashionGame:GetAttributeChangedSignal("ClubSkipVotes"):Connect(refreshSkip)
FashionGame:GetAttributeChangedSignal("ClubDJ"):Connect(refreshSkip)
refreshSkip()

-- shown only inside the club
task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		gui.Enabled = root ~= nil and ClubConfig.isInClub(root.Position)
		task.wait(0.5)
	end
end)

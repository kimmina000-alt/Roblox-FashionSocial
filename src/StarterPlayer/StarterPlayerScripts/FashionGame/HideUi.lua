--!strict
-- UI 숨기기 (D-1594, user 2026-11-17: "ui 숨기기 버튼 추가"). ☰ → 🙈 UI 숨기기 (MenuController) hides every
-- screen window of the game on this screen (the top buttons, the hotbar, banners, the joystick), the name
-- tags over heads and Roblox's own chat / player list, for clean screenshots and videos. Only a small 👁
-- button stays at the top right; a tap on it brings everything back as it was. Windows that pop up
-- while hidden are kept hidden and shown with the rest. Not saved: a rejoin shows the UI.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HideUi = {}

local CORE = { Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health }
local hidden = false
local restore: {[ScreenGui]: boolean} = {}
local coreWas: {[Enum.CoreGuiType]: boolean} = {}

local showGui = Instance.new("ScreenGui")
showGui.Name = "HideUiShow"
showGui.ResetOnSpawn = false
showGui.DisplayOrder = 100
showGui.Enabled = false
showGui.Parent = playerGui
local showButton = Instance.new("TextButton")
showButton.Name = "Show"
showButton.AnchorPoint = Vector2.new(1, 0)
showButton.Position = UDim2.new(1, -12, 0, 12)
showButton.Size = UDim2.fromOffset(44, 44)
showButton.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
showButton.BackgroundTransparency = 0.55
showButton.Text = "👁"
showButton.TextScaled = true
showButton.TextColor3 = Color3.new(1, 1, 1)
showButton.Font = Enum.Font.GothamBold
showButton.Parent = showGui
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = showButton
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = showButton
end

local tags: {[BillboardGui]: boolean} = {} -- (the name tags over everyone's heads too)

local function sweep()
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= showGui and g.Enabled then
			restore[g] = true
			g.Enabled = false
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local head = other.Character and other.Character:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("OHUNameTag")
		if tag and tag:IsA("BillboardGui") and tag.Enabled then
			tags[tag] = true
			tag.Enabled = false
		end
	end
end

function HideUi.isHidden(): boolean
	return hidden
end

function HideUi.hide()
	if hidden then return end
	hidden = true
	table.clear(restore)
	table.clear(tags)
	sweep()
	for _, t in ipairs(CORE) do
		local ok, on = pcall(function() return StarterGui:GetCoreGuiEnabled(t) end)
		coreWas[t] = ok and on == true
		pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end)
	end
	showGui.Enabled = true
	-- (windows the game turns on while hidden wait with the rest)
	task.spawn(function()
		while hidden do
			sweep()
			task.wait(0.3)
		end
	end)
end

function HideUi.show()
	if not hidden then return end
	hidden = false
	showGui.Enabled = false
	for g in pairs(restore) do
		if g.Parent then g.Enabled = true end
	end
	table.clear(restore)
	for tag in pairs(tags) do
		if tag.Parent then tag.Enabled = player:GetAttribute("HideName") ~= true end
	end
	table.clear(tags)
	for t, on in pairs(coreWas) do
		if on then pcall(function() StarterGui:SetCoreGuiEnabled(t, true) end) end
	end
end

showButton.Activated:Connect(HideUi.show)

return HideUi

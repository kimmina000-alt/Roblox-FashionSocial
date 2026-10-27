--!strict
-- Name tag above every character: nickname + accumulated XP (user,
-- 2026-10-22; ECONOMY.md §2, D-074). XP = minutes played (EconomyService
-- sets the player attribute "XP" once a minute). Replaces Roblox's default
-- name display.

local Players = game:GetService("Players")

local NameTagService = {}

local TAG_NAME = "OHUNameTag"

local function formatXp(value: any): string
	local xp = if typeof(value) == "number" then math.floor(value) else 0
	-- 12345 → 12,345
	local text = tostring(xp)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
	return "⭐ " .. formatted .. " XP"
end

local function build(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not head or not head:IsA("BasePart") or not humanoid then return end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local old = head:FindFirstChild(TAG_NAME)
	if old then old:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = TAG_NAME
	billboard.Size = UDim2.fromOffset(200, 46)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.Adornee = head

	local name = Instance.new("TextLabel")
	name.Name = "DisplayName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.58, 0)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = player.DisplayName
	name.Parent = billboard

	local xp = Instance.new("TextLabel")
	xp.Name = "XP"
	xp.BackgroundTransparency = 1
	xp.Position = UDim2.fromScale(0, 0.6)
	xp.Size = UDim2.new(1, 0, 0.4, 0)
	xp.Font = Enum.Font.GothamBold
	xp.TextScaled = true
	xp.TextColor3 = Color3.fromRGB(255, 214, 90)
	xp.TextStrokeTransparency = 0.5
	xp.Text = formatXp(player:GetAttribute("XP"))
	xp.Parent = billboard

	billboard.Parent = head
end

function NameTagService.Start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character) task.spawn(build, player, character) end)
		if player.Character then task.spawn(build, player, player.Character) end
		player:GetAttributeChangedSignal("XP"):Connect(function()
			local head = player.Character and player.Character:FindFirstChild("Head")
			local tag = head and head:FindFirstChild(TAG_NAME)
			local label = tag and tag:FindFirstChild("XP")
			if label and label:IsA("TextLabel") then label.Text = formatXp(player:GetAttribute("XP")) end
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do watch(player) end
	Players.PlayerAdded:Connect(watch)
end

-- Role badges over the head (user 2026-10-27), on their own billboard so they
-- show whether the XP name tags are on or not: "VIP" white with a red neon
-- outline for a VIP pass owner, "DJ" white with a sky-blue one at the decks
-- (character attribute Djing). Above the cafe staff tag's place.
local ROLE_TAG = "OHURoleTag"
local function refreshRoles(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then return end
	local vip = player:GetAttribute("Pass_VIP") == true
	local djing = character:GetAttribute("Djing")
	local dj = djing ~= nil and djing ~= false
	local tag = head:FindFirstChild(ROLE_TAG)
	if not vip and not dj then
		if tag then tag:Destroy() end
		return
	end
	if not tag then
		local g = Instance.new("BillboardGui")
		g.Name = ROLE_TAG
		g.Size = UDim2.fromOffset(110, 26)
		g.StudsOffset = Vector3.new(0, 2.4, 0)
		-- right over Roblox's own name display (user 2026-10-27): the same anchor
		-- as before, one badge height up; the cafe staff tag sits above it
		g.SizeOffset = Vector2.new(0, 1.5)
		g.MaxDistance = 90
		g.LightInfluence = 0
		g.Adornee = head
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, 8)
		list.Parent = g
		for i, spec in ipairs({ { "VIP", Color3.fromRGB(255, 30, 50) }, { "DJ", Color3.fromRGB(70, 200, 255) } }) do
			local l = Instance.new("TextLabel")
			l.Name = spec[1]
			l.LayoutOrder = i
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(0, 46, 1, 0)
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.Text = spec[1]
			l.TextColor3 = Color3.new(1, 1, 1)
			l.Parent = g
			local stroke = Instance.new("UIStroke") -- the neon: a thick coloured outline
			stroke.Color = spec[2]
			stroke.Thickness = 3
			stroke.Parent = l
		end
		g.Parent = head
		tag = g
	end
	for name, on in pairs({ VIP = vip, DJ = dj }) do
		local l = (tag :: Instance):FindFirstChild(name)
		if l and l:IsA("TextLabel") then l.Visible = on end
	end
end

function NameTagService.StartRoles()
	local function watch(player: Player)
		local function onCharacter(character: Model)
			character:WaitForChild("Head", 10)
			refreshRoles(player)
			character:GetAttributeChangedSignal("Djing"):Connect(function() refreshRoles(player) end)
		end
		player.CharacterAdded:Connect(function(character) task.spawn(onCharacter, character) end)
		if player.Character then task.spawn(onCharacter, player.Character) end
		player:GetAttributeChangedSignal("Pass_VIP"):Connect(function() refreshRoles(player) end)
	end
	for _, player in ipairs(Players:GetPlayers()) do watch(player) end
	Players.PlayerAdded:Connect(watch)
end

return NameTagService
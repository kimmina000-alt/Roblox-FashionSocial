--!strict
-- Name tag above every character: nickname + accumulated XP (user,
-- 2026-10-22; ECONOMY.md §2, D-074). XP = minutes played (EconomyService
-- sets the player attribute "XP" once a minute). Replaces Roblox's default
-- name display.

local Players = game:GetService("Players")
local FashionGame = game:GetService("ReplicatedStorage"):WaitForChild("FashionGame")

local NameTagService = {}

local TAG_NAME = "OHUNameTag"
-- (D-948, user 2026-11-07, second try: "기존 가드 vip dj 크기는 그대로 두고 그
-- 크기에 맞춰") the name tag in pixels again, at the role badges' size: the
-- name as tall as a badge (13 px), the XP line under it a little smaller
-- (200 x 46 px before: the name 27 px tall)
local TAG_W, TAG_H = 150, 26

local function formatXp(value: any): string
	local xp = if typeof(value) == "number" then math.floor(value) else 0
	-- 12345 → 12,345
	local text = tostring(xp)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
	return "⭐ " .. formatted .. " XP"
end

-- ⛓ before the name while a guard's handcuffs are on (attribute Cuffed, GuardService, D-722);
-- the nickname, not the id (D-797, user)
local function nameText(player: Player): string
	return (if player:GetAttribute("Cuffed") then "⛓ " else "") .. player.DisplayName
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
	-- (D-948, user 2026-11-07: "머리 위에 닉네임 뜨는 거 너무 커 모바일에서는 더 큼.
	-- 잘 안 보여도 되니까 크기 고정해.") smaller, at the badges' size (above)
	billboard.Size = UDim2.fromOffset(TAG_W, TAG_H)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.Adornee = head
	billboard.Enabled = player:GetAttribute("HideName") ~= true -- (D-1377: ☰ 닉네임 숨기기)

	local name = Instance.new("TextLabel")
	name.Name = "DisplayName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.54, 0) -- (14 px)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = nameText(player) -- the player's id (user 2026-10-27), the VIP / DJ badge sits on top
	name.Parent = billboard

	local xp = Instance.new("TextLabel")
	xp.Name = "XP"
	xp.BackgroundTransparency = 1
	xp.Position = UDim2.fromScale(0, 0.6)
	xp.Size = UDim2.new(1, 0, 0.4, 0) -- (10 px)
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
		-- (user 2026-10-30: id + XP gone, only VIP left) a new outfit can swap the
		-- Head part, and the tag went with the old one: build again on a new Head
		local function onCharacter(character: Model)
			build(player, character)
			character.ChildAdded:Connect(function(child)
				if child.Name == "Head" then task.defer(build, player, character) end
			end)
		end
		player.CharacterAdded:Connect(function(character) task.spawn(onCharacter, character) end)
		if player.Character then task.spawn(onCharacter, player.Character) end
		player:GetAttributeChangedSignal("XP"):Connect(function()
			local head = player.Character and player.Character:FindFirstChild("Head")
			local tag = head and head:FindFirstChild(TAG_NAME)
			local label = tag and tag:FindFirstChild("XP")
			if label and label:IsA("TextLabel") then label.Text = formatXp(player:GetAttribute("XP")) end
		end)
		-- (D-1377) ☰ 닉네임 숨기기: the whole name tag (nickname + XP) off / on
		player:GetAttributeChangedSignal("HideName"):Connect(function()
			local head = player.Character and player.Character:FindFirstChild("Head")
			local tag = head and head:FindFirstChild(TAG_NAME)
			if tag and tag:IsA("BillboardGui") then tag.Enabled = player:GetAttribute("HideName") ~= true end
		end)
		player:GetAttributeChangedSignal("Cuffed"):Connect(function()
			local head = player.Character and player.Character:FindFirstChild("Head")
			local tag = head and head:FindFirstChild(TAG_NAME)
			local label = tag and tag:FindFirstChild("DisplayName")
			if label and label:IsA("TextLabel") then label.Text = nameText(player) end
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do watch(player) end
	Players.PlayerAdded:Connect(watch)
end

-- Role badges over the head (user 2026-10-27), on their own billboard so they
-- show whether the XP name tags are on or not, all in one row and all at the
-- VIP letters' size (user 2026-10-31: the 알바생 and GUARD tags were bigger
-- and overlapped):
--   알바생  white, green outline   (character attribute CafeJob, CafeJobService)
--   GUARD   white on a black plate, red edge   (Guard pass, D-623)
--   VIP     white, red neon outline   (VIP pass)
--   DJ      white, sky-blue outline   (the player's DJ turn: FashionGame
--           attribute ClubDJ = their id, DjService; until 2026-11-01 only while
--           standing at the turntable, character attribute Djing — the user
--           saw no DJ tag)
local ROLE_TAG = "OHURoleTag"
local GUARD_TAG = "OHUGuardTag" -- (its own billboard until 2026-10-31: removed if found)
local ROW_H = 13
-- name, layout order, width (px), outline colour, text
local ROLES = {
	-- (D-1366) the opening event's permanent title (player attribute Title_Founding): first,
	-- on a dark plate with an orange edge like the user's sample
	{ "Founding", 0, 96, Color3.fromRGB(255, 150, 60), "FOUNDING MEMBER" },
	{ "Staff", 1, 34, Color3.fromRGB(30, 150, 80), "알바생" },
	{ "GUARD", 2, 44, Color3.fromRGB(220, 20, 35), "GUARD" },
	{ "VIP", 3, 23, Color3.fromRGB(255, 30, 50), "VIP" },
	{ "DJ", 4, 23, Color3.fromRGB(70, 200, 255), "DJ" },
}
local function refreshRoles(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then return end
	local oldGuard = head:FindFirstChild(GUARD_TAG)
	if oldGuard then oldGuard:Destroy() end
	local djing = character:GetAttribute("Djing")
	local cafeJob = character:GetAttribute("CafeJob")
	local on = {
		Founding = player:GetAttribute("Title_Founding") == true,
		Staff = cafeJob ~= nil and cafeJob ~= false and cafeJob ~= "",
		GUARD = player:GetAttribute("Pass_Guard") == true,
		VIP = player:GetAttribute("Pass_VIP") == true,
		DJ = (djing ~= nil and djing ~= false) or FashionGame:GetAttribute("ClubDJ") == player.UserId,
	}
	-- (D-1378) each badge the player hid in the ☰ menu (attribute HideBadge_<role>)
	for role in pairs(on) do
		if player:GetAttribute("HideBadge_" .. role) == true then on[role] = false end
	end
	local tag = head:FindFirstChild(ROLE_TAG)
	if not (on.Founding or on.Staff or on.GUARD or on.VIP or on.DJ) then
		if tag then tag:Destroy() end
		return
	end
	if tag and not tag:FindFirstChild("Founding") then -- (an older tag without every badge)
		tag:Destroy()
		tag = nil
	end
	if not tag then
		local g = Instance.new("BillboardGui")
		g.Name = ROLE_TAG
		-- (half size, user 2026-10-30: was 110 x 26); wide enough for all four
		g.Size = UDim2.fromOffset(260, ROW_H) -- (150 until D-1366: room for FOUNDING MEMBER too)
		g.StudsOffset = Vector3.new(0, 2.4, 0)
		-- right over the name tag (id + XP, 46 px tall on the same anchor): one
		-- badge height and a half up, so 23 px over its middle like before
		-- (D-948: the name tag is 26 px tall now: 13 + 2 + 6.5 = 21.5 px up)
		g.SizeOffset = Vector2.new(0, 21.5 / ROW_H)
		g.MaxDistance = 90
		g.LightInfluence = 0
		g.Adornee = head
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 4)
		list.Parent = g
		for _, spec in ipairs(ROLES) do
			local l = Instance.new("TextLabel")
			l.Name = spec[1]
			l.LayoutOrder = spec[2]
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(0, spec[3], 1, 0)
			l.TextScaled = true
			l.Text = spec[5]
			l.TextColor3 = Color3.new(1, 1, 1)
			if spec[1] == "GUARD" or spec[1] == "Founding" then
				-- the bodyguard plate, at the row's height
				l.BackgroundColor3 = if spec[1] == "Founding" then Color3.fromRGB(40, 22, 12) else Color3.fromRGB(10, 10, 12)
				l.BackgroundTransparency = 0.05
				if spec[1] == "Founding" then l.TextColor3 = Color3.fromRGB(255, 170, 90) end
				l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 3)
				corner.Parent = l
				local edge = Instance.new("UIStroke")
				edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				edge.Color = spec[4]
				edge.Thickness = 1.5
				edge.Parent = l
				local pad = Instance.new("UIPadding")
				pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 2), UDim.new(0, 2)
				pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
				pad.Parent = l
			else
				-- Jura Bold (user's pick, sample 11, 2026-10-27); 알바생 in Gotham (Jura has no Hangul)
				l.FontFace = if spec[1] == "Staff"
					then Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
					else Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold)
				local stroke = Instance.new("UIStroke") -- the neon: a thick coloured outline
				stroke.Color = spec[4]
				stroke.Thickness = 1.5
				stroke.Parent = l
			end
			l.Parent = g
		end
		g.Parent = head
		tag = g
	end
	for name, shown in pairs(on) do
		local l = (tag :: Instance):FindFirstChild(name)
		if l and l:IsA("TextLabel") then l.Visible = shown end
	end
end

function NameTagService.StartRoles()
	local function watch(player: Player)
		local function onCharacter(character: Model)
			character:WaitForChild("Head", 10)
			refreshRoles(player)
			character:GetAttributeChangedSignal("Djing"):Connect(function() refreshRoles(player) end)
			character:GetAttributeChangedSignal("CafeJob"):Connect(function() refreshRoles(player) end)
			character.ChildAdded:Connect(function(child)
				if child.Name == "Head" then task.defer(refreshRoles, player) end
			end)
		end
		player.CharacterAdded:Connect(function(character) task.spawn(onCharacter, character) end)
		if player.Character then task.spawn(onCharacter, player.Character) end
		player:GetAttributeChangedSignal("Pass_VIP"):Connect(function() refreshRoles(player) end)
		player:GetAttributeChangedSignal("Pass_Guard"):Connect(function() refreshRoles(player) end)
		player:GetAttributeChangedSignal("Title_Founding"):Connect(function() refreshRoles(player) end) -- (D-1366)
		-- (D-1378) each badge's 숨기기 in the ☰ menu
		for _, role in ipairs({ "Founding", "Staff", "GUARD", "VIP", "DJ" }) do
			player:GetAttributeChangedSignal("HideBadge_" .. role):Connect(function() refreshRoles(player) end)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do watch(player) end
	Players.PlayerAdded:Connect(watch)
	-- a DJ turn starting or ending moves the DJ tag
	FashionGame:GetAttributeChangedSignal("ClubDJ"):Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do refreshRoles(player) end
	end)
end

return NameTagService

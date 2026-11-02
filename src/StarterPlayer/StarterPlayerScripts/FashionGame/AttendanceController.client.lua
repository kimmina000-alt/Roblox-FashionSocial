--!strict
-- Attendance card (user 2026-11-03, D-801): the week's 7 stamp slots
-- (EconomyConfig.StreakCoins), the days already here stamped, today's stamp
-- landing with an animation; the opening gift (EconomyConfig.WelcomeCoins) on
-- top on the first visit. Opened by the server (ClubNotify "Attendance",
-- EconomyService.claimStreak); it closes with its × only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local notify = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubNotify") :: RemoteEvent
local COIN = require(script.Parent:WaitForChild("Icons")).coin
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local player = Players.LocalPlayer

local PINK = Color3.fromRGB(255, 92, 160)
local GOLD = Color3.fromRGB(255, 196, 64)
local STAMP = Color3.fromRGB(230, 40, 70)

local function create(className: string, props: {[string]: any}): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	return instance
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local gui = create("ScreenGui", {
	Name = "AttendanceGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50, -- (over the first-visit tour, 45)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})
create("Frame", {
	Name = "Shade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Active = true, -- (taps on the shade do nothing: the × closes it)
	Parent = gui,
})

-- a stamp: a red ring with 출석, tilted
local function stamp(parent: Instance): Frame
	local ring = create("Frame", {
		Name = "Stamp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.92),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = Color3.fromRGB(255, 250, 252),
		BackgroundTransparency = 0.08,
		Rotation = -15,
		ZIndex = 5,
		Parent = parent,
	})
	corner(ring, 999)
	create("UIStroke", { Color = STAMP, Thickness = 3, Transparency = 0.05, Parent = ring })
	local word = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "출석",
		TextColor3 = STAMP,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		ZIndex = 6,
		Parent = ring,
	})
	create("UIPadding", { PaddingLeft = UDim.new(0.1, 0), PaddingRight = UDim.new(0.1, 0), PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.22, 0), Parent = word })
	return ring
end

local current: Frame? = nil

local function show(data: any)
	if typeof(data) ~= "table" or typeof(data.coins) ~= "table" then return end
	local coins = data.coins :: {number}
	local day = math.clamp(tonumber(data.day) or 1, 1, #coins)
	local welcome = tonumber(data.welcome)
	if current then current:Destroy() end

	local panel = create("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, if welcome then 0.82 else 0.68),
		BackgroundColor3 = Color3.fromRGB(255, 248, 251),
		Parent = gui,
	})
	current = panel
	corner(panel, 18)
	create("UISizeConstraint", { MaxSize = Vector2.new(600, if welcome then 340 else 270), Parent = panel })
	create("UIStroke", { Color = PINK, Thickness = 3, Parent = panel })
	local scale = create("UIScale", { Scale = 0.6, Parent = panel })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(90, 80, 100),
		Text = "×",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 24,
		Font = Enum.Font.GothamBold,
		ZIndex = 8,
		Parent = panel,
	})
	corner(close, 999)
	close.Activated:Connect(function()
		Sfx.play("click")
		gui.Enabled = false
		panel:Destroy()
		if current == panel then current = nil end
	end)

	local list = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -28, 1, -24), Position = UDim2.fromOffset(14, 12), Parent = panel })
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })

	-- the opening gift, on top
	if welcome then
		local gift = create("Frame", {
			Name = "Welcome",
			Size = UDim2.new(1, -44, 0.2, 0),
			BackgroundColor3 = PINK,
			LayoutOrder = 1,
			Parent = list,
		})
		corner(gift, 12)
		create("UIGradient", { Color = ColorSequence.new(PINK, Color3.fromRGB(255, 150, 90)), Parent = gift })
		create("TextLabel", {
			Size = UDim2.new(0.58, 0, 0.8, 0),
			Position = UDim2.fromScale(0.04, 0.1),
			BackgroundTransparency = 1,
			Text = "🎉 첫 접속 기념 선물",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = gift,
		})
		create("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.66, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			Image = COIN,
			Parent = gift,
		})
		create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.97, 0.12),
			Size = UDim2.fromScale(0.2, 0.76),
			BackgroundTransparency = 1,
			Text = "+" .. tostring(welcome),
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = gift,
		})
	end

	create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -44, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = string.format("📅 출석 체크 · %d일째", day),
		TextColor3 = Color3.fromRGB(60, 40, 60),
		TextSize = 20,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = 2,
		Parent = list,
	})
	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = string.format("매일 접속하면 도장을 찍어 드려요. 하루라도 빠지면 1일째부터! · %d일째 %d 코인", #coins, coins[#coins]),
		TextColor3 = Color3.fromRGB(130, 110, 130),
		TextScaled = true,
		Font = Enum.Font.GothamMedium,
		LayoutOrder = 3,
		Parent = list,
	})

	-- the 7 slots
	local row = create("Frame", {
		Name = "Days",
		Size = UDim2.new(1, 0, if welcome then 0.44 else 0.56, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = list,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.012, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local todaySlot: Frame? = nil
	for i, amount in ipairs(coins) do
		local last = i == #coins
		local done = i < day or (i == day and not data.fresh)
		local slot = create("Frame", {
			Name = "Day" .. i,
			Size = UDim2.fromScale(0.13, 1),
			BackgroundColor3 = if last then Color3.fromRGB(255, 236, 190) elseif i <= day then Color3.fromRGB(255, 226, 238) else Color3.fromRGB(240, 236, 242),
			LayoutOrder = i,
			Parent = row,
		})
		corner(slot, 10)
		create("UIStroke", { Color = if last then GOLD elseif i == day then PINK else Color3.fromRGB(220, 210, 222), Thickness = if i == day then 3 else 1.5, Parent = slot })
		create("TextLabel", {
			Size = UDim2.fromScale(1, 0.22),
			Position = UDim2.fromScale(0, 0.04),
			BackgroundTransparency = 1,
			Text = i .. "일",
			TextColor3 = Color3.fromRGB(90, 70, 90),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			Parent = slot,
		})
		create("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(if last then 0.72 else 0.58, if last then 0.72 else 0.58),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundTransparency = 1,
			Image = COIN,
			ImageTransparency = if i > day then 0.35 else 0,
			Parent = slot,
		})
		create("TextLabel", {
			Size = UDim2.fromScale(1, 0.22),
			Position = UDim2.fromScale(0, 0.76),
			BackgroundTransparency = 1,
			Text = tostring(amount),
			TextColor3 = if last then Color3.fromRGB(190, 120, 0) else Color3.fromRGB(90, 70, 90),
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			Parent = slot,
		})
		if done then stamp(slot) end
		if i == day then todaySlot = slot end
	end

	create("TextLabel", {
		Name = "Today",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = if data.fresh then string.format("오늘 +%d 코인 받았어요!", coins[day]) else "오늘 출석 도장은 이미 받았어요.",
		TextColor3 = PINK,
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = 5,
		Parent = list,
	})

	gui.Enabled = true

	-- today's stamp lands: big and faint → its place, then the slot bounces
	if data.fresh and todaySlot then
		task.delay(0.7, function()
			if not todaySlot.Parent then return end
			local ring = stamp(todaySlot)
			ring.Size = UDim2.fromScale(2.4, 2.4)
			ring.Rotation = -45
			ring.BackgroundTransparency = 1
			local stroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
			local word = ring:FindFirstChildOfClass("TextLabel") :: TextLabel
			stroke.Transparency = 1
			word.TextTransparency = 1
			local info = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(ring, info, { Size = UDim2.fromScale(0.92, 0.92), Rotation = -15, BackgroundTransparency = 0.08 }):Play()
			TweenService:Create(stroke, info, { Transparency = 0.05 }):Play()
			TweenService:Create(word, info, { TextTransparency = 0 }):Play()
			task.wait(0.28)
			Sfx.play("success")
			local bump = create("UIScale", { Parent = todaySlot })
			local up = TweenService:Create(bump, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.9 })
			up:Play()
			up.Completed:Wait()
			TweenService:Create(bump, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end
end

notify.OnClientEvent:Connect(function(kind: any, value: any)
	if kind == "Attendance" then show(value) end
end)

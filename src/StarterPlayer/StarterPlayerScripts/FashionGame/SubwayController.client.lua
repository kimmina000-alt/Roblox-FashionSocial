--!strict
-- Subway exit / bus stop picker (SubwayService): "몇 번 출구로 가시겠습니까?"
-- or "어느 정류장으로 가시겠습니까?" with one button per pad of that network
-- (parts tagged SubwayExit / BusStop). Closes on X or when the player walks
-- away from the pad.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")
local remote = Remotes:WaitForChild("Subway") :: RemoteFunction
local notify = Remotes:WaitForChild("SubwayNotify") :: RemoteEvent

local player = Players.LocalPlayer

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function round(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local gui = make("ScreenGui", { Name = "SubwayGui", ResetOnSpawn = false, DisplayOrder = 40 }, player:WaitForChild("PlayerGui"))
local panel = make("Frame", {
	Name = "Picker",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(300, 260),
	BackgroundColor3 = Color3.fromRGB(245, 250, 245),
	Visible = false,
}, gui)
round(panel, 16)
make("UIStroke", { Color = Color3.fromRGB(46, 125, 50), Thickness = 2 }, panel)
local heading = make("TextLabel", {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -60, 0, 32),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(30, 70, 35),
	Text = "몇 번 출구로 가시겠습니까?",
}, panel)
local close = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = Color3.fromRGB(225, 235, 225),
	Text = "X", -- ✕ is not in the Roblox font
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(60, 80, 60),
}, panel)
round(close, 16)
local list = make("Frame", {
	Position = UDim2.fromOffset(12, 50),
	Size = UDim2.new(1, -24, 1, -88),
	BackgroundTransparency = 1,
}, panel)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local status = make("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -6),
	Size = UDim2.new(1, -28, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(90, 110, 90),
	Text = "",
}, panel)

local openedAt: Vector3? = nil

local function hide()
	panel.Visible = false
	openedAt = nil
end
close.MouseButton1Click:Connect(hide)

local function exits(tag: string): {{ number: number, name: string, color: Color3 }}
	local found = {}
	for _, pad in ipairs(CollectionService:GetTagged(tag)) do
		local number = pad:GetAttribute("ExitNumber")
		if pad:IsA("BasePart") and typeof(number) == "number" then
			table.insert(found, { number = number, name = tostring(pad:GetAttribute("ExitName") or ""), color = pad.Color })
		end
	end
	table.sort(found, function(a, b) return a.number < b.number end)
	return found
end

local function show(tag: string, current: number)
	local bus = tag == "BusStop"
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	openedAt = if root and root:IsA("BasePart") then root.Position else nil
	heading.Text = if bus then "어느 정류장으로 가시겠습니까?" else "몇 번 출구로 가시겠습니까?"
	status.Text = if bus then "버스로 이동해요." else string.format("지금 %d번 출구예요.", current)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	local all = exits(tag)
	for index, exit in ipairs(all) do
		local here = exit.number == current
		local button = make("TextButton", {
			Name = "Exit_" .. exit.number,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = if here then Color3.fromRGB(220, 225, 220) else Color3.fromRGB(230, 245, 230),
			AutoButtonColor = not here,
			Text = "",
		}, list)
		round(button, 12)
		local badge = make("TextLabel", {
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = exit.color,
			Font = Enum.Font.GothamBlack,
			TextSize = 15,
			TextColor3 = Color3.new(1, 1, 1),
			Text = tostring(exit.number),
		}, button)
		round(badge, 14)
		make("TextLabel", {
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -54, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if here then Color3.fromRGB(140, 150, 140) else Color3.fromRGB(40, 60, 45),
			Text = (if bus then exit.name else string.format("%d번 출구 · %s", exit.number, exit.name)) .. (if here then " (지금 여기)" else ""),
		}, button)
		if not here then
			button.MouseButton1Click:Connect(function()
				status.Text = "이동 중…"
				local ok, message = remote:InvokeServer("Go", tag, exit.number)
				status.Text = if typeof(message) == "string" then message else ""
				if ok then hide() end
			end)
		end
	end
	local height = 96 + #all * 48
	panel.Size = UDim2.fromOffset(300, height)
	-- phones: scale down to fit the screen
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1000, 800)
	local scale = panel:FindFirstChildOfClass("UIScale") or make("UIScale", {}, panel)
	scale.Scale = math.clamp(math.min((vp.Y - 24) / height, (vp.X - 24) / 300), 0.5, 1)
	panel.Visible = true
end

notify.OnClientEvent:Connect(function(kind: any, tag: any, number: any)
	if kind == "Open" and typeof(tag) == "string" and typeof(number) == "number" then show(tag, number) end
end)

-- close when the player walks away from the pad
task.spawn(function()
	while true do
		task.wait(0.5)
		if panel.Visible and openedAt then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or (root.Position - openedAt).Magnitude > 12 then hide() end
		end
	end
end)

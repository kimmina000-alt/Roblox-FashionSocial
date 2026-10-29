--!strict
-- 인생네컷: the host (the person who started the shoot) can send someone out
-- while waiting or during the shooting (user 2026-10-30: a stranger joined
-- and the host does not want them in the photos). A small list at the top of
-- the screen, one "내보내기" per other person; press twice to confirm.
-- PhotoBoothService "Kick" (userId) does the rest.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("PhotoBooth") :: RemoteFunction

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end

local gui = make("ScreenGui", { Name = "BoothKickGui", ResetOnSpawn = false, DisplayOrder = 60 }, player:WaitForChild("PlayerGui"))
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52), -- (under the top bar and the shooting info bar)
	Size = UDim2.fromOffset(250, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(255, 244, 248),
	BackgroundTransparency = 0.08,
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
make("UIStroke", { Color = Color3.fromRGB(240, 150, 185), Thickness = 1.5 }, panel)
make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, panel)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
make("TextLabel", {
	LayoutOrder = 0,
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(150, 60, 95),
	Text = "함께 찍는 사람",
}, panel)

local rows: {[number]: Frame} = {}
local armed: {[number]: number} = {}

local function myBooth(): Model?
	for _, booth in ipairs(CollectionService:GetTagged("PhotoBooth")) do
		local raw = booth:GetAttribute("People")
		if typeof(raw) == "string" then
			local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok and typeof(list) == "table" and table.find(list, player.UserId) then return booth :: Model end
		end
	end
	return nil
end

local function row(userId: number): Frame
	local existing = rows[userId]
	if existing then return existing end
	local other = Players:GetPlayerByUserId(userId)
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = userId }, panel)
	make("TextLabel", {
		Size = UDim2.new(1, -96, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(60, 40, 50),
		Text = if other then other.Name else tostring(userId),
	}, frame)
	local button = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(92, 24),
		BackgroundColor3 = Color3.fromRGB(230, 80, 110),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "내보내기",
	}, frame)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
	button.MouseButton1Click:Connect(function()
		if os.clock() - (armed[userId] or 0) > 3 then
			armed[userId] = os.clock()
			button.Text = "한 번 더 누르기"
			return
		end
		armed[userId] = nil
		button.Text = "내보내는 중…"
		local ok, message = remote:InvokeServer("Kick", userId)
		if not ok then
			button.Text = "내보내기"
			if typeof(message) == "string" then warn("[BoothKick]", message) end
		end
	end)
	rows[userId] = frame
	return frame
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local booth = myBooth()
		local phase = booth and booth:GetAttribute("Phase")
		local others: {[number]: boolean} = {}
		if booth and booth:GetAttribute("Host") == player.UserId and (phase == "waiting" or phase == "shooting") then
			local ok, list = pcall(function() return HttpService:JSONDecode(booth:GetAttribute("People")) end)
			if ok and typeof(list) == "table" then
				for _, id in ipairs(list) do
					if typeof(id) == "number" and id ~= player.UserId then
						others[id] = true
						row(id)
					end
				end
			end
		end
		for id, frame in pairs(rows) do
			if not others[id] then
				frame:Destroy()
				rows[id] = nil
				armed[id] = nil
			elseif os.clock() - (armed[id] or -10) > 3 then
				local button = frame:FindFirstChildWhichIsA("TextButton")
				if button and button.Text == "한 번 더 누르기" then button.Text = "내보내기" end
			end
		end
		panel.Visible = next(others) ~= nil
	end
end)

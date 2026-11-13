--!strict
-- (D-1368, user 2026-11-13: "오후네컷: 사진 다 찍으면 포토월 설명. 남들에게 자랑 가능 기능")
-- After a photo shoot's result window closes, a card explains the photo wall once per
-- player, ever: hold the photo (hotbar / 🎒 bag) and tap a wall inside 오후네컷 (every
-- straight wall there takes photos, PhotoWallController) to stick it where everyone sees
-- it. Seen = the tip "photowall" the server remembers (GuideService "TipSeen", player
-- attribute TipsSeen). It waits while another window is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Popups = require(script.Parent:WaitForChild("Popups"))

local player = Players.LocalPlayer
local KEY = "photowall"

local PhotoWallTip = {}

local function seen(): boolean
	local raw = player:GetAttribute("TipsSeen")
	if typeof(raw) ~= "string" then return false end
	local ok, keys = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and typeof(keys) == "table" and table.find(keys, KEY) ~= nil
end

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end

local showing = false
function PhotoWallTip.maybeShow()
	if showing or seen() then return end
	showing = true
	task.spawn(function()
		-- after the result window and anything it opened (the bag) are closed
		local t0 = os.clock()
		task.wait(0.6)
		while Popups.anyOpen() and os.clock() - t0 < 60 do task.wait(0.5) end
		local gui = create("ScreenGui", { Name = "PhotoWallTipGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 46 },
			player:WaitForChild("PlayerGui"))
		local card = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -40, 0, 210),
			BackgroundColor3 = Color3.fromRGB(255, 240, 246),
		}, gui)
		create("UICorner", { CornerRadius = UDim.new(0, 20) }, card)
		create("UISizeConstraint", { MaxSize = Vector2.new(440, 210) }, card)
		create("UIStroke", { Color = Color3.fromRGB(255, 110, 170), Thickness = 3 }, card)
		create("TextLabel", {
			Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 30), BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.fromRGB(215, 60, 130),
			TextXAlignment = Enum.TextXAlignment.Left, Text = "📌 포토월에 자랑하기",
		}, card)
		local body = create("TextLabel", {
			Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 0, 92), BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.fromRGB(70, 50, 70), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			Text = "방금 찍은 사진을 오후네컷 벽에 붙여 모두에게 자랑할 수 있어요!\n아래 칸이나 🎒 가방에서 사진을 손에 들고, 오후네컷 안의 벽을 누르면 원하는 자리에 붙어요.",
		}, card)
		local ok = create("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(140, 40),
			BackgroundColor3 = Color3.fromRGB(255, 110, 170), Text = "알겠어요!", TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = true,
		}, card)
		create("UICorner", { CornerRadius = UDim.new(0, 14) }, ok)
		local function close()
			if not gui.Parent then return end
			gui:Destroy()
			Popups.closed("PhotoWallTip")
			showing = false
		end
		Popups.opened("PhotoWallTip", close)
		ok.Activated:Connect(close)
		local remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction
		task.spawn(function() pcall(function() remote:InvokeServer("TipSeen", KEY) end) end)
	end)
end

return PhotoWallTip

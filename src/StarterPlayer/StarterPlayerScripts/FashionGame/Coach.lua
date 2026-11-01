--!strict
-- Step-by-step tips with a pulsing outline round what they talk about (user
-- 2026-11-01, D-713). Coach.run(key, steps) shows the steps one card at a
-- time ([건너뛰기] ends them, [다음 ▶]); once finished or skipped the server
-- remembers the key (remote Guide "TipSeen") and it is not shown again.
-- One run at a time: a second waits until the first is over.
--
-- A step: { title, text, target = () -> GuiObject? | Rect?, before = () -> ()?,
-- after = () -> ()? }. The target is looked up when the step shows; a
-- missing or hidden one just shows the card without the outline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction

local Coach = {}

export type Step = { title: string, text: string, target: (() -> any)?, before: (() -> ())?, after: (() -> ())? }

local PEACH = Color3.fromRGB(255, 248, 240)
local ORANGE = Color3.fromRGB(255, 140, 70)
local BROWN = Color3.fromRGB(80, 50, 35)
local GREY = Color3.fromRGB(150, 135, 125)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end

local gui = create("ScreenGui", { Name = "FashionCoachGui", ResetOnSpawn = false, DisplayOrder = 45, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
local ring = create("Frame", { Name = "Ring", BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, gui)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, ring)
local ringStroke = create("UIStroke", { Color = ORANGE, Thickness = 4 }, ring)
local card = create("Frame", {
	Name = "TipCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(1, -32, 0, 150), BackgroundColor3 = PEACH, Visible = false, ZIndex = 3,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, card)
create("UISizeConstraint", { MaxSize = Vector2.new(520, 150) }, card)
create("UIStroke", { Color = ORANGE, Thickness = 2 }, card)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -100, 0, 24), BackgroundTransparency = 1, ZIndex = 4,
	Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = BROWN, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, card)
local count = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(70, 20), ZIndex = 4,
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = GREY,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "",
}, card)
local body = create("TextLabel", {
	Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -32, 0, 56), BackgroundTransparency = 1, ZIndex = 4,
	Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = BROWN, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, card)
local function button(text: string, color: Color3, textColor: Color3): TextButton
	local b = create("TextButton", { BackgroundColor3 = color, Text = text, TextColor3 = textColor, Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 4 }, card)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	return b
end
local skip = button("건너뛰기", Color3.fromRGB(235, 225, 215), BROWN)
skip.AnchorPoint = Vector2.new(0, 1)
skip.Position = UDim2.new(0, 14, 1, -12)
skip.Size = UDim2.new(0.36, -18, 0, 38)
local nextButton = button("다음 ▶", ORANGE, Color3.new(1, 1, 1))
nextButton.AnchorPoint = Vector2.new(1, 1)
nextButton.Position = UDim2.new(1, -14, 1, -12)
nextButton.Size = UDim2.new(0.64, -18, 0, 38)

local function seen(key: string): boolean
	local raw = player:GetAttribute("TipsSeen")
	if typeof(raw) ~= "string" then return true end -- (not loaded yet: wait, don't show)
	local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and typeof(list) == "table" and table.find(list, key) ~= nil
end

-- Whether tips can be shown now (the player's data has loaded) and this one
-- has not been seen.
function Coach.wants(key: string): boolean
	return typeof(player:GetAttribute("TipsSeen")) == "string" and not seen(key)
end

local running: string? = nil
local queue: {{ key: string, steps: {Step} }} = {}
local steps: {Step} = {}
local index = 0
local target: any = nil

local function rectOf(t: any): (Vector2?, Vector2?)
	if typeof(t) == "Rect" then return t.Min, t.Max - t.Min end
	if typeof(t) ~= "Instance" or not t:IsA("GuiObject") or not t.Visible then return nil, nil end
	-- (hidden by a hidden parent too)
	local p: Instance? = t.Parent
	while p and not p:IsA("LayerCollector") do
		if p:IsA("GuiObject") and not p.Visible then return nil, nil end
		p = p.Parent
	end
	local screen = t:FindFirstAncestorOfClass("ScreenGui")
	if not screen or not screen.Enabled then return nil, nil end
	-- (AbsolutePosition leaves out the top bar inset whatever the ScreenGui's
	-- IgnoreGuiInset; this gui ignores it, so it goes back on)
	return t.AbsolutePosition + GuiService:GetGuiInset(), t.AbsoluteSize
end

local finish: (boolean) -> ()

local function show()
	local step = steps[index]
	if not step then finish(true) return end
	if step.before then pcall(step.before) end
	title.Text = step.title
	body.Text = step.text
	count.Text = string.format("%d / %d", index, #steps)
	nextButton.Text = if index == #steps then "확인" else "다음 ▶"
	target = nil
	if step.target then
		local ok, t = pcall(step.target)
		if ok then target = t end
	end
end

finish = function(done: boolean)
	local key = running
	if not key then return end
	local step = steps[index]
	if step and step.after then pcall(step.after) end
	running = nil
	card.Visible = false
	ring.Visible = false
	task.spawn(function() pcall(function() remote:InvokeServer("TipSeen", key) end) end)
	local nextRun = table.remove(queue, 1)
	if nextRun then task.defer(Coach.run, nextRun.key, nextRun.steps) end
end

nextButton.Activated:Connect(function()
	if not running then return end
	local step = steps[index]
	if step and step.after then pcall(step.after) end
	index += 1
	if index > #steps then
		index -= 1
		steps[index] = { title = "", text = "" } -- (its after has run)
		finish(true)
	else
		show()
	end
end)
skip.Activated:Connect(function() finish(false) end)

-- the outline follows its target every frame (windows move, scroll, open)
RunService.RenderStepped:Connect(function()
	if not running then return end
	local position, size = rectOf(target)
	if not position or not size then
		ring.Visible = false
	else
		local pad = 6
		ring.Position = UDim2.fromOffset(position.X - pad, position.Y - pad)
		ring.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
		ring.Visible = true
		ringStroke.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 6))
	end
	-- the card where it hides the least: at the bottom, or on top when the
	-- outline is in the lower part of the screen
	local camera = workspace.CurrentCamera
	local low = position ~= nil and size ~= nil and camera ~= nil and (position.Y + size.Y / 2) > camera.ViewportSize.Y * 0.55
	card.AnchorPoint = if low then Vector2.new(0.5, 0) else Vector2.new(0.5, 1)
	card.Position = if low then UDim2.new(0.5, 0, 0, 64) else UDim2.new(0.5, 0, 1, -16)
end)

function Coach.run(key: string, list: {Step})
	if not Coach.wants(key) then return end
	if running then
		if running ~= key then
			for _, waiting in ipairs(queue) do if waiting.key == key then return end end
			table.insert(queue, { key = key, steps = list })
		end
		return
	end
	running = key
	steps = table.clone(list)
	index = 1
	card.Visible = true
	show()
end

function Coach.isRunning(): boolean
	return running ~= nil
end

-- Every tip again (the guide's 다시 보기).
function Coach.reset()
	pcall(function() remote:InvokeServer("TipsReset") end)
end

return Coach

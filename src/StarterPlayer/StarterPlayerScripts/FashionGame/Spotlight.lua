--!strict
-- The screen goes dark round one button while a tip talks about it (user
-- 2026-11-01, D-714): four dark panels leave a hole over the button, and the
-- button grows a little and back once (a UIScale on it). The tip cards sit
-- in ScreenGuis above this one (the tour's 40, Coach's 45), so they stay lit.
-- Spotlight.set(target) — a GuiObject, a Rect in screen pixels, or nil (off).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Spotlight = {}

local DIM = 0.45 -- the dark panels' transparency
local PAD = 6

local gui = Instance.new("ScreenGui")
gui.Name = "FashionSpotlightGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 39 -- (over the top bar's 5 / 30, under the tip cards)
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local panels: {Frame} = {}
for i = 1, 4 do
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = DIM
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = gui
	panels[i] = f
end

-- Where a target is on the screen (pixels, top bar included), or nil when it
-- is not shown.
function Spotlight.rectOf(t: any): (Vector2?, Vector2?)
	if typeof(t) == "Rect" then return t.Min, t.Max - t.Min end
	if typeof(t) ~= "Instance" or not t:IsA("GuiObject") or not t.Visible then return nil, nil end
	local p: Instance? = t.Parent
	while p and not p:IsA("LayerCollector") do
		if p:IsA("GuiObject") and not p.Visible then return nil, nil end
		p = p.Parent
	end
	local screen = t:FindFirstAncestorOfClass("ScreenGui")
	if not screen or not screen.Enabled then return nil, nil end
	-- (AbsolutePosition leaves out the top bar inset whatever the ScreenGui's
	-- IgnoreGuiInset; these guis ignore it, so it goes back on)
	return t.AbsolutePosition + GuiService:GetGuiInset(), t.AbsoluteSize
end

local target: any = nil
local scale: UIScale? = nil

local function dropScale()
	if scale then scale:Destroy() scale = nil end
end

function Spotlight.set(t: any)
	if t == target then return end
	dropScale()
	target = t
	if typeof(t) == "Instance" and t:IsA("GuiObject") then
		-- grow a little and back, once
		local s = Instance.new("UIScale")
		s.Name = "SpotlightPulse"
		s.Parent = t
		scale = s
		local up = TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.3 })
		local down = TweenService:Create(s, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		up.Completed:Connect(function() if scale == s then down:Play() end end)
		down.Completed:Connect(function() if scale == s then dropScale() end end)
		task.delay(0.15, function() if scale == s then up:Play() end end)
	end
end

RunService.RenderStepped:Connect(function()
	local position, size = Spotlight.rectOf(target)
	local camera = workspace.CurrentCamera
	if not position or not size or not camera then
		for _, f in ipairs(panels) do f.Visible = false end
		return
	end
	local w, h = camera.ViewportSize.X, camera.ViewportSize.Y
	local x0, y0 = math.max(position.X - PAD, 0), math.max(position.Y - PAD, 0)
	local x1, y1 = math.min(position.X + size.X + PAD, w), math.min(position.Y + size.Y + PAD, h)
	-- above, below, left, right of the hole
	local rects = {
		{ 0, 0, w, y0 },
		{ 0, y1, w, h - y1 },
		{ 0, y0, x0, y1 - y0 },
		{ x1, y0, w - x1, y1 - y0 },
	}
	for i, r in ipairs(rects) do
		local f = panels[i]
		f.Position = UDim2.fromOffset(r[1], r[2])
		f.Size = UDim2.fromOffset(math.max(r[3], 0), math.max(r[4], 0))
		f.Visible = true
	end
end)

return Spotlight

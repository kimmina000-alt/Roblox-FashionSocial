--!strict
-- The screen goes dark round one button while a tip talks about it (user
-- 2026-11-01, D-714): four dark panels leave a hole over the button, and the
-- button grows (a UIScale on it) and shrinks back when the tip moves on. The tip cards sit
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

-- (D-718) one frame over the hole whose huge black outer stroke darkens all
-- the rest: four panels left a lighter band at the top on the user's screen
local hole = Instance.new("Frame")
hole.Name = "Hole"
hole.BackgroundTransparency = 1
hole.Visible = false
hole.Parent = gui
do
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = DIM
	stroke.Thickness = 4000
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	pcall(function() (stroke :: any).BorderStrokePosition = Enum.BorderStrokePosition.Outer end)
	stroke.Parent = hole
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

-- (D-715, user: the button stays big while it is talked about and shrinks
-- back when the tip moves on)
local function dropScale()
	local s = scale
	scale = nil
	if not s then return end
	local down = TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	down.Completed:Connect(function() s:Destroy() end)
	down:Play()
end

function Spotlight.set(t: any)
	if t == target then return end
	dropScale()
	target = t
	if typeof(t) == "Instance" and t:IsA("GuiObject") then
		-- grows and stays grown
		local s = Instance.new("UIScale")
		s.Name = "SpotlightPulse"
		s.Parent = t
		scale = s
		TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.3 }):Play()
	end
end

RunService.RenderStepped:Connect(function()
	local position, size = Spotlight.rectOf(target)
	local camera = workspace.CurrentCamera
	if not position or not size or not camera then
		hole.Visible = false
		return
	end
	hole.Position = UDim2.fromOffset(position.X - PAD, position.Y - PAD)
	hole.Size = UDim2.fromOffset(size.X + PAD * 2, size.Y + PAD * 2)
	hole.Visible = true
end)

return Spotlight

--!strict
-- Club LED wall visuals, drawn live with GUI frames (sharp at any size,
-- follow the music, no uploaded video). Two shows take turns every
-- SHOW_SECONDS with a short fade:
--   1  NEON EQ   mirrored neon equalizer from the middle line, glowing caps
--   2  BARS      the wall's first look: plain bars rising from the bottom
-- (user 2026-10-30, later: the laser and strobe shows were too much — "토할
-- 것 같다" — only these two stay)
-- LEDVisuals.new(parent, z) → object with :update(t, loud, colours) and :setVisible(bool)
-- (t = seconds, loud = 0..1 music level, colours = {c1, c2, c3})

local LEDVisuals = {}
LEDVisuals.__index = LEDVisuals

local SHOW_SECONDS = 12
local FADE = 1.2
local EQ_BARS = 28
local BARS = 24

local function frame(parent: Instance, props: {[string]: any}): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

local function glow(f: GuiObject, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return s
end

-- single: the neon EQ only, no turns (the small screen on the DJ desk)
function LEDVisuals.new(parent: Instance, z: number, single: boolean?)
	local self = setmetatable({}, LEDVisuals) :: any
	self.single = single == true
	-- (the low desk screen: taller bars from a lower middle line)
	self.mid = if self.single then 0.72 else 0.62
	self.boost = if self.single then 1.6 else 1
	local root = frame(parent, { Name = "LEDVisuals", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = z })
	self.root = root
	-- 1 NEON EQ
	local eq = frame(root, { Name = "EQ", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z })
	self.eq = eq
	self.eqBars = {}
	for i = 1, EQ_BARS do
		local up = frame(eq, { AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 1 })
		local down = frame(eq, { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, ZIndex = z + 1 })
		local cap = frame(eq, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 2 })
		Instance.new("UICorner", up).CornerRadius = UDim.new(0, 3)
		Instance.new("UICorner", down).CornerRadius = UDim.new(0, 3)
		self.eqBars[i] = { up = up, down = down, cap = cap, stroke = glow(up, Color3.new(1, 1, 1), 3), peak = 0 }
	end
	self.eqLine = frame(eq, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, self.mid), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 2 })
	-- 2 BARS (the first look of the wall)
	local plain = frame(root, { Name = "Bars", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z })
	self.plain = plain
	self.bars = {}
	for i = 1, BARS do
		self.bars[i] = frame(plain, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new((i - 1) / BARS + 0.004, 0, 1, 0),
			Size = UDim2.new(1 / BARS - 0.008, 0, 0.2, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.25,
			ZIndex = z + 1,
		})
	end
	return self
end

function LEDVisuals:setVisible(on: boolean)
	self.root.Visible = on
end

-- how much of each show is on (0..1) at time t
local function weights(t: number): (number, number)
	local cycle = t % (SHOW_SECONDS * 2)
	local first = cycle < SHOW_SECONDS
	local into = if first then cycle else cycle - SHOW_SECONDS
	local k = if into > SHOW_SECONDS - FADE then (into - (SHOW_SECONDS - FADE)) / FADE else 0
	if first then return 1 - k, k end
	return k, 1 - k
end

function LEDVisuals:update(t: number, loud: number, colours: {Color3})
	local c1, c2, c3 = colours[1], colours[2], colours[3]
	local w1, w2 = weights(t)
	if self.single then w1, w2 = 1, 0 end
	self.eq.Visible, self.plain.Visible = w1 > 0, w2 > 0
	-- 1 NEON EQ
	if w1 > 0 then
		local fade = 1 - w1
		for i, b in ipairs(self.eqBars) do
			local x = (i - 0.5) / EQ_BARS
			local mid = 1 - math.abs(x - 0.5) * 1.4 -- taller in the middle
			local wave = 0.5 + 0.5 * math.sin(t * 7 + i * 0.55) * math.sin(t * 2.1 + i * 0.23)
			local h = math.clamp((0.08 + (0.25 + 0.6 * loud) * wave) * mid * self.boost, 0.03, self.mid - 0.04)
			b.peak = math.max(h, b.peak - 0.006)
			local col = c1:Lerp(c2, x):Lerp(c3, math.max(0, h - 0.3))
			b.up.Position = UDim2.fromScale(x, self.mid)
			b.up.Size = UDim2.new(0.7 / EQ_BARS, 0, h, 0)
			b.down.Position = UDim2.fromScale(x, self.mid)
			b.down.Size = UDim2.new(0.7 / EQ_BARS, 0, math.min(h * 0.45, 0.98 - self.mid), 0)
			b.cap.Position = UDim2.fromScale(x, self.mid - b.peak - 0.02)
			b.cap.Size = UDim2.new(0.7 / EQ_BARS, 0, 0.012, 0)
			b.up.BackgroundColor3, b.down.BackgroundColor3, b.cap.BackgroundColor3, b.stroke.Color = col, col, Color3.new(1, 1, 1), col
			b.up.BackgroundTransparency = fade
			b.down.BackgroundTransparency = 0.55 + 0.45 * fade
			b.cap.BackgroundTransparency = fade
			b.stroke.Transparency = 0.35 + 0.65 * fade
		end
		self.eqLine.BackgroundColor3 = c2
		self.eqLine.BackgroundTransparency = 0.2 + 0.8 * fade
	end
	-- 2 BARS
	if w2 > 0 then
		local fade = 1 - w2
		for i, bar in ipairs(self.bars) do
			local wave = 0.5 + 0.5 * math.sin(t * 6 + i * 0.7)
			local h = 0.06 + (0.15 + 0.55 * loud) * wave * (0.6 + 0.4 * math.sin(t * 2.3 + i))
			bar.Size = UDim2.new(1 / BARS - 0.008, 0, math.max(h, 0.04), 0)
			bar.BackgroundColor3 = c3
			bar.BackgroundTransparency = 0.25 + 0.75 * fade
		end
	end
end

return LEDVisuals

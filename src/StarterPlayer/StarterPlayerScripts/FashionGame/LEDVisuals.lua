--!strict
-- Club LED wall visuals (user 2026-10-30: "flashy electronic videos, neon,
-- equalizer, lasers, flashing — about three"). Drawn live with GUI frames, so
-- they are sharp at any size, follow the music and need no uploaded video.
-- Three shows take turns every SHOW_SECONDS with a short fade:
--   1  NEON EQ     mirrored neon equalizer from the middle line, glowing caps
--   2  LASERS      laser fans from the bottom corners and the top, sweeping
--   3  STROBE      neon frames rushing out of the middle, white flashes on the beat
-- LEDVisuals.new(parent) → object with :update(t, loud, colours) and :setVisible(bool)
-- (t = seconds, loud = 0..1 music level, colours = {c1, c2, c3})

local LEDVisuals = {}
LEDVisuals.__index = LEDVisuals

local SHOW_SECONDS = 12 -- (was 20; user 2026-10-30: take turns more often)
local FADE = 1.2
local EQ_BARS = 28
local LASERS = 14
local FRAMES = 7

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

function LEDVisuals.new(parent: Instance, z: number)
	local self = setmetatable({}, LEDVisuals) :: any
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
	self.eqLine = frame(eq, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.62), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 2 })
	-- 2 LASERS (thin long frames turned about their bottom end)
	local lz = frame(root, { Name = "Lasers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z })
	self.lz = lz
	self.lasers = {}
	for i = 1, LASERS do
		local holder = frame(lz, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, ZIndex = z + 1 })
		local beam = frame(holder, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 1 })
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 0) })
		g.Parent = beam
		self.lasers[i] = { holder = holder, beam = beam, stroke = glow(beam, Color3.new(1, 1, 1), 2) }
	end
	self.haze = frame(lz, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, ZIndex = z })
	-- 3 STROBE (neon frames rushing out of the middle + flashes)
	local st = frame(root, { Name = "Strobe", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z })
	self.st = st
	self.rings = {}
	for i = 1, FRAMES do
		local r = frame(st, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = z + 1 })
		Instance.new("UICorner", r).CornerRadius = UDim.new(0.08, 0)
		self.rings[i] = { f = r, stroke = glow(r, Color3.new(1, 1, 1), 5) }
		self.rings[i].stroke.Transparency = 0
	end
	self.flash = frame(st, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = z + 3 })
	self.lastBeat = 0
	return self
end

function LEDVisuals:setVisible(on: boolean)
	self.root.Visible = on
end

-- how much of each show is on (0..1) at time t
local function weights(t: number): (number, number, number)
	local cycle = t % (SHOW_SECONDS * 3)
	local w = { 0, 0, 0 }
	local i = math.floor(cycle / SHOW_SECONDS) + 1
	local into = cycle - (i - 1) * SHOW_SECONDS
	w[i] = 1
	if into > SHOW_SECONDS - FADE then
		local k = (into - (SHOW_SECONDS - FADE)) / FADE
		w[i] = 1 - k
		w[i % 3 + 1] = k
	end
	return w[1], w[2], w[3]
end

function LEDVisuals:update(t: number, loud: number, colours: {Color3})
	local c1, c2, c3 = colours[1], colours[2], colours[3]
	local w1, w2, w3 = weights(t)
	self.eq.Visible, self.lz.Visible, self.st.Visible = w1 > 0, w2 > 0, w3 > 0
	-- 1 NEON EQ
	if w1 > 0 then
		local fade = 1 - w1
		for i, b in ipairs(self.eqBars) do
			local x = (i - 0.5) / EQ_BARS
			local mid = 1 - math.abs(x - 0.5) * 1.4 -- taller in the middle
			local wave = 0.5 + 0.5 * math.sin(t * 7 + i * 0.55) * math.sin(t * 2.1 + i * 0.23)
			local h = math.clamp((0.08 + (0.25 + 0.6 * loud) * wave) * mid, 0.03, 0.58)
			b.peak = math.max(h, b.peak - 0.006)
			local col = c1:Lerp(c2, x):Lerp(c3, math.max(0, h - 0.3))
			b.up.Position = UDim2.fromScale(x, 0.62)
			b.up.Size = UDim2.new(0.7 / EQ_BARS, 0, h, 0)
			b.down.Position = UDim2.fromScale(x, 0.62)
			b.down.Size = UDim2.new(0.7 / EQ_BARS, 0, h * 0.45, 0)
			b.cap.Position = UDim2.fromScale(x, 0.62 - b.peak - 0.02)
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
	-- 2 LASERS: three fans (bottom left, bottom right, top middle)
	if w2 > 0 then
		local fade = 1 - w2
		local origins = { Vector2.new(0.04, 1.02), Vector2.new(0.96, 1.02), Vector2.new(0.5, -0.02) }
		local abs = self.lz.AbsoluteSize
		local len = math.max(abs.X, abs.Y) * 1.3
		for i, l in ipairs(self.lasers) do
			local o = origins[(i - 1) % 3 + 1]
			local k = math.floor((i - 1) / 3)
			local base = if o.Y < 0 then 180 elseif o.X < 0.5 then 30 else -30
			local sweep = math.sin(t * (1.3 + loud) + k * 0.9 + (if o.X < 0.5 then 0 else 2)) * 40
			local ang = base + sweep + (k - 2) * 9
			l.holder.Position = UDim2.fromScale(o.X, o.Y)
			l.holder.Rotation = ang
			l.beam.Size = UDim2.new(0, 3 + 3 * loud, 0, len)
			local col = ({ c1, c2, c3 })[(i - 1) % 3 + 1]
			l.beam.BackgroundColor3, l.stroke.Color = col, col
			-- (a beat makes them blink)
			local blink = if math.sin(t * 9 + i) > 0.85 - loud * 0.3 then 0.6 else 0
			l.beam.BackgroundTransparency = math.clamp(fade + blink, 0, 1)
			l.stroke.Transparency = math.clamp(0.4 + fade + blink, 0, 1)
		end
		self.haze.BackgroundColor3 = c2
		self.haze.BackgroundTransparency = 0.9 + 0.1 * fade
	end
	-- 3 STROBE: frames rushing out, white flashes on the beat
	if w3 > 0 then
		local fade = 1 - w3
		for i, r in ipairs(self.rings) do
			local p = ((t * (0.45 + 0.4 * loud)) + (i - 1) / FRAMES) % 1
			local s = 0.05 + p * 1.3
			r.f.Size = UDim2.fromScale(s * 1.2, s)
			r.f.Rotation = math.sin(t * 0.7 + i) * 6
			local col = ({ c1, c2, c3 })[(i - 1) % 3 + 1]
			r.stroke.Color = col
			r.stroke.Thickness = 2 + 8 * p
			r.stroke.Transparency = math.clamp(p * p + fade, 0, 1)
		end
		-- a flash about twice a second, harder when the music is loud
		local beat = math.floor(t * (2 + 2 * loud))
		if beat ~= self.lastBeat then
			self.lastBeat = beat
			self.flashAt = t
		end
		local since = t - (self.flashAt or -10)
		local strength = math.max(0, 1 - since * 6) * (0.35 + 0.4 * loud)
		self.flash.BackgroundColor3 = if beat % 4 == 0 then Color3.new(1, 1, 1) else c3
		self.flash.BackgroundTransparency = math.clamp(1 - strength * w3, 0, 1)
	end
end

return LEDVisuals

--!strict
-- (D-1140, user 2026-11-10, a screenshot zoomed far out over the beach: "화면 멀리
-- 키우면 바다에 저런 거 보임 확인 후 삭제하거나 정돈") the far sea is flat parts
-- (Hongdae_Layout.OpenSea.SeaSurface) just under the terrain water; near the
-- player the terrain water lies over them, further out (where the terrain has
-- not streamed in) they show. The terrain water looks very different by the
-- hour, so with one colour the edge between them showed as a rectangle with
-- notched sides. This tints the parts on this screen by the clock so they
-- look like the water at that hour. Measured in Play (2026-11-10, the camera
-- high over the beach): the water renders (6, 61, 86) at 0:00, (21, 42, 74) at
-- 6:00, (72, 183, 221) at 12:00, (14, 64, 80) at 18:00; the colours below make
-- the parts render about the same next to it (a second round of measuring;
-- at dusk the parts cannot get quite as bright as the water). Further out (the bands' order)
-- a little darker, as before.

local Lighting = game:GetService("Lighting")

-- hour → part colour
local KEYS: {{number}} = {
	{ 0, 37, 212, 220 },
	{ 5, 37, 180, 205 },
	{ 6, 15, 85, 159 },
	{ 12, 18, 102, 164 },
	{ 17, 20, 115, 175 },
	{ 18, 49, 255, 255 },
	{ 24, 37, 212, 220 },
}
local FAR = 0.78 -- the outermost band's share of the colour

local function tintAt(hour: number): Color3
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if hour >= a[1] and hour <= b[1] then
			local t = (hour - a[1]) / math.max(b[1] - a[1], 0.001)
			return Color3.fromRGB(a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t)
		end
	end
	return Color3.fromRGB(23, 93, 160)
end

-- the bands, nearest the shore first
local bands: {{ part: BasePart, f: number }} = {}
local function collect(): boolean
	local layout = workspace:FindFirstChild("Hongdae_Layout")
	local sea = layout and layout:FindFirstChild("OpenSea")
	if not sea then return false end
	local xs: {number} = {}
	local parts: {BasePart} = {}
	for _, p in ipairs(sea:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "SeaSurface" then table.insert(parts, p) end
	end
	if #parts == 0 then return false end
	local lo, hi = math.huge, -math.huge
	for _, p in ipairs(parts) do
		lo = math.min(lo, p.Position.X)
		hi = math.max(hi, p.Position.X)
		table.insert(xs, p.Position.X)
	end
	table.clear(bands)
	for _, p in ipairs(parts) do
		-- the shore is at the high x (-270), the horizon at the low x
		local k = if hi > lo then (hi - p.Position.X) / (hi - lo) else 0
		table.insert(bands, { part = p, f = 1 - (1 - FAR) * (k ^ 0.8) })
	end
	return true
end

task.spawn(function()
	while not collect() do task.wait(5) end
	local last = -1
	while true do
		local hour = Lighting.ClockTime
		if math.abs(hour - last) > 0.05 then
			last = hour
			local c = tintAt(hour)
			for _, b in ipairs(bands) do
				if b.part.Parent then b.part.Color = Color3.new(c.R * b.f, c.G * b.f, c.B * b.f) end
			end
		end
		task.wait(1)
	end
end)

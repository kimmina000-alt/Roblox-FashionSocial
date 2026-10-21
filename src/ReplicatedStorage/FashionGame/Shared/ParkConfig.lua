--!strict
-- PARK rides (user, 2026-10-22; docs/02_WORLDS/PARK.md): ferris wheel,
-- carousel, swings, spring riders, slide.
--
-- Rides move on every client from the shared server clock
-- (workspace:GetServerTimeNow), so nothing moving is replicated and every
-- client sees the same wheel/carousel angle. The server only keeps who sits
-- where (attributes on the ride parts) and checks boarding.
--
-- Map (tools/graybox 06_Park_Playground), all Models:
--   tag "ParkWheel"     attributes Period, Radius; children "Hub" (Part),
--                       "Rotor" (Model), "Cabin1".."CabinN" (Model, pivot =
--                       hang point), "BoardPoint" (Part on the platform).
--                       Cabin attributes Rider1, Rider2 (userId).
--   tag "ParkCarousel"  attributes Period, Radius, Bob; "Center" (Part),
--                       "Rotor" (Model), "Horse1".."HorseN" (Model, pivot =
--                       saddle top). Horse attribute Rider.
--   tag "ParkSwing"     attributes Length; "Pivot" (Part), "SwingSeat"
--                       (Model, pivot = Pivot). Attributes Rider, Level.
--   tag "ParkSpring"    "Rocker" (Model, pivot = spring top). Attribute Rider.
--   tag "ParkSlide"     attributes P0, P1, P2 (Vector3, path); "SlideStart"
--                       (Part, trigger box at the top).

local ParkConfig = {}

-- Ferris wheel: one turn in Period seconds; a cabin can be boarded or left
-- while it is within BoardAngle of the bottom.
ParkConfig.WheelBoardAngle = math.rad(9)
ParkConfig.CabinSeats = {
	-- seat surface relative to the hang point; riders face the cabin centre
	{ offset = Vector3.new(1.6, -4.9, 0), facing = Vector3.new(-1, 0, 0) },
	{ offset = Vector3.new(-1.6, -4.9, 0), facing = Vector3.new(1, 0, 0) },
}
ParkConfig.BoardDistance = 12

-- Swing speed levels (+/-): amplitude per level. Level 0 = just sitting.
-- Max 5 × 7° = 35°, with a 3.2 s period: smooth, no motion sickness.
ParkConfig.SwingLevels = 5
ParkConfig.SwingDegreesPerLevel = 7
ParkConfig.SwingPeriod = 3.2
ParkConfig.SwingStartLevel = 1

ParkConfig.SpringAngle = math.rad(11)
ParkConfig.SpringPeriod = 1.1

ParkConfig.SlideSeconds = 1.5
-- Cartoon Slide Whistle #1 (Creator Store, free). The "야호!" itself is a
-- speech bubble; replace with a licensed voice clip when one is chosen.
ParkConfig.SlideSoundId = 95716072659114

local function attr(model: Instance, name: string, default: number): number
	local value = model:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function partCFrame(model: Instance, name: string): CFrame?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part.CFrame else nil
end

--------------------------------------------------
-- Ferris wheel
--------------------------------------------------

-- Angles are kept in 0..2π: the server clock is ~1.8e9 s, and a huge angle
-- in CFrame.Angles (single precision) froze the rides.
function ParkConfig.wheelAngle(model: Instance, t: number): number
	return ((t / attr(model, "Period", 150)) % 1) * 2 * math.pi
end

function ParkConfig.cabinCount(model: Instance): number
	local count = 0
	while model:FindFirstChild("Cabin" .. (count + 1)) do count += 1 end
	return count
end

-- Angle of cabin i from the bottom (0 = at the bottom).
function ParkConfig.cabinAngle(model: Instance, index: number, t: number): number
	local count = math.max(ParkConfig.cabinCount(model), 1)
	return (ParkConfig.wheelAngle(model, t) + (index - 1) * 2 * math.pi / count) % (2 * math.pi)
end

-- Upright CFrame of cabin i's hang point.
function ParkConfig.cabinCFrame(model: Instance, index: number, t: number): CFrame?
	local hub = partCFrame(model, "Hub")
	if not hub then return nil end
	local radius = attr(model, "Radius", 26)
	local point = (hub * CFrame.Angles(ParkConfig.cabinAngle(model, index, t), 0, 0) * CFrame.new(0, -radius, 0)).Position
	return hub.Rotation + point
end

-- How far (radians) cabin i is from the bottom.
function ParkConfig.cabinFromBottom(model: Instance, index: number, t: number): number
	local a = ParkConfig.cabinAngle(model, index, t) % (2 * math.pi)
	return math.min(a, 2 * math.pi - a)
end

-- The cabin at the bottom now (within WheelBoardAngle), or nil; and the
-- seconds until the next cabin reaches the bottom window.
function ParkConfig.cabinAtBottom(model: Instance, t: number): (number?, number)
	local count = ParkConfig.cabinCount(model)
	local best, bestGap = nil, math.huge
	for index = 1, count do
		local gap = ParkConfig.cabinFromBottom(model, index, t)
		if gap < bestGap then best, bestGap = index, gap end
	end
	if best and bestGap <= ParkConfig.WheelBoardAngle then return best, 0 end
	-- next arrival: the cabin just before the bottom
	local speed = 2 * math.pi / attr(model, "Period", 150)
	local wait = math.huge
	for index = 1, count do
		local a = ParkConfig.cabinAngle(model, index, t) % (2 * math.pi)
		local toWindow = (2 * math.pi - ParkConfig.WheelBoardAngle) - a
		if toWindow < 0 then toWindow += 2 * math.pi end
		wait = math.min(wait, toWindow / speed)
	end
	return nil, wait
end

--------------------------------------------------
-- Carousel
--------------------------------------------------

function ParkConfig.carouselAngle(model: Instance, t: number): number
	return ((t / attr(model, "Period", 30)) % 1) * 2 * math.pi
end

function ParkConfig.horseCount(model: Instance): number
	local count = 0
	while model:FindFirstChild("Horse" .. (count + 1)) do count += 1 end
	return count
end

-- Saddle-top CFrame of horse k (facing the way it moves).
function ParkConfig.horseCFrame(model: Instance, index: number, t: number): CFrame?
	local center = partCFrame(model, "Center")
	if not center then return nil end
	local count = math.max(ParkConfig.horseCount(model), 1)
	local radius = attr(model, "Radius", 11)
	local saddle = attr(model, "SaddleY", 4)
	local bob = attr(model, "Bob", 0.8) * math.sin((t % 1000) * 1.6 + index * 1.7)
	local theta = (ParkConfig.carouselAngle(model, t) + (index - 1) * 2 * math.pi / count) % (2 * math.pi)
	return center * CFrame.Angles(0, theta, 0) * CFrame.new(0, saddle + bob, -radius) * CFrame.Angles(0, math.pi / 2, 0)
end

--------------------------------------------------
-- Floating things on the sea (beach, 2026-10-22): tubes (tag "FloatTube",
-- rideable, attribute Rider) and decorations (tag "FloatDeco", rubber ducks).
-- Attributes: Base (Vector3, water level), Drift (radius), Period, Phase.
--------------------------------------------------

function ParkConfig.floatCFrame(model: Instance, t: number): CFrame?
	local base = model:GetAttribute("Base")
	if typeof(base) ~= "Vector3" then return nil end
	local phase = attr(model, "Phase", 0)
	local a = ((t / attr(model, "Period", 90)) % 1) * 2 * math.pi + phase
	local radius = attr(model, "Drift", 5)
	local bob = 0.22 * math.sin((t % 1000) * 1.4 + phase * 3)
	local rock = math.rad(4) * math.sin((t % 1000) * 0.9 + phase)
	return CFrame.new(base + Vector3.new(math.cos(a) * radius, bob, math.sin(a) * radius)) * CFrame.Angles(rock, -a * 0.5, 0)
end

--------------------------------------------------
-- Slide path (quadratic Bézier P0 → P1 → P2)
--------------------------------------------------

function ParkConfig.slidePoint(model: Instance, s: number): (Vector3, Vector3)
	local p0 = model:GetAttribute("P0") :: Vector3
	local p1 = model:GetAttribute("P1") :: Vector3
	local p2 = model:GetAttribute("P2") :: Vector3
	local u = 1 - s
	local point = p0 * (u * u) + p1 * (2 * u * s) + p2 * (s * s)
	local tangent = (p1 - p0) * (2 * u) + (p2 - p1) * (2 * s)
	return point, tangent
end

return ParkConfig

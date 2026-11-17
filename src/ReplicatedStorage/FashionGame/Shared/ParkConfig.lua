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
--   tag "ParkViking"    (D-1425) the viking's "Ride" model, pivot = the axle (X axis);
--                       "Swing" (Model, pivot = the axle) is turned about it. Attributes
--                       Period (one swing, s), MaxAngle (deg), Board / Ramp / Hold (s),
--                       Seat1..SeatN (CFrame from the axle at rest, facing the way the
--                       rider looks), Exit (Vector3). Riders: attributes Rider1..RiderN.
--   tag "ParkTeaCups"   (D-1432) the tea cups' "Ride" model, pivot = the turntable's middle
--                       (deck top). "Rotor" (Model) turns with the table; "Cup1".."CupN" (Model,
--                       pivot = the cup's middle on its saucer) turn with the table and spin on
--                       themselves the other way. Attributes Cups, SeatsPerCup, Cup1..CupN
--                       (CFrame from the pivot), SeatRel1..SeatRelM (CFrame from a cup's pivot),
--                       TurnPeriod / CupPeriod (s per turn at full speed), Board / Ramp / Hold
--                       (s; Ramp + Hold is a whole number of turns of both, so a run ends where
--                       it began), Exit (Vector3), Reach. Riders: Rider1..Rider(Cups×SeatsPerCup).
--   tag "ParkJumpStar"  (D-1457) the jumping star's "Ride" model, pivot = the tower's foot (upright,
--                       facing the way the car looks). "Car" (Model, pivot = the same) goes up and
--                       down the tower (ParkConfig.jumpStarState). Attributes Seat1..SeatN (CFrame
--                       from the pivot with the car at the bottom), Board (s standing still),
--                       Exit (Vector3), Reach. Riders: Rider1..RiderN.

local ParkConfig = {}

-- (D-831, user 2026-11-03) the Ferris wheel and the carousel stand still for
-- now (the park is closed). They only ever turned on each player's screen (no
-- server work), but there it costs every frame near them. true = turning
-- again; a live server can also switch them with the attribute
-- ParkRidesRunning (true/false) on ReplicatedStorage.FashionGame.
ParkConfig.RidesRunning = false
-- (D-1420, user 2026-11-15: the carousel's new horses "기능까지 구현") the carousel turns and takes
-- riders again; the Ferris wheel stays stopped (RidesRunning). The live attribute ParkRidesRunning
-- still switches both.
ParkConfig.CarouselRunning = true
-- (D-1425, user 2026-11-15: "바이킹 사람 타서 흔들리는 것까지 구현") the two vikings swing.
ParkConfig.VikingRunning = true
-- (D-1432, user 2026-11-15: "회전컵") the tea cups turn and take riders.
ParkConfig.TeaCupsRunning = true
-- (D-1457, user 2026-11-15: "점핑스타 사람 타서 위아래로 뛰는 것까지 구현")
ParkConfig.JumpStarRunning = true
-- (D-1481, user 2026-11-16: "관람차 운영되게 해") the Ferris wheel turns and takes riders again.
ParkConfig.WheelRunning = true
-- (D-1481, user 2026-11-16: "01_PeaceTrain … 레일 만들고 그냥 박스로 트레인 만들어서 테스트") the peace train runs.
ParkConfig.TrainRunning = true
function ParkConfig.isRunning(kind: string): boolean
	local fg = game:GetService("ReplicatedStorage"):FindFirstChild("FashionGame")
	local live = fg and fg:GetAttribute("ParkRidesRunning")
	if typeof(live) == "boolean" then return live end
	if kind == "ParkCarousel" then return ParkConfig.CarouselRunning end
	if kind == "ParkViking" then return ParkConfig.VikingRunning end
	if kind == "ParkTeaCups" then return ParkConfig.TeaCupsRunning end
	if kind == "ParkJumpStar" then return ParkConfig.JumpStarRunning end
	if kind == "ParkWheel" then return ParkConfig.WheelRunning end
	if kind == "ParkTrain" then return ParkConfig.TrainRunning end
	return ParkConfig.RidesRunning
end

-- Ferris wheel: one turn in Period seconds; a cabin can be boarded or left
-- while it is within BoardAngle of the bottom.
ParkConfig.WheelBoardAngle = math.rad(9)
ParkConfig.CabinSeats = {
	-- seat surface relative to the hang point; riders face the cabin centre
	-- (D-1433: the user's cabin; benches at x ±2.05, top 7.05 under the hang point)
	-- (D-1463: the user's new cabin has its door on the front (+x, the boarding deck): the benches
	-- stand across the wheel, at z ±2.6 in the hub's frame, riders facing each other)
	-- (D-1545, user 2026-11-16: "관람차 의자 블록 삭제하고 기존 앉는 위치에서 살짝만 아래로 내리기. 에셋에 의자
	-- 부분 만들었음") the Bench blocks are gone (park_fixes3_1116), the cabin mesh has its seats: 0.3 lower
	{ offset = Vector3.new(0, -7.35, 2.6), facing = Vector3.new(0, 0, -1) },
	{ offset = Vector3.new(0, -7.35, -2.6), facing = Vector3.new(0, 0, 1) },
}
ParkConfig.BoardDistance = 12
ParkConfig.CabinSway = 1 -- (D-1565) degrees a hanging cabin rocks

-- Swing speed levels (+/-): amplitude per level. Level 0 = just sitting.
-- Max 5 × 7° = 35°, with a 3.2 s period: smooth, no motion sickness.
ParkConfig.SwingLevels = 5
ParkConfig.SwingDegreesPerLevel = 7
ParkConfig.SwingPeriod = 3.2
ParkConfig.SwingStartLevel = 1

ParkConfig.SpringAngle = math.rad(11)
ParkConfig.SpringPeriod = 1.1

ParkConfig.SlideSeconds = 1.5
-- Cartoon Slide Whistle #1 (Creator Store, free) while sliding down.
ParkConfig.SlideSoundId = 95716072659114
-- "야호" voice at the bottom (Creator Store audio chosen by the user,
-- 2026-10-22), heard by everyone near, with the "야호!" bubble.
ParkConfig.YahooSoundId = 130278670102424
-- (D-1708, user 2026-11-18: "바이킹이나 점핑스타 내려올 때 들리는 소리 추가: 126615573673174") "Crowd Cheering"
-- (2.2 s), once each time a viking starts down from a high swing and when the jumping star's big drop starts
-- (RideWindController)
ParkConfig.DropCheerSoundId = 126615573673174
ParkConfig.DropCheerHigh = 0.75 -- (a viking peak counts from this share of its MaxAngle)

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
	-- (D-1565, user 2026-11-17: "중력에 따라 관람차는 계속 일직선으로 서 있으려고 엄청 살짝 흔들리기도")
	-- hanging upright, each cabin rocks very slightly on its pin (1°, its own beat)
	local sway = math.rad(ParkConfig.CabinSway) * math.sin(((t / 3.6) % 1) * 2 * math.pi + index * 1.7)
	return hub.Rotation * CFrame.Angles(sway, 0, 0) + point
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
-- Viking (D-1425): one shared run after another, from the server clock.
-- A run = Board seconds standing still (get on / off), then the swing grows
-- over Ramp seconds, swings at MaxAngle for Hold seconds and dies down over
-- Ramp seconds. Every client turns the boat the same way at the same time.
--------------------------------------------------

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- (angle in radians, standing still now?, seconds until the next change: the start when
-- standing, the stop when swinging)
function ParkConfig.vikingState(model: Instance, t: number): (number, boolean, number)
	local board = attr(model, "Board", 15)
	local ramp = attr(model, "Ramp", 10)
	local hold = attr(model, "Hold", 20)
	local cycle = board + ramp * 2 + hold
	if not ParkConfig.isRunning("ParkViking") then return 0, true, 0 end
	-- (D-1564, user 2026-11-17: "미니 바이킹 슈퍼 바이킹 운행 타임 겹치지 않도록") Offset (s) shifts a
	-- viking's runs: the two vikings share one cycle and each swings while the other stands still
	-- (tools/graybox/park_fixes4_1117.lua sets Board / Offset)
	local c = (t - attr(model, "Offset", 0)) % cycle
	if c < board then return 0, true, board - c end
	local u = c - board
	local env = if u < ramp then smooth(u / ramp) elseif u < ramp + hold then 1 else smooth((cycle - board - u) / ramp)
	local angle = math.rad(attr(model, "MaxAngle", 45)) * env * math.sin(2 * math.pi * u / attr(model, "Period", 4))
	return angle, false, cycle - c
end

function ParkConfig.vikingSeatCount(model: Instance): number
	local count = 0
	while typeof(model:GetAttribute("Seat" .. (count + 1))) == "CFrame" do count += 1 end
	return count
end

-- The boat's turn now (the Swing model goes to pivot * this).
function ParkConfig.vikingTurn(model: Instance, t: number): CFrame
	local angle = ParkConfig.vikingState(model, t)
	return CFrame.Angles(angle, 0, 0)
end

-- Seat k: where the rider sits (seat top), facing the way they look.
function ParkConfig.vikingSeatCFrame(model: Model, index: number, t: number): CFrame?
	local rel = model:GetAttribute("Seat" .. index)
	if typeof(rel) ~= "CFrame" then return nil end
	return model:GetPivot() * ParkConfig.vikingTurn(model, t) * rel
end

--------------------------------------------------
-- Tea cups (D-1432): the same kind of shared run as the viking. Standing still for Board
-- seconds, then the table speeds up over Ramp seconds, turns at full speed for Hold seconds
-- and slows down over Ramp seconds (speed rises and falls in a straight line). The cups spin
-- the other way at their own speed. Ramp + Hold is a whole number of turns of the table and
-- of a cup, so every run starts and ends with the cups at the same places.
--------------------------------------------------

-- (table angle, cup spin angle, standing still?, seconds until the next change)
function ParkConfig.teacupState(model: Instance, t: number): (number, number, boolean, number)
	local board = attr(model, "Board", 15)
	local ramp = attr(model, "Ramp", 4)
	local hold = attr(model, "Hold", 24)
	local run = ramp * 2 + hold
	local cycle = board + run
	if not ParkConfig.isRunning("ParkTeaCups") then return 0, 0, true, 0 end
	local c = t % cycle
	if c < board then return 0, 0, true, board - c end
	local u = c - board
	-- f(u) = seconds at full speed so far
	local f = if u < ramp then u * u / (2 * ramp) elseif u < ramp + hold then ramp / 2 + (u - ramp) else ramp + hold - (run - u) ^ 2 / (2 * ramp)
	local turn = (f / attr(model, "TurnPeriod", 14)) % 1 * 2 * math.pi
	local spin = (f / attr(model, "CupPeriod", 4)) % 1 * 2 * math.pi
	return turn, spin, false, cycle - c
end

function ParkConfig.teacupCount(model: Instance): number
	return attr(model, "Cups", 0)
end

-- (D-1442, user 2026-11-15: "회전컵은 가운데 핸들 클릭하면 점점 더 빨라지고 클릭 안 하면 점점
-- 느려지게") a rider tapping the cup's wheel spins that cup faster; the extra speed dies away
-- by itself. The server keeps each cup's extra spin in the ride's attribute Spin<k> =
-- Vector3(angle, speed, server time - SpinEpoch) and every screen works out the angle from it
-- (a Vector3 holds single precision: the server clock itself, about 1.8e9, loses whole minutes, so
-- the time is counted from the ride's SpinEpoch, a whole second the server set once):
--   speed(t) = speed0 · e^(-(t - t0) / SpinFade), angle(t) = angle0 + speed0 · SpinFade · (1 - e^(…))
-- Taps only count while the table runs and not in its last SpinStopGap seconds; when the run
-- ends the extra angle is held where it was (so the cups stand still for boarding).
ParkConfig.SpinBoost = 1.3 -- (rad/s added per tap; the cup's own spin is 2π / 4 ≈ 1.6)
ParkConfig.SpinMax = 10 -- (rad/s of extra spin at most)
ParkConfig.SpinFade = 2.5 -- (seconds for the extra speed to fall to 37 %)
ParkConfig.SpinStopGap = 5 -- (no taps in the run's last seconds: the cups calm down first)

-- (extra angle, extra speed) of cup k at time t
function ParkConfig.teacupExtra(model: Instance, cup: number, t: number): (number, number)
	local s = model:GetAttribute("Spin" .. cup)
	if typeof(s) ~= "Vector3" then return 0, 0 end
	local _, _, still, left = ParkConfig.teacupState(model, t)
	if still and ParkConfig.isRunning("ParkTeaCups") then
		-- standing still: held at the end of the last run
		t = t - (attr(model, "Board", 15) - left)
	end
	local dt = math.max(0, t - attr(model, "SpinEpoch", 0) - s.Z)
	local k = math.exp(-dt / ParkConfig.SpinFade)
	return s.X + s.Y * ParkConfig.SpinFade * (1 - k), s.Y * k
end

ParkConfig.TeacupRestTurn = math.rad(137.5)

-- Cup k's pivot now.
function ParkConfig.teacupCFrame(model: Model, cup: number, t: number): CFrame?
	local rel = model:GetAttribute("Cup" .. cup)
	if typeof(rel) ~= "CFrame" then return nil end
	local turn, spin = ParkConfig.teacupState(model, t)
	spin += ParkConfig.teacupExtra(model, cup, t)
	-- (D-1517, user: "회전컵 멈췄을 때 회전 방향 모두 다르게 하기. 지금 캐릭터 얼굴이 모두 한 방향"): each cup
	-- turned its own way (137.5° apart, so no two face alike); a run is still whole turns, so it keeps it
	spin += (cup - 1) * ParkConfig.TeacupRestTurn
	return model:GetPivot() * CFrame.Angles(0, turn, 0) * rel * CFrame.Angles(0, -spin, 0)
end

-- Seat k (cup = ceil(k / SeatsPerCup)) now.
function ParkConfig.teacupSeatCFrame(model: Model, index: number, t: number): CFrame?
	local per = attr(model, "SeatsPerCup", 4)
	local cup = math.ceil(index / per)
	local rel = model:GetAttribute("SeatRel" .. ((index - 1) % per + 1))
	local cf = ParkConfig.teacupCFrame(model, cup, t)
	if not cf or typeof(rel) ~= "CFrame" then return nil end
	return cf * rel
end

--------------------------------------------------
-- Jumping star (D-1457): the car hops up the tower, drops and bounces, and comes down, the
-- same run on every screen. A run = Board seconds standing at the bottom, then the hops in
-- JumpKeys (seconds into the hops, height of the seat over its bottom place); between two keys
-- the car eases out and in (it stops for a moment at each key, so every key is a jump's top or a
-- landing). The drops are the short gaps.
--------------------------------------------------

-- (D-1458, user 2026-11-15: "점핑스타 천천히 올라갔다가 천천히 반만 내려왔다가 다시 올라갔다가 훅
-- 내려가는 걸로") slowly up to the top, slowly half way down, slowly up again, a moment at the top,
-- then a sudden drop: falling faster and faster ("fall": x²) to 6 over the bottom, braking hard
-- ("brake") to the bottom with the same speed it fell at, one small bounce.
-- A key's third value is how the gap BEFORE it eases (default: slow out, slow in).
-- (D-1481, user: "점핑스타 제일 처음 니가 만들었던 움직임으로 하되 마지막에 훅 내려가는 구간만 추가"): D-1457's hops
-- (up the tower in hops, bouncing down again) and then D-1458's ending: slowly up to the top, a moment
-- there, the sudden drop and its brake and one small bounce. ParkConfig.jumpStarBigDrop says when the
-- last drop runs (the riders' arms go up and the wind blows only then).
-- (D-1485, user: "끝에 여기까지 올려" + a line between the arms' stars and the sign) the last climb
-- goes to 30 (with JumpScale 1.384: the car's top 52 over the foot, under the JUMPIN STAR sign).
ParkConfig.JumpKeys = {
	{ 0, 0 }, { 2.4, 6 }, { 3.1, 3.5 }, { 5.2, 12 }, { 5.9, 9 }, { 8.0, 17 }, { 8.7, 14 }, { 11.0, 22 },
	{ 12.6, 22 }, { 13.2, 11 }, { 14.3, 20 }, { 14.9, 9 }, { 16.0, 19 }, { 16.6, 7 }, { 17.8, 17 },
	{ 18.4, 5 }, { 19.6, 14 }, { 20.2, 3 }, { 21.4, 10 }, { 22.0, 2 }, { 23.0, 6 }, { 23.6, 0.6 },
	{ 24.4, 2.2 }, { 25.2, 0 },
	{ 33.2, 30 }, { 35.7, 30 }, { 36.8, 6, "fall" }, { 37.2, 0, "brake" }, { 37.9, 1.2 }, { 38.7, 0 },
}
ParkConfig.JumpWindSpeed = 6 -- (studs/s down: faster than this, the wind sound plays — the big drop)

-- (height of the car over its bottom place, standing still?, seconds until the next change)
-- (D-1484) the Ride's attribute JumpScale stretches every height (a taller tower: the user's v2 model).
function ParkConfig.jumpStarState(model: Instance, t: number): (number, boolean, number)
	local keys = ParkConfig.JumpKeys
	local run = keys[#keys][1]
	local board = attr(model, "Board", 15)
	if not ParkConfig.isRunning("ParkJumpStar") then return 0, true, 0 end
	local cycle = board + run
	local c = t % cycle
	if c < board then return 0, true, board - c end
	local u = c - board
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if u < b[1] then
			local x = (u - a[1]) / (b[1] - a[1])
			local ease = b[3]
			if ease == "fall" then
				x = x * x
			elseif ease == "brake" then
				x = 1 - (1 - x) * (1 - x)
			else
				x = x * x * (3 - 2 * x)
			end
			return (a[2] + (b[2] - a[2]) * x) * attr(model, "JumpScale", 1), false, cycle - c
		end
	end
	return 0, false, cycle - c
end

-- (D-1481) is the run in its last, sudden drop (the "fall" gap and the "brake" after it)?
function ParkConfig.jumpStarBigDrop(model: Instance, t: number): boolean
	local keys = ParkConfig.JumpKeys
	if not ParkConfig.isRunning("ParkJumpStar") then return false end
	local board = attr(model, "Board", 15)
	local c = t % (board + keys[#keys][1])
	if c < board then return false end
	local u = c - board
	for i = 2, #keys do
		local e = keys[i][3]
		if e == "fall" or e == "brake" then
			if u >= keys[i - 1][1] and u < keys[i][1] then return true end
		end
	end
	return false
end

function ParkConfig.jumpStarSeatCFrame(model: Model, index: number, t: number): CFrame?
	local rel = model:GetAttribute("Seat" .. index)
	if typeof(rel) ~= "CFrame" then return nil end
	local h = ParkConfig.jumpStarState(model, t)
	return model:GetPivot() * CFrame.new(0, h, 0) * rel
end

--------------------------------------------------
-- Rides with a shared run and seats picked on board (viking, tea cups, jumping star)
--------------------------------------------------

ParkConfig.SeatRideNames = { ParkViking = "바이킹", ParkTeaCups = "회전컵", ParkJumpStar = "점핑스타" }
-- (the name with its subject particle: 바이킹이 / 회전컵이 / 점핑스타가)
ParkConfig.SeatRideSubjects = { ParkViking = "바이킹이", ParkTeaCups = "회전컵이", ParkJumpStar = "점핑스타가" }
ParkConfig.SeatRideIcons = { ParkViking = "⛵", ParkTeaCups = "☕", ParkJumpStar = "⭐" }

function ParkConfig.isSeatRide(kind: string?): boolean
	return kind == "ParkViking" or kind == "ParkTeaCups" or kind == "ParkJumpStar"
end

function ParkConfig.seatRideKind(model: Instance): string?
	local cs = game:GetService("CollectionService")
	if cs:HasTag(model, "ParkViking") then return "ParkViking" end
	if cs:HasTag(model, "ParkTeaCups") then return "ParkTeaCups" end
	if cs:HasTag(model, "ParkJumpStar") then return "ParkJumpStar" end
	return nil
end

-- (standing still?, seconds until the next change)
function ParkConfig.rideState(model: Instance, t: number): (boolean, number)
	local kind = ParkConfig.seatRideKind(model)
	if kind == "ParkTeaCups" then
		local _, _, still, left = ParkConfig.teacupState(model, t)
		return still, left
	elseif kind == "ParkJumpStar" then
		local _, still, left = ParkConfig.jumpStarState(model, t)
		return still, left
	end
	local _, still, left = ParkConfig.vikingState(model, t)
	return still, left
end

-- seat k of any seat ride now (where the rider sits, facing the way they look)
function ParkConfig.seatRideSeatCFrame(model: Model, index: number, t: number): CFrame?
	local kind = ParkConfig.seatRideKind(model)
	if kind == "ParkTeaCups" then return ParkConfig.teacupSeatCFrame(model, index, t) end
	if kind == "ParkJumpStar" then return ParkConfig.jumpStarSeatCFrame(model, index, t) end
	return ParkConfig.vikingSeatCFrame(model, index, t)
end

function ParkConfig.rideSeatCount(model: Instance): number
	if ParkConfig.seatRideKind(model) == "ParkTeaCups" then
		return ParkConfig.teacupCount(model) * attr(model, "SeatsPerCup", 4)
	end
	return ParkConfig.vikingSeatCount(model)
end

--------------------------------------------------
-- Floating things on the sea (beach, 2026-10-22): tubes (tag "FloatTube",
-- rideable, attribute Rider) and decorations (tag "FloatDeco", rubber ducks).
-- Attributes: Base (Vector3, water level), Drift (radius), Period, Phase.
--------------------------------------------------

-- Tube speed while its rider paddles (user 2026-10-26: 타고 움직이기). The
-- rider's client moves the tube and sends where it is; the server keeps it in
-- the attributes Drive (Vector3, at water level) and DriveYaw.
ParkConfig.TubeSpeed = 7
-- tubes bump into each other (user 2026-10-30): they touch closer than
-- TubeTouch (the tube is 4.4 across), are pushed apart at BumpSpeed and slow
-- down with BumpDrag (about 3 studs of travel)
ParkConfig.TubeTouch = 4.3
ParkConfig.BumpSpeed = 9
ParkConfig.BumpDrag = 3

-- Drift-path angle at t (the rider leaving re-centres Base on it, no jump).
function ParkConfig.floatAngle(model: Instance, t: number): number
	return ((t / attr(model, "Period", 90)) % 1) * 2 * math.pi + attr(model, "Phase", 0)
end

-- A tube held at `center` (water level) facing `yaw`, bobbing on the waves.
function ParkConfig.floatAt(model: Instance, t: number, center: Vector3, yaw: number): CFrame
	local phase = attr(model, "Phase", 0)
	local bob = 0.22 * math.sin((t % 1000) * 1.4 + phase * 3)
	local rock = math.rad(4) * math.sin((t % 1000) * 0.9 + phase)
	return CFrame.new(center + Vector3.new(0, bob, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(rock, 0, 0)
end

function ParkConfig.floatCFrame(model: Instance, t: number): CFrame?
	local drive = model:GetAttribute("Drive")
	if typeof(drive) == "Vector3" then
		return ParkConfig.floatAt(model, t, drive, attr(model, "DriveYaw", 0))
	end
	local base = model:GetAttribute("Base")
	if typeof(base) ~= "Vector3" then return nil end
	-- a bump from another tube (user 2026-10-30): pushed off at BumpVel at
	-- server time BumpAt, slowing down (ParkRideService folds it into Base later)
	local bumpVel, bumpAt = model:GetAttribute("BumpVel"), model:GetAttribute("BumpAt")
	if typeof(bumpVel) == "Vector3" and typeof(bumpAt) == "number" then
		local k = ParkConfig.BumpDrag
		base += bumpVel * (1 - math.exp(-k * math.max(0, t - bumpAt))) / k
	end
	local a = ParkConfig.floatAngle(model, t)
	local radius = attr(model, "Drift", 5)
	return ParkConfig.floatAt(model, t, base + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius), -a * 0.5)
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

--!strict
-- (D-1413, user 2026-11-14, a photo of a real dodgem ride: "범퍼카 안에 사람 앉아서 운전할 수 있게 해
-- 범퍼카 서로 부딪히면 밑부분 고무끼리 부딪히면서 퉁 튕기는 물리적 모션까지 구현해 줘 실제 범퍼카에
-- 대해서 알아보고 그대로 구현해 줘") Drivable bumper cars in the park's bumper car hall.
--
-- How a real one works (and what is copied here):
--   * an electric car (power from a ceiling grid or a floor grid), one pedal: press = go, let
--     go = it rolls to a stop; no brake. Slow: about 5-8 km/h.
--   * the steering wheel turns the DRIVE wheel under the front: turned a little the car curves,
--     turned all the way (about 90°) with the pedal down the car spins on the spot or backs up.
--   * a thick rubber ring all round the chassis at floor height: a hit compresses it for a
--     moment and it pushes the cars apart again ("퉁"), which makes the hit last longer and feel
--     softer; a hit off the centre also spins the car. The floor is smooth steel, so the cars
--     slide sideways a little after a hit.
-- Here: the car is a rigid body on the floor plane (position, velocity, heading, spin). The
-- drive force acts at the drive wheel (DriveAhead) along the wheel's direction; the rubber ring
-- is a capsule round the car (two circles) and a contact is a spring with damping (contact time
-- about ContactSeconds, the ring's bounce Restitution); walls (the hall's rails) the same. The
-- body rocks and hops on its suspension after a hit (client only, Wobble*).

local BumperCarConfig = {}

BumperCarConfig.Tag = "BumperCar" -- the car models in the place (Workspace.Scene.BumperCar*)
BumperCarConfig.RootTag = "BumperCarRoot" -- the runtime root part the server builds per car

BumperCarConfig.Length = 10 -- the car's length after scaling the user's mesh (studs; a seated avatar fits)
BumperCarConfig.SeatOffset = Vector3.new(-1.45, -0.55, 0) -- the seat in the body's space (back half; +X is the front)

-- driving (studs, seconds; a 10-stud car = about 2 m, 1 m = 5 studs)
BumperCarConfig.MaxSpeed = 12 -- (with the drag a car tops out near 8.5 studs/s, about 6 km/h)
BumperCarConfig.Accel = 20 -- full pedal
BumperCarConfig.ReverseFactor = 0.55 -- S / stick back: backing up is slower
BumperCarConfig.RollDrag = 0.7 -- 1/s along the car (no pedal: rolls to a stop in a few seconds)
BumperCarConfig.SideGrip = 4.5 -- 1/s across the car (low: the steel floor lets it slide)
BumperCarConfig.SpinDrag = 2.2 -- 1/s
BumperCarConfig.WheelMax = math.rad(85) -- the drive wheel turned all the way
BumperCarConfig.WheelRate = math.rad(240) -- how fast the wheel turns with A / D (and back)
BumperCarConfig.DriveAhead = 0.3 -- the drive wheel this far ahead of the centre (x length)

-- the rubber ring
BumperCarConfig.RingPad = 0.15 -- the ring's half width past the body's sides (studs)
BumperCarConfig.ContactSeconds = 0.14
BumperCarConfig.Restitution = 0.62
BumperCarConfig.RingFriction = 0.25 -- rubber on rubber: the sideways part of a hit (spins the car)
BumperCarConfig.BumpSoundId = "rbxassetid://9117456565" -- Plastic Cooler Hits 8 (Pro Sound Effects): a hollow thud
BumperCarConfig.BumpSoundMin = 2.5 -- closing speed (studs/s) for a sound and a wobble
BumperCarConfig.WobbleKick = 0.028 -- radians of tilt per stud/s of hit (an 8 stud/s hit: about 8°)
BumperCarConfig.WobbleHop = 0.03 -- studs of hop per stud/s
BumperCarConfig.WobbleFreq = 9 -- the body's rock (rad/s)
BumperCarConfig.WobbleDamp = 5

-- the hall (Hongdae_Layout.ParkBlockout["04_BumperCars"]): the rails' inner faces and the floor top
BumperCarConfig.Hall = { x0 = -276.2, x1 = -207.85, z0 = -397.68, z1 = -293.75, floorY = 18.03 }

-- the car's spring (per unit mass) and damping from the contact time and the bounce:
-- a damped spring's half period = ContactSeconds, the speed after / before = Restitution
function BumperCarConfig.spring(): (number, number)
	local lnE = math.log(BumperCarConfig.Restitution)
	local zeta = -lnE / math.sqrt(math.pi * math.pi + lnE * lnE)
	local wd = math.pi / BumperCarConfig.ContactSeconds
	local w0 = wd / math.sqrt(1 - zeta * zeta)
	return w0 * w0, 2 * zeta * w0
end

return BumperCarConfig

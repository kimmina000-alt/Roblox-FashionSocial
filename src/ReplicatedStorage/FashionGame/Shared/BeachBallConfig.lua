--!strict
-- Beach ball throw numbers and the flight, shared by BeachBallService (the
-- real ball) and BeachBallController (the arc and landing mark shown before the
-- throw), so what is shown is where it goes (D-1089).

local BeachBallConfig = {}

-- (D-1048) launch speed by power 0..1; with FLOAT_G / DRAG_VT at 35°:
-- 18 → 7 studs, 50 → 30, 100 → 62 (top 16, 1.5 s in the air)
BeachBallConfig.SPEED_MIN, BeachBallConfig.SPEED_MAX = 18, 100
BeachBallConfig.CHARGE_FULL = 1.5 -- seconds held for full power
BeachBallConfig.FLOAT_G = 55 -- the ball's own fall (the world pulls 196.2)
BeachBallConfig.DRAG_VT = 55 -- the speed the air holds it to when falling
BeachBallConfig.DRAG_K = BeachBallConfig.FLOAT_G / (BeachBallConfig.DRAG_VT * BeachBallConfig.DRAG_VT)

-- (D-1284, user 2026-11-11: "비치볼이 바닥에 닿을 때 통통 튕기는 소리 나게 해 줘 /
-- 반동으로 몇 번 더 튕기면서 멈출 때도 소리 나야 함") a bounce sound at every
-- bounce of a thrown ball, softer as the bounces get smaller, down to the
-- last little one (BeachBallController)
BeachBallConfig.BOUNCE_SOUND = "rbxassetid://0"
BeachBallConfig.BOUNCE_MIN_SPEED = 1.5 -- studs/s falling: slower is not a bounce (bobbing on the sea)
BeachBallConfig.BOUNCE_FULL_SPEED = 40 -- falling this fast or faster: full volume

-- Where the ball leaves the hand and how fast, for a thrower whose root is at
-- `root`, head at `head`, aiming at `target` with `power`.
-- Which way: toward the target, level; up by the aim + 25° (a thrower aims a
-- bit over what they want to hit), 12°..60°.
function BeachBallConfig.launch(root: CFrame, head: Vector3, target: Vector3, power: number): (Vector3, Vector3)
	local aim = target - head
	if aim.Magnitude < 1 or aim.Magnitude > 400 then aim = root.LookVector * 20 end
	local flat = Vector3.new(aim.X, 0, aim.Z)
	flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(root.LookVector.X, 0, root.LookVector.Z).Unit
	local pitch = math.clamp(math.atan2(aim.Y, math.max(1, Vector3.new(aim.X, 0, aim.Z).Magnitude)) + math.rad(25), math.rad(12), math.rad(60))
	local dir = flat * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	local speed = BeachBallConfig.SPEED_MIN + (BeachBallConfig.SPEED_MAX - BeachBallConfig.SPEED_MIN) * math.clamp(power, 0, 1)
	-- from over the right shoulder, where the swing lets go of it, a little ahead
	local from = (root * CFrame.new(0.9, 1.9, 0)).Position + flat * 2.2
	return from, dir * speed
end

-- The flight from `from` at `velocity` until it hits something (raycasts with
-- `params`): the points along the way (every `every` seconds) and where it
-- lands (nil: still in the air after `maxTime`).
function BeachBallConfig.path(from: Vector3, velocity: Vector3, params: RaycastParams, every: number, maxTime: number): ({Vector3}, RaycastResult?)
	local points = { from }
	local p, v = from, velocity
	local dt = 1 / 60
	local t, nextMark = 0, every
	while t < maxTime do
		local a = Vector3.new(0, -BeachBallConfig.FLOAT_G, 0) - v * (v.Magnitude * BeachBallConfig.DRAG_K)
		v += a * dt
		local step = v * dt
		local hit = workspace:Raycast(p, step, params)
		if hit then
			table.insert(points, hit.Position)
			return points, hit
		end
		p += step
		t += dt
		if t >= nextMark then
			table.insert(points, p)
			nextMark += every
		end
	end
	return points, nil
end

return BeachBallConfig

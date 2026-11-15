--!nocheck
-- 슈퍼바이킹 단상 + 주변 펜스 (D-1440, user 2026-11-15: "슈퍼바이킹 단상이랑 주변 펜스 디자인 작업",
-- photos of 경주월드 King Viking: the boat swings between two raised boarding decks with orange
-- corrugated sides, a brown wooden railing with round painted shields along the top, stairs down
-- to the paving, and a metal queue fence round the ride).
--   * two decks, one each side of the boat, out of the arms' way (the arms swing at x ±7.5 from the
--     axle): x ±7.8 .. ±18, z ±26 from the axle, top TOP_Y (the boat's floor level), orange
--     metal sides with vertical ribs (corrugated), a diamond-plate floor; the A-frame legs go through them
--   * a brown railing (posts, two rails) round each deck, open on the boat side between the
--     posts so riders face the boat; round shields (green / blue / red, gold rim) on the outer rail
--   * stairs from each deck's +z end down to the paving (with an invisible ramp to walk on)
--   * a grey metal fence round the base, open in front of both stairs
--   * the ride's Exit moves onto the +x deck (riders get off onto the deck and walk down)
-- Workspace["슈퍼바이킹"].Stage, built anew each run; Edit mode, after park_vikings_1115.

local owner = workspace:WaitForChild("슈퍼바이킹")
local ride = owner:WaitForChild("Ride")
local base = owner:WaitForChild("Base") :: BasePart
local O = ride:GetPivot().Position -- (the axle)
local GROUND = base.Position.Y + base.Size.Y / 2
local TOP_Y = GROUND + 8.5
-- (D-1444, user 2026-11-15: "슈퍼 바이킹 대기하는 공간 더 크게": the decks 10.2 x 52 → 17.2 x 64, was
-- X1 18 / ZH 26; the base grows with them, more to +z where the stairs go down: the bumper cars'
-- fence is 2 studs past the base's -z edge)
local X0, X1, ZH = 7.8, 25, 32 -- (deck from the axle: x inner / outer, z half length)
local BASE_X, BASE_Z0, BASE_Z1 = X1 + 4, -(ZH + 4), ZH + 13 + 4 -- (base from the axle; the stairs run 13 out from the deck)
local ORANGE = Color3.fromRGB(214, 98, 44)
local RIB = Color3.fromRGB(178, 76, 34)
local WOOD = Color3.fromRGB(122, 74, 44)
local GOLD = Color3.fromRGB(224, 180, 70)
local SHIELDS = { Color3.fromRGB(60, 140, 90), Color3.fromRGB(56, 112, 188), Color3.fromRGB(196, 52, 52) }
local FENCE = Color3.fromRGB(150, 156, 164)

local old = owner:FindFirstChild("Stage")
if old then old:Destroy() end
local stage = Instance.new("Model")
stage.Name = "Stage"

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = stage
	return p
end
local function at(x: number, y: number, z: number): CFrame return CFrame.new(O.X + x, y, O.Z + z) end
local function bar(name: string, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?)
	return part(name, Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat)
end
local function W(x: number, y: number, z: number): Vector3 return Vector3.new(O.X + x, y, O.Z + z) end

local H = TOP_Y - GROUND
base.Size = Vector3.new(BASE_X * 2, base.Size.Y, BASE_Z1 - BASE_Z0)
base.CFrame = CFrame.new(O.X, GROUND - base.Size.Y / 2, O.Z + (BASE_Z0 + BASE_Z1) / 2)
for _, sx in ipairs({ -1, 1 }) do
	local xin, xout = sx * X0, sx * X1
	local cx, w = (xin + xout) / 2, X1 - X0
	part("DeckBody", Vector3.new(w, H - 0.3, ZH * 2), at(cx, GROUND + (H - 0.3) / 2, 0), ORANGE, Enum.Material.Metal)
	part("DeckTrim", Vector3.new(w + 0.4, 0.5, ZH * 2 + 0.4), at(cx, TOP_Y - 0.55, 0), WOOD, Enum.Material.WoodPlanks)
	part("DeckFloor", Vector3.new(w, 0.3, ZH * 2), at(cx, TOP_Y - 0.15, 0), Color3.fromRGB(168, 172, 178), Enum.Material.DiamondPlate)
	-- vertical ribs on the outer side and the -z end: the corrugated look (no such material)
	for z = -ZH + 1, ZH - 1, 2 do
		part("Rib", Vector3.new(0.25, H - 1.2, 0.55), at(xout + sx * 0.12, GROUND + (H - 1.2) / 2 + 0.2, z), RIB, Enum.Material.Metal, nil, false)
	end
	for x = math.min(xin, xout) + 1, math.max(xin, xout) - 1, 2 do
		part("Rib", Vector3.new(0.55, H - 1.2, 0.25), at(x, GROUND + (H - 1.2) / 2 + 0.2, -ZH - 0.12), RIB, Enum.Material.Metal, nil, false)
	end
	-- railing: posts round the deck, rails on the outer side and the two ends; the boat side keeps
	-- its posts and a low rail only (riders look at the boat)
	local railY1, railY2 = TOP_Y + 1.6, TOP_Y + 3.2
	local zs = {}
	for k = 0, 8 do table.insert(zs, -ZH + k * ZH * 2 / 8) end
	for _, z in ipairs(zs) do
		part("RailPost", Vector3.new(0.45, 3.4, 0.45), at(xout, TOP_Y + 1.7, z), WOOD, Enum.Material.WoodPlanks)
		part("RailPost", Vector3.new(0.45, 1.8, 0.45), at(xin, TOP_Y + 0.9, z), WOOD, Enum.Material.WoodPlanks)
	end
	for _, y in ipairs({ railY1, railY2 }) do
		bar("Rail", W(xout, y, -ZH), W(xout, y, ZH), 0.35, WOOD, Enum.Material.WoodPlanks)
		bar("Rail", W(xin, TOP_Y + 1.7, -ZH), W(xout, y, -ZH), 0.35, WOOD, Enum.Material.WoodPlanks)
	end
	bar("Rail", W(xin, TOP_Y + 1.8, -ZH), W(xin, TOP_Y + 1.8, ZH), 0.3, WOOD, Enum.Material.WoodPlanks)
	-- round shields on the outer rail, facing out
	for k = 1, 8 do
		local z = -ZH + (k - 0.5) * ZH * 2 / 8
		local c = at(xout + sx * 0.3, TOP_Y + 2.4, z) * CFrame.Angles(0, if sx > 0 then 0 else math.pi, 0)
		part("ShieldRim", Vector3.new(0.2, 2.6, 2.6), c, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder, false)
		part("Shield", Vector3.new(0.25, 2.1, 2.1), c * CFrame.new(sx * 0.05, 0, 0), SHIELDS[(k - 1) % #SHIELDS + 1], Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, false)
		part("ShieldBoss", Vector3.new(0.35, 0.6, 0.6), c * CFrame.new(sx * 0.12, 0, 0), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	end
	-- stairs down from the +z end (outer half of the deck)
	local steps = 10
	local rise, run = H / steps, 1.3
	local sw = 5
	local scx = xout - sx * (sw / 2 + 0.6)
	for k = 1, steps do
		local top = TOP_Y - (k - 1) * rise
		part("Step", Vector3.new(sw, top - GROUND, run), at(scx, GROUND + (top - GROUND) / 2, ZH + (k - 0.5) * run), ORANGE, Enum.Material.Metal)
		part("StepTread", Vector3.new(sw, 0.12, run), at(scx, top - 0.06, ZH + (k - 0.5) * run), Color3.fromRGB(168, 172, 178), Enum.Material.DiamondPlate)
	end
	local len = steps * run
	local ramp = Instance.new("WedgePart") -- (humanoids climb a slope, not tall steps)
	ramp.Name = "StairRamp"
	ramp.Size = Vector3.new(sw, H, len)
	ramp.CFrame = at(scx, GROUND + H / 2, ZH + len / 2) * CFrame.Angles(0, math.pi, 0)
	ramp.Transparency = 1
	ramp.Anchored = true
	ramp.CanTouch = false
	ramp.Parent = stage
	for _, side in ipairs({ -1, 1 }) do
		local x = scx + side * (sw / 2 + 0.1)
		bar("StairRail", W(x, TOP_Y + 3, ZH), W(x, GROUND + 3, ZH + len), 0.3, WOOD, Enum.Material.WoodPlanks)
	end
end

-- the fence round the base, open in front of both stairs: each opening just the stairs' width
-- plus a little (D-1443: a gate in each, park_ride_gates_1115: -x = entrance, +x = exit)
local GAP_W = 7
do
	local hx = BASE_X - 1
	local z0, z1 = O.Z + BASE_Z0 + 1, O.Z + BASE_Z1 - 1
	local cx = O.X
	local function run(a: Vector3, b: Vector3)
		local d = b - a
		local n = math.max(1, math.floor(d.Magnitude / 6 + 0.5))
		for k = 0, n - 1 do
			local p0, p1 = a + d * (k / n), a + d * ((k + 1) / n)
			part("FencePost", Vector3.new(0.35, 3.6, 0.35), CFrame.new(p0 + Vector3.new(0, 1.8, 0)), FENCE, Enum.Material.Metal)
			for _, y in ipairs({ 1.2, 3.3 }) do
				bar("FenceRail", p0 + Vector3.new(0, y, 0), p1 + Vector3.new(0, y, 0), 0.22, FENCE, Enum.Material.Metal)
			end
		end
		part("FencePost", Vector3.new(0.35, 3.6, 0.35), CFrame.new(b + Vector3.new(0, 1.8, 0)), FENCE, Enum.Material.Metal)
	end
	local y = GROUND
	local sxs = O.X + (X1 - 3.1) -- (the stairs' middles, x)
	local function V(x: number, z: number): Vector3 return Vector3.new(x, y, z) end
	run(V(cx - hx, z0), V(cx + hx, z0))
	run(V(cx + hx, z0), V(cx + hx, z1))
	-- +z side: three runs round the two openings
	run(V(cx + hx, z1), V(sxs + GAP_W / 2, z1))
	run(V(sxs - GAP_W / 2, z1), V(2 * O.X - sxs + GAP_W / 2, z1))
	run(V(2 * O.X - sxs - GAP_W / 2, z1), V(cx - hx, z1))
	run(V(cx - hx, z1), V(cx - hx, z0))
	stage:SetAttribute("ExitGate", CFrame.new(sxs, y, z1)) -- (gate middle; +z = out)
	stage:SetAttribute("EntryGate", CFrame.new(2 * O.X - sxs, y, z1))
	stage:SetAttribute("GateWidth", GAP_W)
end

base.Material = Enum.Material.Pavement
base.Color = Color3.fromRGB(196, 160, 140)
stage.Parent = owner
ride:SetAttribute("Exit", W(X0 + 4, TOP_Y + 3, 0)) -- (off onto the +x deck)
print("[park_viking_stage_1115] parts " .. #stage:GetChildren())
return #stage:GetChildren()

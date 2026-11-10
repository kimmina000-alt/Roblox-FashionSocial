--!nocheck
-- OH24 window bars (D-1157, user 2026-11-10), run in Edit mode LAST in the layout
-- chain (after cafe_case_1110). Relative to the store's two WindowBar parts, so
-- it follows the store wherever it stands; running it again gives the same result.
--   1. "편의점 온수기 위치랑 전자레인지 위치 다시 인식": the user put a second hot
--      water dispenser (HotWater + HotWaterTap + HotWaterTray) and a second
--      microwave (OhuMicrowave) on the short bar by hand, in the Workspace root.
--      Both sets now live in OH24Store at the user's spots (the game finds them
--      by name anywhere: RamenCup.Start tags the dispensers, Microwave.Start builds
--      a rig on every OhuMicrowave); a missing second set is a copy of the first.
--   2. "의자 공중에 떠 있음 확인하고 의자 위치 좀더 안쪽으로 수정": the four window
--      stools (ClubStool + WindowStool seat) stood 0.89 above the deck (deck top
--      2.2, stool feet 3.09): down onto the floor below them, pulled in under the
--      long bar's front edge and closer together (5.5 apart, was 7.5).
local L = workspace:FindFirstChild("Hongdae_Layout")
local S = L and L:FindFirstChild("OH24Store")
assert(S, "run the layout chain first")
local log = {}

local short, long
for _, d in ipairs(S:GetChildren()) do
	if d.Name == "WindowBar" and d:IsA("BasePart") then
		if d.Size.Z > d.Size.X then short = d else long = d end
	end
end
assert(short and long, "OH24 WindowBar parts not found")

------------------------------------------------------------------ 1. two sets of machines
-- (in the short bar's space: x across the bar, y up from its middle, z along it)
local SPOTS = {
	HotWater = { Vector3.new(1.05, 2.65, 0), { -3.825, -1.125 } },
	HotWaterTap = { Vector3.new(-0.59, 2.25, 0), { -3.825, -1.125 } },
	HotWaterTray = { Vector3.new(-0.75, 0.27, 0), { -3.825, -1.125 } },
	OhuMicrowave = { Vector3.new(1.45, 0.91, 0), { 5.675, 2.375 } },
}
local TURN = CFrame.Angles(0, math.rad(-90), 0)
local brought, copied = 0, 0
for name, spot in pairs(SPOTS) do
	local parts = {}
	for _, root in ipairs({ S, workspace }) do
		for _, d in ipairs(root:GetChildren()) do
			if d:IsA("BasePart") and d.Name == name then
				if d.Parent ~= S then d.Parent = S brought += 1 end
				table.insert(parts, d)
			end
		end
	end
	if #parts == 0 then table.insert(log, "missing " .. name) continue end
	while #parts < #spot[2] do
		local c = parts[1]:Clone()
		c.Parent = S
		table.insert(parts, c)
		copied += 1
	end
	-- the one nearer the bar's -z end takes the first spot
	table.sort(parts, function(a, b) return short.CFrame:PointToObjectSpace(a.Position).Z < short.CFrame:PointToObjectSpace(b.Position).Z end)
	for i, z in ipairs(spot[2]) do
		local p = parts[i]
		p.CFrame = short.CFrame * CFrame.new(spot[1].X, spot[1].Y, z) * TURN
		p.Anchored = true
	end
	for i = #spot[2] + 1, #parts do parts[i]:Destroy() end
end
table.insert(log, string.format("machines: 2 dispensers + 2 microwaves on the short bar (%d brought in from Workspace, %d copied)", brought, copied))

------------------------------------------------------------------ 2. stools on the deck, under the bar
local XS = { 6.25, 0.75, -4.75, -10.25 } -- along the long bar from its centre (east first)
local frontZ = long.Position.Z + long.Size.Z / 2 -- the room side (+z)
local stools, seats = {}, {}
for _, d in ipairs(S:GetChildren()) do
	if d:IsA("Model") and d.Name == "ClubStool" then table.insert(stools, d) end
	if d:IsA("Seat") and d.Name == "WindowStool" then table.insert(seats, d) end
end
table.sort(stools, function(a, b) return a:GetPivot().Position.X > b:GetPivot().Position.X end)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local skip = {}
for _, m in ipairs(stools) do table.insert(skip, m) end
for _, s in ipairs(seats) do table.insert(skip, s) end
params.FilterDescendantsInstances = skip
local moved = 0
for i, m in ipairs(stools) do
	local dx = XS[i]
	if not dx then break end
	local cf, size = m:GetBoundingBox()
	-- its seat (the nearest, within 3 studs) moves with it
	local seat, best = nil, 3
	for _, s in ipairs(seats) do
		local d = Vector2.new(s.Position.X - cf.X, s.Position.Z - cf.Z).Magnitude
		if d < best then seat, best = s, d end
	end
	-- (D-1253, user 2026-11-10: "편의점 의자 테이블에서 아주 약간만 떨어트리기") 0.4 → 0.9
	local x, z = long.Position.X + dx, frontZ + 0.9
	local hit = workspace:Raycast(Vector3.new(x, cf.Y + size.Y, z), Vector3.new(0, -20, 0), params)
	local floorY = if hit then hit.Position.Y else cf.Y - size.Y / 2
	local delta = Vector3.new(x - cf.X, floorY - (cf.Y - size.Y / 2), z - cf.Z)
	if delta.Magnitude > 0.01 then
		m:PivotTo(m:GetPivot() + delta)
		moved += 1
	end
	if seat then
		local ncf, nsize = m:GetBoundingBox()
		seat.CFrame = CFrame.new(ncf.X, ncf.Y + nsize.Y / 2 - seat.Size.Y / 2, ncf.Z) * seat.CFrame.Rotation
	end
end
table.insert(log, string.format("window stools: %d on the deck under the long bar (5.5 apart)", moved))
return table.concat(log, "\n")

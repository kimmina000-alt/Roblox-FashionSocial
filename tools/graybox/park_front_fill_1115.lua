--!nocheck
-- (D-1434, user 2026-11-15, a phone screenshot: "놀이공원 순위표 붙어 있는 벽 사이 공간 뜸 수정")
-- The park's raised platform (Hongdae_Layout.ParkRaise.ParkPlatform) ends at z -223.4 in the
-- place, while the ranking boards (RankingBoards, z -215.7) and the landing slab above reach
-- z -216: a 7.6-stud hollow under the slab, open from the west sidewalk. This fills it with the
-- platform's own stone, from the platform's west face to the stair wall (x -115.1), up to the
-- slab, so the boards sit on a solid wall. Run in Edit mode after park_raise (chain step);
-- idempotent ("ParkFrontFill" is remade, and nothing is added when there is no gap).

local raise = workspace:WaitForChild("Hongdae_Layout"):WaitForChild("ParkRaise")
local plat = raise:WaitForChild("ParkPlatform") :: BasePart
local FRONT_Z = -216 -- (park_raise LANDING_Z: the landing slab's and the boards' line)
local STAIR_WALL_X = -115.1 -- (the stair's west wall)

local old = raise:FindFirstChild("ParkFrontFill")
if old then old:Destroy() end
local cf, s = plat.CFrame, plat.Size
local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
local lo, hi = plat.Position - e / 2, plat.Position + e / 2
if hi.Z < FRONT_Z - 0.05 then
	local fill = plat:Clone()
	fill.Name = "ParkFrontFill"
	for _, c in ipairs(fill:GetChildren()) do c:Destroy() end
	fill.Size = Vector3.new(STAIR_WALL_X - lo.X, hi.Y - lo.Y, FRONT_Z - hi.Z)
	fill.CFrame = CFrame.new((lo.X + STAIR_WALL_X) / 2, (lo.Y + hi.Y) / 2, (hi.Z + FRONT_Z) / 2)
	fill.Parent = raise
	print(("[park_front_fill_1115] filled x %.1f..%.1f z %.1f..%.1f"):format(lo.X, STAIR_WALL_X, hi.Z, FRONT_Z))
else
	print("[park_front_fill_1115] no gap")
end

-- (D-1446, user 2026-11-15, a top view with two lines drawn: "땅 벌어짐 수정") the park floor had
-- two slots down to the street level: ParkPlatform (the user's edit, kept by user_map_snapshot)
-- starts at x -144.8 while ParkPlatformWest / its strip end at x -148 (a 3.2-wide slot from the
-- landing paving, z -279, to z -455.5), and it ends at z -447.8 while ParkPlatformNorth starts
-- at z -455.5 (a 7.7-wide slot along the whole platform). Both are filled with the same stone, top
-- level with the floor ("ParkSeamFill", remade each run).
for _, c in ipairs(raise:GetChildren()) do
	if c.Name == "ParkSeamFill" then c:Destroy() end
end
local function box(p: BasePart): (Vector3, Vector3)
	local c, sz = p.CFrame, p.Size
	local ext = (c.RightVector * sz.X):Abs() + (c.UpVector * sz.Y):Abs() + (c.LookVector * sz.Z):Abs()
	return p.Position - ext / 2, p.Position + ext / 2
end
local function seam(x0: number, z0: number, x1: number, z1: number)
	if x1 - x0 < 0.05 or z1 - z0 < 0.05 then return end
	local fill = plat:Clone()
	fill.Name = "ParkSeamFill"
	for _, c in ipairs(fill:GetChildren()) do c:Destroy() end
	fill.Size = Vector3.new(x1 - x0, hi.Y - lo.Y, z1 - z0)
	fill.CFrame = CFrame.new((x0 + x1) / 2, (lo.Y + hi.Y) / 2, (z0 + z1) / 2)
	fill.Parent = raise
	print(("[park_front_fill_1115] seam x %.1f..%.1f z %.1f..%.1f"):format(x0, x1, z0, z1))
end
local west = raise:FindFirstChild("ParkPlatformWest") :: BasePart?
local north = raise:FindFirstChild("ParkPlatformNorth") :: BasePart?
local landing = raise:FindFirstChild("ParkLandingPaving") :: BasePart?
local westX = lo.X
if west then
	local _, whi = box(west)
	westX = whi.X - 0.2
	local zTop = if landing then box(landing).Z else hi.Z -- (the landing paving's south edge, z -279)
	seam(westX, lo.Z, lo.X + 0.2, zTop)
end
if north then
	local _, nhi = box(north)
	seam(westX, nhi.Z - 0.2, hi.X, lo.Z + 0.2)
end
return true

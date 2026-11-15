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
return true

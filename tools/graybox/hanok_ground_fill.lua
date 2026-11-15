-- (D-1323, user 2026-11-12: "비어 있는 곳 땅 구현", photo of the empty brown triangle inside
-- the 한옥 마을 behind 광화문) The Hongdae_Layout.Ground slabs leave a hole x 47..277,
-- z 68..387 for the 광화문 front yard (terrain grass at y 0). With the PalaceBlockout gone
-- (the user chose: fill the ground only, no buildings), the part of the hole inside the
-- diagonal palace wall showed the void. Every 4-stud column there with nothing under it
-- gets terrain Grass from y -4 to 0, like the front yard next to it. Columns that already
-- hit something (terrain, the gate, the walls, the Ground slabs) are left alone, so it may
-- run again any time (it only fills what is still empty). Edit mode, command bar / MCP.

-- (D-1451, 2026-11-15 map check: along the map's south wall, z 384..386, a 2-stud slot went down
-- to the void over x 54..275: the column centres there (z 386) hit the invisible MapBoundary
-- wall, so the row was never filled. The rays now pass through the boundary walls and look at
-- three points across each column. The area also starts at z 48 now: behind the diagonal
-- palace wall, x 271..276 z 62..71, a small triangle against the east boundary wall was empty.)
local X0, X1, Z0, Z1 = 47, 277, 48, 387
local T = workspace.Terrain
local filled = 0
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local boundary = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("MapBoundary")
params.FilterDescendantsInstances = if boundary then { boundary } else {}
local function empty(cx: number, cz: number): boolean
	for _, d in ipairs({ -1.5, 0, 1.5 }) do
		for _, e in ipairs({ -1.5, 0, 1.5 }) do
			if not workspace:Raycast(Vector3.new(cx + d, 300, cz + e), Vector3.new(0, -400, 0), params) then return true end
		end
	end
	return false
end
for x = math.floor(X0 / 4) * 4, X1, 4 do
	for z = math.floor(Z0 / 4) * 4, Z1, 4 do
		local cx, cz = x + 2, z + 2
		if cx > X0 and cx < X1 and cz > Z0 and cz < Z1 then
			if empty(cx, cz) then
				T:FillBlock(CFrame.new(cx, -2, cz), Vector3.new(4, 4, 4), Enum.Material.Grass)
				filled += 1
			end
		end
	end
end
print("[HanokGroundFill] columns filled:", filled)
return filled

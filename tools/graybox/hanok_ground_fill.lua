-- (D-1323, user 2026-11-12: "비어 있는 곳 땅 구현", photo of the empty brown triangle inside
-- the 한옥 마을 behind 광화문) The Hongdae_Layout.Ground slabs leave a hole x 47..277,
-- z 68..387 for the 광화문 front yard (terrain grass at y 0). With the PalaceBlockout gone
-- (the user chose: fill the ground only, no buildings), the part of the hole inside the
-- diagonal palace wall showed the void. Every 4-stud column there with nothing under it
-- gets terrain Grass from y -4 to 0, like the front yard next to it. Columns that already
-- hit something (terrain, the gate, the walls, the Ground slabs) are left alone, so it may
-- run again any time (it only fills what is still empty). Edit mode, command bar / MCP.

local X0, X1, Z0, Z1 = 47, 277, 68, 387
local T = workspace.Terrain
local filled = 0
for x = math.floor(X0 / 4) * 4, X1, 4 do
	for z = math.floor(Z0 / 4) * 4, Z1, 4 do
		local cx, cz = x + 2, z + 2
		if cx > X0 and cx < X1 and cz > Z0 and cz < Z1 then
			local hit = workspace:Raycast(Vector3.new(cx, 300, cz), Vector3.new(0, -400, 0))
			if not hit then
				T:FillBlock(CFrame.new(cx, -2, cz), Vector3.new(4, 4, 4), Enum.Material.Grass)
				filled += 1
			end
		end
	end
end
print("[HanokGroundFill] columns filled:", filled)
return filled

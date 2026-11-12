-- (D-1328, user 2026-11-12, two photos of 한옥 마을 walls: "블록 감싸고 있는 벽 돌담벽으로
-- 구현하기") The user's own wall Parts round the 한옥 blocks (Workspace top level, 13.8 tall,
-- 2 thick, length along X) get the photo's look: square grey stone blocks in white mortar,
-- a white plaster band with two courses of dark bricks (texture from
-- tools/art/hanok_doldam_texture.py), and the palace wall's giwa coping (GiwaRoof unions
-- cloned from Hongdae_Layout, ~10 long each) along the top in Workspace.HanokStoneWalls.
-- The walls are renamed HanokStoneWall. Place-only; runs on its own any time (it rebuilds
-- only its own folder). The roofs on the blocks are Workspace.HanokRoofs (D-1328 too).

local TEX = "rbxassetid://84893447335088"
local giwa
for _, d in ipairs(workspace:WaitForChild("Hongdae_Layout"):GetDescendants()) do
	if d.Name == "GiwaRoof" and d:IsA("UnionOperation") and math.abs(d.Size.X - 10.03) < 0.1 then
		giwa = d
		break
	end
end
assert(giwa, "no GiwaRoof in Hongdae_Layout")
local old = workspace:FindFirstChild("HanokStoneWalls")
if old then old:Destroy() end
local F = Instance.new("Folder")
F.Name = "HanokStoneWalls"
local walls, mods = 0, 0
for _, p in ipairs(workspace:GetChildren()) do
	if p:IsA("Part") and (p.Name == "Part" or p.Name == "HanokStoneWall")
		and math.abs(p.Size.Y - 13.8) < 0.05 and math.abs(p.Size.Z - 2) < 0.05 then
		walls += 1
		p.Name = "HanokStoneWall"
		p.Color = Color3.fromRGB(232, 230, 222)
		p.Material = Enum.Material.SmoothPlastic
		for _, t in ipairs(p:GetChildren()) do
			if t:IsA("Texture") then t:Destroy() end
		end
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			local t = Instance.new("Texture")
			t.Texture = TEX
			t.Face = face
			t.StudsPerTileU = 9.2
			t.StudsPerTileV = p.Size.Y
			t.Parent = p
		end
		local L = p.Size.X
		local n = math.max(1, math.ceil(L / 10.03))
		local seg = L / n
		local top = p.CFrame * CFrame.new(0, p.Size.Y / 2 + 0.755, 0)
		for i = 1, n do
			local g = giwa:Clone()
			g.Name = "GiwaCoping"
			for _, c in ipairs(g:GetChildren()) do c:Destroy() end
			g.Size = Vector3.new(seg, giwa.Size.Y, giwa.Size.Z)
			g.CFrame = top * CFrame.new(-L / 2 + seg * (i - 0.5), 0, 0)
			g.Anchored = true
			g.CanCollide = false
			g.Parent = F
			mods += 1
		end
	end
end
F.Parent = workspace
print("[hanok_stonewall_1112] walls:", walls, "coping modules:", mods)
return walls

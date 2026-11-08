-- OH24: the store where the user moved it by hand, and the freezer case
-- filling its wall (D-1063, user 2026-11-09: "스튜디오에서 ... 편의점 수정한 거
-- 있어. 저장해." / "편의점 벽면에 냉동 선반 꽉 차게 확대해 줘").
--   1. the user dragged Hongdae_Layout.OH24Store by (-4.0, +0.6, -6.9) in Studio
--      (seen 2026-11-09: the north-east pier from (-56.65, 13.5, 65.8) to
--      (-60.65, 14.1, 58.9)); the same move here, so a rebuild keeps it. When the
--      store is already there (the place the user saved), nothing moves.
--   2. the wall freezer on the west inner wall (Cold* parts and the goods on
--      their shelves, ShelfRow) stretched along the wall from the north front
--      glass to the south inner wall and up to the ceiling (it was z 73..121 of a
--      wall z 59..139, 1.2..18.8 high under a 21.3 ceiling). Measured from the
--      store's own parts, so it does not care where the store stands.
-- Last step of the layout chain (after oh24_door_1109). Each part runs once
-- (attributes OH24Moved1109 / OH24Fridge1109 on OH24Store).

local L = workspace:FindFirstChild("Hongdae_Layout")
local S = L and L:FindFirstChild("OH24Store")
if not S then return "no OH24Store" end
local log = {}

-- 1. the move
if not S:GetAttribute("OH24Moved1109") then
	local MOVE = Vector3.new(-4.0, 0.6, -6.9)
	local before = Vector3.new(-56.65, 13.5, 65.8)
	local unmoved = false
	for _, d in ipairs(S:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "FacadePier" and (d.Position - before).Magnitude < 0.3 then unmoved = true end
	end
	if unmoved then
		S:PivotTo(S:GetPivot() + MOVE)
		table.insert(log, "store moved " .. tostring(MOVE))
	else
		table.insert(log, "store already where the user put it")
	end
	S:SetAttribute("OH24Moved1109", true)
end

-- 2. the freezer
if not S:GetAttribute("OH24Fridge1109") then
	local parts: {BasePart} = {}
	local x0, x1, y0, y1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	local function ext(p: BasePart): Vector3
		local h = p.CFrame:VectorToWorldSpace(p.Size) / 2
		return Vector3.new(math.abs(h.X), math.abs(h.Y), math.abs(h.Z))
	end
	for _, d in ipairs(S:GetChildren()) do
		if d:IsA("BasePart") and d.Name:match("^Cold") then
			table.insert(parts, d)
			local h = ext(d)
			x0, x1 = math.min(x0, d.Position.X - h.X), math.max(x1, d.Position.X + h.X)
			y0, y1 = math.min(y0, d.Position.Y - h.Y), math.max(y1, d.Position.Y + h.Y)
			z0, z1 = math.min(z0, d.Position.Z - h.Z), math.max(z1, d.Position.Z + h.Z)
		end
	end
	if #parts == 0 then return table.concat(log, "\n") .. "\nno freezer" end
	-- the goods standing on its shelves
	for _, d in ipairs(S:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "ShelfRow" and d.Position.X > x0 - 0.1 and d.Position.X < x1 + 0.1 and d.Position.Z > z0 and d.Position.Z < z1 then
			table.insert(parts, d)
		end
	end
	-- the wall run: the north glass and the south inner wall at this x, the ceiling
	local north, south, ceil = -math.huge, math.huge, math.huge
	local midX = (x0 + x1) / 2
	for _, d in ipairs(S:GetChildren()) do
		if d:IsA("BasePart") then
			local h = ext(d)
			local coversX = d.Position.X - h.X <= midX and d.Position.X + h.X >= midX
			if coversX and (d.Name == "FrontGlass" or d.Name == "InnerWall") and h.X > h.Z then
				if d.Position.Z < z0 then north = math.max(north, d.Position.Z + h.Z) end
				if d.Position.Z > z1 then south = math.min(south, d.Position.Z - h.Z) end
			end
			if d.Name == "Ceiling" and coversX then ceil = math.min(ceil, d.Position.Y - h.Y) end
		end
	end
	if north == -math.huge or south == math.huge or ceil == math.huge then
		return table.concat(log, "\n") .. "\nwall ends not found"
	end
	local Z0, Z1, Y1 = north + 0.15, south - 0.15, ceil - 0.15
	local kz, ky = (Z1 - Z0) / (z1 - z0), (Y1 - y0) / (y1 - y0)
	for _, p in ipairs(parts) do
		-- each piece: its place and its size along z / y stretched the same
		-- the factor for each local axis: kz if it runs along world z, ky along y
		local function factor(v: Vector3): number
			local w = p.CFrame:VectorToWorldSpace(v)
			if math.abs(w.Z) > 0.9 then return kz end
			if math.abs(w.Y) > 0.9 then return ky end
			return 1
		end
		local s = p.Size
		p.Size = Vector3.new(s.X * factor(Vector3.xAxis), s.Y * factor(Vector3.yAxis), s.Z * factor(Vector3.zAxis))
		local pos = p.Position
		p.CFrame = p.CFrame.Rotation + Vector3.new(pos.X, y0 + (pos.Y - y0) * ky, Z0 + (pos.Z - z0) * kz)
	end
	S:SetAttribute("OH24Fridge1109", true)
	table.insert(log, string.format("freezer z %.1f..%.1f → %.1f..%.1f, top %.1f → %.1f (%d parts)", z0, z1, Z0, Z1, y1, Y1, #parts))
end
return table.concat(log, "\n")

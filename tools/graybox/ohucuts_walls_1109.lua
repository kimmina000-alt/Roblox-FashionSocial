-- 오후네컷: photos on every straight inside wall (D-1094, user 2026-11-09:
-- "오후네컷 실내벽 아랫면도 사진 붙일 수 있게 수정. 오후네컷 실내벽 직면인 곳은 모두
-- 붙일 수 있게 해. e 사진 붙이기만 띄우지 말고").
-- Before only the curved wall's middle band (PhotoWall, key SHOP2, 8 high) took
-- photos. Now each straight inside wall gets a clear photo panel in front of
-- it, from just above the floor up to PANEL_TOP, tagged PhotoWall
-- (PhotoBoothService gives it the 사진 붙이기 prompt; PhotoWallController also
-- opens the album when the wall itself is tapped). The panels' Front face looks
-- into the room. Keys are fixed names (OHU_*), so stuck photos stay put when the
-- map is rebuilt. Runs every time (it puts its panels back the same way).
-- Last step of the layout chain (after oh24_store_1109).

local CS = game:GetService("CollectionService")
local F = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("OhuFourCuts")
if not F then return "no OhuFourCuts" end

local FLOOR_GAP, PANEL_TOP = 0.3, 16 -- studs above the wall's bottom / height of the top
local AWAY = 0.12 -- in front of the wall face (past the wainscot boards)

local old = F:FindFirstChild("OhuPhotoPanels")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "OhuPhotoPanels"
folder.Parent = F

-- the walls: name, a point near it (to tell same-named parts apart), which
-- way the room is (world X / Z sign), key
local WALLS = {
	{ "WallPink", Vector3.new(70.5, 0, -112.3), Vector3.new(0, 0, 1), "OHU_STUDIO_N" },
	{ "WallPink", Vector3.new(49.5, 0, -89.7), Vector3.new(1, 0, 0), "OHU_STUDIO_W" },
	{ "PinkWallN", Vector3.new(135.8, 0, -112.4), Vector3.new(0, 0, 1), "OHU_HALL_N" },
	{ "PinkWallS", Vector3.new(88.1, 0, -50.1), Vector3.new(0, 0, -1), "OHU_HALL_S" },
	{ "RoomWall", Vector3.new(130.5, 0, -63.8), Vector3.new(-1, 0, 0), "OHU_ROOM1_W" },
	{ "RoomWall", Vector3.new(130.5, 0, -63.8), Vector3.new(1, 0, 0), "OHU_ROOM1_E" },
	{ "RoomWall", Vector3.new(155.0, 0, -63.8), Vector3.new(-1, 0, 0), "OHU_ROOM2_W" },
	{ "RoomWall", Vector3.new(155.0, 0, -63.8), Vector3.new(1, 0, 0), "OHU_ROOM2_E" },
	{ "CorridorEndWall", Vector3.new(179.0, 0, -95.4), Vector3.new(-1, 0, 0), "OHU_HALL_E" },
}

local made = {}
for _, w in ipairs(WALLS) do
	local name, near, room, key = w[1], w[2], w[3], w[4]
	local best, bestD = nil, 6
	for _, d in ipairs(F:GetChildren()) do
		if d:IsA("BasePart") and d.Name == name then
			local dd = Vector2.new(d.Position.X - near.X, d.Position.Z - near.Z).Magnitude
			if dd < bestD then best, bestD = d, dd end
		end
	end
	if not best then
		table.insert(made, key .. " (wall not found)")
		continue
	end
	local s = best.Size
	-- the wall runs along X or Z (its long side), its thickness the other way
	local alongX = math.abs(room.Z) > 0.5
	local length = if alongX then s.X else s.Z
	local half = (if alongX then s.Z else s.X) / 2
	local bottom = best.Position.Y - s.Y / 2
	local top = math.min(best.Position.Y + s.Y / 2, bottom + PANEL_TOP)
	local h = top - bottom - FLOOR_GAP
	local centre = Vector3.new(best.Position.X, bottom + FLOOR_GAP + h / 2, best.Position.Z) + room * (half + AWAY)
	local p = Instance.new("Part")
	p.Name = "PhotoWall"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, true, false
	p.Transparency = 1
	p.Size = Vector3.new(length - 0.6, h, 0.2)
	-- Front (-Z of the part) toward the room
	p.CFrame = CFrame.lookAt(centre, centre + room)
	p:SetAttribute("WallKey", key)
	p:SetAttribute("Face", "Front")
	CS:AddTag(p, "PhotoWall")
	p.Parent = folder
	table.insert(made, string.format("%s %.1f x %.1f", key, p.Size.X, p.Size.Y))
end
return "photo panels: " .. table.concat(made, ", ")

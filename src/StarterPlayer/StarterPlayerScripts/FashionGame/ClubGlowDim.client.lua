--!strict
-- (D-1574, user 2026-11-17: "클럽 계단과 복도에 있는 조명 발광 수정 안 했으면 거기 발광도 줄여 줘")
-- The club's stair and corridor light lines (Neon parts made by build_main_social_graybox.lua and
-- club_locker_1103.lua) glow at part of their colour on this screen. Neon's glow and bloom follow
-- its colour. Client only: the place keeps the full colours and sizes (a part that streams in again
-- is changed again).
-- (D-1578, user 2026-11-17: "입구 조명 50으로 줄이고 클럽 복도에 조명선 더 얇게 하고 발광 50 높여")
-- the entrance door lights at 50 %; the corridor lines thinner (half as wide, half as tall) and at
-- 50 % instead of 30 %. Stair edges and the VIP stair hall ceiling stay at 30 %.
-- (D-1579, user 2026-11-17 with a shot of the white line by the VIP stair: "여기 흰색 선 더 얇게 하고
-- 발광 원래 발광으로 복구") the white passage line (PassageLight) at its full colour again and a
-- quarter as thick.

-- (D-1582, user 2026-11-17) corridor floor lines white instead of yellow; the white passage line
-- moved 1 stud onto the corridor wall's corner (the wall looked doubled: it stood on the hall wall's
-- end, set back from the corridor wall); the locker room door frame half as thick; the locker room
-- floor lines run into each other at the corners (no gaps); club walls and floors two tones lighter
-- (dark wall 26,26,29 and black marble 20,20,24 plus 22).

local LIGHTS: {[string]: {glow: number, thin: number?, white: boolean?, extend: number?}} = {
	-- stair edges (entrance stair, VIP stair), VIP stair hall ceiling
	StairNeon = { glow = 0.3 }, VIP_StairNeon = { glow = 0.3 }, CeilingStrip = { glow = 0.3 },
	-- corridor lines: foyer floor lines, corridor floor lines (white, D-1582), passage line
	FoyerLED = { glow = 0.5, thin = 0.5, white = true }, PassageLight = { glow = 1, thin = 0.25 },
	CorridorNeon_E = { glow = 0.5, thin = 0.5, white = true }, CorridorNeon_W = { glow = 0.5, thin = 0.5, white = true },
	FloorLED = { glow = 0.5, thin = 0.5, white = true }, HallDoorFootLED = { glow = 0.5, thin = 0.5, white = true },
	-- the street door's frame lights; the locker room door frame and floor lines
	StreetDoorLight = { glow = 0.5 },
	DoorFrameLight = { glow = 1, thin = 0.5 },
	WallLine = { glow = 1, extend = 0.3 },
}
local ROOTS = { "02_Club", "ClubAnnex" }
-- (D-1582) the vertical passage line's new place: on the west end of the corridor wall Corridor_E_S
-- (x 66.5 .. 96, z -275 .. -274), flush with its corridor face; the ceiling line across the corridor
-- mouth moves with it
local PASSAGE_X, PASSAGE_Z = 66.35, -274.84
-- (D-1582) club walls and floors: these colours get TONE_UP added on this screen
local TONE_UP = 22 / 255
local TONED = {
	["26,26,29"] = Enum.Material.SmoothPlastic, -- dark walls
	["20,20,24"] = Enum.Material.Marble, -- black marble floors
}

local done: {[BasePart]: boolean} = setmetatable({}, { __mode = "k" }) :: any

local function inClub(p: Instance): boolean
	for _, name in ipairs(ROOTS) do
		if p:FindFirstAncestor(name) then return true end
	end
	return false
end

-- a line lying on the floor (or along the ceiling): its narrow side across and its height shrink,
-- its length stays; it keeps touching the floor (or the ceiling) it was on
local function thin(p: BasePart, THIN: number)
	local s = p.Size
	local long = math.max(s.X, s.Y, s.Z)
	local new = Vector3.new(
		if s.X < long then s.X * THIN else s.X,
		if s.Y < long then s.Y * THIN else s.Y,
		if s.Z < long then s.Z * THIN else s.Z
	)
	-- keep the side nearest the floor / ceiling in place: move by half the height lost along the
	-- part's own up, towards the floor if it is low in the room (a ceiling line goes up)
	local lost = (s - new) * 0.5
	local up = p.CFrame.UpVector * lost.Y
	local ray = workspace:Raycast(p.Position, Vector3.new(0, -2, 0))
	local onFloor = ray ~= nil and ray.Instance ~= p
	p.Size = new
	p.CFrame = p.CFrame - (if onFloor then up else -up)
end

-- a line made longer by `by` at each end (corners meet; the ends hide in the walls)
local function extend(p: BasePart, by: number)
	local s = p.Size
	local long = math.max(s.X, s.Y, s.Z)
	p.Size = Vector3.new(
		if s.X == long then s.X + by * 2 else s.X,
		if s.Y == long then s.Y + by * 2 else s.Y,
		if s.Z == long then s.Z + by * 2 else s.Z
	)
end

local function movePassage(p: BasePart)
	local pos = p.Position
	if p.Size.Y > 10 then
		p.CFrame = p.CFrame.Rotation + Vector3.new(PASSAGE_X, pos.Y, PASSAGE_Z)
	else
		-- the ceiling line across the corridor mouth (along Z): same south end, north end at the post
		local cf, s = p.CFrame, p.Size
		local axis = if s.X >= s.Z then cf.RightVector else cf.LookVector
		local len = math.max(s.X, s.Z)
		local a, b = pos - axis * len / 2, pos + axis * len / 2
		local south = if a.Z < b.Z then a else b
		local north = Vector3.new(PASSAGE_X, pos.Y, PASSAGE_Z + 0.15)
		local southEnd = Vector3.new(PASSAGE_X, pos.Y, south.Z)
		local newLen = (north - southEnd).Magnitude
		p.Size = if s.X >= s.Z then Vector3.new(newLen, s.Y, s.Z) else Vector3.new(s.X, s.Y, newLen)
		p.CFrame = p.CFrame.Rotation + (north + southEnd) / 2
	end
end

local function dim(p: Instance)
	if not p:IsA("BasePart") or done[p] then return end
	local l = LIGHTS[p.Name]
	if not l or p.Material ~= Enum.Material.Neon or not inClub(p) then return end
	done[p] = true
	local base = if l.white then Color3.new(1, 1, 1) else p.Color
	p.Color = base:Lerp(Color3.new(), 1 - l.glow)
	if l.thin then thin(p, l.thin) end
	if l.extend then extend(p, l.extend) end
	if p.Name == "PassageLight" then movePassage(p) end
end

local function key(c: Color3): string
	return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end
local function tone(p: Instance)
	if not p:IsA("BasePart") or done[p] then return end
	local mat = TONED[key(p.Color)]
	if mat == nil or p.Material ~= mat or not inClub(p) then return end
	done[p] = true
	local c = p.Color
	p.Color = Color3.new(math.min(1, c.R + TONE_UP), math.min(1, c.G + TONE_UP), math.min(1, c.B + TONE_UP))
end

task.spawn(function()
	for _, d in ipairs(workspace:GetDescendants()) do
		dim(d)
		tone(d)
	end
end)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") then
		task.defer(function()
			dim(d)
			tone(d)
		end)
	end
end)

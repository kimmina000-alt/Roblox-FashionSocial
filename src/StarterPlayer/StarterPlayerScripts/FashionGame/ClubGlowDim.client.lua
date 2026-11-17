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

local LIGHTS: {[string]: {glow: number, thin: number?}} = {
	-- stair edges (entrance stair, VIP stair), VIP stair hall ceiling
	StairNeon = { glow = 0.3 }, VIP_StairNeon = { glow = 0.3 }, CeilingStrip = { glow = 0.3 },
	-- corridor lines: foyer floor lines, passage ceiling line, corridor floor lines
	FoyerLED = { glow = 0.5, thin = 0.5 }, PassageLight = { glow = 1, thin = 0.25 },
	CorridorNeon_E = { glow = 0.5, thin = 0.5 }, CorridorNeon_W = { glow = 0.5, thin = 0.5 },
	FloorLED = { glow = 0.5, thin = 0.5 }, HallDoorFootLED = { glow = 0.5, thin = 0.5 },
	-- the street door's frame lights
	StreetDoorLight = { glow = 0.5 },
}
local ROOTS = { "02_Club", "ClubAnnex" }

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

local function dim(p: Instance)
	if not p:IsA("BasePart") or done[p] then return end
	local l = LIGHTS[p.Name]
	if not l or p.Material ~= Enum.Material.Neon or not inClub(p) then return end
	done[p] = true
	p.Color = p.Color:Lerp(Color3.new(), 1 - l.glow)
	if l.thin then thin(p, l.thin) end
end

task.spawn(function()
	for _, d in ipairs(workspace:GetDescendants()) do dim(d) end
end)
workspace.DescendantAdded:Connect(function(d)
	if LIGHTS[d.Name] then task.defer(dim, d) end
end)

--!strict
-- (D-1574, user 2026-11-17: "클럽 계단과 복도에 있는 조명 발광 수정 안 했으면 거기 발광도 줄여 줘")
-- The club's stair and corridor light lines (Neon parts made by build_main_social_graybox.lua and
-- club_locker_1103.lua) glow at 30 % of their colour on this screen. Neon's glow and bloom follow
-- its colour. Client only: the place keeps the full colours (a part that streams in again is dimmed
-- again).

local GLOW = 0.3
local NAMES = {
	StairNeon = true, VIP_StairNeon = true, -- stair edges (entrance stair, VIP stair)
	FoyerLED = true, PassageLight = true, -- foyer floor lines, passage ceiling line
	CorridorNeon_E = true, CorridorNeon_W = true, FloorLED = true, HallDoorFootLED = true, -- corridor floor lines
	CeilingStrip = true, -- VIP stair hall ceiling
}
local ROOTS = { "02_Club", "ClubAnnex" }

local done: {[BasePart]: boolean} = setmetatable({}, { __mode = "k" }) :: any

local function inClub(p: Instance): boolean
	for _, name in ipairs(ROOTS) do
		if p:FindFirstAncestor(name) then return true end
	end
	return false
end

local function dim(p: Instance)
	if not p:IsA("BasePart") or not NAMES[p.Name] or done[p] then return end
	if p.Material ~= Enum.Material.Neon or not inClub(p) then return end
	done[p] = true
	p.Color = p.Color:Lerp(Color3.new(), 1 - GLOW)
end

task.spawn(function()
	for _, d in ipairs(workspace:GetDescendants()) do dim(d) end
end)
workspace.DescendantAdded:Connect(function(d)
	if NAMES[d.Name] then task.defer(dim, d) end
end)

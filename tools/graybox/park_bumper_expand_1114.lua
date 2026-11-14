-- (D-1415, user 2026-11-14, a top view with a red box east of the bumper car hall: "범퍼카 부지
-- 빨간선만큼 확장" (answered: the floor the cars drive on), and "현재 왼쪽 펜스는 길고 오른쪽 펜스는 짧게
-- 만들어 놨는데 서로 좌우 반전 준것처럼 위치 바꾸기. 바꾼 후의 긴 펜스를 입구로 해서 들어갈 수만 있게 하고
-- 나올 수 없게 해. 짧은 펜스 있는 곳은 들어갈 수 없고 나오기만 가능하게 구현.")
-- The bumper car hall (Hongdae_Layout.ParkBlockout["04_BumperCars"]) grows east: its east rail
-- moves from x -206.5 to x -156.2 (the cars' bounds: BumperCarConfig.Hall), the floor, the side
-- rails and the roof grow with it, the east posts move to the new corners.
-- The user's queue fences (loose FencePanel parts in Workspace, mirrored and moved east once by
-- hand / MCP, not by this script) now have the long entrance (corridor + two lanes) on the north
-- and the short exit on the south; the new east rail has two gaps:
--   entrance gap z -393..-387 (from the west lane into the hall), exit gap z -301.5..-295.5
--   (from the hall into the exit corridor), each with an invisible ramp over the floor's step.
-- One-way gates (invisible walls tagged "OneWayGate", attribute Allow = the direction you may
-- walk through; ParkOneWayController turns each one off for a player only on its "from" side):
--   the corridor's mouth (in only, -X), the entrance gap (in only, -X), the exit gap (out only, +X),
--   the exit corridor's mouth (out only, +X).
-- Model: Hongdae_Layout.BumperCarGates (rebuilt each run). The old queue model BumperCarQueue
-- (D-1407..D-1409) is removed. Idempotent (sizes / positions are set, not added).
-- Chain step: replaces park_bumper_queue_1114 (after park_playground_1114).

local CollectionService = game:GetService("CollectionService")
local layout = workspace:WaitForChild("Hongdae_Layout")
local hall = layout:WaitForChild("ParkBlockout"):WaitForChild("04_BumperCars")
local G = 16.2 -- ground top
local WEST = -277.53125 -- the west rail's centre (unchanged)
local EAST = -156.2 -- the new east rail's centre
local RAIL_T = 2.7
local Z_S, Z_N = -292.4168, -399.0106 -- the side rails' centres

local old = layout:FindFirstChild("BumperCarQueue")
if old then old:Destroy() end

-- floor, side rails, roof: from the west rail to past the new east rail
local floorEast = EAST + RAIL_T / 2
for _, p in ipairs(hall:GetChildren()) do
	if p:IsA("BasePart") then
		local yaw = p.Orientation.Y
		if p.Name == "Floor" then
			local len = floorEast - WEST
			p.Size = Vector3.new(p.Size.X, p.Size.Y, len)
			p.CFrame = CFrame.new((WEST + floorEast) / 2, p.Position.Y, p.Position.Z) * CFrame.Angles(0, math.rad(yaw), 0)
		elseif p.Name == "Roof" then
			local w, e = WEST - 2.2, floorEast + 2.2
			p.Size = Vector3.new(p.Size.X, p.Size.Y, e - w)
			p.CFrame = CFrame.new((w + e) / 2, p.Position.Y, p.Position.Z) * CFrame.Angles(0, math.rad(yaw), 0)
		elseif p.Name == "Rail" and (math.abs(p.Position.Z - Z_S) < 0.5 or math.abs(p.Position.Z - Z_N) < 0.5) then
			local len = floorEast - WEST
			p.Size = Vector3.new(p.Size.X, p.Size.Y, len)
			p.CFrame = CFrame.new((WEST + floorEast) / 2, p.Position.Y, p.Position.Z) * CFrame.Angles(0, math.rad(yaw), 0)
		elseif p.Name == "Post" and p.Position.X > -240 then
			p.CFrame = CFrame.new(EAST - 0.6, p.Position.Y, p.Position.Z) * CFrame.Angles(0, math.rad(yaw), 0)
		end
	end
end

-- the east rail: every old piece (x -206.5 or here) out, new pieces with the two gaps
local proto: BasePart? = nil
for _, r in ipairs(hall:GetChildren()) do
	if r:IsA("BasePart") and r.Name == "Rail" and (math.abs(r.Position.X + 206.5) < 0.6 or math.abs(r.Position.X - EAST) < 0.6) then
		proto = proto or r:Clone()
		r:Destroy()
	end
end
local ENTRANCE = { -393, -387 }
local EXIT = { -301.5, -295.5 }
if proto then
	for _, seg in ipairs({ { Z_N + 1.33, ENTRANCE[1] }, { ENTRANCE[2], EXIT[1] }, { EXIT[2], Z_S - 1.33 } }) do
		local p = (proto :: BasePart):Clone()
		p.Size = Vector3.new(RAIL_T, p.Size.Y, seg[2] - seg[1])
		p.CFrame = CFrame.new(EAST, p.Position.Y, (seg[1] + seg[2]) / 2)
		p.Parent = hall
	end
end

------------------------------------------------------------------ gaps: ramps and one-way gates
local oldGates = layout:FindFirstChild("BumperCarGates")
if oldGates then oldGates:Destroy() end
local M = Instance.new("Model")
M.Name = "BumperCarGates"

local function ramp(zc: number, width: number)
	-- (same build as the D-1407 ramps: up from the ground outside to the floor top 18 inside)
	local w = Instance.new("WedgePart")
	w.Name = "GapRamp"
	w.Anchored, w.Transparency = true, 1
	w.CanTouch = false
	w.Size = Vector3.new(width, 1.8, 3.5)
	w.CFrame = CFrame.new(EAST + 1.8, G + 0.9, zc) * CFrame.Angles(0, math.rad(90), 0)
	w.Parent = M
end
ramp((ENTRANCE[1] + ENTRANCE[2]) / 2, ENTRANCE[2] - ENTRANCE[1])
ramp((EXIT[1] + EXIT[2]) / 2, EXIT[2] - EXIT[1])

local function gate(name: string, x: number, z0: number, z1: number, allow: Vector3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = true -- (the client turns it off on the side you may come from)
	p.CanQuery, p.CanTouch, p.CastShadow = false, false, false
	p.Size = Vector3.new(0.4, 9, math.abs(z1 - z0))
	p.CFrame = CFrame.new(x, G + 4.5, (z0 + z1) / 2)
	p:SetAttribute("Allow", allow)
	CollectionService:AddTag(p, "OneWayGate")
	p.Parent = M
end
-- the long entrance: the corridor's mouth (east end, between its two fences) and the gap into the hall
gate("EntranceMouth", -91.6, -399.0, -390.1, Vector3.new(-1, 0, 0))
gate("EntranceGap", EAST, ENTRANCE[1], ENTRANCE[2], Vector3.new(-1, 0, 0))
-- the short exit: the gap out of the hall and the exit corridor's mouth
gate("ExitGap", EAST, EXIT[1], EXIT[2], Vector3.new(1, 0, 0))
gate("ExitMouth", -137.4, -303.0, -294.1, Vector3.new(1, 0, 0))

M.Parent = layout
print("[park_bumper_expand_1114] hall east to", EAST)
return EAST

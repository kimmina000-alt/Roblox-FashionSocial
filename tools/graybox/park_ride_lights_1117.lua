--!nocheck
-- 놀이기구 조명 줄 (D-1656 / D-1657, user 2026-11-17 with phone shots of the tea cups and the fire
-- truck ride at night: "회전컵 컵 아래 접시 둘레에 조명선 추가 / 소방차도 조명 추가").
--   * 회전컵: a thin warm-white neon ring round the edge of each cup's saucer (SaucerGlow, in the Cup
--     model, so it spins with the cup: ParkRidesController.moveModel picks up every part of the model);
--   * 소방차: the same ring round the outer edge of the round track (TrackGlow), and one round the
--     lawn in the middle (LawnGlow).
-- Each ring is a neon disc a little wider than the rim it sits under: only the band outside the rim
-- shows, from above and from the side. No collisions, no shadows. Safe to run again (old rings go first).
-- Run after park_fixes4_1117. (Place-only; save the place.)

local out = {}
local GLOW = Color3.fromRGB(255, 238, 205)

local function ring(name: string, under: BasePart, diameter: number, thick: number, parent: Instance)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = GLOW
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.Size = Vector3.new(thick, diameter, diameter)
	-- (a cylinder's axis is its X: the rim's "up"; the ring's top sits just under the rim's top)
	local up = under.CFrame.RightVector
	if up.Y < 0 then up = -up end
	local rimTop = under.Size.X / 2
	p.CFrame = under.CFrame + up * (rimTop - 0.04 - thick / 2)
	p.Parent = parent
	return p
end

---------------------------------------------------------------- 회전컵
local cups = workspace:FindFirstChild("회전컵")
local ride = cups and cups:FindFirstChild("Ride")
local n = 0
if ride then
	for _, cup in ipairs(ride:GetChildren()) do
		local rim = cup:IsA("Model") and cup:FindFirstChild("SaucerRim")
		if rim and rim:IsA("BasePart") then
			ring("SaucerGlow", rim, rim.Size.Y + 0.4, 0.22, cup)
			n += 1
		end
	end
end
table.insert(out, n .. " saucer rings")

---------------------------------------------------------------- 소방차
local truck = workspace:FindFirstChild("소방차")
if truck then
	local edge = truck:FindFirstChild("TrackEdge")
	if edge and edge:IsA("BasePart") then
		ring("TrackGlow", edge, edge.Size.Y + 0.5, 0.3, truck)
		table.insert(out, "track ring")
	end
	local lawn = truck:FindFirstChild("Lawn")
	if lawn and lawn:IsA("BasePart") then
		ring("LawnGlow", lawn, lawn.Size.Y + 0.4, 0.3, truck)
		table.insert(out, "lawn ring")
	end
end

print("[park_ride_lights_1117] " .. table.concat(out, "; "))
return table.concat(out, "; ")

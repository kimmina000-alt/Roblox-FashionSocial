--!nocheck
-- 놀이공원 야경 (D-1530, user 2026-11-16: "놀이공원 야경 화려하게 구현해"). The pieces ParkNightController
-- lights up at night:
--   * string lights between the park's lamps (ParkLampV2 inside the park): each lamp to its two nearest
--     neighbours 14..48 apart when nothing but trees stands between them, a sagging line of bulbs every
--     2.2 studs (tag "ParkNightBulb", attribute Seq = its place along the line, rainbow order) on a thin
--     dark wire, hung just under the lamp glass;
--   * four searchlights by the park's walls: a dark base, a lamp head (tag "ParkSearchlight", attribute
--     Phase) and an invisible BeamEnd the controller swings through the sky, a soft wide Beam between them
--     (off by day).
-- Model Workspace.놀이공원야경 (rebuilt each run).

local CS = game:GetService("CollectionService")
local G = 16.11
local PARK_LO, PARK_HI = Vector3.new(-268, 0, -770), Vector3.new(-48, 0, -279)
local STEP = 2.2
local PALETTE = {
	Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 230, 60), Color3.fromRGB(90, 230, 110),
	Color3.fromRGB(60, 190, 255), Color3.fromRGB(150, 110, 255), Color3.fromRGB(255, 100, 210),
}

local old = workspace:FindFirstChild("놀이공원야경")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "놀이공원야경"
local strings = Instance.new("Model")
strings.Name = "StringLights"
strings.Parent = root

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

---------------------------------------------------------------- the lamps and the lines between them
local lamps = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d.Name == "ParkLampV2" then
		local p = d:GetPivot().Position
		if p.X > PARK_LO.X and p.X < PARK_HI.X and p.Z > PARK_LO.Z and p.Z < PARK_HI.Z then
			local glass = d:FindFirstChild("LampGlass", true)
			local y = if glass and glass:IsA("BasePart") then glass.Position.Y - glass.Size.Y / 2 - 0.8 else G + 20
			table.insert(lamps, { model = d, at = Vector3.new(p.X, y, p.Z) })
		end
	end
end
local function clear(a: Vector3, b: Vector3, skip: {Instance}): boolean
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	local from = a
	for _ = 1, 6 do
		local r = workspace:Raycast(from, b - from, rp)
		if not r then return true end
		local tree = r.Instance:FindFirstAncestor("FallingBlossomCherryTree") or r.Instance.Name:find("Leaves") or r.Instance.Name:find("Hedge") or r.Instance.Name:find("Bush")
		if not tree then return false end
		table.insert(skip, r.Instance)
		rp.FilterDescendantsInstances = skip
	end
	return true
end
local pairsDone = {}
local lines = {}
for i, l in ipairs(lamps) do
	local near = {}
	for j, m in ipairs(lamps) do
		local d = (Vector3.new(m.at.X, 0, m.at.Z) - Vector3.new(l.at.X, 0, l.at.Z)).Magnitude
		-- (the east wall's lamps stand 88 apart: they are joined along the wall; elsewhere up to 60)
		local alongEast = math.abs(m.at.X + 56) < 3 and math.abs(l.at.X + 56) < 3
		if j ~= i and d >= 14 and d <= (if alongEast then 92 else 60) then table.insert(near, { j = j, d = d }) end
	end
	table.sort(near, function(a, b) return a.d < b.d end)
	local k = 0
	for _, n in ipairs(near) do
		if k >= 2 then break end
		local key = math.min(i, n.j) .. "-" .. math.max(i, n.j)
		if not pairsDone[key] then
			if clear(l.at, lamps[n.j].at, { l.model, lamps[n.j].model }) then
				pairsDone[key] = true
				table.insert(lines, { l.at, lamps[n.j].at })
				k += 1
			end
		else
			k += 1
		end
	end
end

-- the entry plaza's canopy: a tall pole with a star in the middle of the plaza inside the gate and eight
-- short poles round it, a string from the top to each
local PLAZA, RING, TALL, SHORT = Vector3.new(-108, G, -317), 18, 24, 13
local poles = Instance.new("Model")
poles.Name = "Poles"
poles.Parent = root
local DARK = Color3.fromRGB(45, 45, 55)
part(poles, "CanopyPole", Vector3.new(0.9, TALL, 0.9), CFrame.new(PLAZA + Vector3.new(0, TALL / 2, 0)), DARK, Enum.Material.Metal)
part(poles, "CanopyFoot", Vector3.new(1.4, 2.6, 2.6), CFrame.new(PLAZA + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
local star = part(poles, "CanopyStar", Vector3.new(2.2, 2.2, 2.2), CFrame.new(PLAZA + Vector3.new(0, TALL + 1.2, 0)), Color3.fromRGB(255, 225, 80), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
CS:AddTag(star, "NightGlow")
local topAt = PLAZA + Vector3.new(0, TALL - 0.5, 0)
for k = 0, 7 do
	local a = k * math.pi / 4
	local at = PLAZA + Vector3.new(math.cos(a), 0, math.sin(a)) * RING
	part(poles, "RingPole", Vector3.new(0.5, SHORT, 0.5), CFrame.new(at + Vector3.new(0, SHORT / 2, 0)), DARK, Enum.Material.Metal)
	local cap = part(poles, "RingCap", Vector3.new(0.9, 0.9, 0.9), CFrame.new(at + Vector3.new(0, SHORT + 0.3, 0)), Color3.fromRGB(255, 240, 200), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	CS:AddTag(cap, "NightGlow")
	table.insert(lines, { topAt, at + Vector3.new(0, SHORT - 0.3, 0) })
end

-- (the wire: Beams from bulb to bulb, not parts: D-1532, ~360 fewer parts. Each bulb holds the wire's
-- attachment 0.4 above its centre; a line's two ends hang from a tiny invisible WireEnd.)
local seq = 0
local nBulbs = 0
local function wire(a0: Attachment, a1: Attachment)
	local w = Instance.new("Beam")
	w.Name = "Wire"
	w.Attachment0, w.Attachment1 = a0, a1
	w.Width0, w.Width1 = 0.08, 0.08
	w.Color = ColorSequence.new(Color3.fromRGB(35, 35, 40))
	w.Transparency = NumberSequence.new(0)
	w.FaceCamera, w.Segments, w.LightInfluence = true, 1, 1
	w.Parent = a0.Parent
end
for _, ln in ipairs(lines) do
	local a, b = ln[1], ln[2]
	local L = (b - a).Magnitude
	local sag = 0.1 * L
	local n = math.max(3, math.floor(L / STEP))
	local prev: Attachment? = nil
	for k = 0, n do
		local t = k / n
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		local holder
		if k > 0 and k < n then
			seq += 1
			holder = part(strings, "Bulb", Vector3.new(0.8, 0.8, 0.8), CFrame.new(p - Vector3.new(0, 0.4, 0)), PALETTE[seq % #PALETTE + 1], nil, Enum.PartType.Ball)
			holder:SetAttribute("Seq", seq)
			CS:AddTag(holder, "ParkNightBulb")
			nBulbs += 1
		else
			holder = part(strings, "WireEnd", Vector3.new(0.1, 0.1, 0.1), CFrame.new(p), Color3.new(0, 0, 0))
			holder.Transparency = 1
		end
		local at = Instance.new("Attachment")
		at.WorldPosition = p
		at.Parent = holder
		at.WorldPosition = p
		if prev then wire(prev, at) end
		prev = at
	end
end

---------------------------------------------------------------- the searchlights
-- (on the park wall's corner pillars: the spire nearest each corner, the rig standing on its tip)
local CORNERS = { { Vector3.new(-264, 0, -769), 0 }, { Vector3.new(-52, 0, -769), 1.6 }, { Vector3.new(-52, 0, -336), 3.2 }, { Vector3.new(-182, 0, -336), 4.7 } }
local SPOTS = {}
local gate = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("AmusementParkGate")
for _, c in ipairs(CORNERS) do
	local best, bestD
	for _, d in ipairs(gate and gate:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == "ParkPillarSpire" then
			local dd = (Vector3.new(d.Position.X, 0, d.Position.Z) - c[1]).Magnitude
			if not bestD or dd < bestD then best, bestD = d, dd end
		end
	end
	if best then
		local e = (best.CFrame.RightVector * best.Size.X):Abs() + (best.CFrame.UpVector * best.Size.Y):Abs() + (best.CFrame.LookVector * best.Size.Z):Abs()
		table.insert(SPOTS, { Vector3.new(best.Position.X, best.Position.Y + e.Y / 2, best.Position.Z), c[2] })
	end
end
for i, s in ipairs(SPOTS) do
	local rig = Instance.new("Model")
	rig.Name = "Searchlight" .. i
	local at = s[1]
	part(rig, "Base", Vector3.new(1.2, 3.2, 3.2), CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 42, 50), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(rig, "Post", Vector3.new(0.6, 2.4, 0.6), CFrame.new(at + Vector3.new(0, 2.2, 0)), Color3.fromRGB(40, 42, 50), Enum.Material.Metal)
	local head = part(rig, "Head", Vector3.new(1.8, 1.8, 1.8), CFrame.new(at + Vector3.new(0, 3.9, 0)), Color3.fromRGB(235, 240, 255), Enum.Material.Neon, Enum.PartType.Ball)
	head:SetAttribute("Phase", s[2])
	local endPart = part(rig, "BeamEnd", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at + Vector3.new(0, 200, 0)), Color3.new(1, 1, 1))
	endPart.Transparency = 1
	local a0 = Instance.new("Attachment", head)
	local a1 = Instance.new("Attachment", endPart)
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 3, 26
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	-- (white-blue, pink, sky, gold: one colour each)
	local BEAMS = { Color3.fromRGB(210, 230, 255), Color3.fromRGB(255, 120, 220), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 210, 90) }
	beam.Color = ColorSequence.new(BEAMS[(i - 1) % #BEAMS + 1])
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	-- (on every screen from the start: the far corners were not streamed in to a player at the gate)
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = head
	CS:AddTag(head, "ParkSearchlight")
	rig.Parent = root
end

root.Parent = workspace
print(("[park_night_1116] %d lamps, %d lines, %d bulbs, %d searchlights"):format(#lamps, #lines, nBulbs, #SPOTS))
return ("%d lamps, %d lines, %d bulbs"):format(#lamps, #lines, nBulbs)

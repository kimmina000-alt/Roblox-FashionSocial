--!nocheck
-- 놀이공원 손질 2 (D-1516 / D-1519, user 2026-11-16: "땅 확인", "미니바이킹 단상 위에 있는 펜스는 회색 메탈
-- 재질로 변경", "범퍼카 출입구 동쪽으로 옮기기", "회전컵 계단, 펜스 확인").
--   * the strip between the sea road's end (z -275) and the park platform (z -278.74), x -182..-153,
--     had no paving (the bare ground 0.6 under the promenade): Hongdae_Layout.PromenadeParkFill, brick
--     like the promenade;
--   * mini viking: its fence panels standing on the deck (bottom over 19) grey metal;
--   * tea cups: D-1515 put the filled gap's panels half a step off the fence's grid (i / N) and the
--     stairs half a step off their gaps: panels back on the grid, stairs again in the middle of each gap
--     and as wide as it (their sides meet the panels' ends);
--   * bumper cars: the south rail's yellow panels and rubber band laid again round the entrance's new
--     gap at x -95 (park_bumper_big_1116 ENT_X; the marquee moves with it in park_bumper_dress_1115).
-- Run after park_cups_truck_gates_1116 and park_bumper_dress_1115. Idempotent.

local o = {}

-- the promenade strip
do
	local L = workspace:FindFirstChild("Hongdae_Layout")
	local proto
	for _, c in ipairs(L and L:GetChildren() or {}) do
		if c.Name == "Promenade" and c:IsA("BasePart") then proto = c break end
	end
	if proto then
		local old = L:FindFirstChild("PromenadeParkFill")
		if old then old:Destroy() end
		local p = Instance.new("Part")
		p.Name = "PromenadeParkFill"
		p.Material, p.Color, p.MaterialVariant = proto.Material, proto.Color, proto.MaterialVariant
		p.Anchored, p.CastShadow = true, false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Size = Vector3.new(29, 0.6, 3.9)
		p.CFrame = CFrame.new(-167.5, 0.3, -276.79)
		p.Parent = L
		table.insert(o, "promenade strip")
	end
end

-- the mini viking's deck fences
do
	local f = workspace:FindFirstChild("미니바이킹") and workspace["미니바이킹"]:FindFirstChild("Fences")
	local n = 0
	for _, p in ipairs(f and f:GetChildren() or {}) do
		if p.Name == "FencePanel" and p.Position.Y - p.Size.Y / 2 > 19 then
			p.Material = Enum.Material.Metal
			p.Color = Color3.fromRGB(163, 168, 176)
			n += 1
		end
	end
	table.insert(o, ("deck fences %d"):format(n))
end

-- the tea cups' fence on its grid, the stairs on the gaps
do
	local cups = workspace:FindFirstChild("회전컵")
	local base = cups and cups:FindFirstChild("Base")
	local fence = cups and cups:FindFirstChild("Fence")
	if base and fence then
		local C = Vector3.new(base.Position.X, 0, base.Position.Z)
		local Rr = base.Size.Y / 2 + 2
		local N = math.floor(2 * math.pi * Rr / 8.1)
		local step = 2 * math.pi / N
		local function idx(p: BasePart): number
			local d = Vector3.new(p.Position.X, 0, p.Position.Z) - C
			return (math.atan2(d.Z, d.X) % (2 * math.pi)) / step
		end
		for _, p in ipairs(fence:GetChildren()) do
			local f = idx(p)
			if math.abs(f - math.floor(f + 0.5)) > 0.25 then
				local a = math.floor(f) * step
				local pos = C + Vector3.new(math.cos(a), 0, math.sin(a)) * Rr
				local at = Vector3.new(pos.X, p.Position.Y, pos.Z)
				p.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0, math.cos(a)))
			end
		end
		local have = {}
		for _, p in ipairs(fence:GetChildren()) do
			if p.Name == "FencePanel" then have[math.floor(idx(p) + 0.5) % N] = true end
		end
		local groups = {}
		for i = 0, N - 1 do
			if not have[i] then
				local g = groups[#groups]
				if g and (i - g[#g]) % N == 1 then table.insert(g, i) else table.insert(groups, { i }) end
			end
		end
		local st = cups:FindFirstChild("Stairs") or Instance.new("Model")
		st.Name = "Stairs"
		st:ClearAllChildren()
		st.Parent = cups
		local top = base.Position.Y + base.Size.X / 2
		local G = 16.11
		for _, g in ipairs(groups) do
			local a0 = (g[1] - 1) * step + step / 2
			local a1 = (g[#g] + 1) * step - step / 2
			local amid = (a0 + a1) / 2
			local out = Vector3.new(math.cos(amid), 0, math.sin(amid))
			local W = 2 * Rr * math.sin((a1 - a0) / 2) + 0.6
			local R0 = base.Size.Y / 2
			local H = top - G
			local n, dd = 3, 1.7
			for k = 1, n do
				local c = C + out * (R0 + (n - k + 0.5) * dd)
				local h = H / n * k
				local s = Instance.new("Part")
				s.Name = "Step"
				s.Anchored = true
				s.Size = Vector3.new(W, h, dd)
				local at = Vector3.new(c.X, G + h / 2, c.Z)
				s.CFrame = CFrame.lookAt(at, at + out)
				s.Color, s.Material = base.Color, base.Material
				s.TopSurface = Enum.SurfaceType.Smooth
				s.Parent = st
			end
			local c = C + out * (R0 + n * dd / 2)
			local w = Instance.new("WedgePart")
			w.Name = "StepRamp"
			w.Anchored, w.Transparency, w.CastShadow, w.CanTouch = true, 1, false, false
			w.Size = Vector3.new(W, H, n * dd)
			local at = Vector3.new(c.X, G + H / 2, c.Z)
			w.CFrame = CFrame.lookAt(at, at + out)
			w.Parent = st
		end
		table.insert(o, ("tea cups: %d stairs"):format(#groups))
	end
end

-- the bumper hall's south panels round the entrance
do
	local hall = workspace:FindFirstChild("범퍼")
	local dress = hall and hall:FindFirstChild("ArenaDress")
	local area = hall and hall:FindFirstChild("04_BumperCars")
	local PANEL = game:GetService("ServerStorage").ArtAssets:FindFirstChild("YellowFencePanel")
	if dress and area and PANEL then
		local floor = area.Floor
		local FY = floor.Position.Y + floor.Size.Y / 2
		local Z1 = floor.Position.Z + floor.Size.Z / 2
		for _, p in ipairs(dress:GetChildren()) do
			if (p.Name == "FencePanel" or p.Name == "RubberBand") and math.abs(p.Position.Z - Z1) < 1.5 then
				local e = (p.CFrame.RightVector * p.Size.X):Abs() + (p.CFrame.LookVector * p.Size.Z):Abs()
				if e.X > e.Z then p:Destroy() end
			end
		end
		local n = 0
		for _, r in ipairs(area:GetChildren()) do
			if r.Name == "Rail" and math.abs(r.Position.Z - Z1) < 0.5 and r.Size.X > r.Size.Z then
				local lo, hi, c = r.Position - r.Size / 2, r.Position + r.Size / 2, r.Position
				local rb = Instance.new("Part")
				rb.Name = "RubberBand"
				rb.Size = Vector3.new(r.Size.X, 1.6, 0.5)
				rb.CFrame = CFrame.new(c.X, FY + 1.1, lo.Z - 0.25)
				rb.Color, rb.Material = Color3.fromRGB(24, 24, 28), Enum.Material.Rubber
				rb.Anchored, rb.CanCollide, rb.CanTouch, rb.CanQuery = true, false, false, false
				rb.Parent = dress
				local a, b = Vector3.new(lo.X, FY, c.Z), Vector3.new(hi.X, FY, c.Z)
				local L, u, PL = (b - a).Magnitude, (b - a).Unit, PANEL.Size.Z
				local k = math.max(1, math.ceil(L / PL - 0.02))
				for i = 0, k - 1 do
					local t = if k == 1 then L / 2 else PL / 2 + (L - PL) * i / (k - 1)
					local m = a + u * t
					local q = PANEL:Clone()
					q.Name = "FencePanel"
					q.CFrame = CFrame.lookAt(m, m + u) * CFrame.new(if n % 2 == 0 then 0.03 else -0.03, PANEL.Size.Y / 2, 0)
					q.Anchored, q.CanCollide, q.CanTouch, q.CanQuery = true, false, false, false
					q.Parent = dress
					n += 1
				end
			end
		end
		table.insert(o, ("bumper south panels %d"):format(n))
	end
end

print("[park_fixes2_1116] " .. table.concat(o, "; "))
return table.concat(o, "; ")

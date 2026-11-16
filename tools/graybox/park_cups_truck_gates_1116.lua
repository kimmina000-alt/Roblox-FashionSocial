--!nocheck
-- 회전컵 펜스 · 계단, 소방차 1.3배, 바이킹 출입구 (D-1515, user 2026-11-16: "회전컵 펜스 표시한 부분 채우기.
-- 펜스 없는 부분에 단상 올라갈 수 있는 계단 한 칸씩", "소방차 크기 1.3배", "슈퍼바이킹 출입구 펜스도 미니바이킹
-- 출입구 펜스 기능 적용 / 미니바이킹 위치 수정하면서 입구 펜스 열릴 때 펜스 위치 엉뚱한 곳으로 감").
--   * tea cups: the fence gap toward the north-east (the one the user marked) gets its two panels; at
--     each other gap three steps up to the deck (20.94, 4.8 over the paving) + an invisible wedge to walk
--     on (회전컵.Stairs);
--   * fire truck (Workspace.소방차, a ParkCarousel): ScaleTo 1.3 with its north-west corner and the ground
--     kept, fence panels at their own height, Radius / SaddleY × 1.3;
--   * mini viking entrance leaf: Hinge set again on the closed leaf's -z end (the ride was moved by hand,
--     the hinge had stayed, so the leaf opened somewhere else); OrigCFrame moved with it;
--   * super viking like the mini viking: the entrance leaf opens to the same diagonal (OpenYaw 0.98), the
--     exit has no leaf (only its invisible one-way Block).
-- The flower bed by the gate (Workspace.꽃밭, Creator Store 131216077381773 "Flower Bed", its two
-- scripts deleted, scale 0.7, x -179.8..-170.6 z -296.2..-287.0) is place-only.
-- Idempotent.

local o = {}
local function ext(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size
	local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
	return p.Position - e / 2, p.Position + e / 2
end
local function bb(m: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local a, b = ext(p)
			lo, hi = lo:Min(a), hi:Max(b)
		end
	end
	return lo, hi
end

---------------------------------------------------------------- the fire truck
do
	local m = workspace:FindFirstChild("소방차")
	if m and m:GetScale() < 1.29 then
		local lo0 = bb(m)
		local fences = {}
		for _, p in ipairs(m:GetChildren()) do
			if p.Name == "FencePanel" or p.Name == "FenceWall" then fences[p] = p.Size.Y end
		end
		m:ScaleTo(1.3)
		for p, h in pairs(fences) do
			local bottom = p.Position.Y - p.Size.Y / 2
			p.Size = Vector3.new(p.Size.X, h, p.Size.Z)
			p.CFrame += Vector3.new(0, bottom + h / 2 - p.Position.Y, 0)
		end
		local lo1 = bb(m)
		m:PivotTo(m:GetPivot() + (lo0 - lo1))
		for _, k in ipairs({ "Radius", "SaddleY" }) do m:SetAttribute(k, m:GetAttribute(k) * 1.3) end
		table.insert(o, "fire truck x1.3")
	end
end

---------------------------------------------------------------- the tea cups
do
	local cups = workspace:FindFirstChild("회전컵")
	local base = cups and cups:FindFirstChild("Base")
	local fence = cups and cups:FindFirstChild("Fence")
	if base and fence then
		local C = Vector3.new(base.Position.X, 0, base.Position.Z)
		local Rr = base.Size.Y / 2 + 2
		local N = math.floor(2 * math.pi * Rr / 8.1)
		local chord = 2 * Rr * math.sin(math.pi / N)
		local have = {}
		local tmpl, wallT
		for _, p in ipairs(fence:GetChildren()) do
			if p.Name == "FencePanel" then
				local d = Vector3.new(p.Position.X, 0, p.Position.Z) - C
				have[math.floor((math.atan2(d.Z, d.X) % (2 * math.pi)) / (2 * math.pi) * N + 0.5) % N] = true
				tmpl = p
			elseif p.Name == "FenceWall" then
				wallT = p
			end
		end
		local groups = {}
		for i = 0, N - 1 do
			if not have[i] then
				local g = groups[#groups]
				if g and (i - g[#g]) % N == 1 then table.insert(g, i) else table.insert(groups, { i }) end
			end
		end
		if #groups > 1 and (groups[1][1] - groups[#groups][#groups[#groups]]) % N == 1 then
			for _, i in ipairs(groups[1]) do table.insert(groups[#groups], i) end
			table.remove(groups, 1)
		end
		local top = base.Position.Y + base.Size.X / 2
		local G = 16.11
		local old = cups:FindFirstChild("Stairs")
		if old then old:Destroy() end
		local st = Instance.new("Model")
		st.Name = "Stairs"
		st.Parent = cups
		for _, g in ipairs(groups) do
			local amid = 0
			for _, i in ipairs(g) do amid += (i + 0.5) / N * 2 * math.pi end
			amid /= #g
			local deg = math.deg(math.atan2(math.sin(amid), math.cos(amid)))
			if math.abs(deg + 45) < 20 then
				for _, i in ipairs(g) do
					local a = (i + 0.5) / N * 2 * math.pi
					local pos = C + Vector3.new(math.cos(a), 0, math.sin(a)) * Rr
					local tan = Vector3.new(-math.sin(a), 0, math.cos(a))
					for _, t in ipairs({ tmpl, wallT }) do
						local p = t:Clone()
						local at = Vector3.new(pos.X, t.Position.Y, pos.Z)
						p.CFrame = CFrame.lookAt(at, at + tan)
						p.Parent = fence
					end
				end
				table.insert(o, "fence gap filled")
			else
				local out = Vector3.new(math.cos(amid), 0, math.sin(amid))
				local R0 = base.Size.Y / 2
				local W = #g * chord - 3
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
				local run = n * dd
				local c = C + out * (R0 + run / 2)
				local w = Instance.new("WedgePart") -- (rises to its +Z: +Z points in, to the deck)
				w.Name = "StepRamp"
				w.Anchored, w.Transparency, w.CastShadow, w.CanTouch = true, 1, false, false
				w.Size = Vector3.new(W, H, run)
				local at = Vector3.new(c.X, G + H / 2, c.Z)
				w.CFrame = CFrame.lookAt(at, at + out)
				w.Parent = st
				table.insert(o, ("stairs at %.0f°"):format(deg))
			end
		end
	end
end

---------------------------------------------------------------- the viking gates
do
	local mini = workspace:FindFirstChild("미니바이킹")
	local leaf = mini and mini:FindFirstChild("Gates") and mini.Gates:FindFirstChild("Entrance") and mini.Gates.Entrance:FindFirstChild("Leaf1")
	local panel = leaf and leaf:FindFirstChild("DiagPanel")
	local h = leaf and leaf:GetAttribute("Hinge")
	if panel and typeof(h) == "CFrame" then
		local e1 = panel.Position + panel.CFrame.LookVector * panel.Size.Z / 2
		local e2 = panel.Position - panel.CFrame.LookVector * panel.Size.Z / 2
		local e = if e1.Z < e2.Z then e1 else e2
		local newH = CFrame.new(e.X, h.Position.Y, e.Z) * h.Rotation
		local d = newH.Position - h.Position
		if d.Magnitude > 0.05 then
			leaf:SetAttribute("Hinge", newH)
			local oc = panel:GetAttribute("OrigCFrame")
			if typeof(oc) == "CFrame" then panel:SetAttribute("OrigCFrame", oc + d) end
			table.insert(o, "mini viking hinge moved")
		end
	end
	local sv = workspace:FindFirstChild("슈퍼바이킹")
	local gs = sv and sv:FindFirstChild("Gates")
	if gs and leaf then
		local ent = gs:FindFirstChild("Entrance") and gs.Entrance:FindFirstChild("Leaf1")
		-- (+: a leaf along +x from its hinge turns to -z, into the ride)
		if ent then ent:SetAttribute("OpenYaw", math.abs(leaf:GetAttribute("OpenYaw"))) end
		local ex = gs:FindFirstChild("Exit") and gs.Exit:FindFirstChild("Leaf1")
		if ex then ex:Destroy() end
		table.insert(o, "super viking gates")
	end
end

print("[park_cups_truck_gates_1116] " .. table.concat(o, "; "))
return table.concat(o, "; ")

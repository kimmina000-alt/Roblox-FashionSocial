--!nocheck
-- 놀이공원 가로등 + 벤치 = 사용자 모델 (D-1493, user 2026-11-16: "벤치랑 가로등 이걸로 교체해 / 가로등
-- 오래된 느낌의 엔틱한 재질로 하되 사진에 선택한 부분은 하얀 조명으로 / 벤치는 양쪽 다리는 검은색 꺼끌한
-- 재질로 하고 가운데 앉는 부분은 우드로").
-- Sources (place only): ServerStorage.ArtAssets.ParkLampMesh (LampBody + LampGlass) and
-- ParkBenchMesh (BenchLegs + BenchSeat): the user's street lamp.glb / Bench.glb split by material
-- (D:\Roblox\오후\3D 물\split, glass = the wide panes of the lantern, seat = the three planks).
-- Every "ParkLamp" and "Park Bench|공원 벤치" model in Workspace.놀이공원길 and Workspace.놀이터 is
-- replaced in place: same ground point, the lamp as tall as the old one, the bench as long as the old
-- one along the old seat's long side. The lamp keeps the old lamp's PointLight (moved into the
-- glass). Run after park_paths_1116 / park_playground_1116 (which build the old ones). Idempotent:
-- the new models are named ParkLampV2 / ParkBenchV2 and are left alone.

local ART = game.ServerStorage:FindFirstChild("ArtAssets")
local LAMP = ART and ART:FindFirstChild("ParkLampMesh")
local BENCH = ART and ART:FindFirstChild("ParkBenchMesh")
assert(LAMP and BENCH, "ServerStorage.ArtAssets.ParkLampMesh / ParkBenchMesh missing (the user's imports)")

local BRONZE = Color3.fromRGB(92, 68, 48) -- (D-1495: the reference photo's brown bronze)
-- (D-1495, user: "가로등 크기 2배 키우기") lamps stand LAMP_HEIGHT high (twice the old 12.15)
local LAMP_HEIGHT = 24.3
local GLASS = Color3.fromRGB(255, 252, 240)
local LEGS = Color3.fromRGB(28, 28, 30)
local WOOD = Color3.fromRGB(150, 98, 58)

local function aabb(list: {BasePart}): (Vector3, Vector3)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in ipairs(list) do
		local cf, s = p.CFrame, p.Size
		local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
		lo = lo:Min(p.Position - e / 2)
		hi = hi:Max(p.Position + e / 2)
	end
	return lo, hi
end
local function partsOf(m: Instance): {BasePart}
	local t = {}
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then table.insert(t, d) end end
	return t
end

-- a copy of a template, scaled by s about its bottom middle, that bottom middle placed at `at`
local function place(template: Model, s: number, at: CFrame, name: string): Model
	local parts = partsOf(template)
	local lo, hi = aabb(parts)
	local foot = CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	local m = Instance.new("Model")
	m.Name = name
	for _, p in ipairs(parts) do
		local c = p:Clone()
		local rel = foot:ToObjectSpace(p.CFrame)
		c.Size = p.Size * s
		c.CFrame = at * (CFrame.new(rel.Position * s) * rel.Rotation)
		c.Anchored = true
		c.Parent = m
	end
	m.WorldPivot = at
	return m
end

local tLo, tHi = aabb(partsOf(LAMP))
local lampTall = tHi.Y - tLo.Y
local bLo, bHi = aabb(partsOf(BENCH))
local benchLong = math.max(bHi.X - bLo.X, bHi.Z - bLo.Z)

local lamps, benches = 0, 0
for _, root in ipairs({ workspace:FindFirstChild("놀이공원길"), workspace:FindFirstChild("놀이터") }) do
	if not root then continue end
	local old = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Model") and (d.Name == "ParkLamp" or d.Name == "ParkLampV2" or d.Name == "Park Bench|공원 벤치") then table.insert(old, d) end
	end
	for _, m in ipairs(old) do
		local parts = partsOf(m)
		local lo, hi = aabb(parts)
		if m.Name == "ParkLamp" or m.Name == "ParkLampV2" then
			-- the pole stands where the base is (a V2 lamp: on its pivot, rebuilt from the current template)
			local base = m:FindFirstChild("LampBase")
			local x, z = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2
			if base and base:IsA("BasePart") then x, z = base.Position.X, base.Position.Z end
			if m.Name == "ParkLampV2" then x, z = m.WorldPivot.X, m.WorldPivot.Z end
			local new = place(LAMP, LAMP_HEIGHT / lampTall, CFrame.new(x, lo.Y, z), "ParkLampV2")
			for _, p in ipairs(new:GetChildren()) do
				if p.Name == "LampGlass" then
					p.Material, p.Color, p.CanCollide, p.CastShadow = Enum.Material.Neon, GLASS, false, false
					local light = m:FindFirstChildWhichIsA("PointLight", true)
					if light then light:Clone().Parent = p end
				else
					p.Material, p.Color, p.CanCollide = Enum.Material.CorrodedMetal, BRONZE, true
				end
			end
			new.Parent = m.Parent
			lamps += 1
		else
			-- the long side of the old seat (its biggest plank's X axis)
			local seat
			for _, p in ipairs(parts) do
				if p.Name:find("Seat") and (not seat or p.Size.X > seat.Size.X) then seat = p end
			end
			local dir = if seat then seat.CFrame.RightVector else Vector3.xAxis
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			local mid = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
			local long = math.max(hi.X - lo.X, hi.Z - lo.Z)
			-- the template's long side is its z: look along the old seat
			local new = place(BENCH, long / benchLong, CFrame.lookAt(mid, mid + dir), "ParkBenchV2")
			for _, p in ipairs(new:GetChildren()) do
				if p.Name == "BenchSeat" then
					p.Material, p.Color = Enum.Material.Wood, WOOD
				else
					p.Material, p.Color = Enum.Material.Asphalt, LEGS
				end
				p.CanCollide = true
			end
			-- (D-1495, user: "놀이공원 벤치 앉기 기능. 따로 텍스트 띄우지 말고") three invisible Seats on the planks
			-- (tag PromptSeat: walking into one sits you down, no prompt), facing the freer side
			local plank = new:FindFirstChild("BenchSeat") :: BasePart
			local top = plank.Position.Y + plank.Size.Y / 2
			local along, side = new.WorldPivot.LookVector, new.WorldPivot.RightVector
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { new, m }
			local function free(dir: Vector3): number
				local best = 99
				for _, dy in ipairs({ 0.5, 2 }) do
					for _, off in ipairs({ -2.5, 0, 2.5 }) do
						local hit = workspace:Raycast(plank.Position + Vector3.new(0, dy, 0) + along * off, dir * 8, rp)
						if hit then best = math.min(best, hit.Distance) end
					end
				end
				return best
			end
			if free(-side) > free(side) then side = -side end
			for i = -1, 1 do
				local sit = Instance.new("Seat")
				sit.Name = "BenchSit"
				sit.Anchored, sit.Transparency, sit.CanCollide, sit.CastShadow = true, 1, false, false
				sit.Size = Vector3.new(1.8, 0.3, 1.8)
				local pos = Vector3.new(plank.Position.X, top + 0.15, plank.Position.Z) + along * (i * plank.Size.Z / 3)
				sit.CFrame = CFrame.lookAt(pos, pos + side)
				sit.Parent = new
				game:GetService("CollectionService"):AddTag(sit, "PromptSeat")
			end
			new.Parent = m.Parent
			benches += 1
		end
		m:Destroy()
	end
end
print(("[park_lamp_bench_1116] lamps %d, benches %d"):format(lamps, benches))
return lamps + benches

--!nocheck
-- 놀이공원 스낵바 2개 + 풍선 가게 (D-1496, user 2026-11-16: "3d 스낵바 두 군데 이걸로 교체 / 입구 들어와서
-- 오른쪽에 ballonshop 설치. 스낵바와 같은 크기로. 풍선은 색깔 다르게 지정").
-- Sources (place only, the user's imports): ServerStorage.ArtAssets.SnackBar1Mesh (snackbar1.glb: body
-- Cube.008 + awning + 콜팝 sign), SnackBar2Mesh (snackbar2.glb: body Cube.001 + 츄로스 sign),
-- BalloonShopMesh (balloonshop.glb: booth B…0032 + decoration B…003), and, once imported,
-- BalloonShopDecor (BalloonShopDecor_split.glb: Balloon1..4, BalloonStrings, ShopSign — the
-- decoration split so each balloon takes its own colour).
--   1. the kiosk (Scene with SnackBar, body Cube.008) → SnackBar1, Workspace.SnackBar2 (Cube.001) →
--      SnackBar2: each new model laid on the old body (same place, turn and size: scale = old body
--      height / new body height);
--   2. Workspace.BalloonShop inside the park gate, on the right (east) of the way in: body centre
--      (-70, -306), counter facing the way in (west), the snack bars' scale (4.29); an invisible
--      "BalloonCounter" tagged SnackShop (Shop = BalloonShop) at its window for the order prompt;
--   3. the balloons on the shop in BALLOON_COLORS (when BalloonShopDecor is there).
-- Idempotent: the new models are rebuilt from the sources each run.

local ART = game.ServerStorage:FindFirstChild("ArtAssets")
assert(ART, "no ServerStorage.ArtAssets")
local SHOP_AT = Vector3.new(-70, 16.11, -306)
local BALLOON_COLORS = { Color3.fromRGB(235, 60, 75), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 150, 255), Color3.fromRGB(110, 225, 190) }
-- (D-1497, user: "상점 세 개 간판 글씨 … 매표소 간판과 색상 동일하게") the gate booths' letter face colour
local SIGN = Color3.fromRGB(255, 252, 250)
-- (D-1882, user 2026-11-19: "놀이공원 콜팝 츄러스 상점 간판 색 넣기 적절한 색으로") each snack bar's letters in a
-- colour from its own booth (D-1519 textures): 츄러스 = the red of its stripes (yellow roof), 콜팝 = the orange
-- of its stripes (teal roof); the balloon shop stays SIGN
local SIGN_OF = {
	SnackBar1Mesh = Color3.fromRGB(222, 38, 42), -- 츄러스 (SnackBar1 / SnackBar1B, D-1527)
	SnackBar2Mesh = Color3.fromRGB(255, 122, 24), -- 콜팝 (SnackBar2B)
}
local function signColor(templateName: string): Color3
	return SIGN_OF[templateName] or SIGN
end

local function meshes(m: Instance): {MeshPart}
	local t = {}
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("MeshPart") then table.insert(t, d) end end
	return t
end
local function body(m: Instance, suffix: string): MeshPart?
	for _, d in ipairs(meshes(m)) do
		if d.Name == suffix or d.Name:sub(-#suffix) == suffix then return d end
	end
	return nil
end
-- every part of `template` placed on `at` (the template body's place), scaled by s about it
local function lay(template: Instance, tBody: BasePart, at: CFrame, s: number, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	for _, p in ipairs(meshes(template)) do
		local c = p:Clone()
		local rel = tBody.CFrame:ToObjectSpace(p.CFrame)
		c.Size = p.Size * s
		c.CFrame = at * (CFrame.new(rel.Position * s) * rel.Rotation)
		c.Anchored = true
		c.Parent = m
	end
	m.WorldPivot = at
	return m
end

------------------------------------------------------------------ 1. snack bars
local done = {}
local function swap(old: Instance?, oldBodyName: string, templateName: string, bodyName: string, newName: string)
	local template = ART:FindFirstChild(templateName)
	if not old or not template then return end
	local ob = body(old, oldBodyName)
	local tb = body(template, bodyName)
	if not ob or not tb then return end
	local s = ob.Size.Y / tb.Size.Y
	local new = lay(template, tb, ob.CFrame, s, newName)
	for _, p in ipairs(new:GetChildren()) do
		-- the sign letters: the only untextured piece
		if p:IsA("MeshPart") and p.TextureID == "" then p.Color, p.Material = signColor(templateName), Enum.Material.SmoothPlastic end
	end
	new.Parent = workspace
	old:Destroy()
	table.insert(done, newName)
end
local kiosk
for _, c in ipairs(workspace:GetChildren()) do
	if c.Name == "Scene" and c:FindFirstChild("SnackBar") then kiosk = c end
end
swap(kiosk or workspace:FindFirstChild("SnackBar1"), "Cube.008", "SnackBar1Mesh", "Cube.008", "SnackBar1")
swap(workspace:FindFirstChild("SnackBar2"), "Cube.001", "SnackBar2Mesh", "Cube.001", "SnackBar2")

------------------------------------------------------------------ 2. balloon shop
local shopTemplate = ART:FindFirstChild("BalloonShopMesh")
local sb = workspace:FindFirstChild("SnackBar2")
local scale = 4.29
if sb and ART:FindFirstChild("SnackBar2Mesh") then
	local a, b = body(sb, "Cube.001"), body(ART.SnackBar2Mesh, "Cube.001")
	if a and b then scale = a.Size.Y / b.Size.Y end
end
if shopTemplate then
	local tb = body(shopTemplate, "0032")
	if tb then
		local old = workspace:FindFirstChild("BalloonShop")
		if old then old:Destroy() end
		local at = CFrame.new(SHOP_AT + Vector3.new(0, tb.Size.Y * scale / 2, 0)) * CFrame.Angles(0, math.rad(90), 0)
		local shop = lay(shopTemplate, tb, at, scale, "BalloonShop")
		for _, p in ipairs(shop:GetChildren()) do p.Name = if p.Name:sub(-4) == "0032" then "BoothBody" else "BalloonDecor" end
		-- 3. the split decoration: its own colours, the white one hidden
		local decor = ART:FindFirstChild("BalloonShopDecor")
		local whole = body(shopTemplate, "003")
		if decor and whole then
			-- (a separate import sits elsewhere: line its pieces' box up with the whole decoration's)
			local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
			for _, p in ipairs(meshes(decor)) do
				lo, hi = lo:Min(p.Position - p.Size / 2), hi:Max(p.Position + p.Size / 2)
			end
			local offset = whole.Position - (lo + hi) / 2
			for _, p in ipairs(meshes(decor)) do
				local c = p:Clone()
				local rel = tb.CFrame:ToObjectSpace(p.CFrame + offset)
				c.Size = p.Size * scale
				c.CFrame = at * (CFrame.new(rel.Position * scale) * rel.Rotation)
				c.Anchored = true
				local i = tonumber(p.Name:match("^Balloon(%d)$"))
				if i then
					c.Color, c.Material, c.Reflectance = BALLOON_COLORS[i], Enum.Material.SmoothPlastic, 0.12
				elseif p.Name == "ShopSign" then
					c.Color, c.Material = SIGN, Enum.Material.SmoothPlastic
				else
					c.Color = Color3.new(1, 1, 1)
				end
				c.Parent = shop
			end
			for _, p in ipairs(shop:GetChildren()) do
				if p.Name == "BalloonDecor" then p:Destroy() end
			end
		end
		local bodyPart = shop:FindFirstChild("BoothBody") :: BasePart
		local e = (bodyPart.CFrame.RightVector * bodyPart.Size.X):Abs() + (bodyPart.CFrame.UpVector * bodyPart.Size.Y):Abs() + (bodyPart.CFrame.LookVector * bodyPart.Size.Z):Abs()
		local counter = Instance.new("Part")
		counter.Name = "BalloonCounter"
		counter.Anchored, counter.Transparency, counter.CanCollide, counter.CanTouch, counter.CastShadow = true, 1, false, false, false
		counter.Size = Vector3.new(1, 4, 12)
		counter.CFrame = CFrame.new(bodyPart.Position.X - e.X / 2 - 0.6, SHOP_AT.Y + 5, bodyPart.Position.Z)
		counter:SetAttribute("Shop", "BalloonShop")
		counter.Parent = shop
		game:GetService("CollectionService"):AddTag(counter, "SnackShop")
		shop.Parent = workspace
		table.insert(done, "BalloonShop")
	end
end
------------------------------------------------------------------ 4. the three in a row (D-1498)
-- (user: "풍선 파는 곳 양옆으로 츄로스, 콜팝 가게 정렬") 츄로스 south of the balloon shop, 콜팝 north of it, all
-- three facing the way in (west) with their fronts in one line, 0.5 apart; the row starts just
-- inside the gate's hoarding (z ROW_SOUTH). The bench and bin in front of 콜팝 step 3 west.
local ROW_SOUTH, GAP = -291.5, 0.5
local function ext(p: BasePart): (Vector3, Vector3)
	local cf, sz = p.CFrame, p.Size
	local e = (cf.RightVector * sz.X):Abs() + (cf.UpVector * sz.Y):Abs() + (cf.LookVector * sz.Z):Abs()
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
local function move(m: Instance, d: Vector3)
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.CFrame += d end end
	if m:IsA("Model") then m.WorldPivot += d end
end
local function faceWest(name: string, templateName: string, bodyName: string)
	local old, template = workspace:FindFirstChild(name), ART:FindFirstChild(templateName)
	if not old or not template then return nil end
	local ob, tb = body(old, bodyName), body(template, bodyName)
	if not ob or not tb then return nil end
	local new = lay(template, tb, CFrame.new(ob.Position) * CFrame.Angles(0, math.rad(90), 0), ob.Size.Y / tb.Size.Y, name)
	for _, p in ipairs(new:GetChildren()) do
		if p:IsA("MeshPart") and p.TextureID == "" then p.Color, p.Material = signColor(templateName), Enum.Material.SmoothPlastic end
	end
	old:Destroy()
	new.Parent = workspace
	return new
end
local balloonShop = workspace:FindFirstChild("BalloonShop")
local churros = faceWest("SnackBar2", "SnackBar2Mesh", "Cube.001")
local colpop = faceWest("SnackBar1", "SnackBar1Mesh", "Cube.008")
if balloonShop and churros and colpop then
	local front = select(1, bb(balloonShop)).X
	local function put(m: Instance, south: number): number
		local lo, hi = bb(m)
		move(m, Vector3.new(front - lo.X, 0, south - hi.Z))
		return select(1, bb(m)).Z
	end
	local z = put(churros, ROW_SOUTH)
	z = put(balloonShop, z - GAP)
	put(colpop, z - GAP)
	local paths = workspace:FindFirstChild("놀이공원길")
	local furniture = paths and paths:FindFirstChild("Furniture")
	local clo, chi = bb(colpop)
	if furniture then
		local bench, bin
		for _, f in ipairs(furniture:GetChildren()) do
			local lo, hi = bb(f)
			local near = lo.Z < chi.Z + 1 and hi.Z > clo.Z - 1 and hi.X > clo.X - 1 and lo.X < chi.X
			if near and f.Name == "ParkBenchV2" then bench = f end
			if near and f.Name == "ParkBin" then bin = f end
		end
		if bench then
			local lo, hi = bb(bench)
			move(bench, Vector3.new((clo.X - 1) - hi.X, 0, 0))
			if bin then
				local blo = select(1, bb(bench))
				local _, nhi = bb(bin)
				move(bin, Vector3.new((blo.X - 0.4) - nhi.X, 0, 0))
			end
		end
	end
	table.insert(done, "row")
end
------------------------------------------------------------------ 5. a second pair where they stood (D-1499)
-- (user: "츄로스, 콜팝 가게 원래 있던 위치에도 있어야 해. 두 개씩 두자") SnackBar1B (콜팝) and SnackBar2B (츄로스)
-- by the jumping star, facing east as before: boxes x -257.8 / -257.6 west, z -412.8 / -391.7 south
local SECOND = {
	{ "SnackBar1B", "SnackBar1Mesh", "Cube.008", Vector2.new(-257.8, -412.8) },
	{ "SnackBar2B", "SnackBar2Mesh", "Cube.001", Vector2.new(-257.6, -391.7) },
}
for _, s2 in ipairs(SECOND) do
	local template = ART:FindFirstChild(s2[2])
	local tb = template and body(template, s2[3])
	if tb then
		local old = workspace:FindFirstChild(s2[1])
		if old then old:Destroy() end
		local sc = scale
		local new = lay(template, tb, CFrame.new(0, SHOP_AT.Y + tb.Size.Y * sc / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), sc, s2[1])
		for _, p in ipairs(new:GetChildren()) do
			if p:IsA("MeshPart") and p.TextureID == "" then p.Color, p.Material = signColor(s2[2]), Enum.Material.SmoothPlastic end
		end
		new.Parent = workspace
		local lo, hi = bb(new)
		move(new, Vector3.new(s2[4].X - lo.X, 0, s2[4].Y - hi.Z))
		table.insert(done, s2[1])
	end
end
print("[park_shops_1116] " .. table.concat(done, ", "))
return #done

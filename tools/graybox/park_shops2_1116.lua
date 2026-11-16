--!nocheck
-- 풍선샵 글씨 · 츄로스/콜팝 계산대 · 범퍼카 차 (D-1527, user 2026-11-16: "풍선샵에 오후 글씨 삭제",
-- "츄로스랑 콜팝도 풍선처럼 구매 가능하게 구현", "범퍼카 기능 구현").
--   * BalloonShop.ShopSign (the "오후" letters) set aside in ServerStorage.ParkShopsRemoved_1116;
--   * an invisible counter "ShopCounter" tagged SnackShop in front of each snack bar's window (the gate's
--     row faces west, the pair by the jumping star east): SnackBar1 / SnackBar1B = Churros, SnackBar2B =
--     Colpop (SnackConfig.Shops; the held shapes are SnackService kinds "churro" / "colpop");
--   * the six bumper car meshes (범퍼's "Cylinder" MeshParts, parked by the north wall) each go into one of
--     the empty car models tagged BumperCar (Workspace.Scene.BumperCar*), as "Body": BumperCarService builds
--     the car from it (BumperCarConfig.Hall = the new hall's rails, D-1512).
-- Idempotent.

local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local o = {}
local keep = SS:FindFirstChild("ParkShopsRemoved_1116") or Instance.new("Folder")
keep.Name = "ParkShopsRemoved_1116"
keep.Parent = SS
local bs = workspace:FindFirstChild("BalloonShop")
local sign = bs and bs:FindFirstChild("ShopSign")
if sign then
	sign.Parent = keep
	table.insert(o, "balloon sign")
end
for name, shopKey in pairs({ SnackBar1 = "Churros", SnackBar1B = "Churros", SnackBar2B = "Colpop" }) do
	local m = workspace:FindFirstChild(name)
	if m then
		local old = m:FindFirstChild("ShopCounter")
		if old then old:Destroy() end
		local cf, s = m:GetBoundingBox()
		local westFront = cf.X > -160
		local c = Instance.new("Part")
		c.Name = "ShopCounter"
		c.Anchored, c.Transparency, c.CanCollide, c.CanTouch, c.CastShadow = true, 1, false, false, false
		c.Size = Vector3.new(1, 4, s.Z)
		c.CFrame = CFrame.new(if westFront then cf.X - s.X / 2 - 0.6 else cf.X + s.X / 2 + 0.6, 16.11 + 5, cf.Z)
		c:SetAttribute("Shop", shopKey)
		c.Parent = m
		CS:AddTag(c, "SnackShop")
		table.insert(o, name .. " " .. shopKey)
	end
end
local hall = workspace:FindFirstChild("범퍼")
local cars = CS:GetTagged("BumperCar")
table.sort(cars, function(a, b) return a.Name < b.Name end)
local bodies = {}
for _, c in ipairs(hall and hall:GetChildren() or {}) do
	if c.Name == "Cylinder" and c:IsA("MeshPart") then table.insert(bodies, c) end
end
table.sort(bodies, function(a, b) return a.Position.X < b.Position.X end)
local n = 0
for i, m in ipairs(cars) do
	local b = bodies[i]
	if b and not m:FindFirstChildWhichIsA("MeshPart") then
		b.Name = "Body"
		b.Parent = m
		m.WorldPivot = b.CFrame
		n += 1
	end
end
table.insert(o, ("%d cars"):format(n))
print("[park_shops2_1116] " .. table.concat(o, "; "))
return table.concat(o, "; ")

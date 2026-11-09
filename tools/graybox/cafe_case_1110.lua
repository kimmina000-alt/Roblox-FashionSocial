--!nocheck
-- Beach cafe pastry case v3 (D-1149 → D-1151), run in Edit mode LAST in the layout
-- chain (after ohucuts_walls_1109). World coordinates; running it again gives the
-- same result.
--   D-1149 (user 2026-11-10: "진열장에 다른 케이크들도 넣어. 케이크 크기가 크니까 진열장도
--   키워."): the four whole cakes sold here instead of the slices.
--   D-1151 (user 2026-11-10: "케이크 플레이트는 진열장에 있는 케이크 올리는 용도로 써 /
--   진열장 3층인데 1층만 두고 케이크 플레이트 위에 케이크 올려서 원래 크기로."): one tier
--   only (the two upper shelves go), each cake on the user's cake stand
--   (ServerStorage.ArtAssets.Foods.CakeStand, CAFE_cake_plate glb.glb) at the
--   size it has on a table (2.6 across, SnackService CAKE_R * 2 + 0.7), from the
--   till along the case: vintage lettering, strawberry cream, tiramisu, basque.
--   The glass, frames and top come down to just over the tallest cake.
local G = workspace:FindFirstChild("Graybox_MainSocial")
local beach = G and G:FindFirstChild("04_Beach_Aquarium")
local cafe = beach and beach:FindFirstChild("BeachCafe")
assert(cafe, "run the layout chain first")
local foods = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
foods = foods and foods:FindFirstChild("Foods")
assert(foods, "ServerStorage.ArtAssets.Foods missing")
local log = {}

local CAKE_W = 2.6   -- a whole cake on a table (studs across)
local STAND_W = 3.1  -- the stand's plate, a little wider than the cake
local ROOM_OVER = 0.45 -- glass top over the tallest cake

------------------------------------------------------------------ 1. one tier
local base, shelves = nil, {}
for _, d in ipairs(cafe:GetChildren()) do
	if d:IsA("BasePart") then
		if d.Name == "CaseBase" then base = d elseif d.Name == "CaseShelf" then table.insert(shelves, d) end
	end
end
assert(base and #shelves >= 1, "pastry case not found (CaseBase + CaseShelf)")
table.sort(shelves, function(a, b) return a.Position.Y < b.Position.Y end)
local baseTop = base.Position.Y + base.Size.Y / 2
local shelf = shelves[1]
shelf.CFrame = shelf.CFrame.Rotation + Vector3.new(shelf.Position.X, baseTop + shelf.Size.Y / 2, shelf.Position.Z)
for i = 2, #shelves do shelves[i]:Destroy() end
local floorY = baseTop + shelf.Size.Y

------------------------------------------------------------------ 2. cakes on stands
local x0, x1 = shelf.Position.X - shelf.Size.X / 2, shelf.Position.X + shelf.Size.X / 2
local zMid = shelf.Position.Z - 0.06
local removed = 0
for _, d in ipairs(cafe:GetChildren()) do
	if d.Name == "CakeDisplay" or d.Name == "CaseVintageCake" or d.Name == "CaseCake" or d.Name == "CaseCakeStand" then d:Destroy() removed += 1 end
end
local function still(m: Instance)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false end
	end
end
local KINDS = { "VintageLetteringCake", "StrawberryCreamCakeSliced", "TiramisuCakeSliced", "BasqueCheesecakeSliced" }
local standSrc = foods:FindFirstChild("CakeStand")
local step = (x1 - x0) / #KINDS
local tallest = 0
for k, name in ipairs(KINDS) do
	local src = foods:FindFirstChild(name)
	if not src then table.insert(log, "missing Foods." .. name) continue end
	local x = x1 - step * (k - 0.5)
	local standTop = floorY
	if standSrc then
		local st = standSrc:Clone()
		still(st)
		local _, s0 = st:GetBoundingBox()
		st:ScaleTo(st:GetScale() * STAND_W / math.max(s0.X, s0.Z))
		local cf, s = st:GetBoundingBox()
		st:PivotTo(st:GetPivot() + Vector3.new(x - cf.X, floorY + s.Y / 2 - cf.Y, zMid - cf.Z))
		st.Name = "CaseCakeStand"
		st.Parent = cafe
		standTop = floorY + s.Y
	end
	local m = src:Clone()
	still(m)
	local _, s0 = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * CAKE_W / math.max(s0.X, s0.Z))
	-- a little turned, each its own way (the lettering / cut side toward the room)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * m:GetPivot().Rotation * CFrame.Angles(0, math.rad(-15 + 10 * k), 0))
	local cf, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(x - cf.X, standTop - 0.02 + s.Y / 2 - cf.Y, zMid - cf.Z))
	m.Name = "CaseCake"
	m:SetAttribute("Kind", name)
	m.Parent = cafe
	tallest = math.max(tallest, standTop - 0.02 + s.Y - floorY)
end
table.insert(log, string.format("cakes: %d old removed, %d on stands, %.1f across, tallest %.2f", removed, #KINDS, CAKE_W, tallest))

------------------------------------------------------------------ 3. glass height
local caseTopY = floorY + tallest + ROOM_OVER
for _, d in ipairs(cafe:GetChildren()) do
	if d:IsA("BasePart") then
		local c = d.Position
		if d.Name == "CaseFrame" or d.Name == "CaseGlass" then
			d.Size = Vector3.new(d.Size.X, caseTopY - baseTop, d.Size.Z)
			d.CFrame = d.CFrame.Rotation + Vector3.new(c.X, (baseTop + caseTopY) / 2, c.Z)
		elseif d.Name == "CaseTop" then
			d.CFrame = d.CFrame.Rotation + Vector3.new(c.X, caseTopY + d.Size.Y / 2, c.Z)
		end
	end
end
table.insert(log, string.format("one tier at %.2f, case top %.2f", floorY, caseTopY))
return table.concat(log, "\n")

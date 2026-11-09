--!nocheck
-- Beach cafe pastry case v2 (D-1149, user 2026-11-10: "진열장에 다른 케이크들도 넣어.
-- 케이크 크기가 크니까 진열장도 키워."), run in Edit mode LAST in the layout chain
-- (after ohucuts_walls_1109). World coordinates; running it again gives the same result.
--   The case on the counter (x -240.73..-226.88, glass front at z 292.8) keeps
--   its footprint and gets taller: the tiers 2.2 apart (were 1.75, polish_1030
--   step 2), the glass, frames and top with them. The cake slices and the one
--   column of vintage cakes (cafe_layout_v4 step 3, polish_1030 step 20) give
--   way to the four whole cakes sold here, one kind per column, the same kind
--   on all three tiers: vintage lettering (next to the till), strawberry cream,
--   tiramisu, basque. The cakes are the game's own models (ServerStorage.
--   ArtAssets.Foods: VintageLetteringCake, <Kind>CakeSliced), 2.5 across.
local G = workspace:FindFirstChild("Graybox_MainSocial")
local beach = G and G:FindFirstChild("04_Beach_Aquarium")
local cafe = beach and beach:FindFirstChild("BeachCafe")
assert(cafe, "run the layout chain first")
local foods = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
foods = foods and foods:FindFirstChild("Foods")
assert(foods, "ServerStorage.ArtAssets.Foods missing")
local log = {}

------------------------------------------------------------------ 1. taller case
local GAP = 2.2
local base, shelves = nil, {}
for _, d in ipairs(cafe:GetChildren()) do
	if d:IsA("BasePart") then
		if d.Name == "CaseBase" then base = d elseif d.Name == "CaseShelf" then table.insert(shelves, d) end
	end
end
assert(base and #shelves == 3, "pastry case not found (CaseBase + 3 CaseShelf)")
table.sort(shelves, function(a, b) return a.Position.Y < b.Position.Y end)
local baseTop = base.Position.Y + base.Size.Y / 2
local tops = {}
for i, s in ipairs(shelves) do
	local y0 = baseTop + (i - 1) * GAP
	s.CFrame = s.CFrame.Rotation + Vector3.new(s.Position.X, y0 + s.Size.Y / 2, s.Position.Z)
	tops[i] = y0 + s.Size.Y
end
local caseTopY = baseTop + 3 * GAP + 0.1
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
table.insert(log, string.format("case tiers %.2f / %.2f / %.2f, top %.2f", tops[1], tops[2], tops[3], caseTopY))

------------------------------------------------------------------ 2. whole cakes
local shelf = shelves[1]
local x0, x1 = shelf.Position.X - shelf.Size.X / 2, shelf.Position.X + shelf.Size.X / 2
local zMid = shelf.Position.Z - 0.06 -- (where the slices stood)
local removed = 0
for _, d in ipairs(cafe:GetChildren()) do
	if d.Name == "CakeDisplay" or d.Name == "CaseVintageCake" or d.Name == "CaseCake" then d:Destroy() removed += 1 end
end
-- from the till (high x) along the case
local KINDS = { "VintageLetteringCake", "StrawberryCreamCakeSliced", "TiramisuCakeSliced", "BasqueCheesecakeSliced" }
local WIDTH = 2.5
local ROOM = GAP - shelf.Size.Y - 0.25 -- (height a cake may take under the next tier)
local step = (x1 - x0) / #KINDS
local made = 0
for k, name in ipairs(KINDS) do
	local src = foods:FindFirstChild(name)
	if not src then table.insert(log, "missing Foods." .. name) continue end
	local x = x1 - step * (k - 0.5)
	for tier = 1, 3 do
		local m = src:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then d:Destroy()
			elseif d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false end
		end
		local _, s0 = m:GetBoundingBox()
		local fit = WIDTH / math.max(s0.X, s0.Z)
		if s0.Y * fit > ROOM then fit = ROOM / s0.Y end
		m:ScaleTo(m:GetScale() * fit)
		-- a little turned, every tier a different way (the cut side never in front)
		m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, math.rad(20 + 35 * tier + 50 * k), 0))
		local cf, s = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(x - cf.X, tops[tier] + s.Y / 2 - cf.Y, zMid - cf.Z))
		m.Name = "CaseCake"
		m:SetAttribute("Kind", name)
		m.Parent = cafe
		made += 1
	end
end
table.insert(log, string.format("cakes: %d old removed, %d whole cakes (%d kinds x 3 tiers), %.1f across", removed, made, #KINDS, WIDTH))
return table.concat(log, "\n")

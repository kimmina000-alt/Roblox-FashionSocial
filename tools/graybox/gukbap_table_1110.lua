--!nocheck
-- 국밥집 tables a little higher (D-1255, user 2026-11-10: "국밥 집 테이블 아주 약간만
-- 높이기 작은 캐릭터도 있으니까"). Chain step 3-22 (tools/graybox/LAYOUT.md), last.
-- Every table top tagged GukbapTable goes up RAISE studs with what stands on it
-- (the tissue box) and its legs grow by the same; a once-mark (Raised1110 on
-- the top) keeps a second run from raising it again.
local RAISE = 0.4
local CS = game:GetService("CollectionService")
local L = workspace:FindFirstChild("Hongdae_Layout")
local G = L and L:FindFirstChild("Gukbap")
assert(G, "run the layout chain first")

local function footprint(top: BasePart, p: Vector3, pad: number): boolean
	local rel = top.CFrame:PointToObjectSpace(p)
	return math.abs(rel.X) <= top.Size.X / 2 + pad and math.abs(rel.Z) <= top.Size.Z / 2 + pad
end

local raised, legs, boxes = 0, 0, 0
for _, top in ipairs(CS:GetTagged("GukbapTable")) do
	if top:IsA("BasePart") and top:IsDescendantOf(G) and not top:GetAttribute("Raised1110") then
		local topY = top.Position.Y + top.Size.Y / 2
		for _, c in ipairs(top.Parent:GetChildren()) do
			if c ~= top then
				if c:IsA("BasePart") and c.Name == "TableLeg" and footprint(top, c.Position, 0.3) and c.Position.Y < topY then
					-- the leg: its foot stays, its top meets the raised table
					c.Size += Vector3.new(0, RAISE, 0)
					c.CFrame += Vector3.new(0, RAISE / 2, 0)
					legs += 1
				elseif c:IsA("Model") and c.Name == "TissueBox" and footprint(top, c:GetPivot().Position, 0) then
					c:PivotTo(c:GetPivot() + Vector3.new(0, RAISE, 0))
					boxes += 1
				end
			end
		end
		top.CFrame += Vector3.new(0, RAISE, 0)
		top:SetAttribute("Raised1110", RAISE)
		raised += 1
	end
end
return string.format("gukbap_table_1110: %d tables up %.1f (%d legs, %d tissue boxes)", raised, RAISE, legs, boxes)

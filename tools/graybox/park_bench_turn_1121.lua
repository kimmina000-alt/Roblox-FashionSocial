--!nocheck
-- 츄러스 가게 앞 벤치 돌리기 (D-1887, user 2026-11-21: "추로스 상점 앞에 의자 반대로 돌려 풀 보고 앉음").
-- The two benches south-east of the churros shop by the jumping star (SnackBar1B, x -245 z -428) sat
-- people down facing the flower bed (화단3칸) behind them (their seats looked -Z). Each is turned 180°
-- round the middle of its own seats, so people sit facing the path and the shop (+Z).
-- Place only (the benches are in Workspace / 놀이공원길.Furniture): run in Edit mode, then save the place.
-- Idempotent: a bench whose seats already look +Z is left alone.

local AREA_LO, AREA_HI = Vector2.new(-240, -446), Vector2.new(-205, -436)
local o = {}

local function seatsOf(m: Instance): {Seat}
	local list = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Seat") then table.insert(list, d) end
	end
	return list
end

for _, m in ipairs(workspace:GetDescendants()) do
	if m:IsA("Model") and m.Name == "ParkBenchV2" then
		local seats = seatsOf(m)
		if #seats == 0 then continue end
		local mid = Vector3.zero
		for _, s in ipairs(seats) do mid += s.Position end
		mid /= #seats
		if mid.X < AREA_LO.X or mid.X > AREA_HI.X or mid.Z < AREA_LO.Y or mid.Z > AREA_HI.Y then continue end
		if seats[1].CFrame.LookVector.Z > 0 then
			table.insert(o, m:GetFullName() .. " already faces +Z")
			continue
		end
		local c = CFrame.new(mid)
		local turn = c * CFrame.Angles(0, math.pi, 0) * c:Inverse()
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then p.CFrame = turn * p.CFrame end
		end
		m.WorldPivot = turn * m.WorldPivot
		table.insert(o, ("%s turned (seats at %.1f, %.1f)"):format(m:GetFullName(), mid.X, mid.Z))
	end
end

return table.concat(o, "\n")

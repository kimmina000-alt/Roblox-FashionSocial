--!nocheck
-- 도로 차선 색 낮추기 (D-1725, user 2026-11-18: "도로에 흰색 노란색 발광하는 거 잡아봐. 색 채도를 낮추든지.").
-- The road markings (thin SmoothPlastic parts under Workspace.Hongdae_Layout, made by build_hongdae_layout
-- with WHITE (240, 240, 240) / YELLOW (240, 190, 40) / BLUE (40, 90, 200)) glowed in the daytime bloom on
-- phones. build_hongdae_layout now uses the darker colours; this recolours the markings already in the
-- place (only parts with a marking name, at most 0.1 high, in exactly the old colours; anything else is left alone).
-- Last step of the layout chain; idempotent (a second run finds nothing in the old colours).

-- (D-1735: white and yellow again, saturation x 0.35; the D-1725 colours are old colours too)
local OLD_NEW = {
	{ Color3.fromRGB(240, 240, 240), Color3.fromRGB(154, 154, 154) }, -- (D-1736: grey, 80 % brightness)
	{ Color3.fromRGB(240, 190, 40), Color3.fromRGB(200, 189, 157) },
	{ Color3.fromRGB(40, 90, 200), Color3.fromRGB(62, 92, 150) },
	{ Color3.fromRGB(192, 192, 188), Color3.fromRGB(154, 154, 154) },
	{ Color3.fromRGB(192, 192, 191), Color3.fromRGB(154, 154, 154) },
	{ Color3.fromRGB(200, 168, 78), Color3.fromRGB(200, 189, 157) },
}
-- (the marking names build_hongdae_layout gives them)
local NAMES = {}
for _, n in ipairs({ "Arrow", "ArrowHead", "ArrowTurn", "UTurnArrow", "JunctionLine", "JunctionTick", "CenterLine", "BusLane",
	"LaneSolid", "LaneDash", "Crosswalk", "BikeCrossingLine", "StopLine", "CrossingAhead", "SafetyStripe", "SafetyEdge",
	"TurnGuide", "BikeLaneEdge", "EdgeLine" }) do NAMES[n] = true end
local function same(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.006 and math.abs(a.G - b.G) < 0.006 and math.abs(a.B - b.B) < 0.006
end

local root = workspace:FindFirstChild("Hongdae_Layout")
assert(root, "Workspace.Hongdae_Layout missing")
local counts = { 0, 0, 0, 0, 0, 0 }
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") and NAMES[d.Name] and d.Size.Y <= 0.1 and d.Material == Enum.Material.SmoothPlastic then
		for i, pair in ipairs(OLD_NEW) do
			if same(d.Color, pair[1]) then
				d.Color = pair[2]
				counts[i] += 1
				break
			end
		end
	end
end
-- the U-turn arrows (uArrow: their frame stands the arrow on its side, so Size.Y is a width; some are pure
-- white 255): every one takes the new white
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "UTurnArrow" and not same(d.Color, OLD_NEW[1][2]) then
		d.Color = OLD_NEW[1][2]
		counts[1] += 1
	end
end
local msg = string.format("[road_paint_1118] white %d, yellow %d, blue %d recoloured", counts[1] + (counts[4] or 0) + (counts[6] or 0), counts[2] + (counts[5] or 0), counts[3])
print(msg)
return msg

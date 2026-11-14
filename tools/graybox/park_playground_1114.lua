-- The park's playground pieces and the carousel (Graybox_MainSocial["06_Park_Playground"]), moved
-- as whole pieces to fixed places (idempotent: moves TO the targets, not by an offset):
--   * (D-1408) first north of the bumper car hall's exit; the user then placed them by hand;
--   * (D-1415, user 2026-11-14, top view with a green box: "범퍼카 앞에 그네랑 미끄럼틀이랑 흔들리는
--     의자 세 개 녹색 박스 칸 위치로 이동") the swing set "그 네 ", the Slide and SpringRider1..3 keep
--     the user's arrangement and move together (SpringRider1 at TARGET) to the north of the park,
--     out of the way of the bigger bumper car floor (park_bumper_expand_1114);
--   * (D-1415, user picked "회전목마를 옆으로 이동") the carousel "회전목" moves north 10 so the
--     bumper car queue's entrance corridor passes clear of it (CAROUSEL = the base's centre).
-- The slide's path (attributes P0 / P1 / P2, world positions) is set again from its bed.
-- The D-1408 / D-1411 pad, fence and planters (Hongdae_Layout.ParkPlayground) were removed by the
-- user and are not built any more. Chain step: before park_bumper_expand_1114.

local pg = workspace:WaitForChild("Graybox_MainSocial"):WaitForChild("06_Park_Playground")
local TARGET = Vector3.new(-147.38, 17.035, -550.737) -- SpringRider1's pivot (by hand before: -144.28, -310.34)
local CAROUSEL = Vector3.new(-129.3, 18.209, -426.2) -- the carousel base's centre (was -129.3, -416.2)

local function shift(inst: Instance, delta: Vector3)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + delta)
	elseif inst:IsA("BasePart") then
		inst.CFrame = inst.CFrame + delta
	else
		for _, c in ipairs(inst:GetChildren()) do shift(c, delta) end
	end
end

local ref = pg:FindFirstChild("SpringRider1") :: Model
local delta = TARGET - ref:GetPivot().Position
if delta.Magnitude > 0.05 then
	for _, name in ipairs({ "Slide", "그 네 ", "SpringRider1", "SpringRider2", "SpringRider3" }) do
		local m = pg:FindFirstChild(name)
		if m then shift(m, delta) end
	end
end

local carousel = pg:FindFirstChild("회전목")
local base = carousel and carousel:FindFirstChild("CarouselBase") :: BasePart?
if carousel and base then
	local d = CAROUSEL - base.Position
	if d.Magnitude > 0.05 then shift(carousel, d) end
end

-- the slide's path from its bed (top piece to bottom piece, a rider's height above it)
local slide = pg:FindFirstChild("Slide")
if slide then
	local beds = {}
	for _, d in ipairs(slide:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "SlideBed" then table.insert(beds, d) end
	end
	table.sort(beds, function(a, b) return a.Position.Y > b.Position.Y end)
	if #beds >= 3 then
		local up = Vector3.new(0, 2.6, 0)
		local top, mid, bottom = beds[1].Position, beds[math.ceil(#beds / 2)].Position, beds[#beds].Position
		local run = (bottom - beds[#beds - 1].Position).Unit
		slide:SetAttribute("P0", top + up + Vector3.new(0, 0.4, 0))
		slide:SetAttribute("P1", mid + up)
		slide:SetAttribute("P2", bottom + up + run * 2)
	end
end

print("[park_playground_1114] playground moved by", delta)
return delta

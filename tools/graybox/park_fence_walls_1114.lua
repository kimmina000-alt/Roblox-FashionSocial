-- (D-1415, user 2026-11-14: "펜스 넘을 수 없게 안 보이는 벽 추가. 펜스 현 크기 유지.") The user places
-- the park's fence panels by hand (loose FencePanel parts in Workspace: the bumper car queue, the
-- mini viking's barriers and stage railing). Behind every one of them an invisible wall 7 studs
-- high (the panel's own length and place, a little thicker), so nobody hops over a fence.
-- Model: Hongdae_Layout.ParkFenceWalls (rebuilt each run from the panels, so it follows the
-- user's later changes). Chain step: last.

local layout = workspace:WaitForChild("Hongdae_Layout")
local old = layout:FindFirstChild("ParkFenceWalls")
if old then old:Destroy() end
local M = Instance.new("Model")
M.Name = "ParkFenceWalls"

local n = 0
for _, p in ipairs(workspace:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "FencePanel" then
		local bottom = p.Position.Y - p.Size.Y / 2
		local w = Instance.new("Part")
		w.Name = "FenceWall"
		w.Anchored = true
		w.Transparency = 1
		w.CanQuery, w.CanTouch, w.CastShadow = false, false, false
		-- (a panel's length is its Z; keep its turn, stand the wall on the panel's foot)
		local look = p.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, 1) end
		local base = Vector3.new(p.Position.X, bottom + 3.5, p.Position.Z)
		w.Size = Vector3.new(0.6, 7, p.Size.Z)
		w.CFrame = CFrame.lookAt(base, base + flat.Unit)
		w.Parent = M
		n += 1
	end
end
M.Parent = layout
print("[park_fence_walls_1114] walls:", n)
return n

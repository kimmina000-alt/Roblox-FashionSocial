--!strict
-- (D-1319, user 2026-11-12: "빵 진열대 밑에 조명 넣어 줘") warm LED strips along the foot of
-- both beach cafe bakery tables (BakeryTable), each with a SurfaceLight that washes the floor
-- in front of it. Builds only its own folder Workspace.BakeryDisplay.UnderLights (place-only,
-- like BakeryDisplay), so it may run on its own in Edit mode; run it again after the cafe
-- zone is rebuilt.

local display = workspace:FindFirstChild("BakeryDisplay")
assert(display, "Workspace.BakeryDisplay is missing")
local old = display:FindFirstChild("UnderLights")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "UnderLights"
folder.Parent = display

local WARM = Color3.fromRGB(255, 190, 120)
local count = 0
for _, t in ipairs(workspace:GetDescendants()) do
	if t:IsA("BasePart") and t.Name == "BakeryTable" then
		local cf, s = t.CFrame, t.Size
		local bottom = -s.Y / 2
		-- the four sides: { offset to the face, length along it, its axis is X? }
		local sides = {
			{ CFrame.new(s.X / 2 + 0.06, 0, 0), s.Z, false, Vector3.xAxis },
			{ CFrame.new(-s.X / 2 - 0.06, 0, 0), s.Z, false, -Vector3.xAxis },
			{ CFrame.new(0, 0, s.Z / 2 + 0.06), s.X, true, Vector3.zAxis },
			{ CFrame.new(0, 0, -s.Z / 2 - 0.06), s.X, true, -Vector3.zAxis },
		}
		for _, side in ipairs(sides) do
			local p = Instance.new("Part")
			p.Name = "LedStrip"
			p.Anchored = true
			p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
			p.Material = Enum.Material.Neon
			p.Color = WARM
			local len = (side[2] :: number) - 0.4
			p.Size = if side[3] then Vector3.new(len, 0.14, 0.1) else Vector3.new(0.1, 0.14, len)
			p.CFrame = cf * CFrame.new(0, bottom + 0.22, 0) * (side[1] :: CFrame)
			-- small warm PointLights on Attachments along the strip, 0.8 out from the
			-- table (a SurfaceLight did not reach the floor; brighter ones flooded the room)
			local out = side[4] :: Vector3
			local k = math.max(1, math.floor(len / 7 + 0.5))
			for i = 1, k do
				local t = -len / 2 + len * (i - 0.5) / k
				local a = Instance.new("Attachment")
				a.Position = (if side[3] then Vector3.new(t, 0, 0) else Vector3.new(0, 0, t)) + out * 0.8 + Vector3.new(0, 0.1, 0)
				a.Parent = p
				local light = Instance.new("PointLight")
				light.Color = WARM
				light.Brightness = 0.6
				light.Range = 3
				light.Shadows = false
				light.Parent = a
			end
			p.Parent = folder
			count += 1
		end
	end
end
print("[BakeryUnderLights] strips:", count)
return count

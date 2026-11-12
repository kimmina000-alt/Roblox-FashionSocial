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

-- (D-1324, user 2026-11-12: "빵 진열대랑 트레이 밑에 조명 더 얇게 하고 흰색으로 수정") white,
-- and thinner: the strips 0.05 × 0.05 (were 0.14 × 0.1), the tray rims 0.05 wide and 0.03
-- thick (were 0.15 / 0.06). The name WARM stays for the colour of every light here.
local WARM = Color3.fromRGB(250, 250, 255)
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
			p.Size = if side[3] then Vector3.new(len, 0.05, 0.05) else Vector3.new(0.05, 0.05, len)
			p.CFrame = cf * CFrame.new(0, bottom + 0.175, 0) * (side[1] :: CFrame)
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

-- (D-1320, user 2026-11-12: "진열대 나무 트레이 밑에 조명 넣어") under every wooden bread
-- tray on the two tables (the user's CAFE tray MeshParts named "Cube", 0.87 thick): a warm
-- Neon plate 0.15 wider on each side, just above the table top, so a glowing rim shows
-- round the tray's foot, and one small PointLight. Folder Workspace.BakeryDisplay.TrayLights.
local oldT = display:FindFirstChild("TrayLights")
if oldT then oldT:Destroy() end
local trayFolder = Instance.new("Folder")
trayFolder.Name = "TrayLights"
trayFolder.Parent = display
local trays = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("MeshPart") and d.Name == "Cube" and math.abs(d.Size.Y - 0.87) < 0.05 and d.Size.Z > 6
		and d.Position.X > -260 and d.Position.X < -195 and d.Position.Z > 195 and d.Position.Z < 265 then
		local p = Instance.new("Part")
		p.Name = "TrayGlow"
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = WARM
		p.Size = Vector3.new(d.Size.X + 0.1, 0.03, d.Size.Z + 0.1)
		p.CFrame = d.CFrame * CFrame.new(0, -d.Size.Y / 2 + 0.025, 0)
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, 0.2, 0)
		a.Parent = p
		local light = Instance.new("PointLight")
		light.Color = WARM
		light.Brightness = 0.5
		light.Range = 3.5
		light.Shadows = false
		light.Parent = a
		p.Parent = trayFolder
		trays += 1
	end
end
print("[BakeryUnderLights] trays:", trays)
return count

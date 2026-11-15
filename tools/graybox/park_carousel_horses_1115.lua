-- (D-1420, user 2026-11-15, a screenshot with the user's carousel horse circled: "회전목마 노란색
-- 표시한 에셋 사용하여 회전목마 말 교체해서 기능까지 구현") The carousel's 12 block horses
-- (Graybox_MainSocial["06_Park_Playground"]["회전목"].Carousel.Horse1..12) become the user's
-- carousel horse (a white unicorn on a gold pole: MeshPart "Cylinder2" + its horn "Cylinder";
-- the place-only template ServerStorage.ArtAssets.CarouselHorse, from Workspace.Scene.horse).
--   * each new horse keeps its old pivot (the saddle top, LookVector = the way it rides), so
--     ParkConfig.horseCFrame and the riders' seats stay right; its pole on the rotor's pole
--   * the mesh: head along its +X, the pole 0.82 and the saddle top 0.7 above its middle (at
--     size 1); scaled to SCALE (about 7 long, 12 fit round the ring)
--   * the carousel's Radius / SaddleY / Bob attributes are set to its real (scaled) size:
--     the user had scaled the carousel by 1.386 without them, so riders sat 4 studs inside
-- Idempotent (a horse already holding "HorseMesh" is left). Chain step: after the graybox zones
-- (the 06_Park_Playground zone builds the block horses), with park_playground_1114.

local SS = game:GetService("ServerStorage")
local zone = workspace:WaitForChild("Graybox_MainSocial"):WaitForChild("06_Park_Playground")
local carousel = zone:WaitForChild("회전목"):WaitForChild("Carousel")
local template = SS:WaitForChild("ArtAssets"):WaitForChild("CarouselHorse")

local SCALE = 0.7
local POLE_X, SADDLE_Y = 0.82, 0.7 -- (in the mesh's own space, size 1)
local HORN = Vector3.new(3.148, 3.482, 0)

local body0 = template:FindFirstChild("Cylinder2") :: MeshPart
local horn0 = template:FindFirstChild("Cylinder") :: MeshPart

local center = carousel:FindFirstChild("Center") :: BasePart
local count = 0
local radius, saddleY = 0, 0
for i = 1, 64 do
	local horse = carousel:FindFirstChild("Horse" .. i)
	if not horse or not horse:IsA("Model") then break end
	local pivot = horse:GetPivot() -- (saddle top, facing the way it rides)
	radius = Vector2.new(pivot.X - center.Position.X, pivot.Z - center.Position.Z).Magnitude
	saddleY = pivot.Y - center.Position.Y
	if not horse:FindFirstChild("HorseMesh") then
		for _, c in ipairs(horse:GetChildren()) do c:Destroy() end
		-- mesh +X = the pivot's LookVector: turn by +90° about Y
		local meshCF = pivot * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-POLE_X * SCALE, -SADDLE_Y * SCALE, 0)
		local body = body0:Clone()
		body.Name = "HorseMesh"
		body.Size = body0.Size * SCALE
		body.CFrame = meshCF
		local horn = horn0:Clone()
		horn.Name = "HorseHorn"
		horn.Size = horn0.Size * SCALE
		horn.CFrame = meshCF * CFrame.new(HORN * SCALE)
		for _, p in ipairs({ body, horn }) do
			p.Anchored = true
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			p.Parent = horse
		end
		horse.WorldPivot = pivot
	end
	count += 1
end
carousel:SetAttribute("Radius", math.floor(radius * 100 + 0.5) / 100)
carousel:SetAttribute("SaddleY", math.floor(saddleY * 100 + 0.5) / 100)
carousel:SetAttribute("Bob", 1.1)
print(("[park_carousel_horses_1115] horses %d, radius %.2f, saddle %.2f"):format(count, radius, saddleY))
return count

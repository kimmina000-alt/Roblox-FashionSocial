--!nocheck
-- 클럽 통로 바닥 통일 (D-1658, user 2026-11-17 with a phone shot of the locker room passage: "클럽 내부
-- 바닥 통일" / "이미지를 봐봐 무늬가 다르잖아 원인 파악해서 고쳐").
-- Cause: the passage floor (ClubAnnex.LockerRoom.Passage.Floor) is the same black marble as the club
-- floor (Marble 20,20,24, reflectance 0.15; ClubGlowDim tones both up). The club floor's purple veins
-- come from the club's coloured lights and lasers; none of them reach into the walled passage, so its
-- marble showed no veins, only the warm glow of its floor lines (brown on phones).
-- Fix: a purple light under the passage ceiling (PassageGlow: an invisible part with a SurfaceLight
-- facing down, the club's violet), aimed so it stays in the passage. Play 2026-11-17: the passage
-- floor shows the same purple veins as the club floor.
-- Run after club_locker_1103 (it builds the passage). Safe to run again.

local annex = workspace:FindFirstChild("Hongdae_Layout") and workspace.Hongdae_Layout:FindFirstChild("ClubAnnex")
local passage = annex and annex:FindFirstChild("Passage", true)
assert(passage, "ClubAnnex Passage missing")
local floor = passage:FindFirstChild("Floor")
assert(floor and floor:IsA("BasePart"), "Passage.Floor missing")

local old = passage:FindFirstChild("PassageGlow")
if old then old:Destroy() end
local p = Instance.new("Part")
p.Name = "PassageGlow"
p.Anchored = true
p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
p.Transparency = 1
p.Size = Vector3.new(floor.Size.X - 3, 0.2, floor.Size.Z - 3.5)
p.CFrame = CFrame.new(floor.Position.X, floor.Position.Y + 16.5, floor.Position.Z + 0.6)
local light = Instance.new("SurfaceLight")
light.Face = Enum.NormalId.Bottom
light.Color = Color3.fromRGB(150, 80, 255)
light.Brightness = 1.6
light.Range = 24
light.Angle = 120 -- (80 lit almost nothing in Play)
light.Shadows = false
light.Parent = p
p.Parent = passage
print(("[club_passage_light_1117] PassageGlow over the passage at %s"):format(tostring(p.Position)))
return tostring(p.Position)

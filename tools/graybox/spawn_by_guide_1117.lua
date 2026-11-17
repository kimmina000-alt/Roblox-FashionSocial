--!nocheck
-- 스포너를 안내원 토끼 옆으로 (D-1696, user 2026-11-17: "토끼 안내원 옆으로 스포너 위치 이동").
-- The players' SpawnLocation goes right beside the guide NPC's walking zone in the pocket park
-- (GuideConfig.Npc: around -115, 0.6, -56; zone x -123..-106): an 8x8 pad at (-105, top 0.6, -56), flat
-- pocket-park paving (checked in Edit: 0.6 everywhere under it), turned so a player arrives facing the
-- guide (west). Invisible, no collisions of its own (the paving carries them). Run as the last step of
-- the layout chain (build_hongdae_layout places the spawn at the corner square; this moves it again).

local spawn = workspace:FindFirstChild("SpawnLocation")
assert(spawn and spawn:IsA("SpawnLocation"), "SpawnLocation missing")
local TOP = 0.6
spawn.Size = Vector3.new(8, 1, 8)
local at = Vector3.new(-105, TOP - spawn.Size.Y / 2, -56)
spawn.CFrame = CFrame.lookAt(at, at + Vector3.new(-1, 0, 0))
spawn.Transparency = 1
spawn.CanCollide = false
spawn.CanTouch = true
for _, d in ipairs(spawn:GetChildren()) do
	if d:IsA("Decal") then d.Transparency = 1 end
end
print("[spawn_by_guide_1117] spawn at " .. tostring(spawn.Position))
return tostring(spawn.Position)

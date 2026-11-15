--!nocheck
-- 지도 전체 가벼운 최적화 (D-1492, user 2026-11-16: "최적화", scope "지도 전체").
-- Measured first: 19,513 parts (budget 25,000), 412 lights (none casting shadows; the few that
-- overlap are coloured club / photo-booth lights, left alone), and 2,086 parts under 1.5 studs that
-- cast shadows. On phones the shadow pass redraws every shadow caster, and a shadow from a bulb, a
-- bolt or a thin trim is too small to see. So, over every BasePart in Workspace:
--   1. max size < SMALL (1.5)  → CastShadow false;
--   2. Neon and max size < SMALL (bulbs, LED dots) → also CanCollide / CanTouch / CanQuery false
--      (nobody walks on a bulb), unless the part has a tag, a ProximityPrompt / ClickDetector, or a
--      name with Collider / Hitbox / Seat / Prompt in it.
-- Characters are skipped. Idempotent; run it last in the layout chain (after user_map_snapshot and
-- the park scripts), since a chain run rebuilds Hongdae_Layout with shadows on again.

local SMALL = 1.5
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")

local function isCharacterPart(p: BasePart): boolean
	local m = p:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(m) then return true end
		m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function interactive(p: BasePart): boolean
	if #CS:GetTags(p) > 0 then return true end
	if p:FindFirstChildWhichIsA("ProximityPrompt", true) or p:FindFirstChildWhichIsA("ClickDetector", true) then return true end
	local n = p.Name:lower()
	return n:find("collider") ~= nil or n:find("hitbox") ~= nil or n:find("seat") ~= nil or n:find("prompt") ~= nil
end

local shadowOff, bulbOff = 0, 0
for i, p in ipairs(workspace:GetDescendants()) do
	if p:IsA("BasePart") and p ~= workspace.Terrain then
		local m = math.max(p.Size.X, p.Size.Y, p.Size.Z)
		if m < SMALL and not isCharacterPart(p) then
			if p.CastShadow then
				p.CastShadow = false
				shadowOff += 1
			end
			if p.Material == Enum.Material.Neon and (p.CanCollide or p.CanTouch or p.CanQuery) and not interactive(p) then
				p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
				bulbOff += 1
			end
		end
	end
	if i % 5000 == 0 then task.wait() end
end
-- 3. flat slabs lying on something (thickness ≤ 1.2, the thin side vertical, a ray from the middle
--    of the bottom finds ground within 0.6): their shadow falls under themselves
local flatOff = 0
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
for i, p in ipairs(workspace:GetDescendants()) do
	if p:IsA("BasePart") and p.CastShadow and p ~= workspace.Terrain and not isCharacterPart(p) then
		local thick
		if math.abs(p.CFrame.UpVector.Y) > 0.99 then thick = p.Size.Y
		elseif math.abs(p.CFrame.RightVector.Y) > 0.99 then thick = p.Size.X
		elseif math.abs(p.CFrame.LookVector.Y) > 0.99 then thick = p.Size.Z end
		if thick and thick <= 1.2 and math.min(p.Size.X, p.Size.Y, p.Size.Z) == thick then
			rp.FilterDescendantsInstances = { p }
			local hit = workspace:Raycast(Vector3.new(p.Position.X, p.Position.Y - thick / 2 + 0.05, p.Position.Z), Vector3.new(0, -0.6, 0), rp)
			if hit then
				p.CastShadow = false
				flatOff += 1
			end
		end
	end
	if i % 4000 == 0 then task.wait() end
end
print(("[optimize_1116] shadows off %d small + %d flat, bulbs without collision %d"):format(shadowOff, flatOff, bulbOff))
return shadowOff

--!strict
-- Parts tagged "NightGlow" light up at night (user 2026-10-23: the 오후네컷
-- door frame glows after dark). In the day they are plain painted parts; from
-- 18:00 to 06:00 (Lighting.ClockTime) they turn Neon and switch on a soft
-- SurfaceLight on their front face. Runs on each client.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local NIGHT_FROM, NIGHT_TO = 18, 6

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= NIGHT_FROM or t < NIGHT_TO
end

local function apply(part: Instance, night: boolean)
	if not part:IsA("BasePart") then return end
	if part:GetAttribute("DayMaterial") == nil then part:SetAttribute("DayMaterial", part.Material.Name) end
	part.Material = if night then Enum.Material.Neon else Enum.Material[part:GetAttribute("DayMaterial") :: string]
	local light = part:FindFirstChild("NightLight") :: SurfaceLight?
	if not light then
		local l = Instance.new("SurfaceLight")
		l.Name = "NightLight"
		l.Face = Enum.NormalId.Front
		l.Range = 10
		l.Brightness = 1.4
		l.Color = part.Color
		l.Parent = part
		light = l
	end
	(light :: SurfaceLight).Enabled = night
end

local current: boolean? = nil
local function refresh(force: boolean?)
	local night = isNight()
	if night == current and not force then return end
	current = night
	for _, part in ipairs(CollectionService:GetTagged("NightGlow")) do apply(part, night) end
end

CollectionService:GetInstanceAddedSignal("NightGlow"):Connect(function(part)
	apply(part, isNight())
end)
Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function() refresh(false) end)
refresh(true)

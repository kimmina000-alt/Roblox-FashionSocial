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
	-- optional NightColor (Color3): a different colour after dark (cafe wall slits:
	-- pale glass by day, warm glow at night)
	local nightColor = part:GetAttribute("NightColor")
	if typeof(nightColor) == "Color3" then
		if part:GetAttribute("DayColor") == nil then part:SetAttribute("DayColor", part.Color) end
		part.Color = if night then nightColor else part:GetAttribute("DayColor") :: Color3
	end
	local light = part:FindFirstChild("NightLight") :: SurfaceLight?
	if not light then
		local l = Instance.new("SurfaceLight")
		l.Name = "NightLight"
		l.Face = Enum.NormalId.Front
		-- per part: NightRange / NightBrightness / NightAngle (wall uplights)
		l.Range = (part:GetAttribute("NightRange") :: number?) or 10
		l.Brightness = (part:GetAttribute("NightBrightness") :: number?) or 1.4
		l.Angle = (part:GetAttribute("NightAngle") :: number?) or 90
		l.Color = part.Color
		l.Parent = part
		light = l
	end
	if night then (light :: SurfaceLight).Color = part.Color end
	(light :: SurfaceLight).Enabled = night
end

-- Parts tagged "NightWash" carry a SurfaceGui with a warm gradient: the light
-- washing up a wall from its uplights (hanok palace wall, 광화문). Shown at night only.
local function wash(part: Instance, night: boolean)
	for _, g in ipairs(part:GetDescendants()) do
		if g:IsA("SurfaceGui") then g.Enabled = night end
	end
end

local current: boolean? = nil
local function refresh(force: boolean?)
	local night = isNight()
	if night == current and not force then return end
	current = night
	for _, part in ipairs(CollectionService:GetTagged("NightGlow")) do apply(part, night) end
	for _, part in ipairs(CollectionService:GetTagged("NightWash")) do wash(part, night) end
end

CollectionService:GetInstanceAddedSignal("NightGlow"):Connect(function(part)
	apply(part, isNight())
end)
CollectionService:GetInstanceAddedSignal("NightWash"):Connect(function(part)
	wash(part, isNight())
end)
Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function() refresh(false) end)
refresh(true)

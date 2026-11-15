--!strict
-- (D-1419, player feedback 2026-11-15 "밤에 무섭다"; user: "서울 야경 조사해" → "3까지 해 봐",
-- docs/04_ART/NIGHT_SEOUL.md) The night looks like a Seoul night instead of a black void:
--   1. sky and ambient light: not black but a deep navy sky with a warm city glow low on the
--      horizon (Atmosphere colour / decay / haze), a slightly brighter bluish ambient, a little
--      more exposure; blended in at dusk and out at dawn.
--   2. lit windows: about 70 % of the window panes (WindowGlass, Window2F, the OH24 tower's
--      slits, ...) glow warm (a few cool white, like offices), the same ones for everyone (picked
--      from their position); the background buildings' facade photos (BG_* models) get a
--      self-lit copy of the photo at night, so they read as lit buildings, not black blocks.
--   3. street lamps: warm 3,000 K light (Seoul's night lights are mostly 2,500-3,500 K) and a
--      wider, brighter pool on the ground.
--   4. (D-1421, "4랑 5도 적용") shop signs and shop windows: every sign / board / banner picture
--      shines by itself at night (SurfaceGui LightInfluence 0), the shop windows (ShopGlass,
--      EntranceGlass, FrontGlass, ...) light the pavement in front with a warm glow.
--   6. (D-1422, "야경 5 삭제 6 적용": the night walkers of D-1421 are gone again) a little more glow
--      round bright things at night (Lighting.Bloom: lower threshold, a bit stronger and wider),
--      so the signs and lit windows shine softly.
-- Client only (looks); nothing changes in the place.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

---------------------------------------------------------------- settings
local WARM = Color3.fromRGB(255, 196, 140) -- about 3,000 K
local WINDOW_WARM = Color3.fromRGB(240, 185, 120) -- (a little dim: Neon with the bloom was glaring)
local WINDOW_COOL = Color3.fromRGB(205, 215, 235)
local LIT_SHARE = 0.7
local COOL_SHARE = 0.2
local WINDOW_NAMES = { WindowGlass = true, Window2F = true, TowerSlit = true }
local NIGHT = {
	ambient = Color3.fromRGB(88, 90, 112),
	outdoor = Color3.fromRGB(100, 106, 140),
	atmColor = Color3.fromRGB(70, 80, 125),
	atmDecay = Color3.fromRGB(140, 95, 70), -- (the warm glow of the city low on the sky)
	haze = 1.4,
	exposure = 0.25,
	bloomIntensity = 1.25,
	bloomSize = 32,
	bloomThreshold = 1.35,
}
-- night amount by the clock: 0 by day, 1 at night, eased over dusk 17.5-19.5 and dawn 5-6.5
local function nightAmount(t: number): number
	local function s(x: number): number x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
	if t >= 12 then return s((t - 17.5) / 2) end
	return 1 - s((t - 5) / 1.5)
end

---------------------------------------------------------------- 1. sky and ambient
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local day = {
	bloomIntensity = bloom and bloom.Intensity or 1,
	bloomSize = bloom and bloom.Size or 24,
	bloomThreshold = bloom and bloom.Threshold or 2,
	ambient = Lighting.Ambient,
	outdoor = Lighting.OutdoorAmbient,
	exposure = Lighting.ExposureCompensation,
	atmColor = atm and atm.Color or Color3.new(1, 1, 1),
	atmDecay = atm and atm.Decay or Color3.new(1, 1, 1),
	haze = atm and atm.Haze or 0,
}
local function sky(n: number)
	Lighting.Ambient = day.ambient:Lerp(NIGHT.ambient, n)
	Lighting.OutdoorAmbient = day.outdoor:Lerp(NIGHT.outdoor, n)
	Lighting.ExposureCompensation = day.exposure + (NIGHT.exposure - day.exposure) * n
	if bloom then
		bloom.Intensity = day.bloomIntensity + (NIGHT.bloomIntensity - day.bloomIntensity) * n
		bloom.Size = day.bloomSize + (NIGHT.bloomSize - day.bloomSize) * n
		bloom.Threshold = day.bloomThreshold + (NIGHT.bloomThreshold - day.bloomThreshold) * n
	end
	if atm then
		atm.Color = day.atmColor:Lerp(NIGHT.atmColor, n)
		atm.Decay = day.atmDecay:Lerp(NIGHT.atmDecay, n)
		atm.Haze = day.haze + (NIGHT.haze - day.haze) * n
	end
end

---------------------------------------------------------------- 2. windows
-- a steady number in 0..1 from a part's place (the same window lit for everyone, every night)
local function hash01(v: Vector3): number
	local x = math.sin(v.X * 12.9898 + v.Y * 78.233 + v.Z * 37.719) * 43758.5453
	return x - math.floor(x)
end

type Win = { part: BasePart, material: Enum.Material, color: Color3, lit: boolean, cool: boolean }
local windows: {Win} = {}
local facades: {SurfaceGui} = {}

local function addWindow(p: Instance)
	if not p:IsA("BasePart") or not WINDOW_NAMES[p.Name] or p:GetAttribute("NightWindowDone") then return end
	p:SetAttribute("NightWindowDone", true)
	local h = hash01(p.Position)
	table.insert(windows, { part = p, material = p.Material, color = p.Color, lit = h < LIT_SHARE, cool = h < LIT_SHARE * COOL_SHARE })
end

-- the background buildings' facade photos: a self-lit copy on the same face at night
local function addFacade(tex: Instance)
	if not (tex:IsA("Texture") or tex:IsA("Decal")) then return end
	local part = tex.Parent
	if not part or not part:IsA("BasePart") or part:FindFirstChild("NightFacade_" .. tex.Face.Name) then return end
	local g = Instance.new("SurfaceGui")
	g.Name = "NightFacade_" .. tex.Face.Name
	g.Face = tex.Face
	g.LightInfluence = 0
	g.Brightness = 0.7
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 8
	g.Enabled = false
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = (tex :: any).Texture
	img.ImageColor3 = Color3.fromRGB(255, 222, 180)
	img.ImageTransparency = 0.1
	if tex:IsA("Texture") then
		img.ScaleType = Enum.ScaleType.Tile
		img.TileSize = UDim2.fromOffset(tex.StudsPerTileU * g.PixelsPerStud, tex.StudsPerTileV * g.PixelsPerStud)
	else
		img.ScaleType = Enum.ScaleType.Stretch
	end
	img.Parent = g
	g.Parent = part
	table.insert(facades, g)
end

local function scan()
	local layout = workspace:FindFirstChild("Hongdae_Layout")
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and WINDOW_NAMES[d.Name] then addWindow(d) end
	end
	if layout then
		for _, m in ipairs(layout:GetChildren()) do
			if string.sub(m.Name, 1, 3) == "BG_" then
				for _, d in ipairs(m:GetDescendants()) do addFacade(d) end
			end
		end
	end
end

local lightsOn: boolean? = nil
local function setWindows(on: boolean)
	if lightsOn == on then return end
	lightsOn = on
	for i = #windows, 1, -1 do
		local w = windows[i]
		if not w.part.Parent then
			table.remove(windows, i)
		elseif w.lit then
			w.part.Material = if on then Enum.Material.Neon else w.material
			w.part.Color = if on then (if w.cool then WINDOW_COOL else WINDOW_WARM) else w.color
		end
	end
	for _, g in ipairs(facades) do g.Enabled = on end
end

---------------------------------------------------------------- 3. street lamps
local function lamp(l: Instance)
	if l:GetAttribute("SeoulLamp") then return end
	local parent = l.Parent
	if not parent then return end
	if l:IsA("SpotLight") and parent.Name == "LampHead" then
		l:SetAttribute("SeoulLamp", true)
		l.Color = WARM
		l.Range = 40
		l.Brightness = 2.4
		l.Angle = 120
	elseif l:IsA("SurfaceLight") and (parent.Name == "Lense" or parent.Name == "Union") and parent:IsDescendantOf(workspace) then
		local street = parent:FindFirstAncestor("StreetLights")
		if street then
			l:SetAttribute("SeoulLamp", true)
			l.Color = WARM
			l.Range = math.max(l.Range, 50)
		end
	end
end
local function scanLamps()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpotLight") or d:IsA("SurfaceLight") then lamp(d) end
	end
end

---------------------------------------------------------------- 4. signs and shop windows
local SIGN_WORDS = { "Sign", "Board", "Banner", "Logo", "Letter", "Band", "Awning", "Flag", "Header", "Halo", "Poster", "Sticker", "AdPanel", "Name" }
local SHOP_GLASS = { ShopGlass = true, EntranceGlass = true, FrontGlass = true, PizzaGlass = true, PizzaDoorGlass = true, PizzaGlassNorth = true, DoorTransom = true }
type Sign = { gui: SurfaceGui, li: number, brightness: number }
local signs: {Sign} = {}
local shopLights: {SurfaceLight} = {}

local function addSign(g: Instance)
	if not g:IsA("SurfaceGui") or string.sub(g.Name, 1, 12) == "NightFacade_" or g:GetAttribute("NightSign") then return end
	local part = g.Parent
	if not part or not part:IsA("BasePart") or g.LightInfluence < 0.05 then return end
	local hit = false
	for _, w in ipairs(SIGN_WORDS) do
		if string.find(part.Name, w, 1, true) then hit = true break end
	end
	if not hit then return end
	g:SetAttribute("NightSign", true)
	table.insert(signs, { gui = g, li = g.LightInfluence, brightness = g.Brightness })
end

local function addShopGlass(p: Instance)
	if not p:IsA("BasePart") or not SHOP_GLASS[p.Name] or p:FindFirstChild("NightShopLight") then return end
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local l = Instance.new("SurfaceLight")
		l.Name = "NightShopLight"
		l.Face = face
		l.Color = WARM
		l.Range = 14
		l.Brightness = 1.1
		l.Angle = 100
		l.Enabled = false
		l.Parent = p
		table.insert(shopLights, l)
	end
end

local shopsOn: boolean? = nil
local function setShops(on: boolean)
	if shopsOn == on then return end
	shopsOn = on
	for i = #signs, 1, -1 do
		local s = signs[i]
		if not s.gui.Parent then
			table.remove(signs, i)
		else
			s.gui.LightInfluence = if on then 0 else s.li
			s.gui.Brightness = if on then math.max(s.brightness, 1.2) else s.brightness
		end
	end
	for i = #shopLights, 1, -1 do
		local l = shopLights[i]
		if not l.Parent then table.remove(shopLights, i) else l.Enabled = on end
	end
end

local function scanShops()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SurfaceGui") then addSign(d) elseif d:IsA("BasePart") and SHOP_GLASS[d.Name] then addShopGlass(d) end
	end
end

---------------------------------------------------------------- run
task.spawn(function()
	task.wait(3) -- (streamed-in parts first)
	scan()
	scanLamps()
	scanShops()
	lightsOn = nil -- (the windows and facades found now take the hour's state on the next check)
	shopsOn = nil
	-- parts streamed in later
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and WINDOW_NAMES[d.Name] then
			addWindow(d)
			if lightsOn and windows[#windows].part == d then
				local w = windows[#windows]
				if w.lit then
					d.Material = Enum.Material.Neon
					d.Color = if w.cool then WINDOW_COOL else WINDOW_WARM
				end
			end
		elseif d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			if d.Name ~= "NightShopLight" then lamp(d) end
		elseif d:IsA("SurfaceGui") then
			task.defer(function() addSign(d) shopsOn = nil end)
		elseif d:IsA("BasePart") and SHOP_GLASS[d.Name] then
			addShopGlass(d)
			shopsOn = nil
		end
	end)
end)

local last = -1
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - last < 0.25 then return end
	last = now
	local n = nightAmount(Lighting.ClockTime)
	sky(n)
	setWindows(n > 0.5)
	setShops(n > 0.5)
end)

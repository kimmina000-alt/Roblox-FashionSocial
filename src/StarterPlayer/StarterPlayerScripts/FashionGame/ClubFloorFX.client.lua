--!strict
-- Club dance floor lights (user 2026-10-30, from a club video of another
-- game): rings grow out across the floor from a spot and every 4-stud tile
-- they pass lights up and fades again. Drawn on the floor's own tile grid
-- (the grout lines run every 4 studs: x = 4k, z = 4k + 2) with one SurfaceGui
-- of tile frames on a see-through sheet just above the floor, so the grout
-- still shows between the tiles.
-- Every client draws the same rings: they start on a shared beat
-- (GetServerTimeNow) from spots picked with that beat's number as the seed.
-- Only drawn while this player is near the club, and still while the DJ
-- has the music paused.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")

-- the dance floor in front of the DJ stage (whole tiles)
local X0, X1 = 104, 152
local Z0, Z1 = -250, -158
local TOP = -23.97 -- (floor top -24.0, grout -23.98)
local TILE = 4
local BEAT = 1.25 -- a new ring every beat
local RING_SPEED = 22 -- studs per second
local RING_LIFE = 3.2 -- seconds a ring runs
local RING_WIDTH = 5 -- studs of lit tiles at the ring's edge
local NEAR = 140 -- drawn when the camera is this close

local COLORS = {
	Color3.fromRGB(255, 40, 90), -- red-pink
	Color3.fromRGB(255, 60, 200), -- pink
	Color3.fromRGB(60, 220, 255), -- cyan
	Color3.fromRGB(150, 80, 255), -- violet
}

local cols = (X1 - X0) // TILE
local rows = (Z1 - Z0) // TILE

local sheet = Instance.new("Part")
sheet.Name = "ClubFloorFX"
sheet.Anchored = true
sheet.CanCollide = false
sheet.CanQuery = false
sheet.CanTouch = false
sheet.CastShadow = false
sheet.Transparency = 1
sheet.Size = Vector3.new(X1 - X0, 0.02, Z1 - Z0)
sheet.CFrame = CFrame.new((X0 + X1) / 2, TOP, (Z0 + Z1) / 2)

local gui = Instance.new("SurfaceGui")
gui.Name = "Tiles"
gui.Face = Enum.NormalId.Top
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 8
gui.LightInfluence = 0
gui.Brightness = 2.5
gui.AlwaysOnTop = false
gui.Parent = sheet

-- tile frames by grid place. On this sheet's Top face the gui's x runs along
-- world -Z from Z1 and its y along world +X from X0 (measured in Play with a
-- marker in the gui's corner, seen from straight above)
type Tile = { frame: Frame, x: number, z: number }
local tiles: {Tile} = {}
for c = 0, cols - 1 do
	for r = 0, rows - 1 do
		local x, z = X0 + (c + 0.5) * TILE, Z0 + (r + 0.5) * TILE
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale((Z1 - z) / (Z1 - Z0), (x - X0) / (X1 - X0))
		f.Size = UDim2.new(1 / rows, -3, 1 / cols, -3) -- (a gap so the grout shows)
		f.BackgroundTransparency = 1
		f.Parent = gui
		table.insert(tiles, { frame = f, x = x, z = z })
	end
end
sheet.Parent = workspace

-- the rings alive at time t: { centre, radius, strength, colour }
local function rings(t: number): {{ x: number, z: number, r: number, k: number, color: Color3 }}
	local list = {}
	local newest = math.floor(t / BEAT)
	for beat = newest - math.ceil(RING_LIFE / BEAT), newest do
		local age = t - beat * BEAT
		if age >= 0 and age < RING_LIFE then
			local rng = Random.new(beat)
			table.insert(list, {
				x = X0 + 6 + rng:NextNumber() * (X1 - X0 - 12),
				z = Z0 + 6 + rng:NextNumber() * (Z1 - Z0 - 12),
				r = age * RING_SPEED,
				k = 1 - age / RING_LIFE,
				color = COLORS[beat % #COLORS + 1],
			})
		end
	end
	return list
end

local shown = false
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	local near = camera ~= nil and (camera.CFrame.Position - sheet.Position).Magnitude < NEAR
	local paused = FashionGame:GetAttribute("ClubMusicPaused") == true
	if not near or paused then
		if shown then
			for _, tile in ipairs(tiles) do tile.frame.BackgroundTransparency = 1 end
			shown = false
		end
		return
	end
	shown = true
	local t = workspace:GetServerTimeNow()
	local list = rings(t)
	for _, tile in ipairs(tiles) do
		local best, color = 0, COLORS[1]
		for _, ring in ipairs(list) do
			local d = math.abs(math.sqrt((tile.x - ring.x) ^ 2 + (tile.z - ring.z) ^ 2) - ring.r)
			if d < RING_WIDTH then
				local v = (1 - d / RING_WIDTH) * ring.k
				if v > best then best, color = v, ring.color end
			end
		end
		local f = tile.frame
		if best > 0.02 then
			f.BackgroundColor3 = color
			f.BackgroundTransparency = 1 - best * 0.85
		elseif f.BackgroundTransparency < 1 then
			f.BackgroundTransparency = 1
		end
	end
end)

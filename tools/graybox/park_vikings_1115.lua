--!nocheck
-- 미니바이킹 / 슈퍼바이킹 (D-1424, user 2026-11-15: "미니 바이킹 얘네 묶음으로 저장해 놔 / 미니 바이킹이랑
-- 슈퍼바이킹 3d 파일 보냄. 메테리얼 이미지 사진 보고 제작", photos: a mini viking with a yellow
-- A-frame, yellow arms and picture panels, a red/yellow boat; a super viking with a red-brown steel
-- truss frame and a deep red boat with gold trim).
--
-- The two rides live OUTSIDE Hongdae_Layout, so a chain run cannot wipe them:
--   Workspace["미니바이킹"]  the user's mini viking set (stage, stairs, sign, fences, fence walls; the
--                           user built and placed them by hand) + "Ride" built here
--   Workspace["슈퍼바이킹"]  "Base" + "Ride" built here
-- park_layout_1111 no longer builds their blockouts when these models are there.
--
-- "Ride" (Model, pivot = the axle, LookVector = along the boat) holds the frame and the "Swing"
-- model (arms + boat, pivot = the axle too), so a later swinging ride only has to turn "Swing" about
-- the axle (its X axis).
-- The boats are the user's meshes, place-only templates in ServerStorage.ArtAssets:
--   VikingBoatMini / VikingBoatSuper (MeshPart "Boat"; *_Tex = the re-UV'd, painted glbs
--   docs/04_ART/park/viking_tex, used first when the user has imported them).
-- Idempotent: "Ride" is built anew each run. Run in Edit mode (chain step after park_layout_1111).

local SS = game:GetService("ServerStorage")
local art = SS:WaitForChild("ArtAssets")

local function quiet(p: BasePart, collide: boolean?)
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CastShadow = true
end

local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(t, t, (b - a).Magnitude)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Color = color
	p.Material = mat or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	quiet(p, true)
	p.Parent = parent
	return p
end

local function ball(parent: Instance, name: string, at: Vector3, d: number, color: Color3, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * d
	p.CFrame = CFrame.new(at)
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	quiet(p)
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, name: string, cf: CFrame, len: number, d: number, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(len, d, d) -- (along the CFrame's X)
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Metal
	quiet(p, true)
	p.Parent = parent
	return p
end

local function boatTemplate(kind: string): MeshPart?
	for _, n in ipairs({ "VikingBoat" .. kind .. "_Tex", "VikingBoat" .. kind }) do
		local m = art:FindFirstChild(n)
		local b = m and (m:FindFirstChild("Boat") or m:FindFirstChildWhichIsA("MeshPart"))
		if b then return b end
	end
	return nil
end

-- one viking ride. o = the axle's middle (y = the axle); spec:
--   len / width / height: the boat; restY: the boat's bottom at rest; legX / footX: the A-frames'
--   x at the top / at the feet; footZ: the feet along the boat; groundY; colors
local function build(owner: Model, kind: string, o: Vector3, s)
	local old = owner:FindFirstChild("Ride")
	if old then old:Destroy() end
	local ride = Instance.new("Model")
	ride.Name = "Ride"
	local frame = Instance.new("Model")
	frame.Name = "Frame"
	frame.Parent = ride
	local swing = Instance.new("Model")
	swing.Name = "Swing"
	swing.Parent = ride

	-- the A-frames (one each side of the boat) and the axle
	for _, sx in ipairs({ -1, 1 }) do
		local top = o + Vector3.new(sx * s.legX, 0, 0)
		local feet = {}
		for _, sz in ipairs({ -1, 1 }) do
			local foot = Vector3.new(o.X + sx * s.footX, s.groundY, o.Z + sz * s.footZ)
			table.insert(feet, foot)
			beam(frame, "Leg", top, foot, s.leg, s.frameColor)
			local pad = Instance.new("Part")
			pad.Name = "Foot"
			pad.Size = Vector3.new(s.leg * 2.2, 0.6, s.leg * 2.2)
			pad.CFrame = CFrame.new(foot + Vector3.new(0, 0.3, 0))
			pad.Color = s.footColor
			pad.Material = Enum.Material.Metal
			quiet(pad, true)
			pad.Parent = frame
			if s.bulbs then -- lamps down the legs
				for k = 1, s.bulbs do
					local a = k / (s.bulbs + 1)
					local at = top:Lerp(foot, a) + Vector3.new(sx * (s.leg / 2 + 0.15), 0, 0)
					ball(frame, "Bulb", at, s.leg * 0.55, Color3.fromRGB(255, 235, 190), true)
				end
			end
		end
		-- cross braces between the two legs of this A
		for _, h in ipairs(s.braces) do
			local a = top:Lerp(feet[1], h)
			local b = top:Lerp(feet[2], h)
			beam(frame, "Brace", a, b, s.leg * 0.6, s.frameColor)
		end
		if s.truss then -- zig-zag inside the A (the super viking's steel truss)
			local n = 6
			for k = 0, n - 1 do
				local h0, h1 = 0.12 + 0.8 * k / n, 0.12 + 0.8 * (k + 1) / n
				local a = top:Lerp(feet[(k % 2) + 1], h0)
				local b = top:Lerp(feet[((k + 1) % 2) + 1], h1)
				beam(frame, "Truss", a, b, s.leg * 0.35, s.frameColor)
			end
		end
		cyl(frame, "Hub", CFrame.new(top + Vector3.new(sx * s.leg * 0.6, 0, 0)), s.leg * 0.9, s.leg * 2.4, s.hubColor)
	end
	cyl(frame, "Axle", CFrame.new(o), s.legX * 2 + s.leg * 2, s.leg * 0.9, Color3.fromRGB(150, 150, 155))

	-- the boat
	local tmpl = boatTemplate(kind)
	local boatMid = Vector3.new(o.X, s.restY + s.height / 2, o.Z)
	if tmpl then
		local boat = tmpl:Clone()
		boat.Name = "Boat"
		boat.Size = Vector3.new(s.width, s.height, s.len)
		boat.CFrame = CFrame.new(boatMid)
		if boat.TextureID == "" then boat.Color = s.boatColor end
		quiet(boat)
		boat.Parent = swing
	end
	-- the arms: from the hubs down to the boat's sides, a V each side, plus a middle hanger
	local rimY = s.restY + s.height * 0.8
	for _, sx in ipairs({ -1, 1 }) do
		local top = o + Vector3.new(sx * (s.width / 2 + s.arm * 0.6), 0, 0)
		for _, sz in ipairs({ -1, 1 }) do
			local low = Vector3.new(o.X + sx * (s.width / 2 + s.arm * 0.6), rimY, o.Z + sz * s.armZ)
			beam(swing, "Arm", top, low, s.arm, s.armColor)
		end
		beam(swing, "Hanger", top, Vector3.new(top.X, rimY, o.Z), s.arm * 0.8, s.armColor)
		beam(swing, "ArmBrace", Vector3.new(top.X, rimY + 0.2, o.Z - s.armZ), Vector3.new(top.X, rimY + 0.2, o.Z + s.armZ), s.arm * 0.7, s.armColor)
		if s.panels then -- picture boards between the arms (plain colours, no characters)
			for k, sz in ipairs({ -1, 1 }) do
				local mid = top:Lerp(Vector3.new(top.X, rimY, o.Z + sz * s.armZ), 0.55)
				local p = Instance.new("Part")
				p.Name = "Panel"
				p.Size = Vector3.new(0.3, s.panels.Y, s.panels.X)
				p.CFrame = CFrame.new(mid + Vector3.new(sx * 0.35, 0, -sz * s.panels.X * 0.25))
				p.Color = ({ Color3.fromRGB(120, 200, 240), Color3.fromRGB(255, 160, 200) })[k]
				p.Material = Enum.Material.SmoothPlastic
				quiet(p)
				p.Parent = swing
				local rim = p:Clone()
				rim.Name = "PanelRim"
				rim.Size = p.Size + Vector3.new(-0.1, 0.5, 0.5)
				rim.Color = s.hubColor
				rim.CFrame = p.CFrame * CFrame.new(sx * -0.1, 0, 0)
				rim.Parent = swing
			end
		end
		if s.armBulbs then
			for _, sz in ipairs({ -1, 1 }) do
				local low = Vector3.new(top.X, rimY, o.Z + sz * s.armZ)
				for k = 1, s.armBulbs do
					ball(swing, "Bulb", top:Lerp(low, k / (s.armBulbs + 1)) + Vector3.new(sx * (s.arm / 2 + 0.12), 0, 0), s.arm * 0.6, Color3.fromRGB(255, 235, 190), true)
				end
			end
		end
	end
	ride.WorldPivot = CFrame.new(o)
	swing.WorldPivot = CFrame.new(o)
	ride.Parent = owner
	return ride
end

-- 미니바이킹: on the user's stage (deck top y 20.25, middle x -256, z -521.6)
local mini = workspace:FindFirstChild("미니바이킹")
if mini then
	local deckY = 20.3
	build(mini, "Mini", Vector3.new(-256, 38.5, -521.6), {
		len = 25.1, width = 9.0, height = 6.4, restY = deckY + 1.3,
		legX = 6.4, footX = 8.6, footZ = 11.5, groundY = deckY, leg = 1.1,
		braces = { 0.62 }, bulbs = 5,
		arm = 0.8, armZ = 10.5, armBulbs = 4, panels = Vector2.new(5, 3.4),
		frameColor = Color3.fromRGB(250, 200, 30), footColor = Color3.fromRGB(215, 35, 40),
		hubColor = Color3.fromRGB(215, 35, 40), armColor = Color3.fromRGB(250, 200, 30),
		boatColor = Color3.fromRGB(250, 200, 30),
	})
end

-- 슈퍼바이킹: where its blockout stood (middle x -91.6, z -648.8, base top y 18.95)
local super = workspace:FindFirstChild("슈퍼바이킹")
if super then
	local baseY = 18.95
	build(super, "Super", Vector3.new(-91.6, 62, -648.8), {
		len = 50.1, width = 8.7, height = 7.3, restY = baseY + 2,
		legX = 6.8, footX = 11, footZ = 24, groundY = baseY, leg = 2.0,
		braces = { 0.35, 0.7 }, truss = true,
		arm = 1.3, armZ = 21, armBulbs = 6,
		frameColor = Color3.fromRGB(128, 58, 42), footColor = Color3.fromRGB(90, 90, 95),
		hubColor = Color3.fromRGB(150, 70, 50), armColor = Color3.fromRGB(128, 58, 42),
		boatColor = Color3.fromRGB(140, 32, 32),
	})
end
print("[park_vikings_1115] mini " .. tostring(mini ~= nil) .. ", super " .. tostring(super ~= nil))
return true

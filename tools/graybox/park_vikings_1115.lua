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
-- (D-1425, user 2026-11-15: "바이킹 사람 타서 흔들리는 것까지 구현") "Ride" carries the tag ParkViking
-- and the ride attributes (ParkConfig: Period, MaxAngle, Board / Ramp / Hold, Seat1..N, Exit, Reach):
-- ParkRideService seats riders, ParkRidesController swings "Swing" and the riders from the server
-- clock. (D-1427, the user's picture: the ㄴ-shaped blocks are the seats) each rider sits on the seat
-- pan (its top, the middle between the backrest and the front edge), back to the backrest (towards
-- the boat's end), facing the boat's middle. Seats sit on the boat's seat rows (read off the glbs: rows across the boat, two riders a
-- row, facing the boat's middle). The axles went up (mini 2.2, super 3.6) so the boats' ends clear
-- the floor at full swing (checked on the meshes: the ends reach further than the flat bottom).
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

-- (D-1428) "_Tex2" = the boat with its walls lowered above the seats (riders see out); its glb is
-- shorter, so it brings its own height / middle (glb units), see the specs' glb.v2
local function boatTemplate(kind: string): (MeshPart?, string?)
	for _, v in ipairs({ "_Tex3", "_Tex2", "_Tex", "" }) do -- (D-1436: _Tex3 = the user's own edit)
		local m = art:FindFirstChild("VikingBoat" .. kind .. v)
		local b = m and (m:FindFirstChild("Boat") or m:FindFirstChildWhichIsA("MeshPart"))
		if b then return b :: MeshPart, v end
	end
	return nil, nil
end

-- one viking ride. o = the axle's middle (y = the axle); spec:
--   len / width / height: the boat; restY: the boat's bottom at rest; legX / footX: the A-frames'
--   x at the top / at the feet; footZ: the feet along the boat; groundY; colors
local CollectionService = game:GetService("CollectionService")

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

	-- the boat (its height from the glb in use: s.sy studs per glb unit)
	local tmpl, variant = boatTemplate(kind)
	local gv = if variant == "_Tex3" then (s.glb.v3 or s.glb.v2) elseif variant == "_Tex2" then s.glb.v2 else s.glb
	s.height = gv.height * s.sy
	s.glb.height, s.glb.midY = gv.height, gv.midY
	if gv.rows then s.glb.rows = gv.rows end
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
		-- (D-1431, user: "해당 프레임 삭제. 뒤쪽도. 미니바이킹도": no middle hanger, no bar along the boat's side)
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
	-- the ride: seats (from the axle at rest), timing, where riders get off
	local g = s.glb
	local k = 0
	for _, zg in ipairs(g.rows) do
		local z = zg / g.len * s.len
		local y = s.restY + s.height / 2 + (g.seatTop - g.midY) / g.height * s.height - o.Y
		for _, xg in ipairs({ -g.seatX, g.seatX }) do
			k += 1
			local x = xg / g.width * s.width
			local at = Vector3.new(x, y, z)
			ride:SetAttribute("Seat" .. k, CFrame.lookAt(at, Vector3.new(x, y, 0)))
		end
	end
	for name, value in pairs(s.ride) do ride:SetAttribute(name, value) end
	local base = owner:FindFirstChild("Base")
	if s.baseSize and base and base:IsA("BasePart") then -- (D-1428) the base grows with the ride
		local top = base.Position.Y + base.Size.Y / 2
		base.Size = Vector3.new(s.baseSize.X, base.Size.Y, s.baseSize.Y)
		base.CFrame = CFrame.new(o.X, top - base.Size.Y / 2, o.Z)
	end
	-- the swinging part moves on every screen by itself: it must not shove anyone
	for _, d in ipairs(swing:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	CollectionService:AddTag(ride, "ParkViking")
	ride.Parent = owner
	return ride
end

-- 미니바이킹: on the user's stage (deck top y 20.25, middle x -256, z -521.6)
local mini = workspace:FindFirstChild("미니바이킹")
if mini then
	local deckY = 20.3
	-- (D-1439, user: "미니바이킹 기둥 더 높여 줘 / 사이에 기둥은 삭제": the axle 40.7 → 52, longer arms, no
	-- brace between the legs; the boat's end then clears the deck by 1.67 at full swing, was 0.59)
	build(mini, "Mini", Vector3.new(-256, 52, -521.6), {
		len = 25.1, width = 9.0, sy = 3.769, restY = deckY + 3.5,
		glb = { len = 6.698, width = 2.405, height = 1.698, midY = 0.945, seatTop = 0.66, seatX = 0.42, rows = { -2.708, -1.271, 1.271, 2.708 },
			v2 = { height = 1.1318, midY = 0.6623 } },
		ride = { Period = 4.2, MaxAngle = 50, Board = 15, Ramp = 8, Hold = 16, Reach = 18, Exit = Vector3.new(-243.5, deckY + 3, -521.6) },
		legX = 6.4, footX = 8.8, footZ = 13, groundY = deckY, leg = 1.2,
		braces = {}, bulbs = 7,
		arm = 0.85, armZ = 10.5, armBulbs = 6, -- (D-1428: the square boards between the arms removed)
		frameColor = Color3.fromRGB(250, 200, 30), footColor = Color3.fromRGB(215, 35, 40),
		hubColor = Color3.fromRGB(215, 35, 40), armColor = Color3.fromRGB(250, 200, 30),
		boatColor = Color3.fromRGB(250, 200, 30),
	})
end

-- 슈퍼바이킹: where its blockout stood (middle x -91.6, z -648.8, base top y 18.95); D-1477 (user: "슈퍼바이킹이랑
-- 놀이공원 벽 사이에 화단 넣고 길 넣으면서 바이킹 위치 서쪽으로 살짝 이동"): 6 west, x -97.6.
-- (D-1428, user: "슈퍼바이킹 1.3배 키우기", "올라가는 각도 더 높게") everything 1.3 times, the swing
-- up to 78° (the boat's lowest corner still 0.85 over the base, checked on the meshes)
local super = workspace:FindFirstChild("슈퍼바이킹")
if super then
	local baseY = 18.95
	local K = 1.3
	build(super, "Super", Vector3.new(-97.6, baseY + 46.65 * K, -648.8), {
		len = 50.1 * K, width = 8.7 * K, sy = 3.614 * K, restY = baseY + 5.6 * K,
		glb = { len = 13.907, width = 2.405, height = 2.02, midY = 1.106, seatTop = 1.016, seatX = 0.42, rows = { -6.29, -4.85, -3.42, -1.98, -0.54, 0.54, 1.98, 3.42, 4.85, 6.29 },
			v2 = { height = 1.4708, midY = 0.8318 },
			-- (D-1436, user: "슈퍼바이킹 가운데 의자 두 개 삭제했음": the user's Tex3 has no middle rows ±0.54)
			v3 = { height = 1.4708, midY = 0.8318, rows = { -6.29, -4.85, -3.42, -1.98, 1.98, 3.42, 4.85, 6.29 } } },
		ride = { Period = 7.2, MaxAngle = 78, Board = 15, Ramp = 12, Hold = 20, Reach = 34 * K, Exit = Vector3.new(-97.6 + 13 * K, baseY + 3, -648.8) },
		baseSize = Vector2.new(33.41 * K, 66.83 * K),
		legX = 6.8 * K, footX = 11 * K, footZ = 24 * K, groundY = baseY, leg = 2.0 * K,
		braces = {}, -- (D-1429, user: "슈퍼바이킹 기둥 사이에 있는 프레임들 삭제": no braces, no truss)
		arm = 1.3 * K, armZ = 21 * K, armBulbs = 6,
		frameColor = Color3.fromRGB(128, 58, 42), footColor = Color3.fromRGB(90, 90, 95),
		hubColor = Color3.fromRGB(150, 70, 50), armColor = Color3.fromRGB(128, 58, 42),
		boatColor = Color3.fromRGB(140, 32, 32),
	})
end
print("[park_vikings_1115] mini " .. tostring(mini ~= nil) .. ", super " .. tostring(super ~= nil))
return true

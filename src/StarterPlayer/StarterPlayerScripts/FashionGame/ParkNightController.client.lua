--!strict
-- 놀이공원 야경 (D-1530, user 2026-11-16: "놀이공원 야경 화려하게 구현해"). From 18:00 to 06:00 (the game
-- clock, like NightGlowController) and only while this screen's camera is near the park:
--   * the string lights (parts tagged "ParkNightBulb", tools/graybox/park_night_1116.lua): Neon, their
--     colours running along each string; by day plain coloured bulbs;
--   * the Ferris wheel's rim lights (Rotor.RimLight): a rainbow wave going round;
--   * the searchlights (tagged "ParkSearchlight": a head with a Beam to its "BeamEnd"): beams in the sky,
--     each sweeping its own circle;
--   * fireworks over the park every 20–35 s, a few shells at a time, the same on every screen (the shells
--     come from the server clock's slot).
-- Colours change a few times a second, not every frame, so a phone keeps up.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local NIGHT_FROM, NIGHT_TO = 18, 6
local PARK_CENTRE = Vector3.new(-160, 16, -520)
local NEAR = 700
local STEP_SECONDS = 0.16
local PALETTE = {
	Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 230, 60), Color3.fromRGB(90, 230, 110),
	Color3.fromRGB(60, 190, 255), Color3.fromRGB(150, 110, 255), Color3.fromRGB(255, 100, 210),
}

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= NIGHT_FROM or t < NIGHT_TO
end
local function near(): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - PARK_CENTRE).Magnitude < NEAR
end

---------------------------------------------------------------- the string lights
local bulbs: {BasePart} = {}
local seqOf: {[BasePart]: number} = {} -- (D-1532: read once, not 341 attribute reads a step)
local function addBulb(p: Instance)
	if p:IsA("BasePart") and not table.find(bulbs, p) then
		table.insert(bulbs, p)
		seqOf[p] = (p:GetAttribute("Seq") :: number?) or 0
	end
end
for _, p in ipairs(CollectionService:GetTagged("ParkNightBulb")) do addBulb(p) end
CollectionService:GetInstanceAddedSignal("ParkNightBulb"):Connect(addBulb)
CollectionService:GetInstanceRemovedSignal("ParkNightBulb"):Connect(function(p)
	local i = table.find(bulbs, p :: BasePart)
	if i then table.remove(bulbs, i) end
	seqOf[p :: BasePart] = nil
end)

---------------------------------------------------------------- the wheel: rim, rim lights and spokes
-- (the whole wheel glows at night, a rainbow going round it; each piece keeps its place in the wave by
-- its angle round the hub when first found)
local WHEEL_GLOW = { Rim = true, RimLight = true, Spoke = true }
-- (D-1572, user 2026-11-17 with a phone shot: "관람차 발광도 줄여 줘") the rainbow's brightness
-- (HSV value): 1 was a blinding disc on phones; Neon's glow follows its colour
local WHEEL_BRIGHT = 0.4
local rim: {{part: BasePart, day: Color3, dayMat: Enum.Material, angle: number}} = {}
local function findRim()
	-- (streaming: the list is made again whenever the number of wheel pieces here changed; each
	-- piece's day colour / material is kept on it the first time it is seen)
	local present = 0
	for _, wheel in ipairs(CollectionService:GetTagged("ParkWheel")) do
		local rotor = wheel:FindFirstChild("Rotor", true)
		for _, p in ipairs(rotor and rotor:GetChildren() or {}) do
			if p:IsA("BasePart") and WHEEL_GLOW[p.Name] then present += 1 end
		end
	end
	if present == #rim then return end
	table.clear(rim)
	for _, wheel in ipairs(CollectionService:GetTagged("ParkWheel")) do
		local rotor = wheel:FindFirstChild("Rotor", true)
		local hub = wheel:FindFirstChild("Hub", true)
		if rotor and hub and hub:IsA("BasePart") then
			for _, p in ipairs(rotor:GetChildren()) do
				if p:IsA("BasePart") and WHEEL_GLOW[p.Name] and p:GetAttribute("DayColor") == nil then
					p:SetAttribute("DayColor", p.Color)
					p:SetAttribute("DayMaterial", p.Material.Name)
				end
			end
			local c = hub.Position
			-- the wheel's plane from its rim: u = one rim piece's way out from the hub, w = the one most
			-- square to it, the angle of every piece measured in that plane
			local outs = {}
			for _, p in ipairs(rotor:GetChildren()) do
				if p:IsA("BasePart") and p.Name == "Rim" then table.insert(outs, (p.Position - c).Unit) end
			end
			local u = outs[1] or Vector3.yAxis
			local w = u
			for _, v in ipairs(outs) do
				if math.abs(v:Dot(u)) < math.abs(w:Dot(u)) then w = v end
			end
			w = (w - u * w:Dot(u)).Unit
			for _, p in ipairs(rotor:GetChildren()) do
				if p:IsA("BasePart") and WHEEL_GLOW[p.Name] then
					local rel = p.Position - c
					table.insert(rim, { part = p, day = p:GetAttribute("DayColor") :: Color3, dayMat = (Enum.Material :: any)[p:GetAttribute("DayMaterial")], angle = (math.atan2(rel:Dot(w), rel:Dot(u)) / (2 * math.pi)) % 1 })
				end
			end
		end
	end
end

---------------------------------------------------------------- the searchlights
type Light = { head: BasePart, beamEnd: BasePart, beam: Beam, phase: number }
local lights: {Light} = {}
local function addLight(head: Instance)
	if not head:IsA("BasePart") then return end
	-- (streaming: the rig's BeamEnd and the Beam may come in after the head)
	local rig = head.Parent
	local beamEnd = rig and rig:WaitForChild("BeamEnd", 10)
	local beam = head:WaitForChild("Beam", 10)
	if beamEnd and beamEnd:IsA("BasePart") and beam and beam:IsA("Beam") then
		for _, l in ipairs(lights) do
			if l.head == head then return end
		end
		table.insert(lights, { head = head, beamEnd = beamEnd, beam = beam, phase = (head:GetAttribute("Phase") :: number?) or 0 })
	end
end
for _, h in ipairs(CollectionService:GetTagged("ParkSearchlight")) do task.spawn(addLight, h) end
CollectionService:GetInstanceAddedSignal("ParkSearchlight"):Connect(function(h) task.spawn(addLight, h) end)

---------------------------------------------------------------- fireworks
local fireworks = Instance.new("Folder")
fireworks.Name = "ParkFireworks"
fireworks.Parent = workspace
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
-- (D-1726, user 2026-11-18: "놀이공원 폭죽 터질 때 폭죽 터지는 소리 넣기") a bang at each burst, from the shell up
-- in the sky (heard over the whole park, fainter further away); a little different pitch each time.
-- Creator Store "Firework_Explosion1" (free); the user may pick another (candidates in DECISIONS D-1726)
local BANG = "rbxassetid://130548883007767"
local function shell(seed: number, at: Vector3, height: number, color: Color3, delay: number)
	task.delay(delay, function()
		local rocket = Instance.new("Part")
		rocket.Name = "Rocket"
		rocket.Shape = Enum.PartType.Ball
		rocket.Size = Vector3.new(0.6, 0.6, 0.6)
		rocket.Material = Enum.Material.Neon
		rocket.Color = Color3.fromRGB(255, 230, 180)
		rocket.Anchored, rocket.CanCollide, rocket.CanQuery, rocket.CanTouch, rocket.CastShadow = true, false, false, false, false
		rocket.Position = at
		rocket.Parent = fireworks
		local a0 = Instance.new("Attachment", rocket)
		local a1 = Instance.new("Attachment", rocket)
		a1.Position = Vector3.new(0, -0.3, 0)
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.5
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150))
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = rocket
		local top = at + Vector3.new(0, height, 0)
		local rise = TweenService:Create(rocket, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = top })
		rise:Play()
		rise.Completed:Wait()
		rocket.Transparency = 1
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = SPARK
		burst.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
		burst.LightEmission = 1
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) })
		burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
		burst.Lifetime = NumberRange.new(1.4, 2.2)
		burst.Speed = NumberRange.new(26, 34)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Drag = 2.2
		burst.Acceleration = Vector3.new(0, -9, 0)
		burst.Rate = 0
		burst.Parent = a0
		burst:Emit(90)
		local bang = Instance.new("Sound")
		bang.Name = "FireworkBang"
		bang.SoundId = BANG
		-- (D-1728, user 2026-11-18: "폭죽 소리 1/4로 줄이기": 0.8 → 0.2; D-1729: "폭죽 소리 반으로 더 줄이고 환호성 끄는
		-- 거에 폭죽 소리도 넣어": 0.1, and none with the ☰ menu's switch off, attribute MuteCheer)
		-- (D-1737, user 2026-11-18: "놀이공원 폭죽소리 놀이공원 안에서만 들리게 해") heard only while this screen's camera
		-- is inside the park (its walls: x -280..-50, z -1460..-277, as ParkGatePassController)
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local inPark = eye.X > -280 and eye.X < -50 and eye.Z > -1460 and eye.Z < -277
		if Players.LocalPlayer:GetAttribute("MuteCheer") == true or not inPark then bang.Volume = 0 else bang.Volume = 0.1 end
		bang.PlaybackSpeed = 0.9 + (seed % 7) * 0.03
		bang.RollOffMode = Enum.RollOffMode.InverseTapered
		bang.RollOffMinDistance = 60
		bang.RollOffMaxDistance = 600
		bang.Parent = rocket
		bang:Play()
		local flash = Instance.new("PointLight")
		flash.Color, flash.Range, flash.Brightness = color, 60, 4
		flash.Parent = rocket
		TweenService:Create(flash, TweenInfo.new(1.2), { Brightness = 0 }):Play()
		task.delay(6, function() rocket:Destroy() end) -- (3 s until D-1726: the bang is 5 s long)
	end)
end
local lastSlot = -1
local function fireworksTick(now: number)
	-- one show per 27 s slot of the server clock, the same shells on every screen
	local slot = math.floor(now / 27)
	if slot == lastSlot then return end
	lastSlot = slot
	local rng = Random.new(slot)
	local n = rng:NextInteger(3, 6)
	for i = 1, n do
		local at = Vector3.new(rng:NextNumber(-240, -80), 20, rng:NextNumber(-700, -330))
		shell(slot * 10 + i, at, rng:NextNumber(70, 105), PALETTE[rng:NextInteger(1, #PALETTE)], (i - 1) * rng:NextNumber(0.35, 0.9))
	end
end

---------------------------------------------------------------- the loop
local wasOn: boolean? = nil
local step = 0
local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	local on = isNight() and near()
	if on ~= wasOn then
		wasOn = on
		findRim()
		for _, b in ipairs(bulbs) do
			if b:GetAttribute("DayColor") == nil then b:SetAttribute("DayColor", b.Color) end
			b.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			if not on then b.Color = b:GetAttribute("DayColor") :: Color3 end
		end
		for _, r in ipairs(rim) do
			r.part.Material = if on then Enum.Material.Neon else r.dayMat
			if not on then r.part.Color = r.day end
		end
		for _, l in ipairs(lights) do l.beam.Enabled = on end
		if not on then fireworks:ClearAllChildren() end
	end
	if not on then return end
	local now = workspace:GetServerTimeNow()
	-- searchlights every frame (four parts); a light streamed in after dusk is switched on here too
	for _, l in ipairs(lights) do
		if not l.beam.Enabled then l.beam.Enabled = true end
		local t = now * 0.32 + l.phase
		local pitch = math.rad(58 + 14 * math.sin(now * 0.21 + l.phase * 2))
		local dir = Vector3.new(math.cos(t) * math.cos(pitch), math.sin(pitch), math.sin(t) * math.cos(pitch))
		l.beamEnd.Position = l.head.Position + dir * 260
	end
	acc += dt
	if acc < STEP_SECONDS then return end
	acc = 0
	step += 1
	-- (pieces streamed in after dusk get the night look here: bulbs, and the wheel when it arrives)
	for _, b in ipairs(bulbs) do
		local seq = seqOf[b] or 0
		if b.Material ~= Enum.Material.Neon then
			if b:GetAttribute("DayColor") == nil then b:SetAttribute("DayColor", b.Color) end
			b.Material = Enum.Material.Neon
		end
		b.Color = PALETTE[(seq + step) % #PALETTE + 1]
	end
	if step % 12 == 0 then findRim() end
	-- the rim: a rainbow wave round the wheel
	for _, r in ipairs(rim) do
		if r.part.Material ~= Enum.Material.Neon then r.part.Material = Enum.Material.Neon end
		local hue = (r.angle + now * 0.12) % 1
		r.part.Color = Color3.fromHSV(hue, if r.part.Name == "Spoke" then 0.55 else 0.85, WHEEL_BRIGHT)
	end
	fireworksTick(now)
end)

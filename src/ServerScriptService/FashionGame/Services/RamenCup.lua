--!strict
-- 컵라면 (D-1053, user 2026-11-09): the user's model (D:\Roblox\오후\3D 물\cupraman3.glb
-- → ServerStorage.ArtAssets.Foods.CupRamen: Plate = the cup, Bite1 = the lid,
-- Bite2 = the dry noodles, Soup = the broth), made the real way:
--   "closed"  bought at OH24: the lid on
--   "open"    a tap on the cup in the hand: the lid off, dry noodles
--   "cooking" a tap on the store's hot water dispenser (HotWaterTap / HotWater /
--             HotWaterTray, tag HotWater): water pours, the lid back on; 10 s
--   "ready"   a tap after that: the lid off, broth (Soup) with steam, chopsticks
--   then three bites, each with chopsticks lifting red noodle strands from the
--   cup (in the left hand) that stretch on the way to the mouth and are
--   slurped up; the broth sinks a step every bite.
-- SnackService routes a tap on the cup ("Ramen"), on the dispenser ("HotWater")
-- and on the cup left on a table here; the bite itself stays SnackService's.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local RamenCup = {}

RamenCup.CookSeconds = 10
local DISPENSER_NAMES = { HotWaterTap = true, HotWater = true, HotWaterTray = true }
local DISPENSER_REACH = 14 -- studs from the player to the dispenser
local STRANDS = 7
local NOODLE = Color3.fromRGB(205, 70, 45) -- red (spicy broth on the noodles)
local NOODLE_YELLOW = Color3.fromRGB(235, 195, 95) -- (D-1081) 참깨라멘 / 육개그
-- (D-1063, user 2026-11-09) the sounds the user picked
local SOUND_LID = 75936211172606 -- 컵라면 뚜껑 뜯는 소리 (the lid off)
local SOUND_WATER = 9119158299 -- the beach 음수대's water (FountainTap), while the water pours
-- (D-1158, user 2026-11-10: "라면 국물 마시는 소리:133347729618467"; was 133241476322672)
local SOUND_BROTH = 133347729618467 -- 국물 마시는 소리 (the last sip: the cup to the mouth)
-- (the noodle bite itself: SnackService's Sip sound, 117267927001796 from 1 s in)
RamenCup.EatSound = 117267927001796
RamenCup.EatFrom = 1

local function playOnce(parent: Instance, id: number, volume: number, from: number?)
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxassetid://" .. tostring(id)
	snd.Volume = volume
	snd.RollOffMaxDistance = 40
	snd.Parent = parent
	if from then snd.TimePosition = from end
	snd:Play()
	task.delay(8, function() snd:Destroy() end)
	return snd
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- shows / hides one piece of the cup (its own see-through kept)
local function show(p: Instance?, on: boolean)
	if not p or not p:IsA("BasePart") then return end
	local t0 = p:GetAttribute("RamenT0")
	if typeof(t0) ~= "number" then
		t0 = if p.Transparency >= 1 then 0 else p.Transparency
		p:SetAttribute("RamenT0", t0)
	end
	p.Transparency = if on then t0 :: number else 1
	for _, d in ipairs(p:GetChildren()) do
		if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = if on then 0 else 1 end
		if d:IsA("ParticleEmitter") then d.Enabled = on and d:GetAttribute("On") == true end
	end
end

local function parts(handle: Instance, name: string): {BasePart}
	local out = {}
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == name then table.insert(out, d) end
	end
	return out
end

local function showAll(handle: Instance, name: string, on: boolean)
	for _, p in ipairs(parts(handle, name)) do show(p, on) end
end

-- what the cup looks like in each state
local function paint(handle: Instance, state: string)
	showAll(handle, "Bite1", state == "closed" or state == "cooking")
	showAll(handle, "Bite2", state ~= "ready")
	showAll(handle, "Soup", state == "ready")
	showAll(handle, "Chopsticks", state == "ready")
end

local function steam(p: BasePart, rate: number, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Steam"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.LightEmission = 0.15
	-- (D-1063, user: "라면에 김 올라오는 거 더 진하게 넣어 줘 잘 안 보임") thicker: 0.72 → 0.35 at its densest
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.35), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.3), NumberSequenceKeypoint.new(1, size) })
	e.Lifetime = NumberRange.new(1.2, 2.0)
	e.Rate = rate
	e.Speed = NumberRange.new(0.5, 1.1)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, 0.4, 0)
	e.RotSpeed = NumberRange.new(-30, 30)
	e:SetAttribute("On", true)
	e.Parent = p
	return e
end

local function weldOf(p: BasePart): Weld?
	local w = p:FindFirstChildOfClass("Weld")
	return if w and w.Part1 == p then w else nil
end

-- The cup just made by FoodShapes (before SnackService scales the tool):
-- chopsticks (two thin sticks and their tip, ChopTip) and the closed look.
function RamenCup.setup(tool: Tool, handle: BasePart)
	local soup = handle:FindFirstChild("Soup", true) :: BasePart?
	local plate = handle:FindFirstChild("Plate", true) :: BasePart?
	local soupY = if soup and weldOf(soup) then (weldOf(soup) :: Weld).C0.Y else 0.2
	local cupR = if plate then math.max(plate.Size.X, plate.Size.Z) / 2 else 0.4
	local LEN = 0.7
	-- standing in the cup: the tip end (-Y of each stick) down in the broth,
	-- leaning out over the rim on the right
	local stand = CFrame.new(cupR * 0.35, soupY + LEN / 2 - 0.12, 0) * CFrame.Angles(0, 0, math.rad(-18))
	-- held for a bite (D-956's way for the 수육 sticks): out of the fist along the
	-- grip's +Y, the tip end farthest; EatMotionController brings ChopTip to the lips
	local held = CFrame.new(0, LEN / 2 - 0.25, 0) * CFrame.Angles(0, 0, math.rad(180))
	for i, dx in ipairs({ -0.022, 0.022 }) do
		local stick = Instance.new("Part")
		stick.Name = "Chopsticks"
		stick.Size = Vector3.new(0.028, LEN, 0.028)
		stick.Color = Color3.fromRGB(205, 175, 125)
		stick.Material = Enum.Material.Wood
		stick.CanCollide, stick.CanQuery, stick.CanTouch, stick.Massless, stick.CastShadow = false, false, false, true, false
		local offset = stand * CFrame.new(dx, 0, 0)
		stick.CFrame = handle.CFrame * offset
		stick.Parent = handle
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = handle, stick, offset
		w.Parent = stick
		stick:SetAttribute("Stand", offset)
		stick:SetAttribute("Held", held * CFrame.new(dx * 0.5, 0, 0))
		if i == 1 then
			local tip = Instance.new("Part")
			tip.Name = "ChopTip"
			tip.Size = Vector3.new(0.05, 0.05, 0.05)
			tip.Transparency = 1
			tip.CanCollide, tip.CanQuery, tip.CanTouch, tip.Massless, tip.CastShadow = false, false, false, true, false
			tip.CFrame = stick.CFrame * CFrame.new(dx * -1, -LEN / 2 + 0.02, 0)
			tip.Parent = stick
			local tw = Instance.new("Weld")
			tw.Part0, tw.Part1, tw.C0 = stick, tip, CFrame.new(dx * -1, -LEN / 2 + 0.02, 0)
			tw.Parent = tip
		end
	end
	tool:SetAttribute("EatPart", "ChopTip")
	tool:SetAttribute("Ramen", "closed")
	-- (D-1063) three bites with the chopsticks, then the broth from the cup
	tool:SetAttribute("Bites", 4)
	tool.ToolTip = "눌러서 뚜껑 열기"
	paint(handle, "closed")
	tool.Equipped:Connect(function() task.defer(RamenCup.hold, tool, true) end)
	tool.Unequipped:Connect(function()
		-- (the copy is on the character; the tool is in the backpack or on a table by now)
		local owner = tool:GetAttribute("RamenOwner")
		local plr = if typeof(owner) == "number" then Players:GetPlayerByUserId(owner) else nil
		local cup = plr and plr.Character and plr.Character:FindFirstChild("RamenLeftCup")
		if cup then cup:Destroy() end
		RamenCup.hold(tool, false)
	end)
end

-- (scaled with the tool: the chopsticks' poses grow with it, SnackService scaleTool)
function RamenCup.scaled(handle: BasePart, k: number)
	for _, stick in ipairs(parts(handle, "Chopsticks")) do
		for _, key in ipairs({ "Stand", "Held" }) do
			local cf = stick:GetAttribute(key)
			if typeof(cf) == "CFrame" then stick:SetAttribute(key, CFrame.new(cf.Position * k) * cf.Rotation) end
		end
	end
end

local function pose(handle: BasePart, key: string)
	for _, stick in ipairs(parts(handle, "Chopsticks")) do
		local cf = stick:GetAttribute(key)
		local w = weldOf(stick)
		if w and typeof(cf) == "CFrame" then w.C0 = cf end
	end
end

local function heldRamen(player: Player): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("Ramen") then return tool end
	return nil
end

-- A tap on the cup (in the hand). eat = SnackService's bite. Returns ok, message.
function RamenCup.tap(player: Player, tool: Tool, eat: () -> ()): (boolean, string?)
	local character = player.Character
	if not character or tool.Parent ~= character then return false, nil end
	if tool:GetAttribute("Busy") then return false, nil end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then return false, nil end
	local state = tool:GetAttribute("Ramen")
	if state == "closed" then
		tool:SetAttribute("Ramen", "open")
		tool.ToolTip = "편의점 온수기를 눌러 물 붓기"
		paint(handle, "open")
		playOnce(handle, SOUND_LID, 0.8)
		return false, "뚜껑을 열었어요. 편의점 온수기를 눌러 뜨거운 물을 부어 주세요."
	elseif state == "open" then
		return false, "편의점 온수기를 눌러 뜨거운 물을 부어 주세요."
	elseif state == "cooking" then
		local at = tool:GetAttribute("RamenCookAt")
		local left = if typeof(at) == "number" then RamenCup.CookSeconds - (now() - at) else 0
		if left > 0 then
			return false, string.format("라면이 익고 있어요. %d초만 기다려 주세요.", math.ceil(left))
		end
		tool:SetAttribute("Ramen", "ready")
		tool.ToolTip = "눌러서 먹기"
		for _, e in ipairs(handle:GetDescendants()) do
			if e:IsA("ParticleEmitter") and e.Name == "LidSteam" then e:Destroy() end
		end
		local soup = handle:FindFirstChild("Soup", true) :: BasePart?
		if soup and not soup:FindFirstChild("Steam") then steam(soup, 22, math.max(soup.Size.X, soup.Size.Z) * 0.75) end
		paint(handle, "ready")
		playOnce(handle, SOUND_LID, 0.8)
		RamenCup.hold(tool, true)
		return true, nil
	elseif state == "ready" then
		task.spawn(eat)
		return true, nil
	end
	return false, nil
end

-- A tap on the hot water dispenser with the cup in the hand.
function RamenCup.pour(player: Player, target: any): (boolean, string?)
	if typeof(target) ~= "Instance" or not target:IsA("BasePart") or not CollectionService:HasTag(target, "HotWater") then return false, nil end
	local tool = heldRamen(player)
	if not tool then return false, "컵라면을 손에 들고 눌러 주세요." end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - target.Position).Magnitude > DISPENSER_REACH then return false, "온수기 가까이 가서 눌러 주세요." end
	local state = tool:GetAttribute("Ramen")
	if state == "closed" then return false, "먼저 라면을 눌러 뚜껑을 열어 주세요." end
	if state ~= "open" then return false, "이미 물을 부었어요." end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then return false, nil end
	tool:SetAttribute("Busy", true)
	-- the water: a thin stream from the tap down to the cup
	local tap: BasePart = target
	for _, d in ipairs((target.Parent :: Instance):GetChildren()) do
		if d:IsA("BasePart") and d.Name == "HotWaterTap" then tap = d end
	end
	local from = tap.Position - Vector3.new(0, tap.Size.Y / 2, 0)
	local to = handle.Position + Vector3.new(0, 0.3, 0)
	local len = math.max(0.3, (from - to).Magnitude)
	local stream = Instance.new("Part")
	stream.Name = "HotWaterStream"
	stream.Anchored, stream.CanCollide, stream.CanQuery, stream.CanTouch, stream.CastShadow = true, false, false, false, false
	stream.Material = Enum.Material.Glass
	stream.Color = Color3.fromRGB(200, 230, 255)
	stream.Transparency = 0.35
	stream.Shape = Enum.PartType.Cylinder
	-- (D-1081, user 2026-11-09: "컵라면 물 받을 때 물줄기 더 두껍게") 0.06 → 0.16
	stream.Size = Vector3.new(len, 0.16, 0.16)
	stream.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	stream.Parent = workspace
	steam(stream, 4, 0.4)
	local water = playOnce(stream, SOUND_WATER, 0.6)
	task.delay(1.4, function()
		water:Stop()
		stream:Destroy()
		if tool.Parent == nil then return end
		tool:SetAttribute("Busy", nil)
		tool:SetAttribute("Ramen", "cooking")
		tool:SetAttribute("RamenCookAt", now())
		tool.ToolTip = string.format("%d초 뒤에 눌러서 열기", RamenCup.CookSeconds)
		paint(handle, "cooking")
		-- done: a little steam from under the lid says so
		task.delay(RamenCup.CookSeconds, function()
			if tool.Parent == nil or tool:GetAttribute("Ramen") ~= "cooking" then return end
			tool.ToolTip = "다 익었어요! 눌러서 열기"
			for _, lid in ipairs(parts(handle, "Bite1")) do
				local e = steam(lid, 8, math.max(lid.Size.X, lid.Size.Z) * 0.45)
				e.Name = "LidSteam"
			end
		end)
	end)
	return true, nil
end

-- (bite) the noodle strands: from the chopstick tip (right hand) down to the
-- broth of the cup in the left hand; they stretch as the arm lifts the sticks
-- to the mouth, then are slurped up into the tip. Returns the clean-up.
-- (D-1099) the strands themselves, from `tip` down to `soup`, slurped up into the
-- tip after `slurpAfter` seconds; shared by the bite in the hand and the bite
-- taken from the cup on a table. Returns the clean-up.
local function makeStrands(tip: BasePart, soup: BasePart, key: any, slurpAfter: number): () -> ()
	local made: {Instance} = {}
	local lower: {Attachment} = {}
	local r = Random.new()
	-- (D-1081, user 2026-11-09: "용감꼬꼬면이랑 맵라면만 라면 선 붉은색으로 하고
	-- 참깨라면이랑 육개그는 노란색으로") the strands' colour by the ramen
	local yellow = key == "ramen_sesame" or key == "ramen_yukgae"
	local base = if yellow then NOODLE_YELLOW else NOODLE
	local light = if yellow then Color3.fromRGB(255, 235, 150) else Color3.fromRGB(240, 120, 70)
	for i = 1, STRANDS do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(r:NextNumber(-0.03, 0.03), r:NextNumber(-0.02, 0.02), r:NextNumber(-0.03, 0.03))
		a0.Parent = tip
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(r:NextNumber(-0.25, 0.25) * soup.Size.X, 0, r:NextNumber(-0.25, 0.25) * soup.Size.Z)
		a1.Parent = soup
		local beam = Instance.new("Beam")
		beam.Name = "Noodle"
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Color = ColorSequence.new(base:Lerp(light, r:NextNumber(0, 0.5)))
		beam.Width0, beam.Width1 = 0.035, 0.045
		beam.FaceCamera = true
		beam.Segments = 12
		-- a little sag, each one different
		beam.CurveSize0 = r:NextNumber(-0.25, 0.05)
		beam.CurveSize1 = r:NextNumber(-0.05, 0.25)
		beam.LightInfluence = 0.6
		beam.Transparency = NumberSequence.new(0)
		beam.Parent = tip
		table.insert(made, a0)
		table.insert(made, a1)
		table.insert(made, beam)
		table.insert(lower, a1)
	end
	-- slurp: the lower ends come off the broth and run up into the tip
	task.delay(slurpAfter, function()
		if not tip.Parent then return end
		local starts = {}
		for i, a1 in ipairs(lower) do
			local world = a1.WorldPosition
			a1.Parent = tip
			a1.WorldPosition = world
			starts[i] = a1.Position
		end
		local t0 = os.clock()
		while os.clock() - t0 < 0.32 do
			local k = (os.clock() - t0) / 0.32
			k = k * k
			for i, a1 in ipairs(lower) do
				if a1.Parent then a1.Position = starts[i]:Lerp(Vector3.zero, k) end
			end
			task.wait()
		end
		for _, a1 in ipairs(lower) do if a1.Parent then a1.Position = Vector3.zero end end
	end)
	return function()
		for _, d in ipairs(made) do d:Destroy() end
	end
end

function RamenCup.strands(handle: BasePart, cup: Instance): () -> ()
	pose(handle, "Held")
	local tip = handle:FindFirstChild("ChopTip", true) :: BasePart?
	local soup = cup:FindFirstChild("Soup", true) :: BasePart?
	if not tip or not soup then return function() pose(handle, "Stand") end end
	local tool = handle:FindFirstAncestorOfClass("Tool")
	return makeStrands(tip, soup, tool and tool:GetAttribute("Snack"), 0.95)
end

-- (D-1099, user 2026-11-09: "컵라면 테이블에 두고 먹을 때도 면 길게 이어지는 거
-- 넣어 줘") a bite from the cup on a table: the strands from the noodles on the
-- loose chopsticks (`tip`) down to the broth of the cup on the table (`copy`),
-- stretching as the hand lifts them, slurped up at the mouth
function RamenCup.tableStrands(tip: BasePart, copy: Instance, key: any, slurpAfter: number): () -> ()
	local soup = copy:FindFirstChild("Soup", true) :: BasePart?
	if not soup then return function() end end
	return makeStrands(tip, soup, key, slurpAfter)
end

-- (bite done) the broth a step lower, a little narrower (the cup narrows down)
function RamenCup.afterBite(tool: Tool, handle: BasePart, left: number, total: number)
	if left <= 0 then return end
	local plate = handle:FindFirstChild("Plate", true) :: BasePart?
	local depth = (if plate then plate.Size.Y else 0.8) * 0.17
	for _, soup in ipairs(parts(handle, "Soup")) do
		local w = weldOf(soup)
		if w then w.C0 = w.C0 * CFrame.new(0, -depth, 0) end
		soup.Size = Vector3.new(soup.Size.X * 0.95, soup.Size.Y, soup.Size.Z * 0.95)
	end
	-- the chopsticks (standing in it on a table) go down with it
	for _, stick in ipairs(parts(handle, "Chopsticks")) do
		local cf = stick:GetAttribute("Stand")
		if typeof(cf) == "CFrame" then stick:SetAttribute("Stand", cf * CFrame.new(0, -depth, 0)) end
	end
	-- the cup in the left hand shows the new level
	local tool = handle.Parent
	if tool and tool:IsA("Tool") then
		RamenCup.hold(tool, false)
		RamenCup.hold(tool, true)
	end
end

-- (D-1063, user 2026-11-09: "라면 왼손에 들고 있고 오른손에 젓가락 들고 라면 먹는
-- 모션으로 수정") once it is ready and in the hand: the cup in the left hand (a
-- copy welded to it), only the chopsticks in the right (the tool's handle);
-- back into the one hand when it is put away or on a table
local function leftGrip(character: Model): Attachment?
	local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	return hand and hand:FindFirstChild("LeftGripAttachment") :: Attachment?
end
function RamenCup.hold(tool: Tool, on: boolean)
	local character = tool.Parent
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then return end
	local old = character and character:IsA("Model") and character:FindFirstChild("RamenLeftCup")
	if old then old:Destroy() end
	local ready = tool:GetAttribute("Ramen") == "ready"
	local grip = character and character:IsA("Model") and leftGrip(character)
	if not on or not ready or not grip then
		-- one hand again: the whole cup on the handle, the sticks standing in it
		for _, d in ipairs(handle:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("RamenHeld") then
				d:SetAttribute("RamenHeld", nil)
				d.LocalTransparencyModifier = 0
				d.Transparency = d:GetAttribute("RamenHeldT") :: number? or d.Transparency
			end
		end
		if ready then
			paint(handle, "ready")
			pose(handle, "Stand")
		end
		return
	end
	local cup = handle:Clone()
	for _, d in ipairs(cup:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Chopsticks" or d.Name == "ChopTip") then d:Destroy()
		elseif d:IsA("Sound") then d:Destroy() end
	end
	for _, d in ipairs(cup:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			-- (what was hidden on the handle for the hold is shown on the copy)
			local t = d:GetAttribute("RamenHeldT")
			if typeof(t) == "number" then d.Transparency = t d:SetAttribute("RamenHeld", nil) end
		end
	end
	for _, e in ipairs(cup:GetDescendants()) do
		if e:IsA("ParticleEmitter") and e:GetAttribute("On") then e.Enabled = true end
	end
	cup.Name = "RamenLeftCup"
	cup.Anchored = false
	-- every piece moved with it (moving only the root, its welded pieces pulled it
	-- back to where the right hand held it: the cup hung 5 studs off the left hand)
	-- (upright, as the body stands: the left grip's own turn tipped it over in Play)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local upright = if root then CFrame.new(grip.WorldPosition) * root.CFrame.Rotation * CFrame.new(0, 0.15, -0.1)
		else grip.WorldCFrame * tool.Grip:Inverse()
	local move = upright * handle.CFrame:Inverse()
	for _, d in ipairs({ cup, unpack(cup:GetDescendants()) }) do
		if d:IsA("BasePart") then d.CFrame = move * d.CFrame end
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = grip.Parent :: BasePart
	w.Part1 = cup
	w.Parent = cup
	cup.Parent = character
	local plr = Players:GetPlayerFromCharacter(character)
	if plr then tool:SetAttribute("RamenOwner", plr.UserId) end
	-- the handle keeps only the chopsticks, held out of the right fist
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Chopsticks" and d.Name ~= "ChopTip" and d.Transparency < 1 then
			d:SetAttribute("RamenHeldT", d.Transparency)
			d:SetAttribute("RamenHeld", true)
			d.Transparency = 1
		end
		if d:IsA("ParticleEmitter") and d:IsDescendantOf(handle) then d.Enabled = false end
	end
	pose(handle, "Held")
end

-- the cup held in the left hand now (the bite's strands go down into it)
function RamenCup.leftCup(tool: Tool): Instance?
	local character = tool.Parent
	return character and character:IsA("Model") and character:FindFirstChild("RamenLeftCup") or nil
end

-- (D-1063, user: "컵라면 bite 다 먹은 후 컵라면 자체를 들고 입에 가져다 대면서
-- 마시는 모션, 그때 국물 마시는 소리") the last tap: the cup back in the right
-- hand, no chopsticks, the rim to the mouth (EatMotionController: no EatPart →
-- the farthest point of what is held), the broth sound. Returns the clean-up.
function RamenCup.drinkStart(tool: Tool, handle: BasePart): () -> ()
	RamenCup.hold(tool, false)
	showAll(handle, "Chopsticks", false)
	tool:SetAttribute("EatPart", nil)
	playOnce(handle, SOUND_BROTH, 1.2)
	return function() end
end

-- (D-1090) the noodles' colour of this ramen (red; 참깨라멘 / 육개그 yellow)
function RamenCup.noodleColor(key: any): Color3
	return if key == "ramen_sesame" or key == "ramen_yukgae" then NOODLE_YELLOW else NOODLE
end

-- (D-1090, user 2026-11-09: "컵라면 테이블 위에 두면 테이블에 있는 상태에서
-- 젓가락으로 먹게 하고") a bite taken from the cup on the table: the copy's
-- broth a step lower (like afterBite in the hand), its sticks with it
function RamenCup.tableBite(copy: BasePart, left: number)
	if left <= 0 then return end
	local plate = copy:FindFirstChild("Plate", true) :: BasePart?
	local depth = (if plate then plate.Size.Y else 0.8) * 0.17
	for _, soup in ipairs(parts(copy, "Soup")) do
		soup.CFrame -= Vector3.new(0, depth, 0)
		soup.Size = Vector3.new(soup.Size.X * 0.95, soup.Size.Y, soup.Size.Z * 0.95)
	end
	for _, stick in ipairs(parts(copy, "Chopsticks")) do
		stick.CFrame -= Vector3.new(0, depth, 0)
	end
end

-- (D-1189, user 2026-11-10: "컵라면 물 받은 후 테이블에 놓은 상태로 클릭하면 테이블에
-- 놓인 상태에서 뚜껑 열리게 해") the cooked cup opened where it stands on the table:
-- the copy (and the tool kept aside) go "ready", steam from the broth, the
-- lid's sound; the cup stays on the table for the chopsticks. Before the 10 s
-- are over it only says how long is left.
function RamenCup.openOnTable(tool: Tool, copy: BasePart): (boolean, string?)
	if tool:GetAttribute("Ramen") ~= "cooking" then return false, nil end
	local at = tool:GetAttribute("RamenCookAt")
	local left = if typeof(at) == "number" then RamenCup.CookSeconds - (now() - at) else 0
	if left > 0 then
		return false, string.format("라면이 익고 있어요. %d초만 기다려 주세요.", math.ceil(left))
	end
	tool:SetAttribute("Ramen", "ready")
	tool.ToolTip = "눌러서 먹기"
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	for _, root in ipairs({ copy :: Instance, handle :: Instance }) do
		if root then
			for _, e in ipairs(root:GetDescendants()) do
				if e:IsA("ParticleEmitter") and e.Name == "LidSteam" then e:Destroy() end
			end
			local soup = root:FindFirstChild("Soup", true) :: BasePart?
			if soup and not soup:FindFirstChild("Steam") then steam(soup, 22, math.max(soup.Size.X, soup.Size.Z) * 0.75) end
			paint(root, "ready")
		end
	end
	playOnce(copy, SOUND_LID, 0.8)
	return true, nil
end

-- a copy put on a table: the whole cup as it is now, the sticks standing in it
function RamenCup.tableLook(copy: BasePart, tool: Tool)
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			local t = d:GetAttribute("RamenHeldT")
			if typeof(t) == "number" then d.Transparency = t end
			d:SetAttribute("RamenHeld", nil)
			d:SetAttribute("RamenHeldT", nil)
			if d.Name == "Chopsticks" then
				local stand = d:GetAttribute("Stand")
				if typeof(stand) == "CFrame" then d.CFrame = copy.CFrame * stand end
			end
		end
	end
	local state = tool:GetAttribute("Ramen")
	if typeof(state) == "string" then paint(copy, state) end
end

function RamenCup.Start()
	-- the OH24 hot water dispenser answers taps (SnackController asks "HotWater")
	local function tag(d: Instance)
		if d:IsA("BasePart") and DISPENSER_NAMES[d.Name] and d:IsDescendantOf(workspace) then
			CollectionService:AddTag(d, "HotWater")
			d.CanQuery = true
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do tag(d) end
	workspace.DescendantAdded:Connect(tag)
end

return RamenCup

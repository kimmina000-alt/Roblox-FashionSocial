--!strict
-- Sparklers, the stage cold spark and supporter gifts (docs/01_SYSTEMS/
-- CLUB_SHOP_PRICING.md §5, §11, §13; D-270..D-272). All Robux developer
-- products (ids 0 = Studio test purchases).
--
--   Table sparkler (15 R$)   sparks over the buyer's bottle on the table they
--                            picked, 30 s.
--   Sparkler bucket (49 R$)  an ice bucket with 3 cans on that table (18 cups
--                            for everyone) and 3 sparklers one after another.
--   Stage cold spark (99 R$) fountains along the DJ stage front for 10 s;
--                            every player sees a banner with the buyer's name
--                            and message. One per server every 2 minutes
--                            (a purchase during the wait starts when it ends).
--   Supporter gifts          10 / 50 / 100 / 500 / 1,000 / 5,000 R$: the same
--                            banner, nothing else (totals: RankingService).
--
-- Before buying, the client sends the table ("SetTable") and the message
-- ("SetMessage"). Messages are filtered for everyone (TextService) and are
-- never shown unfiltered.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Debris = game:GetService("Debris")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local MonetizationService = require(script.Parent.MonetizationService)
local DrinkService = require(script.Parent.DrinkService)

local SparkleService = {}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARKLER_SECONDS = 30
local COLD_SPARK_SECONDS = 10
-- the two fountains the user liked (D-422): 7 = narrow column, 8 = wider fan
local FOUNTAIN_STYLES = {
	column = { spread = 6, speed = 26 },
	fan = { spread = 14, speed = 22 },
}
local COLD_SPARK_STYLE = "fan" -- (user 2026-10-27: 8 first)
local COLD_SPARK_COOLDOWN = 120 -- (no longer a wait for buyers: only the DJ's free one, 2026-10-27)
local SPARKLER_MAX = 5 -- sparklers burning in one bottle / bucket at once (user 2026-10-27)
local HAND_SPARKLER_SECONDS = 60
local DJ_SPARK_COOLDOWN = 90 -- the DJ fires the stage fireworks for free (user 2026-10-27)
local BURST_SOUND = "rbxassetid://75191072171555" -- "fireworks explosion sfx" (Creator Store)
local CRACKLE_SOUND = "rbxassetid://85890781320627" -- "feu d'artifice crépitation" (Creator Store)
local FUSE_SOUND = "rbxassetid://71438605239854" -- "FireworkFuseNEW" (Creator Store): a hand sparkler fizzing
local BUCKET_CUPS = 18
local BUCKET_LIFETIME = 600
local BUCKET_DRINKS = { "zzang_pop", "golden_apple", "monte" }
local MESSAGE_MAX = 30
-- Supporter products → Robux amount (also the banner text)
local SUPPORT = { Support_10 = 10, Support_50 = 50, Support_100 = 100, Support_500 = 500, Support_1000 = 1000, Support_5000 = 5000 }

local notify: RemoteEvent? = nil
local pendingTable: {[number]: BasePart} = {}
local pendingMessage: {[number]: string} = {}
local coldQueue: {{ player: Player, message: string, byDj: boolean? }} = {}
local coldRunning = false

local function toast(player: Player, message: string)
	if notify then notify:FireClient(player, "Toast", message) end
end

local function banner(kind: string, player: Player, message: string, amount: number?)
	if notify then
		notify:FireAllClients("Banner", {
			kind = kind,
			name = player.DisplayName,
			user = player.Name,
			message = message,
			amount = amount,
		})
	end
end

-- Filtered for everyone in the server; "" when the filter cannot run.
local function filterForAll(player: Player, text: string): string
	text = string.sub(text, 1, MESSAGE_MAX * 4)
	if utf8.len(text) and (utf8.len(text) :: number) > MESSAGE_MAX then
		text = string.sub(text, 1, (utf8.offset(text, MESSAGE_MAX + 1) :: number) - 1)
	end
	if text == "" then return "" end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and typeof(result) == "string" then result else ""
end

--------------------------------------------------
-- Effects
--------------------------------------------------

local function sparks(parent: Instance, offset: Vector3, big: boolean): Attachment
	local at = Instance.new("Attachment")
	at.Name = "Sparkler"
	at.Position = offset
	at.Parent = parent
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.LightEmission = 1
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 244, 210), Color3.fromRGB(255, 190, 90))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if big then 0.5 else 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0, 0.3)
	emitter.EmissionDirection = Enum.NormalId.Top
	if big then
		-- cold spark fountain (user photo of stage machines, 2026-10-27, D-422):
		-- streaks stretched along their flight, white-hot to gold, and glitter
		-- drifting back down round the column
		local style = FOUNTAIN_STYLES[COLD_SPARK_STYLE]
		emitter.Name = "Core"
		emitter.Rate = 700
		emitter.Lifetime = NumberRange.new(0.9, 1.4)
		emitter.Speed = NumberRange.new(style.speed * 0.8, style.speed)
		emitter.SpreadAngle = Vector2.new(style.spread, style.spread)
		emitter.Acceleration = Vector3.new(0, -14, 0)
		emitter.Drag = 0.6
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Squash = NumberSequence.new(-1.6)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.6, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.2), NumberSequenceKeypoint.new(1, 1) })
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 240)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 130)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 60)),
		})
		emitter.Brightness = 8
		local glitter = emitter:Clone()
		glitter.Name = "Glitter"
		glitter.Rate = 250
		glitter.Speed = NumberRange.new(style.speed * 0.5, style.speed * 0.75)
		glitter.SpreadAngle = Vector2.new(style.spread + 10, style.spread + 10)
		glitter.Lifetime = NumberRange.new(1.6, 2.4)
		glitter.Drag = 2
		glitter.Acceleration = Vector3.new(0, -6, 0)
		glitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
		glitter.Parent = at
		emitter.Parent = at
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 140)
		light.Range = 18
		light.Brightness = 3
		light.Parent = at
		return at
	else
		-- bottle sparkler (user photo 2026-10-25): a dense white fountain
		-- shooting up about a bottle's height, sparks raining back down
		emitter.Rate = 240
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(6, 11)
		emitter.SpreadAngle = Vector2.new(18, 18)
		emitter.Acceleration = Vector3.new(0, -12, 0)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.24),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
	emitter.Brightness = 3
	emitter.Parent = at
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Range = if big then 18 else 9
	light.Brightness = if big then 3 else 2
	light.Parent = at
	return at
end

-- Top of a part in world space (tables and buckets are turned cylinders).
local function topOf(part: BasePart): number
	local c, s = part.CFrame, part.Size
	return part.Position.Y + math.abs(c.RightVector.Y) * s.X / 2 + math.abs(c.UpVector.Y) * s.Y / 2 + math.abs(c.LookVector.Y) * s.Z / 2
end

-- A thin upright stick standing at `base` (world), sparks on its tip.
local function burn(parent: BasePart, base: Vector3, seconds: number)
	local s = Instance.new("Part")
	s.Name = "SparklerStick"
	s.Size = Vector3.new(0.04, 1.1, 0.04) -- (thinner, user 2026-10-28 (3))
	s.Color = Color3.fromRGB(200, 200, 205)
	s.Material = Enum.Material.Metal
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.CFrame = CFrame.new(base + Vector3.new(0, 0.55, 0))
	s.Parent = parent
	-- the white-hot tip the sparks come out of
	local tip = Instance.new("Part")
	tip.Name = "SparklerTip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.22, 0.22, 0.22)
	tip.Color = Color3.fromRGB(255, 245, 220)
	tip.Material = Enum.Material.Neon
	tip.Anchored = true
	tip.CanCollide = false
	tip.CanQuery = false
	tip.CanTouch = false
	tip.CFrame = s.CFrame * CFrame.new(0, 0.55, 0)
	tip.Parent = s
	local at = sparks(s, Vector3.new(0, 0.55, 0), false)
	task.delay(seconds, function()
		local emitter = at:FindFirstChildOfClass("ParticleEmitter")
		if emitter then emitter.Enabled = false end
		Debris:AddItem(s, 1)
	end)
end

--------------------------------------------------
-- Table items
--------------------------------------------------

local function tableFor(player: Player): BasePart?
	local t = pendingTable[player.UserId]
	if t and t.Parent and t:IsDescendantOf(workspace) then return t end
	-- fallback: the drink table nearest to the player
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	local best, bestDistance = nil, 30
	for _, candidate in ipairs(CollectionService:GetTagged("DrinkTable")) do
		if candidate:IsA("BasePart") and candidate:IsDescendantOf(workspace) then
			local d = (candidate.Position - root.Position).Magnitude
			if d < bestDistance then best, bestDistance = candidate, d end
		end
	end
	return best
end

local function ownBottle(player: Player, tablePart: BasePart): BasePart?
	for _, child in ipairs(tablePart:GetChildren()) do
		if child.Name == "PlacedBottle" and child:IsA("BasePart") and child:GetAttribute("Owner") == player.UserId then
			return child
		end
	end
	return nil
end

-- Sparklers and sparkler bucket sets are items now (user 2026-10-26): bought
-- from the item seller next to the bartender, held, then a tap on a bottle /
-- bucket (sparkler) or on a table (bucket set) uses them.
local function giveItem(player: Player, attribute: string, name: string, tip: string, color: Color3, count: number?): (boolean, string?)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, "잠시 후 다시 시도하세요." end
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool:SetAttribute(attribute, true)
	if count then tool:SetAttribute("Count", count) end
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = if attribute == "Sparkler" then Vector3.new(0.05, 1.4, 0.05) else Vector3.new(1, 1, 1)
	handle.Color = color
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	return true, nil
end

local function grantSparkler(player: Player): (boolean, string?)
	local ok, message = giveItem(player, "Sparkler", "🎇 스파클러", "들고 테이블 위 병(버킷)을 누르면 불꽃 30초", Color3.fromRGB(200, 200, 205))
	if ok then toast(player, "🎇 스파클러를 받았어요! 들고 테이블 위 병을 눌러 보세요.") end
	return ok, message
end

-- five sparklers in one item (user 2026-10-27): up to five burn in one bucket
local function grantSparkler5(player: Player): (boolean, string?)
	local ok, message = giveItem(player, "Sparkler", "🎇 스파클러 ×5", "들고 테이블 위 병(버킷)을 누를 때마다 하나씩, 한 버킷에 5개까지", Color3.fromRGB(200, 200, 205), 5)
	if ok then toast(player, "🎇 스파클러 5개를 받았어요! 들고 버킷을 누를 때마다 하나씩 꽂혀요.") end
	return ok, message
end

local function grantBucketItem(player: Player): (boolean, string?)
	local ok, message = giveItem(player, "SparklerSet", "🍾 스파클러 버킷", "들고 빈 테이블을 누르면 버킷 + 캔 3개 + 불꽃 3개", Color3.fromRGB(200, 200, 208))
	if ok then toast(player, "🍾 스파클러 버킷을 받았어요! 들고 테이블을 눌러 올려놓으세요.") end
	return ok, message
end

local function grantBucket(player: Player, tablePart: BasePart): (boolean, string?)
	local top = topOf(tablePart)
	local bucket = Instance.new("Part")
	bucket.Name = "SparklerBucket"
	bucket.Shape = Enum.PartType.Cylinder
	bucket.Size = Vector3.new(1.2, 1.3, 1.3) -- (narrow foot; wider rings above: user 2026-10-28 (3))
	bucket.CFrame = CFrame.new(tablePart.Position.X, top + 0.6, tablePart.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	bucket.Color = Color3.fromRGB(200, 200, 208)
	bucket.Material = Enum.Material.Metal
	bucket.Reflectance = 0.25
	bucket.Anchored = true
	bucket.CanCollide = false
	bucket:SetAttribute("Owner", player.UserId)
	bucket:SetAttribute("Servings", BUCKET_CUPS)
	local ice = Instance.new("Part")
	ice.Name = "Ice"
	ice.Shape = Enum.PartType.Cylinder
	ice.Size = Vector3.new(0.1, 1.45, 1.45)
	ice.CFrame = bucket.CFrame * CFrame.new(0.4, 0, 0) -- (below the rim)
	ice.Color = Color3.fromRGB(225, 240, 250)
	ice.Material = Enum.Material.Glass
	ice.Transparency = 0.2
	ice.Anchored = true
	ice.CanCollide = false
	ice.Parent = bucket
	-- the bucket opens up: wider rings toward the top (a stepped taper)
	for i, ring in ipairs({ { -0.2, 0.1, 1.42 }, { 0.1, 0.35, 1.54 }, { 0.35, 0.6, 1.66 } }) do
		local flare = Instance.new("Part")
		flare.Name = "BucketFlare" .. i
		flare.Shape = Enum.PartType.Cylinder
		flare.Size = Vector3.new(ring[2] - ring[1], ring[3], ring[3])
		flare.CFrame = bucket.CFrame * CFrame.new((ring[1] + ring[2]) / 2, 0, 0)
		flare.Color = bucket.Color
		flare.Material = bucket.Material
		flare.Reflectance = bucket.Reflectance
		flare.Anchored = true
		flare.CanCollide = false
		flare.CanQuery = false
		flare.Parent = bucket
	end
	local canColors = { Color3.fromRGB(255, 90, 170), Color3.fromRGB(232, 172, 48), Color3.fromRGB(40, 125, 65) }
	for i, color in ipairs(canColors) do
		local angle = (i - 1) * math.pi * 2 / 3
		local can = Instance.new("Part")
		can.Name = "Can"
		can.Shape = Enum.PartType.Cylinder
		can.Size = Vector3.new(1.05, 0.3, 0.3)
		-- the bottles lean out of the ice, away from the middle
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-out.Z, 0, out.X)
		can.CFrame = CFrame.new(bucket.Position + out * 0.42 + Vector3.new(0, 0.62, 0))
			* CFrame.fromAxisAngle(tangent, math.rad(-28)) * CFrame.Angles(0, 0, math.rad(90))
		can.Color = color
		can.Material = Enum.Material.Metal
		can.Anchored = true
		can.CanCollide = false
		can.Parent = bucket
	end
	-- cans left, small (a tap on the bucket gives one: tapBucket)
	local info = Instance.new("BillboardGui")
	info.Name = "Info"
	info.Size = UDim2.fromOffset(46, 20)
	info.StudsOffset = Vector3.new(0, 1.6, 0)
	info.MaxDistance = 30
	info.LightInfluence = 0
	info.Parent = bucket
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%d/%d", BUCKET_CUPS, BUCKET_CUPS)
	label.Parent = info
	bucket.Parent = tablePart
	-- 3 sparklers in the bucket, one after another
	task.spawn(function()
		for i = 1, 3 do
			if not bucket.Parent then return end
			local angle = (i - 1) * math.pi * 2 / 3 + 0.5
			burn(bucket, Vector3.new(bucket.Position.X + math.cos(angle) * 0.35, topOf(bucket), bucket.Position.Z + math.sin(angle) * 0.35), SPARKLER_SECONDS)
			task.wait(SPARKLER_SECONDS)
		end
	end)
	task.delay(BUCKET_LIFETIME, function()
		if bucket.Parent then bucket:Destroy() end
	end)
	toast(player, "🍾 스파클러 버킷이 나왔어요! 버킷을 누르면 누구나 캔을 마실 수 있어요.")
	return true, nil
end

local function tapBucket(player: Player, bucket: BasePart): (boolean, string?)
	local key = BUCKET_DRINKS[math.random(1, #BUCKET_DRINKS)]
	local ok, message = DrinkService.GiveCup(player, key)
	if not ok then return false, message end
	local left = (bucket:GetAttribute("Servings") or 1) - 1
	bucket:SetAttribute("Servings", left)
	local label = bucket:FindFirstChild("Info") and (bucket :: any).Info:FindFirstChild("Text")
	if label then label.Text = string.format("%d/%d", left, BUCKET_CUPS) end
	if left <= 0 then bucket:Destroy() end
	return true, nil
end

local function holding(player: Player, attribute: string): Tool?
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return if tool and tool:GetAttribute(attribute) then tool else nil
end

-- A tap on a table or on what stands on it. Returns handled = false when
-- DrinkService should take it (bottles, buckets without a sparkler in hand).
local function tap(player: Player, target: any): (boolean, string?, boolean)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(workspace) then return false, nil, false end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false, nil, true end
	local placed = if target.Name == "PlacedBottle" or target.Name == "SparklerBucket" then target
		else (target:FindFirstAncestor("PlacedBottle") or target:FindFirstAncestor("SparklerBucket"))
	local sparkler = holding(player, "Sparkler")
	if sparkler then
		if not placed or not placed:IsA("BasePart") then
			return false, "테이블 위 병이나 버킷을 눌러 주세요.", true
		end
		if (placed.Position - root.Position).Magnitude > 12 then return false, "조금 더 가까이 가 주세요.", true end
		local burning = 0
		for _, d in ipairs(placed:GetChildren()) do if d.Name == "SparklerStick" then burning += 1 end end
		if burning >= SPARKLER_MAX then return false, string.format("한 버킷에 %d개까지 꽂을 수 있어요.", SPARKLER_MAX), true end
		local left = ((sparkler:GetAttribute("Count") :: number?) or 1) - 1
		if left <= 0 then sparkler:Destroy() else
			sparkler:SetAttribute("Count", left)
			sparkler.Name = string.format("🎇 스파클러 ×%d", left)
		end
		-- the first in the middle, the next ones in a ring round the rim
		local look = placed:FindFirstChildWhichIsA("Model")
		local size = if look then look:GetExtentsSize() else placed.Size
		local r = math.min(size.X, size.Z) * 0.28
		local angle = burning * math.pi * 2 / 4
		local offset = if burning == 0 then Vector3.zero else Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local topY = if look then look:GetBoundingBox().Position.Y - size.Y / 2 + math.min(size.Y, 1.1) else topOf(placed)
		burn(placed, Vector3.new(placed.Position.X, topY, placed.Position.Z) + offset, SPARKLER_SECONDS)
		return true, string.format("🎇 불꽃이 켜졌어요! (30초 · 이 버킷 %d/%d)", burning + 1, SPARKLER_MAX), true
	end
	local set = holding(player, "SparklerSet")
	if set then
		local tablePart = if CollectionService:HasTag(target, "DrinkTable") then target else (placed and placed.Parent)
		if not tablePart or not tablePart:IsA("BasePart") or not CollectionService:HasTag(tablePart, "DrinkTable") then
			return false, "테이블을 눌러 주세요.", true
		end
		if (tablePart.Position - root.Position).Magnitude > math.max(tablePart.Size.X, tablePart.Size.Z) / 2 + 14 then
			return false, "테이블 가까이 가서 눌러 주세요.", true
		end
		if DrinkService.HasBucket(tablePart) then return false, "버킷이 놓인 테이블에는 더 올릴 수 없어요.", true end
		set:Destroy()
		return grantBucket(player, tablePart), nil, true
	end
	if placed and placed.Name == "SparklerBucket" and placed:IsA("BasePart") then
		if (placed.Position - root.Position).Magnitude > 12 then return false, "조금 더 가까이 가 주세요.", true end
		local ok, message = tapBucket(player, placed)
		return ok, message, true
	end
	return false, nil, false
end

--------------------------------------------------
-- Stage cold spark
--------------------------------------------------

local function fountainPoints(): {Vector3}
	local edge: Instance? = nil
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "DJ_StageEdge" and d:IsA("BasePart") then edge = d break end
	end
	if not edge or not edge:IsA("BasePart") then return {} end
	-- along the longest horizontal side of the stage edge strip
	local axis = if edge.Size.X > edge.Size.Z then edge.CFrame.RightVector * edge.Size.X else edge.CFrame.LookVector * edge.Size.Z
	local points = {}
	for k = 0, 4 do
		table.insert(points, edge.Position + axis * ((k / 4 - 0.5) * 0.9) + Vector3.new(0, 0.3, 0))
	end
	return points
end

-- a sound at a point, gone after it played
local function soundAt(parent: Instance, id: string, volume: number, range: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.RollOffMinDistance = 20
	s.RollOffMaxDistance = range
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 6)
end

-- One aerial shell (user 2026-10-27: the stage show was thin): a glowing
-- trail rises from the stage front and bursts into a ball of coloured stars
-- with a bang, then a crackle.
local SHELL_COLORS = {
	{ Color3.fromRGB(255, 70, 120), Color3.fromRGB(255, 200, 230) },
	{ Color3.fromRGB(80, 200, 255), Color3.fromRGB(220, 250, 255) },
	{ Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 250, 210) },
	{ Color3.fromRGB(170, 90, 255), Color3.fromRGB(240, 210, 255) },
	{ Color3.fromRGB(90, 255, 150), Color3.fromRGB(220, 255, 230) },
}
local function shell(holder: Instance, from: Vector3, height: number, colors: {Color3})
	local p = Instance.new("Part")
	p.Name = "Shell"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.5, 0.5, 0.5)
	p.Material = Enum.Material.Neon
	p.Color = colors[2]
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = CFrame.new(from)
	p.Parent = holder
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = SPARKLE_TEXTURE
	trail.Rate = 120
	trail.Lifetime = NumberRange.new(0.3, 0.5)
	trail.Speed = NumberRange.new(0.5, 1.5)
	trail.Size = NumberSequence.new(0.35, 0)
	trail.LightEmission = 1
	trail.Brightness = 3
	trail.Color = ColorSequence.new(colors[2])
	trail.Parent = p
	local rise = 0.7
	game:GetService("TweenService"):Create(p, TweenInfo.new(rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(from + Vector3.new(0, height, 0)) }):Play()
	task.delay(rise, function()
		if not p.Parent then return end
		trail.Enabled = false
		p.Transparency = 1
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = SPARKLE_TEXTURE
		burst.Rate = 0
		burst.Lifetime = NumberRange.new(1.2, 1.8)
		burst.Speed = NumberRange.new(16, 24)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Acceleration = Vector3.new(0, -9, 0)
		burst.Drag = 1.5
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		burst.Transparency = NumberSequence.new(0, 0.4)
		burst.LightEmission = 1
		burst.Brightness = 4
		burst.Color = ColorSequence.new(colors[1], colors[2])
		burst.Parent = p
		burst:Emit(160)
		local flash = Instance.new("PointLight")
		flash.Color = colors[1]
		flash.Range = 40
		flash.Brightness = 6
		flash.Parent = p
		soundAt(p, BURST_SOUND, 0.8, 220)
		task.delay(0.35, function() if p.Parent then soundAt(p, CRACKLE_SOUND, 0.5, 160) end end)
		task.delay(0.4, function() flash.Enabled = false end)
		Debris:AddItem(p, 2.5)
	end)
end

local function runColdSpark(player: Player, message: string, byDj: boolean?)
	coldRunning = true
	banner(if byDj then "djspark" else "coldspark", player, message, nil)
	local holder = Instance.new("Folder")
	holder.Name = "ColdSpark"
	holder.Parent = workspace
	local points = fountainPoints()
	for _, point in ipairs(points) do
		local base = Instance.new("Part")
		base.Name = "ColdSparkBase"
		base.Size = Vector3.new(0.6, 0.3, 0.6)
		base.CFrame = CFrame.new(point)
		base.Color = Color3.fromRGB(20, 20, 24)
		base.Anchored = true
		base.CanCollide = false
		base.CanQuery = false
		base.Parent = holder
		sparks(base, Vector3.new(0, 0.2, 0), true)
	end
	-- the fountains' hiss and a shell from a random spot every 0.7 s
	if points[1] then soundAt(holder:FindFirstChildWhichIsA("BasePart") :: BasePart, CRACKLE_SOUND, 0.6, 160) end
	task.spawn(function()
		local t0 = os.clock()
		local k = 0
		while os.clock() - t0 < COLD_SPARK_SECONDS - 1 and holder.Parent and #points > 0 do
			k += 1
			local from = points[math.random(1, #points)] + Vector3.new(math.random(-20, 20) / 10, 0, math.random(-20, 20) / 10)
			shell(holder, from, math.random(26, 38), SHELL_COLORS[(k - 1) % #SHELL_COLORS + 1])
			task.wait(0.7)
		end
	end)
	-- the finale: five shells at once
	task.delay(COLD_SPARK_SECONDS - 1, function()
		for i, point in ipairs(points) do shell(holder, point, 40, SHELL_COLORS[i % #SHELL_COLORS + 1]) end
	end)
	local endsAt = workspace:GetServerTimeNow() + COLD_SPARK_SECONDS + 1
	FashionGame:SetAttribute("ColdSparkReadyAt", endsAt)
	task.delay(COLD_SPARK_SECONDS, function()
		for _, emitter in ipairs(holder:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") and emitter.Name ~= "" and emitter.Parent and emitter.Parent.Name == "Sparkler" then emitter.Enabled = false end
		end
		Debris:AddItem(holder, 4)
	end)
	-- (user 2026-10-27) no 2-minute wait any more: the next one in line goes
	-- off as soon as this show is over
	task.delay(COLD_SPARK_SECONDS + 1, function()
		coldRunning = false
		local nextOne = table.remove(coldQueue, 1)
		if nextOne and nextOne.player.Parent then
			runColdSpark(nextOne.player, nextOne.message, nextOne.byDj)
		end
	end)
end

-- seconds until a show bought now would start
local function waitFor(position: number): number
	local endsAt = (FashionGame:GetAttribute("ColdSparkReadyAt") :: number?) or 0
	local left = math.max(0, endsAt - workspace:GetServerTimeNow())
	return math.ceil(left + (position - 1) * (COLD_SPARK_SECONDS + 1))
end

local function startOrQueue(player: Player, message: string, byDj: boolean?)
	if coldRunning then
		table.insert(coldQueue, { player = player, message = message, byDj = byDj })
		-- a big white countdown on the buyer's screen (ClubShopController)
		if notify then notify:FireClient(player, "ColdSparkWait", workspace:GetServerTimeNow() + waitFor(#coldQueue)) end
	else
		runColdSpark(player, message, byDj)
	end
end

local function grantColdSpark(player: Player): (boolean, string?)
	local message = pendingMessage[player.UserId] or ""
	pendingMessage[player.UserId] = nil
	startOrQueue(player, message, false)
	return true, nil
end

-- the DJ's free shot (user 2026-10-27): only while DJing, once every DJ_SPARK_COOLDOWN
local djSparkAt: {[number]: number} = {}
local function djColdSpark(player: Player): (boolean, string?)
	local character = player.Character
	if not character or not character:GetAttribute("Djing") then return false, "DJ 중일 때만 쏠 수 있어요." end
	local last = djSparkAt[player.UserId] or -math.huge
	local left = math.ceil(last + DJ_SPARK_COOLDOWN - os.clock())
	if left > 0 then return false, string.format("🎆 %d초 뒤에 다시 쏠 수 있어요.", left) end
	djSparkAt[player.UserId] = os.clock()
	startOrQueue(player, "", true)
	return true, nil
end

--------------------------------------------------
-- Hand sparkler (one use) and glowstick (pass)
--------------------------------------------------

-- (user 2026-10-27) a sparkler held in the hand, to dance with. It comes
-- unlit; holding it shows a "🔥 불 붙이기" button (HandSparklerController),
-- which lights it ("LightHandSparkler"). It burns down over
-- HAND_SPARKLER_SECONDS: the stick gets shorter and the sparks go down with
-- its tip, and when the time is up nothing is left in the hand.
local STICK = 1.6 -- burning length at the start
local GRIP = 0.4 -- the bare wire held in the hand (Handle)
local function lightHandSparkler(player: Player): (boolean, string?)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or not tool:GetAttribute("HandSparkler") then return false, "손 스파클러를 손에 들어 주세요." end
	if tool:GetAttribute("Lit") then return false, nil end
	tool:SetAttribute("Lit", true)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local stick = tool:FindFirstChild("Stick") :: BasePart?
	local stickWeld = stick and stick:FindFirstChild("Weld") :: Weld?
	if not handle or not stick or not stickWeld then return false, nil end
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.22, 0.22, 0.22)
	tip.Color = Color3.fromRGB(255, 245, 220)
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.CanQuery = false
	tip.Massless = true
	local tipWeld = Instance.new("Weld")
	tipWeld.Part0 = handle
	tipWeld.Part1 = tip
	tipWeld.C0 = CFrame.new(0, GRIP / 2 + STICK, 0)
	tipWeld.Parent = tip
	tip.Parent = tool
	local at = sparks(tip, Vector3.zero, false)
	local emitter = at:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Rate = 160
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Speed = NumberRange.new(3, 6)
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
	end
	local fizz = Instance.new("Sound")
	fizz.SoundId = FUSE_SOUND
	fizz.Looped = true
	fizz.Volume = 0.35
	fizz.RollOffMaxDistance = 30
	fizz.Parent = handle
	fizz:Play()
	-- burn down: the stick shortens from the top, the tip follows it
	task.spawn(function()
		local t0 = os.clock()
		while tool.Parent do
			local k = math.clamp((os.clock() - t0) / HAND_SPARKLER_SECONDS, 0, 1)
			local length = math.max(0.02, STICK * (1 - k))
			stick.Size = Vector3.new(stick.Size.X, length, stick.Size.Z)
			stickWeld.C0 = CFrame.new(0, GRIP / 2 + length / 2, 0)
			tipWeld.C0 = CFrame.new(0, GRIP / 2 + length, 0)
			if k >= 1 then break end
			task.wait(0.2)
		end
		if tool.Parent then tool:Destroy() end
	end)
	return true, string.format("✨ 불이 붙었어요! %d초 동안 타요.", HAND_SPARKLER_SECONDS)
end

local function grantHandSparkler(player: Player): (boolean, string?)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, "잠시 후 다시 시도하세요." end
	local tool = Instance.new("Tool")
	tool.Name = "✨ 손 스파클러"
	tool.ToolTip = "손에 들고 [불 붙이기]를 누르세요"
	tool.CanBeDropped = false
	tool:SetAttribute("HandSparkler", true)
	tool.Grip = CFrame.new(0, -GRIP / 2, 0) * CFrame.Angles(math.rad(-30), 0, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.08, GRIP, 0.08)
	handle.Color = Color3.fromRGB(70, 70, 74)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	-- the coated part that burns (grey), on top of the wire
	local stick = Instance.new("Part")
	stick.Name = "Stick"
	stick.Size = Vector3.new(0.05, STICK, 0.05)
	stick.Color = Color3.fromRGB(120, 116, 110)
	stick.Material = Enum.Material.Concrete
	stick.CanCollide = false
	stick.CanQuery = false
	stick.Massless = true
	local weld = Instance.new("Weld")
	weld.Name = "Weld"
	weld.Part0 = handle
	weld.Part1 = stick
	weld.C0 = CFrame.new(0, GRIP / 2 + STICK / 2, 0)
	weld.Parent = stick
	stick.Parent = tool
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	toast(player, "✨ 손 스파클러를 받았어요! 손에 들고 [불 붙이기]를 누르세요.")
	return true, nil
end
-- the glowstick (Game Pass, permanent): always in the backpack, a tap changes its colour
local GLOW_COLORS = { Color3.fromRGB(0, 255, 140), Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 180, 255), Color3.fromRGB(255, 230, 60), Color3.fromRGB(255, 120, 40) }
local function giveGlowstick(player: Player)
	if player:GetAttribute("Pass_Glowstick") ~= true then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	for _, where in ipairs({ backpack, player.Character }) do
		if where and where:FindFirstChild("🪄 야광봉") then return end
	end
	local tool = Instance.new("Tool")
	tool.Name = "🪄 야광봉"
	tool.ToolTip = "누르면 색이 바뀌어요"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(-25), 0, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(1.8, 0.22, 0.22)
	handle.Material = Enum.Material.Neon
	handle.Color = GLOW_COLORS[1]
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	-- (a Cylinder's axis is X: turned so it stands upright in the hand, held
	-- near its lower end; measured in Play 2026-10-27, the old grip held it level)
	tool.Grip = CFrame.new(0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	-- the user's pick (2026-10-27, "Lightsaber RP Tool" by VentusWind78, scripts
	-- stripped, ServerStorage.ArtAssets.GlowstickSaber): a black grip with a
	-- glowing tube; its grip becomes the handle, the tube takes the colour
	local glowing: {BasePart} = { handle }
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local saber = art and art:FindFirstChild("GlowstickSaber")
	if saber and saber:IsA("Model") then
		local m = saber:Clone()
		local _, size = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * 2.2 / size.Y)
		local grip = m:FindFirstChild("Handle") :: BasePart?
		if grip then
			handle:Destroy()
			glowing = {}
			grip.CanCollide = false
			grip.Massless = true
			grip.Anchored = false
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p ~= grip then
					p.Anchored = false
					p.CanCollide = false
					p.Massless = true
					local w = Instance.new("WeldConstraint")
					w.Part0 = grip
					w.Part1 = p
					w.Parent = p
					if p.Color.G > 0.3 then -- the tube (the dark parts are the grip)
						p.Material = Enum.Material.Neon
						p.Color = GLOW_COLORS[1]
						p.Transparency = 0.15
						table.insert(glowing, p)
					end
					p.Parent = grip
				end
			end
			grip.Parent = tool
			m:Destroy()
			handle = grip
			tool.Grip = CFrame.new(0, -0.1, 0) -- (the grip stands upright, the tube above the hand)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = GLOW_COLORS[1]
	light.Range = 9
	light.Brightness = 1.5
	light.Parent = glowing[1] or handle
	local index = 1
	tool.Activated:Connect(function()
		index = index % #GLOW_COLORS + 1
		for _, p in ipairs(glowing) do p.Color = GLOW_COLORS[index] end
		light.Color = GLOW_COLORS[index]
	end)
	tool.Parent = backpack
end
--------------------------------------------------
-- Supporter gifts
--------------------------------------------------

local function grantSupport(player: Player, amount: number): (boolean, string?)
	local message = pendingMessage[player.UserId] or ""
	pendingMessage[player.UserId] = nil
	banner("support", player, message, amount)
	-- the live supporter screen on the tower over OH24 (D-294)
	require(script.Parent.RankingService).NoteSupport(player, amount, message)
	-- (totals for the supporter ranking: RankingService, via MonetizationService.OnPurchase)
	toast(player, "💝 후원 고마워요!")
	return true, nil
end

--------------------------------------------------

function SparkleService.Handle(player: Player, action: string, payload: any): (boolean, any, boolean)
	-- third value: true when this service handled the action
	if action == "SetMessage" then
		if typeof(payload) ~= "string" then return false, nil, true end
		pendingMessage[player.UserId] = filterForAll(player, payload)
		return true, pendingMessage[player.UserId], true
	elseif action == "SetTable" then
		local tablePart = payload
		if typeof(tablePart) ~= "Instance" or not tablePart:IsA("BasePart") or not CollectionService:HasTag(tablePart, "DrinkTable") then
			return false, "테이블을 찾을 수 없습니다.", true
		end
		pendingTable[player.UserId] = tablePart
		return true, nil, true
	elseif action == "Tap" then
		return tap(player, payload)
	elseif action == "LightHandSparkler" then
		local ok, message = lightHandSparkler(player)
		return ok, message, true
	elseif action == "DJColdSpark" then
		local ok, message = djColdSpark(player)
		return ok, message, true
	end
	return false, nil, false
end

function SparkleService.Start()
	notify = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubNotify") :: RemoteEvent
	MonetizationService.RegisterProduct("Sparkler1", grantSparkler)
	MonetizationService.RegisterProduct("Sparkler5", grantSparkler5)
	MonetizationService.RegisterProduct("HandSparkler", grantHandSparkler)
	MonetizationService.RegisterProduct("SparklerBucket", grantBucketItem)
	MonetizationService.RegisterProduct("SparklerBucket_VIP", grantBucketItem)
	MonetizationService.RegisterProduct("ColdSpark", grantColdSpark)
	MonetizationService.RegisterProduct("ColdSpark_VIP", grantColdSpark)
	for key, amount in pairs(SUPPORT) do
		assert(MonetizationConfig.Products[key], key)
		MonetizationService.RegisterProduct(key, function(player)
			return grantSupport(player, amount)
		end)
	end
	-- the glowstick pass: in the backpack on every spawn and right after buying
	local function watchGlow(player: Player)
		player.CharacterAdded:Connect(function() task.wait(1) giveGlowstick(player) end)
		player:GetAttributeChangedSignal("Pass_Glowstick"):Connect(function() giveGlowstick(player) end)
		if player.Character then task.defer(giveGlowstick, player) end
	end
	for _, p in ipairs(Players:GetPlayers()) do watchGlow(p) end
	Players.PlayerAdded:Connect(watchGlow)
	Players.PlayerRemoving:Connect(function(player)
		djSparkAt[player.UserId] = nil
		pendingTable[player.UserId] = nil
		pendingMessage[player.UserId] = nil
		for _, t in ipairs(CollectionService:GetTagged("DrinkTable")) do
			for _, child in ipairs(t:GetChildren()) do
				if child.Name == "SparklerBucket" and child:GetAttribute("Owner") == player.UserId then child:Destroy() end
			end
		end
	end)
end

return SparkleService

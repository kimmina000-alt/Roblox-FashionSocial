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
local COLD_SPARK_COOLDOWN = 120
local BUCKET_CUPS = 18
local BUCKET_LIFETIME = 600
local BUCKET_DRINKS = { "zzang_pop", "golden_apple", "monte" }
local MESSAGE_MAX = 30
-- Supporter products → Robux amount (also the banner text)
local SUPPORT = { Support_10 = 10, Support_50 = 50, Support_100 = 100, Support_500 = 500, Support_1000 = 1000, Support_5000 = 5000 }

local notify: RemoteEvent? = nil
local pendingTable: {[number]: BasePart} = {}
local pendingMessage: {[number]: string} = {}
local coldQueue: {{ player: Player, message: string }} = {}
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
		-- cold spark fountain: a tall column of sparks falling back down
		emitter.Rate = 360
		emitter.Lifetime = NumberRange.new(1.2, 1.7)
		emitter.Speed = NumberRange.new(28, 36)
		emitter.SpreadAngle = Vector2.new(8, 8)
		emitter.Acceleration = Vector3.new(0, -18, 0)
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
	s.Size = Vector3.new(0.08, 1.1, 0.08)
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

local function grantSparkler(player: Player): (boolean, string?)
	local tablePart = tableFor(player)
	if not tablePart then return false, "테이블 가까이에서 다시 시도해 주세요." end
	local bottle = ownBottle(player, tablePart)
	if bottle then
		burn(bottle, Vector3.new(bottle.Position.X, topOf(bottle), bottle.Position.Z), SPARKLER_SECONDS)
	else
		-- no bottle of theirs: the sparkler stands in the middle of the table
		burn(tablePart, Vector3.new(tablePart.Position.X, topOf(tablePart), tablePart.Position.Z), SPARKLER_SECONDS)
	end
	toast(player, "🎇 테이블 스파클러가 켜졌어요! (30초)")
	return true, nil
end

local function grantBucket(player: Player): (boolean, string?)
	local tablePart = tableFor(player)
	if not tablePart then return false, "테이블 가까이에서 다시 시도해 주세요." end
	local top = topOf(tablePart)
	local bucket = Instance.new("Part")
	bucket.Name = "SparklerBucket"
	bucket.Shape = Enum.PartType.Cylinder
	bucket.Size = Vector3.new(1.2, 1.5, 1.5)
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
	ice.Size = Vector3.new(0.1, 1.35, 1.35)
	ice.CFrame = bucket.CFrame * CFrame.new(0.58, 0, 0)
	ice.Color = Color3.fromRGB(225, 240, 250)
	ice.Material = Enum.Material.Glass
	ice.Transparency = 0.2
	ice.Anchored = true
	ice.CanCollide = false
	ice.Parent = bucket
	local canColors = { Color3.fromRGB(255, 90, 170), Color3.fromRGB(232, 172, 48), Color3.fromRGB(40, 125, 65) }
	for i, color in ipairs(canColors) do
		local angle = (i - 1) * math.pi * 2 / 3
		local can = Instance.new("Part")
		can.Name = "Can"
		can.Shape = Enum.PartType.Cylinder
		can.Size = Vector3.new(0.9, 0.36, 0.36)
		can.CFrame = CFrame.new(bucket.Position + Vector3.new(math.cos(angle) * 0.38, 0.55, math.sin(angle) * 0.38))
			* CFrame.Angles(0, 0, math.rad(80))
		can.Color = color
		can.Material = Enum.Material.Metal
		can.Anchored = true
		can.CanCollide = false
		can.Parent = bucket
	end
	local pour = Instance.new("ProximityPrompt")
	pour.Name = "PourPrompt"
	pour.ActionText = "캔 따서 마시기"
	pour.ObjectText = player.DisplayName .. "님의 스파클러 버킷"
	pour.MaxActivationDistance = 9
	pour.RequiresLineOfSight = false
	pour.Parent = bucket
	pour.Triggered:Connect(function(who)
		if not bucket.Parent then return end
		local key = BUCKET_DRINKS[math.random(1, #BUCKET_DRINKS)]
		local ok, message = DrinkService.GiveCup(who, key)
		if not ok then
			if message then toast(who, message) end
			return
		end
		local left = (bucket:GetAttribute("Servings") or 1) - 1
		bucket:SetAttribute("Servings", left)
		if left <= 0 then bucket:Destroy() end
	end)
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
	toast(player, "🍾 스파클러 버킷이 나왔어요! 모두 캔을 따서 마실 수 있어요.")
	return true, nil
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

local function runColdSpark(player: Player, message: string)
	coldRunning = true
	banner("coldspark", player, message, nil)
	local holder = Instance.new("Folder")
	holder.Name = "ColdSpark"
	holder.Parent = workspace
	for _, point in ipairs(fountainPoints()) do
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
	task.delay(COLD_SPARK_SECONDS, function()
		for _, emitter in ipairs(holder:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") then emitter.Enabled = false end
		end
		Debris:AddItem(holder, 2)
	end)
	FashionGame:SetAttribute("ColdSparkReadyAt", workspace:GetServerTimeNow() + COLD_SPARK_COOLDOWN)
	task.delay(COLD_SPARK_COOLDOWN, function()
		coldRunning = false
		local nextOne = table.remove(coldQueue, 1)
		if nextOne and nextOne.player.Parent then
			runColdSpark(nextOne.player, nextOne.message)
		end
	end)
end

local function grantColdSpark(player: Player): (boolean, string?)
	local message = pendingMessage[player.UserId] or ""
	pendingMessage[player.UserId] = nil
	if coldRunning then
		-- (bought during the wait: it goes off when the 2 minutes are over)
		table.insert(coldQueue, { player = player, message = message })
		toast(player, string.format("🎆 다른 콜드 스파크가 끝나면 바로 터져요 (대기 %d번째).", #coldQueue))
	else
		runColdSpark(player, message)
	end
	return true, nil
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
	end
	return false, nil, false
end

function SparkleService.Start()
	notify = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubNotify") :: RemoteEvent
	MonetizationService.RegisterProduct("Sparkler1", grantSparkler)
	MonetizationService.RegisterProduct("SparklerBucket", grantBucket)
	MonetizationService.RegisterProduct("SparklerBucket_VIP", grantBucket)
	MonetizationService.RegisterProduct("ColdSpark", grantColdSpark)
	MonetizationService.RegisterProduct("ColdSpark_VIP", grantColdSpark)
	for key, amount in pairs(SUPPORT) do
		assert(MonetizationConfig.Products[key], key)
		MonetizationService.RegisterProduct(key, function(player)
			return grantSupport(player, amount)
		end)
	end
	-- the 불꽃 prompt on every drink table
	local function addPrompt(tablePart: Instance)
		if not tablePart:IsA("BasePart") or tablePart:FindFirstChild("SparklePrompt") then return end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SparklePrompt"
		prompt.ActionText = "불꽃"
		prompt.ObjectText = "테이블"
		prompt.KeyboardKeyCode = Enum.KeyCode.G
		prompt.UIOffset = Vector2.new(0, -70)
		prompt.MaxActivationDistance = math.max(tablePart.Size.X, tablePart.Size.Z) / 2 + 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = tablePart
	end
	for _, t in ipairs(CollectionService:GetTagged("DrinkTable")) do addPrompt(t) end
	CollectionService:GetInstanceAddedSignal("DrinkTable"):Connect(addPrompt)
	Players.PlayerRemoving:Connect(function(player)
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

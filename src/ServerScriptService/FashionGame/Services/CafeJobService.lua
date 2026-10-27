--!strict
-- Cafe part-time job (알바, CAFE.md §9, D-099). Config: CafeJobConfig.
--
--   * Start / stop work at the counter (client prompt → remote CafeJob
--     "Start"/"Stop"). Staff show "알바생" over the head (character attribute CafeJob = shop).
--   * Orders: a player ordering a free drink at a cafe where someone works
--     becomes an order (SnackService order handler) instead of getting the cup
--     straight away; NPC customers also sit down at free seats and order.
--     Orders are published as JSON in FashionGame attribute "CafeOrders".
--   * "Make", id: the staff makes the drink at the counter (MakeSeconds) and
--     carries the cup (Tool with attribute CafeOrder = id; not drinkable).
--   * "Serve", id: next to the customer, the cup is handed over. Coins.
--   * Finished drinks leave an empty cup on the nearest table (while someone
--     works there); staff clear it with the cup's prompt (enabled on the
--     staff's client only). Coins.
-- Every step is checked here; coins go through EconomyService.Earn with a
-- daily cap. Staff cannot block or move other players (CAFE.md §9).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local Shared = FashionGame:WaitForChild("Shared")
local CafeJobConfig = require(Shared:WaitForChild("CafeJobConfig"))
local SnackConfig = require(Shared:WaitForChild("SnackConfig"))

local CafeJobService = {}

local economy: any = nil
local snack: any = nil

type Order = {
	id: number,
	shop: string,
	item: string,
	kind: string, -- "player" | "npc"
	userId: number, -- player customer (0 for NPCs)
	npc: Model?,
	seat: Seat?,
	created: number,
	maker: number, -- staff UserId making / carrying it (0 = nobody yet)
	ready: boolean,
	who: string?, -- NPC: the name it shows (a staff member's friend)
}

local orders: {[number]: Order} = {}
local nextId = 0
local staff: {[Player]: string} = {}
local lastOrderAt: {[number]: number} = {} -- player customer → time
local lastPaidPair: {[string]: number} = {} -- "staff:customer" → time
local lastNpcAt: {[string]: number} = {}

local function isJobShop(shopKey: string): boolean
	return table.find(CafeJobConfig.Shops, shopKey) ~= nil
end

local function toast(player: Player, message: string)
	local notify = Remotes:FindFirstChild("ClubNotify")
	if notify and notify:IsA("RemoteEvent") then notify:FireClient(player, "Toast", message) end
end

local function rootOf(model: Model?): BasePart?
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- the counter part of a cafe (tagged SnackShop, inside Workspace)
local function counterOf(shopKey: string): BasePart?
	for _, part in ipairs(CollectionService:GetTagged("SnackShop")) do
		if part:IsA("BasePart") and part:GetAttribute("Shop") == shopKey and part:IsDescendantOf(workspace) then
			return part
		end
	end
	return nil
end

local function distanceTo(player: Player, part: BasePart): number
	local root = rootOf(player.Character)
	return if root then (root.Position - part.Position).Magnitude else math.huge
end

local function cafeModel(shopKey: string): Instance?
	local counter = counterOf(shopKey)
	return counter and counter.Parent
end

-- where staff start work and make drinks: the back counter behind the bar
-- when the cafe has one (user, 2026-10-22), else the counter
local function stationOf(shopKey: string): BasePart?
	local model = cafeModel(shopKey)
	local back = model and model:FindFirstChild("BackCounter")
	if back and back:IsA("BasePart") then return back end
	return counterOf(shopKey)
end

-- distance from a point to the nearest point of a part's box
local function boxDistance(part: BasePart, point: Vector3): number
	local here = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local clamped = Vector3.new(math.clamp(here.X, -half.X, half.X), math.clamp(here.Y, -half.Y, half.Y), math.clamp(here.Z, -half.Z, half.Z))
	return (here - clamped).Magnitude
end

local function nearStation(player: Player, shopKey: string): boolean
	local station = stationOf(shopKey)
	local root = rootOf(player.Character)
	return station ~= nil and root ~= nil and boxDistance(station, root.Position) <= CafeJobConfig.CounterDistance
end

-- inside the cafe building (its bounding box) plus a margin around it
local areaCache: {[string]: { cf: CFrame, size: Vector3 }} = {}
local function inCafe(shopKey: string, point: Vector3, margin: number): boolean
	local box = areaCache[shopKey]
	local model = cafeModel(shopKey)
	if not box and model and model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		box = { cf = cf, size = size }
		areaCache[shopKey] = box
	end
	if not box then return false end
	local here = box.cf:PointToObjectSpace(point)
	local half = box.size / 2
	return math.abs(here.X) <= half.X + margin and math.abs(here.Z) <= half.Z + margin and math.abs(here.Y) <= half.Y + margin
end

local function playerInCafe(player: Player, shopKey: string, margin: number): boolean
	local root = rootOf(player.Character)
	return root ~= nil and inCafe(shopKey, root.Position, margin)
end

local function staffCount(shopKey: string): number
	local n = 0
	for _, shop in pairs(staff) do
		if shop == shopKey then n += 1 end
	end
	return n
end

local function itemOf(order: Order): SnackConfig.Item?
	local _, item = SnackConfig.find(order.shop, order.item)
	return item
end

local function folder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f :: Folder
end

local function publish()
	local list = {}
	for _, order in pairs(orders) do
		local item = itemOf(order)
		local who = order.who or "손님"
		if order.kind == "player" then
			local customer = Players:GetPlayerByUserId(order.userId)
			who = if customer then customer.DisplayName else "손님"
		end
		table.insert(list, {
			id = order.id, shop = order.shop, name = if item then item.name else order.item,
			kind = order.kind, user = order.userId, who = who,
			maker = order.maker, ready = order.ready, t = order.created,
		})
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	FashionGame:SetAttribute("CafeOrders", HttpService:JSONEncode(list))
end

-- speech bubble over a customer's head: what they ordered. Only the staff of
-- that cafe and the customer see it (user, 2026-10-22): it starts disabled
-- and CafeJobController turns it on.
local function setBubble(model: Model?, text: string?, shopKey: string?, customerId: number?)
	local head = model and model:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild("CafeOrderBubble")
	if old then old:Destroy() end
	if not text then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CafeOrderBubble"
	gui.Size = UDim2.fromOffset(170, 34)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Enabled = false
	gui:SetAttribute("Shop", shopKey or "")
	gui:SetAttribute("Customer", customerId or 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	label.BackgroundTransparency = 0.1
	label.TextColor3 = Color3.fromRGB(40, 30, 25)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = head
end

--------------------------------------------------
-- Cups on tables: empty cups left by customers, and drinks customers put
-- down (user, 2026-10-22). Staff of that cafe clear both.
--------------------------------------------------

-- tables and bar tops (window bar, mezzanine bar), not their legs or stools
local function isTable(part: Instance): boolean
	if not part:IsA("BasePart") then return false end
	local name = string.lower(part.Name)
	if string.find(name, "leg") or string.find(name, "stool") then return false end
	local surface = string.find(name, "table") ~= nil or string.sub(name, -3) == "bar"
	return surface and part.Size.Y <= 1.5 and math.min(part.Size.X, part.Size.Z) >= 1 and math.max(part.Size.X, part.Size.Z) >= 1.5
end
CafeJobService.IsTable = isTable

local function nearestTable(shopKey: string, near: Vector3): BasePart?
	local model = cafeModel(shopKey)
	if not model then return nil end
	local best, bestDistance = nil, 6
	for _, part in ipairs(model:GetDescendants()) do
		if isTable(part) and math.abs(part.Position.Y - near.Y) < 6 then
			local d = boxDistance(part, Vector3.new(near.X, part.Position.Y, near.Z))
			if d < bestDistance then best, bestDistance = part, d end
		end
	end
	return best
end

-- the spot on the table top nearest to a position (long bars: right in front
-- of the seat), a little jitter so cups do not overlap
local function spotOn(tablePart: BasePart, near: Vector3): Vector3
	local here = tablePart.CFrame:PointToObjectSpace(near)
	local half = tablePart.Size / 2
	local x = math.clamp(here.X + (math.random() - 0.5) * 0.8, -half.X + 0.4, half.X - 0.4)
	local z = math.clamp(here.Z + (math.random() - 0.5) * 0.8, -half.Z + 0.4, half.Z - 0.4)
	return tablePart.CFrame:PointToWorldSpace(Vector3.new(x, half.Y, z))
end

local function newCup(shopKey: string, at: Vector3, item: SnackConfig.Item?): Part
	local cup = Instance.new("Part")
	cup.Name = if item then "PlacedDrink" else "EmptyCup"
	cup.Shape = Enum.PartType.Cylinder
	cup.Size = Vector3.new(0.85, 0.6, 0.6)
	cup.CFrame = CFrame.new(at + Vector3.new(0, 0.43, 0)) * CFrame.Angles(0, 0, math.rad(90))
	cup.Color = Color3.fromRGB(245, 245, 250)
	cup.Material = Enum.Material.Glass
	cup.Transparency = 0.3
	cup.Anchored = true
	cup.CanCollide = false
	cup:SetAttribute("Shop", shopKey)
	cup:SetAttribute("Since", os.clock())
	if item then
		local fill = Instance.new("Part")
		fill.Name = "Fill"
		fill.Shape = Enum.PartType.Cylinder
		fill.Size = Vector3.new(0.65, 0.5, 0.5)
		fill.CFrame = cup.CFrame * CFrame.new(-0.05, 0, 0)
		fill.Color = item.color
		fill.Anchored = true
		fill.CanCollide = false
		fill.CanQuery = false
		fill.Parent = cup
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleanPrompt"
	prompt.ActionText = "테이블 정리"
	prompt.ObjectText = if item then item.name else "빈 컵"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- the staff's client turns it on
	prompt.Parent = cup
	prompt.Triggered:Connect(function(player)
		if not cup.Parent or staff[player] ~= shopKey then return end
		-- a drink with some left: only once its owner has left the cafe (user, 2026-10-22)
		if cup:GetAttribute("Owner") ~= nil and not cup:GetAttribute("Clearable") then return end
		cup:Destroy()
		economy.AddJobXP(player, CafeJobConfig.JobKey, "cleaned", CafeJobConfig.CleanXP)
		economy.Earn(player, CafeJobConfig.CleanCoins, "CafeJob", CafeJobConfig.DailyCap, "테이블 정리")
		player:SetAttribute("CafeJobEarned", economy.Earned(player, "CafeJob"))
	end)
	return cup
end

local function placeCup(shopKey: string, near: Vector3)
	if staffCount(shopKey) == 0 then return end
	local tablePart = nearestTable(shopKey, near)
	if not tablePart then return end
	newCup(shopKey, spotOn(tablePart, near), nil).Parent = folder("CafeCups")
end

-- the drink tool the player holds → onto a table of a job cafe
local function putDown(player: Player, tablePart: any): (boolean, string?)
	if typeof(tablePart) ~= "Instance" or not isTable(tablePart) then return false, "테이블에만 놓을 수 있어요." end
	local shopKey: string? = nil
	for _, key in ipairs(CafeJobConfig.Shops) do
		local model = cafeModel(key)
		if model and tablePart:IsDescendantOf(model) then shopKey = key end
	end
	local root = rootOf(player.Character)
	if not shopKey or not root or boxDistance(tablePart, root.Position) > 8 then return false, "테이블 가까이에서 놓아 주세요." end
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local key = tool and tool:GetAttribute("Snack")
	if not tool or typeof(key) ~= "string" or tool:GetAttribute("CafeOrder") then return false, "손에 든 음료가 없어요." end
	local item: SnackConfig.Item? = nil
	for _, shop in pairs(SnackConfig.Shops) do
		local _, found = SnackConfig.find(shop.key, key)
		if found then item = found end
	end
	if not item or item.kind ~= "cup" then return false, "음료만 놓을 수 있어요." end
	local bites = tool:GetAttribute("Bites")
	tool:Destroy()
	local cup = newCup(shopKey :: string, spotOn(tablePart :: BasePart, root.Position), item)
	cup:SetAttribute("Owner", player.UserId)
	cup:SetAttribute("Item", item.key)
	cup:SetAttribute("Bites", if typeof(bites) == "number" then bites else SnackConfig.Bites)
	-- the owner picks it up again (prompt turned on by the owner's client)
	local pick = Instance.new("ProximityPrompt")
	pick.Name = "PickPrompt"
	pick.ActionText = "다시 들기"
	pick.ObjectText = item.name
	pick.HoldDuration = 0
	pick.MaxActivationDistance = 9
	pick.RequiresLineOfSight = false
	pick.Enabled = false
	pick.Parent = cup
	pick.Triggered:Connect(function(who)
		if not cup.Parent or who.UserId ~= cup:GetAttribute("Owner") then return end
		cup:Destroy()
		local again = snack.Give(who, item)
		if again then again:SetAttribute("Bites", cup:GetAttribute("Bites")) end
	end)
	cup.Parent = folder("CafeCups")
	return true, nil
end

--------------------------------------------------
-- Orders
--------------------------------------------------

local function removeOrder(order: Order)
	orders[order.id] = nil
	-- the cup someone was carrying for it goes away
	for _, player in ipairs(Players:GetPlayers()) do
		for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
			if container then
				for _, tool in ipairs(container:GetChildren()) do
					if tool:IsA("Tool") and tool:GetAttribute("CafeOrder") == order.id then tool:Destroy() end
				end
			end
		end
	end
	if order.kind == "player" then
		local customer = Players:GetPlayerByUserId(order.userId)
		setBubble(customer and customer.Character, nil, nil, nil)
	end
	publish()
end

local function npcLeave(order: Order, served: boolean)
	local npc = order.npc
	local seat = order.seat
	removeOrder(order)
	if not npc then return end
	if served then
		-- the thank-you shows for a second only (user, 2026-10-22)
		setBubble(npc, "😋 맛있어요!", order.shop, 0)
		task.delay(1, function() setBubble(npc, nil, nil, nil) end)
		task.delay(CafeJobConfig.NpcStaySeconds, function()
			if seat then placeCup(order.shop, seat.Position) end
			if npc.Parent then npc:Destroy() end
		end)
	else
		npc:Destroy()
	end
end

-- a player customer gets the drink without staff (time out / nobody works)
local function selfServe(order: Order, message: string)
	local customer = Players:GetPlayerByUserId(order.userId)
	local item = itemOf(order)
	removeOrder(order)
	if customer and item then
		snack.Give(customer, item)
		toast(customer, message)
	end
end

local function playerOrder(player: Player, shop: SnackConfig.Shop, item: SnackConfig.Item): (boolean, string?)
	if staff[player] == shop.key then return true, "알바 중에는 주문할 수 없어요. 주문 목록의 음료를 만들어 주세요!" end
	if not isJobShop(shop.key) or staffCount(shop.key) == 0 or staff[player] then return false, nil end
	for _, order in pairs(orders) do
		if order.kind == "player" and order.userId == player.UserId then
			return true, "주문한 음료가 아직 만들어지는 중이에요. 조금만 기다려 주세요!"
		end
	end
	local last = lastOrderAt[player.UserId]
	if last and os.clock() - last < CafeJobConfig.PlayerOrderGap then return false, nil end
	lastOrderAt[player.UserId] = os.clock()
	nextId += 1
	orders[nextId] = {
		id = nextId, shop = shop.key, item = item.key, kind = "player", userId = player.UserId,
		npc = nil, seat = nil, created = os.clock(), maker = 0, ready = false,
	}
	setBubble(player.Character, "☕ " .. item.name, shop.key, player.UserId)
	publish()
	for other, shopKey in pairs(staff) do
		if shopKey == shop.key then toast(other, string.format("🔔 새 주문: %s · %s", item.name, player.DisplayName)) end
	end
	return true, string.format("%s 주문했어요! 알바생이 만들어서 가져다 줘요. 자리에 앉아 기다려 주세요.", item.name)
end

--------------------------------------------------
-- NPC customers
--------------------------------------------------

local SKIN = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(140, 95, 65) }
local CLOTHES = { Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 50), Color3.fromRGB(230, 120, 150), Color3.fromRGB(90, 140, 220), Color3.fromRGB(240, 200, 80), Color3.fromRGB(120, 180, 130) }

local function freeSeat(shopKey: string): Seat?
	local model = cafeModel(shopKey)
	if not model then return nil end
	local taken: {[Seat]: boolean} = {}
	for _, order in pairs(orders) do
		if order.seat then taken[order.seat] = true end
	end
	local free = {}
	for _, seat in ipairs(CollectionService:GetTagged("PromptSeat")) do
		if seat:IsA("Seat") and seat:IsDescendantOf(model) and not seat.Occupant and not taken[seat] then
			table.insert(free, seat)
		end
	end
	return if #free > 0 then free[math.random(1, #free)] else nil
end

-- Friends of the staff (user, 2026-10-22: NPC customers look like the
-- player's friends; the default NPC when there are none). Cached per staff.
local friendCache: {[number]: {{ id: number, name: string }}} = {}
local function friendsOf(userId: number): {{ id: number, name: string }}
	local cached = friendCache[userId]
	if cached then return cached end
	local list = {}
	friendCache[userId] = list
	if userId <= 0 then return list end -- Studio test players have no friends list
	local ok, pages = pcall(function() return Players:GetFriendsAsync(userId) end)
	if not ok or not pages then return list end
	while #list < 200 do
		for _, friend in ipairs(pages:GetCurrentPage()) do
			table.insert(list, { id = friend.Id, name = friend.DisplayName or friend.Username })
		end
		if pages.IsFinished then break end
		local okNext = pcall(function() pages:AdvanceToNextPageAsync() end)
		if not okNext then break end
	end
	return list
end

-- a friend of someone working at this cafe who is not in this server and not
-- already sitting here; nil → default NPC
local function pickFriend(shopKey: string): ({ id: number, name: string })?
	local candidates = {}
	local seated: {[number]: boolean} = {}
	for _, order in pairs(orders) do
		if order.npc then
			local id = order.npc:GetAttribute("FriendId")
			if typeof(id) == "number" then seated[id] = true end
		end
	end
	for member, key in pairs(staff) do
		if key == shopKey then
			for _, friend in ipairs(friendsOf(member.UserId)) do
				if not seated[friend.id] and not Players:GetPlayerByUserId(friend.id) then table.insert(candidates, friend) end
			end
		end
	end
	return if #candidates > 0 then candidates[math.random(1, #candidates)] else nil
end

local function defaultDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN[math.random(1, #SKIN)]
	local top = CLOTHES[math.random(1, #CLOTHES)]
	local bottom = CLOTHES[math.random(1, #CLOTHES)]
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = top
	description.LeftLegColor = bottom
	description.RightLegColor = bottom
	return description
end

local function spawnNpc(shopKey: string)
	local shop = SnackConfig.Shops[shopKey]
	local seat = freeSeat(shopKey)
	if not shop or not seat then return end
	local friend = pickFriend(shopKey)
	local description: HumanoidDescription? = nil
	if friend then
		local okFriend, friendLook = pcall(function() return Players:GetHumanoidDescriptionFromUserId(friend.id) end)
		if okFriend and friendLook then description = friendLook else friend = nil end
	end
	if not description then description = defaultDescription() end
	-- the seat may have been taken while loading the look
	if seat.Occupant or staffCount(shopKey) == 0 then return end
	local ok, npc = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description :: HumanoidDescription, Enum.HumanoidRigType.R15)
	end)
	if not ok or not npc then return end
	-- NPCs order the drinks the staff can make: free cups (the menu also has
	-- coin / Robux food since D-317)
	local drinks = {}
	for _, it in ipairs(shop.items) do
		if it.kind == "cup" and not it.coins and not it.product then table.insert(drinks, it) end
	end
	if #drinks == 0 then return end
	local item = drinks[math.random(1, #drinks)]
	nextId += 1
	npc.Name = "CafeNPC_" .. nextId
	if friend then npc:SetAttribute("FriendId", friend.id) end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = "손님"
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	npc:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
	npc.Parent = folder("CafeNPCs")
	local root = rootOf(npc)
	if root then pcall(function() root:SetNetworkOwner(nil) end) end
	if humanoid then
		seat:Sit(humanoid)
		-- server-side NPC: play the sitting pose here (no Animate script runs)
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://2506281703" -- R15 sit
			local ok2, track = pcall(function() return animator:LoadAnimation(animation) end)
			if ok2 and track then
				track.Looped = true
				track:Play()
			end
		end
	end
	orders[nextId] = {
		id = nextId, shop = shopKey, item = item.key, kind = "npc", userId = 0,
		npc = npc, seat = seat, created = os.clock(), maker = 0, ready = false,
		who = nil,
	}
	-- a friend's look only, no name (user, 2026-10-22)
	setBubble(npc, "☕ " .. item.name, shopKey, 0)
	publish()
end

--------------------------------------------------
-- Work
--------------------------------------------------

-- Job sounds (user 2026-10-27; docs/04_ART/SOUNDS.md): start / end of a
-- shift at the worker, the drink being made at the station, the NPC
-- customer's "감사합니다" when served (not for player customers)
local SOUNDS = {
	-- (user 2026-10-27, 2nd: like a computer switching on / off)
	start = { "rbxassetid://79812542038049", 0.6 }, -- "Windows 10 Startup Sound" (Creator Store)
	stop = { "rbxassetid://6858975342", 0.6 }, -- "Microsoft Windows XP Shutdown Sound" (Creator Store)
	make = { "rbxassetid://9113846434", 0.7 }, -- "Coffee Pot 2" (Pro Sound Effects)
	thanks = { "rbxassetid://132794698600617", 0.9 }, -- "감사합니다 new" (Creator Store)
}
local function playAt(parent: Instance?, key: string)
	if not parent then return end
	local def = SOUNDS[key]
	local s = Instance.new("Sound")
	s.Name = "CafeJob_" .. key
	s.SoundId = def[1]
	s.Volume = def[2]
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 40
	s.Parent = parent
	s:Play()
	task.delay(8, function() s:Destroy() end)
end

-- "알바생" over the head while working (user 2026-10-27: no apron any more)
local function setStaffTag(character: Model?, shopKey: string?)
	if not character then return end
	local old = character:FindFirstChild("CafeStaffTag")
	if old then old:Destroy() end
	local apron = character:FindFirstChild("CafeApron") -- (from before 2026-10-27)
	if apron then apron:Destroy() end
	if not shopKey then return end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CafeStaffTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(110, 30)
	-- just above the name tag (NameTagService: 70 px tall at 2.4 studs) at any
	-- distance: the same anchor, lifted by its own height in pixels
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.SizeOffset = Vector2.new(0, 2.6) -- (over the VIP / DJ row, which sits on the id + XP tag, 2026-10-27)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	-- (user 2026-10-27, 2nd) white letters with a green outline, no box, no cup
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "알바생"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 150, 80)
	stroke.Thickness = 2.5
	stroke.Parent = label
	gui.Parent = character
end

local function stopWork(player: Player, message: string?)
	local shopKey = staff[player]
	if not shopKey then return end
	staff[player] = nil
	if player.Character then
		player.Character:SetAttribute("CafeJob", nil)
		setStaffTag(player.Character, nil)
		playAt(player.Character:FindFirstChild("HumanoidRootPart"), "stop")
	end
	-- cups this person was making / carrying go back to the list
	for _, order in pairs(orders) do
		if order.maker == player.UserId then
			order.maker = 0
			order.ready = false
		end
	end
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("CafeOrder") then tool:Destroy() end
			end
		end
	end
	-- nobody left at this cafe: NPCs go, player customers get their drink
	if staffCount(shopKey) == 0 then
		local list = {}
		for _, order in pairs(orders) do
			if order.shop == shopKey then table.insert(list, order) end
		end
		for _, order in ipairs(list) do
			if order.kind == "npc" then npcLeave(order, false) else selfServe(order, "알바생이 퇴근해서 음료를 바로 받았어요.") end
		end
	end
	publish()
	if message and player.Parent then toast(player, message) end
end

local function startWork(player: Player, shopKey: any): (boolean, string?)
	if typeof(shopKey) ~= "string" or not isJobShop(shopKey) then return false, "알바할 수 없는 곳이에요." end
	if not nearStation(player, shopKey) then
		return false, "카운터 안쪽 작업대에서 시작해 주세요."
	end
	if staff[player] == shopKey then return true, nil end
	if staff[player] then stopWork(player, nil) end
	for _, order in pairs(orders) do
		if order.kind == "player" and order.userId == player.UserId then
			return false, "주문한 음료를 먼저 받아 주세요."
		end
	end
	staff[player] = shopKey
	lastNpcAt[shopKey] = os.clock() - CafeJobConfig.NpcEverySeconds + 4 -- first NPC soon
	if player.Character then
		player.Character:SetAttribute("CafeJob", shopKey)
		setStaffTag(player.Character, shopKey)
		playAt(player.Character:FindFirstChild("HumanoidRootPart"), "start")
	end
	player:SetAttribute("CafeJobEarned", economy.Earned(player, "CafeJob"))
	publish()
	return true, string.format("☕ 알바 시작! 주문 목록에서 [만들기] → 음료를 손님에게 가져다 주세요. (오늘 %d/%d %s)",
		economy.Earned(player, "CafeJob"), CafeJobConfig.DailyCap, "코인")
end

local function carrying(player: Player): number
	local n = 0
	for _, order in pairs(orders) do
		if order.maker == player.UserId then n += 1 end
	end
	return n
end

local function make(player: Player, id: any): (boolean, string?)
	local order = typeof(id) == "number" and orders[id] or nil
	local shopKey = staff[player]
	if not order or not shopKey or order.shop ~= shopKey then return false, "만들 수 없는 주문이에요." end
	if order.maker ~= 0 then return false, "다른 알바생이 만들고 있어요." end
	if carrying(player) >= 2 then return false, "음료는 한 번에 2잔까지 들 수 있어요." end
	if not nearStation(player, shopKey) then
		return false, "작업대에서 만들어 주세요."
	end
	order.maker = player.UserId
	publish()
	playAt(stationOf(shopKey), "make")
	task.wait(CafeJobConfig.MakeSeconds)
	if orders[order.id] ~= order or order.maker ~= player.UserId or staff[player] ~= shopKey then
		return false, nil
	end
	if not nearStation(player, shopKey) then
		order.maker = 0
		publish()
		return false, "만드는 동안 카운터를 떠났어요."
	end
	local item = itemOf(order)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not item or not backpack then return false, nil end
	local tool = snack.MakeTool(item)
	tool.Name = item.name .. " (주문)"
	tool.ToolTip = "주문한 손님에게 가져다 주세요"
	tool:SetAttribute("CafeOrder", order.id)
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	order.ready = true
	publish()
	return true, string.format("%s 완성! 손님에게 가서 [서빙하기]를 누르세요.", item.name)
end

local function serve(player: Player, id: any): (boolean, string?)
	local order = typeof(id) == "number" and orders[id] or nil
	if not order or staff[player] ~= order.shop or order.maker ~= player.UserId or not order.ready then
		return false, "서빙할 수 없는 주문이에요."
	end
	local customerModel: Model? = nil
	local customer: Player? = nil
	if order.kind == "player" then
		customer = Players:GetPlayerByUserId(order.userId)
		customerModel = customer and customer.Character
	else
		customerModel = order.npc
	end
	local target = rootOf(customerModel)
	local mine = rootOf(player.Character)
	if not target or not mine then return false, "손님을 찾을 수 없어요." end
	if (target.Position - mine.Position).Magnitude > CafeJobConfig.ServeDistance then
		return false, "손님 가까이 가서 서빙해 주세요."
	end
	local item = itemOf(order)
	if not item then return false, nil end
	-- coins: NPCs always; the same player customer only every SamePairGap
	local pay = true
	if customer then
		local key = player.UserId .. ":" .. customer.UserId
		local last = lastPaidPair[key]
		if last and os.clock() - last < CafeJobConfig.SamePairGap then pay = false end
		if pay then lastPaidPair[key] = os.clock() end
	end
	if order.kind == "npc" then
		local npc = order.npc
		local humanoid = npc and npc:FindFirstChildOfClass("Humanoid")
		if npc and humanoid then
			local cup = snack.MakeTool(item)
			cup.Parent = npc
			playAt(npc:FindFirstChild("Head") or rootOf(npc), "thanks")
		end
		npcLeave(order, true)
	else
		removeOrder(order)
		if customer then
			snack.Give(customer, item)
			toast(customer, string.format("☕ %s님이 %s 가져다 줬어요!", player.DisplayName, item.name))
		end
	end
	-- job XP every serve, also after the daily coin cap (D-100)
	economy.AddJobXP(player, CafeJobConfig.JobKey, "served", CafeJobConfig.ServeXP)
	local given = 0
	if pay then
		given = economy.Earn(player, CafeJobConfig.ServeCoins, "CafeJob", CafeJobConfig.DailyCap, "음료 서빙")
	end
	player:SetAttribute("CafeJobEarned", economy.Earned(player, "CafeJob"))
	if given == 0 then
		return true, if pay then "서빙 완료! (오늘 알바 코인은 다 받았어요)" else "서빙 완료! (같은 손님은 잠시 후에 코인이 다시 나와요)"
	end
	return true, nil
end

--------------------------------------------------

local function tick()
	local now = os.clock()
	-- staff who left, died or walked away
	for player, shopKey in pairs(staff) do
		local counter = counterOf(shopKey)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not player.Parent or not counter or not humanoid or humanoid.Health <= 0 then
			stopWork(player, nil)
		elseif not playerInCafe(player, shopKey, CafeJobConfig.WorkArea) then
			stopWork(player, "카페에서 멀어져서 알바를 마쳤어요.")
		elseif player.Character:GetAttribute("CafeJob") ~= shopKey then
			-- new character (respawn): the tag back on
			player.Character:SetAttribute("CafeJob", shopKey)
			setStaffTag(player.Character, shopKey)
		end
	end
	-- orders that waited too long, customers who left
	local list = {}
	for _, order in pairs(orders) do table.insert(list, order) end
	for _, order in ipairs(list) do
		if orders[order.id] == order then
			local late = now - order.created > CafeJobConfig.OrderTimeout
			if order.kind == "npc" then
				if late or not order.npc or not order.npc.Parent then npcLeave(order, false) end
			else
				local customer = Players:GetPlayerByUserId(order.userId)
				if not customer then
					removeOrder(order)
				elseif late then
					selfServe(order, "기다려 줘서 고마워요! 음료를 바로 받았어요.")
				elseif not playerInCafe(customer, order.shop, CafeJobConfig.WorkArea + 20) then
					removeOrder(order)
					toast(customer, "카페를 떠나서 주문이 취소됐어요.")
				end
			end
		end
	end
	-- NPC customers for cafes with staff
	for _, shopKey in ipairs(CafeJobConfig.Shops) do
		if staffCount(shopKey) > 0 then
			local npcs = 0
			for _, order in pairs(orders) do
				if order.shop == shopKey and order.kind == "npc" then npcs += 1 end
			end
			if npcs < CafeJobConfig.NpcMax and now - (lastNpcAt[shopKey] or 0) >= CafeJobConfig.NpcEverySeconds then
				lastNpcAt[shopKey] = now
				task.spawn(spawnNpc, shopKey)
			end
		end
	end
	-- old cups; drinks put down can be cleared once their owner left the cafe
	local cups = workspace:FindFirstChild("CafeCups")
	if cups then
		for _, cup in ipairs(cups:GetChildren()) do
			local since = cup:GetAttribute("Since")
			if typeof(since) == "number" and now - since > CafeJobConfig.CupSeconds then
				cup:Destroy()
			else
				local ownerId = cup:GetAttribute("Owner")
				local shopKey = cup:GetAttribute("Shop")
				if typeof(ownerId) == "number" and typeof(shopKey) == "string" then
					local owner = Players:GetPlayerByUserId(ownerId)
					local away = not owner or not playerInCafe(owner, shopKey, CafeJobConfig.WorkArea)
					if cup:GetAttribute("Clearable") ~= away then cup:SetAttribute("Clearable", away) end
				end
			end
		end
	end
end

function CafeJobService.Start(economyService: any, snackService: any)
	economy = economyService
	snack = snackService
	snack.SetOrderHandler(playerOrder)
	snack.SetFinishedHandler(function(character: Model, _item)
		-- an empty cup on the table when a customer finishes a cafe drink
		local root = rootOf(character)
		if not root then return end
		for _, shopKey in ipairs(CafeJobConfig.Shops) do
			if inCafe(shopKey, root.Position, 6) then
				placeCup(shopKey, root.Position)
				return
			end
		end
	end)
	local remote = Remotes:WaitForChild("CafeJob") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, payload: any)
		if action == "Start" then return startWork(player, payload)
		elseif action == "Stop" then
			stopWork(player, nil)
			return true, string.format("알바 끝! 오늘 알바로 %d %s 받았어요.", economy.Earned(player, "CafeJob"), "코인")
		elseif action == "Make" then return make(player, payload)
		elseif action == "Serve" then return serve(player, payload)
		elseif action == "PutDown" then return putDown(player, payload)
		end
		return false, nil
	end
	Players.PlayerRemoving:Connect(function(player)
		stopWork(player, nil)
		lastOrderAt[player.UserId] = nil
	end)
	publish()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then warn("[CafeJob] " .. tostring(err)) end
		end
	end)
end

return CafeJobService

--!strict
-- Cafe part-time job (알바, CAFE.md §9, D-099). Config: CafeJobConfig.
--
--   * Start / stop work at the counter (client prompt → remote CafeJob
--     "Start"/"Stop"). Staff wear an apron (character attribute CafeJob = shop).
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

-- speech bubble over a customer's head: what they ordered
local function setBubble(model: Model?, text: string?)
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
-- Empty cups on tables
--------------------------------------------------

local function cafeModel(shopKey: string): Instance?
	local counter = counterOf(shopKey)
	return counter and counter.Parent
end

-- top centre of the table next to a position (parts named "...Table..." in the cafe)
local function tableTop(shopKey: string, near: Vector3): Vector3?
	local model = cafeModel(shopKey)
	if not model then return nil end
	local best, bestDistance = nil, 9
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and string.find(string.lower(part.Name), "table") and part.Size.X >= 1.5 and part.Size.Z >= 1.5 then
			local flat = Vector3.new(part.Position.X - near.X, 0, part.Position.Z - near.Z).Magnitude
			if flat < bestDistance then best, bestDistance = part, flat end
		end
	end
	if not best then return nil end
	local top = best.Position.Y + best.Size.Y / 2
	-- a little off the centre so several cups do not overlap
	return Vector3.new(best.Position.X + (math.random() - 0.5) * math.min(best.Size.X, 2), top, best.Position.Z + (math.random() - 0.5) * math.min(best.Size.Z, 2))
end

local function placeCup(shopKey: string, near: Vector3)
	if staffCount(shopKey) == 0 then return end
	local top = tableTop(shopKey, near)
	if not top then return end
	local cup = Instance.new("Part")
	cup.Name = "EmptyCup"
	cup.Shape = Enum.PartType.Cylinder
	cup.Size = Vector3.new(0.85, 0.6, 0.6)
	cup.CFrame = CFrame.new(top + Vector3.new(0, 0.43, 0)) * CFrame.Angles(0, 0, math.rad(90))
	cup.Color = Color3.fromRGB(245, 245, 250)
	cup.Material = Enum.Material.Glass
	cup.Transparency = 0.3
	cup.Anchored = true
	cup.CanCollide = false
	cup:SetAttribute("Shop", shopKey)
	cup:SetAttribute("Since", os.clock())
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CleanPrompt"
	prompt.ActionText = "테이블 정리"
	prompt.ObjectText = "빈 컵"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- the staff's client turns it on
	prompt.Parent = cup
	prompt.Triggered:Connect(function(player)
		if not cup.Parent or staff[player] ~= shopKey then return end
		cup:Destroy()
		economy.Earn(player, CafeJobConfig.CleanCoins, "CafeJob", CafeJobConfig.DailyCap, "테이블 정리")
		player:SetAttribute("CafeJobEarned", economy.Earned(player, "CafeJob"))
	end)
	cup.Parent = folder("CafeCups")
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
		setBubble(customer and customer.Character, nil)
	end
	publish()
end

local function npcLeave(order: Order, served: boolean)
	local npc = order.npc
	local seat = order.seat
	removeOrder(order)
	if not npc then return end
	if served then
		setBubble(npc, "😋 맛있어요!")
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
	setBubble(player.Character, "☕ " .. item.name)
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
	local item = shop.items[math.random(1, #shop.items)]
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
		who = if friend then friend.name else nil,
	}
	setBubble(npc, (if friend then friend.name .. " · " else "") .. "☕ " .. item.name)
	publish()
end

--------------------------------------------------
-- Work
--------------------------------------------------

local function setApron(character: Model?, shopKey: string?)
	if not character then return end
	local old = character:FindFirstChild("CafeApron")
	if old then old:Destroy() end
	if not shopKey then return end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then return end
	local apron = Instance.new("Part")
	apron.Name = "CafeApron"
	apron.Size = Vector3.new(torso.Size.X * 0.85, torso.Size.Y * 1.5, 0.12)
	apron.Color = if shopKey == "HanokCafe" then Color3.fromRGB(120, 80, 50) else Color3.fromRGB(35, 90, 70)
	apron.Material = Enum.Material.Fabric
	apron.CanCollide = false
	apron.CanQuery = false
	apron.CanTouch = false
	apron.Massless = true
	local offset = CFrame.new(0, -torso.Size.Y * 0.35, -torso.Size.Z / 2 - 0.07)
	apron.CFrame = torso.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = torso
	weld.Part1 = apron
	weld.C0 = offset
	weld.Parent = apron
	apron.Parent = character
end

local function stopWork(player: Player, message: string?)
	local shopKey = staff[player]
	if not shopKey then return end
	staff[player] = nil
	if player.Character then
		player.Character:SetAttribute("CafeJob", nil)
		setApron(player.Character, nil)
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
	local counter = counterOf(shopKey)
	if not counter or distanceTo(player, counter) > CafeJobConfig.CounterDistance then
		return false, "카운터 가까이에서 시작해 주세요."
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
		setApron(player.Character, shopKey)
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
	local counter = counterOf(shopKey)
	if not counter or distanceTo(player, counter) > CafeJobConfig.CounterDistance then
		return false, "카운터에서 만들어 주세요."
	end
	order.maker = player.UserId
	publish()
	task.wait(CafeJobConfig.MakeSeconds)
	if orders[order.id] ~= order or order.maker ~= player.UserId or staff[player] ~= shopKey then
		return false, nil
	end
	if distanceTo(player, counter) > CafeJobConfig.CounterDistance then
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
		end
		npcLeave(order, true)
	else
		removeOrder(order)
		if customer then
			snack.Give(customer, item)
			toast(customer, string.format("☕ %s님이 %s 가져다 줬어요!", player.DisplayName, item.name))
		end
	end
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
		elseif distanceTo(player, counter) > CafeJobConfig.WorkArea then
			stopWork(player, "카페에서 멀어져서 알바를 마쳤어요.")
		elseif player.Character:GetAttribute("CafeJob") ~= shopKey then
			-- new character (respawn): put the apron back on
			player.Character:SetAttribute("CafeJob", shopKey)
			setApron(player.Character, shopKey)
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
				local counter = counterOf(order.shop)
				if not customer then
					removeOrder(order)
				elseif late then
					selfServe(order, "기다려 줘서 고마워요! 음료를 바로 받았어요.")
				elseif counter and distanceTo(customer, counter) > CafeJobConfig.WorkArea + 20 then
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
	-- old cups
	local cups = workspace:FindFirstChild("CafeCups")
	if cups then
		for _, cup in ipairs(cups:GetChildren()) do
			local since = cup:GetAttribute("Since")
			if typeof(since) == "number" and now - since > CafeJobConfig.CupSeconds then cup:Destroy() end
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
			local counter = counterOf(shopKey)
			if counter and (counter.Position - root.Position).Magnitude < CafeJobConfig.WorkArea then
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

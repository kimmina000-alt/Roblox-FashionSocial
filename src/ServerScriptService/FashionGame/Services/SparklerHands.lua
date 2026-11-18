--!strict
-- (D-1786, user 2026-11-18: "손스파클러 왼손에 들고 있게 수정 / 두 개 들면 두 손에 다
-- 들 수 있게 수정") The hand sparkler (SparkleService) is held in the LEFT hand:
-- once Roblox has welded the equipped tool to the right hand (RightGrip), that
-- weld is moved onto the left hand's grip. With a second hand sparkler in the
-- backpack, its parts go into the RIGHT hand (a Model "SparklerRightHand" in
-- the character, welded to the right grip) while the first one is held; they
-- go back into their own tool when the first is put away. Lighting the held
-- one lights the second too (SparkleService.lightHandSparkler).
-- Roblox lets a character hold only one Tool, so the second stays a Tool in the
-- backpack (bag / give / rejoin keep counting it) and only its parts move.

local Players = game:GetService("Players")

local SparklerHands = {}

type Pair = { partner: Tool, parts: Model, conns: {RBXScriptConnection} }
local pairOf: {[Tool]: Pair} = {} -- held tool -> the one in the right hand
local partsOfPartner: {[Tool]: Model} = {} -- partner tool -> where its parts are

local function isHand(t: Instance): boolean
	return t:IsA("Tool") and t:GetAttribute("HandSparkler") == true
end

local function hand(character: Model, side: string): BasePart?
	local p = character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm")
	return if p and p:IsA("BasePart") then p else nil
end

local function gripOf(character: Model, side: string): Attachment?
	local h = hand(character, side)
	local a = h and h:FindFirstChild(side .. "GripAttachment")
	return if a and a:IsA("Attachment") then a else nil
end

-- (upright in the hanging hand, like the friend bar's left half, D-1144: the
-- grip attachment is turned -90° about X; this turn takes it back)
local function holdC0(grip: Attachment): CFrame
	return CFrame.new(grip.Position) * CFrame.Angles(math.rad(90), 0, 0) * grip.CFrame.Rotation
end

-- where a hand sparkler's parts are now (the tool itself, or its right-hand Model)
function SparklerHands.partsOf(tool: Tool): Instance
	return partsOfPartner[tool] or tool
end

function SparklerHands.partnerOf(tool: Tool): Tool?
	local p = pairOf[tool]
	return p and p.partner
end

-- the held tool's grip weld onto the left hand
local function toLeft(tool: Tool, character: Model)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local left = hand(character, "Left")
	local grip = gripOf(character, "Left")
	if not handle or not left or not grip then return end
	local weld: Weld? = nil
	for _ = 1, 30 do
		if tool.Parent ~= character then return end
		local right = hand(character, "Right")
		local rg = right and right:FindFirstChild("RightGrip")
		if rg and rg:IsA("Weld") and rg.Part1 == handle then weld = rg break end
		local own = handle:FindFirstChild("LeftGrip")
		if own and own:IsA("Weld") then weld = own break end
		task.wait(0.05)
	end
	if not weld then
		-- (no RightGrip came: our own weld)
		local w = Instance.new("Weld")
		w.Name = "LeftGrip"
		w.Part1 = handle
		w.Parent = handle
		weld = w
	end
	local w = weld :: Weld
	w.Part0 = left
	w.C0 = holdC0(grip)
	w.C1 = tool.Grip
end

local function detach(tool: Tool)
	local p = pairOf[tool]
	if not p then return end
	pairOf[tool] = nil
	for _, c in ipairs(p.conns) do c:Disconnect() end
	local partner, parts = p.partner, p.parts
	partsOfPartner[partner] = nil
	if partner.Parent then
		local handle = parts:FindFirstChild("Handle")
		local pg = handle and handle:FindFirstChild("PairGrip")
		if pg then pg:Destroy() end
		for _, c in ipairs(parts:GetChildren()) do c.Parent = partner end
	end
	parts:Destroy()
end

-- a second hand sparkler from the backpack into the right hand
local function attach(tool: Tool, character: Model, player: Player)
	if pairOf[tool] or tool.Parent ~= character then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local grip = gripOf(character, "Right")
	local right = hand(character, "Right")
	if not backpack or not grip or not right then return end
	local lit = tool:GetAttribute("Lit") == true
	local partner: Tool? = nil
	for _, t in ipairs(backpack:GetChildren()) do
		if isHand(t) and t ~= tool and not partsOfPartner[t :: Tool] and (t:GetAttribute("Lit") == true) == lit
			and t:FindFirstChild("Handle") then
			partner = t :: Tool
			break
		end
	end
	if not partner then return end
	local handle = partner:FindFirstChild("Handle") :: BasePart
	local parts = Instance.new("Model")
	parts.Name = "SparklerRightHand"
	for _, c in ipairs(partner:GetChildren()) do
		if c:IsA("BasePart") then c.Parent = parts end
	end
	local w = Instance.new("Weld")
	w.Name = "PairGrip"
	w.Part0 = right
	w.Part1 = handle
	w.C0 = holdC0(grip)
	w.C1 = partner.Grip
	w.Parent = handle
	parts.Parent = character
	local p: Pair = { partner = partner, parts = parts, conns = {} }
	pairOf[tool] = p
	partsOfPartner[partner] = parts
	-- the partner taken out of the backpack (given away, burnt out, equipped
	-- by itself): its parts go back first
	table.insert(p.conns, partner.AncestryChanged:Connect(function()
		if partner.Parent ~= backpack then detach(tool) end
	end))
end

local function onEquipped(tool: Tool, character: Model, player: Player)
	task.spawn(toLeft, tool, character)
	attach(tool, character, player)
	local conn: RBXScriptConnection? = nil
	conn = tool.AncestryChanged:Connect(function()
		if tool.Parent ~= character then
			if conn then conn:Disconnect() end
			detach(tool)
		end
	end)
end

local function heldHand(character: Model): Tool?
	for _, t in ipairs(character:GetChildren()) do
		if isHand(t) then return t :: Tool end
	end
	return nil
end

function SparklerHands.watch(player: Player)
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(function(c)
			if isHand(c) then onEquipped(c :: Tool, character, player) end
		end)
		local held = heldHand(character)
		if held then onEquipped(held, character, player) end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
	-- a second one arriving while the first is held (bought / given / restored)
	local function onBackpack(backpack: Instance)
		backpack.ChildAdded:Connect(function(c)
			if not isHand(c) then return end
			task.defer(function()
				local character = player.Character
				local held = character and heldHand(character)
				if character and held and not pairOf[held] then attach(held, character, player) end
			end)
		end)
	end
	player.ChildAdded:Connect(function(c)
		if c:IsA("Backpack") then onBackpack(c) end
	end)
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then onBackpack(bp) end
end

function SparklerHands.Start()
	for _, p in ipairs(Players:GetPlayers()) do SparklerHands.watch(p) end
	Players.PlayerAdded:Connect(SparklerHands.watch)
end

return SparklerHands

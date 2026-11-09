--!strict
-- (D-1129, user 2026-11-10: "oh24_ssang: 친구바 / 친구랑 나눠 먹을 수 있음. 포인트도
-- 반으로 나눔. / 구매 후 클릭하면 (A) Bite1-1,Bite1-2,Bite1-3,Plate1 (B) Bite2-1,
-- Bite2-2,Bite2-3,Plate2 이렇게 두 아이템으로 나뉨. 친구랑 나누면 나는 A 가지고 친구는
-- B 가짐. 랜덤으로 Bite1-1, Bite2-1 은 반대쪽 A, B에 붙기도 함. / 나눠진 A와 B는
-- Bite1-1,1-2,1-3 순서대로 먹음")
--
-- The user's model (ArtAssets.Foods.SsangBites) has its pieces numbered tops
-- first (1-1 → Bite1, 2-1 → Bite2, 1-2 → Bite3, 2-2 → Bite4, 1-3 → Bite5,
-- 2-3 → Bite6) and every part carries Side = 1 (A) or 2 (B), the sticks too.
-- A half is the whole bar with the other side hidden: its pieces count as
-- eaten (BitesEaten, so the normal piece-by-piece eating, the table and the
-- bag all keep working) and its stick is hidden; the grip moves onto the own
-- stick. At the split one of the two top pieces may stay on the other half,
-- like a real 쌍쌍바 that breaks unevenly (tool attribute PairMoved = 1 or 2).
--
-- The first tap splits it: the buyer keeps A in the right hand, B goes into the
-- left hand with a "반쪽 받기" prompt for the people nearby (the buyer's own
-- client hides it, SnackController). Whoever takes it gets B in the hand with
-- half the XP (SplitXP). Nobody took it: when A is eaten up, B comes into the
-- right hand; when A is put away (bag, table), B goes into the backpack.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local FriendBar = {}

type Deps = {
	makeTool: (item: any) -> Tool,
	eatenOf: (tool: Tool) -> {[number]: boolean},
	setEaten: (tool: Tool, set: {[number]: boolean}) -> (),
	applyEaten: (root: Instance, set: {[number]: boolean}) -> (),
	giveTool: (player: Player, tool: Tool) -> boolean,
	splitXP: (from: Instance, to: Instance, units: number) -> (),
	analytics: (player: Player, what: string) -> (),
}
local deps: Deps? = nil

function FriendBar.init(d: Deps)
	deps = d
end

FriendBar.TakeDistance = 10
-- (D-1131, user 2026-11-10: "친구바 갈라질 때 소리 id: 77063346244597")
FriendBar.SplitSound = 77063346244597
FriendBar.HalfName = "친구바 (반쪽)"

-- where the halves wait while they are in a left hand (BagService saves them: KeptBy)
local folder: Folder? = nil
local function keep(): Folder
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "FriendBarHalves"
		f.Parent = ServerStorage
		folder = f
	end
	return folder :: Folder
end
function FriendBar.keptTools(): {Instance}
	return if folder then folder:GetChildren() else {}
end

local function sideOf(p: Instance): number?
	local s = p:GetAttribute("Side")
	return if typeof(s) == "number" then s else nil
end

-- The tool shows one half: `side` 1 or 2, `moved` = the top piece (1 or 2)
-- that went over to the other half, or 0. Keeps the pieces already eaten.
function FriendBar.applyHalf(tool: Tool, handle: BasePart, side: number, moved: number)
	local d = deps
	if not d then return end
	local set = d.eatenOf(tool)
	local own = 0
	for _, p in ipairs(handle:GetDescendants()) do
		if p:IsA("BasePart") then
			local s = sideOf(p)
			local n = p:GetAttribute("Bite")
			if typeof(n) == "number" and s then
				local mine = (s == side and n ~= moved) or (s ~= side and n == moved)
				if not mine then set[n] = true end
			elseif s and s ~= side then
				-- the other half's stick
				p.Transparency = 1
				p:SetAttribute("BiteT0", 1)
			end
		end
	end
	local counted: {[number]: boolean} = {}
	for _, p in ipairs(handle:GetDescendants()) do
		local n = p:IsA("BasePart") and p:GetAttribute("Bite")
		if typeof(n) == "number" and not set[n] and not counted[n] then
			counted[n] = true
			own += 1
		end
	end
	d.setEaten(tool, set)
	d.applyEaten(handle, set)
	tool:SetAttribute("Pair", nil)
	tool:SetAttribute("Half", side)
	tool:SetAttribute("PairMoved", moved)
	tool:SetAttribute("Bites", math.max(1, own))
	tool.Name = FriendBar.HalfName
	tool.ToolTip = "클릭(터치)해서 먹기"
	-- held by its own stick (the handle sits in the middle of the two)
	for _, p in ipairs(handle:GetChildren()) do
		local weld = p:IsA("BasePart") and sideOf(p) == side and p:GetAttribute("Bite") == nil and p:FindFirstChildOfClass("Weld")
		if weld then
			local g = tool.Grip
			tool.Grip = CFrame.new(Vector3.new(weld.C0.X, g.Position.Y, weld.C0.Z)) * g.Rotation
			break
		end
	end
end

-- the copy of B in the left hand, with the prompt
local function holdLeft(owner: Player, half: Tool, a: Tool): (() -> ())?
	local character = owner.Character
	local hand = character and character:FindFirstChild("LeftHand") or (character and character:FindFirstChild("Left Arm"))
	local grip = hand and hand:FindFirstChild("LeftGripAttachment") :: Attachment?
	local handle = half:FindFirstChild("Handle") :: BasePart?
	if not character or not grip or not handle then return nil end
	local copy = handle:Clone()
	copy.Name = "FriendBarHalf"
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("Sound") then d:Destroy() end
	end
	copy.Anchored = false
	copy.CFrame = grip.WorldCFrame * half.Grip:Inverse()
	-- (D-1144) fixed to the hand's grip (a WeldConstraint keeps the server's offset)
	local weld = Instance.new("Weld")
	weld.Part0 = grip.Parent :: BasePart
	weld.Part1 = copy
	weld.C0 = CFrame.new(grip.Position) * CFrame.Angles(math.rad(90), 0, 0) * grip.CFrame.Rotation -- (upright in the hanging hand)
	weld.C1 = half.Grip
	weld.Parent = copy
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FriendBarTake"
	prompt.ActionText = "반쪽 받기"
	prompt.ObjectText = owner.DisplayName .. "의 친구바"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = FriendBar.TakeDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = copy
	copy.Parent = character

	local done = false
	local conns: {RBXScriptConnection} = {}
	local function finish()
		if done then return end
		done = true
		for _, c in ipairs(conns) do c:Disconnect() end
		if copy.Parent then copy:Destroy() end
	end
	-- someone else takes it
	table.insert(conns, prompt.Triggered:Connect(function(taker: Player)
		if done or taker == owner or half.Parent ~= folder then return end
		local root = taker.Character and taker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - copy.Position).Magnitude > FriendBar.TakeDistance + 4 then return end
		finish()
		half:SetAttribute("KeptBy", nil)
		local d = deps
		if d then
			d.giveTool(taker, half)
			d.analytics(taker, "FriendBar")
		end
	end))
	-- nobody took it: back to the owner
	local function giveBack(eatenUp: boolean)
		if done then return end
		finish()
		if half.Parent ~= folder then return end
		half:SetAttribute("KeptBy", nil)
		local char = owner.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local backpack = owner:FindFirstChildOfClass("Backpack")
		if eatenUp and humanoid and humanoid.Health > 0 and deps then
			(deps :: Deps).giveTool(owner, half)
		elseif backpack and humanoid and humanoid.Health > 0 then
			half.Parent = backpack
		else
			-- (gone with the character: into the next backpack)
			half:SetAttribute("KeptBy", owner.UserId)
			local c: RBXScriptConnection? = nil
			c = owner.CharacterAdded:Connect(function()
				if c then c:Disconnect() end
				task.wait(1)
				local bp = owner:FindFirstChildOfClass("Backpack")
				if bp and half.Parent == folder then
					half:SetAttribute("KeptBy", nil)
					half.Parent = bp
				end
			end)
		end
	end
	table.insert(conns, a.Destroying:Connect(function() giveBack(true) end))
	table.insert(conns, a.AncestryChanged:Connect(function()
		if a.Parent ~= character then giveBack(a.Parent == nil) end
	end))
	table.insert(conns, character.Destroying:Connect(function() giveBack(false) end))
	table.insert(conns, owner.AncestryChanged:Connect(function()
		if not owner.Parent then finish() end
	end))
	return finish
end

-- the first tap: A stays in the hand, B into the left hand for a friend
function FriendBar.split(tool: Tool, item: any)
	local d = deps
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not d or not handle then return end
	local owner = Players:GetPlayerFromCharacter(tool.Parent)
	if not owner then return end
	-- the top pieces stay on their own half half the time, else one goes over
	local r = math.random()
	local moved = if r < 0.5 then 0 elseif r < 0.75 then 1 else 2
	local half = d.makeTool(item)
	local bHandle = half:FindFirstChild("Handle") :: BasePart?
	if not bHandle then half:Destroy() return end
	d.splitXP(tool, half, 2) -- (포인트도 반으로)
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxassetid://" .. tostring(FriendBar.SplitSound)
	snd.Volume = 1
	snd.RollOffMaxDistance = 40
	snd.Parent = handle
	snd:Play()
	snd.Ended:Connect(function() snd:Destroy() end)
	task.delay(6, function() if snd.Parent then snd:Destroy() end end)
	FriendBar.applyHalf(tool, handle, 1, moved)
	FriendBar.applyHalf(half, bHandle, 2, moved)
	half:SetAttribute("KeptBy", owner.UserId)
	half.Parent = keep()
	if not holdLeft(owner, half, tool) then
		half:SetAttribute("KeptBy", nil)
		local backpack = owner:FindFirstChildOfClass("Backpack")
		if backpack then half.Parent = backpack else half:Destroy() end
	end
end

return FriendBar

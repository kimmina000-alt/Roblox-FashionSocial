--!strict
-- Cafes, snack stands, the OH24 convenience store and the 국밥집 (SnackConfig,
-- CAFE.md §8, D-317): the order → item → sit and eat/drink loop.
--
--   * Parts tagged "SnackShop" (attribute Shop) get an order prompt (E).
--     Triggering it tells the client (SnackNotify "Open") to show the menu.
--   * Remote Snack (RemoteFunction) "Buy", shopKey, itemKey: checks distance
--     and coins, then gives a hand-held tool shaped like the item.
--   * Robux items (item.product) are bought with a developer product; the
--     grant gives the item, or for a shared one (item.share) puts a plate on
--     the nearest table where everyone takes a piece ("한 조각 먹기").
--   * Clicking (tapping) the tool takes a bite (item.bites or SnackConfig.Bites).
--     Works standing or sitting at a table.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local SnackConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("SnackConfig"))
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local EconomyConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("EconomyConfig"))
local MonetizationService = require(script.Parent.MonetizationService)
local FoodShapes = require(script.Parent.FoodShapes)
local RamenCup = require(script.Parent:WaitForChild("RamenCup")) -- (D-1053: the user's cup ramen)
local Microwave = require(script.Parent:WaitForChild("Microwave")) -- (D-1104: 삼각김밥 warmed in the OH24 microwave)
local Analytics = require(script.Parent:WaitForChild("Analytics")) -- (D-1124)
local FriendBar = require(script.Parent:WaitForChild("FriendBar")) -- (D-1129: 친구바, split in two)
local SnackHands = require(script.Parent:WaitForChild("SnackHands")) -- (D-1131: 빼쭉이, one stick at a time in the other hand)

local SnackService = {}
local economy: any = nil
-- cafe job (CafeJobService): takes orders while staff is on duty, and hears
-- about finished drinks (empty cup on the table)
local orderHandler: ((Player, SnackConfig.Shop, SnackConfig.Item) -> (boolean, string?))? = nil
local finishedHandler: ((Model, SnackConfig.Item) -> ())? = nil

-- tables a shared plate can be put on
local TABLE_TAGS = { "CafeTable", "GukbapTable", "DrinkTable", "SnackTable" }

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- a part drawn as an ellipsoid (no texture, so a SpecialMesh sphere is fine)
local function blob(name: string, size: Vector3, color: Color3): Part
	local p = part(name, size, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- an upright cylinder (Part cylinders run along X: turned at attach time)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function cyl(name: string, d: number, h: number, color: Color3, material: Enum.Material?): Part
	return part(name, Vector3.new(h, d, d), color, material, Enum.PartType.Cylinder)
end

-- Extra piece fixed to the handle with a Weld (C0 offset; works before the
-- tool is in the world, unlike a WeldConstraint).
local function attach(handle: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = handle.CFrame * offset
	piece.Parent = handle
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.C0 = offset
	weld.Parent = piece
end

local function countSnacks(player: Player): number
	local count = 0
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("Snack") then count += 1 end
			end
		end
	end
	return count
end

-- The two-in-hand limit is for the cafe part-time staff on shift only (their
-- tray job); everyone else can carry more, extra food waits in the backpack
-- (user 2026-10-27).
local function handsFull(player: Player): boolean
	local character = player.Character
	if not (character and character:GetAttribute("CafeJob")) then return false end
	return countSnacks(player) >= SnackConfig.MaxCarried
end

local function mouthGrip(character: Model, lift: number): CFrame?
	local head = character:FindFirstChild("Head") :: BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local attachment = hand and hand:FindFirstChild("RightGripAttachment") :: Attachment?
	if not head or not attachment then return nil end
	local target = head.CFrame * CFrame.new(0.2, -0.35 + lift, -0.8) * CFrame.Angles(math.rad(50), 0, 0)
	return target:Inverse() * attachment.WorldCFrame
end

-- Every hand-held item is eaten in three bites, from the top down: the edible
-- pieces are cut in three bands of their height and one band goes per bite
-- (user 2026-10-26). Soup and noodles drop their level instead.
local EAT_STEPS = 3
local function bitesOf(item: SnackConfig.Item): number
	if (item :: any).oneBite then return 1 end
	-- (D-1036) the user's 국밥 models: one spoonful per piece
	return FoodShapes.biteCount(item) or EAT_STEPS
end

-- containers and tools that stay in the hand
local NOT_EDIBLE = {
	Handle = true, Cup = true, Band = true, Glass = true, Bowl = true, Spoon = true,
	Chopsticks = true, Straw = true, Cap = true,
}
for name in pairs(FoodShapes.NotEdible) do NOT_EDIBLE[name] = true end

-- a bite sound per kind of item (ProSoundEffects / public eating clips, 2026-10-26)
-- (user 2026-10-30: soup without the spoon scraping the bowl, other meat chewing)
local EAT_SOUND = {
	cup = 9114171855, bottle = 9114171855, -- gulp
	parfait = 137096768206416, -- crunchy, like the bread (user 2026-10-30: was the gulp)
	bowl = 133241476322672, noodle = 140514526743537, -- (D-1063: 국밥 = the user's clip; 140514526743537 "Sipping" by blixxitry before)
	ricebowl = 113253562957164, -- 공깃밥: its own clip (user 2026-10-30)
	bag = 137096768206416, bread = 137096768206416, rice = 137096768206416, -- crunchy / bready
	cake = 95249450082163, cone = 95249450082163, bar = 95249450082163, -- soft
	plate = 135174197196705, -- "Chewing" (GIANT EATERS)
}
-- 국밥 (kind "bowl"): the user's own three clips, picked at random each
-- spoonful, never the same twice in a row (user 2026-10-30;
-- docs/04_ART/sounds/gukbap_eat_1..3.mp3, uploaded on Vantablack_Dev). 0 = the old clip.
-- (user 2026-10-30, later) one Creator Store clip instead: "Sipping"
-- (140514526743537, 3.1 s); the own clips were 98804537108952, 105506248237925, 115770485617090
-- (D-1063, user 2026-11-09: "국밥 먹는 소리: 133241476322672"; was 140514526743537)
-- (D-1162, user 2026-11-10: "국밥 먹는 소리 수정: 133347729618467"; was 133241476322672)
local GUKBAP_CLIPS = { 133347729618467 }
-- (D-1075, user 2026-11-09: "국밥 먹는 소리 앞에 0.5초 더 잘라") the old clip from 0.5 s in;
-- the new clip from its start (D-1162)
local GUKBAP_FROM = 0
local lastGukbap = 0
local function gukbapClip(): number?
	local ready = {}
	for i, id in ipairs(GUKBAP_CLIPS) do if id ~= 0 and i ~= lastGukbap then table.insert(ready, i) end end
	if #ready == 0 then
		for i, id in ipairs(GUKBAP_CLIPS) do if id ~= 0 then table.insert(ready, i) end end
	end
	if #ready == 0 then return nil end
	lastGukbap = ready[math.random(1, #ready)]
	return GUKBAP_CLIPS[lastGukbap]
end
-- coffee is sipped, not gulped (user 2026-10-30): "Tea Cup Up And Down 10" (Pro Sound Effects)
-- (user 2026-10-30) the cafe's coffees and water: the user's own clip "마시다"
-- (was 9119949556 "Tea Cup Up And Down 10"); (user 2026-10-30, later) the
-- Creator Store "Water Gulp/Drink Sound" (1481574895, 1.6 s), was 77555451916623
local COFFEE_SIP = 1481574895
local COFFEE = { iceamericano = true, hotamericano = true, latte = true, caramel = true, cappuccino = true, water = true }
-- (D-1158, user 2026-11-10: "물/캔 음료 마시는 소리: 2245190929 / 커피 종류 마시는 소리:
-- 102811247160851 / 아메리카노 핫 마실 때 소리: 97803848511203 / 캔 음료 사서 처음 클릭해서
-- 개봉할 때 나는 소리: 111959113939767 (이건 모션도 넣어야 함)")
local SIP_SOUND: {[string]: number} = {
	water = 2245190929, soda = 2245190929,
	iceamericano = 102811247160851, latte = 102811247160851, caramel = 102811247160851,
	cappuccino = 102811247160851, frappe = 102811247160851,
	hotamericano = 97803848511203,
}
SnackService.CanSip = 2245190929 -- (DrinkService: the club's cans)
SnackService.CanOpen = 111959113939767
local CANS = { soda = true } -- (OH24 cans opened on the first tap)

-- (D-1158) a can not opened yet: open it now (the two-hand motion of the
-- 삼각김밥 wrapper, EatMotionController "Unwrap", and the tab's sound). True when
-- this tap opened it. DrinkService uses it for the club's cans too.
function SnackService.openCan(tool: Tool): boolean
	local key = tool:GetAttribute("Snack")
	local isCan = (typeof(key) == "string" and CANS[key]) or tool:GetAttribute("CanSealed")
	if not isCan or tool:GetAttribute("Opened") then return false end
	tool:SetAttribute("Opened", true)
	tool:SetAttribute("CanSealed", nil)
	local character = tool.Parent
	if character and character:IsA("Model") then
		character:SetAttribute("Unwrap", ((character:GetAttribute("Unwrap") :: number?) or 0) + 1)
	end
	tool:SetAttribute("Busy", true)
	task.delay(1.3, function() if tool.Parent then tool:SetAttribute("Busy", nil) end end)
	local h = tool:FindFirstChild("Handle")
	if h then
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://" .. tostring(SnackService.CanOpen)
		snd.Volume = 0.9
		snd.RollOffMaxDistance = 40
		snd.Parent = h
		task.delay(0.35, function() if snd.Parent then snd:Play() end end) -- (as the left hand meets the tab)
		Debris:AddItem(snd, 5)
	end
	return true
end
local QUIET = { bagel = true, saltbread = true } -- their bite at half volume
-- (D-909, user 2026-11-05: "돼지국밥 먹는 소리 2배로 키워") 0.7 → 1.4
-- (D-952, user 2026-11-07: "국밥 먹는 소리 3배로 키워") the three 국밥 at 3×
-- (pork 1.4 → 4.2, the others 0.7 → 2.1)
-- (D-956, user 2026-11-07 (2): "국밥 먹는 소리 10배로 키워") 10× the volumes from
-- before D-952: pork 14, the others 7. A Sound stops at volume 10, so above that
-- the rest goes on a SoundGroup (Sound 10 × group 1.4).
-- (D-957, user 2026-11-07 (3): "국밥 소리 다 14로 통일 / 수육 먹는 소리도 최대로
-- 키워") all three 국밥 14; 수육 at the most the engine plays: Sound 10 × its
-- SoundGroup 10
local LOUD = { pork = 14, sundae = 14, beef = 14, suyuk = 100 }
local function setVolume(sound: Sound, volume: number)
	if volume <= 10 then
		sound.Volume = volume
		return
	end
	sound.Volume = 10
	local SoundService = game:GetService("SoundService")
	local name = string.format("SnackLoud%.2f", volume / 10)
	local group = SoundService:FindFirstChild(name) :: SoundGroup?
	if not group then
		local g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = volume / 10
		g.Parent = SoundService
		group = g
	end
	sound.SoundGroup = group
end

-- Remembers each edible piece's place in the handle's height (call once the
-- tool is built): which local axis is up, its bottom and top, and its weld.
local function markEdible(tool: Tool, handle: BasePart)
	local lo, hi = math.huge, -math.huge
	local zlo, zhi = math.huge, -math.huge
	for _, piece in ipairs(handle:GetChildren()) do
		local weld = piece:IsA("BasePart") and piece:FindFirstChildOfClass("Weld")
		if weld and not NOT_EDIBLE[piece.Name] and piece.Transparency < 1 then
			-- (front-to-back eating, EatAlong = "Z": where the piece lies along
			-- the handle's Z, and which of its own axes runs that way)
			local along = weld.C0:VectorToObjectSpace(Vector3.zAxis)
			local zAxis = if math.abs(along.X) > 0.9 then "X" elseif math.abs(along.Z) > 0.9 then "Z" elseif math.abs(along.Y) > 0.9 then "Y" else nil
			local zHalf = if zAxis then (piece.Size :: any)[zAxis] / 2 else 0
			piece:SetAttribute("EatZAxis", zAxis)
			piece:SetAttribute("EatZ0", weld.C0.Z - zHalf)
			piece:SetAttribute("EatZ1", weld.C0.Z + zHalf)
			piece:SetAttribute("EatSizeZ", piece.Size)
			piece:SetAttribute("EatC0Z", weld.C0)
			zlo, zhi = math.min(zlo, weld.C0.Z - zHalf), math.max(zhi, weld.C0.Z + zHalf)
			local up = weld.C0:VectorToObjectSpace(Vector3.yAxis)
			local axis = if math.abs(up.X) > 0.9 then "X" elseif math.abs(up.Z) > 0.9 then "Z" elseif math.abs(up.Y) > 0.9 then "Y" else nil
			if axis then
				local half = (piece.Size :: any)[axis] / 2
				local y0, y1 = weld.C0.Y - half, weld.C0.Y + half
				piece:SetAttribute("EatAxis", axis)
				piece:SetAttribute("EatY0", y0)
				piece:SetAttribute("EatY1", y1)
				piece:SetAttribute("EatSize", piece.Size)
				piece:SetAttribute("EatC0", weld.C0)
				lo, hi = math.min(lo, y0), math.max(hi, y1)
			end
		end
	end
	if lo < hi then
		tool:SetAttribute("EatLo", lo)
		tool:SetAttribute("EatHi", hi)
	end
	if zlo < zhi then
		tool:SetAttribute("EatZLo", zlo)
		tool:SetAttribute("EatZHi", zhi)
	end
end

-- Breads (FoodShapes, EatAlong = "Z") lose a band from the front (-Z) end
-- each bite: pieces in front of the cut go, a piece across it gets shorter.
local function eatFromFront(handle: BasePart, lo: number, hi: number, left: number, total: number)
	local cut = lo + (hi - lo) * (total - left) / total
	for _, piece in ipairs(handle:GetChildren()) do
		local weld = piece:IsA("BasePart") and piece:FindFirstChildOfClass("Weld")
		local z0, z1 = piece:GetAttribute("EatZ0"), piece:GetAttribute("EatZ1")
		if weld and piece:IsA("BasePart") and typeof(z0) == "number" and typeof(z1) == "number" then
			local axis = piece:GetAttribute("EatZAxis")
			if z1 <= cut + 0.01 or (axis == nil and (z0 + z1) / 2 < cut) then
				piece.Transparency = 1
			elseif axis and z0 < cut then
				local size = piece:GetAttribute("EatSizeZ") :: Vector3
				local c0 = piece:GetAttribute("EatC0Z") :: CFrame
				local len = z1 - cut
				piece.Size = if axis == "X" then Vector3.new(len, size.Y, size.Z) elseif axis == "Y" then Vector3.new(size.X, len, size.Z) else Vector3.new(size.X, size.Y, len)
				weld.C0 = c0 + Vector3.new(0, 0, (cut - z0) / 2)
			end
		end
	end
end

-- Shows what is left after a bite: everything above the cut line is gone.
-- Pieces flagged EatDrop (a soup surface) sink instead of being cut.
local function eatDownTo(handle: BasePart, lo: number, hi: number, left: number, total: number)
	local cut = lo + (hi - lo) * left / total
	for _, piece in ipairs(handle:GetChildren()) do
		local axis = piece:IsA("BasePart") and piece:GetAttribute("EatAxis")
		local weld = axis and piece:FindFirstChildOfClass("Weld")
		if weld and piece:IsA("BasePart") then
			local y0, y1 = piece:GetAttribute("EatY0") :: number, piece:GetAttribute("EatY1") :: number
			local c0 = piece:GetAttribute("EatC0") :: CFrame
			local drop = piece:GetAttribute("EatDrop")
			if piece:GetAttribute("EatShrink") then
				-- bread is bitten off from its far end: it gets shorter each bite
				-- and goes at the last one (user 2026-10-26)
				local size = piece:GetAttribute("EatSize") :: Vector3
				local z = size.Z * left / total
				piece.Size = Vector3.new(size.X, size.Y, math.max(z, 0.05))
				weld.C0 = c0 + Vector3.new(0, 0, (size.Z - z) / 2)
				if left <= 0 then piece.Transparency = 1 end
			elseif typeof(drop) == "number" then
				-- the soup level goes down a third of the bowl each bite
				weld.C0 = c0 - Vector3.new(0, drop * (total - left) / total, 0)
				if left <= 0 then piece.Transparency = 1 end
			elseif y0 >= cut - 0.01 or (piece:IsA("Part") and piece.Shape == Enum.PartType.Ball and (y0 + y1) / 2 > cut) then
				piece.Transparency = 1
				for _, d in ipairs(piece:GetDescendants()) do
					if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
				end
			elseif y1 > cut and not (piece:IsA("Part") and piece.Shape == Enum.PartType.Ball) then
				local h = cut - y0
				local size = piece:GetAttribute("EatSize") :: Vector3
				piece.Size = if axis == "X" then Vector3.new(h, size.Y, size.Z) elseif axis == "Z" then Vector3.new(size.X, size.Y, h) else Vector3.new(size.X, h, size.Z)
				weld.C0 = c0 + Vector3.new(0, (y0 + h / 2) - c0.Y, 0)
			end
		end
	end
end

-- (D-1036, user 2026-11-09: "국밥도 업데이트") the user's 국밥 models: the parts of
-- piece n carry the attribute Bite = n (FoodShapes). With `left` of `total`
-- bites left, the first pieces in order are gone (hidden, so a copy on the
-- table and the tool stay part for part alike). The number of the next piece.
local function bitePieces(root: Instance): {[number]: {BasePart}}
	local by: {[number]: {BasePart}} = {}
	for _, p in ipairs(root:GetDescendants()) do
		local n = p:IsA("BasePart") and p:GetAttribute("Bite")
		if typeof(n) == "number" then
			by[n] = by[n] or {}
			table.insert(by[n], p :: BasePart)
		end
	end
	return by
end
local function showBitesLeft(root: Instance, left: number, total: number): number?
	local by = bitePieces(root)
	local count = 0
	for n in pairs(by) do count = math.max(count, n) end
	if count == 0 then return nil end
	-- (as many pieces as bites: one each; else spread over the bites)
	local gone = math.clamp(math.round(count * (total - left) / math.max(total, 1)), 0, count)
	for n, parts in pairs(by) do
		for _, p in ipairs(parts) do
			local t0 = p:GetAttribute("BiteT0")
			if typeof(t0) ~= "number" then t0 = p.Transparency p:SetAttribute("BiteT0", t0) end
			p.Transparency = if n <= gone then 1 else t0 :: number
			for _, d in ipairs(p:GetChildren()) do
				if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = if n <= gone then 1 else 0 end
			end
		end
	end
	return if gone < count then gone + 1 else nil
end
-- (D-1037, user 2026-11-09: "국밥도 선택한 바이트 먹을 수 있게") which pieces are
-- eaten, in any order: the tool's attribute BitesEaten, ",3,1,5,"
local function eatenOf(tool: Tool): {[number]: boolean}
	local set = {}
	local raw = tool:GetAttribute("BitesEaten")
	if typeof(raw) == "string" then
		for n in string.gmatch(raw, "%d+") do set[tonumber(n) :: number] = true end
	end
	return set
end
local function setEaten(tool: Tool, set: {[number]: boolean})
	local list = {}
	for n in pairs(set) do table.insert(list, n) end
	table.sort(list)
	tool:SetAttribute("BitesEaten", "," .. table.concat(list, ",") .. ",")
end
-- hide the eaten pieces (and let taps go through them)
local function applyEaten(root: Instance, set: {[number]: boolean})
	for n, parts in pairs(bitePieces(root)) do
		for _, p in ipairs(parts) do
			local t0 = p:GetAttribute("BiteT0")
			if typeof(t0) ~= "number" then t0 = p.Transparency p:SetAttribute("BiteT0", t0) end
			local q0 = p:GetAttribute("BiteQ0")
			if typeof(q0) ~= "boolean" then q0 = p.CanQuery p:SetAttribute("BiteQ0", q0) end
			local gone = set[n] == true
			p.Transparency = if gone then 1 else t0 :: number
			p.CanQuery = if gone then false else q0 :: boolean
			for _, d in ipairs(p:GetChildren()) do
				if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = if gone then 1 else 0 end
			end
		end
	end
end
-- the piece to eat now: the one asked for when it is still there, else the lowest left
local function nextBite(root: Instance, set: {[number]: boolean}, wanted: number?): number?
	local by = bitePieces(root)
	if wanted and by[wanted] and not set[wanted] then return wanted end
	local best: number? = nil
	for n in pairs(by) do
		if not set[n] and (best == nil or n < best) then best = n end
	end
	return best
end

local SOUND_WRAPPER = 75383018229679 -- (D-1065) 삼각김밥 포장 비닐 뜯는 소리
local visualCut: (Tool, Instance?, number, number) -> ()
local function bite(tool: Tool, item: SnackConfig.Item)
	-- a cup the cafe staff is carrying to a customer is not theirs to drink
	if tool:GetAttribute("Busy") or tool:GetAttribute("CafeOrder") then return end
	-- (D-1158) a can (탄산음료 캔): the first tap opens it, the two-hand motion and
	-- the tab's sound, no sip yet
	if SnackService.openCan(tool) then return end
	-- (D-1065) a wrapped 삼각김밥: the first tap tears the wrapper (piece 1) off
	if tool:GetAttribute("Wrapped") then
		tool:SetAttribute("Wrapped", nil)
		local h = tool:FindFirstChild("Handle")
		-- (D-1105, user 2026-11-09: "삼각김밥 처음에 포장 뜯을 때 양 손으로 뜯는 모션
		-- 추가") the character attribute "Unwrap" (a count) starts the two-hand
		-- tear on every client (EatMotionController): both hands come together in
		-- front of the chest (0.35 s), the left one pulls the wrapper off to the side
		-- (it goes with that hand, a copy on each client) and the arms go down
		-- (1.3 s in all). The wrapper on the item goes when the pull starts.
		local character = tool.Parent
		if character and character:IsA("Model") then
			character:SetAttribute("Unwrap", ((character:GetAttribute("Unwrap") :: number?) or 0) + 1)
		end
		tool:SetAttribute("Busy", true)
		task.delay(1.3, function() if tool.Parent then tool:SetAttribute("Busy", nil) end end)
		if h and h:IsA("BasePart") then
			local set = eatenOf(tool)
			set[1] = true
			setEaten(tool, set)
			task.delay(0.45, function() if h.Parent then applyEaten(h, set) end end)
			local snd = Instance.new("Sound")
			snd.SoundId = "rbxassetid://" .. tostring(SOUND_WRAPPER)
			snd.Volume = 0.9
			snd.RollOffMaxDistance = 40
			snd.Parent = h
			task.delay(0.3, function() if snd.Parent then snd:Play() end end)
			-- (D-1080, user 2026-11-09: "삼각김밥 처음에 포장 뜯을 때 소리 1.5초만 쓰기")
			task.delay(1.8, function() if snd.Parent then snd:Stop() snd:Destroy() end end)
		end
		tool:SetAttribute("Bites", ((tool:GetAttribute("Bites") :: number?) or bitesOf(item)) - 1)
		tool.ToolTip = "클릭(터치)해서 먹기"
		return
	end
	-- (D-1129) 친구바: the first tap splits it, the other half into the left hand for a friend
	if tool:GetAttribute("Pair") then
		FriendBar.split(tool, item)
		return
	end
	local character = tool.Parent
	if not character or not character:IsA("Model") then return end
	tool:SetAttribute("Busy", true)
	local original = tool.Grip
	-- R15: the arm bends and the hand brings it up (EatMotionController, IK on
	-- every client, user 2026-10-27: the food floated up with a straight arm);
	-- R6 has no IK chain, there the item still moves up in the hand
	local ik = character:FindFirstChild("RightUpperArm") ~= nil
	local handle = tool:FindFirstChild("Handle")
	-- 컵라면 (user 2026-10-27: only the chopsticks go up): the cup moves to the
	-- left hand for the bite, the right hand takes the chopsticks with noodles
	local restore: (() -> ())? = nil
	local leftGrip = character:FindFirstChild("LeftHand") and (character :: any).LeftHand:FindFirstChild("LeftGripAttachment") :: Attachment?
	local ramenDrink = tool:GetAttribute("Ramen") ~= nil and tool:GetAttribute("Bites") == 1
	if tool:GetAttribute("Ramen") and handle and handle:IsA("BasePart") then
		-- (D-1063) the user's cup ramen: the cup is already in the left hand
		-- (RamenCup.hold), the strands go down into it; the last tap drinks the broth
		if ramenDrink then
			restore = RamenCup.drinkStart(tool, handle)
		else
			local cup = RamenCup.leftCup(tool)
			if not cup then
				RamenCup.hold(tool, true)
				cup = RamenCup.leftCup(tool)
			end
			if cup then restore = RamenCup.strands(handle, cup) end
		end
		task.wait(0.1) -- (the sticks' pose reaches the clients before the arm lifts them)
	elseif item.kind == "noodle" and ik and leftGrip and handle and handle:IsA("BasePart") then
		local cup = handle:Clone()
		for _, d in ipairs(cup:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				if d.Name == "Chopsticks" then d:Destroy() end
			elseif d:IsA("Sound") then d:Destroy() end
		end
		cup.Anchored = false
		cup.CFrame = leftGrip.WorldCFrame * tool.Grip:Inverse()
		local w = Instance.new("WeldConstraint")
		w.Part0 = leftGrip.Parent :: BasePart
		w.Part1 = cup
		w.Parent = cup
		cup.Name = "CupInLeftHand"
		cup.Parent = character
		local hidden = {}
		for _, d in ipairs(handle:GetChildren()) do
			if d:IsA("BasePart") and d.Name ~= "Chopsticks" and d.Transparency < 1 then
				hidden[d] = d.Transparency
				d.Transparency = 1
				for _, t in ipairs(d:GetChildren()) do if t:IsA("Decal") or t:IsA("Texture") then hidden[t] = t.Transparency t.Transparency = 1 end end
			end
		end
		-- a bundle of noodles at the chopstick tips
		-- (D-1053: the user's cup ramen: red noodle strands from the cup up to the
		-- sticks instead, stretching to the mouth, RamenCup.strands)
		local bundle: BasePart? = nil
		local strandsDone: (() -> ())? = nil
		if tool:GetAttribute("Ramen") then
			strandsDone = RamenCup.strands(handle, cup)
			task.wait(0.1) -- (the sticks' new pose reaches the clients before the arm lifts them)
		else
			bundle = part("NoodleBite", Vector3.new(0.16, 0.3, 0.12), Color3.fromRGB(245, 215, 130))
			local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = bundle :: BasePart
			attach(handle, bundle :: BasePart, CFrame.new(0.3, 0.05, 0))
		end
		restore = function()
			cup:Destroy()
			if bundle then bundle:Destroy() end
			if strandsDone then strandsDone() end
			for d, t in pairs(hidden) do (d :: any).Transparency = t end
		end
	elseif (item :: any).stickOut and ik and leftGrip and handle and handle:IsA("BasePart") then
		-- (D-1131) 빼쭉이: the box into the left hand, one stick in the right to the mouth
		restore = SnackHands.pullStick(tool, handle, character, leftGrip)
		task.wait(0.1) -- (the new grip reaches the clients before the arm lifts it)
	end
	character:SetAttribute("Eating", true)
	local up = if ik then nil else mouthGrip(character, if item.kind == "cone" or item.kind == "bar" then -0.2 else 0)
	if up then TweenService:Create(tool, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Grip = up }):Play() end
	local sound = handle and handle:FindFirstChild("Sip") :: Sound?
	-- (D-1063) the cup ramen: its noodle sound from 1 s in; the broth plays its own
	if sound and tool:GetAttribute("Ramen") then
		if ramenDrink then
			sound = nil
		else
			sound.SoundId = "rbxassetid://" .. tostring(RamenCup.EatSound)
			sound.TimePosition = RamenCup.EatFrom
		end
	end
	if sound and item.kind == "bowl" then
		local id = gukbapClip()
		if id then
			sound.SoundId = "rbxassetid://" .. id
			sound.TimePosition = GUKBAP_FROM
		end
	end
	if sound then sound:Play() end
	local total = bitesOf(item)
	-- (D-1161, user 2026-11-10: "음식 한 입 먹을 때마다 조각 사라지는 거 클릭하자마자 사라져야
	-- 함. 먹는 소리 다 들리고 나중에 사라짐 현재는") the bite is cut as the food reaches
	-- the mouth (the arm takes 0.28 s up), not after the sound (1.7 s). Things whose
	-- parts are swapped for the bite (컵라면, 빼쭉이) still wait for their restore.
	local early = restore == nil
	local cut = false
	local function cutBite(): number
		cut = true
		local left = ((tool:GetAttribute("Bites") :: number?) or total) - 1
		tool:SetAttribute("Bites", left)
		return left
	end
	local left = 0
	if early then
		task.wait(0.25)
		left = cutBite()
		visualCut(tool, handle, left, total)
		task.wait(1.15)
	else
		task.wait(1.4)
	end
	-- (some eating clips run longer than a bite; the 국밥 clips are short, let them end)
	if sound and item.kind ~= "bowl" then sound:Stop() end
	character:SetAttribute("Eating", nil)
	if restore then restore() end -- (before the bite is cut below)
	if up and tool.Parent then TweenService:Create(tool, TweenInfo.new(0.3), { Grip = original }):Play() end
	task.wait(0.3)
	if not cut then
		left = cutBite()
		visualCut(tool, handle, left, total)
	end
	-- (D-1103) this bite's part of the food's XP, to the one eating
	local eater = Players:GetPlayerFromCharacter(character)
	if eater and economy then economy.EatXP(eater, tool, left + 1) end
	if eater then Analytics.interact(eater, if item.kind == "cup" or item.kind == "bottle" then "Drink" else "Eat") end -- (D-1124)
	tool:SetAttribute("Busy", nil)
	if left <= 0 then
		if finishedHandler and item.kind == "cup" and tool.Parent and tool.Parent:IsA("Model") then
			task.spawn(finishedHandler, tool.Parent :: Model, item)
		end
		tool:Destroy()
	end
end

-- (D-1161) the bite's piece goes: the next Bite part, a smaller store mesh, or
-- the food cut down from the top / front
function visualCut(tool: Tool, handle: Instance?, left: number, total: number)
	local lo, hi = tool:GetAttribute("EatLo"), tool:GetAttribute("EatHi")
	local zlo, zhi = tool:GetAttribute("EatZLo"), tool:GetAttribute("EatZHi")
	if handle and handle:IsA("BasePart") and tool:GetAttribute("Ramen") then
		RamenCup.afterBite(tool, handle, left, total) -- (D-1053: the broth sinks a step)
	elseif handle and handle:IsA("BasePart") and tool:GetAttribute("EatMode") == "Bites" then
		-- (D-1036: the next piece goes; D-1037: the lowest one still there)
		local set = eatenOf(tool)
		local n = nextBite(handle, set, nil)
		if n then set[n] = true end
		setEaten(tool, set)
		applyEaten(handle, set)
	elseif handle and handle:IsA("BasePart") and tool:GetAttribute("EatMode") == "Scale" and left > 0 then
		-- a store mesh cannot be cut: the whole thing gets smaller each bite
		local k = 0.45 + 0.55 * left / total
		for _, piece in ipairs(handle:GetChildren()) do
			local weld = piece:IsA("BasePart") and piece:FindFirstChildOfClass("Weld")
			local size, c0 = piece:GetAttribute("EatSize0"), piece:GetAttribute("EatC00")
			if weld and piece:IsA("BasePart") and typeof(size) == "Vector3" and typeof(c0) == "CFrame" then
				piece.Size = size * k
				weld.C0 = CFrame.new(c0.Position * k) * c0.Rotation
			end
		end
	elseif handle and handle:IsA("BasePart") and tool:GetAttribute("EatAlong") == "Z" and typeof(zlo) == "number" and typeof(zhi) == "number" and left > 0 then
		eatFromFront(handle, zlo, zhi, left, total)
	elseif handle and handle:IsA("BasePart") and typeof(lo) == "number" and typeof(hi) == "number" and left > 0 then
		eatDownTo(handle, lo, hi, left, total)
	end
end

-- 수육 slice picture (docs/04_ART/textures/suyuk_slice.png, 2026-10-27)
local SUYUK_TEX = "rbxassetid://119654785802449"

-- the cake slice mesh (whole cakes, D-318; see placePlate)
local CAKE_R = 0.95 -- studs (it fits the cafe's small round tables)
local function sliceMesh(): MeshPart?
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local m = art and art:FindFirstChild("CakeSlice")
	return if m and m:IsA("MeshPart") then m else nil
end
-- the user's own cake models (user 2026-10-30, STL → docs/04_ART/models/
-- <Name>Sliced.gltf, tools/art/CakeCut.cs): a whole cake cut in six, each
-- slice "Slice1".."Slice6" a MeshPart closed by its cut faces (the layers
-- inside), the board "Board" apart. Imported into ServerStorage.ArtAssets.Foods.
-- (D-781: the tiramisu, basque and strawberry cream cakes from the user's
-- Meshy STL files, the same way)
local CAKE_MODELS = {
	vintage = "VintageLetteringCakeSliced",
	tiramisu = "TiramisuCakeSliced",
	basque = "BasqueCheesecakeSliced",
	strawberry = "StrawberryCreamCakeSliced",
	-- (D-1034, user 2026-11-09) the user's 수육 plate (Blender → Gukbap_Suyuk.glb):
	-- "Plate" stays, "Bite1".."Bite14" go one per tap in that order
	suyuk = "GukbapSuyuk",
}
-- the pieces of a model plate are "Slice<n>" (cakes) or "Bite<n>" (D-1034)
local function pieceWordOf(m: Instance): string?
	if m:FindFirstChild("Slice1", true) then return "Slice" end
	if m:FindFirstChild("Bite1", true) then return "Bite" end
	return nil
end
local function cakeModel(key: string?): Model?
	local name = key and CAKE_MODELS[key]
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local foods = art and art:FindFirstChild("Foods")
	local m = name and foods and foods:FindFirstChild(name)
	return if m and m:IsA("Model") and pieceWordOf(m) then m else nil
end
-- (D-1034) how wide the 수육 model plate sits on a table (studs)
-- (D-1079, user 2026-11-09: "수육도 1.5배 키우기") 2.8 → 4.2
local SUYUK_PLATE_W = 4.2
-- a copy `width` studs across (the board's width), no collisions
local function cakeCopy(src: Model, width: number): Model
	local m = src:Clone()
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * width / math.max(size.X, size.Z))
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
		end
	end
	return m
end
-- weld every part of `m` to `handle`, keeping where they are now
local function weldAll(handle: BasePart, m: Instance)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local offset = handle.CFrame:ToObjectSpace(d.CFrame)
			d.Anchored = false
			d.Parent = handle
			local weld = Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = d
			weld.C0 = offset
			weld.Parent = d
		end
	end
end

-- (D-950, user 2026-11-07: "음식 사이즈 1.5배 키우기") every food and drink in
-- the hand (and so on a table) is built, then made this much bigger round its
-- handle: part sizes, where the pieces sit, welds, attachments, file meshes
-- and the grip, before the bite bands are measured (markEdible)
local FOOD_SCALE = 1.5
-- how far round its middle a food reaches over a table top (studs)
local function footprintOf(handle: BasePart): number
	local r = math.max(handle.Size.X, handle.Size.Z) / 2
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			-- (a tool not yet in the world has its pieces only on their welds:
			-- their CFrames are not kept up, so the weld offset is used)
			local offset: CFrame? = nil
			for _, j in ipairs(d:GetChildren()) do
				if j:IsA("JointInstance") and j.Part0 == handle and j.Part1 == d then offset = j.C0 * j.C1:Inverse() end
			end
			local p = if offset then offset.Position else handle.CFrame:PointToObjectSpace(d.Position)
			r = math.max(r, Vector2.new(p.X, p.Z).Magnitude + math.max(d.Size.X, d.Size.Z) / 2)
		end
	end
	return math.min(r, 3)
end
local function scaleTool(tool: Tool, handle: BasePart, k: number)
	local function grow(cf: CFrame): CFrame return CFrame.new(cf.Position * k) * cf.Rotation end
	local constraints = {}
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("WeldConstraint") and d.Enabled then d.Enabled = false table.insert(constraints, d) end
	end
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = handle.CFrame * grow(handle.CFrame:ToObjectSpace(d.CFrame))
		end
	end
	for _, d in ipairs({ handle, unpack(handle:GetDescendants()) }) do
		if d:IsA("BasePart") then
			d.Size *= k
			-- (FoodShapes keeps these for its "Scale" bites: grown too, or the
			-- first bite put the piece back to its old size)
			local s0, c00 = d:GetAttribute("EatSize0"), d:GetAttribute("EatC00")
			if typeof(s0) == "Vector3" then d:SetAttribute("EatSize0", s0 * k) end
			if typeof(c00) == "CFrame" then d:SetAttribute("EatC00", grow(c00)) end
		elseif d:IsA("JointInstance") then
			d.C0, d.C1 = grow(d.C0), grow(d.C1)
		elseif d:IsA("Attachment") then
			d.Position *= k
		elseif d:IsA("SpecialMesh") and d.MeshType == Enum.MeshType.FileMesh then
			d.Scale *= k
			d.Offset *= k
		elseif d:IsA("Texture") then
			d.StudsPerTileU *= k
			d.StudsPerTileV *= k
		end
	end
	for _, c in ipairs(constraints) do c.Enabled = true end
	tool.Grip = grow(tool.Grip)
end

-- The hand-held model of each kind of item. The main edible piece is "Fill"
-- (it shrinks with every bite).
local function makeTool(item: SnackConfig.Item, nameOverride: string?): Tool
	local tool = Instance.new("Tool")
	tool.Name = nameOverride or item.name
	local drink = item.kind == "cup" or item.kind == "bottle" or item.kind == "parfait"
	tool.ToolTip = "클릭(터치)해서 " .. (if drink then "마시기" else "먹기")
	tool.CanBeDropped = false
	tool:SetAttribute("Snack", item.key)
	tool:SetAttribute("Bites", bitesOf(item))
	local kind = item.kind
	local handle: Part
	local custom, customGrip, eatMode = FoodShapes.build(item)
	if custom then
		-- detailed models of the cafe foods and the OH24 goods (FoodShapes, 2026-10-27)
		handle = custom
		handle.Parent = tool
		tool.Grip = customGrip or CFrame.new()
		if eatMode == "Z" then tool:SetAttribute("EatAlong", "Z")
		elseif eatMode == "Scale" then tool:SetAttribute("EatMode", "Scale")
		elseif eatMode == "Bites" then tool:SetAttribute("EatMode", "Bites") -- (D-1036: the user's 국밥 models)
		elseif eatMode == "Ramen" then RamenCup.setup(tool, handle) end -- (D-1053: lid, hot water, chopsticks)
		-- (D-1152) a glass with a straw is drunk through it (EatMotionController)
		if eatMode == "Level" and handle:FindFirstChild("Straw") then tool:SetAttribute("EatStraw", true) end
		-- (D-1065) a wrapped 삼각김밥 model: the first tap tears the wrapper off
		if item.wrapped and eatMode == "Bites" then
			tool:SetAttribute("Wrapped", true)
			tool.ToolTip = "클릭(터치)해서 포장 뜯기"
		end
		-- (D-1129) 친구바: the first tap splits it in two (FriendBar)
		if (item :: any).pair and eatMode == "Bites" then
			tool:SetAttribute("Pair", true)
			tool.ToolTip = "클릭(터치)해서 반으로 나누기"
			-- (D-1160, user 2026-11-10: "친구바 처음 클릭했을 때 나는 소리 타이밍 느림 누르자마자
			-- 들리게") the split sound waits in the bar from the start, loaded on every client
			local split = Instance.new("Sound")
			split.Name = "SplitSound"
			split.SoundId = "rbxassetid://" .. tostring(FriendBar.SplitSound)
			split.Volume = 1
			split.RollOffMaxDistance = 40
			split.Parent = handle
		end
	elseif kind == "cone" then
		-- waffle cone (pointing down) with a scoop on top
		handle = part("Handle", Vector3.new(0.45, 0.9, 0.45), Color3.fromRGB(215, 160, 90))
		handle.Parent = tool
		attach(handle, part("Fill", Vector3.new(0.75, 0.75, 0.75), item.color, nil, Enum.PartType.Ball), CFrame.new(0, 0.62, 0))
		if item.topping then
			for k = 0, 2 do
				attach(handle, part("Chip", Vector3.new(0.12, 0.12, 0.12), item.topping), CFrame.new(math.cos(k * 2.1) * 0.3, 0.8, math.sin(k * 2.1) * 0.3))
			end
		end
		tool.Grip = CFrame.new(0, -0.1, 0)
	elseif kind == "bar" then
		-- ice cream bar on a wooden stick, a chocolate dip on top
		handle = part("Handle", Vector3.new(0.12, 0.6, 0.06), Color3.fromRGB(225, 195, 140), Enum.Material.Wood)
		handle.Parent = tool
		attach(handle, part("Fill", Vector3.new(0.38, 0.7, 0.2), item.color), CFrame.new(0, 0.6, 0))
		if item.topping then attach(handle, part("Dip", Vector3.new(0.4, 0.22, 0.22), item.topping), CFrame.new(0, 0.87, 0)) end
		tool.Grip = CFrame.new(0, -0.15, 0)
	elseif kind == "bread" then
		handle = part("Handle", Vector3.new(0.5, 0.3, 0.8), item.color)
		handle.Transparency = 1
		handle.Parent = tool
		attach(handle, blob("Fill", Vector3.new(0.75, 0.42, 1.0), item.color), CFrame.new(0, 0.05, 0))
		if item.topping then attach(handle, blob("Cream", Vector3.new(0.5, 0.18, 0.7), item.topping), CFrame.new(0, 0.22, 0)) end
		for _, name in ipairs({ "Fill", "Cream" }) do
			local piece = handle:FindFirstChild(name)
			if piece then piece:SetAttribute("EatShrink", true) end
		end
		tool.Grip = CFrame.new(0, 0, 0)
	elseif kind == "cake" then
		-- a slice on a little paper plate: the slice mesh with the cake's
		-- texture when this piece came off a whole cake, else simple blocks
		handle = part("Handle", Vector3.new(0.9, 0.05, 0.9), Color3.fromRGB(250, 250, 250))
		handle.Parent = tool
		local tex = (item :: any).sliceTexture
		local src = if tex then sliceMesh() else nil
		-- a slice of one of the user's cake models: that very slice, its cut faces showing
		local model = cakeModel((item :: any).cakeModel)
		local mine = model and model:FindFirstChild((item :: any).sliceName or "Slice1", true)
		if mine and mine:IsA("BasePart") then
			local whole = cakeCopy(model, 2.0)
			local p = whole:FindFirstChild(mine.Name, true) :: BasePart
			p.Name = "Fill"
			-- (stood on the plate: its bottom on the handle's top, its middle over the plate)
			p.CFrame = handle.CFrame * CFrame.new(0, 0.03 + p.Size.Y / 2, 0) * p.CFrame.Rotation
			local offset = handle.CFrame:ToObjectSpace(p.CFrame)
			p.Anchored = false
			p.Parent = handle
			local weld = Instance.new("Weld")
			weld.Part0, weld.Part1, weld.C0 = handle, p, offset
			weld.Parent = p
			whole:Destroy()
		elseif src then
			local p = src:Clone()
			p.Name = "Fill"
			p.Size = src.MeshSize * (0.85 / src.MeshSize.X)
			p.TextureID = tex
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.Anchored = false
			attach(handle, p, CFrame.new(0, p.Size.Y / 2 + 0.03, 0) * CFrame.Angles(0, math.rad(90), 0))
		else
			attach(handle, part("Fill", Vector3.new(0.45, 0.45, 0.7), item.color), CFrame.new(0, 0.25, 0))
			if item.topping then attach(handle, part("Top", Vector3.new(0.47, 0.08, 0.72), item.topping), CFrame.new(0, 0.5, 0)) end
		end
		tool.Grip = CFrame.new(0, -0.05, 0)
	elseif kind == "bowl" or kind == "ricebowl" then
		-- a 뚝배기 (or a steel rice bowl) with a spoon. Round items hang from an
		-- invisible block handle (held upright like the cups); the cylinders
		-- are turned up at attach time
		local stone = kind == "bowl"
		handle = part("Handle", Vector3.new(0.5, 0.4, 0.5), Color3.new(1, 1, 1))
		handle.Transparency = 1
		handle.Parent = tool
		attach(handle, cyl("Bowl", if stone then 0.85 else 0.65, if stone then 0.42 else 0.38, if stone then Color3.fromRGB(70, 46, 38) else Color3.fromRGB(205, 208, 212), if stone then Enum.Material.Slate else Enum.Material.Metal), UPRIGHT)
		attach(handle, cyl("Fill", if stone then 0.72 else 0.55, 0.06, item.color), CFrame.new(0, 0.2, 0) * UPRIGHT)
		attach(handle, part("Spoon", Vector3.new(0.07, 0.75, 0.05), Color3.fromRGB(215, 218, 222), Enum.Material.Metal), CFrame.new(0.12, 0.38, 0) * CFrame.Angles(0, 0, math.rad(-20)))
		tool.Grip = CFrame.new(0, -0.1, 0)
	elseif kind == "noodle" then
		handle = part("Handle", Vector3.new(0.5, 0.5, 0.5), Color3.new(1, 1, 1))
		handle.Transparency = 1
		handle.Parent = tool
		attach(handle, cyl("Cup", 0.75, 0.75, Color3.fromRGB(250, 248, 240)), UPRIGHT)
		attach(handle, cyl("Band", 0.77, 0.3, item.color), UPRIGHT)
		attach(handle, cyl("Fill", 0.62, 0.05, Color3.fromRGB(230, 120, 60)), CFrame.new(0, 0.36, 0) * UPRIGHT)
		attach(handle, part("Chopsticks", Vector3.new(0.05, 0.9, 0.05), Color3.fromRGB(200, 170, 120), Enum.Material.Wood), CFrame.new(0.1, 0.65, 0) * CFrame.Angles(0, 0, math.rad(-25)))
		tool.Grip = CFrame.new(0, -0.15, 0)
	elseif kind == "bottle" then
		handle = part("Handle", Vector3.new(0.4, 0.8, 0.4), Color3.new(1, 1, 1))
		handle.Transparency = 1
		handle.Parent = tool
		local glass = cyl("Glass", 0.42, 0.9, Color3.fromRGB(240, 245, 250), Enum.Material.Glass)
		glass.Transparency = 0.3
		attach(handle, glass, UPRIGHT)
		attach(handle, cyl("Fill", 0.36, 0.7, item.color), CFrame.new(0, -0.05, 0) * UPRIGHT)
		attach(handle, cyl("Cap", 0.25, 0.12, Color3.fromRGB(250, 250, 250)), CFrame.new(0, 0.5, 0) * UPRIGHT)
		tool.Grip = CFrame.new(0, -0.15, 0)
	elseif kind == "bag" then
		handle = part("Handle", Vector3.new(0.75, 0.95, 0.25), item.color)
		handle.Parent = tool
		attach(handle, part("Fill", Vector3.new(0.5, 0.35, 0.27), Color3.fromRGB(250, 250, 250)), CFrame.new(0, 0.05, 0))
		tool.Grip = CFrame.new(0, -0.2, 0)
	elseif kind == "rice" then
		-- 삼각김밥: a white triangle with a strip of laver
		handle = part("Handle", Vector3.new(0.2, 0.7, 0.75), item.color)
		handle.Transparency = 1
		handle.Parent = tool
		local w = Instance.new("WedgePart")
		w.Name = "Fill"
		w.Size = Vector3.new(0.25, 0.7, 0.4)
		w.Color = item.color
		w.CanCollide = false w.CanQuery = false w.CanTouch = false w.Massless = true
		attach(handle, w, CFrame.new(0, 0, -0.19))
		local w2 = w:Clone()
		attach(handle, w2, CFrame.new(0, 0, 0.19) * CFrame.Angles(0, math.rad(180), 0))
		attach(handle, part("Laver", Vector3.new(0.27, 0.3, 0.3), Color3.fromRGB(30, 40, 30)), CFrame.new(0, -0.22, 0))
		tool.Grip = CFrame.new(0, -0.1, 0)
	elseif kind == "parfait" then
		-- a tall glass of layers with cream and a strawberry on top
		handle = part("Handle", Vector3.new(0.5, 0.6, 0.5), Color3.new(1, 1, 1))
		handle.Transparency = 1
		handle.Parent = tool
		local glass = cyl("Glass", 0.55, 1.3, Color3.fromRGB(245, 250, 255), Enum.Material.Glass)
		glass.Transparency = 0.45
		attach(handle, glass, UPRIGHT)
		attach(handle, cyl("Fill", 0.48, 0.5, item.color), CFrame.new(0, -0.3, 0) * UPRIGHT)
		attach(handle, cyl("Layer", 0.48, 0.35, item.topping or Color3.new(1, 1, 1)), CFrame.new(0, 0.12, 0) * UPRIGHT)
		attach(handle, part("Cream", Vector3.new(0.55, 0.55, 0.55), Color3.fromRGB(252, 250, 246), nil, Enum.PartType.Ball), CFrame.new(0, 0.7, 0))
		attach(handle, part("Berry", Vector3.new(0.28, 0.28, 0.28), Color3.fromRGB(220, 30, 50), nil, Enum.PartType.Ball), CFrame.new(0, 1.0, 0))
		tool.Grip = CFrame.new(0, -0.2, 0)
	elseif kind == "plate" then
		-- one piece of 수육 on chopsticks
		-- (D-952, user 2026-11-07: "젓가락 더 얇은 막대기로. 색은 회색") a thin grey
		-- metal stick (0.05 wood before; 0.03 after the 1.5× of D-950)
		handle = part("Handle", Vector3.new(0.02, 0.02, 1.0), Color3.fromRGB(150, 152, 158), Enum.Material.Metal)
		handle.Parent = tool
		-- (D-1034, user 2026-11-09: "1~13은 먹을 때 젓가락에 3d에 있는 수육 오브젝트
		-- 들고 있게 하고 마지막 14 먹을 때는 14오브젝트 들고 먹게 해") a piece taken
		-- off the model plate is that very piece on the sticks, the size it has on
		-- the plate (the tool is made FOOD_SCALE bigger afterwards, so 1 / FOOD_SCALE here)
		local model = cakeModel((item :: any).cakeModel)
		local mine = model and model:FindFirstChild((item :: any).sliceName or "Bite1", true)
		if mine and mine:IsA("BasePart") then
			local whole = cakeCopy(model, SUYUK_PLATE_W / FOOD_SCALE)
			local p = whole:FindFirstChild(mine.Name, true) :: BasePart
			p.Name = "Fill"
			-- its middle at the sticks' far end, lying as it lay on the plate
			p.CFrame = handle.CFrame * CFrame.new(0, 0.03 + p.Size.Y / 2, -0.45) * p.CFrame.Rotation
			local offset = handle.CFrame:ToObjectSpace(p.CFrame)
			p.Anchored = false
			p.Parent = handle
			local weld = Instance.new("Weld")
			weld.Part0, weld.Part1, weld.C0 = handle, p, offset
			weld.Parent = p
			whole:Destroy()
		else
			local slice = part("Fill", Vector3.new(0.5, 0.07, 0.32), item.color)
			local stex = Instance.new("Texture")
			stex.Texture = SUYUK_TEX
			stex.Face = Enum.NormalId.Top
			stex.StudsPerTileU = 0.5
			stex.StudsPerTileV = 0.32
			stex.Parent = slice
			attach(handle, slice, CFrame.new(0, 0.05, -0.45))
		end
		-- (D-956, user 2026-11-07: "수육 먹을 때 모션 확인하고 수정해") held up from
		-- the fist like the 국밥 spoon (the sticks' far end at the grip's +Y, 0.3 of
		-- them below the hand's middle), so the eating motion lifts them the
		-- spoon's way: pointing ahead out of the hand the wrist had to turn round
		-- to aim them at the mouth and the slice ended up in front of the eyes;
		-- the slice's end goes to the lips (EatMotionController, EatPart)
		tool.Grip = (CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(90), 0, 0)):Inverse()
		tool:SetAttribute("EatPart", "Fill")
	else
		-- "cup": glass with a straw (the original drink)
		handle = part("Handle", Vector3.new(0.6, 0.85, 0.6), Color3.fromRGB(250, 250, 255), Enum.Material.Glass)
		handle.Transparency = 0.35
		handle.Parent = tool
		attach(handle, part("Fill", Vector3.new(0.5, 0.65, 0.5), item.color), CFrame.new(0, -0.05, 0))
		if item.topping then attach(handle, part("Topping", Vector3.new(0.52, 0.12, 0.52), item.topping), CFrame.new(0, 0.32, 0)) end
		attach(handle, part("Straw", Vector3.new(0.08, 0.7, 0.08), Color3.fromRGB(255, 255, 255)), CFrame.new(0.1, 0.5, 0) * CFrame.Angles(0, 0, math.rad(-10)))
		tool.Grip = CFrame.new(0, -0.2, 0)
	end
	-- the sound of a bite for this kind of food (drinks gulp)
	local sip = Instance.new("Sound")
	sip.Name = "Sip"
	sip.SoundId = "rbxassetid://" .. tostring(SIP_SOUND[item.key] or (if COFFEE[item.key] then COFFEE_SIP else EAT_SOUND[kind] or ClubConfig.GulpSoundId)) -- (D-1158)
	-- coffee twice as loud, bagel and 소금빵 half (user 2026-10-30)
	setVolume(sip, if COFFEE[item.key] then 0.9 elseif QUIET[item.key] then 0.35 else LOUD[item.key] or 0.7)
	sip.RollOffMaxDistance = 40
	sip.Parent = handle
	-- (D-1079, user 2026-11-09: "국밥 크기 1.5배 키우기") the three 국밥 once more 1.5×
	local k = FOOD_SCALE * (if kind == "bowl" then 1.5 else 1)
	scaleTool(tool, handle, k) -- (D-950)
	if tool:GetAttribute("Ramen") then RamenCup.scaled(handle, k) end
	markEdible(tool, handle)
	-- (D-1142) the americanos (eatMode "Level"): parts with DropStuds sink by it over
	-- the sips; a cup whose only drink part is a flat surface gets its range from it
	if eatMode == "Level" then
		local top, drop = nil :: number?, 0
		for _, p in ipairs(handle:GetChildren()) do
			local d = p:GetAttribute("DropStuds")
			if typeof(d) == "number" and p:IsA("BasePart") then
				p:SetAttribute("EatDrop", d * k)
				local y1 = p:GetAttribute("EatY1")
				if typeof(y1) == "number" then top = math.max(top or -math.huge, y1) drop = math.max(drop, d * k) end
			end
		end
		local lo, hi = tool:GetAttribute("EatLo"), tool:GetAttribute("EatHi")
		if top and (typeof(lo) ~= "number" or typeof(hi) ~= "number" or (hi :: number) - (lo :: number) < 0.05) then
			tool:SetAttribute("EatLo", top - drop)
			tool:SetAttribute("EatHi", top)
		end
	end
	-- soup and noodles: the surface sinks a third of the bowl per bite
	local surface = (kind == "bowl" or kind == "ricebowl" or kind == "noodle") and handle:FindFirstChild("Fill")
	if surface then surface:SetAttribute("EatDrop", (if kind == "noodle" then 0.5 else 0.3) * k) end
	-- (D-1257) cups and bottles are drunk from the rim (EatMotionController); a
	-- glass with a straw still uses the straw
	if kind == "cup" or kind == "bottle" then tool:SetAttribute("Drink", true) end
	-- (D-1254, user 2026-11-10: "국밥에서 김 올라오게 하기") steam from the top of the
	-- 국밥 (the cup ramen's look, a little softer); the copy put on a table carries it
	if kind == "bowl" then
		local top = tool:GetAttribute("EatHi")
		local at = Instance.new("Attachment")
		at.Name = "SteamPoint"
		at.Position = Vector3.new(0, if typeof(top) == "number" then top else 0.3, 0)
		at.Parent = handle
		local e = Instance.new("ParticleEmitter")
		e.Name = "Steam"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.new(1, 1, 1))
		e.LightEmission = 0.15
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.45), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) })
		local w = handle.Size.X
		for _, d in ipairs(handle:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.95 then w = math.max(w, d.Size.X, d.Size.Z) end
		end
		local size = math.clamp(w * 0.4, 0.3, 1.2)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.3), NumberSequenceKeypoint.new(1, size) })
		e.Lifetime = NumberRange.new(1.2, 2.0)
		e.Rate = 14
		e.Speed = NumberRange.new(0.5, 1.1)
		e.SpreadAngle = Vector2.new(15, 15)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, 0.4, 0)
		e.RotSpeed = NumberRange.new(-30, 30)
		e.Parent = at
	end
	-- (D-950) a click / tap is not a bite by itself any more: SnackController
	-- decides (over a food table it puts the food down there, elsewhere it
	-- calls tool:Activate(), the bite)
	tool.ManualActivationOnly = true
	-- (D-1053) the cup ramen's taps go through RamenCup (SnackController asks "Ramen")
	tool.Activated:Connect(function() if not tool:GetAttribute("Ramen") then bite(tool, item) end end)
	-- (D-950) how much of a table top it takes, for the silhouette and the
	-- overlap check (국밥 goes down as its tray set, 3.4 × 1.5 studs across)
	-- (D-1038, user 2026-11-09: "국밥 놓을 때 원 너무 크다. 국밥 크기에 맞춰"): the
	-- user's 국밥 model goes down alone (D-1037), so its own size; the tray size only
	-- for a store bowl that still goes down with the tray
	tool:SetAttribute("PlaceRadius", if kind == "bowl" and tool:GetAttribute("EatMode") ~= "Bites" then 3.4 * k / 2 else footprintOf(handle))
	return tool
end

local function giveTool(player: Player, tool: Tool): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		tool:Destroy()
		return false
	end
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	return true
end

local function nearShop(player: Player, shopKey: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end
	for _, shopPart in ipairs(CollectionService:GetTagged("SnackShop")) do
		if shopPart:IsA("BasePart") and shopPart:IsDescendantOf(workspace) and shopPart:GetAttribute("Shop") == shopKey then
			-- distance to the nearest point of the counter, not its centre (long counters)
			local p = shopPart.CFrame:PointToObjectSpace(root.Position)
			local h = shopPart.Size / 2
			local nearest = shopPart.CFrame:PointToWorldSpace(Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z)))
			if (nearest - root.Position).Magnitude <= SnackConfig.ShopDistance then return true end
		end
	end
	return false
end

--------------------------------------------------
-- Shared plates (cakes, 수육): on a table, a piece for everyone
--------------------------------------------------

local function nearestTable(player: Player): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local best, bestDistance = nil, SnackConfig.PlateDistance
	for _, tag in ipairs(TABLE_TAGS) do
		for _, t in ipairs(CollectionService:GetTagged(tag)) do
			-- (same floor only: the cafe's mezzanine tables are right overhead)
			if t:IsA("BasePart") and t:IsDescendantOf(workspace) and math.abs(t.Position.Y - root.Position.Y) < 6 then
				local d = (t.Position - root.Position).Magnitude
				if d < bestDistance and not t:FindFirstChild("SharedPlate") then best, bestDistance = t, d end
			end
		end
	end
	return best
end

-- Whole cakes (item.cake): 6 slices of the slice mesh with the cake's texture,
-- set round the centre; each slice carries its rim decoration, so taking one
-- leaves a gap that shows the layers (user photo 2026-10-26).


-- one slice MeshPart, radius r; its apex (the cake centre) at `centre`, pointing along angle a
local function cakeSlice(r: number, texture: string, centre: CFrame, a: number): MeshPart?
	local src = sliceMesh()
	if not src then return nil end
	local p = src:Clone()
	p.Name = "Piece"
	local s = r / src.MeshSize.X -- the mesh runs 0..1 along X (apex .. rim)
	p.Size = src.MeshSize * s
	p.TextureID = texture
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	-- (the imported mesh is mirrored in X: its apex is at +X, so the slice is
	-- turned half round to put the apex on the centre; checked in Play)
	p.CFrame = centre * CFrame.Angles(0, a, 0) * CFrame.new(p.Size.X / 2, p.Size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)
	return p
end

local function cakeDeco(cake: SnackConfig.Cake, slice: BasePart, centre: CFrame, a: number, r: number)
	if not cake.deco then return end
	local topY = slice.Size.Y
	local spot = centre * CFrame.Angles(0, a, 0) * CFrame.new(r * 0.78, topY, 0)
	local function ball(name: string, d: number, at: CFrame, color: Color3)
		local b = Instance.new("Part")
		b.Name = name
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(d, d, d)
		b.CFrame = at
		b.Color = color
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CastShadow = false
		b.Parent = slice
	end
	ball("Cream", 0.24, spot * CFrame.new(0, 0.08, 0), Color3.fromRGB(252, 248, 240))
	if cake.deco == "cherry" then
		ball("Cherry", 0.17, spot * CFrame.new(0, 0.24, 0), Color3.fromRGB(205, 25, 40))
		local stem = Instance.new("Part")
		stem.Name = "Stem"
		stem.Size = Vector3.new(0.025, 0.2, 0.025)
		stem.CFrame = spot * CFrame.new(0.03, 0.38, 0) * CFrame.Angles(0, 0, math.rad(-20))
		stem.Color = Color3.fromRGB(110, 60, 30)
		stem.Anchored = true
		stem.CanCollide = false
		stem.CanQuery = false
		stem.Parent = slice
	elseif cake.deco == "strawberry" then
		ball("Strawberry", 0.2, spot * CFrame.new(0, 0.22, 0), Color3.fromRGB(220, 30, 50))
	end
end

-- (D-952) a tap on a shared plate takes a piece (SnackController asks "TakePiece")
local sharedPlates: {[Model]: (Player, any) -> ()} = {}
local PLATE_RADIUS = 1.1 -- (the dish: 2.2 across)

local function placePlate(player: Player, tablePart: BasePart, item: SnackConfig.Item, spot: Vector3?, xp: number?)
	local servings = item.share or 6
	-- (the real top: round tables are turned cylinders, whose Size.Y is the
	-- diameter, so a cake floated above them, user 2026-10-27)
	local c, s = tablePart.CFrame, tablePart.Size
	local top = tablePart.Position + Vector3.new(0, math.abs(c.RightVector.Y) * s.X / 2 + math.abs(c.UpVector.Y) * s.Y / 2 + math.abs(c.LookVector.Y) * s.Z / 2, 0)
	-- (D-952, user 2026-11-07: "수육은 테이블에 놓는 자리 안 뜸") put down where
	-- the player pointed (SnackController's green silhouette), not in the middle
	if spot then top = Vector3.new(spot.X, top.Y, spot.Z) end
	local plate = Instance.new("Model")
	plate.Name = "SharedPlate"
	local cake = item.cake and SnackConfig.Cakes[item.cake]
	local texture = if cake then cake.textures[math.random(1, #cake.textures)] else nil
	if cake and texture and sliceMesh() then
		plate:SetAttribute("CakeTexture", texture)
	else
		cake = nil
	end
	local dish = Instance.new("Part")
	dish.Name = "Dish"
	dish.Shape = Enum.PartType.Cylinder
	dish.Size = Vector3.new(0.12, 2.2, 2.2)
	dish.CFrame = CFrame.new(top + Vector3.new(0, 0.06, 0)) * UPRIGHT
	dish.Color = if item.kind == "plate" then Color3.fromRGB(88, 82, 78) else Color3.fromRGB(250, 248, 244) -- (수육: dark stoneware, user photo)
	if item.kind == "plate" then dish.Material = Enum.Material.Slate end
	dish.Anchored = true
	dish.CanCollide = false
	dish.Parent = plate
	local pieces: {BasePart} = {}
	local lettering: BasePart? = nil
	-- (D-1034) the 수육 plate is a model too (its key in CAKE_MODELS)
	local modelKey = item.cake or (if item.kind == "plate" then item.key else nil)
	local model = cakeModel(modelKey)
	if model then
		-- the user's own cake (user 2026-10-30): the model on its board, six
		-- slices that go one by one, each leaving the cut faces of its
		-- neighbours to see
		local copy = cakeCopy(model, if item.kind == "plate" then SUYUK_PLATE_W else CAKE_R * 2 + 0.7)
		local cf, size = copy:GetBoundingBox()
		copy:PivotTo(copy:GetPivot() + (top + Vector3.new(0, size.Y / 2 + 0.01, 0) - cf.Position))
		for _, d in ipairs(copy:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
		copy.Name = "Cake"
		copy.Parent = plate
		dish.Transparency = 1 -- (the board is the plate; the dish stays for the prompt)
		local word = pieceWordOf(copy) or "Slice"
		for i = 1, servings do
			local s = copy:FindFirstChild(word .. i, true)
			if s and s:IsA("BasePart") then table.insert(pieces, s) end
		end
		-- (D-1034) a tap takes the last of the list: Bite1 first, Bite14 last
		if word == "Bite" then
			local reversed = {}
			for i = #pieces, 1, -1 do table.insert(reversed, pieces[i]) end
			pieces = reversed
		end
		cake = nil
		texture = nil
		plate:SetAttribute("CakeModel", modelKey)
	end
	if cake and texture then
		dish.Size = Vector3.new(0.12, CAKE_R * 2 + 0.4, CAKE_R * 2 + 0.4)
		local centre = CFrame.new(top + Vector3.new(0, 0.12, 0))
		for i = 1, servings do
			local a = (i - 1) / servings * math.pi * 2
			local slice = cakeSlice(CAKE_R, texture, centre, a)
			if slice then
				cakeDeco(cake, slice, centre, a, CAKE_R)
				slice.Parent = plate
				table.insert(pieces, slice)
			end
		end
		-- the lettering across the top while the cake is whole
		if cake.lettering then
			local h = (pieces[1] and pieces[1].Size.Y) or 0.69
			local board = Instance.new("Part")
			board.Name = "Lettering"
			board.Size = Vector3.new(CAKE_R * 1.3, 0.02, CAKE_R * 0.8)
			board.CFrame = centre * CFrame.new(0, h + 0.02, 0)
			board.Transparency = 1
			board.Anchored = true
			board.CanCollide = false
			board.CanQuery = false
			board.Parent = plate
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Top
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 120
			g.Parent = board
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(250, 215, 90)
			t.Text = cake.lettering[math.random(1, #cake.lettering)]
			local st = Instance.new("UIStroke")
			st.Color = Color3.fromRGB(200, 60, 90)
			st.Thickness = 3
			st.Parent = t
			t.Parent = g
			lettering = board
		end
	end
	for i = 1, (if cake or model then 0 else servings) do
		local a = (i - 1) / servings * math.pi * 2
		local p = Instance.new("Part")
		p.Name = "Piece"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		if item.kind == "cake" then
			-- wedges of a round cake: blocks round the centre, a ring of topping
			p.Size = Vector3.new(0.55, 0.6, 0.75)
			p.CFrame = CFrame.new(top + Vector3.new(0, 0.42, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.42)
		else
			-- (user 2026-10-27, photo) flat, uneven 수육 slices with the meat
			-- picture on top, fanned round a dark stoneware plate; one goes per bite
			-- two rows of three, each slice leaning on the one before like dominoes
			local r = Random.new(i * 7)
			local row, k = (i - 1) // 3, (i - 1) % 3
			p.Size = Vector3.new(0.62 + r:NextNumber(-0.06, 0.08), 0.06, 0.38 + r:NextNumber(-0.05, 0.05))
			p.CFrame = CFrame.new(top + Vector3.new((row - 0.5) * 0.85, 0.17 + k * 0.03, (k - 1) * 0.3))
				* CFrame.Angles(math.rad(-22 + r:NextNumber(-4, 4)), math.rad(r:NextNumber(-12, 12) + (row - 0.5) * 20), math.rad(r:NextNumber(-3, 3)))
			local tex = Instance.new("Texture")
			tex.Texture = SUYUK_TEX
			tex.Face = Enum.NormalId.Top
			tex.StudsPerTileU = p.Size.X
			tex.StudsPerTileV = p.Size.Z
			tex.Parent = p
		end
		p.Color = item.color
		p.Parent = plate
		if item.topping and item.kind ~= "plate" then
			local t = p:Clone()
			t.Name = "PieceTop"
			t.Size = Vector3.new(p.Size.X, 0.08, p.Size.Z * 0.9)
			t.CFrame = p.CFrame * CFrame.new(0, p.Size.Y / 2 + 0.04, 0)
			t.Color = item.topping
			t.Parent = p
		end
		table.insert(pieces, p)
	end
	plate:SetAttribute("Servings", servings)
	plate:SetAttribute("Owner", player.UserId)
	plate:SetAttribute("Radius", PLATE_RADIUS)
	-- (D-952, user 2026-11-07: "\"수육 한 접시, 닉네임, 남은 5점\" 이 텍스트 삭제",
	-- "수육도 한 점 먹기 삭제") no label and no "한 점 먹기" E button over the
	-- plate any more: a tap on the plate takes a piece (SnackController →
	-- "TakePiece"), so its parts answer raycasts
	for _, d in ipairs(plate:GetDescendants()) do
		if d:IsA("BasePart") then d.CanQuery = true end
	end
	local pieceWord = if item.kind == "cake" then "조각" else "점"
	local baseName = string.gsub(item.name, "%s*%(.*%)", "")
	local function refresh() end
	local function take(who: Player, chosen: any)
		if handsFull(who) then
			local notify = Remotes:FindFirstChild("SnackNotify") :: RemoteEvent?
			if notify then notify:FireClient(who, "Toast", string.format("손에 %d개까지 들 수 있어요. 먼저 드세요!", SnackConfig.MaxCarried)) end
			return
		end
		local left = (plate:GetAttribute("Servings") :: number) - 1
		if left < 0 then return end
		plate:SetAttribute("Servings", left)
		-- (D-1035, user 2026-11-09: "순서대로 말고 그릇 위에 있는 바이트 중에 마우스
		-- 올려서 선택되는 바이트를 먹게 해") the piece pointed at, when it is one of
		-- this plate's; otherwise the next in line
		local at = if typeof(chosen) == "Instance" then table.find(pieces, chosen) else nil
		local piece = if at then table.remove(pieces, at) else table.remove(pieces)
		local pieceName = piece and piece.Name
		if piece then piece:Destroy() end
		-- the lettering goes with the first cut
		if lettering then
			lettering:Destroy()
			lettering = nil
		end
		-- a piece is eaten in three bites like everything in the hand (a cake slice keeps the cake's texture)
		local pieceItem: any = table.clone(item)
		pieceItem.sliceTexture = plate:GetAttribute("CakeTexture")
		if plate:GetAttribute("CakeModel") then
			pieceItem.cakeModel = plate:GetAttribute("CakeModel")
			pieceItem.sliceName = pieceName
		end
		-- (a 수육 slice is one bite: six bites a plate, user 2026-10-27)
		-- (D-1146, user 2026-11-10: "케이크는 한 조각 떼면 그냥 한입에 먹기") a cake slice too
		if item.kind == "plate" or item.cake ~= nil then pieceItem.oneBite = true end
		local pieceTool = makeTool(pieceItem, baseName .. " 한 " .. pieceWord)
		-- (D-1103) the piece takes its part of the plate's XP (whoever eats it)
		if economy then economy.SplitXP(plate, pieceTool, left + 1) end
		-- (D-790) what it takes to make this piece again after a rejoin
		pieceTool:SetAttribute("Piece", true)
		if pieceItem.sliceTexture then pieceTool:SetAttribute("SliceTexture", pieceItem.sliceTexture) end
		if pieceItem.cakeModel then pieceTool:SetAttribute("SliceModel", pieceItem.cakeModel) end
		if pieceItem.sliceName then pieceTool:SetAttribute("SliceName", pieceItem.sliceName) end
		giveTool(who, pieceTool)
		if left <= 0 then plate:Destroy() else refresh() end
	end
	sharedPlates[plate] = take
	plate:SetAttribute("FoodXP", xp) -- (D-1103)
	plate.Destroying:Connect(function() sharedPlates[plate] = nil end)
	plate.Parent = tablePart
	Debris:AddItem(plate, SnackConfig.PlateSeconds)
end

-- (D-952) a tap on a shared plate: a piece for whoever tapped, if they are near
local function takePiece(player: Player, plate: any, piece: any): (boolean, string?)
	if typeof(plate) ~= "Instance" or not plate:IsA("Model") or not plate.Parent then return false, nil end
	local take = sharedPlates[plate]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not take or not root then return false, nil end
	if (root.Position - plate:GetBoundingBox().Position).Magnitude > 12 then return false, "접시 가까이 가 주세요." end
	-- (D-1035) the piece tapped / clicked (SnackController), checked by take
	take(player, if typeof(piece) == "Instance" and piece:IsDescendantOf(plate) then piece else nil)
	return true, nil
end

-- a plate held in the hand when no table was near: click next to a table to put it down
local function plateTool(player: Player, item: SnackConfig.Item): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = "테이블 가까이에서 클릭(터치)하면 테이블에 놓아요"
	tool.CanBeDropped = false
	tool:SetAttribute("Plate", item.key) -- (D-790: BagService)
	local handle = part("Handle", Vector3.new(1.4, 0.4, 1.4), item.color)
	handle.Parent = tool
	-- (D-1034) the 수육 model plate in the hands too
	local model = cakeModel(item.cake or (if item.kind == "plate" then item.key else nil))
	if model then
		-- (user 2026-10-30) the cake itself in the hands, not a box
		handle.Transparency = 1
		handle.Size = Vector3.new(1.4, 0.1, 1.4)
		local copy = cakeCopy(model, 1.7)
		local cf, size = copy:GetBoundingBox()
		copy:PivotTo(copy:GetPivot() + (handle.CFrame * CFrame.new(0, size.Y / 2 - 0.05, 0)).Position - cf.Position)
		weldAll(handle, copy)
		copy:Destroy()
		tool.Grip = CFrame.new(0, 0, -0.35)
	elseif item.kind == "plate" then
		-- (user 2026-10-30: in the hand it looks like the dish itself) a dark
		-- stoneware plate with the 수육 slices fanned on it
		handle.Transparency = 1
		attach(handle, cyl("Dish", 1.6, 0.1, Color3.fromRGB(88, 82, 78), Enum.Material.Slate), CFrame.new(0, -0.1, 0) * UPRIGHT)
		for i = 1, 6 do
			local r = Random.new(i * 7)
			local row, k = (i - 1) // 3, (i - 1) % 3
			local p = part("Slice", Vector3.new(0.46, 0.05, 0.28), item.color)
			local tex = Instance.new("Texture")
			tex.Texture = SUYUK_TEX
			tex.Face = Enum.NormalId.Top
			tex.StudsPerTileU, tex.StudsPerTileV = p.Size.X, p.Size.Z
			tex.Parent = p
			attach(handle, p, CFrame.new((row - 0.5) * 0.62, -0.02 + k * 0.025, (k - 1) * 0.22)
				* CFrame.Angles(math.rad(-22 + r:NextNumber(-4, 4)), math.rad((row - 0.5) * 20), 0))
		end
	end
	-- (D-952) put down like the other foods: SnackController shows the green /
	-- red silhouette and asks "PutDown" with the spot (no click-to-nearest-table)
	tool.ManualActivationOnly = true
	tool:SetAttribute("PlaceRadius", PLATE_RADIUS)
	tool.Activated:Connect(function()
		local t = nearestTable(player)
		if not t then
			local notify = Remotes:FindFirstChild("SnackNotify") :: RemoteEvent?
			if notify then notify:FireClient(player, "Toast", "가까운 테이블이 없어요. 테이블 옆에서 눌러 주세요.") end
			return
		end
		placePlate(player, t, item)
		tool:Destroy()
	end)
	return tool
end

-- the developer product of a Robux item was paid
local function grantProduct(player: Player, item: SnackConfig.Item, xp: number?): (boolean, string?)
	local notify = Remotes:FindFirstChild("SnackNotify") :: RemoteEvent?
	if item.share then
		-- 수육 goes to the backpack first; the buyer puts it on a table by
		-- clicking next to one (user 2026-10-30: "why is it on the table at once")
		local t = if item.kind == "plate" then nil else nearestTable(player)
		if t then
			placePlate(player, t, item, nil, xp)
			if notify then notify:FireClient(player, "Toast", "🍰 테이블에 놓았어요! 모두 한 조각씩 가져갈 수 있어요.") end
		else
			local backpack = player:FindFirstChildOfClass("Backpack")
			if not backpack then return false, nil end
			local held = plateTool(player, item)
			held:SetAttribute("FoodXP", xp) -- (D-1103: onto the plate when it goes down)
			held.Parent = backpack
			if notify then notify:FireClient(player, "Toast", item.name .. " 인벤토리에 넣었어요! 테이블 옆에서 클릭하면 접시를 놓아요.") end
		end
		return true, nil
	end
	-- a single serving (the parfait): it may go over the hand limit, it is paid
	local single = makeTool(item)
	single:SetAttribute("FoodXP", xp) -- (D-1103)
	if not giveTool(player, single) then return false, nil end
	if notify then notify:FireClient(player, "Toast", item.name .. " 나왔어요!") end
	return true, nil
end

--------------------------------------------------

-- (user 2026-10-27) the till beeps when an order is paid: a POS scanner beep
-- at the shop's counter, heard by the people around (docs/04_ART/SOUNDS.md 20)
local PAY_SOUND = "rbxassetid://9118777437" -- "Scanner Beeps 10" (Pro Sound Effects)
local function payBeep(player: Player, shopKey: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local best: BasePart? = nil
	for _, shopPart in ipairs(CollectionService:GetTagged("SnackShop")) do
		if shopPart:IsA("BasePart") and shopPart:IsDescendantOf(workspace) and shopPart:GetAttribute("Shop") == shopKey then
			if not best or (shopPart.Position - root.Position).Magnitude < (best.Position - root.Position).Magnitude then best = shopPart end
		end
	end
	if not best then return end
	local s = best:FindFirstChild("PayBeep") :: Sound?
	if not s then
		local made = Instance.new("Sound")
		made.Name = "PayBeep"
		made.SoundId = PAY_SOUND
		made.Volume = 0.7
		made.RollOffMinDistance = 6
		made.RollOffMaxDistance = 40
		made.Parent = best
		s = made
	end
	(s :: Sound):Play()
end

local function buy(player: Player, shopKey: any, itemKey: any): (boolean, string?)
	local shop, item = SnackConfig.find(shopKey, itemKey)
	if not shop or not item then return false, "없는 메뉴예요." end
	-- (D-789, user) no ordering anywhere while on a cafe shift (character attribute CafeJob)
	if player.Character and player.Character:GetAttribute("CafeJob") ~= nil then
		return false, "알바 중에는 주문할 수 없어요. 알바를 끝낸 뒤 주문해 주세요."
	end
	if item.comingSoon then return false, "🔒 개발 중이에요. 조금만 기다려 주세요!" end
	if item.product and not item.coins then return false, "Robux 결제로 주문해요." end
	if not nearShop(player, shop.key) then return false, "카운터 가까이에서 주문해 주세요." end
	-- a shared cake bought with coins (the strawberry cake: 💰 or R$)
	if item.share then
		local price = item.coins or 0
		if not economy or not economy.Spend(player, price, "Snack_" .. shop.key .. "_" .. item.key) then
			local balance = if economy then economy.Balance(player) else 0
			return false, string.format("%s이 부족해요 (%d 필요, 지금 %d).", EconomyConfig.CurrencyName, price, balance)
		end
		grantProduct(player, item, if economy then economy.FoodXPFor(price) else 0) -- (D-1103: XP on the plate)
		payBeep(player, shop.key)
		Analytics.interact(player, "Buy") -- (D-1124)
		return true, nil
	end
	if handsFull(player) then
		return false, string.format("손에 %d개까지 들 수 있어요. 먼저 드세요!", SnackConfig.MaxCarried)
	end
	if not player:FindFirstChildOfClass("Backpack") then return false, "잠시 후 다시 시도해 주세요." end
	-- (D-1135) a club can: the club bar's own can (DrinkService), paid in coins here
	local clubCan = (item :: any).clubCan
	if clubCan and SnackService.canGiver then
		local price = item.coins or 0
		if price > 0 and (not economy or economy.Balance(player) < price) then
			local balance = if economy then economy.Balance(player) else 0
			return false, string.format("%s이 부족해요 (%d 필요, 지금 %d).", EconomyConfig.CurrencyName, price, balance)
		end
		local ok, message, can = SnackService.canGiver(player, clubCan, nil)
		if not ok then return false, message end
		if price > 0 and economy then economy.Spend(player, price, "Snack_" .. shop.key .. "_" .. item.key) end
		if can and economy then can:SetAttribute("FoodXP", economy.FoodXPFor(price)) end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and can then humanoid:EquipTool(can) end
		payBeep(player, shop.key)
		Analytics.interact(player, "Buy")
		return true, item.name .. " 나왔어요! 누르면 캔째 마시고, 테이블을 누르면 올려놓고 같이 마셔요."
	end
	-- the cafe staff makes the order (free cups until D-772)
	-- (D-772, user: everything but the Robux menu goes through the staff; the
	-- coins are paid when ordering, CafeJobService)
	if orderHandler and not item.product then
		local handled, message = orderHandler(player, shop, item)
		if handled then return true, message end -- (D-1103: CafeJobService puts the XP on the cup it serves)
	end
	local price = item.coins or 0
	if price > 0 then
		if not economy or not economy.Spend(player, price, "Snack_" .. shop.key .. "_" .. item.key) then
			local balance = if economy then economy.Balance(player) else 0
			return false, string.format("%s이 부족해요 (%d 필요, 지금 %d).", EconomyConfig.CurrencyName, price, balance)
		end
	end
	Analytics.interact(player, "Buy") -- (D-1124: free ones too)
	local bought = makeTool(item)
	-- (D-1103) the XP it is worth, given bite by bite while it is eaten
	if economy then bought:SetAttribute("FoodXP", economy.FoodXPFor(price)) end
	giveTool(player, bought)
	payBeep(player, shop.key)
	local drink = item.kind == "cup" or item.kind == "bottle"
	if item.kind == "noodle" then -- (D-1053: its own steps)
		return true, item.name .. " 나왔어요! 눌러서 뚜껑 열기 → 온수기 눌러 물 붓기 → 10초 뒤에 눌러서 먹어요."
	end
	return true, string.format("%s 나왔어요! 클릭(터치)해서 %s. 자리에 앉아서 즐겨도 돼요.", item.name, if drink then "마셔요" else "먹어요")
end

local function addPrompt(shopPart: Instance)
	if not shopPart:IsA("BasePart") or shopPart:FindFirstChild("SnackPrompt") or not shopPart:IsDescendantOf(workspace) then return end
	local shop = SnackConfig.Shops[shopPart:GetAttribute("Shop") :: any]
	if not shop then return end
	-- a long counter gets a prompt every ~12 studs along it (a prompt only
	-- shows near its own spot: on the 34-long beach cafe counter the one in the
	-- middle could not be reached from the till, user 2026-10-28)
	local size = shopPart.Size
	local long = math.max(size.X, size.Z)
	local axis = if size.X >= size.Z then Vector3.xAxis else Vector3.zAxis
	local count = math.max(1, math.ceil(long / 12))
	for i = 1, count do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SnackPrompt"
		prompt.ActionText = shop.prompt
		prompt.ObjectText = shop.title
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		if count == 1 then
			prompt.Parent = shopPart
		else
			local at = Instance.new("Attachment")
			at.Name = "SnackPromptSpot"
			at.Position = axis * (-long / 2 + long * (i - 0.5) / count)
			at.Parent = shopPart
			prompt.Parent = at
		end
		prompt.Triggered:Connect(function(player)
			local notify = Remotes:FindFirstChild("SnackNotify") :: RemoteEvent?
			if notify then notify:FireClient(player, "Open", shop.key) end
		end)
	end
end

-- Gives a ready drink / snack (cafe job: the staff hands it over).
function SnackService.Give(player: Player, item: SnackConfig.Item): Tool?
	local tool = makeTool(item)
	if not giveTool(player, tool) then return nil end
	return tool
end

-- A drink tool for anyone (an NPC customer, the cup the staff carries).
SnackService.MakeTool = function(item: SnackConfig.Item): Tool return makeTool(item) end

-- A shared plate on a table as if `owner` put it down (the food showcase:
-- owner can be a stand-in { UserId, DisplayName }).
SnackService.PlacePlate = function(owner: any, tablePart: BasePart, item: SnackConfig.Item) placePlate(owner, tablePart, item) end

function SnackService.SetOrderHandler(handler: (Player, SnackConfig.Shop, SnackConfig.Item) -> (boolean, string?))
	orderHandler = handler
end

-- (D-1135) who hands over a club can (DrinkService.GiveBottle: player, drink key, servings) → ok, message, tool
SnackService.canGiver = nil :: ((Player, string, number?) -> (boolean, string?, Tool?))?
SnackService.canSwig = nil :: ((Player) -> (boolean, string?))? -- (D-1158)

-- (D-1158, user 2026-11-10: "캔 음료 테이블에 둘 수 있게 수정. 버켓은 클럽 안에서만.")
-- a club can (DrinkService tier 1: Bottle attribute, 6 cups) goes on the food
-- tables like a drink; buckets (tier 2 / 3) stay on the club's tables
local function isCan(tool: Instance?): boolean
	if not tool or not tool:IsA("Tool") then return false end
	local drink = ClubConfig.findDrink(tool:GetAttribute("Bottle"))
	return drink ~= nil and drink.tier == 1
end

function SnackService.SetFinishedHandler(handler: (Model, SnackConfig.Item) -> ())
	finishedHandler = handler
end

-- Putting the food in hand down on a table (user 2026-10-26: 국밥 too): the
-- tool is kept aside and a still copy of it stands on the table where the
-- player is; its owner picks it up again with "다시 들기" (bites left kept).
local FOOD_TABLE_TAGS = { CafeTable = true, GukbapTable = true, SnackTable = true }
local keptFolder: Folder? = nil
local SOUP_SECONDS = 300

local function itemByKey(key: any): SnackConfig.Item?
	for _, shop in pairs(SnackConfig.Shops) do
		for _, it in ipairs(shop.items) do
			if it.key == key then return it end
		end
	end
	return nil
end

-- One spoonful from a bowl on the table: a spoon with soup on it comes up to
-- the mouth (the bowl's own spoon is gone meanwhile), the soup sinks a step;
-- the empty bowl goes.
local function spoonful(player: Player, model: Model, copy: BasePart, tool: Tool, item: SnackConfig.Item, wanted: number?)
	if model:GetAttribute("Busy") then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then return end
	model:SetAttribute("Busy", true)
	local spoon = Instance.new("Tool")
	spoon.CanBeDropped = false
	local handle: Part
	if item.kind == "noodle" then
		-- 컵라면: chopsticks with a bundle of noodles (user 2026-10-27)
		spoon.Name = "젓가락"
		handle = part("Handle", Vector3.new(0.035, 0.9, 0.035), Color3.fromRGB(205, 175, 125), Enum.Material.Wood)
		handle.Parent = spoon
		attach(handle, part("Stick", Vector3.new(0.035, 0.9, 0.035), Color3.fromRGB(205, 175, 125), Enum.Material.Wood), CFrame.new(0.05, 0, 0) * CFrame.Angles(0, 0, math.rad(-4)))
		-- (D-1090) the user's cup ramen: its own noodles' colour
		local bundle = part("Noodles", Vector3.new(0.16, 0.3, 0.12),
			if tool:GetAttribute("Ramen") then RamenCup.noodleColor(tool:GetAttribute("Snack")) else Color3.fromRGB(245, 215, 130))
		local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = bundle
		attach(handle, bundle, CFrame.new(0.03, 0.42, -0.02))
	elseif FoodShapes.TableEat[item.key] == "hand" then
		-- (D-1154) a bread piece taken by hand: an unseen handle, the piece on it below
		spoon.Name = item.name
		handle = part("Handle", Vector3.new(0.2, 0.2, 0.2), item.color)
		handle.Transparency = 1
		handle.Parent = spoon
		local at = part("Soup", Vector3.new(0.05, 0.05, 0.05), item.color)
		at.Transparency = 1
		attach(handle, at, CFrame.new(0, 0.12, 0))
	elseif FoodShapes.TableEat[item.key] == "fork" then
		-- (D-1147) a dessert fork for the honey bread: a thin steel handle, a
		-- flat head and four tines at +Y; the piece goes on the tines below
		spoon.Name = "포크"
		local STEEL = Color3.fromRGB(215, 218, 222)
		handle = part("Handle", Vector3.new(0.06, 0.6, 0.03), STEEL, Enum.Material.Metal)
		handle.Parent = spoon
		attach(handle, part("Neck", Vector3.new(0.09, 0.1, 0.025), STEEL, Enum.Material.Metal), CFrame.new(0, 0.33, 0))
		attach(handle, part("Head", Vector3.new(0.15, 0.06, 0.025), STEEL, Enum.Material.Metal), CFrame.new(0, 0.39, 0))
		for k = 0, 3 do
			attach(handle, part("Tine", Vector3.new(0.022, 0.16, 0.022), STEEL, Enum.Material.Metal), CFrame.new(-0.057 + k * 0.038, 0.5, 0))
		end
		-- (where the piece sits: speared on the tines; the "Soup" mark is only a place)
		local at = part("Soup", Vector3.new(0.05, 0.05, 0.05), STEEL)
		at.Transparency = 1
		attach(handle, at, CFrame.new(0, 0.52, 0))
	else
		spoon.Name = "숟가락"
		handle = part("Handle", Vector3.new(0.07, 0.75, 0.05), Color3.fromRGB(215, 218, 222), Enum.Material.Metal)
		handle.Parent = spoon
		-- (user pick 2026-10-30: Creator Store spoon 14841373331, its mesh as
		-- ServerStorage.ArtAssets.SpoonS4Mesh; it lies along Z, the bowl at +Z)
		local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
		local src = art and art:FindFirstChild("SpoonS4Mesh")
		if src and src:IsA("MeshPart") then
			handle.Transparency = 1
			local m = src:Clone()
			m.Name = "SpoonMesh"
			m.Size = src.MeshSize * (0.9 / src.MeshSize.Z)
			m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.Massless = false, false, false, false, true
			attach(handle, m, CFrame.new(0, 0.05, 0) * CFrame.Angles(math.rad(-90), 0, 0))
			-- (the bowl stands up, its hollow toward +Z: the soup a thin oval in it; checked in Play)
			local soup = part("Soup", Vector3.new(0.02, 0.2, 0.13), item.color, nil, Enum.PartType.Cylinder)
			attach(handle, soup, CFrame.new(0, 0.38, 0.03) * CFrame.Angles(0, math.rad(90), 0))
		else
			attach(handle, part("Scoop", Vector3.new(0.24, 0.05, 0.3), Color3.fromRGB(215, 218, 222), Enum.Material.Metal), CFrame.new(0, 0.38, -0.1))
			attach(handle, part("Soup", Vector3.new(0.2, 0.04, 0.24), item.color), CFrame.new(0, 0.42, -0.1))
		end
	end
	spoon.Grip = CFrame.new(0, -0.3, 0)
	-- (D-1036) the user's 국밥 model: the next piece (meat, 순대, green onions)
	-- comes up on the spoon, small, in place of the soup, and is gone from the bowl
	if tool:GetAttribute("EatMode") == "Bites" then
		-- (D-1037) the piece tapped on the table, else the lowest one left
		local set = eatenOf(tool)
		local nextPiece = nextBite(copy, set, wanted)
		local parts = nextPiece and bitePieces(copy)[nextPiece]
		if parts and #parts > 0 then
			local soup = handle:FindFirstChild("Soup")
			local holder = Instance.new("Model")
			for _, p in ipairs(parts) do
				local c = p:Clone()
				for _, d in ipairs(c:GetChildren()) do if not (d:IsA("Decal") or d:IsA("Texture")) then d:Destroy() end end
				c.Transparency = (p:GetAttribute("BiteT0") :: number?) or 0
				c.Anchored = true
				c.Parent = holder
			end
			local _, size = holder:GetBoundingBox()
			-- (on a spoon or a fork a small bite; by hand the piece as it lay on the plate, D-1154)
			local fit = if FoodShapes.TableEat[item.key] == "hand" then 1 else 0.26 / math.max(size.X, size.Y, size.Z, 0.01)
			holder:ScaleTo(holder:GetScale() * fit)
			local cf = holder:GetBoundingBox()
			-- (where the soup sat in the spoon; the piece keeps the way it lay in the bowl)
			local at: Vector3 = if soup and soup:IsA("BasePart") then soup.Position else (handle.CFrame * Vector3.new(0, 0.4, 0.03))
			for _, c in ipairs(holder:GetChildren()) do
				if c:IsA("BasePart") then
					c.CFrame = c.CFrame + (at - cf.Position)
					c.Name = "BitePiece"
					c.Anchored = false
					c.CanCollide, c.CanQuery, c.CanTouch, c.Massless = false, false, false, true
					attach(handle, c, handle.CFrame:ToObjectSpace(c.CFrame))
				end
			end
			holder:Destroy()
			if soup then soup:Destroy() end
		end
		if nextPiece then set[nextPiece] = true end
		setEaten(tool, set)
		applyEaten(copy, set)
	end
	local sound = Instance.new("Sound")
	local gukbap = if item.kind == "bowl" then gukbapClip() else nil
	sound.SoundId = "rbxassetid://" .. tostring(gukbap or EAT_SOUND[item.kind] or EAT_SOUND.bowl)
	if gukbap then sound.TimePosition = GUKBAP_FROM end
	if tool:GetAttribute("Ramen") then
		-- (D-1090) the cup ramen's own noodle sound, as in the hand
		sound.SoundId = "rbxassetid://" .. tostring(RamenCup.EatSound)
		sound.TimePosition = RamenCup.EatFrom
	end
	setVolume(sound, LOUD[item.key] or 0.7)
	sound.RollOffMaxDistance = 40
	-- (on the character, not the spoon: the spoon goes 1.5 s after the bite and
	-- would cut a longer clip, user 2026-10-30)
	sound.Parent = character:FindFirstChild("Head") or handle
	Debris:AddItem(sound, 4)
	-- the bowl's own spoon (or the cup's chopsticks) is gone while it is used
	local own = {}
	for _, d in ipairs(copy:GetChildren()) do
		if d:IsA("BasePart") and (d.Name == "Spoon" or d.Name == "Chopsticks") then table.insert(own, d) d.Transparency = 1 end
	end
	humanoid:UnequipTools()
	spoon.Parent = character
	-- (D-1099) the cup ramen on the table: long noodle strands from the sticks'
	-- bundle down into the cup, slurped up when the sticks are at the mouth
	local strandsDone: (() -> ())? = nil
	if tool:GetAttribute("Ramen") then
		local bundle = handle:FindFirstChild("Noodles", true) :: BasePart?
		if bundle then strandsDone = RamenCup.tableStrands(bundle, copy, tool:GetAttribute("Snack"), 1.0) end
	end
	-- the hand takes the spoon up to the mouth (IK, see bite); R6: the spoon moves
	local ik = character:FindFirstChild("RightUpperArm") ~= nil
	local up = if ik then nil else mouthGrip(character, 0)
	if up then TweenService:Create(spoon, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Grip = up }):Play() end
	-- (a moment in the hand first, so the spoon is seen coming from the bowl)
	task.wait(0.25)
	character:SetAttribute("Eating", true)
	task.wait(0.35)
	sound:Play()
	-- (D-1161, user: "조각 사라지는 거 클릭하자마자 사라져야 함") the piece on the spoon / fork /
	-- in the hand is gone as it reaches the mouth, not when the sound is over
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "BitePiece" or d.Name == "Soup") then d.Transparency = 1 end
		if (d:IsA("Decal") or d:IsA("Texture")) and d.Parent and (d.Parent.Name == "BitePiece" or d.Parent.Name == "Soup") then d.Transparency = 1 end
	end
	task.wait(1.1)
	character:SetAttribute("Eating", nil)
	if up and spoon.Parent then TweenService:Create(spoon, TweenInfo.new(0.3), { Grip = CFrame.new(0, -0.3, 0) }):Play() end
	task.wait(0.4)
	if strandsDone then strandsDone() end
	spoon:Destroy()
	for _, d in ipairs(own) do d.Transparency = 0 end
	model:SetAttribute("Busy", nil)
	local total = bitesOf(item)
	local left = ((tool:GetAttribute("Bites") :: number?) or total) - 1
	tool:SetAttribute("Bites", left)
	if economy then economy.EatXP(player, tool, left + 1) end -- (D-1103: a spoonful from the table)
	Analytics.interact(player, "Eat") -- (D-1124)
	local fill = copy:FindFirstChild("Fill")
	if tool:GetAttribute("EatMode") == "Bites" then
		-- (D-1036) the tool in waiting shows the same pieces gone (picked up later)
		local set = eatenOf(tool)
		applyEaten(copy, set)
		local held = tool:FindFirstChild("Handle")
		if held then applyEaten(held, set) end
	elseif tool:GetAttribute("Ramen") then
		-- (D-1090) the broth a step lower on the table and in the tool waiting aside
		RamenCup.tableBite(copy, left)
		local held = tool:FindFirstChild("Handle")
		if held and held:IsA("BasePart") then RamenCup.afterBite(tool, held, left, total) end
	elseif fill and fill:IsA("BasePart") then
		local drop = (fill:GetAttribute("EatDrop") :: number?) or 0.3
		fill.CFrame -= Vector3.new(0, drop / total, 0)
	end
	if left <= 0 then model:Destroy() end
end
-- (D-950) the food on the tables: model → its tool waiting aside, for a
-- spoonful and for taking it back (no buttons on the food any more)
type Placed = { player: Player, tool: Tool, item: SnackConfig.Item?, copy: BasePart, soup: boolean }
local placedFood: {[Model]: Placed} = {}
local function footprint(tool: Tool, handle: BasePart): number
	local r = tool:GetAttribute("PlaceRadius")
	return if typeof(r) == "number" then r else footprintOf(handle)
end
-- (shared with SnackController: a spot is free when another food's middle is
-- farther than this part of the two reaches)
local OVERLAP = 0.85

local function putDown(player: Player, tablePart: any, at: any): (boolean, string?)
	if typeof(tablePart) ~= "Instance" or not tablePart:IsA("BasePart") or not tablePart:IsDescendantOf(workspace) then
		return false, "테이블을 찾을 수 없어요."
	end
	local tagged = false
	for tag in pairs(FOOD_TABLE_TAGS) do
		if CollectionService:HasTag(tablePart, tag) then tagged = true end
	end
	if not tagged then return false, "여기에는 놓을 수 없어요." end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tool = character and character:FindFirstChildOfClass("Tool")
	-- (D-952) a whole cake / 수육 plate goes down on the spot as a shared plate
	local plateKey = tool and tool:GetAttribute("Plate")
	if root and tool and typeof(plateKey) == "string" then
		local item = itemByKey(plateKey)
		if not item then return false, nil end
		if typeof(at) ~= "Vector3" then return false, nil end
		-- (D-1141) the top whichever side faces up (round tables are standing cylinders)
		if not (SnackConfig.onTable(tablePart, at, PLATE_RADIUS)) then
			return false, "테이블 가장자리라 놓을 수 없어요."
		end
		if Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z).Magnitude > 9 then return false, "테이블 가까이 가 주세요." end
		for _, other in ipairs(tablePart:GetChildren()) do
			if other:IsA("Model") and (other.Name == "PlacedFood" or other.Name == "SharedPlate") then
				local r2 = other:GetAttribute("Radius")
				local p = other:GetBoundingBox().Position
				if Vector3.new(p.X - at.X, 0, p.Z - at.Z).Magnitude < (PLATE_RADIUS + (if typeof(r2) == "number" then r2 else 0.8)) * OVERLAP then
					return false, "다른 음식과 너무 가까워요."
				end
			end
		end
		placePlate(player, tablePart, item, at, tool:GetAttribute("FoodXP") :: number?)
		tool:Destroy()
		return true, nil
	end
	-- (D-952, user 2026-11-07: "수육 한 점은 배치 안 되어야 함") a piece taken
	-- from a shared plate is eaten from the hand, never put down
	if tool and tool:GetAttribute("Piece") then return false, nil end
	if not root or not tool or not (tool:GetAttribute("Snack") or isCan(tool)) then return false, "손에 든 음식이 없어요." end -- (D-1158: a can too)
	if tool:GetAttribute("Drinking") then return false, nil end
	-- (D-1106, user 2026-11-09: "먹는 중이에요. 삭제") nothing on the screen
	if tool:GetAttribute("Busy") or tool:GetAttribute("CafeOrder") then return false, nil end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return false, nil end
	local reach = math.max(tablePart.Size.X, tablePart.Size.Y, tablePart.Size.Z) / 2 + 8
	if (root.Position - tablePart.Position).Magnitude > reach then return false, "테이블 가까이 가 주세요." end
	-- the spot: on the table top, toward the player, a little in from the edge
	local cf = tablePart.CFrame
	local halfX = (math.abs(cf.XVector.X) * tablePart.Size.X + math.abs(cf.YVector.X) * tablePart.Size.Y + math.abs(cf.ZVector.X) * tablePart.Size.Z) / 2
	local halfZ = (math.abs(cf.XVector.Z) * tablePart.Size.X + math.abs(cf.YVector.Z) * tablePart.Size.Y + math.abs(cf.ZVector.Z) * tablePart.Size.Z) / 2
	local inner = math.max(0, math.min(halfX, halfZ) - 0.7)
	local flat = Vector3.new(root.Position.X - cf.X, 0, root.Position.Z - cf.Z)
	local offset = if flat.Magnitude > 0.01 then flat.Unit * math.min(flat.Magnitude, inner) else Vector3.zero
	local spot = Vector3.new(cf.X, 0, cf.Z) + offset
	-- (D-950, user 2026-11-07: "음식 들고 테이블 위로 드래그하면 음식 실루엣으로
	-- 테이블 위에 배치 ... 배치할 수 없는 곳이면 빨간색") the spot the player
	-- pointed at (SnackController's green silhouette), checked again here:
	-- on the top, the food inside its edges, not on another food
	local radius = footprint(tool, handle)
	if typeof(at) == "Vector3" then
		if not (SnackConfig.onTable(tablePart, at, radius)) then -- (D-1141)
			return false, "테이블 가장자리라 놓을 수 없어요."
		end
		if Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z).Magnitude > 9 then
			return false, "테이블 가까이 가 주세요."
		end
		for other, entry in pairs(placedFood) do
			if other.Parent == tablePart then
				local p = entry.copy.Position
				local otherR = other:GetAttribute("Radius")
				local r2 = if typeof(otherR) == "number" then otherR else 0.8
				if Vector3.new(p.X - at.X, 0, p.Z - at.Z).Magnitude < (radius + r2) * OVERLAP then
					return false, "다른 음식과 너무 가까워요."
				end
			end
		end
		-- (D-952) the shared plates too
		for _, other in ipairs(tablePart:GetChildren()) do
			if other:IsA("Model") and other.Name == "SharedPlate" then
				local p = other:GetBoundingBox().Position
				if Vector3.new(p.X - at.X, 0, p.Z - at.Z).Magnitude < (radius + PLATE_RADIUS) * OVERLAP then
					return false, "다른 음식과 너무 가까워요."
				end
			end
		end
		spot = Vector3.new(at.X, 0, at.Z)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { tablePart }
	local hit = workspace:Raycast(Vector3.new(spot.X, cf.Y + 20, spot.Z), Vector3.new(0, -40, 0), params)
	if not hit then return false, "테이블 위에 놓을 자리가 없어요." end
	-- a still copy of what is in the hand, upright, facing the player
	local copy = handle:Clone()
	local originals, copies = handle:GetDescendants(), copy:GetDescendants()
	local place = CFrame.lookAt(hit.Position, hit.Position + Vector3.new(flat.X, 0, flat.Z) + Vector3.new(0, 0, 0.001))
	local parts: {BasePart} = {}
	local function fix(original: Instance, clone: Instance)
		if clone:IsA("BasePart") and original:IsA("BasePart") then
			clone.CFrame = place * handle.CFrame:ToObjectSpace(original.CFrame)
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			table.insert(parts, clone)
		elseif clone:IsA("JointInstance") or clone:IsA("Sound") then
			clone:Destroy()
		end
	end
	fix(handle, copy)
	for i, original in ipairs(originals) do
		if copies[i] then fix(original, copies[i]) end
	end
	-- (D-1063) the cup ramen held in two hands: the whole cup on the table, sticks in it
	if tool:GetAttribute("Ramen") then RamenCup.tableLook(copy, tool) end
	local model = Instance.new("Model")
	model.Name = "PlacedFood"
	copy.Parent = model
	-- rest its lowest point on the table top
	local box, size = model:GetBoundingBox()
	local lift = hit.Position.Y + 0.02 - (box.Y - size.Y / 2)
	for _, p in ipairs(parts) do p.CFrame += Vector3.new(0, lift, 0) end
	-- (D-1037, user 2026-11-09: "테이블에 놓을 때 국밥만 올라가게 변경. 기존에 에셋
	-- 삭제") the 국밥 goes down as itself, the bowl in the hand (the user's model,
	-- D-1036); the store tray set (GukbapTray, user pick 2026-10-27) is gone from
	-- ArtAssets. The old way stays for a store bowl with the tray still there.
	local placedItem = itemByKey(tool:GetAttribute("Snack"))
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local ownBowl = tool:GetAttribute("EatMode") == "Bites"
	local tray = not ownBowl and placedItem and placedItem.kind == "bowl" and art and art:FindFirstChild("Foods") and art.Foods:FindFirstChild("GukbapTray")
	if tray then
		for _, p in ipairs(parts) do
			p.Transparency = 1
			for _, d in ipairs(p:GetDescendants()) do if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end end
		end
		local t = tray:Clone()
		local _, tsize = t:GetBoundingBox()
		t:ScaleTo(t:GetScale() * 3.4 * FOOD_SCALE / math.max(tsize.X, tsize.Z)) -- (D-950: 1.5×, as the bowl)
		local tb, ts = t:GetBoundingBox()
		t:PivotTo(t:GetPivot() + (Vector3.new(hit.Position.X, hit.Position.Y + 0.02 + ts.Y / 2, hit.Position.Z) - tb.Position))
		for _, p in ipairs(t:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.CanTouch = false end
		end
		t.Name = "Tray"
		t.Parent = model
	end
	model:SetAttribute("Owner", player.UserId)
	-- the tool waits aside with its bites left
	if not keptFolder then
		keptFolder = Instance.new("Folder")
		keptFolder.Name = "PutDownFood"
		keptFolder.Parent = game:GetService("ServerStorage")
	end
	tool:SetAttribute("KeptBy", player.UserId) -- (D-790: still theirs, BagService)
	tool.Parent = keptFolder
	local item = itemByKey(tool:GetAttribute("Snack"))
	local soup = item ~= nil and (item.kind == "bowl" or item.kind == "ricebowl" or item.kind == "noodle") -- (컵라면 too: chopsticks, 2026-10-27)
		and not tool:GetAttribute("Ramen") -- (D-1053: the user's cup ramen goes back to the hand, its own steps)
	-- (D-1147) the parfait / honey bread pieces with a spoon / fork on the table
	if item ~= nil and ownBowl and FoodShapes.TableEat[item.key] then soup = true end
	-- (D-947 → D-950) no buttons on the food: SnackController finds a tap on
	-- it (so its parts answer raycasts; they are made with CanQuery off) and
	-- asks "Spoon" (a short tap on a 국밥 / 공깃밥 / 컵라면: one spoonful) or
	-- "PickUp" (a long press on any food: back into the backpack as it is)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanQuery = true
			p:SetAttribute("BiteQ0", nil) -- (D-1037: on the table the pieces answer taps)
		end
	end
	-- (D-1037) the pieces already eaten from the hand stay gone, and let taps through
	if ownBowl then applyEaten(copy, eatenOf(tool)) end
	model:SetAttribute("Soup", soup)
	model:SetAttribute("Radius", radius)
	placedFood[model] = { player = player, tool = tool, item = item, copy = copy, soup = soup }
	model.Parent = tablePart
	model.Destroying:Connect(function()
		placedFood[model] = nil
		if tool.Parent == keptFolder then tool:Destroy() end
	end)
	-- (a bowl left behind goes sooner: its owner may have walked off, user 2026-10-26)
	Debris:AddItem(model, if soup then SOUP_SECONDS else SnackConfig.PlateSeconds)
	return true, nil
end

-- Carried foods across a rejoin (D-790, BagService): what the player holds or
-- has put down on a table, as plain entries, and the tools made again from them.
--   { k = "snack", key, bites, piece?, tex?, model?, slice?, name? }  a food / drink in the hand
--   { k = "plate", key }                                              a whole cake / 수육 plate in the hand
function SnackService.BagEntries(player: Player): {any}
	local list = {}
	local function note(tool: Instance)
		if not tool:IsA("Tool") or tool:GetAttribute("CafeOrder") then return end
		local plate = tool:GetAttribute("Plate")
		if typeof(plate) == "string" then
			table.insert(list, { k = "plate", key = plate })
			return
		end
		local key = tool:GetAttribute("Snack")
		if typeof(key) ~= "string" then return end
		local bites = tool:GetAttribute("Bites")
		if typeof(bites) == "number" and bites <= 0 then return end
		table.insert(list, {
			k = "snack", key = key, bites = bites, name = tool.Name,
			piece = tool:GetAttribute("Piece"), tex = tool:GetAttribute("SliceTexture"),
			model = tool:GetAttribute("SliceModel"), slice = tool:GetAttribute("SliceName"),
			eaten = tool:GetAttribute("BitesEaten"), -- (D-1037)
			half = tool:GetAttribute("Half"), moved = tool:GetAttribute("PairMoved"), -- (D-1129: a 친구바 half)
		})
	end
	for _, where in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if where then for _, t in ipairs(where:GetChildren()) do note(t) end end
	end
	if keptFolder then
		for _, t in ipairs(keptFolder:GetChildren()) do
			if t:GetAttribute("KeptBy") == player.UserId then note(t) end
		end
	end
	-- (D-1129) the other half of a 친구바 still in the left hand
	for _, t in ipairs(FriendBar.keptTools()) do
		if t:GetAttribute("KeptBy") == player.UserId then note(t) end
	end
	return list
end

function SnackService.BagRestore(player: Player, e: any): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local item = itemByKey(e.key)
	if not backpack or not item then return false end
	if e.k == "plate" then
		if not item.share then return false end
		plateTool(player, item).Parent = backpack
		return true
	end
	if e.k ~= "snack" then return false end
	local use: any = item
	if e.piece then
		use = table.clone(item)
		use.sliceTexture = e.tex
		use.cakeModel = e.model
		use.sliceName = e.slice
		if item.kind == "plate" or item.cake ~= nil then use.oneBite = true end -- (D-1146: a cake slice too)
	end
	local tool = makeTool(use, if typeof(e.name) == "string" then e.name else nil)
	if e.piece then
		tool:SetAttribute("Piece", true)
		if e.tex then tool:SetAttribute("SliceTexture", e.tex) end
		if e.model then tool:SetAttribute("SliceModel", e.model) end
		if e.slice then tool:SetAttribute("SliceName", e.slice) end
	end
	if typeof(e.bites) == "number" and not use.oneBite then tool:SetAttribute("Bites", math.max(1, math.floor(e.bites))) end -- (D-1146: a slice saved with 3 bites is one bite now)
	-- (D-1036) a 국밥 model shows the pieces already eaten
	local held = tool:FindFirstChild("Handle")
	if held and tool:GetAttribute("EatMode") == "Bites" then
		if typeof(e.eaten) == "string" then
			tool:SetAttribute("BitesEaten", e.eaten) -- (D-1037: the very pieces eaten)
			applyEaten(held, eatenOf(tool))
			-- (D-1129) the wrapper already off (it came back on before)
			if tool:GetAttribute("Wrapped") and eatenOf(tool)[1] then
				tool:SetAttribute("Wrapped", nil)
				tool.ToolTip = "클릭(터치)해서 먹기"
			end
		elseif typeof(e.bites) == "number" then
			showBitesLeft(held, math.max(1, math.floor(e.bites)), bitesOf(use))
		end
		-- (D-1129) a 친구바 half: the other half hidden again
		if (e.half == 1 or e.half == 2) and held:IsA("BasePart") then
			FriendBar.applyHalf(tool, held, e.half, if typeof(e.moved) == "number" then e.moved else 0)
			if typeof(e.bites) == "number" then tool:SetAttribute("Bites", math.max(1, math.floor(e.bites))) end
		end
	end
	tool.Parent = backpack
	return true
end

-- The real foods for the order windows (user 2026-10-31: "실제 아이템 사진"):
-- one model per menu item (FashionGame.FoodPreviews.<item key>), built here
-- because the meshes and textures are in ServerStorage; clients show them in
-- little 3D windows (NeonShopUI), like the club's DrinkPreviews. What you get
-- in the hand, and the whole cake for the cakes.
local function buildFoodPreviews()
	local old = FashionGame:FindFirstChild("FoodPreviews")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "FoodPreviews"
	-- (the asset foods hang off their handle by welds only: they are laid out
	-- in a hidden spot of the world for a moment so the welds place them)
	local stage = Instance.new("Model")
	stage.Name = "FoodPreviewStage"
	local made: {Model} = {}
	local done: {[string]: boolean} = {}
	for _, shop in pairs(SnackConfig.Shops) do
		for _, item in ipairs(shop.items) do
			if not done[item.key] then
				done[item.key] = true
				local ok, err = pcall(function()
					local m = Instance.new("Model")
					m.Name = item.key
					-- how far the card's camera looks down (NeonShopUI): flat foods from above
					local angles = { cake = 35, plate = 40, bowl = 32, ricebowl = 32, bread = 30, noodle = 20, parfait = 12 }
					m:SetAttribute("PreviewAngle", angles[item.kind] or 8)
					local whole = cakeModel(item.cake)
					local cake = item.cake and SnackConfig.Cakes[item.cake]
					if whole then
						cakeCopy(whole, 2.2).Parent = m
					elseif cake and sliceMesh() then
						local centre = CFrame.new()
						for i = 1, 6 do
							local a = (i - 1) / 6 * math.pi * 2
							local slice = cakeSlice(CAKE_R, cake.textures[1], centre, a)
							if slice then
								cakeDeco(cake, slice, centre, a, CAKE_R)
								slice.Parent = m
							end
						end
					elseif (item :: any).clubCan then
						-- (D-1135) the club can's own shape (BottleShapes, as DrinkService draws it)
						local BottleShapes = require(FashionGame:WaitForChild("Shared"):WaitForChild("BottleShapes"))
						local key = (item :: any).clubCan
						local h = part("Handle", Vector3.new(0.7, 1.8, 0.7), item.color)
						h.Transparency = 1
						h.Parent = m
						BottleShapes.add(m, h.CFrame * CFrame.new(0, -0.9, 0), key, item.color, 1.9 / BottleShapes.height(key), h)
						-- (D-1250, user 2026-11-10: "편의점 판매 상품 사진 없는 거 사진 추가") the can
						-- is placed already: it stays where it is (moved off with the handle
						-- below, the can was left 4,000 studs away and the card was empty)
						m:SetAttribute("StaticPreview", true)
						for _, d in ipairs(m:GetDescendants()) do
							if d:IsA("BasePart") then d.Anchored = true end
							if d:IsA("WeldConstraint") or d:IsA("JointInstance") then d:Destroy() end
						end
					else
						local tool = makeTool(item)
						for _, d in ipairs(tool:GetChildren()) do d.Parent = m end
						tool:Destroy()
					end
					table.insert(made, m)
				end)
				if not ok then warn("[SnackService] preview", item.key, err) end
			end
		end
	end
	-- hold each handle still far below the map, let the welds settle
	for i, m in ipairs(made) do
		local handle = if m:GetAttribute("StaticPreview") then nil else m:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.Anchored = true
			handle.CFrame = CFrame.new(i * 20, -4000, 0)
		else
			for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.CanCollide, d.CanTouch, d.CanQuery = false, false, false end
		end
		m.Parent = stage
	end
	stage.Parent = workspace
	for _ = 1, 3 do game:GetService("RunService").Heartbeat:Wait() end
	for i, m in ipairs(made) do
		local handle = if m:GetAttribute("StaticPreview") then nil else m:FindFirstChild("Handle")
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true end
		end
		if handle and handle:IsA("BasePart") then m:PivotTo(m:GetPivot() - Vector3.new(i * 20, -4000, 0)) end
		m.Parent = folder
	end
	stage:Destroy()
	for _, m in ipairs(made) do
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ProximityPrompt") or d:IsA("Light")
				or d:IsA("ParticleEmitter") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				d:Destroy()
			elseif d:IsA("BasePart") and d.Material == Enum.Material.Glass then
				-- (ViewportFrames draw see-through glass as nothing)
				d.Material = Enum.Material.SmoothPlastic
				d.Transparency = math.min(d.Transparency, 0.45)
			end
		end
	end
	folder.Parent = FashionGame
end

-- (D-950) a food on a table the player owns and can reach
local function ownPlaced(player: Player, model: any): Placed?
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent then return nil end
	local entry = placedFood[model]
	if not entry or entry.player ~= player then return nil end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - entry.copy.Position).Magnitude > 14 then return nil end
	return entry
end

-- (D-1155) a food on the table near the player, whoever put it there
local function nearPlaced(player: Player, model: any): Placed?
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent then return nil end
	local entry = placedFood[model]
	if not entry then return nil end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - entry.copy.Position).Magnitude > 14 then return nil end
	return entry
end

-- a short tap on a 국밥 / 공깃밥 / 컵라면 on the table: one spoonful
local function spoonFromTable(player: Player, model: any, piece: any): (boolean, string?)
	-- (D-1155, user 2026-11-10: "테이블에 두면 다른 사람들도 먹을 수 있게 해 / 빼앗기고
	-- 빼앗아먹는 재미 넣자") food eaten at the table (spoon, fork, a bread piece by
	-- hand: entry.soup) is anyone's to take a piece of, and the taker gets the XP
	-- of that bite (no message: user 2026-11-10 "뺏어 먹을 때 뜨는 문구 삭제해").
	-- Drinks and snacks that go back to the hand stay the owner's.
	local entry = nearPlaced(player, model)
	-- (D-1158) a can on the table: back to its owner's hand and a swig there
	if entry and entry.player == player and isCan(entry.tool) then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or (model :: Model):GetAttribute("Busy") then return false, nil end
		local tool = entry.tool
		placedFood[model :: Model] = nil
		tool:SetAttribute("KeptBy", nil)
		tool.Parent = player:FindFirstChildOfClass("Backpack")
		;(model :: Model):Destroy()
		humanoid:EquipTool(tool)
		task.delay(0.35, function()
			if tool.Parent == character and SnackService.canSwig then SnackService.canSwig(player) end
		end)
		return true, nil
	end
	if not entry or not entry.item then return false, nil end
	if entry.player ~= player then
		if not entry.soup or (model :: Model):GetAttribute("Busy") then return false, nil end
		task.spawn(spoonful, player, model, entry.copy, entry.tool, entry.item, if typeof(piece) == "Instance" and piece:IsDescendantOf(model) and typeof(piece:GetAttribute("Bite")) == "number" then piece:GetAttribute("Bite") else nil)
		Analytics.interact(player, "StealBite")
		return true, nil
	end
	-- (D-1090, user 2026-11-09: "컵라면 테이블 위에 두면 테이블에 있는 상태에서
	-- 젓가락으로 먹게 하고 들고 있을 땐 왼손에 들고 먹는 걸로") a cooked cup ramen
	-- on the table is eaten there with chopsticks; before it is cooked (lid, hot
	-- water) and for the last sip of broth it comes back to the hand as before
	local ramen = entry.tool:GetAttribute("Ramen")
	-- (D-1189, user 2026-11-10: "컵라면 물 받은 후 테이블에 놓은 상태로 클릭하면 테이블에
	-- 놓인 상태에서 뚜껑 열리게 해") water poured and on the table: the lid comes
	-- off there (RamenCup.openOnTable), the cup stays put
	if ramen == "cooking" then
		if (model :: Model):GetAttribute("Busy") then return false, nil end
		return RamenCup.openOnTable(entry.tool, entry.copy)
	end
	local onTable = entry.soup or (ramen == "ready" and ((entry.tool:GetAttribute("Bites") :: number?) or 0) > 1)
	if not onTable then
		-- (D-1037, user 2026-11-09: "물 테이블에 설치하면 못 먹음") a tap on a drink
		-- or a snack on the table: back into the hand and one sip / bite at once
		local tool = entry.tool
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or (model :: Model):GetAttribute("Busy") then return false, nil end
		placedFood[model :: Model] = nil
		tool:SetAttribute("KeptBy", nil)
		tool.Parent = player:FindFirstChildOfClass("Backpack")
		;(model :: Model):Destroy()
		humanoid:EquipTool(tool)
		local item = entry.item
		task.delay(0.35, function()
			if tool.Parent ~= character then return end
			if tool:GetAttribute("Ramen") then
				RamenCup.tap(player, tool, function() bite(tool, item) end) -- (D-1053)
			else
				bite(tool, item)
			end
		end)
		return true, nil
	end
	-- (D-1037) the piece of a 국밥 model tapped (SnackController), if any
	local wanted = if typeof(piece) == "Instance" and piece:IsDescendantOf(model) then piece:GetAttribute("Bite") else nil
	task.spawn(spoonful, player, model, entry.copy, entry.tool, entry.item, if typeof(wanted) == "number" then wanted else nil)
	return true, nil
end

-- (D-950, user 2026-11-07: "꾹 누르면 먹던 거면 먹던 그 상태로 인벤토리로 다시
-- 들어오게 해") a long press on any food on the table: back into the backpack
-- with the bites it has left (a bowl shows the spoonfuls eaten at the table)
local function pickUp(player: Player, model: any): (boolean, string?)
	local entry = ownPlaced(player, model)
	if not entry then return false, nil end
	if (model :: Model):GetAttribute("Busy") then return false, nil end -- (D-1106: no "먹는 중이에요.")
	local tool = entry.tool
	-- (into the backpack, not the hand: giveTool would equip it)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, nil end
	tool.Parent = backpack
	tool:SetAttribute("KeptBy", nil)
	local item = entry.item
	local handle = tool:FindFirstChild("Handle")
	local left = tool:GetAttribute("Bites")
	local lo, hi = tool:GetAttribute("EatLo"), tool:GetAttribute("EatHi")
	if item and handle and handle:IsA("BasePart") and tool:GetAttribute("EatMode") == "Bites" then
		applyEaten(handle, eatenOf(tool)) -- (D-1036 / D-1037)
	elseif entry.soup and item and handle and handle:IsA("BasePart") and typeof(left) == "number" and typeof(lo) == "number" and typeof(hi) == "number" then
		local total = bitesOf(item)
		if left < total then eatDownTo(handle, lo, hi, left, total) end
	end
	placedFood[model :: Model] = nil
	;(model :: Model):Destroy()
	return true, nil
end

function SnackService.Start(economyService: any)
	economy = economyService
	FriendBar.init({ -- (D-1129)
		makeTool = function(item: any) return makeTool(item) end,
		eatenOf = eatenOf,
		setEaten = setEaten,
		applyEaten = applyEaten,
		giveTool = giveTool,
		splitXP = function(from: Instance, to: Instance, units: number) if economy then economy.SplitXP(from, to, units) end end,
		analytics = function(player: Player, what: string) Analytics.interact(player, what) end,
	})
	task.spawn(buildFoodPreviews)
	task.spawn(Microwave.Start) -- (D-1104)
	local remote = Remotes:WaitForChild("Snack") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, shopKey: any, itemKey: any)
		if action == "Buy" then return buy(player, shopKey, itemKey) end
		if action == "PutDown" then return putDown(player, shopKey, itemKey) end -- (D-950: itemKey = the spot)
		if action == "Spoon" then return spoonFromTable(player, shopKey, itemKey) end -- (D-1037: itemKey = the piece tapped)
		if action == "PickUp" then return pickUp(player, shopKey) end
		-- (D-1053) the cup ramen: a tap on it in the hand, or on the hot water dispenser
		if action == "Ramen" then
			local tool = shopKey
			local item = if typeof(tool) == "Instance" and tool:IsA("Tool") then itemByKey(tool:GetAttribute("Snack")) else nil
			if not item then return false, nil end
			return RamenCup.tap(player, tool, function() bite(tool, item :: SnackConfig.Item) end)
		end
		if action == "HotWater" then return RamenCup.pour(player, shopKey) end
		if action == "Microwave" then return Microwave.heat(player, shopKey) end -- (D-1104)
		if action == "MicrowaveTake" then return Microwave.take(player, shopKey) end
		if action == "TakePiece" then return takePiece(player, shopKey, itemKey) end -- (D-952; itemKey = the piece pointed at, D-1035)
		return false, nil
	end
	-- food left on a table goes when its owner leaves
	Players.PlayerRemoving:Connect(function(player)
		-- (deferred, D-790: the leave-save notes the food put down first, BagService)
		task.defer(function()
		for _, tag in ipairs(TABLE_TAGS) do
			for _, t in ipairs(CollectionService:GetTagged(tag)) do
				for _, m in ipairs(t:GetChildren()) do
					if m.Name == "PlacedFood" and m:GetAttribute("Owner") == player.UserId then m:Destroy() end
				end
			end
		end
		end)
	end)
	-- Robux menu items
	local registered: {[string]: boolean} = {}
	for _, shop in pairs(SnackConfig.Shops) do
		for _, item in ipairs(shop.items) do
			local key = item.product
			if key and not registered[key] then
				registered[key] = true
				MonetizationService.RegisterProduct(key, function(player: Player)
					Analytics.interact(player, "Buy") -- (D-1124)
					return grantProduct(player, item, if economy then economy.FoodXPFor(nil, true) else 0) -- (D-1103)
				end)
			end
		end
	end
	RamenCup.Start() -- (D-1053: the OH24 hot water dispenser)
	for _, shopPart in ipairs(CollectionService:GetTagged("SnackShop")) do addPrompt(shopPart) end
	CollectionService:GetInstanceAddedSignal("SnackShop"):Connect(addPrompt)
end

return SnackService

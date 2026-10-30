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
	return (item :: any).oneBite and 1 or EAT_STEPS
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
	bowl = 140514526743537, noodle = 140514526743537, -- "Sipping" (blixxitry)
	ricebowl = 113253562957164, -- 공깃밥: its own clip (user 2026-10-30)
	bag = 137096768206416, bread = 137096768206416, rice = 137096768206416, -- crunchy / bready
	cake = 95249450082163, cone = 95249450082163, bar = 95249450082163, -- soft
	plate = 135174197196705, -- "Chewing" (GIANT EATERS)
}
-- 국밥 (kind "bowl"): the user's own three clips, picked at random each
-- spoonful, never the same twice in a row (user 2026-10-30;
-- docs/04_ART/sounds/gukbap_eat_1..3.mp3, uploaded on Vantablack_Dev). 0 = the old clip.
local GUKBAP_CLIPS = { 98804537108952, 105506248237925, 115770485617090 }
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
-- (was 9119949556 "Tea Cup Up And Down 10")
local COFFEE_SIP = 77555451916623
local COFFEE = { iceamericano = true, latte = true, caramel = true, cappuccino = true, water = true }
local QUIET = { bagel = true, saltbread = true } -- their bite at half volume

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

local function bite(tool: Tool, item: SnackConfig.Item)
	-- a cup the cafe staff is carrying to a customer is not theirs to drink
	if tool:GetAttribute("Busy") or tool:GetAttribute("CafeOrder") then return end
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
	if item.kind == "noodle" and ik and leftGrip and handle and handle:IsA("BasePart") then
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
		local bundle = part("NoodleBite", Vector3.new(0.16, 0.3, 0.12), Color3.fromRGB(245, 215, 130))
		local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = bundle
		attach(handle, bundle, CFrame.new(0.3, 0.05, 0))
		restore = function()
			cup:Destroy()
			bundle:Destroy()
			for d, t in pairs(hidden) do (d :: any).Transparency = t end
		end
	end
	character:SetAttribute("Eating", true)
	local up = if ik then nil else mouthGrip(character, if item.kind == "cone" or item.kind == "bar" then -0.2 else 0)
	if up then TweenService:Create(tool, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Grip = up }):Play() end
	local sound = handle and handle:FindFirstChild("Sip") :: Sound?
	if sound and item.kind == "bowl" then
		local id = gukbapClip()
		if id then sound.SoundId = "rbxassetid://" .. id end
	end
	if sound then sound:Play() end
	task.wait(1.4)
	-- (some eating clips run longer than a bite; the 국밥 clips are short, let them end)
	if sound and item.kind ~= "bowl" then sound:Stop() end
	character:SetAttribute("Eating", nil)
	if restore then restore() end -- (before the bite is cut below)
	if up and tool.Parent then TweenService:Create(tool, TweenInfo.new(0.3), { Grip = original }):Play() end
	task.wait(0.3)
	local total = bitesOf(item)
	local left = ((tool:GetAttribute("Bites") :: number?) or total) - 1
	tool:SetAttribute("Bites", left)
	-- a third of it is gone, from the top
	local lo, hi = tool:GetAttribute("EatLo"), tool:GetAttribute("EatHi")
	local zlo, zhi = tool:GetAttribute("EatZLo"), tool:GetAttribute("EatZHi")
	if handle and handle:IsA("BasePart") and tool:GetAttribute("EatMode") == "Scale" and left > 0 then
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
	tool:SetAttribute("Busy", nil)
	if left <= 0 then
		if finishedHandler and item.kind == "cup" and tool.Parent and tool.Parent:IsA("Model") then
			task.spawn(finishedHandler, tool.Parent :: Model, item)
		end
		tool:Destroy()
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
		elseif eatMode == "Scale" then tool:SetAttribute("EatMode", "Scale") end
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
		if src then
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
		handle = part("Handle", Vector3.new(0.05, 0.05, 1.0), Color3.fromRGB(200, 170, 120), Enum.Material.Wood)
		handle.Parent = tool
		local slice = part("Fill", Vector3.new(0.5, 0.07, 0.32), item.color)
		local stex = Instance.new("Texture")
		stex.Texture = SUYUK_TEX
		stex.Face = Enum.NormalId.Top
		stex.StudsPerTileU = 0.5
		stex.StudsPerTileV = 0.32
		stex.Parent = slice
		attach(handle, slice, CFrame.new(0, 0.05, -0.45))
		tool.Grip = CFrame.new(0, 0, 0.3)
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
	sip.SoundId = "rbxassetid://" .. tostring(if COFFEE[item.key] then COFFEE_SIP else EAT_SOUND[kind] or ClubConfig.GulpSoundId)
	-- coffee twice as loud, bagel and 소금빵 half (user 2026-10-30)
	sip.Volume = if COFFEE[item.key] then 0.9 elseif QUIET[item.key] then 0.35 else 0.7
	sip.RollOffMaxDistance = 40
	sip.Parent = handle
	markEdible(tool, handle)
	-- soup and noodles: the surface sinks a third of the bowl per bite
	local surface = (kind == "bowl" or kind == "ricebowl" or kind == "noodle") and handle:FindFirstChild("Fill")
	if surface then surface:SetAttribute("EatDrop", if kind == "noodle" then 0.5 else 0.3) end
	tool.Activated:Connect(function() bite(tool, item) end)
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

local function placePlate(player: Player, tablePart: BasePart, item: SnackConfig.Item)
	local servings = item.share or 6
	-- (the real top: round tables are turned cylinders, whose Size.Y is the
	-- diameter, so a cake floated above them, user 2026-10-27)
	local c, s = tablePart.CFrame, tablePart.Size
	local top = tablePart.Position + Vector3.new(0, math.abs(c.RightVector.Y) * s.X / 2 + math.abs(c.UpVector.Y) * s.Y / 2 + math.abs(c.LookVector.Y) * s.Z / 2, 0)
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
	for i = 1, (if cake then 0 else servings) do
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
	-- label
	local info = Instance.new("BillboardGui")
	info.Name = "Info"
	info.Size = UDim2.fromOffset(190, 24)
	info.StudsOffset = Vector3.new(0, 2.2, 0)
	info.MaxDistance = 30
	info.Adornee = dish
	info.Parent = plate
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 0.35
	text.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = info
	local pieceWord = if item.kind == "cake" then "조각" else "점"
	local baseName = string.gsub(item.name, "%s*%(.*%)", "")
	local function refresh()
		text.Text = string.format("%s · %s님 · 남은 %d%s", baseName, player.DisplayName, plate:GetAttribute("Servings") :: number, pieceWord)
	end
	refresh()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePiecePrompt"
	prompt.ActionText = "한 " .. pieceWord .. " 먹기"
	prompt.ObjectText = baseName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = dish
	prompt.Triggered:Connect(function(who)
		if handsFull(who) then
			local notify = Remotes:FindFirstChild("SnackNotify") :: RemoteEvent?
			if notify then notify:FireClient(who, "Toast", string.format("손에 %d개까지 들 수 있어요. 먼저 드세요!", SnackConfig.MaxCarried)) end
			return
		end
		local left = (plate:GetAttribute("Servings") :: number) - 1
		if left < 0 then return end
		plate:SetAttribute("Servings", left)
		local piece = table.remove(pieces)
		if piece then piece:Destroy() end
		-- the lettering goes with the first cut
		if lettering then
			lettering:Destroy()
			lettering = nil
		end
		-- a piece is eaten in three bites like everything in the hand (a cake slice keeps the cake's texture)
		local pieceItem: any = table.clone(item)
		pieceItem.sliceTexture = plate:GetAttribute("CakeTexture")
		-- (a 수육 slice is one bite: six bites a plate, user 2026-10-27)
		if item.kind == "plate" then pieceItem.oneBite = true end
		giveTool(who, makeTool(pieceItem, baseName .. " 한 " .. pieceWord))
		if left <= 0 then plate:Destroy() else refresh() end
	end)
	plate.Parent = tablePart
	Debris:AddItem(plate, SnackConfig.PlateSeconds)
end

-- a plate held in the hand when no table was near: click next to a table to put it down
local function plateTool(player: Player, item: SnackConfig.Item): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = "테이블 가까이에서 클릭(터치)하면 테이블에 놓아요"
	tool.CanBeDropped = false
	local handle = part("Handle", Vector3.new(1.4, 0.4, 1.4), item.color)
	handle.Parent = tool
	if item.kind == "plate" then
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
	end	tool.Activated:Connect(function()
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
local function grantProduct(player: Player, item: SnackConfig.Item): (boolean, string?)
	local notify = Remotes:FindFirstChild("SnackNotify") :: RemoteEvent?
	if item.share then
		-- 수육 goes to the backpack first; the buyer puts it on a table by
		-- clicking next to one (user 2026-10-30: "why is it on the table at once")
		local t = if item.kind == "plate" then nil else nearestTable(player)
		if t then
			placePlate(player, t, item)
			if notify then notify:FireClient(player, "Toast", "🍰 테이블에 놓았어요! 모두 한 조각씩 가져갈 수 있어요.") end
		else
			local backpack = player:FindFirstChildOfClass("Backpack")
			if not backpack then return false, nil end
			plateTool(player, item).Parent = backpack
			if notify then notify:FireClient(player, "Toast", item.name .. " 인벤토리에 넣었어요! 테이블 옆에서 클릭하면 접시를 놓아요.") end
		end
		return true, nil
	end
	-- a single serving (the parfait): it may go over the hand limit, it is paid
	if not giveTool(player, makeTool(item)) then return false, nil end
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
	if item.product and not item.coins then return false, "Robux 결제로 주문해요." end
	if not nearShop(player, shop.key) then return false, "카운터 가까이에서 주문해 주세요." end
	-- a shared cake bought with coins (the strawberry cake: 💰 or R$)
	if item.share then
		local price = item.coins or 0
		if not economy or not economy.Spend(player, price) then
			local balance = if economy then economy.Balance(player) else 0
			return false, string.format("%s이 부족해요 (%d 필요, 지금 %d).", EconomyConfig.CurrencyName, price, balance)
		end
		grantProduct(player, item)
		payBeep(player, shop.key)
		return true, nil
	end
	if handsFull(player) then
		return false, string.format("손에 %d개까지 들 수 있어요. 먼저 드세요!", SnackConfig.MaxCarried)
	end
	if not player:FindFirstChildOfClass("Backpack") then return false, "잠시 후 다시 시도해 주세요." end
	-- the cafe staff makes the free drinks (their job only knows cups)
	if orderHandler and not item.coins and item.kind == "cup" then
		local handled, message = orderHandler(player, shop, item)
		if handled then return true, message end
	end
	local price = item.coins or 0
	if price > 0 then
		if not economy or not economy.Spend(player, price) then
			local balance = if economy then economy.Balance(player) else 0
			return false, string.format("%s이 부족해요 (%d 필요, 지금 %d).", EconomyConfig.CurrencyName, price, balance)
		end
	end
	giveTool(player, makeTool(item))
	payBeep(player, shop.key)
	local drink = item.kind == "cup" or item.kind == "bottle"
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
local function spoonful(player: Player, model: Model, copy: BasePart, tool: Tool, item: SnackConfig.Item)
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
		local bundle = part("Noodles", Vector3.new(0.16, 0.3, 0.12), Color3.fromRGB(245, 215, 130))
		local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = bundle
		attach(handle, bundle, CFrame.new(0.03, 0.42, -0.02))
	else
		spoon.Name = "숟가락"
		handle = part("Handle", Vector3.new(0.07, 0.75, 0.05), Color3.fromRGB(215, 218, 222), Enum.Material.Metal)
		handle.Parent = spoon
		attach(handle, part("Scoop", Vector3.new(0.24, 0.05, 0.3), Color3.fromRGB(215, 218, 222), Enum.Material.Metal), CFrame.new(0, 0.38, -0.1))
		attach(handle, part("Soup", Vector3.new(0.2, 0.04, 0.24), item.color), CFrame.new(0, 0.42, -0.1))
	end
	spoon.Grip = CFrame.new(0, -0.3, 0)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring((if item.kind == "bowl" then gukbapClip() else nil) or EAT_SOUND[item.kind] or EAT_SOUND.bowl)
	sound.Volume = 0.7
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
	-- the hand takes the spoon up to the mouth (IK, see bite); R6: the spoon moves
	local ik = character:FindFirstChild("RightUpperArm") ~= nil
	local up = if ik then nil else mouthGrip(character, 0)
	if up then TweenService:Create(spoon, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Grip = up }):Play() end
	-- (a moment in the hand first, so the spoon is seen coming from the bowl)
	task.wait(0.25)
	character:SetAttribute("Eating", true)
	task.wait(0.35)
	sound:Play()
	task.wait(1.1)
	character:SetAttribute("Eating", nil)
	if up and spoon.Parent then TweenService:Create(spoon, TweenInfo.new(0.3), { Grip = CFrame.new(0, -0.3, 0) }):Play() end
	task.wait(0.4)
	spoon:Destroy()
	for _, d in ipairs(own) do d.Transparency = 0 end
	model:SetAttribute("Busy", nil)
	local total = bitesOf(item)
	local left = ((tool:GetAttribute("Bites") :: number?) or total) - 1
	tool:SetAttribute("Bites", left)
	local fill = copy:FindFirstChild("Fill")
	if fill and fill:IsA("BasePart") then
		local drop = (fill:GetAttribute("EatDrop") :: number?) or 0.3
		fill.CFrame -= Vector3.new(0, drop / total, 0)
	end
	if left <= 0 then model:Destroy() end
end
local function putDown(player: Player, tablePart: any): (boolean, string?)
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
	if not root or not tool or not tool:GetAttribute("Snack") then return false, "손에 든 음식이 없어요." end
	if tool:GetAttribute("Busy") or tool:GetAttribute("CafeOrder") then return false, "먹는 중이에요." end
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
	local model = Instance.new("Model")
	model.Name = "PlacedFood"
	copy.Parent = model
	-- rest its lowest point on the table top
	local box, size = model:GetBoundingBox()
	local lift = hit.Position.Y + 0.02 - (box.Y - size.Y / 2)
	for _, p in ipairs(parts) do p.CFrame += Vector3.new(0, lift, 0) end
	-- 국밥 on the table is the tray set (user 2026-10-27: store #2, rice and
	-- side dishes round the bowl); the copy stays as the invisible holder of
	-- the prompt
	local placedItem = itemByKey(tool:GetAttribute("Snack"))
	local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
	local tray = placedItem and placedItem.kind == "bowl" and art and art:FindFirstChild("Foods") and art.Foods:FindFirstChild("GukbapTray")
	if tray then
		for _, p in ipairs(parts) do
			p.Transparency = 1
			for _, d in ipairs(p:GetDescendants()) do if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end end
		end
		local t = tray:Clone()
		local _, tsize = t:GetBoundingBox()
		-- (its bowl as big as the one in the hand, user 2026-10-27: was smaller)
		t:ScaleTo(t:GetScale() * 3.4 / math.max(tsize.X, tsize.Z))
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
	tool.Parent = keptFolder
	local item = itemByKey(tool:GetAttribute("Snack"))
	local soup = item ~= nil and (item.kind == "bowl" or item.kind == "ricebowl" or item.kind == "noodle") -- (컵라면 too: chopsticks, 2026-10-27)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if soup then (if item and item.kind == "noodle" then "먹기" else "떠먹기") else "다시 들기"
	prompt.ObjectText = tool.Name
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = copy
	prompt.Triggered:Connect(function(who)
		if who ~= player or not model.Parent then return end
		if soup and item then
			-- 국밥 stays on the table (user 2026-10-26): eaten from there with a
			-- spoon, never picked up again
			spoonful(player, model, copy, tool, item)
		elseif giveTool(player, tool) then
			model:Destroy()
		end
	end)
	model.Parent = tablePart
	model.Destroying:Connect(function()
		if tool.Parent == keptFolder then tool:Destroy() end
	end)
	-- (a bowl left behind goes sooner: its owner may have walked off, user 2026-10-26)
	Debris:AddItem(model, if soup then SOUP_SECONDS else SnackConfig.PlateSeconds)
	return true, nil
end

function SnackService.Start(economyService: any)
	economy = economyService
	local remote = Remotes:WaitForChild("Snack") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, shopKey: any, itemKey: any)
		if action == "Buy" then return buy(player, shopKey, itemKey) end
		if action == "PutDown" then return putDown(player, shopKey) end
		return false, nil
	end
	-- food left on a table goes when its owner leaves
	Players.PlayerRemoving:Connect(function(player)
		for _, tag in ipairs(TABLE_TAGS) do
			for _, t in ipairs(CollectionService:GetTagged(tag)) do
				for _, m in ipairs(t:GetChildren()) do
					if m.Name == "PlacedFood" and m:GetAttribute("Owner") == player.UserId then m:Destroy() end
				end
			end
		end
	end)
	-- Robux menu items
	local registered: {[string]: boolean} = {}
	for _, shop in pairs(SnackConfig.Shops) do
		for _, item in ipairs(shop.items) do
			local key = item.product
			if key and not registered[key] then
				registered[key] = true
				MonetizationService.RegisterProduct(key, function(player: Player)
					return grantProduct(player, item)
				end)
			end
		end
	end
	for _, shopPart in ipairs(CollectionService:GetTagged("SnackShop")) do addPrompt(shopPart) end
	CollectionService:GetInstanceAddedSignal("SnackShop"):Connect(addPrompt)
end

return SnackService

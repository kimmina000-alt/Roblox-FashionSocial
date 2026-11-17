--!strict
-- 풍선 (D-1496, user 2026-11-16: "balloon은 balloonshop에서 파는 판매 물품 풍선에 헬륨 들어 있는 것처럼
-- 떠 있게 하고 풍선 놓으면 하늘로 떠올라가게 구현").
-- Sold at the park's balloon shop (SnackConfig.Shops.BalloonShop, kind "balloon"; SnackService.buy
-- hands the item here). The tool's handle is the hand end of the string; the balloon (the user's
-- balloon.glb sphere, ServerStorage.ArtAssets.BalloonMesh, in the item's colour) is its own little
-- assembly on a RopeConstraint, lifted a bit more than its weight (VectorForce) and gently damped
-- (LinearVelocity with a weak force), so it floats over the head and sways as the holder walks.
-- A click / tap (tool.Activated) lets go: the tool goes away and a free balloon with a short string
-- tail rises into the sky, drifting, and fades out.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")

local BalloonService = {}

local HEIGHT = 2.2 -- (studs, the balloon's own height)
local ROPE = 6 -- (studs of string from the hand; 4.6 until D-1599)
local LIFT = 1.0 -- (× its weight: just floats; was 1.6, D-1599 the follow below lifts it)
-- (D-1599, user 2026-11-17: "풍선 너무 정신사납게 흔들리더라 막 움직이는 거 움직임 좀 줄이고 천천히 움직이게
-- 수정") it hung on the string pulled up by 1.6× its weight with a weak brake, so every step of the
-- holder yanked it about and it spun. Now it floats (lift = its weight) and is drawn softly to a
-- point over the holder's hand side (AlignPosition: slow, at most FOLLOW_SPEED studs / s) and kept
-- upright (AlignOrientation), so it trails a little behind and settles calmly; the string stays as
-- the visible tie (a little slack, so it no longer jerks).
local FOLLOW_SPEED = 7
local FOLLOW_RESPONSE = 0.8 -- (Play 2026-11-17: trails about 2 studs while walking, settles in 1.5 s)
local RISE = 7 -- (studs / s when let go)
local DOUBLE_TAP = 0.45 -- (seconds between the two taps that let go, D-1652)
local STILL_AFTER = 1.5 -- (seconds standing still before the balloon is held still, D-1651)
local FLY_SECONDS = 14

local function template(): MeshPart?
	local art = ServerStorage:FindFirstChild("ArtAssets")
	local src = art and art:FindFirstChild("BalloonMesh")
	if not src then return nil end
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("MeshPart") and d.Name == "Sphere" then return d end
	end
	return nil
end

local function makeBalloon(color: Color3): BasePart
	local src = template()
	local b: BasePart
	if src then
		local m = src:Clone()
		m.Size = src.Size * (HEIGHT / src.Size.Y)
		b = m
	else
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(HEIGHT * 0.82, HEIGHT, HEIGHT * 0.82)
		b = p
	end
	b.Name = "Balloon"
	b.Color = color
	b.Material = Enum.Material.SmoothPlastic
	b.Reflectance = 0.12
	b.Anchored = false
	b.CanCollide = false
	b.CanTouch = false
	b.CanQuery = false
	b.CastShadow = true
	b.CustomPhysicalProperties = PhysicalProperties.new(0.02, 0, 0)
	return b
end

-- lift it (the weight × LIFT) and damp it a little, so it hangs up on its string
local function float(b: BasePart, extra: number)
	local att = Instance.new("Attachment")
	att.Name = "LiftPoint"
	att.Parent = b
	local mass = b:GetMass()
	local g = workspace.Gravity
	local up = Instance.new("VectorForce")
	up.Name = "Lift"
	up.Attachment0 = att
	up.RelativeTo = Enum.ActuatorRelativeTo.World
	up.ApplyAtCenterOfMass = true
	up.Force = Vector3.new(0, mass * g * extra, 0)
	up.Parent = b
	local drag = Instance.new("LinearVelocity")
	drag.Name = "Drag"
	drag.Attachment0 = att
	drag.RelativeTo = Enum.ActuatorRelativeTo.World
	drag.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drag.VectorVelocity = Vector3.zero
	drag.MaxForce = mass * g * 0.35
	drag.Parent = b
	-- (D-1599) upright and not spinning
	local upright = Instance.new("AlignOrientation")
	upright.Name = "Upright"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.Attachment0 = att
	upright.CFrame = CFrame.new()
	upright.Responsiveness = 4
	upright.MaxTorque = mass * g * 20
	upright.Parent = b
end

-- (D-1599) the soft follow to a point over the holder's hand side (an attachment on their root part,
-- which stays level while the arms swing)
local function follow(b: BasePart, character: Model?)
	local old = b:FindFirstChild("Follow")
	if old then old:Destroy() end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local target = root:FindFirstChild("BalloonTarget") :: Attachment?
	if not target then
		target = Instance.new("Attachment")
		target.Name = "BalloonTarget"
		target.Position = Vector3.new(1.4, ROPE - 2.2, 0.6) -- (beside and a bit behind the right hand, the string a little slack)
		target.Parent = root
	end
	local mass = b:GetMass()
	local align = Instance.new("AlignPosition")
	align.Name = "Follow"
	align.Mode = Enum.PositionAlignmentMode.TwoAttachment
	align.Attachment0 = b:FindFirstChild("LiftPoint") :: Attachment
	align.Attachment1 = target
	align.ApplyAtCenterOfMass = true
	align.Responsiveness = FOLLOW_RESPONSE
	align.MaxVelocity = FOLLOW_SPEED
	align.MaxForce = mass * workspace.Gravity * 1.2
	align.Parent = b
end

local function letGo(player: Player, tool: Tool, balloon: BasePart)
	local at = balloon.Position
	local color = balloon.Color
	tool:Destroy()
	local free = makeBalloon(color)
	free.CFrame = CFrame.new(at)
	free.Parent = workspace
	-- a short string tail under it
	local tail = Instance.new("Part")
	tail.Name = "BalloonTail"
	tail.Size = Vector3.new(0.06, 1.6, 0.06)
	tail.Color = Color3.new(1, 1, 1)
	tail.Material = Enum.Material.SmoothPlastic
	tail.CanCollide, tail.CanTouch, tail.CanQuery, tail.Massless = false, false, false, true
	tail.CFrame = free.CFrame * CFrame.new(0, -free.Size.Y / 2 - 0.8, 0)
	tail.Parent = free
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = free, tail
	weld.Parent = tail
	local att = Instance.new("Attachment")
	att.Parent = free
	local rise = Instance.new("LinearVelocity")
	rise.Attachment0 = att
	rise.RelativeTo = Enum.ActuatorRelativeTo.World
	rise.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	local a = math.random() * math.pi * 2
	rise.VectorVelocity = Vector3.new(math.cos(a) * 1.2, RISE, math.sin(a) * 1.2)
	rise.MaxForce = math.huge
	rise.Parent = free
	free:SetNetworkOwner(nil)
	task.delay(FLY_SECONDS - 2, function()
		if free.Parent then
			TweenService:Create(free, TweenInfo.new(2), { Transparency = 1 }):Play()
			TweenService:Create(tail, TweenInfo.new(2), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(free, FLY_SECONDS)
end

-- a balloon tool for the player, in their hand
function BalloonService.give(player: Player, name: string, color: Color3): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return nil end
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = "두 번 누르면 손을 놓아요" -- (D-1652)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Balloon", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, true
	handle.Parent = tool
	local hand = Instance.new("Attachment")
	hand.Name = "StringHand"
	hand.Parent = handle
	local balloon = makeBalloon(color)
	balloon.Parent = tool
	local knot = Instance.new("Attachment")
	knot.Name = "StringKnot"
	knot.Position = Vector3.new(0, -balloon.Size.Y / 2, 0)
	knot.Parent = balloon
	local rope = Instance.new("RopeConstraint")
	rope.Name = "String"
	rope.Attachment0, rope.Attachment1 = hand, knot
	rope.Length = ROPE
	rope.Visible = true
	rope.Thickness = 0.04
	rope.Color = BrickColor.new("White")
	rope.Parent = handle
	float(balloon, LIFT)
	tool.Equipped:Connect(function()
		-- up over the hand again, and the holder's machine moves it (smooth swaying)
		-- (D-1544, user 2026-11-16: "풍선 받으면 왜 밖으로 스폰되지") when the tool is equipped its
		-- handle is not on the hand yet (the grip weld comes a moment later): the balloon was put over
		-- the handle's old place, far off near the map's middle, and the string yanked the holder
		-- that way (out of the park through the gate). Now: over the HAND, the string slack until the
		-- grip is there, then placed once more.
		local character = tool.Parent
		local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
		local at = if hand and hand:IsA("BasePart") then hand.Position else handle.Position
		rope.Enabled = false
		balloon.CFrame = CFrame.new(at + Vector3.new(0, ROPE, 0))
		balloon.AssemblyLinearVelocity = Vector3.zero
		pcall(function() balloon:SetNetworkOwner(player) end)
		task.delay(0.2, function()
			if tool.Parent ~= character or not balloon.Parent then return end
			local over = handle.Position
			if hand and hand:IsA("BasePart") and (over - hand.Position).Magnitude > 4 then over = hand.Position end
			balloon.CFrame = CFrame.new(over + Vector3.new(0, ROPE, 0))
			balloon.AssemblyLinearVelocity = Vector3.zero
			rope.Enabled = true
			follow(balloon, character :: Model)
		end)
	end)
	tool.Unequipped:Connect(function()
		local f = balloon:FindFirstChild("Follow")
		if f then f:Destroy() end
	end)
	-- (D-1652, user 2026-11-17: "풍선 화면 두번 터치하면 날아가는 걸로 수정") two taps within
	-- DOUBLE_TAP seconds let go (one tap did, and a tap meant for the camera or a button lost it)
	local lastTap = 0
	tool.Activated:Connect(function()
		local t = os.clock()
		if t - lastTap > DOUBLE_TAP then
			lastTap = t
			return
		end
		lastTap = 0
		if tool.Parent and balloon.Parent then letGo(player, tool, balloon) end
	end)
	-- (D-1651, user 2026-11-17: "가만히 서 있을 때는 풍선 안 움직이게 수정") once the holder has
	-- stood still for STILL_AFTER seconds the brake (Drag) gets strong, so the balloon stays put;
	-- it lets go as soon as they move again
	task.spawn(function()
		local drag = balloon:FindFirstChild("Drag") :: LinearVelocity?
		local mass = balloon:GetMass() * workspace.Gravity
		local stillFor = 0
		while tool.Parent and balloon.Parent and drag do
			task.wait(0.25)
			local character = tool.Parent
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local moving = not (root and root:IsA("BasePart")) or not character:IsA("Model")
				or root.AssemblyLinearVelocity.Magnitude > 0.6 or root.AssemblyAngularVelocity.Magnitude > 0.5 -- (turning on the spot too)
			stillFor = if moving then 0 else stillFor + 0.25
			local brake = if stillFor >= STILL_AFTER then mass * 8 else mass * 0.35
			if drag.MaxForce ~= brake then drag.MaxForce = brake end
		end
	end)
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(tool) end
	return tool
end

return BalloonService

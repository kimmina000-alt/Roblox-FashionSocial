--!strict
-- Beach ball throwing on this screen (D-1029, BeachBallService): with the ball
-- in hand a tap / click throws it at the point pressed; hit by a ball, this
-- player's character is pushed and falls over for a moment.
-- (D-1048, user 2026-11-09: "비치볼 꾹 누르고 있으면 누르고 있는만큼 멀리 힘있게
-- 날아가게 해 줘. 포물선 그리면서 실제 비치볼 던졌을 때 보이는 물리적 액션과 모션
-- 적용해") Press and hold = "Charge" (a power bar over the head on this screen
-- only), let go = "Throw" toward the point under the finger / the mouse. The
-- throwing arm, on every screen: the server sets the character attributes
-- BallCharge (server time pressed) and BallThrow / BallPower (let go); the
-- right arm (IKControl, like EatMotionController) winds up behind the
-- shoulder, deeper the longer it is held, the upper body turning back with it,
-- then swings over the shoulder and through toward the front, and the ball
-- leaves the hand at the end of the swing (the server's RELEASE_DELAY).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("BeachBall") :: RemoteEvent
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local CHARGE_FULL = 1.5 -- (BeachBallService)
local SWING = 0.14 -- seconds: wind-up → through, the ball goes at its end
local FOLLOW = 0.45 -- seconds after the swing: the arm comes back down

-- ---------------------------------------------------------------------------
-- the power bar (this screen only)
local gauge: BillboardGui? = nil
local gaugeFill: Frame? = nil
local chargingSince: number? = nil

local function showGauge(on: boolean)
	if not on then
		if gauge then gauge:Destroy() end
		gauge, gaugeFill = nil, nil
		return
	end
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	if gauge then gauge:Destroy() end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BeachBallPower"
	gui.Size = UDim2.fromOffset(84, 12)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = back
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Thickness = 1.5
	s.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
	fill.Parent = back
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(1, 0)
	c2.Parent = fill
	gui.Adornee = head
	gui.Parent = player:WaitForChild("PlayerGui")
	gauge, gaugeFill = gui, fill
end

local function hook(tool: Instance)
	if not tool:IsA("Tool") or not tool:GetAttribute("BeachBall") or tool:GetAttribute("Hooked") then return end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		if chargingSince then return end
		chargingSince = os.clock()
		showGauge(true)
		Remote:FireServer("Charge")
	end)
	local function release()
		local since = chargingSince
		if not since then return end
		chargingSince = nil
		showGauge(false)
		if tool.Parent ~= player.Character then return end
		-- the point under the tap / the mouse; nothing there (the sky) → far ahead
		local camera = workspace.CurrentCamera
		local target = mouse.Hit.Position
		if (target - camera.CFrame.Position).Magnitude > 300 then
			target = camera.CFrame.Position + mouse.UnitRay.Direction * 80
		end
		local power = math.clamp((os.clock() - since) / CHARGE_FULL, 0, 1)
		task.delay(SWING * 0.6, function() Sfx.play("whoosh", 0.25 + 0.3 * power) end)
		Remote:FireServer("Throw", target)
	end
	tool.Deactivated:Connect(release)
	tool.Unequipped:Connect(function()
		chargingSince = nil
		showGauge(false)
	end)
end

local function onCharacter(character: Model)
	chargingSince = nil
	showGauge(false)
	for _, d in ipairs(character:GetChildren()) do hook(d) end
	character.ChildAdded:Connect(hook)
end
if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

-- ---------------------------------------------------------------------------
-- the throwing arm (every character)
type Rig = {
	arm: IKControl, body: IKControl?, holder: Part, goal: Attachment, pole: Attachment, bodyGoal: Attachment,
	rest: CFrame, -- the hand with the ball held out, in the root's space
	wind: number, -- how far wound up, 0..1, now
	from: CFrame?, -- (in the swing) the hand where the swing started, root space
}
local rigs: {[Model]: Rig} = {}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function makeRig(character: Model): Rig?
	local rig = rigs[character]
	if rig then return rig end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upper, hand = character:FindFirstChild("RightUpperArm"), character:FindFirstChild("RightHand")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not upper or not hand or not hand:IsA("BasePart") or not root or not root:IsA("BasePart") then return nil end
	local holder = Instance.new("Part")
	holder.Name = "BallThrowTarget"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.identity
	holder.Parent = workspace
	local goal = Instance.new("Attachment")
	goal.Parent = holder
	goal.WorldCFrame = hand.CFrame
	local pole = Instance.new("Attachment")
	pole.Parent = holder
	local bodyGoal = Instance.new("Attachment")
	bodyGoal.Parent = holder
	local arm = Instance.new("IKControl")
	arm.Name = "BallThrowArm"
	-- (Position: with Transform the hand kept the held-out turn, so behind the
	-- shoulder the arm locked straight back like a stick in the first Play test)
	arm.Type = Enum.IKControlType.Position
	arm.ChainRoot = upper
	arm.EndEffector = hand
	arm.Target = goal
	arm.Pole = pole
	arm.SmoothTime = 0
	arm.Weight = 1
	arm.Parent = humanoid
	-- the upper body turns with the arm (LowerTorso → UpperTorso)
	local lower, torso = character:FindFirstChild("LowerTorso"), character:FindFirstChild("UpperTorso")
	local body: IKControl? = nil
	if lower and torso and torso:IsA("BasePart") then
		bodyGoal.WorldCFrame = torso.CFrame
		local b = Instance.new("IKControl")
		b.Name = "BallThrowBody"
		b.Type = Enum.IKControlType.Rotation
		b.ChainRoot = lower
		b.EndEffector = torso
		b.Target = bodyGoal
		b.SmoothTime = 0
		b.Weight = 0
		b.Parent = humanoid
		body = b
	end
	rig = {
		arm = arm, body = body, holder = holder, goal = goal, pole = pole, bodyGoal = bodyGoal,
		rest = root.CFrame:ToObjectSpace(hand.CFrame), wind = 0,
	}
	rigs[character] = rig
	return rig
end

local function removeRig(character: Model)
	local rig = rigs[character]
	if not rig then return end
	rigs[character] = nil
	rig.arm:Destroy()
	if rig.body then rig.body:Destroy() end
	rig.holder:Destroy()
end

local function watch(character: Model)
	local function update()
		if character:GetAttribute("BallCharge") or character:GetAttribute("BallThrow") then makeRig(character) end
	end
	character:GetAttributeChangedSignal("BallCharge"):Connect(update)
	character:GetAttributeChangedSignal("BallThrow"):Connect(update)
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then removeRig(character) end
	end)
	update()
end
local function watchPlayer(other: Player)
	if other.Character then watch(other.Character) end
	other.CharacterAdded:Connect(watch)
end
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
Players.PlayerAdded:Connect(watchPlayer)

-- root space hand positions (the root looks to -Z, right is +X)
-- wound up: up beside and a little behind the head on the right, elbow bent
-- out to the side (the pole), like a ball held back for a throw
local WIND = Vector3.new(1.5, 2.4, 1.0) -- (1.2, 2.5, 0.8: the ball sat on the head)
-- the top of the swing, over the shoulder
local OVER = Vector3.new(0.8, 2.3, -0.4)
-- let go: through, the arm long in front, a little down
local THROUGH = Vector3.new(0.45, 1.05, -2.0)
-- after: the arm down beside the body, a little ahead
local DOWN = Vector3.new(0.9, -0.6, -0.9)

local function at(rig: Rig, pos: Vector3): CFrame
	return CFrame.new(pos) * rig.rest.Rotation
end

RunService.Heartbeat:Connect(function(dt)
	-- this screen's power bar: yellow → orange → red, full at CHARGE_FULL
	if chargingSince and gaugeFill then
		local p = math.clamp((os.clock() - chargingSince) / CHARGE_FULL, 0, 1)
		gaugeFill.Size = UDim2.fromScale(p, 1)
		gaugeFill.BackgroundColor3 = if p < 0.5
			then Color3.fromRGB(255, 220, 90):Lerp(Color3.fromRGB(255, 150, 60), p * 2)
			else Color3.fromRGB(255, 150, 60):Lerp(Color3.fromRGB(255, 70, 80), (p - 0.5) * 2)
	end
	local now = workspace:GetServerTimeNow()
	for character, rig in pairs(rigs) do
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then continue end
		local chargeAt = character:GetAttribute("BallCharge")
		local throwAt = character:GetAttribute("BallThrow")
		local power = character:GetAttribute("BallPower")
		local handGoal: CFrame
		local twist, lean, bodyW = 0, 0, 0
		local swingT = if typeof(throwAt) == "number" then now - throwAt else math.huge
		if typeof(chargeAt) == "number" then
			-- winding up: quickly to a half wind-up, then deeper with the power
			local held = now - chargeAt
			local want = smooth(held / 0.35) * (0.55 + 0.45 * math.clamp(held / CHARGE_FULL, 0, 1))
			rig.wind += (want - rig.wind) * math.min(1, dt * 14)
			-- (a held ball shakes a little at full power: straining)
			local strain = if held >= CHARGE_FULL then math.sin(now * 40) * 0.04 else 0
			handGoal = rig.rest:Lerp(at(rig, WIND), rig.wind) * CFrame.new(0, strain, 0)
			rig.arm.Weight = 1
			twist, lean, bodyW = math.rad(-22) * rig.wind, math.rad(8) * rig.wind, 0.8
			rig.from = nil
		elseif swingT < SWING + FOLLOW then
			local p = if typeof(power) == "number" then power else 0
			if not rig.from then
				-- (a tap shorter than the wind-up: start from a small wind-up anyway)
				rig.wind = math.max(rig.wind, 0.35)
				rig.from = rig.rest:Lerp(at(rig, WIND), rig.wind)
			end
			local from = rig.from :: CFrame
			if swingT < SWING then
				-- the swing: speeding up (ease in), through the top over the shoulder
				local k = swingT / SWING
				k = k * k
				handGoal = if k < 0.5 then from:Lerp(at(rig, OVER), k * 2) else at(rig, OVER):Lerp(at(rig, THROUGH), (k - 0.5) * 2)
				twist = math.rad(-22) * rig.wind * (1 - k) + math.rad(20) * (0.5 + 0.5 * p) * k
				lean = math.rad(8) * rig.wind * (1 - k) + math.rad(-14) * (0.5 + 0.5 * p) * k
			else
				-- the follow-through, then down
				local k = smooth((swingT - SWING) / FOLLOW)
				handGoal = at(rig, THROUGH):Lerp(at(rig, DOWN), k)
				twist = math.rad(20) * (0.5 + 0.5 * p) * (1 - k)
				lean = math.rad(-14) * (0.5 + 0.5 * p) * (1 - k)
			end
			bodyW = 0.8
			-- (the IK lets go of the arm over the last part of the follow-through)
			rig.arm.Weight = 1 - smooth((swingT - SWING - FOLLOW * 0.6) / (FOLLOW * 0.4))
		else
			removeRig(character)
			continue
		end
		rig.goal.WorldCFrame = root.CFrame * handGoal
		-- the elbow out to the right and a little back (down in the follow-through)
		rig.pole.WorldPosition = (root.CFrame * CFrame.new(3, if typeof(chargeAt) == "number" then 1.4 else 0.2, 1.0)).Position
		if rig.body then
			rig.body.Weight = bodyW
			rig.bodyGoal.WorldCFrame = root.CFrame.Rotation * CFrame.Angles(lean, twist, 0) + root.Position
		end
	end
end)

-- ---------------------------------------------------------------------------
-- hit by a ball: pushed and down for a moment (harder from a faster ball)
local falling = false
Remote.OnClientEvent:Connect(function(action, dir, speed)
	if action ~= "Hit" or typeof(dir) ~= "Vector3" then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return end
	-- sitting, riding a tube or a ride (anchored), or already down: nothing
	if falling or humanoid.Sit or root.Anchored or humanoid:GetState() == Enum.HumanoidStateType.Swimming then return end
	falling = true
	local s = if typeof(speed) == "number" then math.clamp(speed / 60, 0.4, 1.2) else 1
	root.AssemblyLinearVelocity = dir * (22 * s) + Vector3.new(0, 10 + 6 * s, 0)
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	task.delay(1.3, function()
		falling = false
		if humanoid.Parent and humanoid.Health > 0 then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
	end)
end)

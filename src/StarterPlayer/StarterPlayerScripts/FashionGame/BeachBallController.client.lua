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

-- (D-1089, user 2026-11-09: "비치볼 잡아서 던지는 거 모바일 버전에서 제대로 안 됨.
-- 화면 꾹 누르면 던지는 강도 올라가는 바 보여지게 하기. 던질 곳 + 이런 총 쏠 때
-- 보여주는 것처럼 던져질 곳 표시하기. 총 쏘거나 물건 던져서 사람이나 목표물 맞히는
-- 게임 조사해서 참고해서 그대로 매끄럽게 구현할 것") The tool's own Activated /
-- Deactivated did not give a hold on phones (a tap is both at once). Now, like
-- mobile shooters and grenade throws in other games:
--   * with the ball in hand the aim is shown all the time: a "+" in the middle
--     of the screen on phones (drag the screen to turn the camera = aim), the
--     mouse pointer on PC; the arc the ball will fly (dots) and a ring where it
--     will land, drawn from the very launch the server uses (BeachBallConfig)
--   * press and hold anywhere that is not a button or the move stick: a power
--     bar at the bottom of the screen fills (1.5 s to full) and the arc grows
--     with it; let go: thrown, with that power, toward the aim
-- The press is read here (UserInputService), the tool takes no taps itself
-- (ManualActivationOnly, BeachBallService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remote = FashionGame:WaitForChild("Remotes"):WaitForChild("BeachBall") :: RemoteEvent
local BeachBallConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("BeachBallConfig"))

local CHARGE_FULL = BeachBallConfig.CHARGE_FULL
local SWING = 0.14 -- seconds: wind-up → through, the ball goes at its end
local FOLLOW = 0.45 -- seconds after the swing: the arm comes back down
local DOTS = 22 -- dots along the arc
local AIM_COLOR = Color3.fromRGB(255, 255, 255)
local HOT_COLOR = Color3.fromRGB(255, 90, 80)

-- ---------------------------------------------------------------------------
-- the screen parts: power bar (bottom middle), "+" (phones)
local screen = Instance.new("ScreenGui")
screen.Name = "BeachBallAim"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 30
screen.Enabled = false
screen.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.Name = "Power"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -118)
bar.Size = UDim2.fromOffset(240, 18)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
bar.BackgroundTransparency = 0.2
bar.Visible = false
bar.Parent = screen
do
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = bar
	local s = Instance.new("UIStroke") s.Color = Color3.new(1, 1, 1) s.Thickness = 2 s.Parent = bar
end
local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BorderSizePixel = 0
barFill.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
barFill.Parent = bar
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = barFill end
local barText = Instance.new("TextLabel")
barText.AnchorPoint = Vector2.new(0.5, 1)
barText.Position = UDim2.new(0.5, 0, 0, -4)
barText.Size = UDim2.fromOffset(240, 18)
barText.BackgroundTransparency = 1
barText.Font = Enum.Font.GothamBlack
barText.TextSize = 14
barText.TextColor3 = Color3.new(1, 1, 1)
barText.TextStrokeTransparency = 0.4
barText.Text = "힘"
barText.Parent = bar

local cross = Instance.new("TextLabel")
cross.Name = "Cross"
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Size = UDim2.fromOffset(36, 36)
cross.BackgroundTransparency = 1
cross.Font = Enum.Font.GothamBold
cross.TextSize = 34
cross.TextColor3 = AIM_COLOR
cross.TextStrokeTransparency = 0.3
cross.Text = "+"
cross.Visible = false
cross.Parent = screen

-- the arc and the landing ring (in the world, this screen only)
local marks = Instance.new("Folder")
marks.Name = "BeachBallAimMarks"
local dots: {BasePart} = {}
for i = 1, DOTS do
	local d = Instance.new("Part")
	d.Name = "Dot"
	d.Shape = Enum.PartType.Ball
	d.Size = Vector3.one * 0.32
	d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
	d.Material = Enum.Material.Neon
	d.Color = AIM_COLOR
	d.Transparency = 1
	d.Parent = marks
	dots[i] = d
end
local ring = Instance.new("Part")
ring.Name = "Landing"
ring.Shape = Enum.PartType.Cylinder
ring.Size = Vector3.new(0.12, 3.2, 3.2)
ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
ring.Material = Enum.Material.Neon
ring.Color = AIM_COLOR
ring.Transparency = 1
ring.Parent = marks
local ringInner = ring:Clone()
ringInner.Name = "LandingInner"
ringInner.Size = Vector3.new(0.14, 2.5, 2.5)
ringInner.Color = Color3.fromRGB(20, 20, 26)
ringInner.Parent = marks
marks.Parent = workspace

local function hideMarks()
	for _, d in ipairs(dots) do d.Transparency = 1 end
	ring.Transparency, ringInner.Transparency = 1, 1
end

-- ---------------------------------------------------------------------------
local heldTool: Tool? = nil
local chargingSince: number? = nil
local pressInput: InputObject? = nil

local function touchMode(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- where the throw aims: the middle of the screen on phones, the mouse on PC
local function aimPoint(): Vector3
	local camera = workspace.CurrentCamera
	local ray
	if touchMode() then
		local vp = camera.ViewportSize
		ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	else
		ray = mouse.UnitRay
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, marks }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if hit then return hit.Position end
	-- (the sky) far ahead along the aim
	return ray.Origin + ray.Direction * 80
end

local function power(): number
	return if chargingSince then math.clamp((os.clock() - chargingSince) / CHARGE_FULL, 0, 1) else 0
end

local function setHeld(tool: Tool?)
	heldTool = tool
	chargingSince, pressInput = nil, nil
	screen.Enabled = tool ~= nil
	bar.Visible = false
	cross.Visible = tool ~= nil and touchMode()
	if not tool then hideMarks() end
end

local function hook(tool: Instance)
	if not tool:IsA("Tool") or not tool:GetAttribute("BeachBall") or tool:GetAttribute("Hooked") then return end
	tool:SetAttribute("Hooked", true)
	tool.Equipped:Connect(function() setHeld(tool) end)
	tool.Unequipped:Connect(function() if heldTool == tool then setHeld(nil) end end)
	tool.AncestryChanged:Connect(function()
		if heldTool == tool and tool.Parent ~= player.Character then setHeld(nil) end
	end)
	if tool.Parent == player.Character then setHeld(tool) end
end

local function onCharacter(character: Model)
	setHeld(nil)
	for _, d in ipairs(character:GetChildren()) do hook(d) end
	character.ChildAdded:Connect(hook)
end
if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

-- press: anywhere that is not a button / the move stick (processed)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not heldTool or chargingSince then return end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
	-- (D-1275, user 2026-11-11: "비치볼 잡고 던질 때 모바일 버전에서 왼쪽 이동키 부분 제외하고
	-- 오른쪽 누르면 파워 충전. 공 들고 돌아다닐 수 있게 왼쪽은 비워.") on a phone the left
	-- half is the move stick's (Roblox's dynamic stick starts anywhere there):
	-- only a press on the right half charges
	if t == Enum.UserInputType.Touch then
		local camera = workspace.CurrentCamera
		if camera and input.Position.X < camera.ViewportSize.X * 0.5 then return end
	end
	chargingSince = os.clock()
	pressInput = input
	bar.Visible = true
	Remote:FireServer("Charge")
end)
local function release()
	local tool = heldTool
	if not chargingSince or not tool then return end
	local p = power()
	chargingSince, pressInput = nil, nil
	bar.Visible = false
	if tool.Parent ~= player.Character then return end
	-- (D-1284, user 2026-11-11: "비치볼 던질 때 슉 소리 빼고") no whoosh on the throw
	Remote:FireServer("Throw", aimPoint(), p)
	hideMarks()
end
UserInputService.InputEnded:Connect(function(input)
	if not chargingSince then return end
	if input == pressInput or (pressInput and input.UserInputType == pressInput.UserInputType and input.UserInputType == Enum.UserInputType.MouseButton1) then
		release()
	end
end)

-- the aim, the arc and the bar every frame while the ball is in hand
RunService.RenderStepped:Connect(function()
	local tool = heldTool
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not tool or not root or not head then return end
	local p = power()
	if chargingSince then
		barFill.Size = UDim2.fromScale(math.max(p, 0.02), 1)
		barFill.BackgroundColor3 = if p < 0.5
			then Color3.fromRGB(255, 220, 90):Lerp(Color3.fromRGB(255, 150, 60), p * 2)
			else Color3.fromRGB(255, 150, 60):Lerp(HOT_COLOR, (p - 0.5) * 2)
		barText.Text = if p >= 1 then "최대!" else string.format("힘 %d%%", math.floor(p * 100))
	end
	-- the arc of a throw with this power now (a soft toss while not pressed)
	local from, velocity = BeachBallConfig.launch(root.CFrame, head.Position, aimPoint(), p)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance, marks }
	local points, hit = BeachBallConfig.path(from, velocity, params, 0.05, 4)
	local color = if chargingSince then AIM_COLOR:Lerp(HOT_COLOR, p) else AIM_COLOR
	local n = #points
	for i, d in ipairs(dots) do
		-- spread over the whole arc, fading toward its end; fainter when not pressed
		local k = (i - 1) / (DOTS - 1)
		local at = points[math.clamp(1 + math.floor(k * (n - 1) + 0.5), 1, n)]
		d.Position = at
		d.Color = color
		d.Transparency = (if chargingSince then 0.15 else 0.55) + 0.35 * k
	end
	if hit then
		local up = hit.Normal
		local side = if math.abs(up.Y) < 0.95 then up:Cross(Vector3.yAxis).Unit else Vector3.xAxis
		-- (a cylinder's round faces are on its X axis: X along the surface's normal)
		local cf = CFrame.fromMatrix(hit.Position + up * 0.08, up, side)
		ring.CFrame = cf
		ringInner.CFrame = cf * CFrame.new(0.01, 0, 0)
		ring.Color = color
		ring.Transparency = if chargingSince then 0.1 else 0.45
		ringInner.Transparency = ring.Transparency
	else
		ring.Transparency, ringInner.Transparency = 1, 1
	end
end)

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

-- ---------------------------------------------------------------------------
-- (D-1284, user 2026-11-11: "비치볼이 바닥에 닿을 때 통통 튕기는 소리 나게 해 줘 / 반동으로
-- 몇 번 더 튕기면서 멈출 때도 소리 나야 함") every screen hears every thrown ball
-- bounce: its height is followed each frame and where it was falling and now
-- goes up, that was a bounce. Louder (and a little lower) the faster it fell,
-- so the last small bounces are soft taps until it lies still.
do
	local watched: {[BasePart]: { y: number, vy: number, at: number, sound: Sound }} = {}
	local function watch(part: Instance)
		if not part:IsA("BasePart") or part.Name ~= "ThrownBeachBall" then return end
		local sound = Instance.new("Sound")
		sound.Name = "BounceSound"
		sound.SoundId = BeachBallConfig.BOUNCE_SOUND
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = 90
		sound.Parent = part
		watched[part] = { y = part.Position.Y, vy = 0, at = 0, sound = sound }
		part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(workspace) then watched[part] = nil end
		end)
	end
	for _, child in ipairs(workspace:GetChildren()) do watch(child) end
	workspace.ChildAdded:Connect(watch)
	RunService.RenderStepped:Connect(function(dt)
		if dt <= 0 then return end
		local now = os.clock()
		for part, w in pairs(watched) do
			local y = part.Position.Y
			local vy = (y - w.y) / dt
			-- falling, then suddenly not (a turn up much sharper than the fall's
			-- own slowing in the air)
			if w.vy < -BeachBallConfig.BOUNCE_MIN_SPEED and vy > w.vy * 0.3 and now - w.at > 0.08 then
				w.at = now
				local k = math.clamp(-w.vy / BeachBallConfig.BOUNCE_FULL_SPEED, 0, 1)
				w.sound.Volume = 0.12 + 0.68 * k
				w.sound.PlaybackSpeed = 1.15 - 0.2 * k + (math.random() - 0.5) * 0.06
				w.sound.TimePosition = 0
				w.sound:Play()
			end
			w.y, w.vy = y, vy
		end
	end)
end
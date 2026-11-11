--!strict
-- Beach balls you can pick up and throw at people (D-1029, user 2026-11-08:
-- "비치볼 손에 잡고 던져서 사람 맞힐 수 있게 해").
--
-- The five balls on the sea (Workspace models BeachBall1..5, tag FloatDeco,
-- polish_1030 step 24) get a "비치볼 잡기" prompt. Picking one up hides it on
-- the water and puts a ball tool in the hand; a tap / click throws it at the
-- point pressed (BeachBallController sends it). The thrown ball is a real
-- physics ball (server owned, light and bouncy, it floats on the water); a
-- person it hits at speed falls over for a moment (their own client does it,
-- remote BeachBall "Hit"). A thrown ball can be picked up again; after 15 s
-- left alone it goes back on the sea.
-- (D-1048, user 2026-11-09: "비치볼 꾹 누르고 있으면 누르고 있는만큼 멀리 힘있게
-- 날아가게 해 줘. 포물선 그리면서 실제 비치볼 던졌을 때 보이는 물리적 액션과 모션
-- 적용해. 다른 사람 맞았을 때 보이는 퐁! 글씨 삭제") Press = "Charge" (the arm
-- winds up, character attribute BallCharge), let go = "Throw": the power is
-- how long it was held (server clock, full at CHARGE_FULL s), from a soft
-- toss of about 7 studs to about 60. The ball leaves the hand at the end of
-- the swing (RELEASE_DELAY, attribute BallThrow / BallPower for the swing on
-- every screen) and flies like a real beach ball: light, so the air slows it
-- (drag ∝ v², terminal speed DRAG_VT) and it falls softly (FLOAT_G instead of
-- the world's gravity), spinning backward, then bounces and rolls. No "퐁!".
-- Not saved in the bag (BagService only keeps its own items), and it goes back
-- when the holder leaves, dies or goes into the club.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("BeachBall") :: RemoteEvent

local BeachBallService = {}

-- (D-1089, user 2026-11-09: "비치볼 잡아서 던지는 거 모바일 버전에서 제대로 안 됨.
-- 화면 꾹 누르면 던지는 강도 올라가는 바 보여지게 하기. 던질 곳 + 이런 총 쏠 때
-- 보여주는 것처럼 던져질 곳 표시하기 ... 비치볼이니까 맞은 다음 튕기는 물리적 효과")
-- the numbers and the launch are shared with the controller (BeachBallConfig),
-- which shows the arc and where it lands before the throw; the tool takes no
-- taps of its own any more (ManualActivationOnly: the controller reads the
-- press itself, phones too); the power the screen showed is used (within what
-- the server clock allows); a ball that hits someone bounces off them.
local BeachBallConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("BeachBallConfig"))
local SHOWN = 0.25 -- (polish_1030: the balls' see-through)
local CHARGE_FULL = BeachBallConfig.CHARGE_FULL -- seconds held for full power
local RELEASE_DELAY = 0.12 -- the swing before the ball leaves the hand
local FLOAT_G = BeachBallConfig.FLOAT_G -- the ball's own fall (the world pulls 196.2)
local BOUNCE = 0.6 -- how much of its speed a ball keeps bouncing off a person
local REST_SECONDS = 15 -- a thrown ball nobody picked up goes back to the sea
local HIT_SPEED = 14 -- slower than this it only rolls into you

type Ball = {
	model: Model,
	part: BasePart, -- the ball on the water (hidden while out)
	prompt: ProximityPrompt,
	holder: Player?,
	tool: Tool?,
	thrown: BasePart?,
	thrownAt: number,
	thrower: Player?,
	hits: {[Instance]: boolean},
	chargeAt: number?,
	gauge: boolean?, -- (D-1290) charging by the swinging gauge (phones)
}
local balls: {Ball} = {}
local holding: {[Player]: Ball} = {}

local function makePrompt(parent: BasePart): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "비치볼 잡기"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = parent
	return prompt
end

-- back on the sea, free to pick up
local function putBack(ball: Ball)
	if ball.tool then ball.tool:Destroy() end
	if ball.thrown then ball.thrown:Destroy() end
	if ball.holder and holding[ball.holder] == ball then holding[ball.holder] = nil end
	if ball.holder and ball.holder.Character then ball.holder.Character:SetAttribute("BallCharge", nil) end
	ball.tool, ball.thrown, ball.holder, ball.thrower, ball.chargeAt = nil, nil, nil, nil, nil
	ball.part.Transparency = SHOWN
	ball.prompt.Enabled = true
	ball.model:SetAttribute("Out", nil)
end

local function give(ball: Ball, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or humanoid.Health <= 0 or not backpack or holding[player] then return end
	require(script.Parent:WaitForChild("Analytics")).interact(player, "BeachBall") -- (D-1124)
	if ball.thrown then ball.thrown:Destroy() ball.thrown = nil end
	ball.part.Transparency = 1
	ball.prompt.Enabled = false
	ball.model:SetAttribute("Out", true)
	local tool = Instance.new("Tool")
	tool.Name = "비치볼"
	tool.ToolTip = "꾹 누를수록 멀리 던지기"
	tool.ManualActivationOnly = true -- (D-1089: BeachBallController reads the press)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("BeachBall", true)
	local handle = ball.part:Clone()
	for _, d in ipairs(handle:GetChildren()) do d:Destroy() end
	handle.Name = "Handle"
	handle.Transparency = SHOWN
	handle.Anchored = false
	handle.CanCollide, handle.CanTouch, handle.CanQuery = false, false, false
	handle.Massless = true
	handle.Size = handle.Size * 0.7
	handle.Parent = tool
	-- sitting on top of the held-out right hand (measured in Play: the grip's
	-- -Y runs up from the palm when the arm is held out)
	tool.Grip = CFrame.new(0, -1.2, 0.2)
	tool.Parent = backpack
	ball.tool, ball.holder = tool, player
	holding[player] = ball
	humanoid:EquipTool(tool)
	-- gone from the player some other way (died, the backpack emptied): back to the sea
	tool.AncestryChanged:Connect(function()
		if ball.tool == tool and not tool:IsDescendantOf(player) and not (player.Character and tool:IsDescendantOf(player.Character)) then
			task.defer(function()
				if ball.tool == tool and not tool:IsDescendantOf(game) then putBack(ball) end
			end)
		end
	end)
end

local function hitSomeone(ball: Ball, hitPart: BasePart, velocity: Vector3)
	local model = hitPart:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not humanoid or humanoid.Health <= 0 or ball.hits[model] then return end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim and victim == ball.thrower then return end
	ball.hits[model] = true
	local dir = Vector3.new(velocity.X, 0, velocity.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	if victim then Remote:FireClient(victim, "Hit", dir, velocity.Magnitude) end
	-- (D-1089) the ball bounces off the person it hit: its speed toward them
	-- turned back (off their body's middle), a good part of it kept, a little up,
	-- spinning the other way
	local p = ball.thrown
	local body = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if p and body then
		local n = p.Position - body.Position
		n = Vector3.new(n.X, n.Y * 0.3, n.Z)
		n = if n.Magnitude > 0.1 then n.Unit else -dir
		local v = velocity
		local into = v:Dot(n)
		if into < 0 then v -= n * (2 * into) end
		p.AssemblyLinearVelocity = v * BOUNCE + Vector3.new(0, 8, 0)
		p.AssemblyAngularVelocity = -p.AssemblyAngularVelocity * 0.5
	end
end

-- (D-1048) the air on every flying ball: lift most of the world's gravity
-- off (it falls at FLOAT_G) and slow it by drag ∝ v²
-- (Play test: a soft toss landed 10 studs out and then rolled 19 more over the
-- sand) on the ground it also slows like a ball on sand: ROLL_K per second
local flying: {[BasePart]: VectorForce} = {}
local DRAG_K = BeachBallConfig.DRAG_K
local ROLL_K = 2.2
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude
groundRay.RespectCanCollide = true
game:GetService("RunService").Heartbeat:Connect(function(dt)
	for p, force in pairs(flying) do
		if not p.Parent then flying[p] = nil continue end
		local m = p.AssemblyMass
		local v = p.AssemblyLinearVelocity
		local f = Vector3.new(0, m * (workspace.Gravity - FLOAT_G), 0) - v * (v.Magnitude * DRAG_K * m)
		groundRay.FilterDescendantsInstances = { p }
		if workspace:Raycast(p.Position, Vector3.new(0, -(p.Size.Y / 2 + 0.35), 0), groundRay) then
			f -= Vector3.new(v.X, 0, v.Z) * (ROLL_K * m)
			p.AssemblyAngularVelocity *= math.max(0, 1 - ROLL_K * dt)
		end
		force.Force = f
	end
end)

local function throw(ball: Ball, player: Player, target: Vector3, shown: any)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then return end
	-- (D-1290) phones: the gauge that swings up and down (BeachBallConfig.gauge)
	local power = if not ball.chargeAt then 0
		elseif ball.gauge then BeachBallConfig.gauge(os.clock() - ball.chargeAt)
		else math.clamp((os.clock() - ball.chargeAt) / CHARGE_FULL, 0, 1)
	-- (D-1089) the power the player's screen showed (its arc), when it is close
	-- to what the server clock says (the press reaches the server a little late)
	if typeof(shown) == "number" and shown == shown then
		power = math.clamp(shown, math.max(0, power - 0.25), math.min(1, power + 0.15))
	end
	ball.chargeAt = nil
	-- the swing on every screen (BeachBallController), then the ball leaves the hand
	character:SetAttribute("BallCharge", nil)
	character:SetAttribute("BallPower", power)
	character:SetAttribute("BallThrow", workspace:GetServerTimeNow())
	local tool = ball.tool
	holding[player] = nil
	ball.holder = nil
	task.wait(RELEASE_DELAY)
	if ball.tool ~= tool or not root.Parent then return end
	if tool then tool:Destroy() end
	ball.tool = nil
	-- which way and how fast: the same launch the thrower's screen drew (BeachBallConfig)
	local from, velocity = BeachBallConfig.launch(root.CFrame, head.Position, target, power)
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	local p = ball.part:Clone()
	for _, d in ipairs(p:GetChildren()) do d:Destroy() end
	p.Name = "ThrownBeachBall"
	p.Transparency = SHOWN
	p.Anchored = false
	p.CanCollide, p.CanTouch, p.CanQuery = true, true, false
	p.Massless = false
	-- light and bouncy (density low enough to float on the sea)
	-- (friction 0.35 rolled it 25 studs over the sand after a hit: 1 with full weight)
	-- (D-1284, user 2026-11-11: "반동으로 몇 번 더 튕기면서 멈출 때") the ball's own
	-- bounce wins over the sand's (weight 100, was 1: the two were averaged and
	-- it hopped once): a few smaller and smaller bounces, then it lies still
	p.CustomPhysicalProperties = PhysicalProperties.new(0.08, 1, 0.6, 100, 100)
	-- from over the right shoulder, where the swing lets go of it, a little ahead
	p.CFrame = CFrame.new(from)
	p.Parent = workspace
	p:SetNetworkOwner(nil)
	local at = Instance.new("Attachment")
	at.Parent = p
	local force = Instance.new("VectorForce")
	force.Attachment0 = at
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	force.Parent = p
	flying[p] = force
	p.AssemblyLinearVelocity = velocity
	-- spinning backward off the fingers (a thrown ball turns over its top
	-- toward the thrower), harder with more power, a little wobble
	local back = flat:Cross(Vector3.yAxis)
	p.AssemblyAngularVelocity = back * (4 + 10 * power) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
	ball.thrown, ball.thrownAt, ball.thrower = p, os.clock(), player
	ball.hits = {}
	local prompt = makePrompt(p)
	prompt.Triggered:Connect(function(who) give(ball, who) end)
	p.Touched:Connect(function(other)
		if ball.thrown ~= p then return end
		local v = p.AssemblyLinearVelocity
		if v.Magnitude >= HIT_SPEED then hitSomeone(ball, other, v) end
	end)
end

function BeachBallService.Start()
	local function add(model: Instance)
		if not model:IsA("Model") or not model.Name:match("^BeachBall%d+$") or not model:IsDescendantOf(workspace) then return end
		for _, b in ipairs(balls) do if b.model == model then return end end
		local part = model:FindFirstChild("Ball")
		if not part or not part:IsA("BasePart") then return end
		local ball: Ball = { model = model, part = part, prompt = makePrompt(part), thrownAt = 0, hits = {} }
		ball.prompt.Triggered:Connect(function(player) give(ball, player) end)
		table.insert(balls, ball)
	end
	for _, d in ipairs(workspace:GetDescendants()) do add(d) end
	workspace.DescendantAdded:Connect(add)

	Remote.OnServerEvent:Connect(function(player, action, target, power)
		local ball = holding[player]
		local character = player.Character
		if not ball or not ball.tool or not character or ball.tool.Parent ~= character then return end
		if action == "Charge" then
			-- (D-1048) pressed: the power grows from now
			ball.chargeAt = os.clock()
			ball.gauge = target == "Gauge" -- (D-1290: the "+" tapped on a phone)
			character:SetAttribute("BallCharge", workspace:GetServerTimeNow())
			return
		end
		if action ~= "Throw" or typeof(target) ~= "Vector3" or target ~= target then return end
		throw(ball, player, target, power)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local ball = holding[player]
		if ball then putBack(ball) end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for _, ball in ipairs(balls) do
				local thrown = ball.thrown
				if thrown and (now - ball.thrownAt > REST_SECONDS or thrown.Position.Y < -60 or not thrown.Parent) then
					putBack(ball)
				elseif ball.holder then
					-- (no balls in the club: they would knock the dancers over)
					local holder = ball.holder
					local humanoid = holder.Character and holder.Character:FindFirstChildOfClass("Humanoid")
					if holder:GetAttribute("ClubInside") or not humanoid or humanoid.Health <= 0 then putBack(ball) end
				end
			end
		end
	end)
end

return BeachBallService

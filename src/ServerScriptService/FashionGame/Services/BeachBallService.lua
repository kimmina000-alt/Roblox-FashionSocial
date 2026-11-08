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
-- remote BeachBall "Hit") with "퐁!" over their head for everyone. A thrown
-- ball can be picked up again; after 15 s left alone it goes back on the sea.
-- Not saved in the bag (BagService only keeps its own items), and it goes back
-- when the holder leaves, dies or goes into the club.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("BeachBall") :: RemoteEvent

local BeachBallService = {}

local SHOWN = 0.25 -- (polish_1030: the balls' see-through)
local SPEED = 62 -- studs/s along the aim
local LIFT = 9 -- a little extra up so it flies in an arc
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
	ball.tool, ball.thrown, ball.holder, ball.thrower = nil, nil, nil, nil
	ball.part.Transparency = SHOWN
	ball.prompt.Enabled = true
	ball.model:SetAttribute("Out", nil)
end

local function give(ball: Ball, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or humanoid.Health <= 0 or not backpack or holding[player] then return end
	if ball.thrown then ball.thrown:Destroy() ball.thrown = nil end
	ball.part.Transparency = 1
	ball.prompt.Enabled = false
	ball.model:SetAttribute("Out", true)
	local tool = Instance.new("Tool")
	tool.Name = "비치볼"
	tool.ToolTip = "누른 곳으로 던지기"
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
	if victim then Remote:FireClient(victim, "Hit", dir) end
	-- "퐁!" over the head, for everyone
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "BeachBallPong"
		gui.Size = UDim2.fromOffset(90, 40)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "퐁!"
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.fromRGB(255, 120, 150)
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		gui.Adornee = head
		gui.Parent = head
		game:GetService("Debris"):AddItem(gui, 1.2)
	end
end

local function throw(ball: Ball, player: Player, target: Vector3)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then return end
	local from = head.Position
	local aim = target - from
	if aim.Magnitude < 1 or aim.Magnitude > 400 then aim = root.CFrame.LookVector end
	local dir = aim.Unit
	if ball.tool then ball.tool:Destroy() ball.tool = nil end
	holding[player] = nil
	ball.holder = nil
	local p = ball.part:Clone()
	for _, d in ipairs(p:GetChildren()) do d:Destroy() end
	p.Name = "ThrownBeachBall"
	p.Transparency = SHOWN
	p.Anchored = false
	p.CanCollide, p.CanTouch, p.CanQuery = true, true, false
	p.Massless = false
	-- light and bouncy (density low enough to float on the sea)
	-- (friction 0.35 rolled it 25 studs over the sand after a hit: 1 with full weight)
	p.CustomPhysicalProperties = PhysicalProperties.new(0.08, 1, 0.55, 100, 1)
	p.CFrame = CFrame.new(from + dir * 2.6 + Vector3.new(0, 0.3, 0))
	p.Parent = workspace
	p:SetNetworkOwner(nil)
	p.AssemblyLinearVelocity = dir * SPEED + Vector3.new(0, LIFT, 0)
	p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8
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

	Remote.OnServerEvent:Connect(function(player, action, target)
		if action ~= "Throw" or typeof(target) ~= "Vector3" or target ~= target then return end
		local ball = holding[player]
		local character = player.Character
		if not ball or not ball.tool or not character or ball.tool.Parent ~= character then return end
		throw(ball, player, target)
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

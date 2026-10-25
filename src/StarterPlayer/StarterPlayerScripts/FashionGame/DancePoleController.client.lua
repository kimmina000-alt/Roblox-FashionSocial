--!strict
-- Club dance poles (user 2026-10-25): the "봉 잡고 돌기" prompt on a pole
-- (on an attachment of the pole base, tag DancePole) puts the player on its base, holding the pole and turning
-- slowly round it with the "빙그르르" (twirl) dance, a playful spin. Jump,
-- or the prompt again, lets go; it also stops after 20 s. The character
-- moves on this client (its owner), so everyone sees it.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local TWIRL_ID = "rbxassetid://10714293450" -- ClubConfig "twirl" (Roblox emote)
local RADIUS = 1.9
local TURN_SPEED = 1.1 -- radians per second
local MAX_TIME = 20

local active: { stop: () -> () }? = nil

local function start(base: BasePart)
	if active then active.stop() return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Sit then return end
	local baseTop = base.Position.Y + base.Size.X / 2 -- the base is a cylinder lying on X, turned upright
	local pole = base
	local hover = humanoid.HipHeight + root.Size.Y / 2
	local away = Vector3.new(root.Position.X - pole.Position.X, 0, root.Position.Z - pole.Position.Z)
	local angle = if away.Magnitude > 0.1 then math.atan2(away.Z, away.X) else 0
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local track: AnimationTrack? = nil
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = TWIRL_ID
		track = animator:LoadAnimation(animation)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.2)
	end
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	local started = os.clock()
	local connections: { RBXScriptConnection } = {}
	local stopped = false
	local function stop()
		if stopped then return end
		stopped = true
		for _, c in ipairs(connections) do c:Disconnect() end
		if track then track:Stop(0.2) end
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		active = nil
	end
	active = { stop = stop }
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if not root.Parent or humanoid.Health <= 0 or os.clock() - started > MAX_TIME then stop() return end
		angle += dt * TURN_SPEED
		local p = Vector3.new(pole.Position.X + math.cos(angle) * RADIUS, baseTop + hover, pole.Position.Z + math.sin(angle) * RADIUS)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(p, p + tangent)
	end))
	table.insert(connections, UserInputService.JumpRequest:Connect(stop))
	table.insert(connections, humanoid.Died:Connect(stop))
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player or prompt.Name ~= "PolePrompt" then return end
	local grip = prompt.Parent
	local base = grip and grip.Parent
	if base and base:IsA("BasePart") then start(base) end
end)

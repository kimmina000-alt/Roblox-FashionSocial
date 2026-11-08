--!strict
-- Beach ball throwing on this screen (D-1029, BeachBallService): with the ball
-- in hand a tap / click throws it at the point pressed; hit by a ball, this
-- player's character is pushed and falls over for a moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("BeachBall") :: RemoteEvent
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local function hook(tool: Instance)
	if not tool:IsA("Tool") or not tool:GetAttribute("BeachBall") or tool:GetAttribute("Hooked") then return end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		-- the point under the tap / the mouse; nothing there (the sky) → far ahead
		local camera = workspace.CurrentCamera
		local target = mouse.Hit.Position
		if (target - camera.CFrame.Position).Magnitude > 300 then
			target = camera.CFrame.Position + mouse.UnitRay.Direction * 80
		end
		Sfx.play("whoosh", 0.35)
		Remote:FireServer("Throw", target)
	end)
end

local function onCharacter(character: Model)
	for _, d in ipairs(character:GetChildren()) do hook(d) end
	character.ChildAdded:Connect(hook)
end
if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

local falling = false
Remote.OnClientEvent:Connect(function(action, dir)
	if action ~= "Hit" or typeof(dir) ~= "Vector3" then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return end
	-- sitting, riding a tube or a ride (anchored), or already down: only the "퐁!"
	if falling or humanoid.Sit or root.Anchored or humanoid:GetState() == Enum.HumanoidStateType.Swimming then return end
	falling = true
	root.AssemblyLinearVelocity = dir * 22 + Vector3.new(0, 14, 0)
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	task.delay(1.3, function()
		falling = false
		if humanoid.Parent and humanoid.Health > 0 then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
	end)
end)

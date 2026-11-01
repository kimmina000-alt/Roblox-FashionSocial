--!strict
-- The guard's carry (GuardService, D-722, user 2026-11-01), on every screen:
--   - a guard carrying someone (player attribute Carrying) holds both arms out
--     in front, under the player lying across them (Motor6D.Transform after
--     the animations, every frame; C0 is read-only on current avatars)
--   - the carried player (attribute CarriedBy) cannot walk or jump
--   - the guard gets a big "⬇ 내려놓기" button at the bottom of the screen
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")

-- arms forward (about the shoulder's X axis), elbows a little bent
local SHOULDER = CFrame.Angles(math.rad(80), 0, 0)
local ELBOW = CFrame.Angles(math.rad(25), 0, 0)
local JOINTS = {
	{ "RightUpperArm", "RightShoulder", SHOULDER },
	{ "LeftUpperArm", "LeftShoulder", SHOULDER },
	{ "RightLowerArm", "RightElbow", ELBOW },
	{ "LeftLowerArm", "LeftElbow", ELBOW },
}

RunService.Stepped:Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		if character and p:GetAttribute("Carrying") then
			for _, joint in ipairs(JOINTS) do
				local part = character:FindFirstChild(joint[1])
				local motor = part and part:FindFirstChild(joint[2])
				if motor and motor:IsA("Motor6D") then motor.Transform = joint[3] end
			end
		end
	end
	-- held: no walking off (the server sets PlatformStand too)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and player:GetAttribute("CarriedBy") then
		humanoid.PlatformStand = true
		humanoid.Jump = false
	end
end)

-- put down: stand up at once (2P test 2026-11-02, D-738: the player lay on
-- their side for two seconds before getting up by themselves)
player:GetAttributeChangedSignal("CarriedBy"):Connect(function()
	if player:GetAttribute("CarriedBy") then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return end
	humanoid.PlatformStand = false
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1, 0), root.Position + Vector3.new(0, 1, 0) + look.Unit)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end)

-- the guard's drop button
local gui = Instance.new("ScreenGui")
gui.Name = "GuardCarryGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local dropButton = Instance.new("TextButton")
dropButton.Name = "DropButton"
dropButton.AnchorPoint = Vector2.new(0.5, 1)
dropButton.Position = UDim2.new(0.5, 0, 1, -24)
dropButton.Size = UDim2.fromOffset(170, 44)
dropButton.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
dropButton.BackgroundTransparency = 0.1
dropButton.Font = Enum.Font.GothamBold
dropButton.TextSize = 17
dropButton.TextColor3 = Color3.new(1, 1, 1)
dropButton.Text = "⬇ 내려놓기"
dropButton.Visible = false
dropButton.Parent = gui
Instance.new("UICorner", dropButton).CornerRadius = UDim.new(0, 12)
do
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.fromRGB(220, 20, 35)
	edge.Thickness = 2
	edge.Parent = dropButton
end

local function refresh()
	local id = player:GetAttribute("Carrying")
	local target = typeof(id) == "number" and Players:GetPlayerByUserId(id) or nil
	dropButton.Visible = id ~= nil
	dropButton.Text = if target then "⬇ " .. target.DisplayName .. " 내려놓기" else "⬇ 내려놓기"
end
player:GetAttributeChangedSignal("Carrying"):Connect(refresh)
refresh()

dropButton.Activated:Connect(function()
	task.spawn(function()
		pcall(function() FashionGame:WaitForChild("Remotes"):WaitForChild("ClubShop"):InvokeServer("GuardDrop") end)
	end)
end)

--!strict
-- First-visit tutorial and the guide NPC (D-712, Shared/GuideConfig).
--   * The tutorial is shown once: wallet.tutorial is saved when it ends or is
--     skipped. The player attribute TutorialDone (true / false) tells the
--     client, set once the player's data has loaded.
--   * Remote Guide (RemoteFunction) "TutorialDone": the client finished or
--     skipped the tour.
--   * The guide NPC stands between the ranking boards; its prompt
--     "GuidePrompt" opens the 무엇이든 물어보세요 window on the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local GuideConfig = require(Shared:WaitForChild("GuideConfig"))
local NpcLooks = require(Shared:WaitForChild("NpcLooks"))

local GuideService = {}

local data: any = nil -- PlayerDataService

local function spawnGuide()
	local spec = GuideConfig.Npc
	if workspace:FindFirstChild("GuideNPC") then return end
	local description = NpcLooks.describe(spec.look)
	local ok, model = pcall(function()
		if description then
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end
		local plain = Instance.new("HumanoidDescription")
		plain.TorsoColor = Color3.fromRGB(255, 140, 90)
		return Players:CreateHumanoidModelFromDescription(plain, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[GuideService] Could not create the guide:", model)
		return
	end
	model.Name = "GuideNPC"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = spec.name
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- (as the bar staff: only the root anchored, the look applied again in
	-- Workspace for its body scales; DrinkService.spawnStaff)
	if root then root.Anchored = true end
	local at = spec.position
	model:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3, 0), at + Vector3.new(0, 3, 0) + spec.facing))
	model.Parent = workspace
	if description and humanoid then
		pcall(function() humanoid:ApplyDescription(description) end)
		task.wait(0.5)
		local look = NpcLooks.Looks[spec.look]
		if look and look.pose then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. tostring(look.pose)
			local okTrack, track = pcall(function() return animator:LoadAnimation(animation) end)
			if okTrack and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Idle
				track:Play()
			end
		end
	end
	-- feet on the ground whatever the body's size
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, at.Y - (box.Position.Y - size.Y / 2), 0))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GuidePrompt"
	prompt.ActionText = "무엇이든 물어보세요"
	prompt.ObjectText = spec.name
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root or model.PrimaryPart
	-- a "?" over the head so it is seen from afar
	local head = model:FindFirstChild("Head")
	if head then
		local board = Instance.new("BillboardGui")
		board.Name = "GuideMark"
		board.Size = UDim2.fromOffset(46, 46)
		board.StudsOffset = Vector3.new(0, 3.2, 0)
		board.AlwaysOnTop = true
		board.MaxDistance = 120
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.fromScale(1, 1)
		mark.BackgroundColor3 = Color3.fromRGB(255, 140, 90)
		mark.Text = "?"
		mark.TextScaled = true
		mark.Font = Enum.Font.GothamBlack
		mark.TextColor3 = Color3.new(1, 1, 1)
		mark.Parent = board
		Instance.new("UICorner", mark).CornerRadius = UDim.new(1, 0)
		board.Parent = head
	end
end

local function tell(player: Player)
	task.spawn(function()
		local wallet = data.Wallet(player) -- (waits for the player's data)
		if player.Parent then player:SetAttribute("TutorialDone", wallet.tutorial == true) end
	end)
end

function GuideService.Start(playerData: any)
	data = playerData
	local remote = FashionGame:WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any)
		if action == "TutorialDone" then
			local wallet = data.Wallet(player)
			if not wallet.tutorial then
				wallet.tutorial = true
				data.MarkDirty(player)
			end
			player:SetAttribute("TutorialDone", true)
			return true
		end
		return false
	end
	Players.PlayerAdded:Connect(tell)
	for _, player in ipairs(Players:GetPlayers()) do tell(player) end
	task.spawn(spawnGuide)
end

return GuideService

--!strict
-- The guide NPC on the tip cards, as if it were talking (user 2026-11-01,
-- D-716): a picture of the bunny standing on the card's top-left corner. The
-- picture is a still copy the server keeps (ReplicatedStorage.FashionGame
-- .GuidePortrait, GuideService) drawn in a ViewportFrame.
-- GuideSpeaker.attach(card) — call once per card; the card's title should
-- leave GuideSpeaker.Width px free on the left.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuideSpeaker = {}

GuideSpeaker.Width = 104
local HEIGHT = 124

function GuideSpeaker.attach(card: Frame)
	local view = Instance.new("ViewportFrame")
	view.Name = "GuideSpeaker"
	view.AnchorPoint = Vector2.new(0, 1)
	view.Position = UDim2.fromOffset(4, 34) -- (its feet on the card, below the top edge)
	view.Size = UDim2.fromOffset(GuideSpeaker.Width, HEIGHT)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 200, 205)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-0.3, -1, -0.8)
	view.ZIndex = (card.ZIndex or 1) + 2
	view.Parent = card
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	task.spawn(function()
		local source = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("GuidePortrait", 60)
		if not source or not view.Parent then return end
		local world = Instance.new("WorldModel")
		world.Parent = view
		local copy = source:Clone()
		copy.Parent = world
		if copy:IsA("Model") then
			local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- facing the viewer, a little turned toward the card's text
			local base = if root then root.CFrame else copy:GetPivot()
			copy:PivotTo(copy:GetPivot() * base.Rotation:Inverse() * CFrame.Angles(0, math.rad(20), 0))
			local cf, size = copy:GetBoundingBox()
			local distance = (size.Y * 0.56) / math.tan(math.rad(camera.FieldOfView / 2))
			camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.05, -distance), cf.Position + Vector3.new(0, size.Y * 0.05, 0))
		end
	end)
	return view
end

return GuideSpeaker

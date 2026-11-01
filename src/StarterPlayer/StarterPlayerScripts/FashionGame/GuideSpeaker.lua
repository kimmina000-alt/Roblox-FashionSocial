--!strict
-- The guide NPC beside the tip cards, as if it were talking (user 2026-11-01,
-- D-716; D-717: left of the card, its bottom edge level with the card's, upper
-- body only, waving). The picture is a still copy the server keeps
-- (ReplicatedStorage.FashionGame.GuidePortrait, GuideService) drawn in a
-- ViewportFrame's WorldModel, where it plays the R15 wave on a loop.
-- GuideSpeaker.attach(card) — once per card. GuideSpeaker.Width: the room
-- the picture takes left of the card.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuideSpeaker = {}

GuideSpeaker.Width = 150
local HEIGHT = 180
local WAVE = 507770239 -- the standard R15 wave

function GuideSpeaker.attach(card: Frame)
	local view = Instance.new("ViewportFrame")
	view.Name = "GuideSpeaker"
	view.AnchorPoint = Vector2.new(1, 1)
	view.Position = UDim2.new(0, -6, 1, 0)
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
		if not copy:IsA("Model") then return end
		local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- facing the viewer (a body faces -Z; the camera stands at -Z), a little turned
		copy:PivotTo(CFrame.new(copy:GetPivot().Position) * CFrame.Angles(0, math.rad(15), 0))
		-- the parts follow the joints while the wave plays: unanchored, the
		-- root alone holds the body
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = d == root end
		end
		local humanoid = copy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. WAVE
			pcall(function()
				local track = animator:LoadAnimation(animation)
				track.Looped = true
				track:Play()
			end)
		end
		-- the upper body: from the waist (the root) to over the head
		-- (the bunny is mostly head and ears: its body box from a quarter up)
		local box, boxSize = copy:GetBoundingBox()
		local bottom = box.Y - boxSize.Y / 2 + boxSize.Y * 0.25
		local top = box.Y + boxSize.Y / 2 + 0.2
		local span = top - bottom
		local centre = Vector3.new(copy:GetPivot().X, (top + bottom) / 2, copy:GetPivot().Z)
		local distance = (span * 0.6) / math.tan(math.rad(camera.FieldOfView / 2))
		camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0, -distance), centre)
	end)
	return view
end

return GuideSpeaker

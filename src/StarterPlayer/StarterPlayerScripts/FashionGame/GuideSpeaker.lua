--!strict
-- 안내원 토끼가 말하는 카드 (D-1692, user 2026-11-17: "안내원 토끼가 인사하는 모션으로 상반신만 보이게 텍스트
-- 왼쪽에 넣어서 안내원 토끼가 말하는 것처럼 구현").
-- GuideSpeaker.attach(card, width) puts the guide NPC (the rabbit; the server keeps a still copy in
-- ReplicatedStorage.FashionGame.GuidePortrait, GuideService) in a ViewportFrame at the left of a card,
-- from the waist up, waving (the "Hello" emote, looped). The caller moves its text right by `width`.
-- Used by the first-visit tour, the first goal and the club cards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")

local GuideSpeaker = {}

-- (the "Hello" emote: the rabbit lifts a paw beside its face and waves; the plain R15 "Wave" 507770239
-- barely moved this small guide's hand, checked in Play)
local WAVE = "rbxassetid://3344650532"
local FOV = 30

-- from the waist up, the whole width (the rabbit is small and its head big), fitted to the view's shape
local function frameUpperBody(model: Model, camera: Camera, view: ViewportFrame)
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not torso then return end
	local box, size = model:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2
	local bottom = torso.Position.Y - torso.Size.Y / 2 - 0.6
	local h = top - bottom
	local w = math.max(size.X, size.Z) * 0.9
	local px = view.AbsoluteSize
	local aspect = if px.Y > 0 then px.X / px.Y else 0.85
	local vfov = math.rad(FOV)
	local hfov = 2 * math.atan(math.tan(vfov / 2) * aspect)
	local d = math.max((h / 2) / math.tan(vfov / 2), (w / 2) / math.tan(hfov / 2)) * 1.05
	local front = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	local at = Vector3.new(head.Position.X, (top + bottom) / 2, head.Position.Z)
	camera.FieldOfView = FOV
	-- a little from the side, as if turned to the text
	camera.CFrame = CFrame.lookAt(at + front * d + front:Cross(Vector3.yAxis) * d * 0.15, at)
end

-- the guide waving at the left of `card`, `width` wide and the card's height (minus a small margin)
function GuideSpeaker.attach(card: GuiObject, width: number): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.Name = "GuideSpeaker"
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromOffset(2, 2)
	view.Size = UDim2.new(0, width, 1, -4)
	view.Ambient = Color3.fromRGB(200, 200, 205)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-0.4, -1, -0.6)
	view.ZIndex = card.ZIndex + 1
	view.Parent = card
	local camera = Instance.new("Camera")
	camera.Parent = view
	view.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = view
	task.spawn(function()
		local source = FashionGame:WaitForChild("GuidePortrait", 60)
		if not source or not view.Parent then return end
		local ok, model = pcall(function() return (source :: Model):Clone() end)
		if not ok or not model then return end
		model.Parent = world
		model:PivotTo(CFrame.new())
		-- the copy is all anchored: free the body (the root holds it) so the wave can move the arm
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = d.Name == "HumanoidRootPart" end
		end
		frameUpperBody(model, camera, view)
		view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() frameUpperBody(model, camera, view) end)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
		if animator then
			local anim = Instance.new("Animation")
			anim.AnimationId = WAVE
			local ok2, track = pcall(function() return (animator :: Animator):LoadAnimation(anim) end)
			if ok2 and track then
				track.Looped = true
				track:Play(0.2)
			end
		end
	end)
	return view
end

return GuideSpeaker

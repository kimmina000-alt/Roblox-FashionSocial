--!strict
-- (D-1330, user 2026-11-13, a screen recording of another game's outfit editor:
-- "카탈로그 열면 첨부 동영상처럼 내 캐릭터를 카탈로그 창과 겹치지 않게 화면의 옆쪽에
-- 보이도록 구현해 줘. 최대화 화면에서도 새로운 미리보기 창 말고 내 캐릭터가 미리보기
-- 창에 들어가도록 카메라를 수정해 줘")
-- While the catalog is open the camera looks at the front of the player's own
-- character and frames it, whole body, inside a screen rectangle the catalog
-- gives: the free side of the screen beside the minimized window, or the
-- preview box of the expanded one. The camera follows the character every
-- frame; closing the catalog gives the camera back as it was.
--   CatalogCamera.frame(rect)  rect = { x, y, w, h } in screen pixels (the
--                              catalog's ScreenGui ignores the GUI inset)
--   CatalogCamera.release()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CatalogCamera = {}

local FILL = 0.86 -- the character's height / the rectangle's height
local BIND = "CatalogCamera"
local target: { x: number, y: number, w: number, h: number }? = nil
local saved: { type: Enum.CameraType, subject: Instance?, fov: number }? = nil

-- (D-1336, user 2026-11-13: "카탈로그 열었을 때 회전해서 캐릭터 앞 뒤 위 아래 볼 수
-- 있도록 수정") a drag on the world (not on the catalog window, the joystick or the
-- jump button: those inputs are already taken) turns the camera round the character:
-- left / right all the way round (the back too), up / down from below to above.
-- Every new opening starts from the front again.
local UserInputService = game:GetService("UserInputService")
local yaw, pitch = 0, 0
local PITCH_MIN, PITCH_MAX = math.rad(-60), math.rad(80)
local SPEED = math.rad(0.45) -- per pixel dragged
local dragging: InputObject? = nil
local lastPos: Vector3? = nil
UserInputService.InputBegan:Connect(function(input, processed)
	if not saved or processed or dragging then return end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2 then
		dragging = input
		lastPos = input.Position
	end
end)
-- (D-1337, user 2026-11-13: "확대 축소도 돼?") two-finger pinch on a phone, the mouse
-- wheel on a PC: closer up to 0.35 of the distance (the view rises to the face, like the
-- old preview, D-819) or out to 1.6
local zoom = 1
local ZOOM_MIN, ZOOM_MAX = 0.35, 1.6
local pinchStart: number? = nil
UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
	if not saved then return end
	if state == Enum.UserInputState.Begin then
		if processed then return end
		pinchStart = zoom
		dragging, lastPos = nil, nil -- (the two fingers do not turn the view too)
	elseif pinchStart and (state == Enum.UserInputState.Change or state == Enum.UserInputState.End) then
		zoom = math.clamp((pinchStart :: number) / math.max(0.05, scale), ZOOM_MIN, ZOOM_MAX)
		if state == Enum.UserInputState.End then pinchStart = nil end
	end
end)
UserInputService.InputChanged:Connect(function(input, processed)
	if saved and not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
		zoom = math.clamp(zoom * (if input.Position.Z > 0 then 0.88 else 1 / 0.88), ZOOM_MIN, ZOOM_MAX)
		return
	end
	if pinchStart then return end
	local drag = dragging
	if not drag or not lastPos then return end
	local moved = if drag.UserInputType == Enum.UserInputType.Touch
		then input == drag
		else input.UserInputType == Enum.UserInputType.MouseMovement
	if not moved then return end
	local d = input.Position - (lastPos :: Vector3)
	lastPos = input.Position
	yaw -= d.X * SPEED
	pitch = math.clamp(pitch + d.Y * SPEED, PITCH_MIN, PITCH_MAX)
end)
UserInputService.InputEnded:Connect(function(input)
	local drag = dragging
	if drag and (input == drag or (drag.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType == drag.UserInputType)) then
		dragging = nil
		lastPos = nil
	end
end)

-- (D-1339, user 2026-11-13: the avatar editor still showed the old preview box) while
-- the avatar editor is open its draft copy of the character (client only) stands in the
-- world where the player stands and the real character is hidden on this screen, so the
-- camera shows the draft the same way as the catalog shows the character
local stageModel: Model? = nil
local function setHidden(character: Model?, hidden: boolean)
	if not character then return end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- model = the draft copy (already in the world), nil = back to the real character
-- (the old copy is removed)
-- (D-1383, user 2026-11-13: "아바타 미세 편집 들어갈 때 캐릭터가 입은 옷 사라졌다가 다시
-- 나타나는데 계속 나타나있게 수정") a new copy comes in hidden and takes over only once its
-- clothes and accessories are loaded (ApplyDescriptionResetAsync rebuilds them all, and
-- layered clothing is drawn a few frames later): until then the old copy, or the real
-- character on the way in, stays on screen
local pendingToken = 0
local pendingModel: Model? = nil
function CatalogCamera.stage(model: Model?)
	if model == stageModel or (model ~= nil and model == pendingModel) then return end
	pendingToken += 1
	local token = pendingToken
	if pendingModel and pendingModel ~= model and pendingModel:IsDescendantOf(workspace) then pendingModel:Destroy() end
	pendingModel = nil
	if not model then
		local old = stageModel
		stageModel = nil
		if old and old:IsDescendantOf(workspace) then old:Destroy() end
		setHidden(Players.LocalPlayer.Character, false)
		return
	end
	pendingModel = model
	task.spawn(function()
		pcall(function() game:GetService("ContentProvider"):PreloadAsync({ model }) end)
		for _ = 1, 6 do RunService.Heartbeat:Wait() end
		task.wait(0.25) -- (layered clothing wraps a moment after it loads)
		if token ~= pendingToken or not model.Parent then return end
		pendingModel = nil
		local old = stageModel
		stageModel = model
		setHidden(model, false)
		if old and old ~= model and old:IsDescendantOf(workspace) then old:Destroy() end
	end)
end

-- puts a draft copy where the player stands (hidden until stage() shows it): nothing to
-- bump into or hit
-- (D-1383, user: "장신구 조정할 때 위치 수정해도 안 움직이다가 … 카탈로그 창 끄면 변경한 위치로
-- 장신구 위치 바뀜") only the root is anchored now: the accessory fit moves an accessory by
-- its attachment and lets its constraint carry the handle, which an anchored handle never
-- did, so the copy showed no change until the catalog closed
function CatalogCamera.placeCopy(clone: Model)
	local character = Players.LocalPlayer.Character
	if not character then return end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("RigidConstraint") then
			d.Enabled = true -- (the preview world turned some off to place handles by hand)
		elseif d:IsA("BillboardGui") then
			d:Destroy() -- (the name tag is the real character's)
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.EvaluateStateMachine = false -- (a still copy: no falling or getting up)
	end
	setHidden(clone, true)
	clone.Parent = workspace
	clone:PivotTo(character:GetPivot())
end

local function step()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if stageModel and stageModel.Parent then
		setHidden(character, true) -- (every frame: the camera scripts reset it)
		character = stageModel
	end
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rect = target
	if not (camera and character and root and rect) then return end
	camera.CameraType = Enum.CameraType.Scriptable
	-- the body's top and bottom (not accessories: wings or long hair can make the
	-- whole box much taller); avatars may be scaled, so no fixed height
	local top, bottom = -math.huge, math.huge
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part ~= root then
			-- (rotated parts: the vertical reach of the box)
			local r = part.CFrame
			local reach = math.abs(r.RightVector.Y) * part.Size.X / 2 + math.abs(r.UpVector.Y) * part.Size.Y / 2 + math.abs(r.LookVector.Y) * part.Size.Z / 2
			top = math.max(top, part.Position.Y + reach)
			bottom = math.min(bottom, part.Position.Y - reach)
		end
	end
	if top < bottom then return end
	local height = math.clamp(top - bottom, 2, 30)
	-- (D-1337) zoomed in, the view rises toward the face
	local lift = height * 0.36 * math.clamp((1 - zoom) / (1 - ZOOM_MIN), 0, 1)
	local center = Vector3.new(root.Position.X, (top + bottom) / 2 + lift, root.Position.Z)
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
	local view = camera.ViewportSize
	local tanHalf = math.tan(math.rad(camera.FieldOfView) / 2)
	local distance = height / (FILL * 2 * tanHalf) * (view.Y / math.max(40, rect.h)) * zoom
	-- studs per pixel at that distance: shift the camera so the character's middle
	-- lands on the rectangle's middle
	local perPixel = 2 * distance * tanHalf / view.Y
	local dx = (rect.x + rect.w / 2 - view.X / 2) * perPixel
	local dy = (rect.y + rect.h / 2 - view.Y / 2) * perPixel
	-- (D-1336) round the character by the drag: yaw about the vertical, then up / down
	local around = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(look)
	local dir = around * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	camera.CFrame = CFrame.lookAt(center + dir * distance, center) * CFrame.new(-dx, dy, 0)
end

-- (D-1348, user 2026-11-13: "카탈로그 최소화에서는 아바타 위치만 왼쪽으로 옮기고 걸어다닐 수
-- 있게 해 줘. 지금은 켜놓고 걸어다닐 수 없음. 걸으려고 움직이면 화면만 회전함") beside the
-- minimized window the game camera stays as it is (behind the character, the player's own
-- drag and zoom, walking); only the picture is slid sideways so the character stands in the
-- free part of the screen. (The front view of frame() turned with the character: walking
-- turned the character, the camera went round to its front again, and so on.)
local SIDE_BIND = "CatalogCameraSide"
local sideRect: { x: number, y: number, w: number, h: number }? = nil
local function sideStep()
	local camera = workspace.CurrentCamera
	local rect = sideRect
	if not camera or not rect or camera.CameraType ~= Enum.CameraType.Custom then return end
	local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	if distance < 1 then return end -- (first person: nothing to slide)
	local view = camera.ViewportSize
	local perPixel = 2 * distance * math.tan(math.rad(camera.FieldOfView) / 2) / view.Y
	local dx = (rect.x + rect.w / 2 - view.X / 2) * perPixel
	camera.CFrame = camera.CFrame * CFrame.new(-dx, 0, 0)
end
local function stopSide()
	if sideRect then
		sideRect = nil
		RunService:UnbindFromRenderStep(SIDE_BIND)
	end
end

function CatalogCamera.side(rect: { x: number, y: number, w: number, h: number })
	if saved then CatalogCamera.release() end
	if not sideRect then
		-- right after the camera scripts, before anything else draws
		RunService:BindToRenderStep(SIDE_BIND, Enum.RenderPriority.Camera.Value + 1, sideStep)
	end
	sideRect = rect
end

function CatalogCamera.frame(rect: { x: number, y: number, w: number, h: number })
	stopSide()
	target = rect
	if saved then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	yaw, pitch, dragging, lastPos = 0, 0, nil, nil -- (D-1336) from the front
	zoom, pinchStart = 1, nil -- (D-1337) whole body
	saved = { type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView }
	-- after the other camera scripts (stage camera, photo booth) so this one wins
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 10, step)
end

function CatalogCamera.release()
	stopSide()
	target = nil
	dragging, lastPos = nil, nil
	CatalogCamera.stage(nil)
	if not saved then return end
	RunService:UnbindFromRenderStep(BIND)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = saved.type
		camera.FieldOfView = saved.fov
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = if saved.type == Enum.CameraType.Custom and humanoid then humanoid else saved.subject
		-- (D-1340, user 2026-11-13: "카탈로그 끄면 ... 원래 카메라 위치로. 캐릭터 다시 기본
		-- 위치로 보여 줄 것") the game camera kept looking from where the catalog had put it
		-- (in front of the character, on phones the character off to one side): back
		-- behind the character at the usual distance, a little above
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if saved.type == Enum.CameraType.Custom and root then
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
			local focus = root.Position + Vector3.new(0, 1.5, 0)
			local cf = CFrame.lookAt(focus - look * 12 + Vector3.new(0, 4, 0), focus)
			camera.CFrame = cf
			camera.Focus = CFrame.new(focus)
			-- (once more after the camera scripts' next frame, which can still use the old one)
			task.defer(function()
				if not saved and camera.CameraType == Enum.CameraType.Custom then
					camera.CFrame = cf
				end
			end)
		end
	end
	saved = nil
end

function CatalogCamera.active(): boolean
	return saved ~= nil or sideRect ~= nil
end

return CatalogCamera

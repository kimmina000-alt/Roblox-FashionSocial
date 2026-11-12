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
UserInputService.InputChanged:Connect(function(input)
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

local function step()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
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
	local center = Vector3.new(root.Position.X, (top + bottom) / 2, root.Position.Z)
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
	local view = camera.ViewportSize
	local tanHalf = math.tan(math.rad(camera.FieldOfView) / 2)
	local distance = height / (FILL * 2 * tanHalf) * (view.Y / math.max(40, rect.h))
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

function CatalogCamera.frame(rect: { x: number, y: number, w: number, h: number })
	target = rect
	if saved then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	yaw, pitch, dragging, lastPos = 0, 0, nil, nil -- (D-1336) from the front
	saved = { type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView }
	-- after the other camera scripts (stage camera, photo booth) so this one wins
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 10, step)
end

function CatalogCamera.release()
	target = nil
	dragging, lastPos = nil, nil
	if not saved then return end
	RunService:UnbindFromRenderStep(BIND)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = saved.type
		camera.FieldOfView = saved.fov
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = if saved.type == Enum.CameraType.Custom and humanoid then humanoid else saved.subject
	end
	saved = nil
end

function CatalogCamera.active(): boolean
	return saved ~= nil
end

return CatalogCamera

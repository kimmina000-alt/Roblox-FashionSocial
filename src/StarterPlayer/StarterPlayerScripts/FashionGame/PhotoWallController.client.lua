--!strict
-- 인생네컷 extras (user, 2026-10-20):
--
--   * Photo wall (parts tagged "PhotoWall", attribute Face = "Front"/"Back"
--     for the side people look at): "사진 붙이기" prompt → pick a photo from
--     the album (or use the photo item in hand) → move it over the wall and
--     tap to stick it. The photo leaves the album (PhotoBoothService
--     "WallPost"); it can overlap photos already there.
--   * Booth barrier: while this player is in a booth flow (character
--     attribute PhotoBooth = booth key), a local invisible wall closes the
--     booth's open side so walking out is blocked smoothly. The server also
--     pulls people back in (PhotoBoothService), this only makes it feel solid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local PhotoConfig = require(Shared:WaitForChild("PhotoConfig"))
local Remotes = FashionGame:WaitForChild("Remotes")
local boothRemote = Remotes:WaitForChild("PhotoBooth") :: RemoteFunction
local boothEvent = Remotes:WaitForChild("PhotoBoothEvent") :: RemoteEvent
local PhotoRender = require(script.Parent:WaitForChild("PhotoRender"))

local PINK = Color3.fromRGB(255, 110, 170)

local function invoke(action: string, payload: any): (boolean, any)
	local ok, success, result = pcall(function()
		return boothRemote:InvokeServer(action, payload)
	end)
	if not ok then return false, "잠시 후 다시 시도하세요." end
	return success == true, result
end

local gui = Instance.new("ScreenGui")
gui.Name = "FashionPhotoWallGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 42
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function round(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local toastLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.25,
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 15,
	TextWrapped = true,
	Font = Enum.Font.GothamBold,
	Visible = false,
	ZIndex = 30,
}, gui)
round(toastLabel, 12)
local toastToken = 0
local function toast(message: any)
	if typeof(message) ~= "string" or message == "" then return end
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(3, function()
		if toastToken == token then toastLabel.Visible = false end
	end)
end

--------------------------------------------------
-- Wall geometry
--------------------------------------------------

-- Face the photos are on; viewer's right in the wall's object space.
local function faceOf(wall: BasePart): (Enum.NormalId, number)
	local face = wall:GetAttribute("Face")
	if face == "Back" then return Enum.NormalId.Back, 1 end
	return Enum.NormalId.Front, -1
end

-- Photo size on the wall in studs.
local function photoSize(layoutKey: string): Vector2
	local aspect = PhotoRender.stripAspect(layoutKey)
	local height = if layoutKey == "2x2" then 3.4 else 4.4
	return Vector2.new(height * aspect, height)
end

-- u (0 = left, 1 = right as seen from the front), v (0 = top) → world CFrame.
local function wallCFrame(wall: BasePart, u: number, v: number): CFrame
	local face, right = faceOf(wall)
	local zSign = if face == Enum.NormalId.Back then 1 else -1
	local x = (u - 0.5) * wall.Size.X * right
	local y = (0.5 - v) * wall.Size.Y
	return wall.CFrame * CFrame.new(x, y, zSign * (wall.Size.Z / 2 + 0.06))
		* (if face == Enum.NormalId.Back then CFrame.Angles(0, math.pi, 0) else CFrame.new())
end

local function uvOf(wall: BasePart, world: Vector3): (number, number)
	local _, right = faceOf(wall)
	local p = wall.CFrame:PointToObjectSpace(world)
	return 0.5 + right * p.X / wall.Size.X, 0.5 - p.Y / wall.Size.Y
end

--------------------------------------------------
-- Wall rendering
--------------------------------------------------

type Entry = { id: string, wall: string, u: number, v: number, by: string, at: number, photo: any }
local entries: {Entry} = {}
local surfaces: {[BasePart]: Frame} = {}
local drawn: {[string]: Frame} = {}

local function wallKey(wall: BasePart): string
	return tostring(wall:GetAttribute("WallKey") or wall:GetFullName())
end

-- With streaming the wall part comes and goes (a new instance each time): its
-- surface and photos go with it and are drawn again when it is back (the
-- photos vanished after walking away and back, user 2026-10-26).
local drawnWall: {[string]: BasePart} = {}
local function forgetWall(wall: BasePart)
	local holder = surfaces[wall]
	surfaces[wall] = nil
	if holder and holder.Parent then holder.Parent:Destroy() end
	for id, w in pairs(drawnWall) do
		if w == wall then
			drawn[id] = nil
			drawnWall[id] = nil
		end
	end
end

local function surfaceFor(wall: BasePart): Frame
	local existing = surfaces[wall]
	if existing then return existing end
	wall.AncestryChanged:Connect(function()
		if not wall:IsDescendantOf(workspace) then forgetWall(wall) end
	end)
	local face = faceOf(wall)
	-- In PlayerGui with Adornee = wall: the photos are ViewportFrames, and a
	-- ViewportFrame in a SurfaceGui parented to a Workspace part is not drawn
	-- (the wall showed empty strips, user report 2026-10-22).
	local surface = make("SurfaceGui", {
		Name = "PhotoWallSurface",
		Face = face,
		ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 36,
		LightInfluence = 0.3,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Adornee = wall,
	}, playerGui)
	local holder = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, surface)
	surfaces[wall] = holder
	return holder
end

local function findWall(key: string): BasePart?
	for _, wall in ipairs(CollectionService:GetTagged("PhotoWall")) do
		if wall:IsA("BasePart") and wall:IsDescendantOf(workspace) and wallKey(wall) == key then return wall end
	end
	return nil
end

-- (D-1085, user 2026-11-09: "벽에 붙인 스티커 사진 클릭하면 해당 사진 크게
-- 고화질로 볼 수 있게 하기") a tap on a photo on the wall shows it big on the
-- screen: drawn again from the photo itself (the same 3D shots, not a picture
-- of the small one), so it is sharp at that size. A tap anywhere else or ✕ closes.
local viewer = make("TextButton", {
	Name = "PhotoViewer",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.25,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	ZIndex = 50,
}, gui)
local viewerBox = make("Frame", {
	Name = "Photo",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
	ZIndex = 51,
}, viewer)
local viewerClose = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "✕",
	TextColor3 = Color3.new(0, 0, 0),
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	ZIndex = 60,
}, viewer)
round(viewerClose, 20)
-- (D-1109, user 2026-11-09: "사진 클릭해서 크게 보고 컴퓨터는 휠 굴려서 모바일은
-- 두 손가락으로 확대, 축소해서 더 크게 볼 수 있게 해") zoom 1x .. 5x about the
-- pointer (the wheel) or the middle of the two fingers (a pinch); once zoomed in,
-- one finger / the mouse drags it around. A tap closes it at 1x; zoomed in, a tap
-- goes back to 1x. ✕ always closes. The wheel does not move the game camera
-- while it is open.
local ContextActionService = game:GetService("ContextActionService")
local ZOOM_MAX = 5
local zoom = { z = 1, x = 0, y = 0, baseW = 0, baseH = 0, pinchFrom = 1, pinched = false }
local function applyZoom()
	local w, h = zoom.baseW * zoom.z, zoom.baseH * zoom.z
	-- keep some of the photo on the screen
	zoom.x = math.clamp(zoom.x, -w / 2, w / 2)
	zoom.y = math.clamp(zoom.y, -h / 2, h / 2)
	if zoom.z <= 1.001 then zoom.x, zoom.y = 0, 0 end
	viewerBox.Size = UDim2.fromOffset(w, h)
	viewerBox.Position = UDim2.new(0.5, zoom.x, 0.5, zoom.y)
	-- (D-1110, user 2026-11-09: "오른쪽 상단에 끄는 버튼 없애") a tap closes it
	viewerClose.Visible = false
end
-- zoom to z, the screen point `at` staying where it is
local function zoomTo(z: number, at: Vector2?)
	z = math.clamp(z, 1, ZOOM_MAX)
	if at then
		local vp = viewer.AbsoluteSize
		local cx, cy = vp.X / 2 + zoom.x, vp.Y / 2 + zoom.y
		local k = z / zoom.z
		zoom.x += (at.X - cx) * (1 - k)
		zoom.y += (at.Y - cy) * (1 - k)
	end
	zoom.z = z
	applyZoom()
end
local function closeViewer()
	viewer.Visible = false
	ContextActionService:UnbindAction("PhotoViewerWheel")
	for _, child in ipairs(viewerBox:GetChildren()) do child:Destroy() end
end
viewerClose.Activated:Connect(closeViewer)
-- taps and drags on the dark screen and the photo
do
	local press: { input: InputObject, at: Vector3, last: Vector3, moved: boolean }? = nil
	viewer.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		if press and t == Enum.UserInputType.Touch then return end -- (the second finger: a pinch)
		zoom.pinched = false
		press = { input = input, at = input.Position, last = input.Position, moved = false }
	end)
	UserInputService.InputChanged:Connect(function(input)
		local p = press
		if not p or not viewer.Visible then return end
		local moving = input == p.input or (input.UserInputType == Enum.UserInputType.MouseMovement and p.input.UserInputType == Enum.UserInputType.MouseButton1)
		if not moving then return end
		if (input.Position - p.at).Magnitude > 8 then p.moved = true end
		if zoom.z > 1.001 and not zoom.pinched then
			local d = input.Position - p.last
			zoom.x += d.X
			zoom.y += d.Y
			applyZoom()
		end
		p.last = input.Position
	end)
	UserInputService.InputEnded:Connect(function(input)
		local p = press
		if not p or input ~= p.input then return end
		press = nil
		if p.moved or zoom.pinched or not viewer.Visible then return end
		if zoom.z > 1.001 then zoomTo(1) else closeViewer() end
	end)
	UserInputService.TouchPinch:Connect(function(positions, scale, _, state)
		if not viewer.Visible then return end
		zoom.pinched = true
		if state == Enum.UserInputState.Begin then zoom.pinchFrom = zoom.z end
		local mid = nil
		if #positions >= 2 then mid = (positions[1] + positions[2]) / 2 end
		zoomTo(zoom.pinchFrom * scale, mid)
	end)
end
local placing: { wall: BasePart, photo: any, ghost: BasePart }? = nil
local heldWallTap: ((BasePart, number, number) -> ())? = nil -- (D-1108, set below)
local function openViewer(photo: any)
	if placing then return end
	closeViewer()
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local aspect = PhotoRender.stripAspect(photo.layout)
	-- as big as fits: 86 % of the screen's height (or its width)
	local h = math.min(vp.Y * 0.86, vp.X * 0.9 / aspect)
	zoom.z, zoom.x, zoom.y, zoom.baseW, zoom.baseH = 1, 0, 0, h * aspect, h
	applyZoom()
	viewerClose.Position = UDim2.new(1, -16, 0, 16 + require(script.Parent:WaitForChild("TopBar")).bottom())
	PhotoRender.drawPhoto(viewerBox, photo)
	for _, d in ipairs(viewerBox:GetDescendants()) do
		if d:IsA("GuiObject") then d.ZIndex = math.max(d.ZIndex, 52) end
	end
	viewer.Visible = true
	ContextActionService:BindActionAtPriority("PhotoViewerWheel", function(_, state, input)
		if state == Enum.UserInputState.Change and input.UserInputType == Enum.UserInputType.MouseWheel then
			local m = UserInputService:GetMouseLocation()
			zoomTo(zoom.z * (if input.Position.Z > 0 then 1.2 else 1 / 1.2), Vector2.new(m.X, m.Y))
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)
end

local function drawEntry(entry: Entry, order: number)
	if drawn[entry.id] then return end
	local wall = findWall(entry.wall)
	if not wall then return end
	local holder = surfaceFor(wall)
	local size = photoSize(entry.photo.layout)
	local frame = make("Frame", {
		Name = "WallPhoto",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(entry.u, entry.v),
		Size = UDim2.fromScale(size.X / wall.Size.X, size.Y / wall.Size.Y),
		-- No Rotation: ViewportFrames under a rotated frame are not drawn, so the
		-- photos showed as an empty strip (user report 2026-10-22).
		BackgroundTransparency = 1,
		ZIndex = order,
	}, holder)
	PhotoRender.drawPhoto(frame, entry.photo)
	-- (a tap on it: found by a ray in the world, D-1110, not a button here)
	drawn[entry.id] = frame
	drawnWall[entry.id] = wall
end

local function redrawAll()
	-- Keep only the newest MaxWallPhotos.
	while #entries > PhotoConfig.MaxWallPhotos do
		local old = table.remove(entries, 1) :: Entry
		local frame = drawn[old.id]
		if frame then frame:Destroy() end
		drawn[old.id] = nil
		drawnWall[old.id] = nil
	end
	for index, entry in ipairs(entries) do drawEntry(entry, index) end
end

-- (D-1108) the server loads the wall from the DataStore when it starts: the
-- first player of a new server (and every Studio test) asked before that and
-- got an empty wall for good. Asked again a few times while it is empty.
task.spawn(function()
	for _, delay in ipairs({ 0, 4, 10, 25 }) do
		task.wait(delay)
		local ok, list = invoke("GetWall", nil)
		if ok and typeof(list) == "table" and #list > 0 then
			local have = {}
			for _, e in ipairs(entries) do have[e.id] = true end
			for _, entry in ipairs(list) do
				if not have[entry.id] then table.insert(entries, entry) end
			end
			table.sort(entries, function(a, b) return (a.at or 0) < (b.at or 0) end)
			redrawAll()
			return
		end
	end
end)

boothEvent.OnClientEvent:Connect(function(kind: any, value: any)
	if kind == "WallAdd" and typeof(value) == "table" then
		table.insert(entries, value)
		redrawAll()
	end
end)
-- a wall streaming in (again): draw its photos
CollectionService:GetInstanceAddedSignal("PhotoWall"):Connect(function()
	task.defer(redrawAll)
end)

--------------------------------------------------
-- Picker (album photos) + placement
--------------------------------------------------

local picker = make("Frame", {
	Name = "WallPicker",
	BackgroundColor3 = Color3.fromRGB(24, 20, 32),
	BackgroundTransparency = 0.03,
	Visible = false,
	Active = true,
	ClipsDescendants = true,
	ZIndex = 10,
}, gui)
round(picker, 16)
make("UIStroke", { Color = PINK, Thickness = 2 }, picker)
local pickerTitle = make("TextLabel", {
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.new(1, -70, 0, 30),
	BackgroundTransparency = 1,
	Text = "붙일 사진을 고르세요",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, picker)
local pickerClose = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 8),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = Color3.fromRGB(44, 42, 54),
	Text = "X",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	ZIndex = 12,
}, picker)
round(pickerClose, 16)
local pickerList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 46),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 11,
}, picker)
local pickerGrid = make("UIGridLayout", { CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, pickerList)

local hint = make("TextLabel", {
	Name = "PlaceHint",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = Color3.fromRGB(24, 20, 32),
	BackgroundTransparency = 0.1,
	Text = "포토월을 눌러 붙일 자리를 고르세요",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	Visible = false,
	ZIndex = 10,
}, gui)
round(hint, 12)
local cancelButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(110, 34),
	BackgroundColor3 = Color3.fromRGB(44, 42, 54),
	Text = "취소",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	Visible = false,
	ZIndex = 10,
}, gui)
round(cancelButton, 17)

-- (D-1085) while a photo is being stuck on, the photos' tap buttons stand aside
-- (they would take the tap that sticks it)
local function setTaps(on: boolean)
	for _, frame in pairs(drawn) do
		local tap = frame:FindFirstChild("Tap")
		if tap and tap:IsA("GuiButton") then tap.Visible = on end
	end
end

local function stopPlacing()
	if placing then placing.ghost:Destroy() end
	placing = nil
	setTaps(true)
	hint.Visible = false
	cancelButton.Visible = false
end

local function startPlacing(wall: BasePart, photo: any, u0: number?, v0: number?)
	stopPlacing()
	local size = photoSize(photo.layout)
	local frameInfo = PhotoConfig.findFrame(photo.frame) or PhotoConfig.Frames[2]
	local ghost = make("Part", {
		Name = "WallGhost",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = Vector3.new(size.X, size.Y, 0.05),
		Color = frameInfo.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CFrame = wallCFrame(wall, u0 or 0.5, v0 or 0.5), -- (D-1108: where the wall was tapped)
	}, workspace)
	placing = { wall = wall, photo = photo, ghost = ghost }
	setTaps(false)
	local top = require(script.Parent:WaitForChild("TopBar")).bottom() + 10
	-- (D-1256, user 2026-11-10: "포토월 안내 문구 삭제") only the 취소 button, where the
	-- "포토월을 눌러 붙일 자리를 고르세요" line was
	hint.Position = UDim2.new(0.5, 0, 0, top)
	cancelButton.Position = UDim2.new(0.5, 0, 0, top)
	hint.Visible = false
	cancelButton.Visible = true
end
cancelButton.MouseButton1Click:Connect(stopPlacing)

-- Where the pointer hits the wall (u, v clamped so the photo stays on it).
-- A touch position is in GUI space (below the top bar inset) and goes through
-- ScreenPointToRay; the mouse location is in viewport space (phones put the
-- photo a top-bar height away from the tap before, user 2026-10-26).
local function pointerUV(screen: Vector2, touch: boolean?): (number?, number?)
	local state = placing
	local camera = workspace.CurrentCamera
	if not state or not camera then return nil, nil end
	local ray = if touch then camera:ScreenPointToRay(screen.X, screen.Y) else camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { state.wall }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not hit then return nil, nil end
	local u, v = uvOf(state.wall, hit.Position)
	local size = photoSize(state.photo.layout)
	local mu = size.X / 2 / state.wall.Size.X
	local mv = size.Y / 2 / state.wall.Size.Y
	return math.clamp(u, mu, 1 - mu), math.clamp(v, mv, 1 - mv)
end

-- (D-1108) the preview follows the mouse; on a phone it stays where the wall
-- was tapped and follows a finger moving over the wall
RunService.RenderStepped:Connect(function()
	local state = placing
	if not state or not UserInputService.MouseEnabled then return end
	local u, v = pointerUV(UserInputService:GetMouseLocation())
	if u and v then state.ghost.CFrame = wallCFrame(state.wall, u, v) end
end)
UserInputService.InputChanged:Connect(function(input)
	local state = placing
	if not state or input.UserInputType ~= Enum.UserInputType.Touch then return end
	local u, v = pointerUV(Vector2.new(input.Position.X, input.Position.Y), true)
	if u and v then state.ghost.CFrame = wallCFrame(state.wall, u, v) end
end)

-- (D-1108) a short tap (not a drag) on the wall sticks it there
local posting = false
local placeDown: {[InputObject]: { t: number, p: Vector3 }} = {}
UserInputService.InputBegan:Connect(function(input, processed)
	if not placing or processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	placeDown[input] = { t = os.clock(), p = input.Position }
end)
UserInputService.InputEnded:Connect(function(input, processed)
	local d = placeDown[input]
	placeDown[input] = nil
	local state = placing
	if not d or not state or processed or posting then return end
	if os.clock() - d.t > 0.5 or (input.Position - d.p).Magnitude > 14 then return end
	local touch = input.UserInputType == Enum.UserInputType.Touch
	local position = if touch
		then Vector2.new(input.Position.X, input.Position.Y)
		else UserInputService:GetMouseLocation()
	local u, v = pointerUV(position, touch)
	if not u or not v then return end
	posting = true
	local ok, message = invoke("WallPost", { wall = state.wall, id = state.photo.id, u = u, v = v })
	posting = false
	toast(message)
	if ok then stopPlacing() end
end)

local Popups = require(script.Parent:WaitForChild("Popups"))
local function closePicker()
	picker.Visible = false
	Popups.closed("PhotoWall")
	for _, child in ipairs(pickerList:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end
pickerClose.MouseButton1Click:Connect(closePicker)

local function openPicker(wall: BasePart)
	local vp = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
	local top = require(script.Parent:WaitForChild("TopBar")).bottom() + 6
	local w = math.min(760, math.max(280, math.floor(vp.X * 0.42)))
	local h = math.min(math.max(260, math.floor(vp.Y * 0.58)), vp.Y - top - 84)
	picker.Position = UDim2.fromOffset(math.floor((vp.X - w) / 2), math.floor(top + math.max(0, (vp.Y - top - 84 - h) / 2)))
	picker.Size = UDim2.fromOffset(w, h)
	pickerList.Size = UDim2.fromOffset(w - 24, h - 56)
	local cellH = math.clamp(math.floor((h - 66) / 1.6), 110, 240)
	pickerGrid.CellSize = UDim2.fromOffset(math.floor(cellH * 0.55), cellH)
	closePicker()
	picker.Visible = true
	Popups.opened("PhotoWall", closePicker)
	pickerTitle.Text = "불러오는 중..."
	local ok, data = invoke("GetAlbum", nil)
	if not picker.Visible then return end
	if not ok or typeof(data) ~= "table" then
		closePicker()
		toast(if typeof(data) == "string" then data else "사진첩을 불러오지 못했어요.")
		return
	end
	local photos = data.photos or {}
	pickerTitle.Text = if #photos > 0 then "붙일 사진을 고르세요 (붙이면 사진첩에서 빠져요)" else "사진첩이 비어 있어요"
	for index, photo in ipairs(photos) do
		local cell = make("TextButton", {
			LayoutOrder = index,
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 12,
		}, pickerList)
		local holder = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 }, cell)
		PhotoRender.drawPhoto(holder, photo)
		cell.MouseButton1Click:Connect(function()
			closePicker()
			startPlacing(wall, photo)
		end)
	end
end

local function heldPhotoId(): string?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("PhotoId")
	return if typeof(id) == "string" then id else nil
end

-- (D-1108, user 2026-11-09: "벽에 붙이기 안내창 뜨는 거 지우고 사진 손에 들고 벽
-- 눌러야 붙일 수 있게 위치 잡을 수 있게 하고 빈손으로 사진 누르면 크게 보는 걸로
-- 하자") only the photo in the hand is stuck on: a tap on the wall with it puts
-- its preview there (the next tap sticks it); no E prompt, no album window.
-- With empty hands a tap on a photo shows it big (drawEntry's Tap button).
local function useWall(wall: BasePart, u: number?, v: number?)
	local held = heldPhotoId()
	if not held then return end
	local ok, data = invoke("GetAlbum", nil)
	if ok and typeof(data) == "table" then
		for _, photo in ipairs(data.photos or {}) do
			if photo.id == held then
				startPlacing(wall, photo, u, v)
				return
			end
		end
	end
	toast("사진첩에 없는 사진이에요.")
end
heldWallTap = function(wall: BasePart, u: number, v: number)
	useWall(wall, u, v)
end

-- (D-1110, user 2026-11-09: "하늘색 벽에 붙어 있는 사진들은 크게 보는 거 안 됨")
-- the photos are found by a ray in the world, not by buttons on the walls'
-- SurfaceGuis: the sky-blue niche (SHOP) sits behind the invisible hall panel
-- (OHU_HALL_N), which took every tap first. The ray goes through the photo
-- walls (they are invisible panels or wall faces) up to the first solid part
-- that can be seen; every photo wall on the way is a candidate, nearest first.
type WallHit = { wall: BasePart, at: Vector3 }
local function pick(ray: Ray, character: Model): {WallHit}
	local photoWalls = {}
	for _, w in ipairs(CollectionService:GetTagged("PhotoWall")) do
		if w:IsA("BasePart") and w:IsDescendantOf(workspace) then table.insert(photoWalls, w) end
	end
	-- the first thing seen that is not a photo wall (see-through parts skipped)
	local ignore: {Instance} = { character }
	for _, w in ipairs(photoWalls) do table.insert(ignore, w) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local solid = 120
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local h = workspace:Raycast(ray.Origin, ray.Direction * 120, params)
		if not h then break end
		local p = h.Instance
		if p:IsA("BasePart") and (p.Transparency >= 0.95 or not p.CanCollide and p.Transparency > 0.5) then
			table.insert(ignore, p)
		else
			solid = (h.Position - ray.Origin).Magnitude
			break
		end
	end
	-- the photo walls before it
	local out: {WallHit} = {}
	local only = RaycastParams.new()
	only.FilterType = Enum.RaycastFilterType.Include
	local left = table.clone(photoWalls)
	for _ = 1, 6 do
		if #left == 0 then break end
		only.FilterDescendantsInstances = left
		local h = workspace:Raycast(ray.Origin, ray.Direction * 120, only)
		if not h then break end
		if (h.Position - ray.Origin).Magnitude > solid + 0.8 then break end
		table.insert(out, { wall = h.Instance :: BasePart, at = h.Position })
		local i = table.find(left, h.Instance)
		if i then table.remove(left, i) end
	end
	return out
end
-- the newest photo on that wall under that point
local function photoAt(wall: BasePart, at: Vector3): Entry?
	local u, v = uvOf(wall, at)
	local best: Entry? = nil
	local bestAt = -math.huge
	for _, entry in ipairs(entries) do
		if drawnWall[entry.id] == wall then
			local size = photoSize(entry.photo.layout)
			local hu, hv = size.X / 2 / wall.Size.X, size.Y / 2 / wall.Size.Y
			if math.abs(u - entry.u) <= hu and math.abs(v - entry.v) <= hv and (entry.at or 0) > bestAt then
				best, bestAt = entry, entry.at or 0
			end
		end
	end
	return best
end

-- (D-1094) a short tap / click on a photo wall nearby: with a photo in the hand
-- it is a spot to stick it (D-1108), with empty hands the photo there is shown
-- big (D-1110). Not while placing or a window is open.
do
	local downAt: {[InputObject]: { t: number, p: Vector3 }} = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or placing then return end -- (a tap that sticks a photo is not this)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			downAt[input] = { t = os.clock(), p = input.Position }
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		local d = downAt[input]
		downAt[input] = nil
		if not d or processed or placing or picker.Visible or viewer.Visible then return end
		if os.clock() - d.t > 0.4 or (input.Position - d.p).Magnitude > 12 then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return end
		local tool = character:FindFirstChildOfClass("Tool")
		local held = heldPhotoId()
		if tool and not held then return end -- (food etc. in the hand: its own tap)
		local camera = workspace.CurrentCamera
		-- (InputObject.Position is below the top bar inset for the mouse too)
		local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
		local walls = pick(ray, character)
		if #walls == 0 then return end
		if held then
			-- the wall surface itself: the last photo wall before the solid one
			local w = walls[#walls]
			if (w.at - root.Position).Magnitude > 20 then return end
			local u, v = uvOf(w.wall, w.at)
			useWall(w.wall, u, v)
			return
		end
		-- (D-1085 / D-1108) empty hands: the photo under the tap, big
		for _, w in ipairs(walls) do
			local entry = photoAt(w.wall, w.at)
			if entry then openViewer(entry.photo) return end
		end
	end)
end

--------------------------------------------------
-- Booth barrier (local)
--------------------------------------------------

local barrier: BasePart? = nil

local function boothByKey(key: any): Model?
	for _, booth in ipairs(CollectionService:GetTagged("PhotoBooth")) do
		if booth:IsA("Model") and booth:GetAttribute("BoothKey") == key then return booth end
	end
	return nil
end

local function updateBarrier()
	local character = player.Character
	local key = character and character:GetAttribute("PhotoBooth")
	local booth = key and boothByKey(key)
	if barrier then
		barrier:Destroy()
		barrier = nil
	end
	if not booth then return end
	local floor = booth:FindFirstChild("StudioFloor")
	local stand = booth:FindFirstChild("Stand")
	local camera = booth:FindFirstChild("CameraPoint")
	if not floor or not floor:IsA("BasePart") or not stand or not stand:IsA("BasePart") or not camera or not camera:IsA("BasePart") then return end
	local away = camera.Position - stand.Position
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.1 then return end
	away = away.Unit
	-- Depth of the floor along `away`, width across it.
	local depth = math.abs(away.X) * floor.Size.X + math.abs(away.Z) * floor.Size.Z
	local width = math.abs(away.Z) * floor.Size.X + math.abs(away.X) * floor.Size.Z
	local center = floor.Position + away * (depth / 2) + Vector3.new(0, 6, 0)
	local wall = make("Part", {
		Name = "PhotoBoothBarrier",
		Anchored = true,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(width + 2, 14, 0.6),
		CFrame = CFrame.lookAt(center, center + away),
	}, workspace)
	barrier = wall
end

local characterConnection: RBXScriptConnection? = nil
local function watchCharacter(character: Model)
	if characterConnection then characterConnection:Disconnect() end
	characterConnection = character:GetAttributeChangedSignal("PhotoBooth"):Connect(updateBarrier)
	updateBarrier()
end
if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)

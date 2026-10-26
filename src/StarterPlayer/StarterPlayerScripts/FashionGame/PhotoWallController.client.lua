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

local function surfaceFor(wall: BasePart): Frame
	local existing = surfaces[wall]
	if existing then return existing end
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
		if wall:IsA("BasePart") and wallKey(wall) == key then return wall end
	end
	return nil
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
	drawn[entry.id] = frame
end

local function redrawAll()
	-- Keep only the newest MaxWallPhotos.
	while #entries > PhotoConfig.MaxWallPhotos do
		local old = table.remove(entries, 1) :: Entry
		local frame = drawn[old.id]
		if frame then frame:Destroy() end
		drawn[old.id] = nil
	end
	for index, entry in ipairs(entries) do drawEntry(entry, index) end
end

task.spawn(function()
	local ok, list = invoke("GetWall", nil)
	if ok and typeof(list) == "table" then
		for _, entry in ipairs(list) do table.insert(entries, entry) end
		redrawAll()
	end
end)

boothEvent.OnClientEvent:Connect(function(kind: any, value: any)
	if kind == "WallAdd" and typeof(value) == "table" then
		table.insert(entries, value)
		redrawAll()
	end
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

local placing: { wall: BasePart, photo: any, ghost: BasePart }? = nil

local function stopPlacing()
	if placing then placing.ghost:Destroy() end
	placing = nil
	hint.Visible = false
	cancelButton.Visible = false
end

local function startPlacing(wall: BasePart, photo: any)
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
		CFrame = wallCFrame(wall, 0.5, 0.5),
	}, workspace)
	placing = { wall = wall, photo = photo, ghost = ghost }
	local top = require(script.Parent:WaitForChild("TopBar")).bottom() + 10
	hint.Position = UDim2.new(0.5, 0, 0, top)
	cancelButton.Position = UDim2.new(0.5, 0, 0, top + 46)
	hint.Visible = true
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

RunService.RenderStepped:Connect(function()
	local state = placing
	if not state then return end
	local u, v = pointerUV(UserInputService:GetMouseLocation())
	if u and v then state.ghost.CFrame = wallCFrame(state.wall, u, v) end
end)

local posting = false
UserInputService.InputBegan:Connect(function(input, processed)
	local state = placing
	if not state or processed or posting then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
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

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "WallPrompt" then return end
	local wall = prompt.Parent
	if not wall or not wall:IsA("BasePart") or not CollectionService:HasTag(wall, "PhotoWall") then return end
	-- Holding a photo item: stick that one; otherwise choose from the album.
	local held = heldPhotoId()
	if held then
		local ok, data = invoke("GetAlbum", nil)
		if ok and typeof(data) == "table" then
			for _, photo in ipairs(data.photos or {}) do
				if photo.id == held then
					startPlacing(wall, photo)
					return
				end
			end
		end
	end
	openPicker(wall)
end)

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

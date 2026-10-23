--!strict
-- Real-looking mirrors (user 2026-10-23: "see yourself like a real mirror").
-- Roblox has no planar reflections, so each part tagged "Mirror" gets a
-- ViewportFrame on its Front face (a SurfaceGui in PlayerGui with Adornee: a
-- ViewportFrame under a Workspace part is not drawn). The viewport holds
-- copies of the room and of nearby characters placed at their mirror image
-- behind the glass; its camera sits at the real camera's position, looking
-- straight through the glass, and the frame is cropped so the visible part
-- lines up with the mirror (an off-axis view), so the reflection follows
-- the eye like a real mirror. Only mirrors near the camera and on screen
-- are updated.
--
-- Mirror part: Front face (LookVector) points into the room; Size.X / Size.Y
-- are the glass width / height. Attribute "Rounded" = true clips the image
-- to a pill shape (CanvasGroup + UICorner).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PPS = 40 -- pixels per stud on the glass
local RANGE = 34 -- update mirrors this close to the camera
local CHAR_RANGE = 26 -- reflect characters this close to the mirror
local ROOM_DEPTH, ROOM_SIDE = 44, 36 -- room copied in front of the mirror
local MAX_ROOM_PARTS = 260

type MirrorState = {
	part: BasePart,
	gui: SurfaceGui,
	frame: ViewportFrame,
	camera: Camera,
	world: WorldModel,
	room: boolean,
	chars: { [Model]: { model: Model, pairs: { { BasePart } }, count: number } },
}

local mirrors: { [BasePart]: MirrorState } = {}

-- the mirror image of a CFrame in the plane through m with normal n. The
-- rotation keeps look and up reflected (a proper rotation, so meshes are not
-- turned inside out; only their left / right detail is not swapped)
local function reflect(cf: CFrame, m: Vector3, n: Vector3): CFrame
	local p = cf.Position
	local p2 = p - 2 * (p - m):Dot(n) * n
	local look, up = cf.LookVector, cf.UpVector
	local look2 = look - 2 * look:Dot(n) * n
	local up2 = up - 2 * up:Dot(n) * n
	return CFrame.fromMatrix(p2, look2:Cross(up2), up2)
end

local function strip(x: Instance)
	for _, d in ipairs(x:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Light")
			or d:IsA("LayerCollector") or d:IsA("ProximityPrompt") or d:IsA("Sound") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
end

local function make(part: BasePart): MirrorState
	local gui = Instance.new("SurfaceGui")
	gui.Name = "MirrorGui"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.Parent = gui
	if part:GetAttribute("Rounded") then
		-- a CanvasGroup does not clip a ViewportFrame: mask the corners with a
		-- thick stroke around a rounded frame instead (in the rim's glow colour)
		local mask = Instance.new("Frame")
		mask.Size = UDim2.fromScale(1, 1)
		mask.BackgroundTransparency = 1
		mask.ZIndex = 5
		local r = math.floor(math.min(part.Size.X, part.Size.Y) * PPS / 2)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = mask
		local s = Instance.new("UIStroke")
		s.Thickness = r
		s.Color = (part:GetAttribute("MaskColor") :: Color3?) or Color3.fromRGB(255, 250, 242)
		s.Parent = mask
		mask.Parent = holder
	end
	local frame = Instance.new("ViewportFrame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(240, 220, 220)
	frame.BackgroundTransparency = 0
	frame.Ambient = Color3.fromRGB(175, 165, 165)
	frame.LightColor = Color3.fromRGB(255, 245, 238)
	frame.LightDirection = Vector3.new(0.2, -1, 0.3)
	frame.Parent = holder
	local camera = Instance.new("Camera")
	camera.Parent = frame
	frame.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = frame
	gui.Parent = player:WaitForChild("PlayerGui")
	return { part = part, gui = gui, frame = frame, camera = camera, world = world, room = false, chars = {} }
end

-- static copy of the room in front of the mirror, at its mirror image
local function copyRoom(state: MirrorState)
	local part = state.part
	local m, n = part.Position, part.CFrame.LookVector
	local box = part.CFrame * CFrame.new(0, 0, -ROOM_DEPTH / 2)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { part }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(exclude, p.Character) end
	end
	params.FilterDescendantsInstances = exclude
	local found = workspace:GetPartBoundsInBox(box, Vector3.new(ROOM_SIDE * 2, 30, ROOM_DEPTH), params)
	-- big parts first (walls, floor, furniture), small decoration only if room is left
	table.sort(found, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
	local right, up = part.CFrame.RightVector, part.CFrame.UpVector
	local w, h = part.Size.X / 2 + 0.3, part.Size.Y / 2 + 0.3
	-- half extent of a part along a unit axis
	local function half(src: BasePart, axis: Vector3): number
		local cf, s = src.CFrame, src.Size / 2
		return math.abs(cf.RightVector:Dot(axis)) * s.X + math.abs(cf.UpVector:Dot(axis)) * s.Y + math.abs(cf.LookVector:Dot(axis)) * s.Z
	end
	-- a part that reaches behind the glass (the wall it hangs on, its frame)
	-- would cover the view: skip it unless it lies off to the side of the
	-- glass (floor, ceiling, side walls)
	local function usable(src: BasePart): boolean
		local rel = src.Position - m
		if rel:Dot(n) - half(src, n) > 0.05 then return true end -- wholly in front
		if rel:Dot(n) <= 0 then return false end
		local offSide = math.abs(rel:Dot(right)) - half(src, right) > w
		local offUp = math.abs(rel:Dot(up)) - half(src, up) > h
		return offSide or offUp
	end
	local count = 0
	for _, src in ipairs(found) do
		if count >= MAX_ROOM_PARTS then break end
		if src.Transparency < 0.98 and not CollectionService:HasTag(src, "Mirror") and src.Size.Magnitude < 160
			and usable(src) then
			local ok, copy = pcall(function() return src:Clone() end)
			if ok and copy then
				for _, ch in ipairs(copy:GetChildren()) do
					if not (ch:IsA("DataModelMesh") or ch:IsA("Decal") or ch:IsA("SurfaceAppearance")) then ch:Destroy() end
				end
				local b = copy :: BasePart
				b.Anchored = true
				b.CFrame = reflect(src.CFrame, m, n)
				b.Parent = state.world
				count += 1
			end
		end
	end
	state.room = count > 20
end

local function charCopy(state: MirrorState, character: Model)
	local old = state.chars[character]
	if old then old.model:Destroy() end
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function() return character:Clone() end)
	character.Archivable = was
	if not ok or not copy then state.chars[character] = nil return end
	local originals, copies = {}, {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(originals, d) end
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(copies, d) end
	end
	strip(copy)
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
	end
	local list = {}
	if #originals == #copies then
		for i, o in ipairs(originals) do table.insert(list, { o, copies[i] }) end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	copy.Parent = state.world
	state.chars[character] = { model = copy, pairs = list, count = #character:GetDescendants() }
end

local function nearbyCharacters(state: MirrorState): { Model }
	local out = {}
	local m, n = state.part.Position, state.part.CFrame.LookVector
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if c and root then
			local d = root.Position - m
			if d.Magnitude < CHAR_RANGE and d:Dot(n) > 0 then table.insert(out, c) end
		end
	end
	return out
end

local lastCheck = 0
local function update(state: MirrorState, cam: Camera, now: number)
	local part = state.part
	local eye = cam.CFrame.Position
	local m, n = part.Position, part.CFrame.LookVector
	local up, right = part.CFrame.UpVector, -part.CFrame.RightVector -- right as seen from the front
	local rel = eye - m
	local d = rel:Dot(n)
	local w, h = part.Size.X, part.Size.Y
	if d < 0.3 or rel.Magnitude > RANGE then
		state.gui.Enabled = false
		return
	end
	local _, onScreen = cam:WorldToViewportPoint(m)
	local _, a = cam:WorldToViewportPoint(m + right * w / 2)
	local _, b = cam:WorldToViewportPoint(m - right * w / 2)
	if not (onScreen or a or b) then
		state.gui.Enabled = false
		return
	end
	state.gui.Enabled = true
	if not state.room then copyRoom(state) end
	-- characters: add / refresh / drop
	if now - lastCheck > 0.5 then
		local keep = {}
		for _, c in ipairs(nearbyCharacters(state)) do
			keep[c] = true
			local entry = state.chars[c]
			if not entry or entry.count ~= #c:GetDescendants() or entry.model.Parent == nil then charCopy(state, c) end
		end
		for c, entry in pairs(state.chars) do
			if not keep[c] or c.Parent == nil then
				entry.model:Destroy()
				state.chars[c] = nil
			end
		end
	end
	for _, entry in pairs(state.chars) do
		for _, pr in ipairs(entry.pairs) do
			local o, c = pr[1], pr[2]
			c.CFrame = reflect(o.CFrame, m, n)
			c.LocalTransparencyModifier = 0
		end
	end
	-- off-axis view: a symmetric frustum around the eye's foot point on the
	-- glass, cropped back to the glass rectangle
	local ex, ey = rel:Dot(right), rel:Dot(up)
	local hx, hy = w / 2 + math.abs(ex), h / 2 + math.abs(ey)
	state.camera.CFrame = CFrame.fromMatrix(eye, right, up, n)
	state.camera.FieldOfView = math.clamp(math.deg(2 * math.atan(hy / d)), 1, 120)
	state.frame.Size = UDim2.fromOffset(2 * hx * PPS, 2 * hy * PPS)
	state.frame.Position = UDim2.fromOffset((w / 2 + ex) * PPS, (h / 2 - ey) * PPS)
end

local function add(part: Instance)
	if not part:IsA("BasePart") or mirrors[part] then return end
	if not part:IsDescendantOf(workspace) then return end
	mirrors[part] = make(part)
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) and mirrors[part] then
			mirrors[part].gui:Destroy()
			mirrors[part] = nil
		end
	end)
end

for _, p in ipairs(CollectionService:GetTagged("Mirror")) do add(p) end
CollectionService:GetInstanceAddedSignal("Mirror"):Connect(add)

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local now = os.clock()
	for _, state in pairs(mirrors) do update(state, cam, now) end
	if now - lastCheck > 0.5 then lastCheck = now end
end)

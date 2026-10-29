--!strict
-- Draws 인생네컷 photos on the client (PHOTO_BOOTH.md §4/§7).
--
-- A photo is data, not an image: for each shot, each person's outfit
-- (OutfitSnapshot), position/yaw on the booth stand, dance clip + time, and
-- props. Here every shot is rebuilt in a ViewportFrame: a copy of the booth
-- set (backdrop colour), dressed avatars frozen at the stored pose frame, and
-- the booth camera.
--
-- Dressed avatars are built once per outfit (ApplyDescriptionResetAsync on a
-- copy of the local character, like the wardrobe cards) and cloned for every
-- shot. Rendering is queued one shot at a time to keep phones responsive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared")
local OutfitSnapshot = require(Shared:WaitForChild("OutfitSnapshot"))
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local PhotoConfig = require(Shared:WaitForChild("PhotoConfig"))
local PhotoProps = require(Shared:WaitForChild("PhotoProps"))
local BoothPose = require(Shared:WaitForChild("BoothPose"))
local RunService = game:GetService("RunService")

local PhotoRender = {}

-- Kneeling rigs (entry.kn): the pose is set after the animator every step
-- while the rig is shown.
local kneeling: {[Model]: boolean} = {}
RunService.Stepped:Connect(function()
	for rig in pairs(kneeling) do
		if rig.Parent then BoothPose.kneel(rig) else kneeling[rig] = nil end
	end
end)

-- 40 with the level booth camera (2026-10-22): people fill more of the cut;
-- four people side by side (2.8 studs apart) still fit. 48 with the camera
-- 0.8 higher (2026-10-26): tall avatars kept their heads cut off; small ones
-- still fill the lower two thirds. 56 with the deeper booths (2026-10-27,
-- user: tall avatars still lost their necks): about 13 studs show above the
-- floor at the stand.
local FOV = 56
PhotoRender.FieldOfView = FOV

-- Hidden place where dressed templates are built (ApplyDescription needs the
-- model inside the DataModel).
local holderGui = Instance.new("ScreenGui")
holderGui.Name = "PhotoRenderHolder"
holderGui.Enabled = false
holderGui.ResetOnSpawn = false
holderGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local holderViewport = Instance.new("ViewportFrame")
holderViewport.Parent = holderGui
local holderWorld = Instance.new("WorldModel")
holderWorld.Parent = holderViewport

local templates: {[string]: Model} = {}
local building: {[string]: boolean} = {}
local animations: {[string]: Animation} = {}

local function outfitKey(outfit: any): string
	local ok, encoded = pcall(function() return HttpService:JSONEncode(outfit) end)
	return if ok then encoded else tostring(outfit)
end

-- A dressed avatar for an outfit snapshot (cached).
local function template(outfit: any): Model?
	local key = outfitKey(outfit)
	while building[key] do task.wait(0.05) end
	if templates[key] then return templates[key] end
	local character = Players.LocalPlayer.Character
	local description = OutfitSnapshot.decode(outfit)
	if not character or not description then return nil end
	building[key] = true
	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") or descendant:IsA("Tool")
			or (descendant:IsA("Accessory") and descendant:GetAttribute("PhotoProp")) then
			descendant:Destroy()
		end
	end
	clone:SetAttribute("DanceKey", nil)
	clone.Parent = holderWorld
	clone:PivotTo(CFrame.new(0, 1000, 0))
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function() humanoid:ApplyDescriptionResetAsync(description) end)
	end
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = false end
	end
	local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then root.Anchored = true end
	clone.Parent = nil
	templates[key] = clone
	building[key] = nil
	return clone
end

local function animationFor(key: string): Animation?
	local dance = ClubConfig.findDance(key)
	if not dance then return nil end
	local animation = animations[key]
	if not animation then
		animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. tostring(dance.animationId)
		animations[key] = animation
	end
	return animation
end

local function colorOf(list: any, fallback: Color3): Color3
	if typeof(list) == "table" and typeof(list[1]) == "number" then
		return Color3.fromRGB(list[1], list[2] or 0, list[3] or 0)
	end
	return fallback
end

local function setPart(world: Instance, size: Vector3, cf: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = world
end

-- Fills `viewport` with one shot. `people` maps userId → { o = outfit }.
function PhotoRender.renderShot(viewport: ViewportFrame, shot: any, people: {[number]: any}, booth: any)
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
	end
	viewport.Ambient = Color3.fromRGB(170, 170, 175)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0.4, -1, 1)
	local back = colorOf(booth and booth.back, Color3.fromRGB(235, 235, 240))
	viewport.BackgroundColor3 = back
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local cam = booth and booth.cam
	camera.CFrame = if typeof(cam) == "table" and #cam == 12
		then CFrame.new(table.unpack(cam))
		else CFrame.lookAt(Vector3.new(0, -0.6, -11), Vector3.new(0, -2.6, 0))
	-- Booth set in stand space (the stand looks at the camera along -Z).
	-- (no side walls and a wide backdrop and floor: the wider view showed the
	-- darker walls at both edges of every cut, user 2026-10-26)
	setPart(world, Vector3.new(44, 16, 0.5), CFrame.new(0, 2, 6.25), back)
	setPart(world, Vector3.new(44, 0.3, 15), CFrame.new(0, -5.85, 0), back:Lerp(Color3.new(1, 1, 1), 0.4))
	for _, entry in ipairs(shot.people or {}) do
		local s = entry.s -- 키높이 발판: { x, y, z, width, height } in stand space
		if typeof(s) == "table" and #s == 5 then
			setPart(world, Vector3.new(s[4], s[5], s[4]), CFrame.new(s[1], s[2], s[3]), back:Lerp(Color3.new(0, 0, 0), 0.12))
		end
	end
	for _, entry in ipairs(shot.people or {}) do
		local info = people[entry.u]
		local base = info and info.o and template(info.o)
		if base and viewport.Parent then
			local rig = base:Clone()
			rig.Parent = world
			rig:PivotTo(CFrame.new(entry.x or 0, entry.y or -2.9, entry.z or 0) * CFrame.Angles(0, entry.r or 0, 0))
			if entry.kn then
				kneeling[rig] = true
				BoothPose.kneel(rig)
			end
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local lift = PhotoProps.liftFor(rig)
				for _, key in ipairs(entry.p or {}) do
					local accessory = PhotoProps.build(key, lift)
					if accessory then PhotoProps.wear(rig, accessory) end
				end
				local animator = humanoid:FindFirstChildOfClass("Animator")
				local animation = typeof(entry.k) == "string" and animationFor(entry.k)
				if animator and animation then
					local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
					if ok and track then
						track.Priority = Enum.AnimationPriority.Action
						track:Play(0)
						track:AdjustSpeed(0)
						local waited = 0
						while track.Length == 0 and waited < 2 do
							task.wait(0.05)
							waited += 0.05
						end
						local t = entry.t or 0
						if track.Length > 0 then
							local dance = ClubConfig.findDance(entry.k)
							track.TimePosition = if dance and dance.looped then t % track.Length else math.min(t, track.Length - 0.01)
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------
-- Photo strips
--------------------------------------------------

local queue: {() -> ()} = {}
local pumping = false
local function enqueue(job: () -> ())
	table.insert(queue, job)
	if pumping then return end
	pumping = true
	task.spawn(function()
		while #queue > 0 do
			local next = table.remove(queue, 1) :: () -> ()
			local ok, err = pcall(next)
			if not ok then warn("[PhotoRender]", err) end
		end
		pumping = false
	end)
end

export type Strip = { frame: Frame, cells: {ViewportFrame}, setColor: (frameKey: string) -> () }

-- Aspect (width / height) of a whole strip for a layout.
function PhotoRender.stripAspect(layoutKey: string): number
	local layout = PhotoConfig.findLayout(layoutKey) or PhotoConfig.Layouts[1]
	-- cells are 4:3, with an 8 % border and a footer
	local cellW, cellH = 4, 3
	local w = layout.cols * cellW + (layout.cols + 1) * 0.35
	local h = layout.rows * cellH + (layout.rows + 1) * 0.35 + 1.4
	return w / h
end

-- Frame styles (PhotoConfig frame.style): "gloss" adds a shine gradient and a
-- diagonal highlight, "glitter" scatters sparkles over the border. Drawn
-- under the cells (ZIndex 0 relative), so photos stay clean.
local SPARKLES = {
	{0.06, 0.03}, {0.5, 0.012}, {0.92, 0.05}, {0.03, 0.3}, {0.97, 0.36}, {0.04, 0.62},
	{0.96, 0.7}, {0.08, 0.95}, {0.35, 0.985}, {0.7, 0.975}, {0.95, 0.93}, {0.22, 0.02},
	{0.78, 0.015}, {0.02, 0.48}, {0.98, 0.18}, {0.6, 0.995},
}
-- Glossy / glitter frames (user 2026-10-30: no pattern, the plain frame colour
-- with a real shimmer; second pass: it could not be seen). A gradient on the
-- strip itself carries a bright band that keeps sweeping across (a gradient
-- colours only the strip, never the photos on it); glitter frames add
-- twinkling sparkles placed only on the frame's own border (clear of the
-- photos). Sticker frames (dog, cat, heart, star, flower) get emoji stickers
-- on the border and the photo corners. One Heartbeat drives every shimmer.
-- (plain tables, cleaned when the strip is gone: weak keys let Roblox drop the
-- wrappers while the GUI was still alive, so nothing moved)
local shines: {[UIGradient]: number} = {}
local twinkles: {[GuiObject]: {number}} = {}
game:GetService("RunService").Heartbeat:Connect(function()
	local t = os.clock()
	for g, phase in pairs(shines) do
		if not g:IsDescendantOf(game) then shines[g] = nil
		else g.Offset = Vector2.new(((t * 0.7 + phase) % 3) - 1.5, 0) end
	end
	for dot, spec in pairs(twinkles) do
		if not dot:IsDescendantOf(game) then twinkles[dot] = nil
		else
			local v = math.abs(math.sin(t * spec[1] + spec[2])) ^ 4
			dot.BackgroundTransparency = 1 - v
			dot.Rotation = (t * 40 * spec[1]) % 90
		end
	end
end)
local function applyStyle(strip: Frame, info: any)
	for _, name in ipairs({ "Deco", "Stickers", "Gloss" }) do
		local old = strip:FindFirstChild(name)
		if old then old:Destroy() end
	end
	if not info or info.style == "solid" or info.style == nil then return end
	if info.style == "gloss" or info.style == "glitter" then
		local base = info.color
		local lite = base:Lerp(Color3.new(1, 1, 1), if info.style == "gloss" then 0.85 else 0.65)
		local g = Instance.new("UIGradient")
		g.Name = "Gloss"
		g.Rotation = 30
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, base),
			ColorSequenceKeypoint.new(0.36, base),
			ColorSequenceKeypoint.new(0.47, lite),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.53, lite),
			ColorSequenceKeypoint.new(0.64, base),
			ColorSequenceKeypoint.new(1, base),
		})
		g.Parent = strip
		shines[g] = math.random() * 3
	end
	-- the frame's border: points that do not fall on a photo cell
	local cells = {}
	for _, c in ipairs(strip:GetChildren()) do
		if c:IsA("ViewportFrame") then table.insert(cells, { c.Position.X.Scale, c.Position.Y.Scale, c.Size.X.Scale, c.Size.Y.Scale }) end
	end
	local aspect = PhotoRender.stripAspect(if #cells == 4 and cells[2][1] > cells[1][1] then "2x2" else "1x4")
	local function onBorder(x: number, y: number, rx: number): boolean
		local ry = rx * aspect
		for _, c in ipairs(cells) do
			if x + rx > c[1] and x - rx < c[1] + c[3] and y + ry > c[2] and y - ry < c[2] + c[4] then return false end
		end
		return x > rx and x < 1 - rx and y > ry and y < 1 - ry
	end
	local top = Instance.new("Frame")
	top.Name = "Stickers"
	top.Size = UDim2.fromScale(1, 1)
	top.BackgroundTransparency = 1
	top.ZIndex = 3
	top.Parent = strip
	-- a sticker: an emoji, or an image when it is an rbxassetid (the 몽이 mascot)
	local function sticker(value: string): GuiObject
		if string.sub(value, 1, 13) == "rbxassetid://" then
			local img = Instance.new("ImageLabel")
			img.Image = value
			img.BackgroundTransparency = 1
			img.ScaleType = Enum.ScaleType.Fit
			return img
		end
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Text = value
		s.TextScaled = true
		return s
	end
	local rng = Random.new(#info.key * 7919)
	if info.style == "glitter" then
		local placed = 0
		for _ = 1, 600 do
			if placed >= 26 then break end
			local size = rng:NextNumber(0.035, 0.06)
			local x, y = rng:NextNumber(0, 1), rng:NextNumber(0, 1)
			if onBorder(x, y, size * 0.5) then
				placed += 1
				local dot = Instance.new("Frame")
				dot.Name = "Glint"
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Position = UDim2.fromScale(x, y)
				dot.Size = UDim2.fromScale(size, size)
				dot.SizeConstraint = Enum.SizeConstraint.RelativeXX
				dot.BackgroundColor3 = Color3.new(1, 1, 1)
				dot.BorderSizePixel = 0
				dot.ZIndex = 3
				dot.Parent = top
				twinkles[dot] = { rng:NextNumber(1.6, 3.6), rng:NextNumber(0, 6.3) }
			end
		end
	elseif info.style == "sticker" and typeof(info.stickers) == "table" then
		-- a sticker on a corner of every photo (alternating), two by the footer
		local list = info.stickers
		for i, c in ipairs(cells) do
			local right = i % 2 == 0
			local s = sticker(list[(i - 1) % #list + 1])
			s.Name = "Sticker"
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.Position = UDim2.fromScale(c[1] + (if right then c[3] - 0.02 else 0.02), c[2] + (if right then c[4] - 0.01 else 0.01))
			s.Size = UDim2.fromScale(c[3] * 0.3, c[3] * 0.3) -- (by the photo's width: 2x2 cells are half as wide)
			s.SizeConstraint = Enum.SizeConstraint.RelativeXX
			s.Rotation = if right then 12 else -12
			s.ZIndex = 3
			s.Parent = top
		end
		for _, x in ipairs({ 0.13, 0.87 }) do
			local s = sticker(list[#list])
			s.Name = "Sticker"
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.Position = UDim2.fromScale(x, 0.955) -- (either side of OHU)
			s.Size = UDim2.fromScale(cells[1][3] * 0.22, cells[1][3] * 0.22)
			s.SizeConstraint = Enum.SizeConstraint.RelativeXX
			s.ZIndex = 3
			s.Parent = top
		end
	end
end
-- Builds an empty strip (frame colour, cells, footer) inside `parent`,
-- sized by the parent's height. Cells are filled with fillStrip.
function PhotoRender.newStrip(parent: GuiObject, layoutKey: string, frameKey: string, footer: string?): Strip
	local layout = PhotoConfig.findLayout(layoutKey) or PhotoConfig.Layouts[1]
	local frameInfo = PhotoConfig.findFrame(frameKey) or PhotoConfig.Frames[1]
	local strip = Instance.new("Frame")
	strip.Name = "PhotoStrip"
	strip.AnchorPoint = Vector2.new(0.5, 0.5)
	strip.Position = UDim2.fromScale(0.5, 0.5)
	strip.Size = UDim2.fromScale(1, 1)
	strip.BackgroundColor3 = frameInfo.color
	strip.BorderSizePixel = 0
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = PhotoRender.stripAspect(layout.key)
	aspect.Parent = strip
	local cellW, cellH, gap = 4, 3, 0.35
	local totalW = layout.cols * cellW + (layout.cols + 1) * gap
	local totalH = layout.rows * cellH + (layout.rows + 1) * gap + 1.4
	local cells = {}
	for row = 0, layout.rows - 1 do
		for col = 0, layout.cols - 1 do
			local cell = Instance.new("ViewportFrame")
			cell.Name = "Cell" .. (#cells + 1)
			cell.BorderSizePixel = 0
			cell.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
			cell.Position = UDim2.fromScale((gap + col * (cellW + gap)) / totalW, (gap + row * (cellH + gap)) / totalH)
			cell.Size = UDim2.fromScale(cellW / totalW, cellH / totalH)
			cell.ZIndex = 2 -- (over the frame's shimmer)
			cell.Parent = strip
			table.insert(cells, cell)
		end
	end
	local label = Instance.new("TextLabel")
	label.Name = "Footer"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, (totalH - 1.3) / totalH)
	label.Size = UDim2.fromScale(1, 1.1 / totalH)
	label.Text = footer or "OHU" -- (only OHU under the photos, user 2026-10-30)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = frameInfo.text
	label.ZIndex = 2
	label.Parent = strip
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 22
	sizeLimit.Parent = label
	strip.Parent = parent
	applyStyle(strip, frameInfo)
	local function setColor(key: string)
		local info = PhotoConfig.findFrame(key)
		if info then
			strip.BackgroundColor3 = info.color
			label.TextColor3 = info.text
			applyStyle(strip, info)
		end
	end
	return { frame = strip, cells = cells, setColor = setColor }
end

-- Fills cell i with shots[i] (missing shots stay empty grey).
function PhotoRender.fillStrip(strip: Strip, shots: {any}, people: {[number]: any}, booth: any)
	for index, cell in ipairs(strip.cells) do
		local shot = shots[index]
		if shot then
			enqueue(function()
				if cell.Parent then PhotoRender.renderShot(cell, shot, people, booth) end
			end)
		else
			for _, child in ipairs(cell:GetChildren()) do child:Destroy() end
		end
	end
end

-- Queues one shot into a viewport (for pick grids).
function PhotoRender.queueShot(viewport: ViewportFrame, shot: any, people: {[number]: any}, booth: any)
	enqueue(function()
		if viewport.Parent then PhotoRender.renderShot(viewport, shot, people, booth) end
	end)
end

-- userId → person info map from a photo's/session's people list.
function PhotoRender.peopleMap(list: any): {[number]: any}
	local map = {}
	if typeof(list) == "table" then
		for _, entry in ipairs(list) do
			if typeof(entry) == "table" and typeof(entry.u) == "number" then map[entry.u] = entry end
		end
	end
	return map
end

-- A whole saved photo in `parent`.
function PhotoRender.drawPhoto(parent: GuiObject, photo: any): Strip
	local strip = PhotoRender.newStrip(parent, photo.layout, photo.frame, "OHU")
	PhotoRender.fillStrip(strip, photo.shots or {}, PhotoRender.peopleMap(photo.people), photo.booth)
	return strip
end

return PhotoRender

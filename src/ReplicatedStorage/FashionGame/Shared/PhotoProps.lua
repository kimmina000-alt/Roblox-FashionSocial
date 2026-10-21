--!strict
-- 인생네컷 props (소품): simple shapes built in code, worn as accessories.
-- The server puts them on characters during a shoot; the client builds the
-- same ones again when it redraws a saved photo. Keys: PhotoConfig.Props.

local PhotoProps = {}

type PartSpec = { size: Vector3, offset: CFrame, color: Color3, shape: string?, neon: boolean? }
type PropSpec = { attach: string, handleOffset: CFrame, parts: {PartSpec} }

local PINK = Color3.fromRGB(255, 120, 180)
local BLACK = Color3.fromRGB(25, 25, 30)
local WHITE = Color3.fromRGB(250, 250, 250)
local GOLD = Color3.fromRGB(240, 200, 60)
local RED = Color3.fromRGB(240, 60, 90)

-- handleOffset: where the handle sits relative to the character attachment.
local SPECS: {[string]: PropSpec} = {
	catears = { attach = "HatAttachment", handleOffset = CFrame.new(0, 0.15, 0), parts = {
		{ size = Vector3.new(0.45, 0.5, 0.15), offset = CFrame.new(-0.42, 0.2, 0) * CFrame.Angles(0, 0, math.rad(15)), color = BLACK, shape = "Wedge" },
		{ size = Vector3.new(0.45, 0.5, 0.15), offset = CFrame.new(0.42, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-15)), color = BLACK, shape = "Wedge" },
		{ size = Vector3.new(0.25, 0.3, 0.05), offset = CFrame.new(-0.42, 0.17, -0.06) * CFrame.Angles(0, 0, math.rad(15)), color = PINK, shape = "Wedge" },
		{ size = Vector3.new(0.25, 0.3, 0.05), offset = CFrame.new(0.42, 0.17, -0.06) * CFrame.Angles(0, 0, math.rad(-15)), color = PINK, shape = "Wedge" },
	} },
	bunny = { attach = "HatAttachment", handleOffset = CFrame.new(0, 0.1, 0), parts = {
		{ size = Vector3.new(0.3, 1.1, 0.15), offset = CFrame.new(-0.25, 0.55, 0) * CFrame.Angles(0, 0, math.rad(8)), color = WHITE },
		{ size = Vector3.new(0.3, 1.1, 0.15), offset = CFrame.new(0.25, 0.55, 0) * CFrame.Angles(0, 0, math.rad(-8)), color = WHITE },
		{ size = Vector3.new(0.15, 0.8, 0.05), offset = CFrame.new(-0.25, 0.55, -0.08) * CFrame.Angles(0, 0, math.rad(8)), color = PINK },
		{ size = Vector3.new(0.15, 0.8, 0.05), offset = CFrame.new(0.25, 0.55, -0.08) * CFrame.Angles(0, 0, math.rad(-8)), color = PINK },
	} },
	bow = { attach = "HatAttachment", handleOffset = CFrame.new(0.3, 0.05, 0) * CFrame.Angles(0, 0, math.rad(-20)), parts = {
		{ size = Vector3.new(0.2, 0.2, 0.2), offset = CFrame.new(), color = PINK },
		{ size = Vector3.new(0.35, 0.4, 0.15), offset = CFrame.new(-0.25, 0, 0) * CFrame.Angles(0, math.rad(90), 0), color = PINK, shape = "Wedge" },
		{ size = Vector3.new(0.35, 0.4, 0.15), offset = CFrame.new(0.25, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), color = PINK, shape = "Wedge" },
	} },
	crown = { attach = "HatAttachment", handleOffset = CFrame.new(0, 0.18, 0), parts = {
		{ size = Vector3.new(0.35, 0.9, 0.9), offset = CFrame.Angles(0, 0, math.rad(90)), color = GOLD, shape = "Cylinder" },
		{ size = Vector3.new(0.2, 0.25, 0.15), offset = CFrame.new(0, 0.28, -0.4), color = GOLD, shape = "Wedge" },
		{ size = Vector3.new(0.2, 0.25, 0.15), offset = CFrame.new(-0.35, 0.28, -0.2), color = GOLD, shape = "Wedge" },
		{ size = Vector3.new(0.2, 0.25, 0.15), offset = CFrame.new(0.35, 0.28, -0.2), color = GOLD, shape = "Wedge" },
		{ size = Vector3.new(0.12, 0.12, 0.12), offset = CFrame.new(0, 0.05, -0.46), color = RED, neon = true },
	} },
	shades = { attach = "FaceFrontAttachment", handleOffset = CFrame.new(0, 0.12, -0.05), parts = {
		{ size = Vector3.new(1, 0.06, 0.06), offset = CFrame.new(0, 0.08, 0), color = BLACK },
		{ size = Vector3.new(0.38, 0.24, 0.05), offset = CFrame.new(-0.24, 0, 0), color = BLACK },
		{ size = Vector3.new(0.38, 0.24, 0.05), offset = CFrame.new(0.24, 0, 0), color = BLACK },
	} },
	heart = { attach = "FaceFrontAttachment", handleOffset = CFrame.new(0, 0.12, -0.05), parts = {
		{ size = Vector3.new(1, 0.05, 0.05), offset = CFrame.new(0, 0.08, 0), color = RED },
		{ size = Vector3.new(0.3, 0.3, 0.05), offset = CFrame.new(-0.24, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), color = PINK, neon = true },
		{ size = Vector3.new(0.3, 0.3, 0.05), offset = CFrame.new(0.24, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), color = PINK, neon = true },
	} },
}

local function makePart(spec: PartSpec): BasePart
	local part: BasePart
	if spec.shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if spec.shape == "Cylinder" then block.Shape = Enum.PartType.Cylinder end
		part = block
	end
	part.Size = spec.size
	part.Color = spec.color
	part.Material = if spec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	return part
end

-- How far above the head top the hair reaches (studs, 0..2). Hat props are
-- lifted by most of it so big hair does not swallow them (user report
-- 2026-10-21). Server (live avatar) and PhotoRender (saved photo) both use it.
function PhotoProps.liftFor(character: Model): number
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return 0 end
	local headTop = head.Size.Y / 2
	local top = headTop
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") and not accessory:GetAttribute("PhotoProp") then
			local handle = accessory:FindFirstChild("Handle")
			local onHead = handle and (handle:FindFirstChild("HatAttachment") or handle:FindFirstChild("HairAttachment"))
			if handle and handle:IsA("BasePart") and onHead then
				local up = (handle.Position - head.Position):Dot(head.CFrame.UpVector)
				top = math.max(top, up + handle.Size.Y / 2)
			end
		end
	end
	return math.clamp((top - headTop) * 0.8, 0, 2)
end

-- A new Accessory for the prop key, or nil for an unknown key. `lift` (studs)
-- raises hat props above the hair (PhotoProps.liftFor).
function PhotoProps.build(key: string, lift: number?): Accessory?
	local spec = SPECS[key]
	if not spec then return nil end
	local accessory = Instance.new("Accessory")
	accessory.Name = "PhotoProp_" .. key
	accessory:SetAttribute("PhotoProp", key)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.1, 0.1, 0.1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = accessory
	local attachment = Instance.new("Attachment")
	attachment.Name = spec.attach
	-- The handle sits at handleOffset from the character's attachment.
	local offset = spec.handleOffset
	if spec.attach == "HatAttachment" and lift and lift > 0 then
		offset = CFrame.new(0, lift, 0) * offset
	end
	attachment.CFrame = offset:Inverse()
	attachment.Parent = handle
	for index, partSpec in ipairs(spec.parts) do
		local part = makePart(partSpec)
		part.Name = "Piece" .. index
		part.CFrame = partSpec.offset
		part.Parent = handle
		-- A Weld (fixed C0 offset), not a WeldConstraint: a WeldConstraint made
		-- before the accessory is in the world kept the pieces where they were
		-- built, ~100 studs from the head, so props looked invisible
		-- (user report 2026-10-21).
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = partSpec.offset
		weld.Parent = part
	end
	return accessory
end

-- Puts a prop on a rig that is not in Workspace (PhotoRender's WorldModel).
-- Humanoid:AddAccessory only welds inside Workspace, so in a saved photo the
-- prop stayed at the stand origin, in the middle of the picture (user report
-- 2026-10-22). Here the weld is made by hand from the matching attachments.
function PhotoProps.wear(rig: Model, accessory: Accessory)
	local handle = accessory:FindFirstChild("Handle") :: BasePart?
	if not handle then return end
	local handleAttachment = handle:FindFirstChildOfClass("Attachment")
	local bodyAttachment: Attachment? = nil
	if handleAttachment then
		for _, descendant in ipairs(rig:GetDescendants()) do
			if descendant:IsA("Attachment") and descendant.Name == handleAttachment.Name
				and descendant.Parent and descendant.Parent:IsA("BasePart") and descendant.Parent.Parent == rig then
				bodyAttachment = descendant
				break
			end
		end
	end
	accessory.Parent = rig
	if not handleAttachment or not bodyAttachment then return end
	local bodyPart = bodyAttachment.Parent :: BasePart
	handle.CFrame = bodyAttachment.WorldCFrame * handleAttachment.CFrame:Inverse()
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = handle
	weld.Part1 = bodyPart
	weld.C0 = handleAttachment.CFrame
	weld.C1 = bodyAttachment.CFrame
	weld.Parent = handle
end

-- Prop keys currently worn by a character.
function PhotoProps.worn(character: Model): {string}
	local keys = {}
	for _, child in ipairs(character:GetChildren()) do
		local key = child:IsA("Accessory") and child:GetAttribute("PhotoProp")
		if typeof(key) == "string" then table.insert(keys, key) end
	end
	return keys
end

return PhotoProps

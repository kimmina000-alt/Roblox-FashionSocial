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

-- A new Accessory for the prop key, or nil for an unknown key.
function PhotoProps.build(key: string): Accessory?
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
	attachment.CFrame = spec.handleOffset:Inverse()
	attachment.Parent = handle
	for index, partSpec in ipairs(spec.parts) do
		local part = makePart(partSpec)
		part.Name = "Piece" .. index
		part.CFrame = partSpec.offset
		part.Parent = handle
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end
	return accessory
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

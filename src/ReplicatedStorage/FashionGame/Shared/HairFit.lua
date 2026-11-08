--!strict
-- Accessory fit: position, rotation and size of a worn rigid accessory, done
-- by the game itself (user 2026-11-01). First for hair only (D-705): Roblox's
-- avatar rules leave hair out of the accessories a game may move
-- (AccessoryRefinementTypes), and ApplyDescription keeps a hair's
-- AccessoryDescription.Position but does not move it. Since D-709 for every
-- rigid accessory, with wider ranges than Roblox's rules allow (their size
-- range was about 0.9..1.1) and a size for hair too.
--
-- How: an accessory hangs from the body by an AccessoryRigidConstraint
-- between the handle's attachment and the body's. Shifting the handle's
-- attachment by the inverse of the offset moves the accessory by the offset,
-- in the body attachment's frame (the frame the official sliders used); the
-- size scales the handle (and a SpecialMesh) and the attachment's place in
-- it, so the accessory grows about the point it hangs from.
--
-- Offsets are kept per asset id: { p = Vector3, r = Vector3 (degrees), s = number }.
-- The server saves them (wallet.hair) and sets them on the live character;
-- the avatar editor sets them on its preview the same way, as the sliders move.

local HairFit = {}

local IS_SERVER = game:GetService("RunService"):IsServer()

HairFit.Position = { Min = Vector3.new(-1, -1, -1), Max = Vector3.new(1, 1, 1) }
HairFit.Rotation = { Min = Vector3.new(-45, -45, -45), Max = Vector3.new(45, 45, 45) }
HairFit.Scale = { Min = 0.5, Max = 2 }

export type Offset = { p: Vector3, r: Vector3, s: number? }

local function clampVector(v: Vector3, bounds: { Min: Vector3, Max: Vector3 }): Vector3
	return Vector3.new(
		math.clamp(v.X, bounds.Min.X, bounds.Max.X),
		math.clamp(v.Y, bounds.Min.Y, bounds.Max.Y),
		math.clamp(v.Z, bounds.Min.Z, bounds.Max.Z)
	)
end

-- A clean offset from anything a client sent (or nil when it is not one).
function HairFit.clean(value: any): Offset?
	if typeof(value) ~= "table" or typeof(value.p) ~= "Vector3" or typeof(value.r) ~= "Vector3" then return nil end
	local p, r = value.p :: Vector3, value.r :: Vector3
	if p ~= p or r ~= r then return nil end -- NaN
	local s = if typeof(value.s) == "number" and value.s == value.s then value.s else 1
	return { p = clampVector(p, HairFit.Position), r = clampVector(r, HairFit.Rotation), s = math.clamp(s, HairFit.Scale.Min, HairFit.Scale.Max) }
end

function HairFit.isZero(offset: Offset?): boolean
	return offset == nil or (offset.p.Magnitude < 1e-3 and offset.r.Magnitude < 1e-2 and math.abs((offset.s or 1) - 1) < 1e-3)
end

local function scaleOf(offset: Offset?): number
	return if offset and offset.s then offset.s else 1
end

local function offsetCFrame(offset: Offset?): CFrame
	if not offset then return CFrame.identity end
	local r = offset.r
	return CFrame.new(offset.p) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
end

local function scaled(cf: CFrame, s: number): CFrame
	return CFrame.new(cf.Position * s) * cf.Rotation
end

-- The handle's attachment that holds this accessory to the body.
local function handleAttachment(accessory: Accessory): Attachment?
	local handle = accessory:FindFirstChild("Handle")
	if not handle then return nil end
	local rigid = handle:FindFirstChild("AccessoryRigidConstraint")
	if rigid and rigid:IsA("RigidConstraint") and rigid.Attachment0 and rigid.Attachment0:IsDescendantOf(handle) then
		return rigid.Attachment0
	end
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Attachment") and child.Name:find("Attachment") then return child end
	end
	return nil
end

-- The size Roblox gave the handle (and its SpecialMesh), kept the first time.
local function baseSize(handle: BasePart): (Vector3, Vector3?)
	local size = handle:GetAttribute("HairFitSize")
	if typeof(size) ~= "Vector3" then
		size = handle.Size
		handle:SetAttribute("HairFitSize", size)
	end
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	local meshScale: Vector3? = nil
	if mesh then
		local kept = mesh:GetAttribute("HairFitScale")
		if typeof(kept) ~= "Vector3" then
			kept = mesh.Scale
			mesh:SetAttribute("HairFitScale", kept)
		end
		meshScale = kept :: Vector3
	end
	return size :: Vector3, meshScale
end

-- Sets one accessory to an offset (nil or zero: back where Roblox put it).
function HairFit.set(accessory: Accessory, offset: Offset?)
	local attachment = handleAttachment(accessory)
	local handle = accessory:FindFirstChild("Handle") :: BasePart?
	if not attachment or not handle then return end
	-- (where Roblox placed the handle, for the preview rig: kept before anything changes)
	if not accessory:IsDescendantOf(workspace) and typeof(handle:GetAttribute("HairFitPlaced")) ~= "CFrame" then
		handle:SetAttribute("HairFitPlaced", handle.CFrame)
	end
	local base = attachment:GetAttribute("HairFitBase")
	if typeof(base) ~= "CFrame" then
		base = attachment.CFrame
		attachment:SetAttribute("HairFitBase", base)
	end
	local s = scaleOf(offset)
	local size, meshScale = baseSize(handle)
	handle.Size = size * s
	handle:SetAttribute("HairFitSizeSet", handle.Size)
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if mesh and meshScale then mesh.Scale = meshScale * s end
	attachment.CFrame = if HairFit.isZero(offset) then base else scaled(base :: CFrame, s) * offsetCFrame(offset):Inverse()
	-- (what was set: a later ApplyDescription that keeps this accessory puts
	-- the attachment back, and HairFit.changedByEngine tells that apart)
	attachment:SetAttribute("HairFitSet", attachment.CFrame)
	-- a preview rig outside Workspace (a ViewportFrame's WorldModel) runs no
	-- physics, so its constraint never moves the handle: place it by hand.
	-- (Never in Workspace: moving one part there moves the whole character.)
	if not accessory:IsDescendantOf(workspace) then HairFit.preview(accessory, offset) end
end

-- Places an accessory on a preview rig (never in Workspace) from where Roblox
-- placed it: moved by the offset and scaled about the body attachment it
-- hangs from. (D-706) placing it from the two attachments put a zero offset
-- somewhere else than Roblox did (lower and forward on the preview).
function HairFit.preview(accessory: Accessory, offset: Offset?)
	local handle = accessory:FindFirstChild("Handle") :: BasePart?
	local rigid = handle and handle:FindFirstChild("AccessoryRigidConstraint")
	local body = rigid and rigid:IsA("RigidConstraint") and rigid.Attachment1
	if not handle or not body then return end
	local placed = handle:GetAttribute("HairFitPlaced")
	if typeof(placed) ~= "CFrame" then
		placed = handle.CFrame
		handle:SetAttribute("HairFitPlaced", placed)
	end
	if HairFit.isZero(offset) then
		handle.CFrame = placed :: CFrame
	else
		-- (while the constraint holds, the handle is part of the rig's
		-- assembly and moving it moves the whole rig: the still preview rig
		-- doesn't need it)
		(rigid :: RigidConstraint).Enabled = false
		local pivot = body.WorldCFrame
		handle.CFrame = pivot * offsetCFrame(offset) * scaled(pivot:Inverse() * (placed :: CFrame), scaleOf(offset))
	end
end

-- Called when a handle's attachment moved: true (and the new place taken as
-- the base) when it was not HairFit.set that moved it.
function HairFit.changedByEngine(attachment: Attachment): boolean
	local set = attachment:GetAttribute("HairFitSet")
	if typeof(set) ~= "CFrame" then return false end
	local now = attachment.CFrame
	if (now.Position - set.Position).Magnitude < 1e-4 and now.LookVector:Dot(set.LookVector) > 0.99999
		and now.UpVector:Dot(set.UpVector) > 0.99999 then
		return false
	end
	attachment:SetAttribute("HairFitBase", now)
	attachment:SetAttribute("HairFitSet", nil)
	return true
end

-- The same for the handle's size (Roblox rescales accessories with the body).
function HairFit.sizeChangedByEngine(handle: BasePart): boolean
	local set = handle:GetAttribute("HairFitSizeSet")
	if typeof(set) ~= "Vector3" or (handle.Size - set).Magnitude < 1e-4 then return false end
	handle:SetAttribute("HairFitSize", handle.Size)
	handle:SetAttribute("HairFitSizeSet", nil)
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if mesh then mesh:SetAttribute("HairFitScale", nil) end
	return true
end

-- Sets every rigid accessory on a humanoid's character from a map
-- assetId → offset. Accessories are matched to their asset ids through the
-- humanoid's own HumanoidDescription (GetAppliedInstance); with only one
-- hair worn and no match, that one is used.
function HairFit.apply(humanoid: Humanoid, offsets: {[number]: Offset})
	local character = humanoid.Parent
	if not character then return end
	local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
	local matched: {[Accessory]: boolean} = {}
	local hairOffset: Offset? = nil
	local hairIds = 0
	if description then
		for _, child in ipairs(description:GetChildren()) do
			if child:IsA("AccessoryDescription") and not child.IsLayered then
				if child.AccessoryType == Enum.AccessoryType.Hair then
					hairIds += 1
					hairOffset = offsets[child.AssetId]
				end
				local ok, instance = pcall(function() return child:GetAppliedInstance() end)
				if ok and instance and instance:IsA("Accessory") and instance.Parent == character then
					matched[instance] = true
					HairFit.set(instance, offsets[child.AssetId])
					-- (D-1052) the server names each accessory's asset id for the clients
					if IS_SERVER and instance:GetAttribute("HairFitId") ~= child.AssetId then
						instance:SetAttribute("HairFitId", child.AssetId)
					end
				end
			end
		end
	end
	-- (D-1052, user 2026-11-09, KOYA video: "실시간으로 아이템 위치 조절할 때 반영
	-- 잘 되는 점") on a client GetAppliedInstance finds nothing on the live
	-- character, so the avatar editor's sliders moved only the preview copy (and
	-- one hair): the live accessories are found by the id the server put on them
	for _, accessory in ipairs(character:GetChildren()) do
		local id = accessory:GetAttribute("HairFitId")
		if accessory:IsA("Accessory") and not matched[accessory] and typeof(id) == "number" then
			matched[accessory] = true
			HairFit.set(accessory, offsets[id])
		end
	end
	if next(matched) == nil and hairIds == 1 then
		for _, accessory in ipairs(character:GetChildren()) do
			if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Hair then
				HairFit.set(accessory, hairOffset)
			end
		end
	end
end

-- Offsets ⇄ the plain tables saved in the DataStore:
-- { "id" = { px, py, pz, rx, ry, rz, s } } (no s before D-709)
function HairFit.toSaved(offsets: {[number]: Offset}): {[string]: {number}}
	local saved = {}
	for id, offset in pairs(offsets) do
		if not HairFit.isZero(offset) then
			saved[tostring(id)] = { offset.p.X, offset.p.Y, offset.p.Z, offset.r.X, offset.r.Y, offset.r.Z, scaleOf(offset) }
		end
	end
	return saved
end

function HairFit.fromSaved(saved: any): {[number]: Offset}
	local offsets = {}
	if typeof(saved) ~= "table" then return offsets end
	for key, list in pairs(saved) do
		local id = tonumber(key)
		if id and typeof(list) == "table" and (#list == 6 or #list == 7) then
			local ok = true
			for _, n in ipairs(list) do if typeof(n) ~= "number" or n ~= n then ok = false end end
			if ok then
				local offset = HairFit.clean({ p = Vector3.new(list[1], list[2], list[3]), r = Vector3.new(list[4], list[5], list[6]), s = list[7] or 1 })
				if offset then offsets[id] = offset end
			end
		end
	end
	return offsets
end

return HairFit

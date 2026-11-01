--!strict
-- Hair position (user 2026-11-01, D-705). Roblox's avatar rules leave hair out
-- of the accessories a game may move (AccessoryRefinementTypes), and
-- ApplyDescription keeps a hair's AccessoryDescription.Position but does not
-- move it. So the game moves it itself: a hair hangs from its head by an
-- AccessoryRigidConstraint between the handle's attachment and the head's;
-- shifting the handle's attachment by the inverse of the offset moves the
-- hair by the offset, in the head attachment's frame (the same frame the
-- official accessory sliders use).
--
-- Offsets are kept per hair asset id: { p = Vector3, r = Vector3 (degrees) }.
-- The server saves them (wallet.hair) and sets them on the live character;
-- the avatar editor sets them on its preview the same way.

local HairFit = {}

HairFit.Position = { Min = Vector3.new(-0.6, -0.6, -0.6), Max = Vector3.new(0.6, 0.6, 0.6) }
HairFit.Rotation = { Min = Vector3.new(-25, -25, -25), Max = Vector3.new(25, 25, 25) }

export type Offset = { p: Vector3, r: Vector3 }

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
	return { p = clampVector(p, HairFit.Position), r = clampVector(r, HairFit.Rotation) }
end

function HairFit.isZero(offset: Offset?): boolean
	return offset == nil or (offset.p.Magnitude < 1e-3 and offset.r.Magnitude < 1e-2)
end

local function offsetCFrame(offset: Offset): CFrame
	local r = offset.r
	return CFrame.new(offset.p) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
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

-- Sets one hair to an offset (nil or zero: back where Roblox put it).
function HairFit.set(accessory: Accessory, offset: Offset?)
	local attachment = handleAttachment(accessory)
	if not attachment then return end
	local base = attachment:GetAttribute("HairFitBase")
	if typeof(base) ~= "CFrame" then
		base = attachment.CFrame
		attachment:SetAttribute("HairFitBase", base)
	end
	attachment.CFrame = if HairFit.isZero(offset) then base else (base :: CFrame) * offsetCFrame(offset :: Offset):Inverse()
	-- (what was set: a later ApplyDescription that keeps this accessory puts
	-- the attachment back, and HairFit.changedByEngine tells that apart)
	attachment:SetAttribute("HairFitSet", attachment.CFrame)
	-- a preview rig outside Workspace (a ViewportFrame's WorldModel) runs no
	-- physics, so its constraint never moves the handle: place it by hand.
	-- (Never in Workspace: moving one part there moves the whole character.)
	if not accessory:IsDescendantOf(workspace) then
		local handle = accessory:FindFirstChild("Handle") :: BasePart?
		local rigid = handle and handle:FindFirstChild("AccessoryRigidConstraint")
		local body = rigid and rigid:IsA("RigidConstraint") and rigid.Attachment1
		if handle and body then
			-- Moved from where Roblox placed it, about the body attachment:
			-- (D-706) placing it from the two attachments put a zero offset
			-- somewhere else than Roblox did (lower and forward on the preview)
			local placed = handle:GetAttribute("HairFitPlaced")
			if typeof(placed) ~= "CFrame" then
				placed = handle.CFrame
				handle:SetAttribute("HairFitPlaced", placed)
			end
			if HairFit.isZero(offset) then
				handle.CFrame = placed :: CFrame
			else
				-- (while the constraint holds, the handle is part of the rig's
				-- assembly and moving it moves the whole rig: the still
				-- preview rig doesn't need it)
				(rigid :: RigidConstraint).Enabled = false
				local pivot = body.WorldCFrame
				handle.CFrame = pivot * offsetCFrame(offset :: Offset) * pivot:Inverse() * (placed :: CFrame)
			end
		end
	end
end

-- Called when a hair handle's attachment moved: true (and the new place taken
-- as the base) when it was not HairFit.set that moved it.
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

-- Sets every hair on a humanoid's character from a map assetId → offset.
-- Hair accessories are matched to their asset ids through the humanoid's own
-- HumanoidDescription (GetAppliedInstance); with only one hair worn and no
-- match, that one is used.
function HairFit.apply(humanoid: Humanoid, offsets: {[number]: Offset})
	local character = humanoid.Parent
	if not character then return end
	local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
	local matched: {[Accessory]: boolean} = {}
	local lastOffset: Offset? = nil
	local hairIds = 0
	if description then
		for _, child in ipairs(description:GetChildren()) do
			if child:IsA("AccessoryDescription") and child.AccessoryType == Enum.AccessoryType.Hair and not child.IsLayered then
				hairIds += 1
				lastOffset = offsets[child.AssetId]
				local ok, instance = pcall(function() return child:GetAppliedInstance() end)
				if ok and instance and instance:IsA("Accessory") and instance.Parent == character then
					matched[instance] = true
					HairFit.set(instance, offsets[child.AssetId])
				end
			end
		end
	end
	if next(matched) == nil and hairIds == 1 then
		for _, accessory in ipairs(character:GetChildren()) do
			if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Hair then
				HairFit.set(accessory, lastOffset)
			end
		end
	end
end

-- Offsets ⇄ the plain tables saved in the DataStore: { "id" = { px, py, pz, rx, ry, rz } }
function HairFit.toSaved(offsets: {[number]: Offset}): {[string]: {number}}
	local saved = {}
	for id, offset in pairs(offsets) do
		if not HairFit.isZero(offset) then
			saved[tostring(id)] = { offset.p.X, offset.p.Y, offset.p.Z, offset.r.X, offset.r.Y, offset.r.Z }
		end
	end
	return saved
end

function HairFit.fromSaved(saved: any): {[number]: Offset}
	local offsets = {}
	if typeof(saved) ~= "table" then return offsets end
	for key, list in pairs(saved) do
		local id = tonumber(key)
		if id and typeof(list) == "table" and #list == 6 then
			local ok = true
			for _, n in ipairs(list) do if typeof(n) ~= "number" or n ~= n then ok = false end end
			if ok then
				local offset = HairFit.clean({ p = Vector3.new(list[1], list[2], list[3]), r = Vector3.new(list[4], list[5], list[6]) })
				if offset then offsets[id] = offset end
			end
		end
	end
	return offsets
end

return HairFit

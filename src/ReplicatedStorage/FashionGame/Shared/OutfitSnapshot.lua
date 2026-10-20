--!strict
-- SupportedAppearanceSnapshot (Stage 2 Wardrobe, D-019/D-021).
--
-- Converts a HumanoidDescription to a plain, DataStore-safe table and back.
-- Only values HumanoidDescription itself can express are stored, each in its own
-- typed section (accessories, classic clothing, body parts, scales, colours,
-- animations, emotes, makeup) instead of one flat asset-id list. Rigid accessory
-- Position/Rotation/Scale and layered/makeup Order are included, so outfits
-- saved after Avatar Editor adjustments restore with those adjustments.
--
-- Shared by the server (save/restore) and the client (outfit card previews).

local OutfitSnapshot = {}

OutfitSnapshot.VERSION = 1

local ASSET_PROPERTIES = {
	-- classic clothing / face
	"Shirt", "Pants", "GraphicTShirt", "Face",
	-- body parts
	"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
	-- animations
	"IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation",
	"FallAnimation", "ClimbAnimation", "SwimAnimation", "MoodAnimation",
}
OutfitSnapshot.ASSET_PROPERTIES = ASSET_PROPERTIES

local SCALE_PROPERTIES = {
	"BodyTypeScale", "DepthScale", "HeadScale", "HeightScale", "ProportionScale", "WidthScale",
}

local COLOR_PROPERTIES = {
	"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor",
}

local MAX_ACCESSORIES = 30
local MAX_MAKEUP = 10
local MAX_EMOTES = 20

local function round(value: number, places: number): number
	local factor = 10 ^ places
	return math.floor(value * factor + 0.5) / factor
end

local function vec(v: Vector3): {number}
	return { round(v.X, 3), round(v.Y, 3), round(v.Z, 3) }
end

local function toVector(value: any, fallback: Vector3): Vector3
	if typeof(value) ~= "table" then return fallback end
	local x, y, z = value[1], value[2], value[3]
	if typeof(x) ~= "number" or typeof(y) ~= "number" or typeof(z) ~= "number" then
		return fallback
	end
	if x ~= x or y ~= y or z ~= z then return fallback end
	return Vector3.new(x, y, z)
end

local function isAssetId(value: any): boolean
	return typeof(value) == "number" and value > 0 and value % 1 == 0 and value < 2 ^ 53
end

local function enumByName(enumType: any, name: any): any
	if typeof(name) ~= "string" then return nil end
	local ok, item = pcall(function()
		return enumType[name]
	end)
	return if ok then item else nil
end

-- HumanoidDescription -> plain table.
function OutfitSnapshot.encode(description: HumanoidDescription): {[string]: any}
	local snapshot: {[string]: any} = { v = OutfitSnapshot.VERSION }

	local assets = {}
	for _, property in ipairs(ASSET_PROPERTIES) do
		local value = (description :: any)[property]
		if typeof(value) == "number" and value > 0 then
			assets[property] = value
		end
	end
	snapshot.assets = assets

	local scales = {}
	for _, property in ipairs(SCALE_PROPERTIES) do
		scales[property] = round((description :: any)[property], 3)
	end
	snapshot.scales = scales

	local colors = {}
	for _, property in ipairs(COLOR_PROPERTIES) do
		colors[property] = ((description :: any)[property] :: Color3):ToHex()
	end
	snapshot.colors = colors

	local accessories = {}
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("AccessoryDescription") and child.AssetId > 0 then
			table.insert(accessories, {
				id = child.AssetId,
				t = child.AccessoryType.Name,
				l = child.IsLayered,
				o = child.Order,
				pf = round(child.Puffiness, 3),
				p = vec(child.Position),
				r = vec(child.Rotation),
				s = vec(child.Scale),
			})
		end
	end
	snapshot.accessories = accessories

	local makeup = {}
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("MakeupDescription") and child.AssetId > 0 then
			table.insert(makeup, { id = child.AssetId, t = child.MakeupType.Name, o = child.Order })
		end
	end
	snapshot.makeup = makeup

	local emotes = {}
	for name, ids in pairs(description:GetEmotes()) do
		table.insert(emotes, { n = name, ids = table.clone(ids) })
	end
	snapshot.emotes = emotes
	local equipped = {}
	for _, entry in ipairs(description:GetEquippedEmotes()) do
		table.insert(equipped, { n = entry.Name, s = entry.Slot })
	end
	snapshot.equipped = equipped

	return snapshot
end

-- Plain table -> new HumanoidDescription. Invalid fields are dropped (never
-- guessed), so a damaged record restores whatever is still valid.
function OutfitSnapshot.decode(snapshot: any): HumanoidDescription?
	if typeof(snapshot) ~= "table" or snapshot.v ~= OutfitSnapshot.VERSION then
		return nil
	end
	local description = Instance.new("HumanoidDescription")

	if typeof(snapshot.assets) == "table" then
		for _, property in ipairs(ASSET_PROPERTIES) do
			local value = snapshot.assets[property]
			if isAssetId(value) then
				(description :: any)[property] = value
			end
		end
	end

	if typeof(snapshot.scales) == "table" then
		for _, property in ipairs(SCALE_PROPERTIES) do
			local value = snapshot.scales[property]
			if typeof(value) == "number" and value == value then
				(description :: any)[property] = math.clamp(value, 0, 2)
			end
		end
	end

	if typeof(snapshot.colors) == "table" then
		for _, property in ipairs(COLOR_PROPERTIES) do
			local value = snapshot.colors[property]
			if typeof(value) == "string" and #value == 6 then
				local ok, color = pcall(Color3.fromHex, value)
				if ok then (description :: any)[property] = color end
			end
		end
	end

	if typeof(snapshot.accessories) == "table" then
		-- AccessoryDescription instances are parented directly; SetAccessories
		-- expects property tables, not instances (verified in Studio).
		for index, entry in ipairs(snapshot.accessories) do
			if index > MAX_ACCESSORIES then break end
			if typeof(entry) == "table" and isAssetId(entry.id) then
				local accessoryType = enumByName(Enum.AccessoryType, entry.t)
				if accessoryType then
					local accessory = Instance.new("AccessoryDescription")
					accessory.AssetId = entry.id
					accessory.AccessoryType = accessoryType
					accessory.IsLayered = entry.l == true
					if typeof(entry.o) == "number" then accessory.Order = math.floor(entry.o) end
					if typeof(entry.pf) == "number" then accessory.Puffiness = math.clamp(entry.pf, 0, 2) end
					if not accessory.IsLayered then
						accessory.Position = toVector(entry.p, Vector3.zero)
						accessory.Rotation = toVector(entry.r, Vector3.zero)
						accessory.Scale = toVector(entry.s, Vector3.one)
					end
					accessory.Parent = description
				end
			end
		end
	end

	if typeof(snapshot.makeup) == "table" then
		for index, entry in ipairs(snapshot.makeup) do
			if index > MAX_MAKEUP then break end
			if typeof(entry) == "table" and isAssetId(entry.id) then
				local makeupType = enumByName(Enum.MakeupType, entry.t)
				if makeupType then
					local makeup = Instance.new("MakeupDescription")
					makeup.AssetId = entry.id
					makeup.MakeupType = makeupType
					if typeof(entry.o) == "number" then makeup.Order = math.floor(entry.o) end
					makeup.Parent = description
				end
			end
		end
	end

	if typeof(snapshot.emotes) == "table" then
		local emotes = {}
		local count = 0
		for _, entry in ipairs(snapshot.emotes) do
			if typeof(entry) == "table" and typeof(entry.n) == "string" and typeof(entry.ids) == "table" then
				local ids = {}
				for _, id in ipairs(entry.ids) do
					if isAssetId(id) then table.insert(ids, id) end
				end
				if #ids > 0 and count < MAX_EMOTES then
					emotes[entry.n] = ids
					count += 1
				end
			end
		end
		pcall(function() description:SetEmotes(emotes) end)
		if typeof(snapshot.equipped) == "table" then
			local equipped = {}
			for _, entry in ipairs(snapshot.equipped) do
				if typeof(entry) == "table" and typeof(entry.n) == "string" and emotes[entry.n]
					and typeof(entry.s) == "number" then
					table.insert(equipped, { Name = entry.n, Slot = entry.s })
				end
			end
			pcall(function() description:SetEquippedEmotes(equipped) end)
		end
	end

	return description
end

-- Every individually restorable item in a snapshot, as typed refs.
-- Used to report which items did not survive a restore.
function OutfitSnapshot.itemRefs(snapshot: any): {{kind: string, id: number, slot: string?}}
	local refs = {}
	if typeof(snapshot) ~= "table" then return refs end
	if typeof(snapshot.assets) == "table" then
		for _, property in ipairs(ASSET_PROPERTIES) do
			local value = snapshot.assets[property]
			if isAssetId(value) then
				table.insert(refs, { kind = "Asset", id = value, slot = property })
			end
		end
	end
	for _, section in ipairs({ "accessories", "makeup" }) do
		local list = snapshot[section]
		if typeof(list) == "table" then
			for _, entry in ipairs(list) do
				if typeof(entry) == "table" and isAssetId(entry.id) then
					table.insert(refs, { kind = "Asset", id = entry.id, slot = section })
				end
			end
		end
	end
	return refs
end

-- Asset ids present in a description, for comparing a restore result.
function OutfitSnapshot.presentAssetIds(description: HumanoidDescription): {[number]: boolean}
	local present = {}
	for _, property in ipairs(ASSET_PROPERTIES) do
		local value = (description :: any)[property]
		if typeof(value) == "number" and value > 0 then present[value] = true end
	end
	for _, child in ipairs(description:GetChildren()) do
		if (child:IsA("AccessoryDescription") or child:IsA("MakeupDescription")) and child.AssetId > 0 then
			present[child.AssetId] = true
		end
	end
	return present
end

return OutfitSnapshot

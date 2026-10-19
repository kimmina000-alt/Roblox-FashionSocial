--!strict

local AppearanceCodec = {}

local SCALE_PROPS = {
	"WidthScale",
	"HeightScale",
	"DepthScale",
	"HeadScale",
	"BodyTypeScale",
	"ProportionScale",
}

local COLOR_PROPS = {
	"HeadColor",
	"TorsoColor",
	"LeftArmColor",
	"RightArmColor",
	"LeftLegColor",
	"RightLegColor",
}

local CLASSIC_PROPS = {
	"GraphicTShirt",
	"Shirt",
	"Pants",
	"Face",
	"Head",
	"Torso",
	"LeftArm",
	"RightArm",
	"LeftLeg",
	"RightLeg",
}

local ANIM_PROPS = {
	"ClimbAnimation",
	"FallAnimation",
	"IdleAnimation",
	"JumpAnimation",
	"RunAnimation",
	"SwimAnimation",
	"WalkAnimation",
	"MoodAnimation",
}

AppearanceCodec.ScaleProps = SCALE_PROPS
AppearanceCodec.ColorProps = COLOR_PROPS

local function colorToTable(color: Color3): {number}
	return { color.R, color.G, color.B }
end

local function tableToColor(value: any): Color3
	if typeof(value) ~= "table" then
		return Color3.new(1, 1, 1)
	end
	return Color3.new(value[1] or 1, value[2] or 1, value[3] or 1)
end

local function vecToTable(value: Vector3): {number}
	return { value.X, value.Y, value.Z }
end

local function tableToVec(value: any, fallback: Vector3): Vector3
	if typeof(value) ~= "table" then
		return fallback
	end
	return Vector3.new(
		value[1] or fallback.X,
		value[2] or fallback.Y,
		value[3] or fallback.Z
	)
end

local function enumName(value: any): string?
	if typeof(value) == "EnumItem" then
		return value.Name
	end
	if typeof(value) == "string" then
		return value
	end
	return nil
end

function AppearanceCodec.Serialize(description: HumanoidDescription): {[string]: any}
	local accessories = {}
	local usedIds: {[number]: boolean} = {}

	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("AccessoryDescription") then
			usedIds[child.AssetId] = true
			table.insert(accessories, {
				AssetId = child.AssetId,
				AccessoryType = enumName(child.AccessoryType),
				IsLayered = child.IsLayered,
				Order = child.Order,
				Position = vecToTable(child.Position),
				Rotation = vecToTable(child.Rotation),
				Scale = vecToTable(child.Scale),
			})
		end
	end

	for _, accessory in ipairs(description:GetAccessories(true)) do
		local assetId = accessory.AssetId
		if typeof(assetId) == "number" and not usedIds[assetId] then
			usedIds[assetId] = true
			table.insert(accessories, {
				AssetId = assetId,
				AccessoryType = enumName(accessory.AccessoryType),
				IsLayered = accessory.IsLayered == true,
				Order = accessory.Order,
				Puffiness = accessory.Puffiness,
			})
		end
	end

	local makeup = {}
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("MakeupDescription") then
			table.insert(makeup, {
				AssetId = child.AssetId,
				MakeupType = enumName(child.MakeupType),
				Order = child.Order,
			})
		end
	end

	local scales = {}
	for _, name in ipairs(SCALE_PROPS) do
		scales[name] = description[name]
	end

	local colors = {}
	for _, name in ipairs(COLOR_PROPS) do
		colors[name] = colorToTable(description[name])
	end

	local classic = {}
	for _, name in ipairs(CLASSIC_PROPS) do
		classic[name] = description[name]
	end

	local animations = {}
	for _, name in ipairs(ANIM_PROPS) do
		animations[name] = description[name]
	end

	local emotes = {}
	for emoteName, ids in pairs(description:GetEmotes()) do
		emotes[emoteName] = ids
	end

	return {
		version = 1,
		scales = scales,
		colors = colors,
		classic = classic,
		animations = animations,
		accessories = accessories,
		makeup = makeup,
		emotes = emotes,
		equippedEmotes = description:GetEquippedEmotes(),
	}
end

function AppearanceCodec.Deserialize(data: any): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	if typeof(data) ~= "table" then
		return description
	end

	local scales = data.scales
	if typeof(scales) == "table" then
		for _, name in ipairs(SCALE_PROPS) do
			if typeof(scales[name]) == "number" then
				description[name] = scales[name]
			end
		end
	end

	local colors = data.colors
	if typeof(colors) == "table" then
		for _, name in ipairs(COLOR_PROPS) do
			description[name] = tableToColor(colors[name])
		end
	end

	local classic = data.classic
	if typeof(classic) == "table" then
		for _, name in ipairs(CLASSIC_PROPS) do
			if typeof(classic[name]) == "number" then
				description[name] = classic[name]
			end
		end
	end

	local animations = data.animations
	if typeof(animations) == "table" then
		for _, name in ipairs(ANIM_PROPS) do
			if typeof(animations[name]) == "number" then
				description[name] = animations[name]
			end
		end
	end

	if typeof(data.accessories) == "table" then
		for _, entry in ipairs(data.accessories) do
			if typeof(entry) == "table" and typeof(entry.AssetId) == "number" then
				local accessory = Instance.new("AccessoryDescription")
				accessory.AssetId = entry.AssetId
				local typeName = entry.AccessoryType
				if typeof(typeName) == "string" and Enum.AccessoryType[typeName] then
					accessory.AccessoryType = Enum.AccessoryType[typeName]
				end
				if entry.IsLayered == true and typeof(entry.Order) == "number" then
					accessory.Order = entry.Order
				end
				if typeof(entry.Position) == "table" then
					accessory.Position = tableToVec(entry.Position, Vector3.zero)
				end
				if typeof(entry.Rotation) == "table" then
					accessory.Rotation = tableToVec(entry.Rotation, Vector3.zero)
				end
				if typeof(entry.Scale) == "table" then
					accessory.Scale = tableToVec(entry.Scale, Vector3.one)
				end
				accessory.Parent = description
			end
		end
	end

	if typeof(data.makeup) == "table" then
		for _, entry in ipairs(data.makeup) do
			if typeof(entry) == "table" and typeof(entry.AssetId) == "number" then
				local makeup = Instance.new("MakeupDescription")
				makeup.AssetId = entry.AssetId
				local typeName = entry.MakeupType
				if typeof(typeName) == "string" and Enum.MakeupType[typeName] then
					makeup.MakeupType = Enum.MakeupType[typeName]
				end
				if typeof(entry.Order) == "number" then
					makeup.Order = entry.Order
				end
				makeup.Parent = description
			end
		end
	end

	if typeof(data.emotes) == "table" then
		description:SetEmotes(data.emotes)
	end
	if typeof(data.equippedEmotes) == "table" then
		description:SetEquippedEmotes(data.equippedEmotes)
	end

	return description
end

function AppearanceCodec.CollectWornIds(data: any): {number}
	local ids = {}
	local seen: {[number]: boolean} = {}
	local function add(id: any)
		if typeof(id) == "number" and id > 0 and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	if typeof(data) ~= "table" then
		return ids
	end
	if typeof(data.accessories) == "table" then
		for _, entry in ipairs(data.accessories) do
			if typeof(entry) == "table" then
				add(entry.AssetId)
			end
		end
	end
	if typeof(data.makeup) == "table" then
		for _, entry in ipairs(data.makeup) do
			if typeof(entry) == "table" then
				add(entry.AssetId)
			end
		end
	end
	if typeof(data.classic) == "table" then
		for _, name in ipairs(CLASSIC_PROPS) do
			add(data.classic[name])
		end
	end
	if typeof(data.animations) == "table" then
		for _, name in ipairs(ANIM_PROPS) do
			add(data.animations[name])
		end
	end
	if typeof(data.emotes) == "table" then
		for _, idsList in pairs(data.emotes) do
			if typeof(idsList) == "table" then
				for _, id in ipairs(idsList) do
					add(id)
				end
			end
		end
	end
	return ids
end

return AppearanceCodec

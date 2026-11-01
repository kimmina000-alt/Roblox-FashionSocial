-- Builds the thumbnail models (D-740) from tools/thumbnail/avatars.lua: run in
-- Studio Edit mode with `AVATARS` set to that file's table (the sync server:
-- loadstring it first). Each list becomes an R15 rig in
-- Workspace.ThumbnailAvatars, standing in a row at `ORIGIN`, anchored.
-- A body bundle's outfit (colours, scales, body parts) is the base; every
-- other asset goes on by its type: body parts / heads, the face, classic
-- shirt / pants / t-shirt, accessories (layered clothing as layered).
-- Emotes and animation packs are left out (a still picture).

local AVATARS = _G.AVATARS
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local AssetService = game:GetService("AssetService")

local ORIGIN = CFrame.new(-30, 3.2, -46) -- (the spawn square; moved out of the way after the shots)
local GAP = 5

local ACCESSORY = {
	[8] = Enum.AccessoryType.Hat, [41] = Enum.AccessoryType.Hair, [42] = Enum.AccessoryType.Face,
	[43] = Enum.AccessoryType.Neck, [44] = Enum.AccessoryType.Shoulder, [45] = Enum.AccessoryType.Front,
	[46] = Enum.AccessoryType.Back, [47] = Enum.AccessoryType.Waist,
	[64] = Enum.AccessoryType.TShirt, [65] = Enum.AccessoryType.Shirt, [66] = Enum.AccessoryType.Pants,
	[67] = Enum.AccessoryType.Jacket, [68] = Enum.AccessoryType.Sweater, [69] = Enum.AccessoryType.Shorts,
	[70] = Enum.AccessoryType.LeftShoe, [71] = Enum.AccessoryType.RightShoe, [72] = Enum.AccessoryType.DressSkirt,
	[76] = Enum.AccessoryType.Eyebrow, [77] = Enum.AccessoryType.Eyelash,
}
local LAYERED = { [64] = true, [65] = true, [66] = true, [67] = true, [68] = true, [69] = true, [70] = true, [71] = true, [72] = true, [76] = true, [77] = true }
-- the order layered clothes go on, inside → outside
local LAYER_ORDER = { [64] = 1, [65] = 2, [72] = 3, [66] = 3, [69] = 3, [68] = 4, [67] = 5, [70] = 6, [71] = 6, [76] = 1, [77] = 1 }
local BODY = { [17] = "Head", [79] = "Head", [27] = "Torso", [28] = "RightArm", [29] = "LeftArm", [30] = "LeftLeg", [31] = "RightLeg" }

local function typeOf(id: number): number?
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset) end)
	return if ok and info then info.AssetTypeId else nil
end

local report = {}
local folder = workspace:FindFirstChild("ThumbnailAvatars") or Instance.new("Folder")
folder.Name = "ThumbnailAvatars"
folder.Parent = workspace

for index, avatar in ipairs(AVATARS) do
	local old = folder:FindFirstChild(avatar.name)
	if old then old:Destroy() end
	-- assets: bundles opened up; the first body bundle's outfit is the base
	local assets: {number} = {}
	local base: HumanoidDescription? = nil
	for _, item in ipairs(avatar.items) do
		if typeof(item) == "table" then
			local ok, details = pcall(function() return AssetService:GetBundleDetailsAsync(item.b) end)
			if ok and details then
				for _, part in ipairs(details.Items) do
					if part.Type == "UserOutfit" then
						if not base and details.BundleType == "BodyParts" then
							local okOutfit, desc = pcall(function() return Players:GetHumanoidDescriptionFromOutfitId(part.Id) end)
							if okOutfit then base = desc end
						end
					elseif part.Type == "Asset" then
						table.insert(assets, part.Id)
					end
				end
			else
				table.insert(report, avatar.name .. ": bundle " .. item.b .. " failed")
			end
		else
			table.insert(assets, item)
		end
	end
	local desc = base or Instance.new("HumanoidDescription")
	if not base then
		for _, part in ipairs({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }) do
			(desc :: any)[part .. "Color"] = Color3.fromRGB(255, 220, 196)
		end
	end
	local accessories = {}
	local skipped = 0
	for _, id in ipairs(assets) do
		local t = typeOf(id)
		if t and BODY[t] then
			(desc :: any)[BODY[t]] = id
		elseif t == 18 then desc.Face = id
		elseif t == 11 then desc.Shirt = id
		elseif t == 12 then desc.Pants = id
		elseif t == 2 then desc.GraphicTShirt = id
		elseif t and ACCESSORY[t] then
			table.insert(accessories, { AssetId = id, AccessoryType = ACCESSORY[t], IsLayered = LAYERED[t] == true, Order = if LAYERED[t] then LAYER_ORDER[t] else nil })
		else
			skipped += 1
		end
	end
	-- keep the base outfit's own accessories too
	for _, a in ipairs(desc:GetAccessories(true)) do table.insert(accessories, a) end
	desc:SetAccessories(accessories, true)
	local ok, rig = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
	if ok and rig then
		rig.Name = avatar.name
		-- (by its number, so a few at a time still stand in their own place)
		local number = tonumber(string.match(avatar.name, "^A(%d+)")) or index
		rig:PivotTo(ORIGIN * CFrame.new((number - 6) * GAP, 0, 0))
		local root = rig:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then root.Anchored = true end
		rig.Parent = folder
		table.insert(report, string.format("%s: %d items, %d skipped", avatar.name, #accessories, skipped))
	else
		table.insert(report, avatar.name .. ": rig failed " .. tostring(rig))
	end
end
return table.concat(report, "\n")

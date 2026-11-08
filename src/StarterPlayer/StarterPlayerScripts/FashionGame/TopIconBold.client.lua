--!strict
-- (D-1069, user 2026-11-09: "오른쪽 상단에 카탈로그, 가방, 음표 버튼 흐림. 의견 받는
-- 버튼처럼 더 하얗게.") the catalog / bag / music icons are thin-line pictures and
-- look grey beside the 💬 button (drawn with 2 px white strokes): each gets the
-- same picture once more 1 px to each side, so its lines read as bold white.
-- The copies follow the icon (picture, colour, size) if a button changes it.

local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local BUTTONS = {
	{ "FashionCatalogGui", "CatalogButton" },
	{ "FashionInventoryGui", "BagButton" },
	{ "FashionDanceGui", "DanceButton" },
}
local OFFSETS = { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) }

local function bolden(icon: ImageLabel)
	if icon:GetAttribute("Bold") then return end
	icon:SetAttribute("Bold", true)
	local copies = {}
	for i, o in ipairs(OFFSETS) do
		local c = Instance.new("ImageLabel")
		c.Name = "IconBold" .. i
		c.BackgroundTransparency = 1
		c.Parent = icon.Parent
		copies[i] = { c, o }
	end
	local function sync()
		for _, e in ipairs(copies) do
			local c, o = e[1] :: ImageLabel, e[2] :: Vector2
			c.Image = icon.Image
			c.ImageColor3 = icon.ImageColor3
			c.ImageTransparency = icon.ImageTransparency
			c.ImageRectOffset = icon.ImageRectOffset
			c.ImageRectSize = icon.ImageRectSize
			c.ScaleType = icon.ScaleType
			c.AnchorPoint = icon.AnchorPoint
			c.Size = icon.Size
			c.Position = icon.Position + UDim2.fromOffset(o.X, o.Y)
			c.ZIndex = icon.ZIndex
			c.Visible = icon.Visible
		end
	end
	sync()
	for _, prop in ipairs({ "Image", "ImageColor3", "ImageTransparency", "Size", "Position", "Visible", "ZIndex" }) do
		icon:GetPropertyChangedSignal(prop):Connect(sync)
	end
end

for _, spec in ipairs(BUTTONS) do
	task.spawn(function()
		local gui = playerGui:WaitForChild(spec[1], 60)
		local button = gui and gui:WaitForChild(spec[2], 60)
		local icon = button and button:WaitForChild("Icon", 60)
		if icon and icon:IsA("ImageLabel") then bolden(icon) end
	end)
end

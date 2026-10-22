--!strict

local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local TryOnItem = Remotes:WaitForChild("TryOnItem")
local PlayerData = Remotes:WaitForChild("PlayerData")
local ReorderDrag = require(script.Parent:WaitForChild("ReorderDrag"))
local AvatarEditor = require(script.Parent:WaitForChild("AvatarEditor"))

local Config = require(
	FashionGame:WaitForChild("Shared"):WaitForChild("CatalogConfig")
)

local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- STATE
--------------------------------------------------

local currentCategory = "전체"
local currentCategoryAssetTypes = Config.AllowedAssetTypes
local currentCategoryBundleTypes = nil
local currentCategoryIncludeOffSale = Config.IncludeOffSale
local currentKeyword = ""

local currentSort = Enum.CatalogSortType.Relevance
local currentMinPrice = 0
local currentMaxPrice = 0
local currentIncludeOffSale = Config.IncludeOffSale

local currentWornItems: {[number]: boolean} = {}
local wornOrder: {number} = {}
local activeTopLevelGroup: string? = nil
local filterPanelOpen = false
local renderSubcategoryStrip: (string?) -> ()
local selectCategory
local createItemCard: (any, number) -> ()
local statusLabel: TextLabel
local updateCatalogLayout: () -> ()


-- Live card button refreshers keyed by asset ID.
local wornButtonUpdaters: {[number]: () -> ()} = {}

local searchBusy = false
local actionBusy = false
local bundleContentsOpen = false
local showBundleContents
local renderCurrentPage: () -> ()
-- Forward declarations: these are called from handlers defined above their bodies
-- (ISSUE-CATALOG-006). Assigned later with `name = function() ... end`.
local refreshWornItems: () -> ()
local searchCatalog: () -> ()
local renderCurrentOutfit: () -> ()
local recordRecent: (any, string) -> ()
local toggleFavorite: (number, string, any) -> ()

local friendlyError = require(script.Parent:WaitForChild("FriendlyErrors"))

local catalogPages: Pages? = nil
local currentPageNumber = 1

-- Browse modes (CATALOG_QUICK_NAVIGATION_IMPLEMENTATION_PLAN): "Catalog" search, "Popular"
-- (official MostFavorited sort), or a local list: "Recent" (session only, D-020/D-023),
-- "Favorites" (in-game, persisted), "Wearing" (actual worn snapshot). Local lists never
-- page in global catalog results.
local browseMode = "Catalog"
local recentItems: {any} = {}
local MAX_RECENT = 100
local favoriteItems: {any} = {}
local favoriteSet: {[string]: boolean} = {}
local favoritesNote: string? = nil
local itemDetailsCache: {[string]: any} = {}
local avatarEditor: any = nil
local wardrobeView: any = nil
local openAvatarEditor: () -> ()
local renderLocalMode: () -> ()
local showToast: (string) -> ()
local previewOverride: HumanoidDescription? = nil
local resultsMessage: TextLabel
local previewGeneration = 0

local expandedPanel = false
local cardContentScale = 1
local cardContentUIScales: {UIScale} = {}

--------------------------------------------------
-- ★ TYPES CURRENTLY SUPPORTED BY OUR TRY-ON SERVICE
--------------------------------------------------

local TRY_ON_SUPPORTED_ASSET_TYPES: {[string]: boolean} = {
	TShirt = true,
	Shirt = true,
	Pants = true,

	Hat = true,
	HairAccessory = true,
	FaceAccessory = true,
	NeckAccessory = true,
	ShoulderAccessory = true,
	FrontAccessory = true,
	BackAccessory = true,
	WaistAccessory = true,

	TShirtAccessory = true,
	ShirtAccessory = true,
	PantsAccessory = true,
	JacketAccessory = true,
	SweaterAccessory = true,
	ShortsAccessory = true,
	LeftShoeAccessory = true,
	RightShoeAccessory = true,
	DressSkirtAccessory = true,
	EyebrowAccessory = true,
	EyelashAccessory = true,
	ClimbAnimation = true,
	FallAnimation = true,
	IdleAnimation = true,
	JumpAnimation = true,
	RunAnimation = true,
	SwimAnimation = true,
	WalkAnimation = true,
	MoodAnimation = true,
	EmoteAnimation = true,
	FaceMakeup = true,
	LipMakeup = true,
	EyeMakeup = true,
	-- Body parts / head / classic face (usually reached through a bundle's contents)
	Torso = true,
	LeftArm = true,
	RightArm = true,
	LeftLeg = true,
	RightLeg = true,
	Head = true,
	DynamicHead = true,
	Face = true,
}

--------------------------------------------------
-- UTILITY
--------------------------------------------------

local function create(
	className: string,
	properties: {[string]: any}?
)
	local object = Instance.new(className)

	if properties then
		for property, value in pairs(properties) do
			object[property] = value
		end
	end

	return object
end

local function clearContainer(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIGridLayout")
			and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function formatPrice(price: any): string
	if typeof(price) ~= "number" then
		return "Off Sale"
	end

	if price <= 0 then
		return "Free"
	end

	return tostring(price) .. " R$"
end

local function getAssetTypeName(item: any): string
	local assetType = item.AssetType

	if typeof(assetType) == "string" then
		return assetType
	end

	if typeof(assetType) == "EnumItem" then
		return assetType.Name
	end

	return "Unknown"
end

--------------------------------------------------
-- SCREEN GUI
--------------------------------------------------

local screenGui = create("ScreenGui", {
	Name = "FashionCatalogGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

screenGui.Parent = playerGui

--------------------------------------------------
-- OPEN BUTTON
--------------------------------------------------

local openButton = create("TextButton", {
	Name = "CatalogButton",
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(44, 44),
	Position = UDim2.new(1, -16, 0, 34),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.2,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Text = "C",
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = true,
})
openButton.Parent = screenGui

create("UICorner", {
	CornerRadius = UDim.new(1, 0),
}).Parent = openButton

-- Anchor the catalog button to the RIGHT end of the Roblox top bar area.
-- Left-side top bar items (menu, chat, voice chat mic) grow to the right and
-- previously covered a left-anchored button.
local function positionOpenButton()
	local inset = GuiService.TopbarInset
	local centerY = 34
	local rightX = -16
	local size = 44
	if inset.Height > 0 then
		centerY = inset.Min.Y + inset.Height / 2
		size = math.clamp(inset.Height - 12, 32, 44)
		local camera = workspace.CurrentCamera
		if camera and inset.Width > 0 then
			rightX = -(camera.ViewportSize.X - inset.Max.X) - 8
		end
	end
	openButton.Size = UDim2.fromOffset(size, size)
	openButton.Position = UDim2.new(1, rightX, 0, centerY)
end
positionOpenButton()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(positionOpenButton)

--------------------------------------------------
-- CURRENT AVATAR PREVIEW WINDOW
--------------------------------------------------

local previewGui = create("ScreenGui", {
	Name = "FashionAvatarPreviewGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 21,
})
previewGui.Parent = playerGui

local previewManuallyClosed = false

local previewFrame = create("Frame", {
	Name = "AvatarPreviewWindow",
	Size = UDim2.fromOffset(250, 300),
	Position = UDim2.fromOffset(16, 164),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.6,
	Visible = false,
})
previewFrame.Parent = previewGui
previewFrame.BackgroundTransparency = 1
create("UICorner", { CornerRadius = UDim.new(0, 15) }).Parent = previewFrame

local previewTitle = create("TextLabel", {
	Name = "PreviewTitle",
	Size = UDim2.new(1, -44, 0, 32),
	Position = UDim2.fromOffset(10, 4),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
})
previewTitle.Parent = previewFrame

-- The preview is a persistent panel; only the catalog's main close button closes the UI.
local avatarEditorButton = create("TextButton", {
	Name = "AvatarEditorButton",
	Size = UDim2.fromOffset(34, 34),
	Position = UDim2.fromOffset(8, 8),
	BackgroundTransparency = 1,
	BackgroundColor3 = Color3.fromRGB(55, 55, 65),
	Text = "⚙",
	TextColor3 = Color3.fromRGB(245, 245, 250),
	TextSize = 21,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = true,
	ZIndex = 5,
})
avatarEditorButton.Parent = previewFrame
avatarEditorButton.BackgroundTransparency = 0.45
create("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = avatarEditorButton

local wardrobeButton = create("TextButton", {
	Name = "WardrobeButton",
	Size = UDim2.fromOffset(34, 34),
	Position = UDim2.fromOffset(8, 48),
	BackgroundTransparency = 1,
	BackgroundColor3 = Color3.fromRGB(55, 55, 65),
	Text = "▣",
	TextColor3 = Color3.fromRGB(245, 245, 250),
	TextSize = 21,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = true,
	ZIndex = 5,
})
wardrobeButton.Parent = previewFrame
wardrobeButton.BackgroundTransparency = 0.45
create("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = wardrobeButton

local avatarViewport = create("ViewportFrame", {
	Name = "AvatarViewport",
	Size = UDim2.new(1, -12, 1, -46),
	Position = UDim2.fromOffset(6, 38),
	BackgroundColor3 = Color3.fromRGB(35, 35, 43),
	BorderSizePixel = 0,
	Ambient = Color3.fromRGB(200, 200, 200),
	LightColor = Color3.fromRGB(255, 255, 255),
	LightDirection = Vector3.new(-1, -1, -1),
})
avatarViewport.Parent = previewFrame
create("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = avatarViewport

local currentOutfitFrame = create("Frame", {
	Name = "CurrentOutfitFrame",
	BackgroundTransparency = 1,
	Visible = false,
})
currentOutfitFrame.Parent = previewFrame
local currentOutfitTitle = create("TextLabel", {
	Name = "CurrentOutfitTitle",
	Size = UDim2.new(1, 0, 0, 24),
	Position = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	Text = "착용 중인 아이템",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
})
currentOutfitTitle.Parent = currentOutfitFrame
local currentOutfitList = create("ScrollingFrame", {
	Name = "CurrentOutfitItems",
	Size = UDim2.new(1, 0, 1, -26),
	Position = UDim2.fromOffset(0, 26),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
})
currentOutfitList.Parent = currentOutfitFrame
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}).Parent = currentOutfitList


local avatarPreviewWorld = Instance.new("WorldModel")
avatarPreviewWorld.Parent = avatarViewport

local avatarPreviewCamera = Instance.new("Camera")
avatarPreviewCamera.FieldOfView = 35
avatarPreviewCamera.Parent = avatarViewport
avatarViewport.CurrentCamera = avatarPreviewCamera

-- Preview orbit state survives refreshes so wearing an item keeps the angle.
local PREVIEW_MIN_ZOOM = 0.45
local PREVIEW_MAX_ZOOM = 1.6
local previewYaw = 0
local previewPitch = 0
local previewZoom = 1
local previewTarget = Vector3.zero
local previewBaseDistance = 8

local function updatePreviewCamera()
	-- Characters face local -Z; yaw 0 looks at the front of the avatar.
	local rotation = CFrame.Angles(0, previewYaw, 0) * CFrame.Angles(previewPitch, 0, 0)
	local offset = rotation:VectorToWorldSpace(Vector3.new(0, 0, -previewBaseDistance * previewZoom))
	avatarPreviewCamera.CFrame = CFrame.lookAt(previewTarget + offset, previewTarget)
end

local function refreshAvatarPreview()
	previewGeneration += 1
	local generation = previewGeneration
	for _, child in ipairs(avatarPreviewWorld:GetChildren()) do
		child:Destroy()
	end

	local character = player.Character
	if not character then
		return
	end

	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end

	clone.Name = "AvatarPreviewCharacter"
	clone.Parent = avatarPreviewWorld
	clone:PivotTo(CFrame.new(0, 0, 0))
	-- Avatar Editor draft: applied to this client-only clone, never to the live character.
	local override = previewOverride
	if override then
		local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
		if cloneHumanoid then
			local ok, err = pcall(function()
				-- ApplyDescriptionAsync skips accessories whose AssetId did not change,
				-- so editor-only changes (Position/Rotation/Scale) never showed until
				-- Apply. The Reset variant rebuilds them from the draft (verified in Studio).
				cloneHumanoid:ApplyDescriptionResetAsync(override:Clone())
			end)
			if not ok then warn("[CatalogUI] Preview draft apply failed:", err) end
		end
		if generation ~= previewGeneration then
			clone:Destroy()
			return
		end
		clone:PivotTo(CFrame.new(0, 0, 0))
	end
	local boundsCFrame, bounds = clone:GetBoundingBox()
	local viewportSize = avatarViewport.AbsoluteSize
	local aspect = if viewportSize.Y > 0 then viewportSize.X / viewportSize.Y else 1
	local halfFov = math.rad(avatarPreviewCamera.FieldOfView * 0.5)
	local verticalDistance = (bounds.Y * 0.5) / math.tan(halfFov)
	local horizontalDistance = (bounds.X * 0.5) / (math.tan(halfFov) * math.max(aspect, 0.1))
	previewTarget = boundsCFrame.Position
	previewBaseDistance = math.max(verticalDistance, horizontalDistance, bounds.Z * 0.5 + 0.5) * 1.12
	updatePreviewCamera()
	-- Avatar Editor draws the X/Y/Z guide around the selected accessory.
	if avatarEditor then avatarEditor:onPreviewBuilt(clone) end
end

-- Drag inside the avatar preview to orbit the avatar; mouse wheel zooms.
-- Input is only captured when it starts inside the preview viewport.
local previewDragInput: InputObject? = nil
local previewDragLast: Vector3? = nil
avatarViewport.Active = true
avatarViewport.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		previewDragInput = input
		previewDragLast = input.Position
	end
end)
avatarViewport.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		previewZoom = math.clamp(previewZoom * (if input.Position.Z > 0 then 0.9 else 1.1), PREVIEW_MIN_ZOOM, PREVIEW_MAX_ZOOM)
		updatePreviewCamera()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not previewDragInput or not previewDragLast then return end
	local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
		and previewDragInput.UserInputType == Enum.UserInputType.MouseButton1
	if not isMouseMove and input ~= previewDragInput then return end
	local delta = input.Position - previewDragLast
	previewDragLast = input.Position
	previewYaw -= delta.X * 0.012
	previewPitch = math.clamp(previewPitch + delta.Y * 0.008, -0.6, 0.6)
	updatePreviewCamera()
end)
UserInputService.InputEnded:Connect(function(input)
	if previewDragInput and (input == previewDragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
		previewDragInput = nil
		previewDragLast = nil
	end
end)

-- Reframe the preview after responsive layout changes alter its viewport shape.
avatarViewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if previewFrame.Visible then task.defer(refreshAvatarPreview) end
end)

-- These entry points are intentionally placed now; their feature panels are planned.
avatarEditorButton.MouseButton1Click:Connect(function()
	openAvatarEditor()
end)


-- Respawn gives a fresh character (default look): rebuild the worn list, the
-- 착용 중 grid and the preview from the server (QA 2026-10-20: the strip kept
-- the pre-respawn items).
player.CharacterAdded:Connect(function(character)
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	task.wait(0.3)
	if player.Character ~= character then return end
	refreshWornItems()
	if previewFrame.Visible then
		refreshAvatarPreview()
	end
end)

--------------------------------------------------
-- MAIN FRAME
--------------------------------------------------

local mainFrame = create("Frame", {
	Name = "MainFrame",
	-- Recomputed from the current viewport by updateCatalogLayout().
	Size = UDim2.new(0, 520, 0, 680),
	Position = UDim2.new(1, -536, 0, 8),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.6,
	Visible = false,
})

mainFrame.Parent = screenGui
mainFrame.BackgroundTransparency = 1

-- Rounded catalog box (80% opaque). In expanded mode it sits beside the
-- avatar preview box with the same gap as the outer screen margin.
local catalogPanel = create("Frame", {
	Name = "CatalogPanel",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ZIndex = 0,
})
catalogPanel.Parent = mainFrame
create("UICorner", { CornerRadius = UDim.new(0, 15) }).Parent = catalogPanel

create("UICorner", {
	CornerRadius = UDim.new(0, 14),
}).Parent = mainFrame

previewFrame.Parent = mainFrame
previewGui.Enabled = false

--------------------------------------------------
-- TITLE
--------------------------------------------------

local titleLabel = create("TextLabel", {
	Name = "Title",
	Size = UDim2.new(1, -120, 0, 48),
	Position = UDim2.fromOffset(20, 10),
	BackgroundTransparency = 1,
	Text = "CATALOG",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
})
titleLabel.Parent = mainFrame

--------------------------------------------------
-- CLOSE
--------------------------------------------------

local closeButton = create("TextButton", {
	Name = "CloseButton",
	Size = UDim2.fromOffset(40, 40),
	Position = UDim2.new(1, -52, 0, 12),
	BackgroundColor3 = Color3.fromRGB(55, 55, 65),
	Text = "×",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 26,
	Font = Enum.Font.GothamBold,
})
closeButton.Parent = mainFrame

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = closeButton

local expandButton = create("TextButton", {
	Name = "ExpandButton",
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.new(1, -96, 0, 14),
	BackgroundColor3 = Color3.fromRGB(55, 55, 65),
	Text = "↗",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = true,
})
expandButton.Parent = mainFrame
create("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = expandButton

--------------------------------------------------
-- SEARCH BOX
--------------------------------------------------

local searchBox = create("TextBox", {
	Name = "SearchBox",
	Size = UDim2.new(1, -180, 0, 40),
	Position = UDim2.fromOffset(20, 66),
	BackgroundColor3 = Color3.fromRGB(40, 40, 48),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
	PlaceholderText = "Search Roblox catalog...",
	Text = "",
	TextSize = 15,
	Font = Enum.Font.Gotham,
	ClearTextOnFocus = false,
})
searchBox.Parent = mainFrame

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = searchBox

--------------------------------------------------
-- SEARCH BUTTON
--------------------------------------------------

local searchButton = create("TextButton", {
	Name = "SearchButton",
	Size = UDim2.fromOffset(120, 40),
	Position = UDim2.new(1, -140, 0, 66),
	BackgroundColor3 = Color3.fromRGB(70, 70, 85),
	Text = "SEARCH",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
})
searchButton.Parent = mainFrame

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = searchButton

--------------------------------------------------
-- ★ FILTER BAR
--------------------------------------------------

local filterLabel = create("TextLabel", {
	Name = "FilterLabel",
	Size = UDim2.fromOffset(70, 34),
	Position = UDim2.fromOffset(20, 116),
	BackgroundTransparency = 1,
	Text = "FILTER",
	TextColor3 = Color3.fromRGB(170, 170, 180),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
})
filterLabel.Parent = mainFrame

--------------------------------------------------
-- ★ CATEGORY SELECTOR
--------------------------------------------------


--------------------------------------------------
-- ★ SORT SELECTOR
--------------------------------------------------

local sortButton = create("TextButton", {
	Name = "SortButton",
	Size = UDim2.fromOffset(220, 34),
	Position = UDim2.fromOffset(320, 116),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	Text = "Sort: Relevance ▼",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
})
sortButton.Parent = mainFrame

create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
}).Parent = sortButton

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = sortButton

local sortMenu = create("Frame", {
	Name = "SortMenu",
	Size = UDim2.fromOffset(220, 220),
	Position = UDim2.fromOffset(320, 152),
	BackgroundColor3 = Color3.fromRGB(34, 34, 42),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 50,
})
sortMenu.Parent = mainFrame

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = sortMenu

create("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}).Parent = sortMenu

create("UIPadding", {
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 4),
}).Parent = sortMenu

--------------------------------------------------
-- ★ PRICE FILTER
--------------------------------------------------

local minPriceBox = create("TextBox", {
	Name = "MinPrice",
	Size = UDim2.fromOffset(90, 34),
	Position = UDim2.fromOffset(560, 116),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
	PlaceholderText = "Min",
	Text = "",
	TextSize = 12,
	Font = Enum.Font.Gotham,
})
minPriceBox.Parent = mainFrame

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = minPriceBox

local maxPriceBox = create("TextBox", {
	Name = "MaxPrice",
	Size = UDim2.fromOffset(90, 34),
	Position = UDim2.fromOffset(660, 116),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
	PlaceholderText = "Max",
	Text = "",
	TextSize = 12,
	Font = Enum.Font.Gotham,
})
maxPriceBox.Parent = mainFrame

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = maxPriceBox

local offSaleButton = create("TextButton", {
	Name = "OffSaleButton",
	Size = UDim2.fromOffset(110, 34),
	Position = UDim2.fromOffset(760, 116),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	Text = "□ Off Sale",
	TextColor3 = Color3.fromRGB(220, 220, 225),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
})
offSaleButton.Parent = mainFrame

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = offSaleButton

--------------------------------------------------
-- STATUS
--------------------------------------------------

local backToPacksButton = create("TextButton", {
	Name = "BackToPacksButton",
	Size = UDim2.fromOffset(145, 28),
	Position = UDim2.fromOffset(20, 160),
	BackgroundColor3 = Color3.fromRGB(55, 55, 65),
	Text = "← BACK TO PACKS",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	Visible = false,
})
backToPacksButton.Parent = mainFrame
create("UICorner", { CornerRadius = UDim.new(0, 7) }).Parent = backToPacksButton

statusLabel = create("TextLabel", {
	Name = "Status",
	Size = UDim2.new(1, -190, 0, 30),
	Position = UDim2.fromOffset(175, 160),
	BackgroundTransparency = 1,
	Text = "Ready",
	TextColor3 = Color3.fromRGB(170, 170, 180),
	TextSize = 13,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
})
statusLabel.Parent = mainFrame

--------------------------------------------------
-- RESULTS
--------------------------------------------------

local resultsFrame = create("ScrollingFrame", {

	Name = "Results",
	Size = UDim2.new(1, -40, 1, -250),
	Position = UDim2.fromOffset(20, 195),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 6,
})
resultsFrame.Parent = mainFrame

local itemNameTooltip = create("TextLabel", {
	Name = "ItemNameTooltip",
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.fromOffset(20, 24),
	Position = UDim2.fromOffset(0, 0),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.2,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextWrapped = false,
	Visible = false,
	ZIndex = 200,
})
itemNameTooltip.Parent = screenGui
create("UIPadding", {
	PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
	PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
}).Parent = itemNameTooltip
create("UICorner", {CornerRadius = UDim.new(0, 5)}).Parent = itemNameTooltip

-- Expanded-layout navigation overlays. Search and Filter stay fixed while the
-- discovery shortcuts can be horizontally scrolled independently.
local discoveryBar = create("ScrollingFrame", {
	Name = "DiscoveryBar",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	Visible = false,
})
discoveryBar.Parent = mainFrame
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}).Parent = discoveryBar

local discoveryButtons = {}
-- Minimized strip order (D-022): 최근 / 인기 / 즐겨찾기 / 착용 중 / ⚙ / 옷장.
-- In expanded mode ⚙ and 옷장 live at the top of the avatar preview box instead.
local COMPACT_ONLY_DISCOVERY = {["⚙"] = true, ["옷장"] = true}
for index, label in ipairs({"최근", "인기", "즐겨찾기", "착용 중", "⚙", "옷장"}) do
	local b = create("TextButton", {
		Name = "Discovery_" .. tostring(index),
		Size = UDim2.fromOffset(86, 30),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.6,
		Text = label,
		TextColor3 = Color3.fromRGB(235, 235, 240),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		LayoutOrder = index,
	})
	b.Parent = discoveryBar
	create("UICorner", {CornerRadius = UDim.new(0, 7)}).Parent = b
	discoveryButtons[label] = b
end

local discoveryDragStartX: number? = nil
local discoveryDragCanvasX = 0
discoveryBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		discoveryDragStartX = input.Position.X
		discoveryDragCanvasX = discoveryBar.CanvasPosition.X
	end
end)
discoveryBar.InputChanged:Connect(function(input)
	if discoveryDragStartX and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = discoveryDragStartX - input.Position.X
		discoveryBar.CanvasPosition = Vector2.new(
			math.clamp(discoveryDragCanvasX + delta, 0, math.max(0, discoveryBar.AbsoluteCanvasSize.X - discoveryBar.AbsoluteWindowSize.X)),
			0
		)
	end
end)
discoveryBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		discoveryDragStartX = nil
	end
end)

local fixedFilterButton = create("TextButton", {
	Name = "FixedFilterButton",
	Size = UDim2.fromOffset(70, 30),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.6,
	Text = "필터 ☰",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	Visible = false,
})
fixedFilterButton.Parent = mainFrame
create("UICorner", {CornerRadius = UDim.new(0, 7)}).Parent = fixedFilterButton

local mainCategoryStrip = create("ScrollingFrame", {
	Name = "MainCategoryStrip",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	Visible = false,
})
mainCategoryStrip.Parent = mainFrame
local subcategoryStrip = create("ScrollingFrame", {Name="SubcategoryStrip",BackgroundColor3=Color3.fromRGB(36,36,44),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.X,Visible=false})
subcategoryStrip.Parent=mainFrame
create("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder}).Parent=subcategoryStrip
local function createArrowButton(name: string, text: string): TextButton
	local button = create("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(46, 60, 70),
		BackgroundTransparency = 0,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 20,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = true,
		Visible = false,
		ZIndex = 3,
	})
	button.Parent = mainFrame
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }).Parent = button
	return button
end
local subcategoryLeftButton = createArrowButton("SubcategoryLeftArrow", "‹")
local subcategoryRightButton = createArrowButton("SubcategoryRightArrow", "›")
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}).Parent = mainCategoryStrip

local categoryLeftButton = createArrowButton("CategoryLeftArrow", "‹")
local categoryRightButton = createArrowButton("CategoryRightArrow", "›")

local filterPanel = create("Frame", {
	Name = "ExpandedFilterPanel",
	Size = UDim2.fromOffset(300, 166),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 70,
})
filterPanel.Parent = mainFrame
create("UICorner", {CornerRadius = UDim.new(0, 8)}).Parent = filterPanel

local FILTER_PAD = 8
local FILTER_GAP = 6
local FILTER_ROW = 26
local function filterText(className: string, props: {[string]: any})
	props.ZIndex = 71
	props.Font = props.Font or Enum.Font.GothamBold
	local object = create(className, props)
	object.Parent = filterPanel
	if className ~= "TextLabel" then
		create("UICorner", {CornerRadius = UDim.new(0, 6)}).Parent = object
	end
	return object
end
local creatorLabel = filterText("TextLabel", {
	BackgroundTransparency = 1, Text = "Creator: All creators",
	TextColor3 = Color3.fromRGB(220, 220, 228), TextSize = 10, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local creatorNameBox = filterText("TextBox", {
	BackgroundColor3 = Color3.fromRGB(45, 45, 54), Text = "", PlaceholderText = "Creator name",
	TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(165, 165, 172),
	TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false,
})
local priceFilterLabel = filterText("TextLabel", {
	BackgroundTransparency = 1, Text = "Price range (R$)",
	TextColor3 = Color3.fromRGB(220, 220, 228), TextSize = 10, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local priceTildeLabel = filterText("TextLabel", {
	BackgroundTransparency = 1, Text = "~", TextColor3 = Color3.new(1, 1, 1), TextSize = 16,
})
local unavailableFilterButton = filterText("TextButton", {
	BackgroundColor3 = Color3.fromRGB(50, 50, 60), Text = "Unavailable: Off",
	TextColor3 = Color3.new(1, 1, 1), TextSize = 10,
})
local salesTypeButton = filterText("TextButton", {
	BackgroundColor3 = Color3.fromRGB(50, 50, 60), Text = "Sales type: All",
	TextColor3 = Color3.fromRGB(170, 170, 175), TextSize = 10, AutoButtonColor = false,
})
local applyFilterButton = filterText("TextButton", {
	BackgroundColor3 = Color3.fromRGB(75, 75, 90), Text = "Apply filters",
	TextColor3 = Color3.new(1, 1, 1), TextSize = 11,
})

-- Sort moved into the filter popup as-is (same options and behaviour).
sortButton.Parent = filterPanel
sortButton.ZIndex = 71
sortMenu.Parent = filterPanel
sortMenu.ZIndex = 80
for _, box in ipairs({minPriceBox, maxPriceBox, offSaleButton}) do
	box.Parent = filterPanel
	box.ZIndex = 71
end
minPriceBox.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
maxPriceBox.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
offSaleButton.TextSize = 10
minPriceBox.TextSize = 11
maxPriceBox.TextSize = 11

local FILTER_SORT_Y = 0
local function layoutFilterPanel(popupWidth: number): number
	local inner = popupWidth - FILTER_PAD * 2
	local y = FILTER_PAD
	creatorLabel.Position = UDim2.fromOffset(FILTER_PAD, y)
	creatorLabel.Size = UDim2.fromOffset(inner, 14)
	y += 14 + 2
	creatorNameBox.Position = UDim2.fromOffset(FILTER_PAD, y)
	creatorNameBox.Size = UDim2.fromOffset(inner, FILTER_ROW)
	y += FILTER_ROW + FILTER_GAP
	priceFilterLabel.Position = UDim2.fromOffset(FILTER_PAD, y)
	priceFilterLabel.Size = UDim2.fromOffset(inner, 14)
	y += 14 + 2
	local offSaleWidth = math.floor(inner * 0.3)
	local tildeWidth = 14
	local boxWidth = math.floor((inner - offSaleWidth - tildeWidth - FILTER_GAP * 3) / 2)
	minPriceBox.Position = UDim2.fromOffset(FILTER_PAD, y)
	minPriceBox.Size = UDim2.fromOffset(boxWidth, FILTER_ROW)
	priceTildeLabel.Position = UDim2.fromOffset(FILTER_PAD + boxWidth + FILTER_GAP, y)
	priceTildeLabel.Size = UDim2.fromOffset(tildeWidth, FILTER_ROW)
	maxPriceBox.Position = UDim2.fromOffset(FILTER_PAD + boxWidth + tildeWidth + FILTER_GAP * 2, y)
	maxPriceBox.Size = UDim2.fromOffset(boxWidth, FILTER_ROW)
	offSaleButton.Position = UDim2.fromOffset(popupWidth - FILTER_PAD - offSaleWidth, y)
	offSaleButton.Size = UDim2.fromOffset(offSaleWidth, FILTER_ROW)
	y += FILTER_ROW + FILTER_GAP
	local halfWidth = math.floor((inner - FILTER_GAP) / 2)
	unavailableFilterButton.Position = UDim2.fromOffset(FILTER_PAD, y)
	unavailableFilterButton.Size = UDim2.fromOffset(halfWidth, FILTER_ROW)
	salesTypeButton.Position = UDim2.fromOffset(popupWidth - FILTER_PAD - halfWidth, y)
	salesTypeButton.Size = UDim2.fromOffset(halfWidth, FILTER_ROW)
	y += FILTER_ROW + FILTER_GAP
	FILTER_SORT_Y = y
	sortButton.Position = UDim2.fromOffset(FILTER_PAD, y)
	sortButton.Size = UDim2.fromOffset(inner, FILTER_ROW)
	sortButton.TextSize = 10
	y += FILTER_ROW + FILTER_GAP
	applyFilterButton.Position = UDim2.fromOffset(FILTER_PAD, y)
	applyFilterButton.Size = UDim2.fromOffset(inner, FILTER_ROW + 2)
	y += FILTER_ROW + 2 + FILTER_PAD
	return y
end

local function updateMainCategorySelection()
	for _, child in ipairs(mainCategoryStrip:GetChildren()) do
		if child:IsA("TextButton") then
			local selected = child.Name == (activeTopLevelGroup and ("MainCategory_" .. activeTopLevelGroup) or "MainCategory_All")
			child.BackgroundTransparency = selected and 0 or 0.6
			child.BackgroundColor3 = selected and Color3.fromRGB(78, 78, 94) or Color3.fromRGB(0, 0, 0)
			child.TextColor3 = selected and Color3.fromRGB(255,255,255) or Color3.fromRGB(190,190,200)
		end
	end
end

local groupButtonByName = {}
-- Largest size <= desired whose single-line text fits maxWidth (min 8).
local function fitTextSize(text: string, font: Enum.Font, desired: number, maxWidth: number): number
	local size = desired
	while size > 8 do
		local ok, bounds = pcall(function()
			return game:GetService("TextService"):GetTextSize(text, size, font, Vector2.new(1000, 100))
		end)
		if not ok or bounds.X <= maxWidth then break end
		size -= 1
	end
	return size
end

-- Category chips size to their text: short labels give short buttons.
local CHIP_PADDING = 12
local function makeChipAutoWidth(button: TextButton, height: number)
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.fromOffset(0, height)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, CHIP_PADDING),
		PaddingRight = UDim.new(0, CHIP_PADDING),
	}).Parent = button
end
local allMainCategoryButton=create("TextButton",{Name="MainCategory_All",BackgroundColor3=Color3.fromRGB(78,78,94),BackgroundTransparency=0,Text="전체",TextColor3=Color3.new(1,1,1),TextSize=16,Font=Enum.Font.GothamBold,LayoutOrder=0}); makeChipAutoWidth(allMainCategoryButton, 28); allMainCategoryButton.Parent=mainCategoryStrip; create("UICorner",{CornerRadius=UDim.new(0,7)}).Parent=allMainCategoryButton
allMainCategoryButton.MouseButton1Click:Connect(function()
	activeTopLevelGroup = nil
	updateMainCategorySelection()
	renderSubcategoryStrip(nil)
	selectCategory("전체", Config.AllowedAssetTypes, nil)
end)
for index, group in ipairs(Config.CategoryGroups) do
	local b = create("TextButton", {
		Name = "MainCategory_" .. group.Name,
		BackgroundColor3 = Color3.fromRGB(0,0,0),
		BackgroundTransparency = 0.6,
		Text = group.Name,
		TextColor3 = Color3.fromRGB(190,190,200),
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		LayoutOrder = index,
	})
	makeChipAutoWidth(b, 28)
	b.Parent = mainCategoryStrip
	create("UICorner", {CornerRadius = UDim.new(0, 7)}).Parent = b
	groupButtonByName[group.Name] = b
	b.MouseButton1Click:Connect(function()
		activeTopLevelGroup = group.Name
		renderSubcategoryStrip(group.Name)
		updateMainCategorySelection()
		local groupAssetTypes = {}
		local groupBundleTypes = {}
		local seenAssetTypes = {}
		local seenBundleTypes = {}
		for _, category in ipairs(group.Categories) do
			for _, assetType in ipairs(category.AssetTypes) do
				local key = tostring(assetType)
				if not seenAssetTypes[key] then seenAssetTypes[key] = true; table.insert(groupAssetTypes, assetType) end
			end
			for _, bundleType in ipairs(category.BundleTypes or {}) do
				local key = tostring(bundleType)
				if not seenBundleTypes[key] then seenBundleTypes[key] = true; table.insert(groupBundleTypes, bundleType) end
			end
		end
		selectCategory(group.Name, groupAssetTypes, groupBundleTypes)
	end)
end

categoryLeftButton.MouseButton1Click:Connect(function()
	print("대분류 카테고리의 왼쪽 화살표 클릭")
	mainCategoryStrip.CanvasPosition = Vector2.new(math.max(0, mainCategoryStrip.CanvasPosition.X - 120), 0)
end)
categoryRightButton.MouseButton1Click:Connect(function()
	print("대분류 카테고리의 오른쪽 화살표 클릭")
	mainCategoryStrip.CanvasPosition = Vector2.new(math.min(mainCategoryStrip.AbsoluteCanvasSize.X, mainCategoryStrip.CanvasPosition.X + 120), 0)
end)

subcategoryLeftButton.MouseButton1Click:Connect(function()
	print("중분류 카테고리의 왼쪽 화살표 클릭")
	subcategoryStrip.CanvasPosition = Vector2.new(math.max(0, subcategoryStrip.CanvasPosition.X - 120), 0)
end)
subcategoryRightButton.MouseButton1Click:Connect(function()
	print("중분류 카테고리의 오른쪽 화살표 클릭")
	subcategoryStrip.CanvasPosition = Vector2.new(math.min(subcategoryStrip.AbsoluteCanvasSize.X, subcategoryStrip.CanvasPosition.X + 120), 0)
end)

-- Mouse drag scrolling for desktop; touch scrolling remains native on mobile.
local categoryDragStartX: number? = nil
local categoryDragCanvasX = 0
local subcategoryDragStartX: number? = nil
local subcategoryDragCanvasX = 0
mainCategoryStrip.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		categoryDragStartX = input.Position.X
		categoryDragCanvasX = mainCategoryStrip.CanvasPosition.X
	end
end)
mainCategoryStrip.InputChanged:Connect(function(input)
	if categoryDragStartX and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = categoryDragStartX - input.Position.X
		mainCategoryStrip.CanvasPosition = Vector2.new(
			math.clamp(categoryDragCanvasX + delta, 0, math.max(0, mainCategoryStrip.AbsoluteCanvasSize.X - mainCategoryStrip.AbsoluteWindowSize.X)),
			0
		)
	end
end)
mainCategoryStrip.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then categoryDragStartX = nil end
end)
subcategoryStrip.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		subcategoryDragStartX = input.Position.X
		subcategoryDragCanvasX = subcategoryStrip.CanvasPosition.X
	end
end)
subcategoryStrip.InputChanged:Connect(function(input)
	if subcategoryDragStartX and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = subcategoryDragStartX - input.Position.X
		subcategoryStrip.CanvasPosition = Vector2.new(math.clamp(subcategoryDragCanvasX + delta, 0, math.max(0, subcategoryStrip.AbsoluteCanvasSize.X - subcategoryStrip.AbsoluteWindowSize.X)), 0)
	end
end)
subcategoryStrip.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then subcategoryDragStartX = nil end
end)

local MODE_BY_LABEL = { ["최근"] = "Recent", ["인기"] = "Popular", ["즐겨찾기"] = "Favorites", ["착용 중"] = "Wearing", ["옷장"] = "Wardrobe" }
local function updateDiscoveryHighlight()
	for label, button in pairs(discoveryButtons) do
		local active = MODE_BY_LABEL[label] ~= nil and MODE_BY_LABEL[label] == browseMode
		button.BackgroundColor3 = if active then Color3.fromRGB(78, 78, 94) else Color3.fromRGB(0, 0, 0)
		button.BackgroundTransparency = if active then 0 else 0.6
	end
end
-- Pressing the active mode again returns to the normal catalog.
local function setBrowseMode(mode: string)
	if mode == browseMode then
		mode = "Catalog"
	end
	browseMode = mode
	updateDiscoveryHighlight()
	searchCatalog()
end
for label, mode in pairs(MODE_BY_LABEL) do
	discoveryButtons[label].MouseButton1Click:Connect(function()
		setBrowseMode(mode)
	end)
end
discoveryButtons["⚙"].MouseButton1Click:Connect(function()
	openAvatarEditor()
end)
fixedFilterButton.MouseButton1Click:Connect(function()
	filterPanelOpen = not filterPanelOpen
	updateCatalogLayout()
end)
-- A press anywhere outside the filter popup (and its sort list) closes it
-- (2026-10-20 feedback). The 필터 button keeps toggling it.
do
	local function inside(gui: GuiObject, position: Vector3): boolean
		local origin, size = gui.AbsolutePosition, gui.AbsoluteSize
		return gui.Visible and position.X >= origin.X and position.X <= origin.X + size.X
			and position.Y >= origin.Y and position.Y <= origin.Y + size.Y
	end
	UserInputService.InputBegan:Connect(function(input)
		if not filterPanelOpen then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local position = input.Position
		if inside(filterPanel, position) or inside(sortMenu, position) or inside(fixedFilterButton, position) then
			return
		end
		filterPanelOpen = false
		updateCatalogLayout()
	end)
end
local function syncOffSaleLabels()
	unavailableFilterButton.Text = "Unavailable: " .. (currentIncludeOffSale and "On" or "Off")
	offSaleButton.Text = currentIncludeOffSale and "☑ Off Sale" or "□ Off Sale"
	local onColor = Color3.fromRGB(105, 85, 160)
	local offColor = Color3.fromRGB(50, 50, 60)
	offSaleButton.BackgroundColor3 = currentIncludeOffSale and onColor or offColor
	unavailableFilterButton.BackgroundColor3 = currentIncludeOffSale and onColor or offColor
end
unavailableFilterButton.MouseButton1Click:Connect(function()
	currentIncludeOffSale = not currentIncludeOffSale
	syncOffSaleLabels()
end)
applyFilterButton.MouseButton1Click:Connect(function()
	syncOffSaleLabels()
	filterPanelOpen = false
	updateCatalogLayout()
	searchCatalog()
end)
salesTypeButton.MouseButton1Click:Connect(function()
	print("[CatalogUI] Limited sales filter disabled until API support is verified.")
end)


local grid = create("UIGridLayout", {
	CellSize = UDim2.fromOffset(165, 240),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
grid.Parent = resultsFrame

--------------------------------------------------
-- ★ PAGINATION
--------------------------------------------------

local pageLabel = create("TextLabel", {
	Name = "PageLabel",
	Size = UDim2.fromOffset(120, 32),
	Position = UDim2.new(0.5, -60, 1, -45),
	BackgroundTransparency = 1,
	Text = "Page 1",
	TextColor3 = Color3.fromRGB(190, 190, 200),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
})
pageLabel.Parent = mainFrame

local nextButton = create("TextButton", {
	Name = "NextButton",
	Size = UDim2.fromOffset(120, 32),
	Position = UDim2.new(1, -140, 1, -45),
	BackgroundColor3 = Color3.fromRGB(55, 55, 65),
	Text = "Loading more...",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
})
nextButton.Parent = mainFrame
nextButton.Visible = false
pageLabel.Visible = false

create("UICorner", {
	CornerRadius = UDim.new(0, 8),
}).Parent = nextButton

--------------------------------------------------
-- RESPONSIVE CATALOG LAYOUT
--------------------------------------------------


updateCatalogLayout = function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	-- below the top-bar button row (it can sit lower than the Roblox inset on phones)
	local insetTop = math.max(GuiService:GetGuiInset().Y, require(script.Parent:WaitForChild("TopBar")).bottom())
	-- Phones: narrow, or touch devices with a short landscape height. Tablets keep
	-- the wider compact window.
	local isPhone = viewport.X < 600 or (UserInputService.TouchEnabled and viewport.Y < 500)
	local narrow = viewport.X < 900
	local margin = if isPhone then 6 else 10
	local topY = insetTop + margin
	local panelWidth: number
	local panelHeight: number
	if expandedPanel then
		-- Equal gap on all four sides, starting below the Roblox top bar.
		panelWidth = math.max(200, viewport.X - margin * 2)
		panelHeight = math.max(160, viewport.Y - topY - margin)
		mainFrame.Position = UDim2.fromOffset(margin, topY)
	else
		local compactWidth = if isPhone then math.max(160, math.floor(viewport.X * 0.4))
			elseif narrow then math.floor(viewport.X * 0.5)
			else math.min(760, math.max(280, math.floor(viewport.X * 0.42)))
		panelWidth = math.min(compactWidth, viewport.X - margin * 2)
		local maxHeight = math.max(160, viewport.Y - topY - margin)
		panelHeight = if isPhone then maxHeight else math.min(math.max(260, math.floor(viewport.Y * 0.58)), maxHeight)
		mainFrame.Position = UDim2.fromOffset(viewport.X - panelWidth - margin, viewport.Y - panelHeight - margin)
	end
	mainFrame.Size = UDim2.fromOffset(panelWidth, panelHeight)
	local compact = not expandedPanel
	local phoneCompact = compact and isPhone
	local leftWidth = if expandedPanel then math.floor(panelWidth * 0.25) else 0
	local catalogX = if expandedPanel then leftWidth + margin else 0
	local rightWidth = panelWidth - catalogX
	catalogPanel.Position = UDim2.fromOffset(catalogX, 0)
	catalogPanel.Size = UDim2.fromOffset(rightWidth, panelHeight)
	local pad = if phoneCompact then 6 elseif expandedPanel then 10 else 8
	local x = catalogX + pad
	local contentRight = panelWidth - pad
	local innerWidth = math.max(1, contentRight - x)
	local headerY = pad
	local rowH = if expandedPanel then 32 else 28
	local controlSize = if phoneCompact then 28 else 32

	if expandedPanel then
		previewFrame.Position = UDim2.fromOffset(0, 0)
		previewFrame.Size = UDim2.fromOffset(leftWidth, panelHeight)
		previewFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		previewFrame.BackgroundTransparency = 0.2
		previewTitle.Visible = false
		-- The viewport fills the box down to the worn strip; ⚙ (edit) and ▣ (save)
		-- sit inside its top-left corner, stacked vertically (2026-10-19 feedback).
		avatarViewport.Position = UDim2.fromOffset(8, 8)
		avatarViewport.Size = UDim2.new(1, -16, 1, -132)
		avatarEditorButton.Position = UDim2.fromOffset(14, 14)
		wardrobeButton.Position = UDim2.fromOffset(14, 52)
		avatarEditorButton.Size = UDim2.fromOffset(32, 32)
		wardrobeButton.Size = UDim2.fromOffset(32, 32)
		currentOutfitFrame.Visible = true
		currentOutfitFrame.Position = UDim2.new(0, 8, 1, -116)
		currentOutfitFrame.Size = UDim2.new(1, -16, 0, 108)
	else
		previewTitle.Visible = false
		currentOutfitFrame.Visible = false
	end

	-- Header: title, discovery shortcuts, expand and close.
	closeButton.Size = UDim2.fromOffset(controlSize, controlSize)
	closeButton.Position = UDim2.fromOffset(contentRight - controlSize, headerY)
	closeButton.TextSize = if phoneCompact then 20 else 26
	expandButton.Size = UDim2.fromOffset(controlSize, controlSize)
	expandButton.Position = UDim2.fromOffset(contentRight - controlSize * 2 - 6, headerY)
	expandButton.Visible = true
	expandButton.Text = if expandedPanel then "↙" else "↗"
	expandButton.TextSize = if phoneCompact then 16 else 20
	local controlsLeft = contentRight - controlSize * 2 - 6
	titleLabel.Visible = not phoneCompact
	titleLabel.Position = UDim2.fromOffset(x, headerY + 1)
	titleLabel.Size = UDim2.fromOffset(math.min(132, math.max(72, math.floor(rightWidth * 0.22))), 30)
	titleLabel.TextSize = if expandedPanel then 18 else 15
	local discoveryX: number
	local discoveryY: number
	local discoveryWidth: number
	if phoneCompact then
		discoveryX, discoveryY = x, headerY
		discoveryWidth = math.max(1, controlsLeft - 6 - x)
	elseif compact then
		discoveryX, discoveryY = x, headerY + 36
		discoveryWidth = innerWidth
	else
		discoveryWidth = math.max(1, math.min(360, controlsLeft - 8 - (x + titleLabel.Size.X.Offset)))
		discoveryX, discoveryY = controlsLeft - 6 - discoveryWidth, headerY
	end
	discoveryBar.Visible = true
	discoveryBar.Position = UDim2.fromOffset(discoveryX, discoveryY)
	discoveryBar.Size = UDim2.fromOffset(discoveryWidth, controlSize)
	local visibleDiscovery = 0
	for label, button in pairs(discoveryButtons) do
		button.Visible = compact or not COMPACT_ONLY_DISCOVERY[label]
		if button.Visible then visibleDiscovery += 1 end
	end
	local perRow = if expandedPanel then visibleDiscovery else 4
	local discoveryButtonWidth = math.max(44, math.floor((discoveryWidth - 5 * (perRow - 1)) / perRow))
	for label, button in pairs(discoveryButtons) do
		local iconOnly = label == "⚙"
		local buttonWidth = if iconOnly then math.min(discoveryButtonWidth, 36) else discoveryButtonWidth
		button.Size = UDim2.fromOffset(buttonWidth, controlSize - 4)
		-- Text is 1.5x the earlier size, shrunk only when a label would not fit.
		button.TextSize = if iconOnly then 18
			else fitTextSize(button.Text, button.Font, if expandedPanel then 16 elseif phoneCompact then 13 else 15, buttonWidth - 6)
	end

	-- Category row (and, in expanded mode, search + filter on the same row).
	local rowY = if phoneCompact then headerY + controlSize + 4 elseif compact then headerY + 70 else headerY + 40
	local categoryWidth = if expandedPanel then math.max(80, math.floor(innerWidth * (if narrow then 0.32 else 0.42))) else innerWidth
	local function placeArrowRow(left: TextButton, strip: ScrollingFrame, right: TextButton, rowX: number, y: number, width: number)
		-- Arrow circles are half the row height (user request 2026-10-19).
		local diameter = math.floor(rowH / 2)
		local offsetY = math.floor((rowH - diameter) / 2)
		left.Visible = true
		right.Visible = true
		left.Size = UDim2.fromOffset(diameter, diameter)
		right.Size = UDim2.fromOffset(diameter, diameter)
		left.TextSize = diameter
		right.TextSize = diameter
		left.Position = UDim2.fromOffset(rowX, y + offsetY)
		right.Position = UDim2.fromOffset(rowX + width - diameter, y + offsetY)
		strip.Visible = true
		strip.Position = UDim2.fromOffset(rowX + diameter + 4, y + 2)
		strip.Size = UDim2.fromOffset(math.max(1, width - diameter * 2 - 8), rowH - 4)
	end
	placeArrowRow(categoryLeftButton, mainCategoryStrip, categoryRightButton, x, rowY, categoryWidth)
	local subY = rowY + rowH + 4
	placeArrowRow(subcategoryLeftButton, subcategoryStrip, subcategoryRightButton, x, subY, innerWidth)

	local searchX = if compact then x else x + categoryWidth + 8
	local searchY = if compact then subY + rowH + 4 else rowY
	local searchArea = math.max(1, contentRight - searchX)
	local searchButtonWidth = if phoneCompact then 28 else math.clamp(math.floor(searchArea * 0.17), 40, 76)
	local filterWidth = if phoneCompact then 32 else math.clamp(math.floor(searchArea * 0.14), 40, 66)
	local searchWidth = math.max(28, searchArea - searchButtonWidth - filterWidth - 8)
	searchBox.Position = UDim2.fromOffset(searchX, searchY)
	searchBox.Size = UDim2.fromOffset(searchWidth, rowH)
	searchBox.TextSize = if expandedPanel then 12 elseif phoneCompact then 9 else 10
	searchBox.PlaceholderText = if phoneCompact then "Search..." else "Search Roblox catalog..."
	searchButton.Visible = true
	searchButton.Text = if phoneCompact then "🔍" else "SEARCH"
	searchButton.Position = UDim2.fromOffset(searchX + searchWidth + 4, searchY)
	searchButton.Size = UDim2.fromOffset(searchButtonWidth, rowH)
	searchButton.TextSize = if phoneCompact then 18
		else fitTextSize(searchButton.Text, searchButton.Font, if expandedPanel then 15 else 13, searchButtonWidth - 4)
	fixedFilterButton.Visible = true
	fixedFilterButton.Text = "필터"
	fixedFilterButton.Position = UDim2.fromOffset(contentRight - filterWidth, searchY)
	fixedFilterButton.Size = UDim2.fromOffset(filterWidth, rowH)
	fixedFilterButton.TextSize = fitTextSize("필터", fixedFilterButton.Font, if phoneCompact then 13 elseif expandedPanel then 16 else 15, filterWidth - 4)
	sortButton.Visible = true
	local sortLabel = "Relevance"
	for _, option in ipairs(Config.SortOptions) do
		if option.Value == currentSort then
			sortLabel = option.Name
			break
		end
	end
	sortButton.Text = "Sort: " .. sortLabel .. " ▼"
	filterLabel.Visible = false

	-- Filter popup: opens under the filter button, right edges aligned, clamped on screen.
	if filterPanelOpen then
		local popupWidth = math.min(300, math.max(180, viewport.X - margin * 2))
		local popupHeight = layoutFilterPanel(popupWidth)
		filterPanel.Size = UDim2.fromOffset(popupWidth, popupHeight)
		local frameOrigin = mainFrame.Position
		local frameX = frameOrigin.X.Offset
		local frameY = frameOrigin.Y.Offset
		local buttonRight = frameX + contentRight
		local popupX = math.clamp(buttonRight - popupWidth, margin, math.max(margin, viewport.X - popupWidth - margin))
		local popupY = frameY + searchY + rowH + 4
		popupY = math.clamp(popupY, topY, math.max(topY, viewport.Y - popupHeight - margin))
		filterPanel.Position = UDim2.fromOffset(popupX - frameX, popupY - frameY)
		-- Sort dropdown opens below the sort field, or above it when there is no room.
		local optionCount = #Config.SortOptions
		local menuHeight = optionCount * (FILTER_ROW + 4) + 8
		sortMenu.Size = UDim2.fromOffset(popupWidth - FILTER_PAD * 2, menuHeight)
		local belowY = FILTER_SORT_Y + FILTER_ROW + 2
		if popupY + belowY + menuHeight > viewport.Y - margin then
			sortMenu.Position = UDim2.fromOffset(FILTER_PAD, math.max(FILTER_SORT_Y - menuHeight - 2, -(popupY - margin)))
		else
			sortMenu.Position = UDim2.fromOffset(FILTER_PAD, belowY)
		end
		filterPanel.Visible = true
	else
		filterPanel.Visible = false
		sortMenu.Visible = false
	end

	-- Results.
	local resultsY = (if compact then searchY else subY) + rowH + 6
	backToPacksButton.Visible = bundleContentsOpen
	backToPacksButton.Position = UDim2.fromOffset(x, resultsY)
	if bundleContentsOpen then
		resultsY += 28 + 4
	end
	statusLabel.Visible = false
	resultsFrame.Position = UDim2.fromOffset(x, resultsY)
	resultsFrame.Size = UDim2.fromOffset(innerWidth, math.max(1, panelHeight - resultsY - pad))
	resultsFrame.BackgroundTransparency = 1
	if expandedPanel and not isPhone then
		local cellWidth = math.clamp(math.floor((innerWidth - 36) / 6), 88, 148)
		grid.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth * 1.45))
		cardContentScale = 1
	else
		grid.CellSize = if isPhone then UDim2.fromOffset(76, 114) else UDim2.fromOffset(100, 146)
		cardContentScale = if isPhone then 0.68 else 0.82
	end
	grid.CellPadding = UDim2.fromOffset(6, 6)
	for _, contentScale in ipairs(cardContentUIScales) do
		contentScale.Scale = cardContentScale
		local content = contentScale.Parent
		if content and content:IsA("Frame") then
			content.Size = UDim2.fromScale(1 / cardContentScale, 1 / cardContentScale)
		end
	end
	currentOutfitTitle.Text = "착용 중인 아이템"
	previewFrame.Visible = expandedPanel and mainFrame.Visible
	if resultsMessage then
		resultsMessage.Position = resultsFrame.Position + UDim2.fromOffset(12, 24)
		resultsMessage.Size = UDim2.fromOffset(math.max(1, innerWidth - 24), 60)
	end

	-- Avatar Editor mode: the right box shows the editor instead of catalog controls.
	local editorOpen = avatarEditor ~= nil and avatarEditor:isOpen()
	if editorOpen and not expandedPanel then
		expandedPanel = true
		updateCatalogLayout()
		return
	end
	titleLabel.Text = if editorOpen then "AVATAR EDITOR" else "CATALOG"
	if editorOpen then
		for _, gui in ipairs({
			discoveryBar, categoryLeftButton, mainCategoryStrip, categoryRightButton,
			subcategoryLeftButton, subcategoryStrip, subcategoryRightButton,
			searchBox, searchButton, fixedFilterButton, resultsFrame, backToPacksButton,
			filterPanel,
		}) do
			gui.Visible = false
		end
		if resultsMessage then resultsMessage.Visible = false end
		avatarEditor:layout(x, rowY, innerWidth, math.max(120, panelHeight - rowY - pad))
	else
		resultsFrame.Visible = true
	end
	positionOpenButton()
end

local function bindViewport(camera: Camera?)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateCatalogLayout)
	end
	updateCatalogLayout()
end

bindViewport(workspace.CurrentCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindViewport(workspace.CurrentCamera)
end)

expandButton.MouseButton1Click:Connect(function()
	if expandedPanel and avatarEditor and avatarEditor:isOpen() then
		avatarEditor:requestClose(function()
			expandedPanel = false
			updateCatalogLayout()
		end)
		return
	end
	expandedPanel = not expandedPanel
	if expandedPanel then
		previewManuallyClosed = false
	end
	updateCatalogLayout()
	if expandedPanel then
		refreshAvatarPreview()
	end
end)

--------------------------------------------------
-- CATEGORY LOOKUP
--------------------------------------------------

local function getCategoryAssetTypes()
	return currentCategoryAssetTypes
end

--------------------------------------------------
-- CURRENT WORN ITEMS
--------------------------------------------------

-- Worn snapshot order, shared by the expanded worn strip and the 착용 중 card list:
--   1. layered clothing, OUTERMOST first (KOYA-style; WrapLayer.Order, higher = on top)
--   2. other worn items (rigid accessories, classic clothing, makeup, ...)
--   3. animation poses (idle/walk/run/...) — innermost
--   4. emotes — always last
local wornLayerInfo: {[number]: {IsLayered: boolean, Order: number?, Category: string?}} = {}
local ANIMATION_CATEGORIES = {
	ClimbAnimation = true, FallAnimation = true, IdleAnimation = true, JumpAnimation = true,
	RunAnimation = true, SwimAnimation = true, WalkAnimation = true, MoodAnimation = true,
}

local function wornGroup(assetId: number): number
	local info = wornLayerInfo[assetId]
	if not info then return 2 end
	if info.IsLayered then return 1 end
	if info.Category == "Emote" then return 4 end
	if info.Category and ANIMATION_CATEGORIES[info.Category] then return 3 end
	return 2
end

local function getWornOrder(): ({number}, {number})
	local wornIndex = {}
	for index, assetId in ipairs(wornOrder) do wornIndex[assetId] = index end
	local all = {}
	for _, assetId in ipairs(wornOrder) do
		if currentWornItems[assetId] then table.insert(all, assetId) end
	end
	table.sort(all, function(a, b)
		local groupA, groupB = wornGroup(a), wornGroup(b)
		if groupA ~= groupB then return groupA < groupB end
		if groupA == 1 then
			local orderA = wornLayerInfo[a].Order or 0
			local orderB = wornLayerInfo[b].Order or 0
			if orderA ~= orderB then return orderA > orderB end
		end
		return (wornIndex[a] or 0) < (wornIndex[b] or 0)
	end)
	local layered = {}
	for _, assetId in ipairs(all) do
		if wornGroup(assetId) == 1 then table.insert(layered, assetId) end
	end
	return all, layered
end

local function editorBlocksAvatarChanges(): boolean
	if avatarEditor and avatarEditor:isDirty() then
		showToast("아바타 편집 중인 변경 사항을 먼저 적용하거나 취소하세요.")
		return true
	end
	return false
end

local function applyLayerOrder(orderedIds: {number})
	if actionBusy or editorBlocksAvatarChanges() then
		renderCurrentOutfit()
		if browseMode == "Wearing" then renderLocalMode() end
		return
	end
	actionBusy = true
	local handled, handlerError = pcall(function()
		local ok, success, message = pcall(function()
			return TryOnItem:InvokeServer("SetLayerOrder", orderedIds)
		end)
		if not (ok and success == true) then
			warn("[CatalogUI] Layer order failed:", success, message)
			showToast(if typeof(message) == "string" then message else "레이어 순서를 바꾸지 못했습니다.")
		end
		-- Both views re-render from the same server snapshot, so they stay in sync.
		refreshWornItems()
		refreshAvatarPreview()
	end)
	if not handled then
		warn("[CatalogUI] Layer order handler error:", handlerError)
		renderCurrentOutfit()
	end
	actionBusy = false
end

local function removeWornItem(assetId: number)
	if actionBusy or editorBlocksAvatarChanges() then return end
	actionBusy = true
	local handled, handlerError = pcall(function()
		local ok, success, message = pcall(function()
			return TryOnItem:InvokeServer("Remove", { id = assetId, itemType = "Asset" })
		end)
		if ok and success == true then
			currentWornItems[assetId] = nil
			for i = #wornOrder, 1, -1 do
				if wornOrder[i] == assetId then table.remove(wornOrder, i) end
			end
			refreshWornItems()
			refreshAvatarPreview()
		else
			warn("[CatalogUI] Outfit remove failed:", success, message)
			showToast(friendlyError(message, "아이템을 벗지 못했습니다."))
		end
	end)
	if not handled then
		warn("[CatalogUI] Outfit remove handler error:", handlerError)
	end
	actionBusy = false
end

local function layerDragCanStart(): boolean
	return not actionBusy and not (avatarEditor and avatarEditor:isDirty())
end

-- Worn strip (left box, expanded mode): drag layered cards to reorder.
local stripDrag = ReorderDrag.new({
	container = currentOutfitList,
	screenGui = screenGui,
	scrollingFrame = currentOutfitList,
	isDraggable = function(card) return card:GetAttribute("LayerId") ~= nil end,
	getId = function(card) return card:GetAttribute("LayerId") end,
	getImage = function(card) return "rbxthumb://type=Asset&id=" .. tostring(card:GetAttribute("LayerId")) .. "&w=150&h=150" end,
	canStart = layerDragCanStart,
	onCommit = applyLayerOrder,
	onCancel = function() renderCurrentOutfit() end,
})

-- 착용 중 card list (right box): same reorder, same server call.
local wearingDrag = ReorderDrag.new({
	container = resultsFrame,
	screenGui = screenGui,
	scrollingFrame = resultsFrame,
	isDraggable = function(card) return card:GetAttribute("LayerId") ~= nil end,
	getId = function(card) return card:GetAttribute("LayerId") end,
	getImage = function(card) return "rbxthumb://type=Asset&id=" .. tostring(card:GetAttribute("LayerId")) .. "&w=150&h=150" end,
	canStart = layerDragCanStart,
	onCommit = function(visibleIds: {number})
		-- The grid may show only part of the layered items (search/category filters).
		-- Keep hidden items where they were and place the dragged subset in the
		-- remaining slots, so the server always receives the full, duplicate-free list.
		local _, layered = getWornOrder()
		local ordered, seen = {}, {}
		for _, id in ipairs(visibleIds) do
			if not seen[id] then seen[id] = true table.insert(ordered, id) end
		end
		local result, nextVisible = {}, 1
		for _, id in ipairs(layered) do
			if seen[id] then
				table.insert(result, ordered[nextVisible])
				nextVisible += 1
			else
				table.insert(result, id)
			end
		end
		for i = nextVisible, #ordered do
			local id = ordered[i]
			if not table.find(result, id) then table.insert(result, id) end
		end
		applyLayerOrder(result)
	end,
	onCancel = function() renderLocalMode() end,
})

local function addLayerBadge(parent: GuiObject, number: number)
	local badge = create("TextLabel", {
		Name = "LayerNumber",
		Size = UDim2.fromOffset(16, 14),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.fromRGB(105, 85, 160),
		Text = tostring(number),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 9,
		Font = Enum.Font.GothamBold,
		ZIndex = 5,
	})
	badge.Parent = parent
	create("UICorner", {CornerRadius = UDim.new(0, 4)}).Parent = badge
end

renderCurrentOutfit = function()
	if stripDrag:isDragging() then return end
	clearContainer(currentOutfitList)
	local ordered = getWornOrder()
	local layerNumber = 0
	for index, assetId in ipairs(ordered) do
		local itemCard = create("Frame", {
			Name = "Worn_" .. tostring(assetId),
			Size = UDim2.fromOffset(58, 76),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.6,
			LayoutOrder = index,
		})
		itemCard.Parent = currentOutfitList
		create("UICorner", {CornerRadius = UDim.new(0, 6)}).Parent = itemCard
		local image = create("ImageButton", {
			Name = "Thumb",
			Size = UDim2.new(1, -6, 1, -22),
			Position = UDim2.fromOffset(3, 3),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Image = "rbxthumb://type=Asset&id=" .. tostring(assetId) .. "&w=150&h=150",
			ScaleType = Enum.ScaleType.Fit,
		})
		image.Parent = itemCard
		if wornGroup(assetId) == 1 then
			layerNumber += 1
			itemCard:SetAttribute("LayerId", assetId)
			addLayerBadge(itemCard, layerNumber)
			stripDrag:attach(itemCard, image)
		end
		local removeButton = create("TextButton", {
			Size = UDim2.new(1, -4, 0, 18),
			Position = UDim2.new(0, 2, 1, -19),
			BackgroundColor3 = Color3.fromRGB(80, 48, 58),
			Text = "× 해제",
			TextColor3 = Color3.new(1,1,1),
			TextSize = 9,
			Font = Enum.Font.GothamBold,
		})
		removeButton.Parent = itemCard
		create("UICorner", {CornerRadius = UDim.new(0, 4)}).Parent = removeButton
		removeButton.MouseButton1Click:Connect(function()
			removeWornItem(assetId)
		end)
	end
end

refreshWornItems = function()
	local success, serverSuccess, result = pcall(function()
		return TryOnItem:InvokeServer("GetCurrent", 0)
	end)

	if not success then
		warn("[FashionGame] GetCurrent failed:", serverSuccess)
		return
	end

	if serverSuccess ~= true then
		warn("[FashionGame] GetCurrent rejected:", result)
		return
	end

	if typeof(result) ~= "table" then
		warn("[FashionGame] GetCurrent returned invalid data.")
		return
	end

	currentWornItems = {}
	wornLayerInfo = {}

	for _, item in ipairs(result) do
		if typeof(item) == "table" then
			local assetId = item.AssetId

			if typeof(assetId) == "number" then
				currentWornItems[assetId] = true
				wornLayerInfo[assetId] = {
					IsLayered = item.IsLayered == true,
					Order = if typeof(item.Order) == "number" then item.Order else nil,
					Category = item.Category,
				}
				local found = false
				for _, orderedId in ipairs(wornOrder) do
					if orderedId == assetId then found = true break end
				end
				if not found then table.insert(wornOrder, assetId) end
			end
		end
	end


	for _, updateButton in pairs(wornButtonUpdaters) do
		updateButton()
	end
	renderCurrentOutfit()
	if browseMode == "Wearing" and not wearingDrag:isDragging() then
		renderLocalMode()
	end
	if avatarEditor and avatarEditor:isOpen() and not avatarEditor:isDirty() and not avatarEditor.busy then
		task.spawn(function() avatarEditor:reloadState() end)
	end

	if previewFrame.Visible then
		refreshAvatarPreview()
	end
end

--------------------------------------------------
-- CARD
--------------------------------------------------

--------------------------------------------------
-- TOAST / EMPTY STATE
--------------------------------------------------

local toastLabel = create("TextLabel", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 1),
	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.fromOffset(240, 0),
	BackgroundColor3 = Color3.fromRGB(20, 20, 26),
	BackgroundTransparency = 0.1,
	TextColor3 = Color3.fromRGB(240, 240, 245),
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextWrapped = true,
	Visible = false,
	ZIndex = 250,
})
create("UIPadding", {
	PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
}).Parent = toastLabel
create("UICorner", {CornerRadius = UDim.new(0, 8)}).Parent = toastLabel
toastLabel.Parent = screenGui
local toastToken = 0
showToast = function(text: string)
	toastToken += 1
	local token = toastToken
	local frame = mainFrame
	toastLabel.Size = UDim2.fromOffset(math.max(140, math.min(320, frame.AbsoluteSize.X - 16)), 0)
	toastLabel.Position = UDim2.fromOffset(
		frame.AbsolutePosition.X - screenGui.AbsolutePosition.X + frame.AbsoluteSize.X / 2,
		frame.AbsolutePosition.Y - screenGui.AbsolutePosition.Y + frame.AbsoluteSize.Y - 12
	)
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(2.6, function()
		if token == toastToken then toastLabel.Visible = false end
	end)
end

-- Distinct empty / unsupported / error states over the results area.
resultsMessage = create("TextLabel", {
	Name = "ResultsMessage",
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(175, 175, 185),
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	Visible = false,
	ZIndex = 4,
})
resultsMessage.Parent = mainFrame
local function setResultsMessage(text: string?)
	resultsMessage.Position = resultsFrame.Position + UDim2.fromOffset(12, 24)
	resultsMessage.Size = UDim2.new(0, math.max(1, resultsFrame.AbsoluteSize.X - 24), 0, 60)
	resultsMessage.Text = text or ""
	resultsMessage.Visible = text ~= nil and text ~= "" and resultsFrame.Visible
end

--------------------------------------------------
-- RECENT (session only) / FAVORITES (persisted) / ITEM DETAILS
--------------------------------------------------

local function itemKey(itemType: string, id: number): string
	return itemType .. ":" .. tostring(id)
end

-- Recent = every item successfully worn at least once this session, kept after
-- removal, newest first, reset on rejoin (D-020 / D-023).
recordRecent = function(item: any, itemType: string)
	local id = item.Id
	if typeof(id) ~= "number" then return end
	for index = #recentItems, 1, -1 do
		if recentItems[index].Id == id and recentItems[index].ItemType == itemType then
			table.remove(recentItems, index)
		end
	end
	local entry = table.clone(item)
	entry.ItemType = itemType
	table.insert(recentItems, 1, entry)
	while #recentItems > MAX_RECENT do table.remove(recentItems) end
	itemDetailsCache[itemKey(itemType, id)] = entry
end

local function refreshFavoriteStars()
	for _, star in ipairs(resultsFrame:GetDescendants()) do
		if star.Name == "FavoriteStar" and star:IsA("TextLabel") then
			star.Visible = favoriteSet[star:GetAttribute("FavoriteKey")] == true
		end
	end
end

local function setFavorites(result: any)
	favoriteItems = {}
	favoriteSet = {}
	for _, entry in ipairs(result.favorites or {}) do
		table.insert(favoriteItems, entry)
		favoriteSet[itemKey(entry.itemType, entry.id)] = true
	end
	favoritesNote = result.note
end

local function loadFavorites()
	local ok, success, result = pcall(function()
		return PlayerData:InvokeServer("GetFavorites", nil)
	end)
	if ok and success == true and typeof(result) == "table" then
		setFavorites(result)
		refreshFavoriteStars()
	else
		warn("[CatalogUI] Could not load favorites:", success, result)
	end
end

toggleFavorite = function(id: number, itemType: string, item: any)
	local ok, success, result = pcall(function()
		return PlayerData:InvokeServer("ToggleFavorite", { id = id, itemType = itemType })
	end)
	if not (ok and success == true and typeof(result) == "table") then
		showToast(if typeof(result) == "string" then result else "즐겨찾기를 바꾸지 못했습니다.")
		return
	end
	setFavorites(result)
	if item then itemDetailsCache[itemKey(itemType, id)] = item end
	refreshFavoriteStars()
	local message = if result.favorited then "즐겨찾기에 추가했습니다." else "즐겨찾기에서 해제했습니다."
	if favoritesNote then message ..= "\n" .. favoritesNote end
	showToast(message)
	if browseMode == "Favorites" then renderLocalMode() end
end

-- Batch details through AvatarEditorService:GetBatchItemDetails (cached).
local function fetchItemDetails(entries: {{id: number, itemType: string}}): {[string]: any}
	local result = {}
	local missing = { Asset = {}, Bundle = {} }
	for _, entry in ipairs(entries) do
		local key = itemKey(entry.itemType, entry.id)
		if itemDetailsCache[key] then
			result[key] = itemDetailsCache[key]
		elseif missing[entry.itemType] then
			table.insert(missing[entry.itemType], entry.id)
		end
	end
	for itemType, ids in pairs(missing) do
		local index = 1
		while index <= #ids do
			local chunk = {}
			for i = index, math.min(index + 99, #ids) do table.insert(chunk, ids[i]) end
			index += 100
			local ok, details = pcall(function()
				return AvatarEditorService:GetBatchItemDetails(chunk, Enum.AvatarItemType[itemType])
			end)
			if ok and typeof(details) == "table" then
				for _, detail in ipairs(details) do
					if typeof(detail) == "table" and typeof(detail.Id) == "number" then
						detail.ItemType = itemType
						local key = itemKey(itemType, detail.Id)
						itemDetailsCache[key] = detail
						result[key] = detail
					end
				end
			else
				warn("[CatalogUI] GetBatchItemDetails failed:", details)
			end
		end
	end
	return result
end

-- Shoes are sold on Roblox only as "Shoes" bundles (left + right shoe assets;
-- the individual shoe assets are off-sale). Wear/remove them as a pair from the
-- card; the worn strip still lists each shoe separately.
-- Bundles worn as one set from the card (WEAR/WORN instead of CONTENTS):
-- Shoes (left + right), BodyParts (full body) and DynamicHead (head). Roblox
-- search does not return the individual parts. "Core" types decide WORN.
local WearableBundles = {}
WearableBundles.core = {
	Shoes = { LeftShoeAccessory = true, RightShoeAccessory = true },
	BodyParts = { Torso = true, LeftArm = true, RightArm = true, LeftLeg = true, RightLeg = true },
	DynamicHead = { Head = true, DynamicHead = true },
} :: {[string]: {[string]: boolean}}
WearableBundles.wearTypes = {
	LeftShoeAccessory = true, RightShoeAccessory = true,
	Torso = true, LeftArm = true, RightArm = true, LeftLeg = true, RightLeg = true,
	Head = true, DynamicHead = true, MoodAnimation = true,
	EyebrowAccessory = true, EyelashAccessory = true, HairAccessory = true, FaceAccessory = true,
	FaceMakeup = true, LipMakeup = true, EyeMakeup = true,
} :: {[string]: boolean}
WearableBundles.coreAssets = {} :: {[number]: {number}}
local shoeBundleAssets: {[number]: {number}} = {}
local shoeBundleLoading: {[number]: boolean} = {}

local function loadShoeBundleAssets(bundleId: number, bundleType: string, onLoaded: () -> ())
	if shoeBundleAssets[bundleId] or shoeBundleLoading[bundleId] then return end
	local core = WearableBundles.core[bundleType] or {}
	shoeBundleLoading[bundleId] = true
	task.spawn(function()
		local ok, details = pcall(function()
			return AssetService:GetBundleDetailsAsync(bundleId)
		end)
		local ids, coreIds = {}, {}
		if ok and typeof(details) == "table" and typeof(details.Items) == "table" then
			for _, bundled in ipairs(details.Items) do
				local typeName = if typeof(bundled) == "table" then tostring(bundled.AssetType) else ""
				if typeof(bundled) == "table" and bundled.Type == "Asset" and typeof(bundled.Id) == "number"
					and WearableBundles.wearTypes[typeName] then
					table.insert(ids, bundled.Id)
					if core[typeName] then table.insert(coreIds, bundled.Id) end
				end
			end
		else
			warn("[CatalogController] Bundle details failed:", details)
		end
		shoeBundleAssets[bundleId] = ids
		WearableBundles.coreAssets[bundleId] = if #coreIds > 0 then coreIds else ids
		shoeBundleLoading[bundleId] = nil
		onLoaded()
	end)
end

local function isShoeBundleWorn(bundleId: number): boolean
	local ids = WearableBundles.coreAssets[bundleId]
	if not ids or #ids == 0 then return false end
	for _, id in ipairs(ids) do
		if not currentWornItems[id] then return false end
	end
	return true
end

createItemCard = function(item: any, layoutOrder: number)
	local assetId = item.Id

	if typeof(assetId) ~= "number" then
		return
	end

	local isBundle = item.ItemType == "Bundle"
	local isShoeBundle = isBundle and WearableBundles.core[tostring(item.BundleType)] ~= nil
	local assetTypeName = if isBundle then tostring(item.BundleType or "Bundle") else getAssetTypeName(item)
	local canTryOn = not isBundle and TRY_ON_SUPPORTED_ASSET_TYPES[assetTypeName] == true

	local card = create("Frame", {
		Name = "Item_" .. tostring(assetId),
		BackgroundColor3 = Color3.fromRGB(36, 36, 44),
		LayoutOrder = layoutOrder,
	})
	card.Parent = resultsFrame

	local cardCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 8),
	})
	cardCorner.Parent = card

	local cardContent = create("Frame", {
		Name = "CardContent",
		-- Virtual frame: after UIScale it exactly fills the card.
		Size = UDim2.fromScale(1 / cardContentScale, 1 / cardContentScale),
		BackgroundTransparency = 1,
	})
	cardContent.Parent = card
	local cardContentUIScale = create("UIScale", {
		Scale = cardContentScale,
	})
	cardContentUIScale.Parent = cardContent
	table.insert(cardContentUIScales, cardContentUIScale)

	local thumbnail = create("ImageLabel", {
		Name = "Thumbnail",
		Size = UDim2.new(1, -10, 1, -100),
		Position = UDim2.fromOffset(5, 5),
		BackgroundColor3 = Color3.fromRGB(28, 28, 34),
		BorderSizePixel = 0,
		Image = "rbxthumb://type="
			.. (isBundle and "BundleThumbnail" or "Asset")
			.. "&id="
			.. tostring(assetId)
			.. "&w=420&h=420",
		ScaleType = Enum.ScaleType.Fit,
	})
	thumbnail.Parent = cardContent

	-- In-game Favorites: double-click / double-tap the image (0.5s). The image has no
	-- single-click action, so nothing has to wait for the double-click window.
	local favoriteType = if isBundle then "Bundle" else "Asset"
	local favoriteKey = favoriteType .. ":" .. tostring(assetId)
	local star = create("TextLabel", {
		Name = "FavoriteStar",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1,
		Text = "★",
		TextColor3 = Color3.fromRGB(255, 212, 64),
		TextStrokeTransparency = 0.4,
		TextSize = 22,
		Font = Enum.Font.GothamBold,
		Visible = favoriteSet[favoriteKey] == true,
		ZIndex = 4,
	})
	star:SetAttribute("FavoriteKey", favoriteKey)
	star.Parent = cardContent
	local imageHitArea = create("TextButton", {
		Name = "ImageHitArea",
		Size = thumbnail.Size,
		Position = thumbnail.Position,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	})
	imageHitArea.Parent = cardContent
	local lastImageTap = 0
	imageHitArea.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastImageTap <= 0.5 then
			lastImageTap = 0
			toggleFavorite(assetId, favoriteType, item)
		else
			lastImageTap = now
		end
	end)
	card:SetAttribute("ImageHitAreaName", "ImageHitArea")

	local thumbnailCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 6),
	})
	thumbnailCorner.Parent = thumbnail

	local nameLabel = create("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.new(0, 6, 1, -92),
		BackgroundTransparency = 1,
		Text = tostring(item.Name or "Unknown Item"),
		TextColor3 = Color3.fromRGB(245, 245, 245),
		TextSize = 20,
		Font = Enum.Font.GothamMedium,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	nameLabel.Parent = cardContent
	nameLabel.MouseEnter:Connect(function()
		if game:GetService("UserInputService").MouseEnabled then
			local mousePosition = game:GetService("UserInputService"):GetMouseLocation()
			itemNameTooltip.Text = tostring(item.Name or "Unknown Item")
			itemNameTooltip.Position = UDim2.fromOffset(mousePosition.X + 12, mousePosition.Y + 12)
			itemNameTooltip.Visible = true
		end
	end)
	nameLabel.MouseMoved:Connect(function(x, y)
		if itemNameTooltip.Visible then
			itemNameTooltip.Position = UDim2.fromOffset(x + 12, y + 12)
		end
	end)
	nameLabel.MouseLeave:Connect(function()
		itemNameTooltip.Visible = false
	end)

	local typeLabel = create("TextLabel", {
		Name = "AssetType",
		Size = UDim2.new(1, -12, 0, 14),
		Position = UDim2.new(0, 6, 1, -68),
		BackgroundTransparency = 1,
		Text = assetTypeName,
		TextColor3 = Color3.fromRGB(145, 145, 160),
		TextSize = 9,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	typeLabel.Parent = cardContent

	local priceLabel = create("TextLabel", {
		Name = "Price",
		Size = UDim2.new(1, -12, 0, 16),
		Position = UDim2.new(0, 6, 1, -52),
		BackgroundTransparency = 1,
		Text = formatPrice(item.Price),
		TextColor3 = Color3.fromRGB(190, 190, 200),
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	priceLabel.Parent = cardContent

	local actionButton = create("TextButton", {
		Name = "ActionButton",
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.new(0, 6, 1, -30),
		BackgroundColor3 = Color3.fromRGB(70, 70, 85),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = canTryOn,
	})
	actionButton.Parent = cardContent

	local actionCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 7),
	})
	actionCorner.Parent = actionButton

	local function updateButton()
		if isShoeBundle then
			if isShoeBundleWorn(assetId) then
				actionButton.Text = "WORN"
				actionButton.BackgroundColor3 = Color3.fromRGB(105, 85, 160)
			else
				actionButton.Text = "WEAR"
				actionButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
			end
			actionButton.AutoButtonColor = true
			return
		end
		if isBundle then
			actionButton.Text = "CONTENTS"
			actionButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
			actionButton.AutoButtonColor = true
			return
		end

		if not canTryOn then
			actionButton.Text = "VIEW ONLY"
			actionButton.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
			actionButton.AutoButtonColor = false
			return
		end

		if currentWornItems[assetId] then
			actionButton.Text = "WORN"
			actionButton.BackgroundColor3 = Color3.fromRGB(105, 85, 160)
		else
			actionButton.Text = "WEAR"
			actionButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
		end
	end

	updateButton()
	wornButtonUpdaters[assetId] = updateButton
	if isShoeBundle then
		loadShoeBundleAssets(assetId, tostring(item.BundleType), function()
			if actionButton.Parent then updateButton() end
		end)
	end

	actionButton.MouseButton1Click:Connect(function()
		if actionBusy then
			return
		end
		if editorBlocksAvatarChanges() then
			return
		end

		if isShoeBundle then
			actionBusy = true
			local handled, handlerError = pcall(function()
				local wasWorn = isShoeBundleWorn(assetId)
				statusLabel.Text = if wasWorn then "Removing..." else "Wearing..."
				local success, result, message = pcall(function()
					if wasWorn then
						return TryOnItem:InvokeServer("RemoveMany", shoeBundleAssets[assetId])
					end
					return TryOnItem:InvokeServer("Wear", { id = assetId, itemType = "Bundle" })
				end)
				if success and result == true then
					if not wasWorn then
						recordRecent(item, "Bundle")
						for _, id in ipairs(shoeBundleAssets[assetId] or {}) do
							for i = #wornOrder, 1, -1 do if wornOrder[i] == id then table.remove(wornOrder, i) end end
							table.insert(wornOrder, 1, id)
						end
					end
					task.wait(0.2)
					refreshWornItems()
					refreshAvatarPreview()
					updateButton()
					statusLabel.Text = if wasWorn then "Shoes removed." else "Shoes equipped."
				else
					warn("[CatalogController] Shoe bundle action failed:", result, message)
					statusLabel.Text = if typeof(message) == "string" then message else "Failed to change bundle."
					showToast(friendlyError(message, if wasWorn then "번들을 벗지 못했습니다." else "번들을 착용하지 못했습니다."))
				end
			end)
			if not handled then
				warn("[CatalogController] Shoe bundle handler error:", handlerError)
			end
			actionBusy = false
			return
		end

		if isBundle then
			if showBundleContents then
				showBundleContents(assetId, tostring(item.Name or "Animation Pack"))
			end
			return
		end

		if not canTryOn then
			return
		end

		actionBusy = true

		local handled, handlerError = pcall(function()
			if currentWornItems[assetId] then
				statusLabel.Text = "Removing..."

				local success, result, message = pcall(function()
					return TryOnItem:InvokeServer("Remove", { id = assetId, itemType = "Asset" })
				end)

				if success and result == true then
					currentWornItems[assetId] = nil
					for i = #wornOrder, 1, -1 do if wornOrder[i] == assetId then table.remove(wornOrder, i) end end
					updateButton()
					task.wait(0.15)
					refreshWornItems()
					refreshAvatarPreview()
					statusLabel.Text = "Item removed."
				else
					warn("[CatalogController] Remove failed:", result, message)
					showToast(friendlyError(message, "아이템을 벗지 못했습니다."))
					statusLabel.Text =
						typeof(message) == "string"
						and message
						or "Failed to remove item."
				end
			else
				statusLabel.Text = "Wearing..."

				local success, result, message = pcall(function()
					return TryOnItem:InvokeServer("Wear", { id = assetId, itemType = "Asset" })
				end)

				if success and result == true then
					recordRecent(item, "Asset")
					for i = #wornOrder, 1, -1 do if wornOrder[i] == assetId then table.remove(wornOrder, i) end end
					table.insert(wornOrder, 1, assetId)
					task.wait(0.2)
					refreshWornItems()
					refreshAvatarPreview()
					updateButton()
					statusLabel.Text = "Item equipped."
					-- Animations/emotes: play the new clip once on the preview avatar (no loop).
					if ANIMATION_CATEGORIES[assetTypeName] or assetTypeName == "EmoteAnimation" then
						task.spawn(function()
							local okCall, okServer, animationId = pcall(function()
								return TryOnItem:InvokeServer("GetAnimationPreview", assetId)
							end)
							if not (okCall and okServer == true and typeof(animationId) == "string") then
								warn("[CatalogUI] Animation preview unavailable:", okServer, animationId)
								return
							end
							-- Preload first: an uncached clip loaded on the viewport clone
							-- otherwise never finishes loading (seen in Studio for emotes).
							local animation = Instance.new("Animation")
							animation.AnimationId = animationId
							pcall(function()
								game:GetService("ContentProvider"):PreloadAsync({ animation })
							end)
							local previewCharacter = avatarPreviewWorld:FindFirstChild("AvatarPreviewCharacter")
							local previewHumanoid = previewCharacter and previewCharacter:FindFirstChildOfClass("Humanoid")
							if not previewHumanoid then return end
							local animator = previewHumanoid:FindFirstChildOfClass("Animator")
							if not animator then
								animator = Instance.new("Animator")
								animator.Parent = previewHumanoid
							end
							local okLoad, track = pcall(function()
								return (animator :: Animator):LoadAnimation(animation)
							end)
							if okLoad and track then
								track.Looped = false
								track:Play()
							end
						end)
					end
				else
					warn("[CatalogController] Wear failed:", result, message)
					showToast(friendlyError(message, "아이템을 착용하지 못했습니다."))
					statusLabel.Text =
						typeof(message) == "string"
						and message
						or "Failed to equip item."
				end
			end
		end)
		if not handled then
			warn("[CatalogController] Wear/remove handler error:", handlerError)
			statusLabel.Text = "Something went wrong. Try again."
			showToast("문제가 생겼습니다. 다시 시도하세요.")
		end

		actionBusy = false
	end)
	return card
end

--------------------------------------------------
-- ANIMATION BUNDLE CONTENTS
--------------------------------------------------

local ANIMATION_ASSET_TYPE_NAMES: {[string]: boolean} = {
	ClimbAnimation = true,
	FallAnimation = true,
	IdleAnimation = true,
	JumpAnimation = true,
	RunAnimation = true,
	SwimAnimation = true,
	WalkAnimation = true,
	MoodAnimation = true,
	EmoteAnimation = true,
}

showBundleContents = function(bundleId: number, bundleName: string)
	if searchBusy or actionBusy then
		return
	end

	searchBusy = true
	bundleContentsOpen = true
	backToPacksButton.Visible = true
	statusLabel.Text = "Loading contents: " .. bundleName
	wornButtonUpdaters = {}
	table.clear(cardContentUIScales)
	clearContainer(resultsFrame)

	local success, details = pcall(function()
		return AssetService:GetBundleDetailsAsync(bundleId)
	end)

	if not success or typeof(details) ~= "table" then
		warn("[CatalogController] GetBundleDetailsAsync failed:", details)
		statusLabel.Text = "Could not load bundle contents. Check Output."
		searchBusy = false
		return
	end

	local animationItems = {}
	local sourceItems = details.Items
	if typeof(sourceItems) == "table" then
		for _, bundledItem in ipairs(sourceItems) do
			if typeof(bundledItem) == "table"
				and bundledItem.Type == "Asset"
				and typeof(bundledItem.Id) == "number" then

				local itemTypeName = bundledItem.AssetType
				if typeof(itemTypeName) ~= "string" or not ANIMATION_ASSET_TYPE_NAMES[itemTypeName] then
					-- Bundle details may omit or generalize the asset type.
					-- Ask AvatarEditorService for the canonical catalog asset type.
					local detailOk, itemDetails = pcall(function()
						return AvatarEditorService:GetItemDetailsAsync(
							bundledItem.Id,
							Enum.AvatarItemType.Asset
						)
					end)
					if detailOk and typeof(itemDetails) == "table" then
						itemTypeName = itemDetails.AssetType
						if typeof(itemTypeName) == "string" then
							bundledItem = {
								Id = bundledItem.Id,
								Name = itemDetails.Name or bundledItem.Name,
								AssetType = itemTypeName,
								Price = itemDetails.Price,
								ItemType = "Asset",
							}
						end
					end
				end

				if typeof(itemTypeName) == "string" and ANIMATION_ASSET_TYPE_NAMES[itemTypeName] then
					bundledItem.ItemType = "Asset"
					table.insert(animationItems, bundledItem)
				end
			end
		end
	end

	if #animationItems == 0 then
		statusLabel.Text = "No individual animation assets were found in this bundle."
	else
		statusLabel.Text = tostring(#animationItems) .. " animation assets in " .. bundleName
		for index, animationItem in ipairs(animationItems) do
			createItemCard(animationItem, index)
		end
	end

	pageLabel.Text = "Bundle contents • " .. tostring(#animationItems)
	nextButton.Active = false
	nextButton.AutoButtonColor = false
	nextButton.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	searchBusy = false
end

backToPacksButton.MouseButton1Click:Connect(function()
	if searchBusy then
		return
	end
	bundleContentsOpen = false
	backToPacksButton.Visible = false
	renderCurrentPage()
	statusLabel.Text = "Returned to animation packs."
end)

--------------------------------------------------
-- LOCAL LISTS: Recent / Favorites / Wearing
-- Search keyword and category filter apply inside the list only.
--------------------------------------------------

local function categoryTypeNames(): ({[string]: boolean}?, {[string]: boolean}?)
	if currentCategory == "전체" or currentCategory == "All" then return nil, nil end
	local assets, bundles = {}, {}
	for _, assetType in ipairs(currentCategoryAssetTypes or {}) do
		if typeof(assetType) == "EnumItem" then assets[assetType.Name] = true end
	end
	for _, bundleType in ipairs(currentCategoryBundleTypes or {}) do
		if typeof(bundleType) == "EnumItem" then bundles[bundleType.Name] = true end
	end
	return assets, bundles
end

local function passesLocalFilters(detail: any): boolean
	local keyword = string.lower(searchBox.Text or "")
	if keyword ~= "" and not string.find(string.lower(tostring(detail.Name or "")), keyword, 1, true) then
		return false
	end
	local assets, bundles = categoryTypeNames()
	if assets and bundles then
		if detail.ItemType == "Bundle" then
			return bundles[tostring(detail.BundleType)] == true
		end
		return assets[tostring(detail.AssetType)] == true
	end
	return true
end

local EMPTY_MESSAGES = {
	Recent = "이번 접속에서 입어 본 아이템이 없습니다. 최근 목록은 다시 접속하면 비워집니다.",
	Favorites = "즐겨찾기한 아이템이 없습니다. 아이템 이미지를 두 번 눌러 추가하세요.",
	Wearing = "착용 중인 아이템이 없습니다.",
}

renderLocalMode = function()
	if browseMode == "Catalog" or browseMode == "Popular" then return end
	local mode = browseMode
	-- Overlapping renders (mode switch + worn refresh) must not both append cards;
	-- duplicated cards made the 착용 중 drag send a duplicated, rejected layer list.
	local generation = (resultsFrame:GetAttribute("LocalRenderGeneration") or 0) + 1
	resultsFrame:SetAttribute("LocalRenderGeneration", generation)
	catalogPages = nil
	bundleContentsOpen = false
	backToPacksButton.Visible = false
	wornButtonUpdaters = {}
	table.clear(cardContentUIScales)
	clearContainer(resultsFrame)
	resultsFrame.CanvasPosition = Vector2.zero

	if mode == "Wardrobe" then
		setResultsMessage(nil)
		if wardrobeView then wardrobeView:render() end
		return
	end

	local entries = {}
	if mode == "Recent" then
		for _, item in ipairs(recentItems) do
			table.insert(entries, { id = item.Id, itemType = item.ItemType })
		end
	elseif mode == "Favorites" then
		for _, favorite in ipairs(favoriteItems) do
			table.insert(entries, { id = favorite.id, itemType = favorite.itemType })
		end
	else
		for _, assetId in ipairs((getWornOrder())) do
			table.insert(entries, { id = assetId, itemType = "Asset" })
		end
	end
	local details = fetchItemDetails(entries)
	if browseMode ~= mode or generation ~= resultsFrame:GetAttribute("LocalRenderGeneration") then return end
	clearContainer(resultsFrame)
	table.clear(cardContentUIScales)

	local count = 0
	local layerNumber = 0
	for _, entry in ipairs(entries) do
		local detail = details[itemKey(entry.itemType, entry.id)]
		if detail and passesLocalFilters(detail) then
			count += 1
			local card = createItemCard(detail, count)
			if card and mode == "Wearing" and wornGroup(entry.id) == 1 then
				layerNumber += 1
				card:SetAttribute("LayerId", entry.id)
				addLayerBadge(card, layerNumber)
				local badge = card:FindFirstChild("LayerNumber")
				if badge then (badge :: TextLabel).Position = UDim2.new(1, -20, 0, 4) end
				local handle = card:FindFirstChild("ImageHitArea", true)
				if handle then wearingDrag:attach(card, handle :: GuiObject) end
			end
		end
	end
	for _, contentScale in ipairs(cardContentUIScales) do
		contentScale.Scale = cardContentScale
	end
	if count == 0 then
		setResultsMessage(if #entries == 0 then EMPTY_MESSAGES[mode] else "검색어·카테고리에 맞는 아이템이 이 목록에 없습니다.")
	else
		setResultsMessage(nil)
	end
end

--------------------------------------------------
-- ★ RENDER CURRENT PAGE
--------------------------------------------------

renderCurrentPage = function()
	bundleContentsOpen = false
	backToPacksButton.Visible = false

	if not catalogPages then
		return
	end

	wornButtonUpdaters = {}
	clearContainer(resultsFrame)

	local success, currentPage = pcall(function()
		return catalogPages:GetCurrentPage()
	end)

	if not success then
		warn("[CatalogController] Failed to read current page:", currentPage)
		statusLabel.Text = "Failed to load results."
		return
	end

	local resultCount = 0

	-- Animation subcategories must show only their matching individual asset
	-- type. Keep bundle results untouched for the Animation Pack category.
	local expectedAnimationTypeName: string? = nil
	if currentCategoryAssetTypes and #currentCategoryAssetTypes == 1 then
		local selectedAssetType = currentCategoryAssetTypes[1]
		if typeof(selectedAssetType) == "EnumItem"
			and selectedAssetType.EnumType == Enum.AvatarAssetType
			and string.find(selectedAssetType.Name, "Animation", 1, true) then
			expectedAnimationTypeName = selectedAssetType.Name
		end
	end

	for _, item in ipairs(currentPage) do
		local itemTypeName = getAssetTypeName(item)
		if expectedAnimationTypeName == nil or itemTypeName == expectedAnimationTypeName then
			createItemCard(item, resultCount + 1)
			resultCount += 1
		end
	end

	if expectedAnimationTypeName ~= nil and resultCount == 0 then
		statusLabel.Text = "No individual " .. expectedAnimationTypeName .. " assets found on this page."
	end

	pageLabel.Text = ""
	nextButton.Active = not catalogPages.IsFinished
	nextButton.AutoButtonColor = not catalogPages.IsFinished

end

--------------------------------------------------
-- ★ SEARCH
--------------------------------------------------

searchCatalog = function()
	-- Newest request wins: a click while a search or page load is running is no
	-- longer dropped; the older request's results are discarded instead.
	local generation = (resultsFrame:GetAttribute("SearchGeneration") or 0) + 1
	resultsFrame:SetAttribute("SearchGeneration", generation)
	if browseMode ~= "Catalog" and browseMode ~= "Popular" then
		sortMenu.Visible = false
		renderLocalMode()
		return
	end
	setResultsMessage(nil)

	searchBusy = true
	resultsFrame.CanvasPosition = Vector2.zero

	sortMenu.Visible = false

	currentKeyword = searchBox.Text
	bundleContentsOpen = false
	backToPacksButton.Visible = false

	local minPrice = tonumber(minPriceBox.Text)
	local maxPrice = tonumber(maxPriceBox.Text)

	currentMinPrice = math.max(0, minPrice or 0)
	currentMaxPrice = math.max(0, maxPrice or 0)

	if currentMaxPrice > 0
		and currentMaxPrice < currentMinPrice then
		local temp = currentMinPrice
		currentMinPrice = currentMaxPrice
		currentMaxPrice = temp
	end

	statusLabel.Text = "Searching..."

	local params = CatalogSearchParams.new()

	--------------------------------------------------
	-- ★ [VERIFIED] OFFICIAL SEARCH PARAMETERS
	-- SearchKeyword / Limit / SortType / SortAggregation / MinPrice /
	-- IncludeOffSale / CategoryFilter / SalesTypeFilter / CreatorType /
	-- MaxPrice / AssetTypes are all current CatalogSearchParams properties.
	--------------------------------------------------

	params.SearchKeyword = currentKeyword
	params.Limit = Config.SearchLimit
	-- Popular: Roblox MostFavorited over the past month (fallback: all time, stated).
	local isPopular = browseMode == "Popular"
	params.SortType = if isPopular then Enum.CatalogSortType.MostFavorited else currentSort
	params.SortAggregation = if isPopular then Enum.CatalogSortAggregation.PastMonth else Config.SortAggregation
	params.MinPrice = currentMinPrice
	params.IncludeOffSale = currentIncludeOffSale
	params.CategoryFilter = Config.CategoryFilter
	params.SalesTypeFilter = Config.SalesTypeFilter
	params.CreatorType = Config.CreatorType
	if creatorNameBox.Text ~= "" then
		local creatorOk, creatorErr = pcall(function()
			params.CreatorName = creatorNameBox.Text
		end)
		if not creatorOk then
			warn("[CatalogController] Creator name filtering is not supported by this client API:", creatorErr)
		end
	end

	if currentMaxPrice > 0 then
		params.MaxPrice = currentMaxPrice
	end

	local assetTypes = getCategoryAssetTypes()
	local bundleTypes = currentCategoryBundleTypes

	-- Set both filters explicitly. Bundle-only searches must not inherit a
	-- default asset filter, and an empty AssetTypes list is valid for bundles.
	params.AssetTypes = assetTypes or {}

	local validBundleTypes = {}
	if bundleTypes then
		for _, bundleType in ipairs(bundleTypes) do
			if typeof(bundleType) == "EnumItem"
				and bundleType.EnumType == Enum.BundleType then
				table.insert(validBundleTypes, bundleType)
			else
				warn("[CatalogController] Ignoring invalid BundleType:", bundleType)
			end
		end
	end
	params.BundleTypes = validBundleTypes
	-- Category defaults (e.g. body parts) may force off-sale items on, but never
	-- turn the user's own Off Sale choice off (ISSUE-CATALOG-003).
	params.IncludeOffSale = currentIncludeOffSale or currentCategoryIncludeOffSale

	print(
		"[CatalogController] Search filters:",
		"category=", currentCategory,
		"assetTypes=", #params.AssetTypes,
		"bundleTypes=", #params.BundleTypes,
		"keyword=", currentKeyword
	)

	--------------------------------------------------
	-- SEARCH
	--------------------------------------------------

	local success, pages = pcall(function()
		return AvatarEditorService:SearchCatalogAsync(params)
	end)
	if generation ~= resultsFrame:GetAttribute("SearchGeneration") then return end
	if not success and isPopular then
		warn("[CatalogController] Popular PastMonth failed, retrying AllTime:", pages)
		params.SortAggregation = Enum.CatalogSortAggregation.AllTime
		success, pages = pcall(function()
			return AvatarEditorService:SearchCatalogAsync(params)
		end)
		if generation ~= resultsFrame:GetAttribute("SearchGeneration") then return end
		if success then showToast("인기: 지난 한 달 집계를 쓸 수 없어 전체 기간 기준으로 표시합니다.") end
	end

	if not success then
		warn("[CatalogController] Search failed:", pages)
		statusLabel.Text = "Search failed. Check Output."
		clearContainer(resultsFrame)
		setResultsMessage("검색에 실패했습니다 (Roblox API 오류). 잠시 후 다시 시도하세요.")
		searchBusy = false
		return
	end

	local currentPage = pages:GetCurrentPage()

	-- Every new search/category/filter starts at the top of the results list.
	resultsFrame.CanvasPosition = Vector2.zero

	-- Keep each category truthful: an individual animation category must not
	-- silently display Animation Pack bundles as if they were individual assets.
	catalogPages = pages
	currentPageNumber = 1
	renderCurrentPage()
	statusLabel.Text = ""
	local shown = 0
	for _, child in ipairs(resultsFrame:GetChildren()) do
		if child:IsA("Frame") then shown += 1 end
	end
	if shown == 0 then
		setResultsMessage(if currentKeyword ~= "" then "\"" .. currentKeyword .. "\" 검색 결과가 없습니다." else "이 카테고리에 표시할 아이템이 없습니다.")
	end

	searchBusy = false
end

-- CATEGORY SELECTION
--------------------------------------------------

selectCategory = function(name: string, assetTypes, bundleTypes)
	if (not assetTypes or #assetTypes == 0) and (not bundleTypes or #bundleTypes == 0) then
		statusLabel.Text = "이 카테고리는 현재 Roblox API에서 직접 검색할 수 없습니다."
		showToast("이 카테고리는 Roblox 카탈로그 API로 검색할 수 없어 준비 중입니다.")
		return
	end

	-- Categories filter Recent/Favorites/Wearing, but mean nothing for saved
	-- outfits: a category press in the Wardrobe goes back to the catalog.
	if browseMode == "Wardrobe" then
		browseMode = "Catalog"
		updateDiscoveryHighlight()
	end
	currentCategory = name
	activeTopLevelGroup = nil
	for _, group in ipairs(Config.CategoryGroups) do
		for _, category in ipairs(group.Categories) do
			if category.Name == name or group.Name == name then activeTopLevelGroup = group.Name end
		end
	end
	if name == "전체" or name == "All" then activeTopLevelGroup = nil end
	updateMainCategorySelection()
	if name == "전체" or name == "All" then renderSubcategoryStrip(nil) else renderSubcategoryStrip(activeTopLevelGroup) end
	currentCategoryAssetTypes = assetTypes
	currentCategoryBundleTypes = bundleTypes
	currentCategoryIncludeOffSale = false
	for _, group in ipairs(Config.CategoryGroups) do
		for _, category in ipairs(group.Categories) do
			if (category.Name == name or group.Name == name) and category.IncludeOffSale == true then
				currentCategoryIncludeOffSale = true
			end
		end
	end
	searchCatalog()
end

local lastSubcategoryGroup: string? = "__none__"
renderSubcategoryStrip = function(groupName: string?)
	local keepScrollX = if groupName == lastSubcategoryGroup then subcategoryStrip.CanvasPosition.X else 0
	lastSubcategoryGroup = groupName
	clearContainer(subcategoryStrip)
	local entries = {}
	local function appendCategory(entry, category)
		for _, assetType in ipairs(category.AssetTypes) do table.insert(entry.assetTypes, assetType) end
		for _, bundleType in ipairs(category.BundleTypes or {}) do table.insert(entry.bundleTypes, bundleType) end
	end
	local function appendGroup(entry, wantedGroup, wantedNames)
		for _, group in ipairs(Config.CategoryGroups) do
			if group.Name == wantedGroup then
				for _, category in ipairs(group.Categories) do
					if not wantedNames then
						appendCategory(entry, category)
					else
						for _, wantedName in ipairs(wantedNames) do
							if category.Name == wantedName then appendCategory(entry, category) end
						end
					end
				end
			end
		end
	end
	if groupName == nil then
		local definitions = {
			{label = "전체", all = true},
			{label = "헤어", groups = {{"신체", {"헤어"}}}},
			{label = "얼굴", groups = {{"신체", {"머리", "얼굴"}}}},
			{label = "상의", groups = {{"복장", {"셔츠", "티셔츠", "스웨터", "재킷", "클래식 셔츠", "클래식 티셔츠"}}}},
			{label = "하의", groups = {{"복장", {"바지", "원피스 및 치마", "반바지", "신발", "클래식 바지"}}}},
			{label = "액세서리", groups = {{"액세서리", nil}}},
			{label = "애니메이션", groups = {{"애니메이션", nil}}},
		}
		for _, definition in ipairs(definitions) do
			local entry = {label = definition.label, name = definition.label, assetTypes = {}, bundleTypes = {}}
			if definition.all then
				entry.assetTypes = Config.AllowedAssetTypes
			else
				for _, groupDef in ipairs(definition.groups) do appendGroup(entry, groupDef[1], groupDef[2]) end
			end
			table.insert(entries, entry)
		end
	else
		for _, group in ipairs(Config.CategoryGroups) do
			if group.Name == groupName then
				local entry = {label = "전체", name = group.Name, assetTypes = {}, bundleTypes = {}}
				appendGroup(entry, group.Name, nil)
				table.insert(entries, entry)
				for _, category in ipairs(group.Categories) do table.insert(entries, {label = category.Name, name = category.Name, data = category}) end
			end
		end
	end
	for index, entry in ipairs(entries) do
		local selected = entry.name == currentCategory
		local button = create("TextButton", {
			Name = "Subcategory_" .. tostring(index),
			BackgroundColor3 = selected and Color3.fromRGB(78, 78, 94) or Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = selected and 0 or 0.6,
			TextColor3 = if entry.data and #entry.data.AssetTypes == 0 and not entry.data.BundleTypes then Color3.fromRGB(125,125,135) else (selected and Color3.fromRGB(255,255,255) or Color3.fromRGB(190,190,200)),
			Text = if entry.data and #entry.data.AssetTypes == 0 and not entry.data.BundleTypes then entry.label .. " (준비 중)" else entry.label,
			TextSize = 15, Font = selected and Enum.Font.GothamBold or Enum.Font.Gotham, LayoutOrder = index,
			AutoButtonColor = not (entry.data and #entry.data.AssetTypes == 0 and not entry.data.BundleTypes),
		})
		makeChipAutoWidth(button, 26)
		button.Parent = subcategoryStrip
		create("UICorner", {CornerRadius = UDim.new(0, 6)}).Parent = button
		button.MouseButton1Click:Connect(function()
			print("중분류 카테고리 버튼 클릭:", entry.label)
			if entry.data then selectCategory(entry.data.Name, entry.data.AssetTypes, entry.data.BundleTypes)
			elseif #entry.assetTypes > 0 or #entry.bundleTypes > 0 then selectCategory(entry.name, entry.assetTypes, entry.bundleTypes)
			else showToast("이 카테고리는 Roblox 카탈로그 API로 검색할 수 없어 준비 중입니다.") end
		end)
	end
	subcategoryStrip.CanvasPosition = Vector2.new(keepScrollX, 0)
end
renderSubcategoryStrip(nil)
--------------------------------------------------

-- ★ SORT MENU
--------------------------------------------------

for index, option in ipairs(Config.SortOptions) do
	local button = create("TextButton", {
		Name = "Sort_" .. tostring(index),
		Size = UDim2.new(1, 0, 0, FILTER_ROW),
		BackgroundColor3 = Color3.fromRGB(45, 45, 54),
		Text = option.Name,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		LayoutOrder = index,
		ZIndex = 81,
	})
	button.Parent = sortMenu

	local corner = create("UICorner", {
		CornerRadius = UDim.new(0, 6),
	})
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		currentSort = option.Value
		sortButton.Text = "Sort: " .. option.Name .. " ▼"
		sortMenu.Visible = false
		searchCatalog()
	end)
end

--------------------------------------------------
-- ★ FILTER BUTTONS
--------------------------------------------------

sortButton.MouseButton1Click:Connect(function()
	sortMenu.Visible = not sortMenu.Visible
end)

offSaleButton.MouseButton1Click:Connect(function()
	currentIncludeOffSale = not currentIncludeOffSale
	syncOffSaleLabels()
end)

--------------------------------------------------
-- ★ PAGINATION BUTTONS
--------------------------------------------------

local function loadNextCatalogPage()
	if browseMode ~= "Catalog" and browseMode ~= "Popular" then
		return
	end
	if searchBusy or not catalogPages or catalogPages.IsFinished then
		return
	end
	searchBusy = true
	local generation = resultsFrame:GetAttribute("SearchGeneration")
	local pages = catalogPages
	statusLabel.Text = "Loading more items..."
	local success, err = pcall(function()
		pages:AdvanceToNextPageAsync()
	end)
	if generation ~= resultsFrame:GetAttribute("SearchGeneration") or pages ~= catalogPages then
		-- A new search started meanwhile; drop this page.
		searchBusy = false
		return
	end
	if not success then
		warn("[CatalogController] Next page failed:", err)
		statusLabel.Text = "Could not load more items."
		showToast("아이템을 더 불러오지 못했습니다. 잠시 후 다시 스크롤하세요.")
		searchBusy = false
		return
	end
	currentPageNumber += 1
	local ok, page = pcall(function()
		return catalogPages:GetCurrentPage()
	end)
	if ok and typeof(page) == "table" then
		local count = #resultsFrame:GetChildren()
		for _, item in ipairs(page) do
			if not resultsFrame:FindFirstChild("Item_" .. tostring(item.Id)) then
				createItemCard(item, count + 1)
				count += 1
			end
		end
	end
	statusLabel.Text = ""
	searchBusy = false
end

resultsFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	local remaining = resultsFrame.AbsoluteCanvasSize.Y - resultsFrame.CanvasPosition.Y - resultsFrame.AbsoluteWindowSize.Y
	if remaining < 220 then
		loadNextCatalogPage()
	end
end)

--------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------

local function closeCatalogNow()
	mainFrame.Visible = false
	previewFrame.Visible = false
	sortMenu.Visible = false
	filterPanelOpen = false
	filterPanel.Visible = false
	toastLabel.Visible = false
	require(script.Parent:WaitForChild("Popups")).closed("Catalog")
end

local function closeCatalog()
	if avatarEditor and avatarEditor:isOpen() then
		avatarEditor:requestClose(closeCatalogNow)
		return
	end
	closeCatalogNow()
end

openButton.MouseButton1Click:Connect(function()
	if mainFrame.Visible then
		closeCatalog()
		return
	end
	mainFrame.Visible = true
	-- one popup at a time: another window opening closes the catalog (and the
	-- avatar editor, without asking)
	require(script.Parent:WaitForChild("Popups")).opened("Catalog", function()
		if avatarEditor and avatarEditor:isOpen() then avatarEditor:_close() end
		closeCatalogNow()
	end)
	-- Every open starts from the first screen: minimized, 전체/전체, normal catalog,
	-- no keyword, default sort and filters, scrolled to the top (2026-10-19/20 feedback).
	expandedPanel = false
	browseMode = "Catalog"
	updateDiscoveryHighlight()
	bundleContentsOpen = false
	searchBox.Text = ""
	currentKeyword = ""
	currentSort = Enum.CatalogSortType.Relevance
	minPriceBox.Text = ""
	maxPriceBox.Text = ""
	currentMinPrice = 0
	currentMaxPrice = 0
	currentIncludeOffSale = Config.IncludeOffSale
	syncOffSaleLabels()
	filterPanelOpen = false
	sortMenu.Visible = false
	currentCategory = "전체"
	currentCategoryAssetTypes = Config.AllowedAssetTypes
	currentCategoryBundleTypes = nil
	currentCategoryIncludeOffSale = false
	activeTopLevelGroup = nil
	updateMainCategorySelection()
	renderSubcategoryStrip(nil)
	mainCategoryStrip.CanvasPosition = Vector2.zero
	subcategoryStrip.CanvasPosition = Vector2.zero
	resultsFrame.CanvasPosition = Vector2.zero

	refreshWornItems()
	updateCatalogLayout()
	if expandedPanel then
			previewFrame.Visible = true
		refreshAvatarPreview()
	end
	searchCatalog()
end)

closeButton.MouseButton1Click:Connect(function()
	closeCatalog()
end)

--------------------------------------------------
-- SEARCH EVENTS
--------------------------------------------------

searchButton.MouseButton1Click:Connect(function()
	if browseMode == "Wardrobe" then
		browseMode = "Catalog"
		updateDiscoveryHighlight()
	end
	searchCatalog()
end)

searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		searchCatalog()
	end
end)

minPriceBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		searchCatalog()
	end
end)

maxPriceBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		searchCatalog()
	end
end)

--------------------------------------------------
-- AVATAR EDITOR
--------------------------------------------------

local function setPreviewDescription(description: HumanoidDescription?)
	previewOverride = description
	if previewFrame.Visible then
		refreshAvatarPreview()
	end
end

avatarEditor = AvatarEditor.new({
	mainFrame = mainFrame,
	screenGui = screenGui,
	TryOnItem = TryOnItem,
	setPreviewDescription = setPreviewDescription,
	refreshWornItems = function()
		refreshWornItems()
	end,
	onOpenChanged = function(_open: boolean)
		filterPanelOpen = false
		updateCatalogLayout()
	end,
	previewViewport = avatarViewport,
})

wardrobeView = require(script.Parent:WaitForChild("WardrobeView")).new({
	container = resultsFrame,
	screenGui = screenGui,
	PlayerData = PlayerData,
	TryOnItem = TryOnItem,
	getCardScale = function() return cardContentScale end,
	registerScale = function(uiScale) table.insert(cardContentUIScales, uiScale) end,
	showToast = function(text) showToast(text) end,
	setMessage = function(text) setResultsMessage(text) end,
	isActive = function() return browseMode == "Wardrobe" and mainFrame.Visible end,
	canChangeAvatar = function()
		if actionBusy then
			showToast("다른 아바타 변경이 진행 중입니다.")
			return false
		end
		return not editorBlocksAvatarChanges()
	end,
	setBusy = function(busy) actionBusy = busy end,
	editorDirty = function() return avatarEditor ~= nil and avatarEditor:isDirty() end,
	onRestored = function()
		refreshWornItems()
		refreshAvatarPreview()
	end,
})

-- ▣ always opens the Wardrobe (it does not toggle back like the discovery strip).
wardrobeButton.MouseButton1Click:Connect(function()
	if avatarEditor and avatarEditor:isOpen() then
		avatarEditor:requestClose(function()
			browseMode = "Wardrobe"
			updateDiscoveryHighlight()
			searchCatalog()
		end)
		return
	end
	browseMode = "Wardrobe"
	updateDiscoveryHighlight()
	searchCatalog()
end)

-- ⚙ (preview box or minimized strip) opens the maximized catalog in edit mode (D-022).
openAvatarEditor = function()
	if not mainFrame.Visible then return end
	-- ⚙ toggles: pressing it again closes the editor (asking first if there are
	-- un-applied changes) and the catalog view comes back (2026-10-20 feedback).
	if avatarEditor:isOpen() then
		avatarEditor:requestClose(function()
			updateCatalogLayout()
			refreshAvatarPreview()
		end)
		return
	end
	if not expandedPanel then
		expandedPanel = true
		previewManuallyClosed = false
	end
	updateCatalogLayout()
	avatarEditor:open()
	updateCatalogLayout()
	refreshAvatarPreview()
end

task.spawn(loadFavorites)

--------------------------------------------------
-- INITIALIZE
--------------------------------------------------

print("[FashionGame] CatalogController initialized.")

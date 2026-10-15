--!strict

local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local TryOnItem = Remotes:WaitForChild("TryOnItem")

local Config = require(
	FashionGame:WaitForChild("Shared"):WaitForChild("CatalogConfig")
)

local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- STATE
--------------------------------------------------

local currentCategory = "All"
local currentCategoryAssetTypes = Config.AllowedAssetTypes
local currentCategoryBundleTypes = nil
local currentCategoryIncludeOffSale = Config.IncludeOffSale
local currentKeyword = ""

local currentSort = Enum.CatalogSortType.Relevance
local currentMinPrice = 0
local currentMaxPrice = 0
local currentIncludeOffSale = Config.IncludeOffSale

local currentWornItems: {[number]: boolean} = {}

-- Live card button refreshers keyed by asset ID.
local wornButtonUpdaters: {[number]: () -> ()} = {}

local searchBusy = false
local actionBusy = false
local bundleContentsOpen = false
local showBundleContents
local renderCurrentPage: () -> ()

local catalogPages: Pages? = nil
local currentPageNumber = 1

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
})

screenGui.Parent = playerGui

--------------------------------------------------
-- OPEN BUTTON
--------------------------------------------------

local openButton = create("TextButton", {
	Name = "CatalogButton",
	Size = UDim2.fromOffset(130, 44),
	Position = UDim2.new(0, 24, 1, -68),
	BackgroundColor3 = Color3.fromRGB(35, 35, 42),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Text = "CATALOG",
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = true,
})

openButton.Parent = screenGui

local openCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 10),
})
openCorner.Parent = openButton

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
	BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	Visible = false,
})
previewFrame.Parent = previewGui
create("UICorner", { CornerRadius = UDim.new(0, 12) }).Parent = previewFrame

local previewTitle = create("TextLabel", {
	Name = "PreviewTitle",
	Size = UDim2.new(1, -44, 0, 32),
	Position = UDim2.fromOffset(10, 4),
	BackgroundTransparency = 1,
	Text = "CURRENT OUTFIT",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
})
previewTitle.Parent = previewFrame

local previewCloseButton = create("TextButton", {
	Name = "PreviewCloseButton",
	Size = UDim2.fromOffset(28, 28),
	Position = UDim2.new(1, -34, 0, 5),
	BackgroundColor3 = Color3.fromRGB(55, 55, 65),
	Text = "×",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 20,
	Font = Enum.Font.GothamBold,
})
previewCloseButton.Parent = previewFrame
create("UICorner", { CornerRadius = UDim.new(0, 7) }).Parent = previewCloseButton

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

local avatarPreviewWorld = Instance.new("WorldModel")
avatarPreviewWorld.Parent = avatarViewport

local avatarPreviewCamera = Instance.new("Camera")
avatarPreviewCamera.FieldOfView = 35
avatarPreviewCamera.Parent = avatarViewport
avatarViewport.CurrentCamera = avatarPreviewCamera

local function refreshAvatarPreview()
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
	local _, bounds = clone:GetBoundingBox()
	local targetY = bounds.Y * 0.5
	local distance = math.max(4.5, bounds.Y * 1.45)
	avatarPreviewCamera.CFrame = CFrame.lookAt(
		Vector3.new(0, targetY, distance),
		Vector3.new(0, targetY, 0)
	)
end

previewCloseButton.MouseButton1Click:Connect(function()
	previewManuallyClosed = true
	previewFrame.Visible = false
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
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
	BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	Visible = false,
})

mainFrame.Parent = screenGui

local mainCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 14),
})
mainCorner.Parent = mainFrame

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

local closeCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
closeCorner.Parent = closeButton

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

local searchCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
searchCorner.Parent = searchBox

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

local searchButtonCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
searchButtonCorner.Parent = searchButton

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

local categoryButton = create("TextButton", {
	Name = "CategoryButton",
	Size = UDim2.fromOffset(220, 34),
	Position = UDim2.fromOffset(80, 116),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	Text = "All ▼",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
})
categoryButton.Parent = mainFrame

local categoryButtonPadding = create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
})
categoryButtonPadding.Parent = categoryButton

local categoryCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
categoryCorner.Parent = categoryButton

local categoryMenu = create("ScrollingFrame", {
	Name = "CategoryMenu",
	Size = UDim2.fromOffset(220, 360),
	Position = UDim2.fromOffset(80, 152),
	BackgroundColor3 = Color3.fromRGB(34, 34, 42),
	BorderSizePixel = 0,
	Visible = false,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ZIndex = 50,
})
categoryMenu.Parent = mainFrame

local categoryMenuCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
categoryMenuCorner.Parent = categoryMenu

local categoryMenuLayout = create("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
categoryMenuLayout.Parent = categoryMenu

local categoryMenuPadding = create("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 6),
})
categoryMenuPadding.Parent = categoryMenu

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

local sortButtonPadding = create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
})
sortButtonPadding.Parent = sortButton

local sortCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
sortCorner.Parent = sortButton

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

local sortMenuCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
sortMenuCorner.Parent = sortMenu

local sortMenuLayout = create("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
sortMenuLayout.Parent = sortMenu

local sortMenuPadding = create("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 6),
})
sortMenuPadding.Parent = sortMenu

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

local minPriceCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
minPriceCorner.Parent = minPriceBox

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

local maxPriceCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
maxPriceCorner.Parent = maxPriceBox

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

local offSaleCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
offSaleCorner.Parent = offSaleButton

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

local statusLabel = create("TextLabel", {
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
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 6,
})
resultsFrame.Parent = mainFrame

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
	Text = "NEXT →",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
})
nextButton.Parent = mainFrame

local nextCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 8),
})
nextCorner.Parent = nextButton

--------------------------------------------------
-- RESPONSIVE CATALOG LAYOUT
--------------------------------------------------

local expandedPanel = false
local cardContentScale = 1
local cardContentUIScales: {UIScale} = {}

local function updateCatalogLayout()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local isNarrow = viewport.X < 900
	local panelWidth: number
	local panelHeight: number
	local expandedMobilePreviewHeight = math.min(190, math.floor(viewport.Y * 0.27))

	-- Expanded mode is full-screen on both PC and mobile.
	if expandedPanel then
		panelWidth, panelHeight = viewport.X, viewport.Y
		mainFrame.Position = UDim2.fromOffset(0, 0)
		mainFrame.Size = UDim2.fromOffset(panelWidth, panelHeight)
		mainCorner.CornerRadius = UDim.new(0, 0)
	elseif isNarrow then
		panelWidth = math.min(math.max(190, math.floor(viewport.X * 0.5)), viewport.X - 12)
		panelHeight = math.min(math.max(260, math.floor(viewport.Y * 0.5)), viewport.Y - 12)
		mainFrame.Position = UDim2.new(1, -panelWidth - 6, 1, -panelHeight - 6)
		mainFrame.Size = UDim2.fromOffset(panelWidth, panelHeight)
		mainCorner.CornerRadius = UDim.new(0, 14)
	else
		local maxWidth = math.min(760, viewport.X - 32)
		local oldDefaultWidth = math.clamp(math.floor(viewport.X * 0.34), math.min(420, maxWidth), maxWidth)
		panelWidth = math.clamp(math.floor(oldDefaultWidth * (2 / 3)), math.min(280, maxWidth), maxWidth)
		panelHeight = math.clamp(math.floor(viewport.Y * (2 / 3)), math.min(280, viewport.Y - 16), viewport.Y - 16)
		mainFrame.Position = UDim2.new(1, -panelWidth - 16, 0.5, -math.floor(panelHeight / 2))
		mainFrame.Size = UDim2.fromOffset(panelWidth, panelHeight)
		mainCorner.CornerRadius = UDim.new(0, 14)
	end

	expandButton.Visible = true
	local compact = not expandedPanel
	local compactMobile = isNarrow and compact
	local expandedMobile = isNarrow and expandedPanel
	local innerWidth = math.max(1, panelWidth - 24)

	titleLabel.Position = UDim2.fromOffset(12, 5)
	titleLabel.Size = UDim2.new(1, -120, 0, 34)
	titleLabel.TextSize = if compact then 16 else 22
	closeButton.Position = UDim2.new(1, -42, 0, 6)
	closeButton.Size = UDim2.fromOffset(32, 32)
	expandButton.Position = UDim2.new(1, -80, 0, 6)
	expandButton.Size = UDim2.fromOffset(32, 32)
	expandButton.Text = if expandedPanel then "↙" else "↗"

	if compact then
		-- Keep search, category (ALL), and sort on one toolbar row.
		-- Hide status/secondary filters to give result cards usable height.
		searchBox.Position = UDim2.fromOffset(8, 44)
		searchBox.Size = UDim2.new(0.46, -8, 0, 32)
		searchBox.TextSize = 12
		searchBox.PlaceholderText = "Search..."
		searchButton.Visible = false
		categoryButton.Position = UDim2.new(0.46, 4, 0, 44)
		categoryButton.Size = UDim2.new(0.27, -4, 0, 32)
		categoryButton.TextSize = 10
		sortButton.Position = UDim2.new(0.73, 0, 0, 44)
		sortButton.Size = UDim2.new(0.27, -8, 0, 32)
		sortButton.TextSize = 10

		minPriceBox.Visible = false
		maxPriceBox.Visible = false
		offSaleButton.Visible = false
		filterLabel.Visible = false
		backToPacksButton.Visible = bundleContentsOpen
		backToPacksButton.Position = UDim2.fromOffset(8, 80)
		backToPacksButton.Size = UDim2.fromOffset(math.min(130, innerWidth * 0.42), 22)
		backToPacksButton.TextSize = 9
		statusLabel.Visible = false

		-- Results start directly below the toolbar. This prevents the compact
		-- panel from clipping the first row of cards behind status controls.
		resultsFrame.Position = UDim2.fromOffset(8, 82)
		resultsFrame.Size = UDim2.new(1, -16, 1, -122)
	else
		backToPacksButton.Visible = bundleContentsOpen
		statusLabel.Visible = true

		if expandedMobile then
			-- Expanded mobile: controls first, avatar preview next, cards below.
			searchBox.Position = UDim2.fromOffset(8, 44)
			searchBox.Size = UDim2.new(0.60, -8, 0, 34)
			searchBox.TextSize = 12
			searchBox.PlaceholderText = "Search Roblox catalog..."
			searchButton.Visible = true
			searchButton.Position = UDim2.new(0.60, 0, 0, 44)
			searchButton.Size = UDim2.new(0.16, -4, 0, 34)
			searchButton.TextSize = 10

			categoryButton.Position = UDim2.new(0, 8, 0, 84)
			categoryButton.Size = UDim2.new(0.48, -8, 0, 32)
			categoryButton.TextSize = 11
			sortButton.Position = UDim2.new(0.52, 0, 0, 84)
			sortButton.Size = UDim2.new(0.48, -8, 0, 32)
			sortButton.TextSize = 11
			filterLabel.Visible = false

			local priceY = 122
			local priceWidth = math.clamp(math.floor(innerWidth * 0.22), 56, 92)
			minPriceBox.Position = UDim2.fromOffset(8, priceY)
			minPriceBox.Size = UDim2.fromOffset(priceWidth, 30)
			maxPriceBox.Position = UDim2.fromOffset(14 + priceWidth, priceY)
			maxPriceBox.Size = UDim2.fromOffset(priceWidth, 30)
			offSaleButton.Position = UDim2.fromOffset(20 + priceWidth * 2, priceY)
			offSaleButton.Size = UDim2.new(1, -(32 + priceWidth * 2), 0, 30)
			minPriceBox.Visible = true
			maxPriceBox.Visible = true
			offSaleButton.Visible = true

			backToPacksButton.Position = UDim2.fromOffset(8, 160)
			backToPacksButton.Size = UDim2.fromOffset(math.min(130, innerWidth * 0.35), 24)
			backToPacksButton.TextSize = 9
			statusLabel.Position = UDim2.new(0, math.min(144, innerWidth * 0.40), 0, 160)
			statusLabel.Size = UDim2.new(1, -math.min(152, innerWidth * 0.40 + 8), 0, 24)
			statusLabel.TextSize = 10

			previewFrame.Size = UDim2.new(0.46, 0, 0, expandedMobilePreviewHeight)
			previewFrame.Position = UDim2.fromOffset(8, 192)
			local resultsY = 200 + expandedMobilePreviewHeight
			resultsFrame.Position = UDim2.fromOffset(8, resultsY)
			resultsFrame.Size = UDim2.new(1, -16, 1, -(resultsY + 42))
		else
			searchBox.Position = UDim2.fromOffset(12, 48)
			searchBox.Size = UDim2.new(0.48, -12, 0, 36)
			searchBox.TextSize = 14
			searchBox.PlaceholderText = "Search Roblox catalog..."
			searchButton.Visible = true
			searchButton.Position = UDim2.new(0.48, 4, 0, 48)
			searchButton.Size = UDim2.new(0.12, -4, 0, 36)
			searchButton.TextSize = 11
			categoryButton.Position = UDim2.new(0.60, 4, 0, 48)
			categoryButton.Size = UDim2.new(0.20, -4, 0, 36)
			categoryButton.TextSize = 11
			sortButton.Position = UDim2.new(0.80, 0, 0, 48)
			sortButton.Size = UDim2.new(0.20, -12, 0, 36)
			sortButton.TextSize = 11
			filterLabel.Visible = false

			local priceY = 92
			local priceWidth = math.clamp(math.floor(innerWidth * 0.22), 60, 100)
			minPriceBox.Position = UDim2.fromOffset(12, priceY)
			minPriceBox.Size = UDim2.fromOffset(priceWidth, 30)
			maxPriceBox.Position = UDim2.fromOffset(18 + priceWidth, priceY)
			maxPriceBox.Size = UDim2.fromOffset(priceWidth, 30)
			offSaleButton.Position = UDim2.fromOffset(24 + priceWidth * 2, priceY)
			offSaleButton.Size = UDim2.new(1, -(36 + priceWidth * 2), 0, 30)
			minPriceBox.Visible = true
			maxPriceBox.Visible = true
			offSaleButton.Visible = true
			backToPacksButton.Position = UDim2.fromOffset(12, 130)
			backToPacksButton.Size = UDim2.fromOffset(math.min(145, innerWidth * 0.3), 26)
			backToPacksButton.TextSize = 10
			statusLabel.Position = UDim2.new(0, math.min(165, innerWidth * 0.34), 0, 130)
			statusLabel.Size = UDim2.new(1, -math.min(177, innerWidth * 0.34 + 12), 0, 26)
			statusLabel.TextSize = 12

			resultsFrame.Position = UDim2.fromOffset(if expandedPanel then 288 else 12, 164)
			resultsFrame.Size = UDim2.new(1, if expandedPanel then -300 else -24, 1, -214)
			previewFrame.Size = UDim2.fromOffset(260, math.min(360, math.max(280, math.floor(viewport.Y * 0.55))))
			previewFrame.Position = UDim2.fromOffset(16, 164)
		end
	end

	categoryMenu.Position = UDim2.new(categoryButton.Position.X.Scale, categoryButton.Position.X.Offset, 0, categoryButton.Position.Y.Offset + categoryButton.Size.Y.Offset + 4)
	categoryMenu.Size = UDim2.new(categoryButton.Size.X.Scale, categoryButton.Size.X.Offset, 0, math.max(100, math.min(360, panelHeight - 150)))
	sortMenu.Position = UDim2.new(sortButton.Position.X.Scale, sortButton.Position.X.Offset, 0, sortButton.Position.Y.Offset + sortButton.Size.Y.Offset + 4)
	sortMenu.Size = UDim2.new(sortButton.Size.X.Scale, sortButton.Size.X.Offset, 0, math.max(100, math.min(220, panelHeight - 150)))

	-- Card dimensions are intentionally different for compact PC/mobile and expanded views.
	if compactMobile then
		grid.CellSize = UDim2.fromOffset(76, 114)
		cardContentScale = 0.68
	elseif compact then
		grid.CellSize = UDim2.fromOffset(100, 146)
		cardContentScale = 0.82
	elseif expandedMobile then
		grid.CellSize = UDim2.fromOffset(112, 164)
		cardContentScale = 0.86
	else
		grid.CellSize = UDim2.fromOffset(132, 192)
		cardContentScale = 1
	end
	grid.CellPadding = UDim2.fromOffset(6, 6)
	for _, contentScale in ipairs(cardContentUIScales) do
		contentScale.Scale = cardContentScale
	end

	previewFrame.Visible = expandedPanel and mainFrame.Visible and not previewManuallyClosed
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

local function refreshWornItems()
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

	for _, item in ipairs(result) do
		if typeof(item) == "table" then
			local assetId = item.AssetId

			if typeof(assetId) == "number" then
				currentWornItems[assetId] = true
			end
		end
	end


	for _, updateButton in pairs(wornButtonUpdaters) do
		updateButton()
	end

	if previewFrame.Visible then
		refreshAvatarPreview()
	end
end

--------------------------------------------------
-- CARD
--------------------------------------------------

local function createItemCard(item: any, layoutOrder: number)
	local assetId = item.Id

	if typeof(assetId) ~= "number" then
		return
	end

	local isBundle = item.ItemType == "Bundle"
	local assetTypeName = if isBundle then (item.BundleType or "Bundle") else getAssetTypeName(item)
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
		Size = UDim2.new(1, 0, 1, 0),
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
		Size = UDim2.new(1, -10, 0, 92),
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

	local thumbnailCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 6),
	})
	thumbnailCorner.Parent = thumbnail

	local nameLabel = create("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -12, 0, 26),
		Position = UDim2.fromOffset(6, 100),
		BackgroundTransparency = 1,
		Text = tostring(item.Name or "Unknown Item"),
		TextColor3 = Color3.fromRGB(245, 245, 245),
		TextSize = 10,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	nameLabel.Parent = cardContent

	local typeLabel = create("TextLabel", {
		Name = "AssetType",
		Size = UDim2.new(1, -12, 0, 14),
		Position = UDim2.fromOffset(6, 126),
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
		Position = UDim2.fromOffset(6, 142),
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

	actionButton.MouseButton1Click:Connect(function()
		if actionBusy then
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

		if currentWornItems[assetId] then
			statusLabel.Text = "Removing..."

			local success, result, message = pcall(function()
				return TryOnItem:InvokeServer("Remove", assetId)
			end)

			if success and result == true then
				currentWornItems[assetId] = nil
				updateButton()
				task.wait(0.15)
				refreshWornItems()
				refreshAvatarPreview()
				statusLabel.Text = "Item removed."
			else
				warn("[CatalogController] Remove failed:", result, message)
				statusLabel.Text =
					typeof(message) == "string"
					and message
					or "Failed to remove item."
			end
		else
			statusLabel.Text = "Wearing..."

			local success, result, message = pcall(function()
				return TryOnItem:InvokeServer("Wear", assetId)
			end)

			if success and result == true then
				task.wait(0.2)
				refreshWornItems()
				refreshAvatarPreview()
				updateButton()
				statusLabel.Text = "Item equipped."
			else
				warn("[CatalogController] Wear failed:", result, message)
				statusLabel.Text =
					typeof(message) == "string"
					and message
					or "Failed to equip item."
			end
		end

		actionBusy = false
	end)
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

	pageLabel.Text = "Page " .. tostring(currentPageNumber)
		.. "  •  "
		.. tostring(resultCount)

	local finished = catalogPages.IsFinished

	nextButton.Active = not finished
	nextButton.AutoButtonColor = not finished

	if finished then
		nextButton.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	else
		nextButton.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	end

end

--------------------------------------------------
-- ★ SEARCH
--------------------------------------------------

local function searchCatalog()
	if searchBusy then
		return
	end

	searchBusy = true

	categoryMenu.Visible = false
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
	params.SortType = currentSort
	params.SortAggregation = Config.SortAggregation
	params.MinPrice = currentMinPrice
	params.IncludeOffSale = currentIncludeOffSale
	params.CategoryFilter = Config.CategoryFilter
	params.SalesTypeFilter = Config.SalesTypeFilter
	params.CreatorType = Config.CreatorType

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
	params.IncludeOffSale = currentCategoryIncludeOffSale

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

	if not success then
		warn("[CatalogController] Search failed:", pages)
		statusLabel.Text = "Search failed. Check Output."
		searchBusy = false
		return
	end

	local currentPage = pages:GetCurrentPage()

	-- Keep each category truthful: an individual animation category must not
	-- silently display Animation Pack bundles as if they were individual assets.
	catalogPages = pages
	currentPageNumber = 1
	renderCurrentPage()
	statusLabel.Text = tostring(#currentPage) .. " items loaded."

	searchBusy = false
end

-- ★ CATEGORY MENU
--------------------------------------------------

local categoryButtons: {[string]: TextButton} = {}
local expandedGroups: {[string]: boolean} = {}

local function selectCategory(name: string, assetTypes, bundleTypes)
	if (not assetTypes or #assetTypes == 0) and (not bundleTypes or #bundleTypes == 0) then
		statusLabel.Text = "이 카테고리는 현재 Roblox API에서 직접 검색할 수 없습니다."
		return
	end

	currentCategory = name
	currentCategoryAssetTypes = assetTypes
	currentCategoryBundleTypes = bundleTypes
	currentCategoryIncludeOffSale = false
	for _, group in ipairs(Config.CategoryGroups) do
		for _, category in ipairs(group.Categories) do
			if category.Name == name and category.IncludeOffSale == true then
				currentCategoryIncludeOffSale = true
			end
		end
	end
	categoryButton.Text = name .. " ▼"
	categoryMenu.Visible = false
	searchCatalog()
end

local allButton = create("TextButton", {
	Name = "AllButton",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Color3.fromRGB(65, 65, 78),
	Text = "전체",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 0,
	ZIndex = 51,
})
allButton.Parent = categoryMenu

local allPadding = create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
})
allPadding.Parent = allButton

local allCorner = create("UICorner", {
	CornerRadius = UDim.new(0, 6),
})
allCorner.Parent = allButton

allButton.MouseButton1Click:Connect(function()
	selectCategory("전체", Config.AllowedAssetTypes, nil)
end)

for groupIndex, group in ipairs(Config.CategoryGroups) do
	local groupButton = create("TextButton", {
		Name = "Group_" .. tostring(groupIndex),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(43, 43, 52),
		Text = "＋ " .. group.Name,
		TextColor3 = Color3.fromRGB(235, 235, 240),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = groupIndex * 100,
		ZIndex = 51,
	})
	groupButton.Parent = categoryMenu

	local groupPadding = create("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
	})
	groupPadding.Parent = groupButton

	local groupCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 6),
	})
	groupCorner.Parent = groupButton

	local subButtons = {}

	for subIndex, category in ipairs(group.Categories) do
		local subButton = create("TextButton", {
			Name = "Category_" .. tostring(groupIndex) .. "_" .. tostring(subIndex),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Color3.fromRGB(50, 50, 60),
			Text = "   " .. category.Name,
			TextColor3 = Color3.fromRGB(215, 215, 225),
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = groupIndex * 100 + subIndex,
			Visible = false,
			ZIndex = 51,
			AutoButtonColor = (#category.AssetTypes > 0) or (category.BundleTypes and #category.BundleTypes > 0),
		})
		subButton.Parent = categoryMenu

		local subPadding = create("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
		})
		subPadding.Parent = subButton

		local subCorner = create("UICorner", {
			CornerRadius = UDim.new(0, 6),
		})
		subCorner.Parent = subButton

		local hasAssetTypes = #category.AssetTypes > 0
		local hasBundleTypes = category.BundleTypes and #category.BundleTypes > 0

		if not hasAssetTypes and not hasBundleTypes then
			subButton.Text = "   " .. category.Name .. "  (준비 중)"
			subButton.TextColor3 = Color3.fromRGB(120, 120, 130)
		end

		subButton.MouseButton1Click:Connect(function()
			selectCategory(category.Name, category.AssetTypes, category.BundleTypes)
		end)

		table.insert(subButtons, subButton)
	end

	groupButton.MouseButton1Click:Connect(function()
		expandedGroups[group.Name] = not expandedGroups[group.Name]
		local expanded = expandedGroups[group.Name]

		groupButton.Text = (expanded and "− " or "＋ ") .. group.Name

		for _, subButton in ipairs(subButtons) do
			subButton.Visible = expanded
		end
	end)
end

--------------------------------------------------

-- ★ SORT MENU
--------------------------------------------------

for index, option in ipairs(Config.SortOptions) do
	local button = create("TextButton", {
		Name = "Sort_" .. tostring(index),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(50, 50, 60),
		Text = option.Name,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		LayoutOrder = index,
		ZIndex = 51,
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

categoryButton.MouseButton1Click:Connect(function()
	sortMenu.Visible = false
	categoryMenu.Visible = not categoryMenu.Visible
end)

sortButton.MouseButton1Click:Connect(function()
	categoryMenu.Visible = false
	sortMenu.Visible = not sortMenu.Visible
end)

offSaleButton.MouseButton1Click:Connect(function()
	currentIncludeOffSale = not currentIncludeOffSale

	if currentIncludeOffSale then
		offSaleButton.Text = "☑ Off Sale"
		offSaleButton.BackgroundColor3 = Color3.fromRGB(105, 85, 160)
	else
		offSaleButton.Text = "□ Off Sale"
		offSaleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	end

	searchCatalog()
end)

--------------------------------------------------
-- ★ PAGINATION BUTTONS
--------------------------------------------------

nextButton.MouseButton1Click:Connect(function()
	if searchBusy or not catalogPages or catalogPages.IsFinished then
		return
	end

	searchBusy = true
	statusLabel.Text = "Loading next page..."

	local success, err = pcall(function()
		catalogPages:AdvanceToNextPageAsync()
	end)

	if not success then
		warn("[CatalogController] Next page failed:", err)
		statusLabel.Text = "Failed to load next page."
		searchBusy = false
		return
	end

	currentPageNumber += 1
	renderCurrentPage()
	statusLabel.Text = "Page " .. tostring(currentPageNumber)

	searchBusy = false
end)

--------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------

openButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = true

	refreshWornItems()
	updateCatalogLayout()
	if expandedPanel then
		previewManuallyClosed = false
		previewFrame.Visible = true
		refreshAvatarPreview()
	end
	searchCatalog()
end)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	previewFrame.Visible = false
	categoryMenu.Visible = false
	sortMenu.Visible = false
end)

--------------------------------------------------
-- SEARCH EVENTS
--------------------------------------------------

searchButton.MouseButton1Click:Connect(function()
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
-- INITIALIZE
--------------------------------------------------

print("[FashionGame] CatalogController initialized.")

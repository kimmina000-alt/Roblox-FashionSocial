--!strict

local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
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
local currentKeyword = ""

local currentSort = Enum.CatalogSortType.Relevance
local currentMinPrice = 0
local currentMaxPrice = 0
local currentIncludeOffSale = Config.IncludeOffSale

local currentWornItems: {[number]: boolean} = {}

local searchBusy = false
local actionBusy = false

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
-- MAIN FRAME
--------------------------------------------------

local mainFrame = create("Frame", {
	Name = "MainFrame",
	Size = UDim2.new(0, 900, 0, 680),
	Position = UDim2.new(0.5, -450, 0.5, -340),
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

local statusLabel = create("TextLabel", {
	Name = "Status",
	Size = UDim2.new(1, -40, 0, 30),
	Position = UDim2.fromOffset(20, 160),
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
-- CATEGORY LOOKUP
--------------------------------------------------

local function getCategoryAssetTypes()
	for _, category in ipairs(Config.Categories) do
		if category.Name == currentCategory then
			return category.AssetTypes
		end
	end

	return Config.AllowedAssetTypes
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
end

--------------------------------------------------
-- CARD
--------------------------------------------------

local function createItemCard(item: any, layoutOrder: number)
	local assetId = item.Id

	if typeof(assetId) ~= "number" then
		return
	end

	local assetTypeName = getAssetTypeName(item)
	local canTryOn = TRY_ON_SUPPORTED_ASSET_TYPES[assetTypeName] == true

	local card = create("Frame", {
		Name = "Item_" .. tostring(assetId),
		BackgroundColor3 = Color3.fromRGB(36, 36, 44),
		LayoutOrder = layoutOrder,
	})
	card.Parent = resultsFrame

	local cardCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 10),
	})
	cardCorner.Parent = card

	local thumbnail = create("ImageLabel", {
		Name = "Thumbnail",
		Size = UDim2.new(1, -12, 0, 140),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.fromRGB(28, 28, 34),
		BorderSizePixel = 0,
		Image = "rbxthumb://type=Asset&id="
			.. tostring(assetId)
			.. "&w=420&h=420",
		ScaleType = Enum.ScaleType.Fit,
	})
	thumbnail.Parent = card

	local thumbnailCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 8),
	})
	thumbnailCorner.Parent = thumbnail

	local nameLabel = create("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 150),
		BackgroundTransparency = 1,
		Text = tostring(item.Name or "Unknown Item"),
		TextColor3 = Color3.fromRGB(245, 245, 245),
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	nameLabel.Parent = card

	local typeLabel = create("TextLabel", {
		Name = "AssetType",
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 180),
		BackgroundTransparency = 1,
		Text = assetTypeName,
		TextColor3 = Color3.fromRGB(145, 145, 160),
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	typeLabel.Parent = card

	local priceLabel = create("TextLabel", {
		Name = "Price",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 198),
		BackgroundTransparency = 1,
		Text = formatPrice(item.Price),
		TextColor3 = Color3.fromRGB(190, 190, 200),
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	priceLabel.Parent = card

	local actionButton = create("TextButton", {
		Name = "ActionButton",
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.new(0, 8, 1, -36),
		BackgroundColor3 = Color3.fromRGB(70, 70, 85),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = canTryOn,
	})
	actionButton.Parent = card

	local actionCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 7),
	})
	actionCorner.Parent = actionButton

	local function updateButton()
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

	actionButton.MouseButton1Click:Connect(function()
		if not canTryOn or actionBusy then
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
-- ★ RENDER CURRENT PAGE
--------------------------------------------------

local function renderCurrentPage()
	if not catalogPages then
		return
	end

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

	for index, item in ipairs(currentPage) do
		createItemCard(item, index)
		resultCount += 1
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

	if currentPageNumber <= 1 then
		previousButton.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	else
		previousButton.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
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

	if assetTypes then
		params.AssetTypes = assetTypes
	end

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

	catalogPages = pages
	currentPageNumber = 1

	renderCurrentPage()

	local currentPage = pages:GetCurrentPage()

	statusLabel.Text =
		tostring(#currentPage)
		.. " items loaded."

	searchBusy = false
end

--------------------------------------------------
-- ★ CATEGORY MENU
--------------------------------------------------

local categoryButtons: {[string]: TextButton} = {}

for index, category in ipairs(Config.Categories) do
	local button = create("TextButton", {
		Name = category.Name .. "Button",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(50, 50, 60),
		Text = category.Name,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = index,
		ZIndex = 51,
	})
	button.Parent = categoryMenu

	local padding = create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
	})
	padding.Parent = button

	local corner = create("UICorner", {
		CornerRadius = UDim.new(0, 6),
	})
	corner.Parent = button

	categoryButtons[category.Name] = button

	button.MouseButton1Click:Connect(function()
		currentCategory = category.Name
		categoryButton.Text = category.Name .. " ▼"
		categoryMenu.Visible = false
		searchCatalog()
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
	searchCatalog()
end)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
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

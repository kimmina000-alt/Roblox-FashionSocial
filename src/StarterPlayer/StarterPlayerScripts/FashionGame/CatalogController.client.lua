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
local currentAnimationCategory = "Idle"
local currentKeyword = ""

local currentWornItems: {[number]: boolean} = {}

local searchBusy = false
local searchQueued = false
local actionBusy = false
local currentPages: any = nil
local currentPageNumber = 1
local currentSortIndex = 1

local SORT_OPTIONS = {
	{ Name = "Relevance", Value = Enum.CatalogSortType.Relevance },
	{ Name = "Popular", Value = Enum.CatalogSortType.Bestselling },
	{ Name = "Favorites", Value = Enum.CatalogSortType.MostFavorited },
	{ Name = "Newest", Value = Enum.CatalogSortType.RecentlyCreated },
	{ Name = "Price Low", Value = Enum.CatalogSortType.PriceLowToHigh },
	{ Name = "Price High", Value = Enum.CatalogSortType.PriceHighToLow },
}

--------------------------------------------------
-- CATEGORY CONFIG
--------------------------------------------------

local CATEGORIES = Config.Categories

local CATEGORY_LABELS = {
	All = "All",
	Body = "Body",
	Hair = "Hair",
	Face = "Face",
	Makeup = "Makeup",
	EyesBrows = "Eyes & Brows",
	Clothing = "Clothing",
	Shoes = "Shoes",
	Accessories = "Accessories",
	Animations = "Animations",
	Other = "Other",
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
		child:Destroy()
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

	Size = UDim2.new(0, 760, 0, 620),
	Position = UDim2.new(0.5, -380, 0.5, -310),

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
-- SORT / PAGINATION
--------------------------------------------------

local sortButton = create("TextButton", {
	Name = "SortButton",
	Size = UDim2.fromOffset(120, 34),
	Position = UDim2.new(1, -140, 0, 116),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	Text = "Sort: Relevance",
})
sortButton.Parent = mainFrame

local sortCorner = create("UICorner", { CornerRadius = UDim.new(0, 8) })
sortCorner.Parent = sortButton

local previousPageButton = create("TextButton", {
	Name = "PreviousPageButton",
	Size = UDim2.fromOffset(80, 30),
	Position = UDim2.new(0, 20, 1, -38),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	Text = "PREV",
})
previousPageButton.Parent = mainFrame
local prevCorner = create("UICorner", { CornerRadius = UDim.new(0, 7) })
prevCorner.Parent = previousPageButton

local nextPageButton = create("TextButton", {
	Name = "NextPageButton",
	Size = UDim2.fromOffset(80, 30),
	Position = UDim2.new(1, -100, 1, -38),
	BackgroundColor3 = Color3.fromRGB(50, 50, 60),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	Text = "NEXT",
})
nextPageButton.Parent = mainFrame
local nextCorner = create("UICorner", { CornerRadius = UDim.new(0, 7) })
nextCorner.Parent = nextPageButton

local pageLabel = create("TextLabel", {
	Name = "PageLabel",
	Size = UDim2.fromOffset(120, 30),
	Position = UDim2.new(0.5, -60, 1, -38),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(170, 170, 180),
	TextSize = 11,
	Font = Enum.Font.Gotham,
	Text = "Page 1",
})
pageLabel.Parent = mainFrame

--------------------------------------------------
-- CATEGORY BAR
--------------------------------------------------

local categoryBar = create("ScrollingFrame", {
	Name = "CategoryBar",

	Size = UDim2.new(1, -40, 0, 42),
	Position = UDim2.fromOffset(20, 116),

	BackgroundTransparency = 1,

	CanvasSize = UDim2.new(0, 0, 0, 0),

	AutomaticCanvasSize = Enum.AutomaticSize.X,

	ScrollingDirection = Enum.ScrollingDirection.X,

	ScrollBarThickness = 0,
})

categoryBar.Parent = mainFrame

local categoryLayout = create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,

	Padding = UDim.new(0, 8),

	VerticalAlignment = Enum.VerticalAlignment.Center,
})

categoryLayout.Parent = categoryBar

--------------------------------------------------
-- STATUS
--------------------------------------------------

local statusLabel = create("TextLabel", {
	Name = "Status",

	Size = UDim2.new(1, -40, 0, 30),
	Position = UDim2.fromOffset(20, 194),

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

	Size = UDim2.new(1, -40, 1, -281),
	Position = UDim2.fromOffset(20, 226),

	BackgroundTransparency = 1,

	BorderSizePixel = 0,

	CanvasSize = UDim2.new(0, 0, 0, 0),

	AutomaticCanvasSize = Enum.AutomaticSize.Y,

	ScrollingDirection = Enum.ScrollingDirection.Y,

	ScrollBarThickness = 6,
})

resultsFrame.Parent = mainFrame

local grid = create("UIGridLayout", {
	CellSize = UDim2.fromOffset(165, 230),

	CellPadding = UDim2.fromOffset(10, 10),

	SortOrder = Enum.SortOrder.LayoutOrder,
})

grid.Parent = resultsFrame

--------------------------------------------------
-- CATEGORY BUTTONS
--------------------------------------------------

local categoryButtons: {[string]: TextButton} = {}
local animationCategoryBar: ScrollingFrame? = nil
local animationCategoryButtons: {[string]: TextButton} = {}

local function updateCategoryVisuals()
	for name, button in pairs(categoryButtons) do
		if name == currentCategory then
			button.BackgroundColor3 = Color3.fromRGB(105, 85, 160)
		else
			button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		end
	end
end


--------------------------------------------------
-- ANIMATION SUBCATEGORY BAR
--------------------------------------------------

local function updateAnimationCategoryVisuals()
	for name, button in pairs(animationCategoryButtons) do
		if name == currentAnimationCategory then
			button.BackgroundColor3 = Color3.fromRGB(105, 85, 160)
		else
			button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		end
	end
end

local function createAnimationCategoryBar()
	if animationCategoryBar then
		return
	end

	local bar = create("ScrollingFrame", {
		Name = "AnimationCategoryBar",

		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.fromOffset(20, 154),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,

		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
	})

	bar.Parent = mainFrame

	local layout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	layout.Parent = bar

	for _, category in ipairs(Config.AnimationCategories) do
		local button = create("TextButton", {
			Name = category.Name .. "AnimationButton",
			Size = UDim2.fromOffset(72, 30),

			BackgroundColor3 = Color3.fromRGB(50, 50, 60),

			Text = category.DisplayName,
			TextColor3 = Color3.fromRGB(255, 255, 255),

			TextSize = 11,
			Font = Enum.Font.GothamBold,
		})

		button.Parent = bar

		local corner = create("UICorner", {
			CornerRadius = UDim.new(0, 7),
		})

		corner.Parent = button

		animationCategoryButtons[category.Name] = button

		button.MouseButton1Click:Connect(function()
			if currentAnimationCategory == category.Name then
				return
			end

			currentAnimationCategory = category.Name
			updateAnimationCategoryVisuals()
			searchCatalog()
		end)
	end

	animationCategoryBar = bar
	updateAnimationCategoryVisuals()
end

local function setAnimationCategoryBarVisible(visible: boolean)
	if not animationCategoryBar then
		createAnimationCategoryBar()
	end

	if animationCategoryBar then
		animationCategoryBar.Visible = visible
	end
end

--------------------------------------------------
-- CURRENT WORN ITEMS
--------------------------------------------------

local function refreshWornItems()
	local success, serverSuccess, result = pcall(function()
		return TryOnItem:InvokeServer(
			"GetCurrent",
			0
		)
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
-- CATEGORY LOOKUP
--------------------------------------------------

local function getCategoryAssetTypes()
	if currentCategory == "Animations" then
		local animationCategory = Config.GetAnimationCategory(
			currentAnimationCategory
		)

		if animationCategory then
			return animationCategory.AssetTypes
		end
	end

	return Config.GetCategoryAssetTypes(currentCategory)
end

local function getItemDefinition(item: any)
	-- SearchCatalogAsync returns AssetType as an AvatarAssetType name
	-- (for example "HairAccessory", "WalkAnimation").
	local assetTypeName = item.AssetType

	if typeof(assetTypeName) ~= "string" then
		return nil
	end

	return Config.GetDefinitionByName(assetTypeName)
end

--------------------------------------------------
-- CARD
--------------------------------------------------

local function createItemCard(item: any, layoutOrder: number)
	local assetId = item.Id

	if typeof(assetId) ~= "number" then
		return
	end

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

	--------------------------------------------------
	-- THUMBNAIL
	--------------------------------------------------

	local thumbnail = create("ImageLabel", {
		Name = "Thumbnail",

		Size = UDim2.new(1, -12, 0, 145),
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

	--------------------------------------------------
	-- NAME
	--------------------------------------------------

	local nameLabel = create("TextLabel", {
		Name = "Name",

		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.fromOffset(8, 155),

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

	--------------------------------------------------
	-- PRICE
	--------------------------------------------------

	local priceLabel = create("TextLabel", {
		Name = "Price",

		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 185),

		BackgroundTransparency = 1,

		Text = formatPrice(item.Price),

		TextColor3 = Color3.fromRGB(170, 170, 180),

		TextSize = 12,
		Font = Enum.Font.Gotham,

		TextXAlignment = Enum.TextXAlignment.Left,
	})

	priceLabel.Parent = card

	--------------------------------------------------
	-- ACTION BUTTON
	--------------------------------------------------

	local definition = getItemDefinition(item)
	local canWear = definition ~= nil and definition.WearMode ~= "Unsupported"

	local actionButton = create("TextButton", {
		Name = "ActionButton",

		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.new(0, 8, 1, -36),

		BackgroundColor3 = Color3.fromRGB(70, 70, 85),

		TextColor3 = Color3.fromRGB(255, 255, 255),

		TextSize = 12,
		Font = Enum.Font.GothamBold,

		AutoButtonColor = canWear,
		Active = canWear,
	})

	actionButton.Parent = card

	local actionCorner = create("UICorner", {
		CornerRadius = UDim.new(0, 7),
	})

	actionCorner.Parent = actionButton

	local function updateButton()
		if not canWear then
			actionButton.Text = "VIEW ONLY"
			actionButton.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
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

	--------------------------------------------------
	-- BUTTON ACTION
	--------------------------------------------------

	actionButton.MouseButton1Click:Connect(function()
		if not canWear then
			return
		end

		print("[FashionGame] Wear clicked", assetId)
		if actionBusy then
			return
		end

		actionBusy = true

		if currentWornItems[assetId] then
			statusLabel.Text = "Removing..."

			local success, result, message = pcall(function()
				return TryOnItem:InvokeServer(
					"Remove",
					assetId
				)
			end)
			
			print(
				"[FashionGame] Wear response:",
				success,
				result,
				message
			)
			
			if success and result == true then
				currentWornItems[assetId] = nil

				actionButton.Text = "WEAR"
				actionButton.BackgroundColor3 =
					Color3.fromRGB(70, 70, 85)

				statusLabel.Text = "Item removed."
			else
				warn(
					"[CatalogController] Remove failed:",
					result,
					message
				)

				statusLabel.Text =
					typeof(message) == "string"
					and message
					or "Failed to remove item."
			end
		else
			statusLabel.Text = "Wearing..."

			local success, result, message = pcall(function()
				return TryOnItem:InvokeServer(
					"Wear",
					assetId
				)
			end)

			print(
				"[FashionGame] Wear response:",
				success,
				result,
				message
			)

			if success and result == true then
				print("[FashionGame] Wear success - refreshing UI")

				statusLabel.Text = "Item equipped."

				task.wait(0.2)

				refreshWornItems()

				updateButton()
			else
				warn(
					"[CatalogController] Wear failed:",
					result,
					message
				)

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
-- SEARCH
--------------------------------------------------

local searchCatalog: () -> ()

local function finishSearch()
	searchBusy = false

	if searchQueued then
		searchQueued = false
		task.defer(function()
			searchCatalog()
		end)
	end
end

searchCatalog = function()
	if searchBusy then
		searchQueued = true
		return
	end

	searchBusy = true

	for _, child in ipairs(resultsFrame:GetChildren()) do
		if not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end

	currentKeyword = searchBox.Text
	currentPageNumber = 1
	currentPages = nil
	pageLabel.Text = "Page 1"

	statusLabel.Text = "Searching..."

	local params = CatalogSearchParams.new()

	params.SearchKeyword = currentKeyword

	params.Limit = Config.SearchLimit

	-- Body parts, shoes, and many animation assets are not individually on sale.
	-- Include off-sale items so those AvatarAssetTypes can actually be searched.
	params.IncludeOffSale = true
	params.SortType = SORT_OPTIONS[currentSortIndex].Value

	local assetTypes = getCategoryAssetTypes()

	if assetTypes then
		params.AssetTypes = assetTypes
	else
		params.AssetTypes = Config.AllowedAssetTypes
	end

	local success, pages = pcall(function()
		return AvatarEditorService:SearchCatalogAsync(params)
	end)

	if not success then
		warn(
			"[CatalogController] Search failed:",
			pages
		)

		statusLabel.Text =
			"Search failed. Check Output."

		finishSearch()

		return
	end

	currentPages = pages

	local currentPage

	local pageSuccess, pageResult = pcall(function()
		return pages:GetCurrentPage()
	end)

	if not pageSuccess then
		warn(
			"[CatalogController] Failed to read catalog page:",
			pageResult
		)

		statusLabel.Text =
			"Failed to load results."

		finishSearch()

		return
	end

	currentPage = pageResult

	local resultCount = 0

	for index, item in ipairs(currentPage) do
		createItemCard(
			item,
			index
		)

		resultCount += 1
	end

	statusLabel.Text =
		tostring(resultCount)
		.. " items found. Page "
		.. tostring(currentPageNumber)
	pageLabel.Text = "Page " .. tostring(currentPageNumber)
	previousPageButton.Active = currentPageNumber > 1
	previousPageButton.AutoButtonColor = currentPageNumber > 1
	nextPageButton.Active = currentPages ~= nil and not currentPages.IsFinished
	nextPageButton.AutoButtonColor = nextPageButton.Active

	finishSearch()
end

--------------------------------------------------
-- CATEGORY CREATION
--------------------------------------------------

for _, category in ipairs(CATEGORIES) do
	local button = create("TextButton", {
		Name = category.Name .. "Button",

		Size = UDim2.fromOffset(100, 34),

		BackgroundColor3 = Color3.fromRGB(50, 50, 60),

		Text = CATEGORY_LABELS[category.Name] or category.Name,

		TextColor3 = Color3.fromRGB(255, 255, 255),

		TextSize = 12,
		Font = Enum.Font.GothamBold,
	})

	button.Parent = categoryBar

	local corner = create("UICorner", {
		CornerRadius = UDim.new(0, 8),
	})

	corner.Parent = button

	categoryButtons[category.Name] = button

	button.MouseButton1Click:Connect(function()
		if currentCategory == category.Name then
			return
		end

		currentCategory = category.Name

		if currentCategory == "Animations" then
			currentAnimationCategory = "Idle"
			setAnimationCategoryBarVisible(true)
		else
			setAnimationCategoryBarVisible(false)
		end

		updateCategoryVisuals()

		searchCatalog()
	end)
end

updateCategoryVisuals()
setAnimationCategoryBarVisible(false)
previousPageButton.Active = false
previousPageButton.AutoButtonColor = false

--------------------------------------------------
-- SORT / PAGINATION EVENTS
--------------------------------------------------

sortButton.MouseButton1Click:Connect(function()
	if searchBusy then
		return
	end

	currentSortIndex += 1
	if currentSortIndex > #SORT_OPTIONS then
		currentSortIndex = 1
	end

	sortButton.Text = "Sort: " .. SORT_OPTIONS[currentSortIndex].Name
	searchCatalog()
end)

previousPageButton.MouseButton1Click:Connect(function()
	if searchBusy or currentPageNumber <= 1 then
		return
	end

	-- Pages only advances forward; re-run the same search to return
	-- to page 1 when PREV is requested.
	currentPageNumber = 1
	searchCatalog()
end)

nextPageButton.MouseButton1Click:Connect(function()
	if searchBusy or not currentPages or currentPages.IsFinished then
		return
	end

	searchBusy = true
	statusLabel.Text = "Loading next page..."

	local success, err = pcall(function()
		currentPages:AdvanceToNextPageAsync()
	end)

	if not success then
		warn("[CatalogController] Next page failed:", err)
		statusLabel.Text = "Failed to load next page."
		finishSearch()
		return
	end

	currentPageNumber += 1

	for _, child in ipairs(resultsFrame:GetChildren()) do
		if not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end

	local page = currentPages:GetCurrentPage()
	local count = 0
	for index, item in ipairs(page) do
		createItemCard(item, index)
		count += 1
	end

	statusLabel.Text = tostring(count) .. " items found. Page " .. tostring(currentPageNumber)
	pageLabel.Text = "Page " .. tostring(currentPageNumber)
	previousPageButton.Active = true
	previousPageButton.AutoButtonColor = true
	nextPageButton.Active = not currentPages.IsFinished
	nextPageButton.AutoButtonColor = nextPageButton.Active
	finishSearch()
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

--------------------------------------------------
-- INITIALIZE
--------------------------------------------------

print("[FashionGame] CatalogController initialized.")

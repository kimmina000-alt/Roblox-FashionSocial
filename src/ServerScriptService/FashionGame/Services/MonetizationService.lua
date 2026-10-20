--!strict
-- Game Pass ownership and Developer Product receipts (server only).
--
-- * Passes: ownership is checked with UserOwnsGamePassAsync when a player
--   joins and updated when an in-game purchase finishes. The result is shown
--   to everyone as the player attribute "Pass_<key>" (true/false).
-- * Products: ProcessReceipt routes each receipt to the handler registered
--   for its product key. A receipt is granted at most once: the PurchaseId is
--   recorded in a DataStore (when available) before PurchaseGranted is
--   returned, so a retried receipt after a crash is not granted twice.
-- * Studio test purchases: when an ID is still 0 (not created yet), Studio
--   play may simulate the purchase so the flow can be tested. Never in live
--   servers.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

local MonetizationService = {}

type ProductHandler = (player: Player) -> (boolean, string?)

local productHandlers: {[string]: ProductHandler} = {}
local passListeners: {[string]: {(player: Player) -> ()}} = {}

local purchaseStore: DataStore? = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("FashionGamePurchases")
	end)
	if ok then purchaseStore = store end
end

--------------------------------------------------
-- Game passes
--------------------------------------------------

local function setPass(player: Player, key: string, owned: boolean)
	local had = player:GetAttribute("Pass_" .. key) == true
	player:SetAttribute("Pass_" .. key, owned)
	if owned and not had then
		for _, listener in ipairs(passListeners[key] or {}) do
			task.spawn(listener, player)
		end
	end
end

local function refreshPasses(player: Player)
	for key, pass in pairs(MonetizationConfig.GamePasses) do
		if pass.id == 0 then
			setPass(player, key, player:GetAttribute("Pass_" .. key) == true)
		else
			local ok, owned = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			setPass(player, key, ok and owned == true)
		end
	end
end

function MonetizationService.HasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function MonetizationService.OnPassGranted(key: string, listener: (player: Player) -> ())
	passListeners[key] = passListeners[key] or {}
	table.insert(passListeners[key], listener)
end

--------------------------------------------------
-- Developer products
--------------------------------------------------

function MonetizationService.RegisterProduct(key: string, handler: ProductHandler)
	productHandlers[key] = handler
end

local function alreadyGranted(purchaseId: string): boolean?
	if not purchaseStore then return false end
	local ok, value = pcall(function()
		return (purchaseStore :: DataStore):GetAsync("p_" .. purchaseId)
	end)
	if not ok then return nil end
	return value ~= nil
end

local function recordGranted(purchaseId: string, userId: number, key: string): boolean
	if not purchaseStore then return true end
	local ok = pcall(function()
		(purchaseStore :: DataStore):SetAsync("p_" .. purchaseId, { u = userId, k = key, t = os.time() })
	end)
	return ok
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local key = MonetizationConfig.productKeyForId(receipt.ProductId)
	local handler = key and productHandlers[key]
	if not key or not handler then
		warn("[MonetizationService] No handler for product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		-- Roblox retries when the player is back.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local done = alreadyGranted(receipt.PurchaseId)
	if done == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if done then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local ok, granted, message = pcall(handler, player)
	if not ok or not granted then
		warn("[MonetizationService] Grant failed", key, granted, message)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not recordGranted(receipt.PurchaseId, receipt.PlayerId, key) then
		-- Granted in game but not recorded: Roblox may retry; the handlers are
		-- written so a repeat only gives the same item again (no double DJ time
		-- beyond one extra slot), which is the safer side for the buyer.
		warn("[MonetizationService] Could not record receipt", receipt.PurchaseId)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------
-- Studio test purchases (IDs still 0)
--------------------------------------------------

-- Returns true when the item has no real ID yet and this is Studio.
function MonetizationService.IsStudioTest(kind: string, key: string): boolean
	if not RunService:IsStudio() then return false end
	local entry = if kind == "pass" then MonetizationConfig.GamePasses[key] else MonetizationConfig.Products[key]
	return entry ~= nil and entry.id == 0
end

function MonetizationService.StudioTestBuy(player: Player, kind: any, key: any): (boolean, string?)
	if typeof(kind) ~= "string" or typeof(key) ~= "string" then
		return false, "잘못된 요청입니다."
	end
	if not MonetizationService.IsStudioTest(kind, key) then
		return false, "Studio 테스트 구매는 상품 ID가 없을 때 Studio에서만 됩니다."
	end
	if kind == "pass" then
		setPass(player, key, true)
		return true, nil
	end
	local handler = productHandlers[key]
	if not handler then return false, "상품 처리기가 없습니다." end
	return handler(player)
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then return end
		local key = MonetizationConfig.passKeyForId(passId)
		if key then setPass(player, key, true) end
	end)
	Players.PlayerAdded:Connect(refreshPasses)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(refreshPasses, player)
	end
end

return MonetizationService

--!strict
-- Roblox purchase IDs (Game Passes and Developer Products) in one place.
--
-- The IDs are created on the Creator Dashboard (Monetization) for this
-- experience and pasted here. While an ID is 0 the item is "not registered":
--   * live servers show "준비 중인 상품입니다" and never grant anything;
--   * Studio play shows a clearly labelled [Studio 테스트] purchase so the
--     flow can be tested before the product exists (MonetizationService).
-- Prices here are only for display/planning; Roblox charges the price set on
-- the dashboard.

local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	-- Club VIP balcony access (D-045). Permanent.
	VIP = { id = 0, name = "VIP 패스", price = 299 },
	-- 인생네컷 glossy + glitter frames (D-064). Permanent.
	FramePack = { id = 0, name = "프레임 팩 (글로시·반짝이)", price = 99 },
}

MonetizationConfig.Products = {
	-- DJ booth time (D-052). Consumable: each purchase adds DJMinutes.
	DJ = { id = 0, name = "DJ 30분", price = 75 },
	-- Paid drinks (DrinkService). key must match ClubConfig.Drinks[].product.
	Drink_Fanta = { id = 0, name = "환타", price = 6 },
	-- 인생네컷 album +10 slots (first 10 are free, D-064).
	AlbumSlots = { id = 0, name = "사진첩 +10장", price = 25 },
}

-- Minutes of DJ time per DJ purchase.
MonetizationConfig.DJMinutes = 30

function MonetizationConfig.productKeyForId(productId: number): string?
	for key, product in pairs(MonetizationConfig.Products) do
		if product.id ~= 0 and product.id == productId then
			return key
		end
	end
	return nil
end

function MonetizationConfig.passKeyForId(passId: number): string?
	for key, pass in pairs(MonetizationConfig.GamePasses) do
		if pass.id ~= 0 and pass.id == passId then
			return key
		end
	end
	return nil
end

return MonetizationConfig

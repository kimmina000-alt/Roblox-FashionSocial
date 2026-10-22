--!strict
-- Every Robux item in one place (docs/01_SYSTEMS/PRODUCTS.md is the list
-- people read; keep both in step).
--
-- How an item is named (user, 2026-10-22: "통일감 있게"):
--   sku   AREA-TYPE-NAME, upper case, never changes once live
--         AREA = CLUB | PHOTO | CAFE | PARK | AVATAR | VIP ...
--         TYPE = PASS (Game Pass, bought once, permanent)
--              | DP   (Developer Product, can be bought again)
--   key   the name the code uses (table key below); new keys follow
--         Area_Name, e.g. Photo_StickerPack1. The first items keep their
--         older short keys (VIP, FramePack, DJ, Drink_Fanta, AlbumSlots).
--   id    the number Roblox gives when the item is created on the Creator
--         Dashboard (Monetization). We cannot choose it: paste it here.
--
-- While id is 0 the item is "not registered":
--   * live servers show "준비 중인 상품입니다" and never grant anything;
--   * Studio play shows a clearly labelled [Studio 테스트] purchase so the
--     flow can be tested before the product exists (MonetizationService).
-- price is for display/planning; Roblox charges the price set on the dashboard.
-- status: "planned" (not on the dashboard yet) | "live" | "retired" (keep the
-- entry so old purchases still resolve; set offsale on the dashboard).

local MonetizationConfig = {}

export type Item = {
	sku: string,
	id: number,
	name: string,
	price: number,
	status: string,
	description: string,
}

MonetizationConfig.GamePasses = {
	-- Club VIP balcony access (D-045). Permanent.
	VIP = { sku = "CLUB-PASS-VIP", id = 0, name = "VIP 패스", price = 299, status = "planned",
		description = "클럽 2층 VIP 라운지에 언제든 들어갈 수 있어요." },
	-- 인생네컷 glossy + glitter frames (D-064). Permanent.
	FramePack = { sku = "PHOTO-PASS-FRAMEPACK1", id = 0, name = "프레임 팩 (글로시·반짝이)", price = 99, status = "planned",
		description = "인생네컷 특별 프레임(글로시·반짝이)을 영구로 써요." },
} :: {[string]: Item}

MonetizationConfig.Products = {
	-- DJ booth time (D-052). Consumable: each purchase adds DJMinutes.
	DJ = { sku = "CLUB-DP-DJ30", id = 0, name = "DJ 30분", price = 75, status = "planned",
		description = "클럽 DJ 부스를 30분 동안 써요. 곡 선택·조명." },
	-- Paid drinks (DrinkService). key must match ClubConfig.Drinks[].product.
	Drink_Fanta = { sku = "CLUB-DP-DRINK-FANTA", id = 0, name = "환타", price = 6, status = "planned",
		description = "클럽 바에서 환타 한 병(6잔). 테이블에 놓고 나눠 마셔요." },
	-- 인생네컷 album +10 slots (first 10 are free, D-064).
	AlbumSlots = { sku = "PHOTO-DP-ALBUM10", id = 0, name = "사진첩 +10장", price = 25, status = "planned",
		description = "인생네컷 사진첩 칸을 10장 늘려요." },
} :: {[string]: Item}

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

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
	VIP = { sku = "CLUB-PASS-VIP", id = 2053896389, name = "VIP 패스", price = 299, status = "live",
		description = "클럽 2층 VIP 라운지에 언제든 들어갈 수 있어요." },
	-- 인생네컷 glossy + glitter frames (D-064). Permanent.
	FramePack = { sku = "PHOTO-PASS-FRAMEPACK1", id = 2052036510, name = "프레임 팩 (글로시·반짝이)", price = 99, status = "live",
		description = "인생네컷 특별 프레임(글로시·반짝이)을 영구로 써요." },
	-- Coin x2 for good (D-278): time online and the cafe job earn twice as much.
	CoinX2 = { sku = "ECON-PASS-COINX2", id = 2054100489, name = "코인 x2 패스", price = 199, status = "live",
		description = "접속 코인과 알바 코인을 영원히 2배로 받아요." },
	-- Glowstick (user 2026-10-27): a permanent hand item, tap to change colour. Create on the dashboard, paste the id.
	Glowstick = { sku = "CLUB-PASS-GLOWSTICK", id = 0, name = "야광봉", price = 99, status = "planned",
		description = "언제 어디서나 들 수 있는 야광봉. 누르면 색이 바뀌어요." },
} :: {[string]: Item}

MonetizationConfig.Products = {
	-- Bus stop ad boards (BusAdService, D-279): 4 stops × 2 panels
	BusAd1D = { sku = "CITY-DP-BUSAD-1D", id = 3722464596, name = "버스 정류장 광고 24시간", price = 49, status = "live",
		description = "버스 정류장 광고판에 내 아바타와 아이디를 24시간 걸어요." },
	BusAd3D = { sku = "CITY-DP-BUSAD-3D", id = 3722464621, name = "버스 정류장 광고 3일", price = 99, status = "live",
		description = "버스 정류장 광고판에 내 아바타와 아이디를 3일 걸어요." },
	-- 1 hour of coin x2 (counted while online; cannot be bought with the pass)
	CoinBoost1h = { sku = "ECON-DP-BOOST1H", id = 3722464572, name = "1시간 코인 x2 부스트", price = 25, status = "live",
		description = "접속해 있는 1시간 동안 코인을 2배로 받아요." },
	-- DJ booth time (D-052). Consumable: each purchase adds DJMinutes.
	-- (Robux only, test price 25 R$: D-268 / D-270)
	DJ = { sku = "CLUB-DP-DJ30", id = 3722464534, name = "DJ 30분", price = 25, status = "live",
		description = "클럽 DJ 부스를 30분 동안 써요. 곡 선택·조명." },
	-- Paid drinks (DrinkService). key must match ClubConfig.Drinks[].product
	-- or .vipProduct. One bottle = 6 cups, placed on a table and shared.
	-- (오렌지 소다 became a 💰5 tier-1 drink, D-271: kept only as a record)
	Drink_Fanta = { sku = "CLUB-DP-DRINK-FANTA", id = 0, name = "환타", price = 6, status = "retired",
		description = "클럽 바에서 환타 한 병(6잔). 테이블에 놓고 나눠 마셔요." },
	-- tier 2 (also 💰100 / 💰150 in coins)
	Drink_GingerBrew = { sku = "CLUB-DP-DRINK-GINGER", id = 3722464952, name = "진저 브루", price = 10, status = "live",
		description = "클럽 바 진저 브루 한 병(6잔)." },
	Drink_Monte = { sku = "CLUB-DP-DRINK-MONTE", id = 3722464990, name = "몬테 스파클링", price = 10, status = "live",
		description = "클럽 바 몬테 스파클링 한 병(6잔)." },
	Drink_FrenchLemonade = { sku = "CLUB-DP-DRINK-FRENCHLEMON", id = 3722465028, name = "프렌치 레모네이드", price = 10, status = "live",
		description = "클럽 바 프렌치 레모네이드 한 병(6잔)." },
	Drink_GoldenApple = { sku = "CLUB-DP-DRINK-GOLDENAPPLE", id = 3722465079, name = "골든 애플 스파클링", price = 10, status = "live",
		description = "클럽 바 골든 애플 스파클링 한 병(6잔)." },
	Drink_ZzangPop = { sku = "CLUB-DP-DRINK-ZZANGPOP", id = 3722465111, name = "쨍팝", price = 10, status = "live",
		description = "클럽 바 쨍팝 한 캔(6잔). 핑크·라임·오렌지 중 골라요." },
	Drink_HotBoost = { sku = "CLUB-DP-DRINK-HOTBOOST", id = 3722465131, name = "핫부스트", price = 15, status = "live",
		description = "클럽 바 에너지 드링크 핫부스트(6잔)." },
	Drink_GreenClaw = { sku = "CLUB-DP-DRINK-GREENCLAW", id = 3722465145, name = "그린 클로", price = 15, status = "live",
		description = "클럽 바 에너지 드링크 그린 클로(6잔)." },
	Drink_BlueWing = { sku = "CLUB-DP-DRINK-BLUEWING", id = 3722465175, name = "블루 윙", price = 15, status = "live",
		description = "클럽 바 에너지 드링크 블루 윙(6잔)." },
	-- tier 3 (Robux only) and their VIP prices (20% off, D-270)
	Drink_StackHydro = { sku = "CLUB-DP-DRINK-STACK", id = 3722465198, name = "스택 하이드로", price = 49, status = "live",
		description = "프리미엄 음료 스택 하이드로(6잔)." },
	Drink_StackHydro_VIP = { sku = "CLUB-DP-DRINK-STACK-VIP", id = 3722465233, name = "스택 하이드로 (VIP가)", price = 39, status = "live",
		description = "VIP 가격 스택 하이드로(6잔)." },
	Drink_PastelSplash = { sku = "CLUB-DP-DRINK-PASTEL", id = 3722465255, name = "파스텔 스플래시", price = 79, status = "live",
		description = "프리미엄 음료 파스텔 스플래시(6잔)." },
	Drink_PastelSplash_VIP = { sku = "CLUB-DP-DRINK-PASTEL-VIP", id = 3722465335, name = "파스텔 스플래시 (VIP가)", price = 63, status = "live",
		description = "VIP 가격 파스텔 스플래시(6잔)." },
	Drink_SkullWater = { sku = "CLUB-DP-DRINK-SKULL", id = 3722465361, name = "스컬 캔 워터", price = 99, status = "live",
		description = "프리미엄 음료 스컬 캔 워터(6잔)." },
	Drink_SkullWater_VIP = { sku = "CLUB-DP-DRINK-SKULL-VIP", id = 3722465378, name = "스컬 캔 워터 (VIP가)", price = 79, status = "live",
		description = "VIP 가격 스컬 캔 워터(6잔)." },
	-- Sparklers and the stage cold spark (SparkleService, D-270..D-272)
	Sparkler1 = { sku = "CLUB-DP-SPARKLER1", id = 3722465414, name = "테이블 스파클러", price = 15, status = "live",
		description = "테이블의 내 병 위로 스파클러가 30초 동안 타올라요." },
	-- (user 2026-10-27) five sparklers in one item, up to five burn in one bucket; and a hand sparkler (60 s)
	Sparkler5 = { sku = "CLUB-DP-SPARKLER5", id = 0, name = "테이블 스파클러 5개", price = 59, status = "planned",
		description = "테이블 스파클러 5개 묶음. 한 버킷에 5개까지 함께 꽂혀요." },
	HandSparkler = { sku = "CLUB-DP-HANDSPARKLER", id = 0, name = "손 스파클러", price = 19, status = "planned",
		description = "손에 들고 60초 동안 타오르는 스파클러. 들고 춤출 수 있어요." },
	SparklerBucket = { sku = "CLUB-DP-SPARKLER-BUCKET", id = 3722465439, name = "스파클러 버킷 세트", price = 49, status = "live",
		description = "얼음 버킷 + 캔 3개(모두 마실 수 있어요) + 스파클러 3개." },
	SparklerBucket_VIP = { sku = "CLUB-DP-SPARKLER-BUCKET-VIP", id = 3722465476, name = "스파클러 버킷 세트 (VIP가)", price = 39, status = "live",
		description = "VIP 가격 스파클러 버킷 세트." },
	ColdSpark = { sku = "CLUB-DP-COLDSPARK", id = 3722465515, name = "무대 콜드 스파크", price = 99, status = "live",
		description = "DJ 무대 앞 불꽃 분수 10초 + 모두의 화면에 내 이름과 한마디." },
	ColdSpark_VIP = { sku = "CLUB-DP-COLDSPARK-VIP", id = 3722465534, name = "무대 콜드 스파크 (VIP가)", price = 79, status = "live",
		description = "VIP 가격 무대 콜드 스파크." },
	-- Supporter gifts: a banner with the name and message for everyone (D-271)
	Support_10 = { sku = "GAME-DP-SUPPORT-10", id = 3722465568, name = "후원 10", price = 10, status = "live", description = "게임 후원 10 R$." },
	Support_50 = { sku = "GAME-DP-SUPPORT-50", id = 3722465600, name = "후원 50", price = 50, status = "live", description = "게임 후원 50 R$." },
	Support_100 = { sku = "GAME-DP-SUPPORT-100", id = 3722465631, name = "후원 100", price = 100, status = "live", description = "게임 후원 100 R$." },
	Support_500 = { sku = "GAME-DP-SUPPORT-500", id = 3722468261, name = "후원 500", price = 500, status = "live", description = "게임 후원 500 R$." },
	Support_1000 = { sku = "GAME-DP-SUPPORT-1000", id = 3722468275, name = "후원 1,000", price = 1000, status = "live", description = "게임 후원 1,000 R$." },
	Support_5000 = { sku = "GAME-DP-SUPPORT-5000", id = 3722468330, name = "후원 5,000", price = 5000, status = "live", description = "게임 후원 5,000 R$." },
	-- VIP only (D-274)
	Drink_Golmok = { sku = "CLUB-DP-DRINK-GOLMOK", id = 3722465394, name = "골목 공방 소다 (VIP 전용)", price = 59, status = "live",
		description = "VIP 전용 수제 소다(6잔). 레몬 라벤더·생강 장미·오미자 히비스커스·오디." },
	-- Cafe and 국밥집 (SnackService, D-310..D-312): the parfait is one serving,
	-- the cakes and the 수육 plate go on a table and everyone takes a piece
	Cafe_Parfait = { sku = "CAFE-DP-PARFAIT", id = 3722468372, name = "딸기 파르페", price = 15, status = "live",
		description = "카페의 큰 딸기 파르페 한 잔." },
	-- (also 💰100 in coins, like the club's tier-2 bottles)
	Cafe_CakeStrawberry = { sku = "CAFE-DP-CAKE-STRAWBERRY", id = 3722468408, name = "딸기생크림 케이크", price = 10, status = "live",
		description = "테이블에 놓는 홀케이크. 6조각을 모두 함께 나눠 먹어요." },
	Cafe_CakeVintage = { sku = "CAFE-DP-CAKE-VINTAGE", id = 3722468462, name = "빈티지 레터링 케이크", price = 25, status = "live",
		description = "체리와 크림, 레터링이 올라간 빈티지 홀케이크(색은 랜덤 4가지). 6조각을 모두 함께 나눠 먹어요." },
	Cafe_CakeTiramisu = { sku = "CAFE-DP-CAKE-TIRAMISU", id = 3722468430, name = "티라미수 케이크", price = 25, status = "live",
		description = "테이블에 놓는 홀케이크. 6조각을 모두 함께 나눠 먹어요." },
	Cafe_CakeBasque = { sku = "CAFE-DP-CAKE-BASQUE", id = 3722468449, name = "바스크 치즈케이크", price = 25, status = "live",
		description = "테이블에 놓는 홀케이크. 6조각을 모두 함께 나눠 먹어요." },
	Gukbap_Suyuk = { sku = "GUKBAP-DP-SUYUK", id = 3722468485, name = "수육 한 접시", price = 19, status = "live",
		description = "국밥집 테이블에 놓는 수육 한 접시. 6점을 모두 함께 나눠 먹어요." },
	-- 인생네컷 album +10 slots (first 10 are free, D-064).
	AlbumSlots = { sku = "PHOTO-DP-ALBUM10", id = 3722464659, name = "사진첩 +10장", price = 25, status = "live",
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

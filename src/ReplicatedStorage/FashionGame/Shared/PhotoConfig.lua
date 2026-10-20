--!strict
-- 인생네컷 photo booth settings (PHOTO_BOOTH.md, P1 + group shooting).
-- Shared by PhotoBoothService (server) and PhotoBoothController (client).

export type Layout = { key: string, name: string, cols: number, rows: number }
-- price: "free" | "coins" (EconomyConfig coin price, unlocked forever) |
-- "pass" (Game Pass MonetizationConfig.GamePasses.FramePack).
-- style: "solid" | "gloss" (shine gradient) | "glitter" (sparkles).
export type Frame = { key: string, name: string, color: Color3, text: Color3, tab: string, price: string, coins: number?, style: string }

local PhotoConfig = {}

PhotoConfig.Layouts = {
	{ key = "1x4", name = "기본 1×4", cols = 1, rows = 4 },
	{ key = "2x2", name = "기본 2×2", cols = 2, rows = 2 },
} :: {Layout}

-- Who may join the host (참고 게임: 혼자만 / 친구와 / 모두와).
PhotoConfig.Modes = {
	{ key = "solo", name = "혼자만" },
	{ key = "friends", name = "친구와" },
	{ key = "all", name = "모두와" },
}

PhotoConfig.MaxPeople = 4
PhotoConfig.ShotCount = 8          -- photos taken per session
PhotoConfig.PickCount = 4          -- photos kept (4컷)
PhotoConfig.ShotSeconds = 10       -- countdown per photo
PhotoConfig.FirstShotSeconds = 8   -- a little longer to pick the first pose
PhotoConfig.WaitSeconds = 10       -- waiting for friends (친구와 / 모두와)
PhotoConfig.SoloWaitSeconds = 3
PhotoConfig.PickSeconds = 120      -- time to pick 4 + a frame
PhotoConfig.MaxPhotos = 10         -- free album slots (user, 2026-10-20: 10장까지 무료)
PhotoConfig.HardMaxPhotos = 60     -- stored maximum incl. bought slots (D-064)
PhotoConfig.SlotsPerPurchase = 10  -- MonetizationConfig.Products.AlbumSlots
PhotoConfig.MaxWallPhotos = 30     -- photo wall: newest stay, oldest fall off
PhotoConfig.OpenDistance = 24      -- how close to the booth to start / join
PhotoConfig.LeaveDistance = 30     -- (unused since D-064: people stay inside the booth)

-- Frames (user, 2026-10-20): 블랙/화이트 free; other colours and pastels are
-- bought with coins earned in game (EconomyConfig); glossy / glitter frames
-- come with the paid Frame Pack (Robux). Bought frames stay unlocked.
PhotoConfig.FrameTabs = { "색상", "파스텔", "특별한" }
PhotoConfig.Frames = {
	{ key = "black", name = "블랙", color = Color3.fromRGB(20, 20, 24), text = Color3.new(1, 1, 1), tab = "색상", price = "free", style = "solid" },
	{ key = "white", name = "화이트", color = Color3.fromRGB(250, 250, 250), text = Color3.fromRGB(30, 30, 30), tab = "색상", price = "free", style = "solid" },
	{ key = "gray", name = "그레이", color = Color3.fromRGB(150, 150, 158), text = Color3.new(1, 1, 1), tab = "색상", price = "coins", coins = 120, style = "solid" },
	{ key = "pink", name = "핑크", color = Color3.fromRGB(255, 160, 200), text = Color3.new(1, 1, 1), tab = "파스텔", price = "coins", coins = 200, style = "solid" },
	{ key = "sky", name = "하늘", color = Color3.fromRGB(150, 205, 255), text = Color3.new(1, 1, 1), tab = "파스텔", price = "coins", coins = 200, style = "solid" },
	{ key = "mint", name = "민트", color = Color3.fromRGB(150, 230, 200), text = Color3.fromRGB(30, 60, 50), tab = "파스텔", price = "coins", coins = 200, style = "solid" },
	{ key = "lemon", name = "레몬", color = Color3.fromRGB(255, 235, 140), text = Color3.fromRGB(80, 60, 20), tab = "파스텔", price = "coins", coins = 200, style = "solid" },
	{ key = "lilac", name = "라일락", color = Color3.fromRGB(200, 170, 255), text = Color3.new(1, 1, 1), tab = "파스텔", price = "coins", coins = 200, style = "solid" },
	{ key = "neon", name = "글로시 네온", color = Color3.fromRGB(40, 10, 60), text = Color3.fromRGB(255, 80, 200), tab = "특별한", price = "pass", style = "gloss" },
	{ key = "gloss_pink", name = "글로시 핑크", color = Color3.fromRGB(255, 110, 175), text = Color3.new(1, 1, 1), tab = "특별한", price = "pass", style = "gloss" },
	{ key = "gold", name = "반짝이 골드", color = Color3.fromRGB(212, 175, 55), text = Color3.fromRGB(40, 30, 10), tab = "특별한", price = "pass", style = "glitter" },
	{ key = "glitter_silver", name = "반짝이 실버", color = Color3.fromRGB(196, 200, 212), text = Color3.fromRGB(40, 40, 50), tab = "특별한", price = "pass", style = "glitter" },
} :: {Frame}

function PhotoConfig.priceText(frame: Frame): string
	if frame.price == "coins" then return "🪙 " .. tostring(frame.coins) end
	if frame.price == "pass" then return "프레임 팩" end
	return "무료"
end

-- Poses: the club dances/poses (ClubConfig.Dances), poses first.
PhotoConfig.PoseCategoryOrder = { "포즈·응원", "댄스" }

-- Props (소품): simple shapes built in code (PhotoProps), worn as
-- accessories during the shoot and redrawn in the saved photo.
PhotoConfig.Props = {
	{ key = "catears", name = "고양이 귀" },
	{ key = "bunny", name = "토끼 귀" },
	{ key = "bow", name = "리본" },
	{ key = "crown", name = "왕관" },
	{ key = "shades", name = "선글라스" },
	{ key = "heart", name = "하트 안경" },
}
PhotoConfig.MaxProps = 3

function PhotoConfig.findLayout(key: any): Layout?
	for _, layout in ipairs(PhotoConfig.Layouts) do
		if layout.key == key then return layout end
	end
	return nil
end

function PhotoConfig.findFrame(key: any): Frame?
	for _, frame in ipairs(PhotoConfig.Frames) do
		if frame.key == key then return frame end
	end
	return nil
end

function PhotoConfig.isMode(key: any): boolean
	for _, mode in ipairs(PhotoConfig.Modes) do
		if mode.key == key then return true end
	end
	return false
end

function PhotoConfig.isProp(key: any): boolean
	for _, prop in ipairs(PhotoConfig.Props) do
		if prop.key == key then return true end
	end
	return false
end

return PhotoConfig

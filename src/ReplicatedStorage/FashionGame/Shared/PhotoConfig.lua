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
-- (D-1126) the motion video of the picked cuts (PhotoMotionReel): seconds
-- before each shot. A Roblox video capture is 30 s at most: 4 cuts x (5 s +
-- 1 s still) = 24 s; 7 s would be 32 s (cut off) and would also show the end of
-- the previous shot (countdown 8-10 s).
PhotoConfig.MotionClipSeconds = 5
-- (D-1136, user 2026-11-10: "오후네컷 키 큰 캐릭터들 목 잘리니까 아래로 내려갈 수 있게 하자..
-- 위 아래 화살표 넣어서 캐릭터 위치 변경할 수 있게 해 ... 누를 때마다 내려가게 수치 조절할
-- 수 있게 하고. 한 번에 일어설 수 있는 버튼도") 높이 맞추기 in the pose list: ▼ / ▲ move the
-- person this many studs per press (an R15 avatar is about 5 studs tall: 0.5 = a
-- tenth of it), down to HeightMin, up to HeightMax; 🧍 일어서기 puts it back.
PhotoConfig.HeightStep = 0.5
PhotoConfig.HeightMin = -6
PhotoConfig.HeightMax = 2
-- (D-1011, user 2026-11-08: "어제 오후네컷 네 명이 찍으려고 하니까 안 된다는 의견 있었는데 동시에 들어가지 말고 시간차 두고 입장하고 네 명 초과하면 입장 안 되는지 세세한 부분 체크") the 7-player test: by the time the
-- others had walked up and tapped 같이 찍기, the 10 s were over and the host
-- shot alone. Now 30 s; each person who joins gives everyone at least 15 s
-- more; a full booth (4) starts 5 s later. The host can still tap 바로 시작.
PhotoConfig.WaitSeconds = 30       -- waiting for friends (친구와 / 모두와; 10 until D-1011)
PhotoConfig.JoinExtraSeconds = 15  -- after someone joins, at least this long before shooting
PhotoConfig.FullStartSeconds = 5   -- 4 people in: shooting starts this soon
PhotoConfig.SoloWaitSeconds = 3
PhotoConfig.PickSeconds = 120      -- time for the host to pick 4 + a frame
-- Copies (user, 2026-10-22): after the host chose the frame, each person picks
-- how many prints to keep: 1 free, more cost coins each.
PhotoConfig.CopySeconds = 30
PhotoConfig.MaxCopies = 5
PhotoConfig.ExtraCopyCoins = 10 -- (was 20, D-311)
PhotoConfig.MaxPhotos = 10         -- free album slots (user, 2026-10-20: 10장까지 무료)
PhotoConfig.HardMaxPhotos = 60     -- stored maximum incl. bought slots (D-064)
PhotoConfig.SlotsPerPurchase = 10  -- MonetizationConfig.Products.AlbumSlots
PhotoConfig.MaxWallPhotos = 30     -- photo wall: newest stay, oldest fall off (per wall since D-1342)
-- (D-1342, user 2026-11-13: a photo on the 오후네컷 wall had gone) the 30 used to be for the
-- whole game, so photos posted on any wall pushed the oldest off every other wall: now 30 on
-- each wall, and at most this many in all (one DataStore key; about 5 KB a photo)
PhotoConfig.MaxWallPhotosTotal = 150

-- removes the oldest entries (the list is oldest first) past both limits; returns them
function PhotoConfig.trimWall(list: {any}): {any}
	local perWall: {[string]: number} = {}
	for _, e in ipairs(list) do perWall[tostring(e.wall)] = (perWall[tostring(e.wall)] or 0) + 1 end
	local total = #list
	local removed = {}
	local i = 1
	while i <= #list do
		local e = list[i]
		local key = tostring(e.wall)
		if total > PhotoConfig.MaxWallPhotosTotal or perWall[key] > PhotoConfig.MaxWallPhotos then
			table.remove(list, i)
			perWall[key] -= 1
			total -= 1
			table.insert(removed, e)
		else
			i += 1
		end
	end
	return removed
end
PhotoConfig.OpenDistance = 24      -- how close to the booth to start / join
PhotoConfig.LeaveDistance = 30     -- (unused since D-064: people stay inside the booth)

-- Frames (user, 2026-10-20): 블랙/화이트 free; other colours and pastels are
-- bought with coins earned in game (EconomyConfig); glossy / glitter frames
-- come with the paid Frame Pack (Robux). Bought frames stay unlocked.
PhotoConfig.FrameTabs = { "색상", "파스텔", "특별한" }
PhotoConfig.Frames = {
	{ key = "black", name = "블랙", color = Color3.fromRGB(20, 20, 24), text = Color3.new(1, 1, 1), tab = "색상", price = "free", style = "solid" },
	{ key = "white", name = "화이트", color = Color3.fromRGB(250, 250, 250), text = Color3.fromRGB(30, 30, 30), tab = "색상", price = "free", style = "solid" },
	{ key = "gray", name = "그레이", color = Color3.fromRGB(150, 150, 158), text = Color3.new(1, 1, 1), tab = "색상", price = "coins", coins = 50, style = "solid" },
	{ key = "pink", name = "핑크", color = Color3.fromRGB(255, 160, 200), text = Color3.new(1, 1, 1), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "sky", name = "하늘", color = Color3.fromRGB(150, 205, 255), text = Color3.new(1, 1, 1), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "mint", name = "민트", color = Color3.fromRGB(150, 230, 200), text = Color3.fromRGB(30, 60, 50), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "lemon", name = "레몬", color = Color3.fromRGB(255, 235, 140), text = Color3.fromRGB(80, 60, 20), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "lilac", name = "라일락", color = Color3.fromRGB(200, 170, 255), text = Color3.new(1, 1, 1), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	-- (ten pastels, user 2026-10-30)
	{ key = "peach", name = "피치", color = Color3.fromRGB(255, 200, 170), text = Color3.fromRGB(110, 60, 40), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "coral", name = "코랄", color = Color3.fromRGB(255, 165, 160), text = Color3.new(1, 1, 1), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "sage", name = "세이지", color = Color3.fromRGB(185, 215, 175), text = Color3.fromRGB(50, 70, 45), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "aqua", name = "아쿠아", color = Color3.fromRGB(160, 228, 235), text = Color3.fromRGB(30, 70, 80), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "cream", name = "크림", color = Color3.fromRGB(248, 236, 210), text = Color3.fromRGB(110, 90, 60), tab = "파스텔", price = "coins", coins = 100, style = "solid" },
	{ key = "neon_black", name = "블랙 네온", color = Color3.fromRGB(14, 12, 18), text = Color3.fromRGB(255, 120, 220), tab = "특별한", price = "pass", style = "solid", neon = Color3.fromRGB(255, 70, 200) }, -- (black with a neon outline, user 2026-10-30)
	{ key = "neon", name = "글로시 네온", color = Color3.fromRGB(40, 10, 60), text = Color3.fromRGB(255, 80, 200), tab = "특별한", price = "pass", style = "gloss" },
	{ key = "gloss_pink", name = "글로시 핑크", color = Color3.fromRGB(255, 110, 175), text = Color3.new(1, 1, 1), tab = "특별한", price = "pass", style = "gloss" },
	{ key = "gold", name = "반짝이 골드", color = Color3.fromRGB(212, 175, 55), text = Color3.fromRGB(40, 30, 10), tab = "특별한", price = "pass", style = "glitter" },
	{ key = "glitter_silver", name = "반짝이 실버", color = Color3.fromRGB(196, 200, 212), text = Color3.fromRGB(40, 40, 50), tab = "특별한", price = "pass", style = "glitter" },
	-- sticker frames (user 2026-10-30): a pastel frame with emoji stickers on the photo corners
	{ key = "puppy", name = "강아지", color = Color3.fromRGB(240, 214, 180), text = Color3.fromRGB(110, 70, 40), tab = "특별한", price = "pass", style = "sticker", stickers = { "🐶", "🦴", "🐾" } },
	{ key = "kitty", name = "고양이", color = Color3.fromRGB(255, 214, 226), text = Color3.fromRGB(150, 70, 100), tab = "특별한", price = "pass", style = "sticker", stickers = { "🐱", "🐟", "🐾" } },
	{ key = "hearts", name = "하트", color = Color3.fromRGB(255, 182, 206), text = Color3.new(1, 1, 1), tab = "특별한", price = "pass", style = "sticker", stickers = { "💖", "💕", "💗" } },
	{ key = "stars", name = "별", color = Color3.fromRGB(180, 200, 255), text = Color3.new(1, 1, 1), tab = "특별한", price = "pass", style = "sticker", stickers = { "⭐", "🌟", "✨" } },
	{ key = "flowers", name = "꽃", color = Color3.fromRGB(214, 240, 200), text = Color3.fromRGB(70, 110, 60), tab = "특별한", price = "pass", style = "sticker", stickers = { "🌸", "🌼", "🌷" } },
	{ key = "mongi", name = "몽이", color = Color3.fromRGB(255, 226, 234), text = Color3.fromRGB(150, 80, 110), tab = "특별한", price = "pass", style = "sticker", stickers = { "rbxassetid://139448598693468", "rbxassetid://102428635231665", "💗" } }, -- (the shop's own mascot, user 2026-10-30; docs/04_ART/textures/mascot_mongi*.png)
	-- (D-1366) the opening event's limited frame: the 7th attendance gives it (price "event",
	-- never sold); the user's own art comes later, until then a pink sticker frame
	{ key = "opening2026", name = "오픈 기념", color = Color3.fromRGB(255, 196, 222), text = Color3.fromRGB(150, 70, 140), tab = "특별한", price = "event", style = "sticker", stickers = { "🌸", "👑", "💜" } },
	{ key = "hamster", name = "햄찌·토끼", color = Color3.fromRGB(255, 236, 200), text = Color3.fromRGB(130, 90, 50), tab = "특별한", price = "pass", style = "sticker", stickers = { "🐹", "🐰", "🍙" } },
} :: {Frame}

function PhotoConfig.priceText(frame: Frame): string
	if frame.price == "coins" then return "💰 " .. tostring(frame.coins) end
	if frame.price == "pass" then return "프레임 팩" end
	if frame.price == "event" then return "출석 7회" end -- (D-1366)
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

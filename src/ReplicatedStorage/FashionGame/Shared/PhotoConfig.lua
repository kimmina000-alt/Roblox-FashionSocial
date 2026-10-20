--!strict
-- 인생네컷 photo booth settings (PHOTO_BOOTH.md, P1 + group shooting).
-- Shared by PhotoBoothService (server) and PhotoBoothController (client).

export type Layout = { key: string, name: string, cols: number, rows: number }
export type Frame = { key: string, name: string, color: Color3, text: Color3, tab: string }

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
PhotoConfig.MaxPhotos = 30         -- album size per player (PHOTO_BOOTH.md §8)
PhotoConfig.OpenDistance = 24      -- how close to the booth to start / join
PhotoConfig.LeaveDistance = 30     -- walking further away during the shoot = leaving

-- Frames (MVP: all free). The tab groups them like the reference.
PhotoConfig.FrameTabs = { "색상", "파스텔", "특별한" }
PhotoConfig.Frames = {
	{ key = "black", name = "블랙", color = Color3.fromRGB(20, 20, 24), text = Color3.new(1, 1, 1), tab = "색상" },
	{ key = "white", name = "화이트", color = Color3.fromRGB(250, 250, 250), text = Color3.fromRGB(30, 30, 30), tab = "색상" },
	{ key = "gray", name = "그레이", color = Color3.fromRGB(150, 150, 158), text = Color3.new(1, 1, 1), tab = "색상" },
	{ key = "pink", name = "핑크", color = Color3.fromRGB(255, 160, 200), text = Color3.new(1, 1, 1), tab = "파스텔" },
	{ key = "sky", name = "하늘", color = Color3.fromRGB(150, 205, 255), text = Color3.new(1, 1, 1), tab = "파스텔" },
	{ key = "mint", name = "민트", color = Color3.fromRGB(150, 230, 200), text = Color3.fromRGB(30, 60, 50), tab = "파스텔" },
	{ key = "lemon", name = "레몬", color = Color3.fromRGB(255, 235, 140), text = Color3.fromRGB(80, 60, 20), tab = "파스텔" },
	{ key = "lilac", name = "라일락", color = Color3.fromRGB(200, 170, 255), text = Color3.new(1, 1, 1), tab = "파스텔" },
	{ key = "neon", name = "네온 클럽", color = Color3.fromRGB(40, 10, 60), text = Color3.fromRGB(255, 80, 200), tab = "특별한" },
	{ key = "gold", name = "골드", color = Color3.fromRGB(212, 175, 55), text = Color3.fromRGB(40, 30, 10), tab = "특별한" },
} :: {Frame}

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

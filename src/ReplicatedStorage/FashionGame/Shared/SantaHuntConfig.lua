--!strict
-- (D-1878, user 2026-11-22: "크리스마스 이벤트 미니 산타 찾기 (매일 특별한 산타 하나씩 등장)") The mini
-- Santa hunt, in place of a winter attendance event: 2026-12-06 05:00 ~ 12-26 05:00 KST (the day
-- turns at 05:00 KST like the attendance), one special mini Santa a day, always at the same spot
-- on every server, with a hint line. A Santa can only be found on its own day. Found Santas go into
-- the 산타 도감 (wallet.santa.found), which stays after the event as the "2026 미니 산타 앨범"; a found
-- Santa can be taken out of the album as a plush to hold (SantaHuntService "Hold").
-- SantaFactory builds every Santa from parts by its `look`.

local SantaHuntConfig = {}

SantaHuntConfig.Start = DateTime.fromUniversalTime(2026, 12, 5, 20, 0, 0) -- (= 2026-12-06 05:00 KST)
SantaHuntConfig.Title = "미니 산타 찾기"
SantaHuntConfig.AlbumTitle = "2026 미니 산타 앨범"

export type Santa = {
	key: string, name: string, hint: string,
	pos: Vector3, -- near the floor of the spot (the server drops it onto the floor below)
	look: string, -- SantaFactory variant
	yaw: number?, -- degrees, which way it faces
	image: string?, -- (D-2043) the album card / reveal picture (tools/art/santa/album_render.py)
}

-- one a day, in order: day 1 = 12/6
SantaHuntConfig.Santas = {
	{ key = "firstsnow", name = "첫눈 산타", hint = "모두가 처음 도착하는 광장 근처를 찾아보세요.", pos = Vector3.new(-90, 6, -62), look = "classic", image = "rbxassetid://70959554400964" },
	{ key = "dj", name = "DJ 산타", hint = "쿵쿵, 음악이 제일 크게 울리는 곳에 있어요.", pos = Vector3.new(120, -6, -140), look = "dj", image = "rbxassetid://74945536137534" },
	{ key = "barista", name = "바리스타 산타", hint = "바다가 보이는 카페에서 커피를 내리고 있어요.", pos = Vector3.new(-270, 8, 262), look = "barista", image = "rbxassetid://139256484559670" },
	{ key = "fourcuts", name = "네컷 산타", hint = "찰칵! 친구랑 사진 찍는 가게에 숨어 있어요.", pos = Vector3.new(150, 8, -75), look = "camera", image = "rbxassetid://120775406884084" },
	{ key = "oh24", name = "편의점 산타", hint = "24시간 불이 꺼지지 않는 가게에 있어요.", pos = Vector3.new(-94, 6, 128), look = "store", image = "rbxassetid://130181672023192" },
	{ key = "gukbap", name = "국밥 산타", hint = "뜨끈한 국물 냄새가 나는 곳이에요.", pos = Vector3.new(87, 6, -330), look = "gukbap", image = "rbxassetid://136308288604503" },
	{ key = "hanbok", name = "한복 산타", hint = "기와 지붕 아래, 한옥 마을을 걸어 보세요.", pos = Vector3.new(391, 6, -36), look = "hanbok", image = "rbxassetid://135369048243020" },
	{ key = "guard", name = "수문장 산타", hint = "커다란 문을 지키고 있어요.", pos = Vector3.new(144, 6, 132), look = "guard", image = "rbxassetid://108262909888263" },
	{ key = "teacup", name = "찻잔 산타", hint = "빙글빙글 도는 찻잔 근처에 있어요.", pos = Vector3.new(-97, 26, -372), look = "teacup", image = "rbxassetid://138518527504570" },
	{ key = "surfer", name = "서퍼 산타", hint = "파도 소리가 들리는 튜브 더미 옆이에요.", pos = Vector3.new(-217, 6, -131), look = "surfer", image = "rbxassetid://107056547236954" },
	{ key = "bakery", name = "빵집 산타", hint = "갓 구운 빵 냄새를 따라가 보세요.", pos = Vector3.new(-243, 8, 247), look = "baker", image = "rbxassetid://92707888473586" },
	{ key = "bus", name = "버스 산타", hint = "버스를 기다리는 정류장에 앉아 있어요.", pos = Vector3.new(31, 5, 217), look = "bus", image = "rbxassetid://91703093367846" },
	{ key = "subway", name = "지하철 산타", hint = "계단 아래로 내려가는 지하철 출구에 있어요.", pos = Vector3.new(29, 4, 62), look = "subway", image = "rbxassetid://117191769519373" },
	{ key = "wheel", name = "관람차 산타", hint = "제일 높이 올라가는 관람차 타는 곳에 있어요.", pos = Vector3.new(-200, 22, -590), look = "wheel", image = "rbxassetid://89036281803702" },
	{ key = "bumper", name = "범퍼카 산타", hint = "쿵! 부딪히며 노는 곳에 있어요.", pos = Vector3.new(-112, 22, -600), look = "bumper", image = "rbxassetid://78670094756835" },
	{ key = "churros", name = "츄러스 산타", hint = "달콤한 간식을 파는 가게 앞이에요.", pos = Vector3.new(-232, 22, -428), look = "churros", image = "rbxassetid://126608481294175" },
	{ key = "vip", name = "VIP 산타", hint = "클럽 안, VIP만 올라가는 계단 아래예요.", pos = Vector3.new(186, -20, -282), look = "vip", image = "rbxassetid://94487535064165" },
	{ key = "viking", name = "바이킹 산타", hint = "하늘 높이 흔들리는 배 근처에 있어요.", pos = Vector3.new(-65, 22, -518), look = "viking", image = "rbxassetid://125151267251187" },
	{ key = "rudolph", name = "루돌프와 산타", hint = "네온 무대 위에서 루돌프랑 쉬고 있어요.", pos = Vector3.new(-98, 6, -137), look = "rudolph", image = "rbxassetid://113881079038825" },
	{ key = "golden", name = "황금 산타", hint = "크리스마스의 주인공! 기린 키재기판 옆을 찾아보세요.", pos = Vector3.new(-71, 24, -331), look = "golden", image = "rbxassetid://85564698368142" },
} :: {Santa}

-- the window and the reveal's colours (Christmas red and pine green)
SantaHuntConfig.Theme = {
	accent = Color3.fromRGB(214, 44, 64), accentSoft = Color3.fromRGB(255, 230, 230),
	second = Color3.fromRGB(40, 140, 90), secondSoft = Color3.fromRGB(222, 244, 230),
	ink = Color3.fromRGB(70, 36, 44), bgTop = Color3.fromRGB(255, 238, 238), bgBottom = Color3.fromRGB(226, 244, 232),
}

SantaHuntConfig.Days = #SantaHuntConfig.Santas
SantaHuntConfig.EndUnix = SantaHuntConfig.Start.UnixTimestamp + SantaHuntConfig.Days * 86400

-- the same clock as the attendance events (Studio: the EventNow attribute)
local Opening = require(script.Parent:WaitForChild("OpeningEventConfig"))
function SantaHuntConfig.now(): number
	return Opening.now()
end

-- today's day number 1..Days, or nil outside the event
function SantaHuntConfig.dayNow(unix: number?): number?
	local now = unix or SantaHuntConfig.now()
	local d = math.floor((now - SantaHuntConfig.Start.UnixTimestamp) / 86400) + 1
	if d < 1 or d > SantaHuntConfig.Days then return nil end
	return d
end
function SantaHuntConfig.started(unix: number?): boolean
	return (unix or SantaHuntConfig.now()) >= SantaHuntConfig.Start.UnixTimestamp
end
function SantaHuntConfig.ended(unix: number?): boolean
	return (unix or SantaHuntConfig.now()) >= SantaHuntConfig.EndUnix
end
-- "12/6" for day n (KST)
function SantaHuntConfig.dateText(n: number): string
	local t = os.date("!*t", SantaHuntConfig.Start.UnixTimestamp + 9 * 3600 + (n - 1) * 86400) :: any
	return string.format("%d/%d", t.month, t.day)
end

-- found days as a bit mask (the player attribute SantaFound): bit n-1 = day n
function SantaHuntConfig.has(mask: number?, n: number): boolean
	return bit32.btest(mask or 0, bit32.lshift(1, n - 1))
end
function SantaHuntConfig.count(mask: number?): number
	local c = 0
	for n = 1, SantaHuntConfig.Days do
		if SantaHuntConfig.has(mask, n) then c += 1 end
	end
	return c
end

return SantaHuntConfig

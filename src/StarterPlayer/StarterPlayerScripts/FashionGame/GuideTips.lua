--!strict
-- The first-time tips (user 2026-11-01, D-713), shown with Coach, each once,
-- each skippable:
--   hud      after the place tour: the buttons on the screen (Roblox's on the
--            left, the clock, coins, ♥ 후원, ☰ and the buttons it opens)
--   catalog  the first time the catalog opens
--   bag      the first time the 🎒 bag opens
--   dance    the first time the dance window opens
--   gukbap   the first time the 국밥집 order window opens
--   club     the first time in the club
--   cafe     the first time at the beach cafe
--   job      the first 알바 shift
--   photo    the first time in 오후네컷 (D-715)
--   dj       the first time the DJ turntable's window opens (D-716)
-- Place tips fly the camera to each thing they talk about (D-715).
-- GuideController calls GuideTips.hud() at the end of the tour and
-- GuideTips.start() once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")

local Coach = require(script.Parent:WaitForChild("Coach"))
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))
local GuideConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("GuideConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GuideTips = {}

-- the first descendant called `name` under PlayerGui[guiName] (or with a text containing `text`)
local function find(guiName: string, name: string?, text: string?): () -> Instance?
	return function()
		local root = playerGui:FindFirstChild(guiName)
		if not root then return nil end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("GuiObject") and (name == nil or d.Name == name)
				and (text == nil or ((d:IsA("TextButton") or d:IsA("TextLabel")) and string.find((d :: any).Text, text, 1, true) ~= nil)) then
				return d
			end
		end
		return nil
	end
end

--------------------------------------------------
-- The screen
--------------------------------------------------

-- (D-715, user: right after "준비 끝" the menu button first)
local HUD: {Coach.Step} = {
	-- (D-721: the menu's buttons are out in the top row now, no ☰)
	{ title = "옷걸이 · 카탈로그", text = "옷과 장신구를 찾아 입어 보고 갈아입어요.", target = function() return TopBar.button(4) end },
	{ title = "🎒 가방", text = "산 음식·아이템과 오후네컷에서 찍은 사진이 여기 있어요.", target = function() return TopBar.button(3) end },
	{ title = "♪ 춤", text = "춤을 골라 춰요. 클럽에서는 지금 나오는 곡에 맞춰 춰요.", target = function() return TopBar.button(1) end },
	{ title = "왼쪽 위 · Roblox 버튼", text = "Roblox 기본 버튼이에요. 메뉴(설정·나가기), 채팅, 음성 채팅을 여기서 켜고 꺼요.",
		target = function()
			local inset = GuiService.TopbarInset
			if inset.Min.X <= 0 then return nil end
			return Rect.new(6, inset.Min.Y + 4, inset.Min.X - 6, math.max(inset.Max.Y - 4, inset.Min.Y + 40))
		end },
	{ title = "🕐 시간", text = "오후에는 시간이 흘러요. 실제 30분이 게임 속 하루예요. 해가 지고 밤(18:00~06:00)이 되면 클럽이 문을 열어요.",
		target = find("FashionHudGui", "ClockPill") },
	{ title = "₩ 소지금", text = "내 코인이에요. 게임에 있으면 1분마다 쌓이고, 카페 알바로 더 벌 수 있어요. 음식·아이템을 살 때 써요.",
		target = find("FashionHudGui", "CoinPill") },
	{ title = "♥ 후원", text = "Robux로 오후를 후원하는 버튼이에요. 후원하면 화면 위 배너와 순위표·전광판에 이름과 메시지가 올라가요.",
		target = function() return TopBar.button(5) end },
	-- (D-716, user: the last words, at the guide's own patch)
	{ title = "🐰 언제든 물어봐!", text = "더 궁금한 점은 공원 순위표 앞에 있는 나에게 찾아와!",
		camera = function()
			local spot = GuideConfig.Npc.position
			return CFrame.lookAt(spot + Vector3.new(16, 9, 14), spot + Vector3.new(0, 2, 0))
		end },
}

function GuideTips.hud()
	Coach.run("hud", HUD)
end

--------------------------------------------------
-- Windows
--------------------------------------------------

local CAT = "FashionCatalogGui"
-- the catalog's big window on / off (CatalogController listens to ↗'s Want)
local function catalogBig(on: boolean)
	local button = find(CAT, "ExpandButton")()
	if button then button:SetAttribute("Want", on) end
end
local CATALOG: {Coach.Step} = {
	{ title = "👗 카탈로그", text = "Roblox의 옷·장신구를 찾아 바로 입어 보는 곳이에요. 하나씩 알려 드릴게요." },
	{ title = "🔍 검색", text = "아이템 이름을 써서 찾아요.", target = find(CAT, "SearchBox") },
	{ title = "카테고리", text = "신체·복장·액세서리·얼굴 꾸미기·애니메이션… 옆으로 밀면(드래그) 메뉴가 더 나와요.", target = find(CAT, "MainCategoryStrip") },
	{ title = "세부 카테고리", text = "헤어·얼굴·상의·하의처럼 더 자세히 골라요. 이 줄도 옆으로 밀면 더 있어요.", target = find(CAT, "SubcategoryStrip") },
	{ title = "빠른 메뉴", text = "최근 본 것, 인기, ★ 즐겨찾기, 착용 중, ⚙ 아바타 편집, 옷장. 옆으로 밀면 더 나와요.", target = find(CAT, "DiscoveryBar") },
	{ title = "아이템", text = "[WEAR]를 누르면 바로 입어요. ★를 누르면 즐겨찾기에 담아요. 아래로 내리면 더 많이 나와요.", target = find(CAT, "Results") },
	{ title = "필터", text = "가격·제작자·정렬로 결과를 걸러요.", target = find(CAT, "FixedFilterButton") },
	-- (D-731, user: the ↗ button first, then the big window for the rest; it
	-- closes again when the tip ends, catalogBig below)
	{ title = "↗ 크게 보기", text = "이 버튼을 누르면 카탈로그가 크게 열려요. 내 모습 미리보기, 아바타 편집·옷장, 착용 중인 아이템이 함께 나와요.", target = find(CAT, "ExpandButton") },
	{ title = "미리보기", text = "지금 내 모습이에요. 끌면 돌아가고, 휠·두 손가락으로 크게 볼 수 있어요.",
		before = function() catalogBig(true) end, target = find(CAT, "AvatarViewport") },
	{ title = "⚙ 아바타 편집", text = "장신구의 위치·회전·크기를 세세하게 맞추고, 체형·피부색·메이크업 순서도 바꿔요.", target = find(CAT, "AvatarEditorButton") },
	{ title = "▣ 옷장", text = "지금 입은 코디를 이름 붙여 저장하고, 나중에 한 번에 다시 입어요.", target = find(CAT, "WardrobeButton") },
	{ title = "착용 중인 아이템", text = "입고 있는 것들이에요. [× 해제]로 하나씩 벗어요.", target = find(CAT, "CurrentOutfitFrame") },
	{ title = "되돌리기 · 다시", text = "방금 바꾼 것을 되돌리거나 다시 해요.", target = find(CAT, "UndoButton") },
}

local BAG: {Coach.Step} = {
	{ title = "🎒 가방", text = "산 음식·아이템이 모두 여기 있어요. 누르면 손에 들고, 든 것을 다시 누르면 넣어요.", target = find("FashionInventoryGui", "Bag") },
	{ title = "사진", text = "오후네컷에서 찍은 사진이에요. 누르면 크게 보고, 손에 들거나 지울 수 있어요.", target = find("FashionInventoryGui", nil, "사진") },
}

local DANCE_GUI = "FashionDanceGui"
local DANCE: {Coach.Step} = {
	{ title = "♪ 춤", text = "춤을 골라 춰요. 클럽에서는 지금 나오고 있는 곡에 맞춰 출 수 있어요.", target = find(DANCE_GUI, "DancePanel") },
	{ title = "춤 고르기", text = "추고 싶은 춤을 눌러요. 위의 탭으로 종류를 바꿔요.", target = find(DANCE_GUI, "DanceGrid") },
	{ title = "속도", text = "춤 속도를 느리게·빠르게 맞춰요.", target = find(DANCE_GUI, "TempoRow") },
	{ title = "같이 추기", text = "근처 사람을 누르면 그 사람과 같은 춤을 같은 박자로 춰요. 화면에서 사람을 직접 눌러도 돼요.", target = find(DANCE_GUI, "JoinList") },
	{ title = "멈추기", text = "춤을 멈춰요. 걸어도 멈춰요.", target = find(DANCE_GUI, "StopButton") },
}

--------------------------------------------------
-- Places
--------------------------------------------------

-- (D-715, user: every place tip flies the camera to what it talks about, like
-- the place tour.) Camera helper: a view of a tagged / found part (the
-- nearest to the player), `back` studs out from it toward the player (or
-- along its LookVector) and `up` above.
-- (parts or models: the photo booths are models)
local function cframeOf(i: Instance): CFrame?
	if i:IsA("BasePart") then return i.CFrame end
	if i:IsA("Model") then return i:GetPivot() end
	return nil
end
local function nearest(list: {Instance}): Instance?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bestD = nil, math.huge
	for _, i in ipairs(list) do
		local cf = cframeOf(i)
		if cf and i:IsDescendantOf(workspace) then
			local d = if root then (cf.Position - root.Position).Magnitude else 0
			if d < bestD then best, bestD = i, d end
		end
	end
	return best
end
local function viewOfPart(get: () -> Instance?, back: number, up: number, useFront: boolean?): () -> CFrame?
	return function()
		local thing = get()
		local cf = thing and cframeOf(thing)
		if not cf then return nil end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local away = if useFront then cf.LookVector
			elseif root then Vector3.new(root.Position.X - cf.X, 0, root.Position.Z - cf.Z)
			else cf.LookVector
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 0.01 then away = Vector3.new(1, 0, 0) end
		return CFrame.lookAt(cf.Position + away.Unit * back + Vector3.new(0, up, 0), cf.Position)
	end
end
local function tagged(tag: string, filter: ((any) -> boolean)?): () -> any
	return function()
		local list = {}
		for _, i in ipairs(CollectionService:GetTagged(tag)) do
			if cframeOf(i) and (not filter or filter(i)) then table.insert(list, i) end
		end
		return nearest(list)
	end
end
local function shopCounter(key: string): () -> BasePart?
	return tagged("SnackShop", function(p) return p:GetAttribute("Shop") == key end)
end

local GUKBAP: {Coach.Step} = {
	{ title = "🍲 오후 돼지국밥", text = "국밥을 사면 뚝배기가 손에 들려요. 화면을 누를 때마다 한 숟가락씩 떠먹어요.",
		camera = viewOfPart(shopCounter("Gukbap"), 12, 7) },
	{ title = "테이블에 놓기", text = "국밥을 든 채로 테이블 가까이 가서 '테이블에 놓기'를 누르면 쟁반째 놓여요. 앉아서 '떠먹기'로 먹어요. 놓은 국밥은 나만 먹을 수 있어요.",
		camera = viewOfPart(tagged("GukbapTable"), 9, 7) },
	{ title = "수육 · 함께 먹기", text = "수육 한 접시는 테이블에 놓으면 모두 한 점씩 가져가 먹어요. 공깃밥·물·김치는 무료예요.",
		camera = viewOfPart(tagged("GukbapTable"), 6, 6) },
}

-- the club's spots (BartenderSpot: the item seller stands on it, the
-- bartender 12 studs along the bar, DrinkService)
local function bartenderView(): CFrame?
	local spot = tagged("BartenderSpot")()
	if not spot then return nil end
	-- (their whole body over the bar, the face clear of the card at the bottom)
	local at = (spot.CFrame * CFrame.new(-12, 4, 0)).Position
	return CFrame.lookAt(at + spot.CFrame.LookVector * 24 + Vector3.new(0, 7, 0), at - Vector3.new(0, 2, 0))
end
local function sellerView(): CFrame?
	local spot = tagged("BartenderSpot")()
	if not spot then return nil end
	local at = spot.Position + Vector3.new(0, 4, 0)
	return CFrame.lookAt(at + spot.CFrame.LookVector * 24 + Vector3.new(0, 7, 0), at - Vector3.new(0, 2, 0))
end
local function djView(): CFrame?
	local spot = tagged("DJSpot")()
	if not spot then return nil end
	return CFrame.lookAt(spot.Position + spot.CFrame.LookVector * 26 + Vector3.new(0, 10, 0), spot.Position + Vector3.new(0, 4, 0))
end
-- (a round table on the floor: the VIP balcony's are upstairs)
local CLUB_TABLE = tagged("DrinkTable", function(p) return p.Name == "RoundTable" and ClubConfig.isInClub(p.Position) end)

local CLUB: {Coach.Step} = {
	{ title = "🎧 OHU CLUB", text = "어서 오세요! 클럽에서 할 수 있는 것을 알려 드릴게요.", camera = djView },
	{ title = "♪ 춤 버튼", text = "오른쪽 위 ♪ 버튼으로 춤을 골라 지금 나오는 곡에 맞춰 춰요.", target = function() return TopBar.button(1) end },
	{ title = "노래 목록 · › 스킵", text = "노래 제목 왼쪽 목록 버튼(줄 세 개)에서 다음에 들을 곡을 예약하고, 오른쪽 ›로 스킵 투표를 해요. 클럽 사람 절반이 찬성하면 넘어가요.", target = find(DANCE_GUI, "NowPlaying") },
	{ title = "🍹 바텐더", text = "바에 있는 바텐더에게 '음료 주문'을 눌러 음료(무알코올)를 골라요. 무료 음료도 있어요.", camera = bartenderView },
	{ title = "🍾 음료를 테이블에", text = "음료 병을 든 채 테이블을 누르면 모든 사람·친구만·나만 중에 골라 테이블에 놓아요. 한 번 놓은 음료는 회수할 수 없어요. 테이블이 아닌 곳을 누르면 병째 마셔요.",
		camera = viewOfPart(CLUB_TABLE, 12, 5) },
	{ title = "🥂 테이블에서 마시기", text = "테이블 위 버킷을 누르면 한 잔씩 따라 마셔요.",
		camera = viewOfPart(CLUB_TABLE, 8, 4) },
	{ title = "🎆 불꽃 판매원", text = "바텐더 옆 판매원에게서 스파클러, 스파클러 세트, 무대 콜드 스파크를 사요. 스파클러를 든 채 병을 누르면 불꽃이 튀어요.", camera = sellerView },
	{ title = "🎧 DJ", text = "DJ 부스의 '디제잉하기'에서 DJ 시간을 사면 차례가 와요. DJ는 곡·속도·조명을 바꾸고 큰 전광판에 나와요.", camera = djView },
}

local BEACH_COUNTER = shopCounter("BeachCafe")
local function cafeBackView(): CFrame?
	local counter = BEACH_COUNTER()
	local back = counter and counter.Parent and counter.Parent:FindFirstChild("BackCounter")
	if not counter or not back or not back:IsA("BasePart") then return nil end
	-- from the customers' side, over the counter, at the work bench behind it
	local across = Vector3.new(counter.Position.X - back.Position.X, 0, counter.Position.Z - back.Position.Z)
	if across.Magnitude < 0.01 then return nil end
	return CFrame.lookAt(counter.Position + across.Unit * 10 + Vector3.new(0, 7, 0), back.Position + Vector3.new(0, 2, 0))
end
local CAFE_TABLE = function(): BasePart?
	local counter = BEACH_COUNTER()
	local list = {}
	for _, i in ipairs(CollectionService:GetTagged("CafeTable")) do
		-- (the ground floor's, near the counter: the mezzanine's are overhead)
		if i:IsA("BasePart") and counter and math.abs(i.Position.Y - counter.Position.Y) < 6 then table.insert(list, i) end
	end
	return nearest(list)
end

local CAFE: {Coach.Step} = {
	{ title = "☕ OHU CAFE · Sunset", text = "바다가 보이는 카페예요. 카운터에서 '주문하기'를 누르면 음료·빵·케이크를 골라요.",
		camera = viewOfPart(BEACH_COUNTER, 12, 7) },
	{ title = "케이크 · 함께 먹기", text = "케이크는 테이블 옆에서 눌러 놓으면 모두 한 조각씩 가져가 먹어요.",
		camera = viewOfPart(CAFE_TABLE, 8, 7) },
	{ title = "알바", text = "카운터 안쪽 작업대에서 '알바 시작'을 누르면 카페 직원이 되어 손님에게 음료를 만들어 주고 코인을 벌어요.",
		camera = cafeBackView },
}

local JOB: {Coach.Step} = {
	{ title = "☕ 알바 시작!", text = "이제 카페 직원이에요. 머리 위에 '알바생'이 보여요.", target = find("CafeJobGui", "JobPill") },
	{ title = "주문 목록", text = "왼쪽 '알바 중' 칸을 누르면 주문 목록이 나와요. 손님(플레이어·NPC)이 주문하면 여기에 쌓여요.", target = find("CafeJobGui", "JobPill") },
	{ title = "📱 폰에서는", text = "폰에서는 '알바 중' 칸이 작게 보여요. 목록을 위아래로 끌어서(드래그) 아래쪽 주문까지 확인해요.",
		target = function() return find("CafeJobGui", "Orders")() or find("CafeJobGui", "JobPill")() end },
	{ title = "만들기", text = "작업대에서 [만들기] 또는 '음료 만들기'를 누르면 잠깐 뒤 음료가 손에 들려요. 한 번에 2잔까지 들 수 있어요.",
		camera = cafeBackView },
	{ title = "서빙하기", text = "음료를 들고 주문한 손님에게 가면 그 손님에게 '서빙하기'가 떠요. 누르면 건네주고 코인을 받아요.",
		camera = viewOfPart(CAFE_TABLE, 10, 8) },
	{ title = "테이블 정리", text = "손님이 다 마시고 남긴 빈 컵은 '테이블 정리'로 치우면 코인을 더 받아요.",
		camera = viewOfPart(CAFE_TABLE, 6, 6) },
	{ title = "끝내기", text = "하루에 벌 수 있는 알바 코인에는 한도가 있어요. 그만할 때는 카운터에서 '알바 끝내기'를 눌러요.",
		camera = viewOfPart(BEACH_COUNTER, 10, 6) },
}

-- The DJ turntable's window ('디제잉하기', ClubMusicController), D-716
local MUSIC = "FashionMusicGui"
local DJ: {Coach.Step} = {
	{ title = "🎧 DJ 턴테이블", text = "클럽 음악을 고르는 DJ 창이에요. DJ가 없을 때는 누구나 이 창에서 DJ 시간을 사서 DJ가 될 수 있어요.", target = find(MUSIC, "MusicPanel") },
	{ title = "DJ 되기", text = "DJ 시간을 사면 차례가 와요. 앞사람이 DJ 중이면 대기 순서에 들어가고, 차례가 오면 'DJ 차례' 창에서 부스로 갈지 골라요.", target = find(MUSIC, nil, "DJ") },
	{ title = "🎵 곡 고르기", text = "DJ는 노래 목록에서 지금 틀 곡과 다음 곡을 고르고, 건너뛰거나 일시정지할 수 있어요.", target = find(MUSIC, "MusicListPanel") },
	{ title = "⚡ 속도 · 조명", text = "곡 속도(⚡)와 조명 색, 레이저를 바꿔 클럽 분위기를 만들어요.", target = find(MUSIC, nil, "⚡") },
	{ title = "📺 전광판 · 불꽃", text = "DJ는 뒤의 큰 전광판에 실시간으로 나와요(📺로 켜고 끔). 무대 스파클러로 불꽃도 터뜨릴 수 있어요.", camera = djView },
}

-- the two photo walls (tag PhotoWall: in the 오후네컷 hall, and outside), in a
-- fixed order; seen from in front of the face the photos are on
local function photoWall(i: number): BasePart?
	local list = {}
	for _, w in ipairs(CollectionService:GetTagged("PhotoWall")) do
		if w:IsA("BasePart") and w:IsDescendantOf(workspace) then table.insert(list, w) end
	end
	table.sort(list, function(a, b) return a:GetFullName() > b:GetFullName() end)
	return list[i]
end
local function photoWallView(i: number): CFrame?
	local w = photoWall(i)
	if not w then return nil end
	-- (the photos are on its Face side: "Back" = against the LookVector)
	local out = if w:GetAttribute("Face") == "Back" then -w.CFrame.LookVector else w.CFrame.LookVector
	return CFrame.lookAt(w.Position + out * (w.Size.X * 0.9 + 4) + Vector3.new(0, 2, 0), w.Position)
end

-- 오후네컷 (D-715): the booths and the photo wall
local PHOTO: {Coach.Step} = {
	-- (the booths are closed rooms east of the lobby: seen from the lobby)
	{ title = "📸 오후네컷", text = "친구랑 네 컷 사진을 찍는 사진관이에요.",
		camera = function() return CFrame.lookAt(Vector3.new(92, 22, -72), Vector3.new(150, 8, -64)) end },
	{ title = "사진 찍기", text = "포토부스 앞에서 E 키(폰은 화면의 '사진 찍기' 버튼)를 누르면 들어가요. 포즈를 고르고 네 컷을 찍어요. 친구는 '같이 찍기'로 함께 들어와요.",
		-- (D-717, user's shot: from the hall, the PINK / SKY ROOM doors on the wall at z -80)
		camera = function() return CFrame.lookAt(Vector3.new(150, 11, -99), Vector3.new(150, 10, -80)) end }, -- (closer, D-718: the cabinet near the camera showed white)
	-- (D-718, user: both photo walls, each outlined with a box)
	{ title = "포토월 ①", text = "찍은 사진은 사진첩(가방의 사진 탭)에 남아요. 포토월 앞에서 '사진 붙이기'를 누르면 내 사진을 벽에 붙여 모두에게 보여 줄 수 있어요.",
		camera = function() return photoWallView(1) end, mark = function() return photoWall(1) end },
	{ title = "포토월 ②", text = "포토월은 두 곳이에요. 여기에도 사진을 붙일 수 있어요.",
		camera = function() return photoWallView(2) end, mark = function() return photoWall(2) end },
}

--------------------------------------------------
-- Triggers
--------------------------------------------------

-- runs `key` the first time `object` (found later, maybe) becomes visible
local function onShown(key: string, steps: {Coach.Step}, getObject: () -> Instance?, only: (() -> boolean)?, onEnd: (() -> ())?)
	task.spawn(function()
		local object: Instance? = nil
		while not object do
			object = getObject()
			if not object then task.wait(1) end
		end
		local gui = object :: GuiObject
		local function check()
			if gui.Visible and Coach.wants(key) and (not only or only()) then task.delay(0.4, function()
				if gui.Visible then Coach.run(key, steps, nil, onEnd) end
			end) end
		end
		gui:GetPropertyChangedSignal("Visible"):Connect(check)
		check()
	end)
end

function GuideTips.start()
	onShown("catalog", CATALOG, function()
		local g = playerGui:FindFirstChild(CAT)
		return g and g:FindFirstChild("MainFrame")
	end, nil, function() catalogBig(false) end) -- (D-731: the big window closes at the end)
	onShown("bag", BAG, function()
		local g = playerGui:FindFirstChild("FashionInventoryGui")
		return g and g:FindFirstChild("Bag")
	end)
	onShown("dance", DANCE, function()
		local g = playerGui:FindFirstChild(DANCE_GUI)
		return g and g:FindFirstChild("DancePanel")
	end)
	-- (D-717, user: only for whoever holds the DJ time)
	onShown("dj", DJ, function()
		local g = playerGui:FindFirstChild(MUSIC)
		return g and g:FindFirstChild("MusicPanel")
	end, function()
		return ReplicatedStorage.FashionGame:GetAttribute("ClubDJ") == player.UserId
	end)
	onShown("gukbap", GUKBAP, function()
		for _, d in ipairs(playerGui:GetDescendants()) do
			if d.Name == "Menu_Gukbap" and d:IsA("GuiObject") then return d end
		end
		return nil
	end)
	-- the first 알바 shift
	local function watchJob(character: Model)
		character:GetAttributeChangedSignal("CafeJob"):Connect(function()
			if character:GetAttribute("CafeJob") then task.delay(1, Coach.run, "job", JOB) end
		end)
	end
	player.CharacterAdded:Connect(watchJob)
	if player.Character then watchJob(player.Character) end
	-- (D-725) once, after FeedbackConfig.NudgeMinutes of this visit: ask for 의견
	require(script.Parent:WaitForChild("Feedback")) -- (builds the 💬 button)
	local FeedbackConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("FeedbackConfig"))
	local FEEDBACK_ASK: {Coach.Step} = {
		{ title = "💬 오후 어때요?", text = "불편한 점이나 있었으면 하는 게 있으면 이 💬 버튼으로 알려 주세요. 개발자가 하나하나 직접 읽어요!",
			target = function() return TopBar.button(2) end },
	}
	local joinedAt = os.clock()
	-- places: in the club, near the beach cafe's counter
	task.spawn(function()
		while true do
			task.wait(1)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and not Coach.isRunning() then
				if Coach.wants("feedbackAsk") and os.clock() - joinedAt > FeedbackConfig.NudgeMinutes * 60
					and player:GetAttribute("TutorialDone") == true then
					Coach.run("feedbackAsk", FEEDBACK_ASK)
				elseif Coach.wants("club") and ClubConfig.isInClub(root.Position) then
					Coach.run("club", CLUB, true) -- (D-729: then facing away from the lift)
				elseif Coach.wants("photo") and (function()
					-- inside the 오후네컷 building (Hongdae_Layout.OhuFourCuts), under its roof
					local layout = workspace:FindFirstChild("Hongdae_Layout")
					local building = layout and layout:FindFirstChild("OhuFourCuts")
					if not building or not building:IsA("Model") then return false end
					local cf, size = building:GetBoundingBox()
					local p = cf:PointToObjectSpace(root.Position)
					return math.abs(p.X) < size.X / 2 - 2 and math.abs(p.Z) < size.Z / 2 - 2 and root.Position.Y < cf.Y + size.Y / 2
				end)() then
					Coach.run("photo", PHOTO)
				elseif Coach.wants("cafe") then
					for _, counter in ipairs(CollectionService:GetTagged("SnackShop")) do
						if counter:IsA("BasePart") and counter:GetAttribute("Shop") == "BeachCafe"
							and (counter.Position - root.Position).Magnitude < 28 then
							Coach.run("cafe", CAFE)
						end
					end
				end
			end
		end
	end)
end

return GuideTips

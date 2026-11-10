--!strict
-- First-visit tutorial and the guide NPC by the ranking boards (user
-- 2026-11-01, D-712). GuideController (client) shows both; GuideService
-- (server) spawns the NPC and remembers who has seen the tutorial
-- (wallet.tutorial).
--
-- Places: at = a spot on the ground at the place (the 길 안내 marker and line
-- go there), look = what the camera looks at in the tour (the building).

local GuideConfig = {}

-- eye: where the tour's camera stands (optional; else out beyond `at`)
export type Place = { key: string, name: string, emoji: string, text: string, at: Vector3, look: Vector3, eye: Vector3? }

GuideConfig.Places = {
	-- (the tour's first words, user 2026-11-01, D-715)
	spawn = { key = "spawn", name = "오후", emoji = "👋", text = "안녕하세요. 오후에 오신 것을 환영합니다. 동네를 한 바퀴 둘러볼게요!",
		at = Vector3.new(-30, 3, -36), look = Vector3.new(-30, 3, -36) },
	club = { key = "club", name = "OHU CLUB", emoji = "🎧", text = "밤(18:00~06:00)에 문을 여는 클럽이에요. 춤추고, 노래를 고르고, DJ도 될 수 있어요.",
		at = Vector3.new(41, 3.6, -210), look = Vector3.new(105, 30, -210) },
	photo = { key = "photo", name = "오후네컷", emoji = "📸", text = "친구랑 네 컷 사진을 찍는 사진관이에요. 찍은 사진은 사진첩에 남아요.",
		at = Vector3.new(50, 3, -54), look = Vector3.new(105, 20, -79) },
	gukbap = { key = "gukbap", name = "오후 돼지국밥", emoji = "🍲", text = "국밥을 사서 자리에서 먹어요. 수육 한 접시는 테이블에 놓고 다 같이 나눠 먹어요.",
		at = Vector3.new(46, 3, -319), look = Vector3.new(90, 15, -330) },
	oh24 = { key = "oh24", name = "OH24 편의점 (준비 중)", emoji = "🏪", text = "과자·음료·컵라면을 코인으로 사는 편의점이에요. 지금은 오픈 준비 중이에요.",
		at = Vector3.new(-68, 1, 118), look = Vector3.new(-88, 2, 118), eye = Vector3.new(-22, 24, 112) },
	cafe = { key = "cafe", name = "OHU CAFE · Sunset", emoji = "☕", text = "바다가 보이는 카페예요. 음료와 케이크를 먹고, 카운터 안쪽에서 알바도 할 수 있어요.",
		at = Vector3.new(-206, 3, 272), look = Vector3.new(-260, 18, 276) },
	beach = { key = "beach", name = "해변", emoji = "🏖", text = "모래사장과 바다예요. 튜브를 타고 물놀이를 해요.",
		at = Vector3.new(-215, 1, -40), look = Vector3.new(-250, 0, -40) },
	hanok = { key = "hanok", name = "광화문 · 한옥 마을", emoji = "🏯", text = "광화문 앞 마당과 해태 앞은 사진 찍기 좋은 곳이에요.",
		at = Vector3.new(120, 1, 165), look = Vector3.new(165, 18, 215), eye = Vector3.new(55, 48, 110) },
	park = { key = "park", name = "OHU LAND (준비 중)", emoji = "🎡", text = "계단 위 놀이공원은 곧 열려요. 지금은 문 앞 광장까지 올라갈 수 있어요.",
		at = Vector3.new(-97, 17, -250), look = Vector3.new(-100, 30, -330) },
	guide = { key = "guide", name = "순위표 · 안내원", emoji = "🙋", text = "기부·레벨 순위표가 있어요. 앞에서 돌아다니는 토끼 안내원에게 무엇이든 물어보세요!",
		at = Vector3.new(-112, 1, -56), look = Vector3.new(-120, 6, -60) },
} :: {[string]: Place}

-- (the first-visit tour of these places is gone, D-845)

-- The guide NPC: walks about the paved square in front of the 기부 순위표
-- (user 2026-11-01, D-713: the area the user circled; between the boards
-- before), never out of the box zoneMin..zoneMax (the road is past z -45).
-- It stops and turns to anyone who comes within StopDistance.
GuideConfig.Npc = {
	position = Vector3.new(-115, 0.6, -56),
	facing = Vector3.new(1, 0, 0),
	name = "안내원",
	look = "Guide", -- NpcLooks
	zoneMin = Vector3.new(-123, 0, -64),
	zoneMax = Vector3.new(-106, 0, -48),
	walkSpeed = 5,
	stopDistance = 10,
	walkAnimation = 913402848, -- the standard R15 walk
}

-- 무엇이든 물어보세요: question → answer (and the place to show, if any).
export type Faq = { q: string, a: string, place: string?, action: string? }
GuideConfig.Faq = {
	{ q = "클럽은 어디 있고 언제 열어요?", a = "큰길 동쪽의 검은 건물 OHU CLUB이에요. 밤 18:00~06:00에만 들어갈 수 있어요(게임 시간, 오른쪽 위 시계).", place = "club" },
	{ q = "춤은 어떻게 춰요?", a = "화면 오른쪽 위 ♪ 버튼을 눌러 춤을 골라요. 근처 사람을 누르면 같이 출 수 있어요.", place = "club" },
	{ q = "노래를 바꾸거나 넘길 수 있어요?", a = "클럽 위 노래 제목 왼쪽 목록 버튼(줄 세 개)에서 노래를 예약하고, 오른쪽 ›로 스킵 투표를 해요. 클럽 사람 절반이 찬성하면 넘어가요.", place = "club" },
	{ q = "DJ는 어떻게 해요?", a = "클럽의 🎵 버튼 창에서 DJ 시간을 사면 차례가 와요. DJ 턴테이블 앞에서 🎵 버튼을 누르면 디제잉을 시작해요. DJ는 노래·속도·조명을 바꿀 수 있어요.", place = "club" },
	{ q = "사진은 어디서 찍어요?", a = "오후네컷 사진관에서 친구랑 네 컷을 찍어요. 화면의 📸 버튼으로 지금 화면도 찍을 수 있어요.", place = "photo" },
	{ q = "코인은 어떻게 벌어요?", a = "게임에 있으면 1분마다 코인이 쌓여요. 비치 카페에서 알바를 하면 더 벌 수 있어요.", place = "cafe" },
	{ q = "알바는 어떻게 해요?", a = "비치 카페 카운터 안쪽 작업대에서 '알바 시작'을 눌러요. 주문 목록에서 [만들기] → 손님에게 [서빙하기]를 하면 코인을 받아요.", place = "cafe" },
	{ q = "음식은 어디서 먹어요?", a = "국밥집·카페에서 사요(OH24 편의점은 오픈 준비 중이에요). 손에 든 음식을 누르면 한 입씩 먹고, 케이크·수육은 테이블에 놓고 다 같이 나눠 먹어요.", place = "gukbap" },
	{ q = "옷은 어떻게 갈아입어요?", a = "오른쪽 위 옷걸이 버튼으로 카탈로그를 열어 입어 보고, ⚙ 아바타 편집에서 장신구 위치·크기도 바꿀 수 있어요." },
	{ q = "멀리 빨리 가려면요?", a = "길가의 버스 정류장 표지판을 누르면 다른 정류장으로 바로 가요. 지하철 출구 계단 아래에서도 갈 곳을 고를 수 있어요." },
	{ q = "물놀이는 어디서 해요?", a = "서쪽 해변에서 튜브를 타고 바다에 들어가요.", place = "beach" },
	{ q = "놀이공원은 언제 열어요?", a = "OHU LAND는 지금 준비 중이에요. 계단 위 문 앞 광장까지는 올라갈 수 있어요.", place = "park" },
	{ q = "국밥을 테이블에 놓으면 남도 먹어요?", a = "아니요, 테이블에 놓은 국밥은 놓은 사람만 떠먹어요. 수육 한 접시와 케이크는 테이블에 놓으면 모두 한 조각씩 가져가 먹어요.", place = "gukbap" },
	-- (D-725) action = "feedback": the button opens 💬 의견 보내기
	{ q = "💬 불편한 점·바라는 점 보내기", a = "버그, 불편한 점, 있었으면 하는 것 무엇이든 알려 주세요! 개발자가 하나하나 직접 읽어요. 화면 오른쪽 위 💬 버튼으로도 보낼 수 있어요.", action = "feedback" },
} :: {Faq}

-- How long the 길 안내 marker stays (it goes as soon as the player arrives).
GuideConfig.WaypointSeconds = 90
GuideConfig.ArriveDistance = 14

return GuideConfig

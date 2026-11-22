--!strict
-- (D-1366, user 2026-11-13, with a mock-up "한국의 오후 · OHU GRAND OPENING 출석 이벤트":
-- "오픈 이벤트 추가하자") The attendance events. One attendance a day (the day turns at 05:00
-- KST), not in a row, Goal of them to finish; the n-th attendance gives Rewards[n]: coins, the
-- event's limited photo frame at the 7th, its permanent title (over the nickname) at the 14th.
-- Each reward once per account. OpeningEventService gives them; OpeningEventController shows the
-- window (on the day's first visit, and from the 🎁 button while an event runs).
-- (D-1874, user 2026-11-21: "겨울 출석 이벤트 오후의 첫눈 바로 만들어", right after the opening
-- event) several events, one after another: `Events` in order, `current()` = the one running now.
--   opening  OHU GRAND OPENING   2026-11-13 ~ 12-05   wallet.opening        FOUNDING MEMBER
--   winter   오후의 첫눈          (off since D-1878: the mini Santa hunt instead)
-- The top-level Start / Days / Goal / FrameKey / TitleText / Rewards / EndUnix / ended() stay the
-- opening event's (EconomyConfig.welcomeGift ends with it).

local OpeningEventConfig = {}

export type Reward = { coins: number?, frame: boolean?, title: boolean? }
export type Event = {
	key: string, Start: DateTime, Days: number, Goal: number, FrameKey: string, TitleKey: string,
	TitleText: string, Rewards: {Reward}, EndUnix: number,
	-- the window's words and colours
	small: string, title: string, sub: string, limited: string, titleHex: string,
	accent: Color3, accentSoft: Color3, second: Color3, secondSoft: Color3, special: Color3, ink: Color3,
	bgTop: Color3, bgBottom: Color3, plate: Color3, plateText: Color3, plateEdge: Color3,
	frameName: string, -- the reveal's line for the frame
	label: string, -- the coin toast's words, a format ("오픈 출석 %d일차")
	titleName: string, -- the reveal's line for the title
}

local function coinsAndGifts(): {Reward}
	return {
		{ coins = 5 }, { coins = 10 }, { coins = 15 }, { coins = 20 }, { coins = 25 }, { coins = 30 },
		{ frame = true },
		{ coins = 35 }, { coins = 40 }, { coins = 45 }, { coins = 50 }, { coins = 55 }, { coins = 60 },
		{ title = true },
	}
end

-- (D-1693, user 2026-11-17: the attendance day turns at 05:00 KST, not midnight: the club opens 18:00 ~ 06:00,
-- so a night out stays one day) day 1 = 2026-11-13 05:00 KST ~ 11-14 05:00, and so on
local opening: Event = {
	key = "opening",
	Start = DateTime.fromUniversalTime(2026, 11, 12, 20, 0, 0), -- (= 2026-11-13 05:00 KST; 15:00 UTC = 00:00 KST until D-1693)
	-- (D-1875, user 2026-11-21: "이틀 늘리자") 21 → 23 days, to 2026-12-06 05:00 KST: someone who first comes
	-- on day 10 (11/22) can still reach 14 by coming every day
	Days = 23, Goal = 14, FrameKey = "opening2026", TitleKey = "Founding", TitleText = "FOUNDING MEMBER",
	Rewards = coinsAndGifts(), EndUnix = 0,
	small = "한국의 오후 · OHU GRAND OPENING", title = "출석 이벤트 💖", sub = "매일 오후에 놀러 오고, 특별한 선물 받아 가세요!",
	-- (D-1695, user 2026-11-17: the line's words)
	limited = '👑 한정 칭호 <font color="#FFAA5A">FOUNDING MEMBER</font> 증정. 모두에게 보이는 내 아이디 위에 뜨는 한정 칭호 아이템으로 해당 칭호는 이벤트 종료 후 재판매하지 않습니다.',
	titleHex = "#FF5CA8",
	accent = Color3.fromRGB(255, 92, 168), accentSoft = Color3.fromRGB(255, 224, 238),
	second = Color3.fromRGB(176, 140, 235), secondSoft = Color3.fromRGB(236, 226, 252),
	special = Color3.fromRGB(246, 196, 80), ink = Color3.fromRGB(88, 50, 120),
	bgTop = Color3.fromRGB(255, 226, 240), bgBottom = Color3.fromRGB(236, 226, 252),
	plate = Color3.fromRGB(40, 22, 12), plateText = Color3.fromRGB(255, 170, 90), plateEdge = Color3.fromRGB(255, 150, 60),
	frameName = "오픈 기념 한정 프레임 획득!", label = "오픈 출석 %d일차", titleName = "한정 칭호 FOUNDING MEMBER 획득!",
}

-- (D-1874) 오후의 첫눈: starts the moment the opening event ends (2026-12-06 05:00 KST since D-1875; 12-04 before), 26 days
-- (the last day is 12/31 05:00 ~ 2027-01-01 05:00 KST), 14 to finish; icy blue and lilac
local winter: Event = {
	key = "winter",
	Start = DateTime.fromUniversalTime(2026, 12, 5, 20, 0, 0), -- (= 2026-12-06 05:00 KST)
	Days = 26, Goal = 14, FrameKey = "winter2026", TitleKey = "Winter", TitleText = "WINTER 2026",
	Rewards = coinsAndGifts(), EndUnix = 0,
	small = "OHU WINTER EVENT · 오후의 첫눈", title = "출석 이벤트 ❄️", sub = "눈 오는 오후에 놀러 오고, 겨울 선물 받아 가세요!",
	limited = '❄️ 한정 칭호 <font color="#9FDBFF">WINTER 2026</font> 증정. 모두에게 보이는 내 아이디 위에 뜨는 한정 칭호 아이템으로 해당 칭호는 이벤트 종료 후 재판매하지 않습니다.',
	titleHex = "#3C8CE6",
	accent = Color3.fromRGB(60, 140, 230), accentSoft = Color3.fromRGB(220, 236, 255),
	second = Color3.fromRGB(140, 150, 232), secondSoft = Color3.fromRGB(230, 232, 252),
	special = Color3.fromRGB(120, 200, 255), ink = Color3.fromRGB(40, 60, 110),
	bgTop = Color3.fromRGB(226, 242, 255), bgBottom = Color3.fromRGB(236, 232, 255),
	plate = Color3.fromRGB(18, 32, 68), plateText = Color3.fromRGB(170, 222, 255), plateEdge = Color3.fromRGB(110, 190, 255),
	frameName = "겨울 한정 프레임 획득!", label = "겨울 출석 %d일차", titleName = "한정 칭호 WINTER 2026 획득!",
}

-- (D-1878, user 2026-11-22: "겨울 출석 말고 미니 산타 찾기로 할 거") the winter attendance event is off: after the
-- opening event comes the mini Santa hunt (SantaHuntConfig). `winter` stays defined but is not in the list.
OpeningEventConfig.Events = { opening } :: {Event}
for _, ev in ipairs(OpeningEventConfig.Events) do
	ev.EndUnix = ev.Start.UnixTimestamp + ev.Days * 86400
end
function OpeningEventConfig.find(key: string?): Event?
	for _, ev in ipairs(OpeningEventConfig.Events) do
		if ev.key == key then return ev end
	end
	return nil
end
function OpeningEventConfig.findByTitle(titleKey: string): Event?
	for _, ev in ipairs(OpeningEventConfig.Events) do
		if ev.TitleKey == titleKey then return ev end
	end
	return nil
end

-- the opening event's fields at the top level, as before
OpeningEventConfig.Opening = opening
OpeningEventConfig.Winter = winter
OpeningEventConfig.Start = opening.Start
OpeningEventConfig.Days = opening.Days
OpeningEventConfig.Goal = opening.Goal
OpeningEventConfig.FrameKey = opening.FrameKey
OpeningEventConfig.TitleKey = "founding"
OpeningEventConfig.TitleText = opening.TitleText
OpeningEventConfig.Rewards = opening.Rewards

-- (D-1873) "now" for the event: the real clock; in Studio the ReplicatedStorage.FashionGame attribute
-- EventNow (a unix time, Studio only) stands in for it, to test the last day / after the end
function OpeningEventConfig.now(): number
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then
		local fg = game:GetService("ReplicatedStorage"):FindFirstChild("FashionGame")
		local override = fg and fg:GetAttribute("EventNow")
		if typeof(override) == "number" then return override end
	end
	return DateTime.now().UnixTimestamp
end

-- (D-1873) the opening event's end: day 23 ends 2026-12-06 05:00 KST (D-1875). After it the opening gift
-- stops (EconomyConfig.welcomeGift) and the opening frame is no longer shown to people who did
-- not get it (PhotoConfig hideAfter). Titles and frames stay with the people who got them.
OpeningEventConfig.EndUnix = opening.EndUnix
function OpeningEventConfig.ended(unix: number?): boolean
	return (unix or OpeningEventConfig.now()) >= opening.EndUnix
end

-- the event running now (nil between events)
function OpeningEventConfig.current(unix: number?): Event?
	local now = unix or OpeningEventConfig.now()
	for _, ev in ipairs(OpeningEventConfig.Events) do
		if now >= ev.Start.UnixTimestamp and now < ev.EndUnix then return ev end
	end
	return nil
end

-- the day number (1 = the first day) of `ev` (default: the event running now), or nil outside it
function OpeningEventConfig.dayNow(unix: number?, ev: Event?): number?
	local now = unix or OpeningEventConfig.now()
	local e = ev or OpeningEventConfig.current(now)
	if not e then return nil end
	local d = math.floor((now - e.Start.UnixTimestamp) / 86400) + 1
	if d < 1 or d > e.Days then return nil end
	return d
end

-- "11/13 ~ 12/3" (KST)
function OpeningEventConfig.periodText(ev: Event?): string
	local e = ev or OpeningEventConfig.current() or opening
	local first = os.date("!*t", e.Start.UnixTimestamp + 9 * 3600) :: any
	local last = os.date("!*t", e.Start.UnixTimestamp + 9 * 3600 + (e.Days - 1) * 86400) :: any
	return string.format("%d/%d ~ %d/%d", first.month, first.day, last.month, last.day)
end

function OpeningEventConfig.rewardText(r: Reward, ev: Event?): string
	if r.coins then return string.format("%d 코인", r.coins) end
	if r.frame then return "한정 포토 프레임" end
	if r.title then return (ev or opening).TitleText end
	return ""
end

return OpeningEventConfig

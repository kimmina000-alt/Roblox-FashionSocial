--!strict
-- (D-1366, user 2026-11-13, with a mock-up "한국의 오후 · OHU GRAND OPENING 출석 이벤트":
-- "오픈 이벤트 추가하자") The opening attendance event: 21 days from 2026-11-13 00:00 KST, one
-- attendance a day (KST days) at the first visit of that day, not in a row, 14 to finish.
-- The n-th attendance gives Rewards[n]: coins, the limited photo frame at the 7th, the
-- permanent FOUNDING MEMBER title (before the nickname) at the 14th. Each reward once per
-- account (wallet.opening). OpeningEventService gives them; OpeningEventController shows the
-- window (on the day's first visit, and from the 🎁 button while the event runs).

local OpeningEventConfig = {}

OpeningEventConfig.Start = DateTime.fromUniversalTime(2026, 11, 12, 15, 0, 0) -- (= 2026-11-13 00:00 KST)
OpeningEventConfig.Days = 21
OpeningEventConfig.Goal = 14
OpeningEventConfig.FrameKey = "opening2026" -- PhotoConfig.Frames
OpeningEventConfig.TitleKey = "founding"
OpeningEventConfig.TitleText = "FOUNDING MEMBER"

export type Reward = { coins: number?, frame: boolean?, title: boolean? }
OpeningEventConfig.Rewards = {
	{ coins = 5 }, { coins = 10 }, { coins = 15 }, { coins = 20 }, { coins = 25 }, { coins = 30 },
	{ frame = true },
	{ coins = 35 }, { coins = 40 }, { coins = 45 }, { coins = 50 }, { coins = 55 }, { coins = 60 },
	{ title = true },
} :: {Reward}

-- the event's day number now (1 = the first day), or nil outside the 21 days
function OpeningEventConfig.dayNow(unix: number?): number?
	local now = unix or DateTime.now().UnixTimestamp
	local d = math.floor((now - OpeningEventConfig.Start.UnixTimestamp) / 86400) + 1
	if d < 1 or d > OpeningEventConfig.Days then return nil end
	return d
end

-- "11/13 ~ 12/3" (KST)
function OpeningEventConfig.periodText(): string
	local first = os.date("!*t", OpeningEventConfig.Start.UnixTimestamp + 9 * 3600) :: any
	local last = os.date("!*t", OpeningEventConfig.Start.UnixTimestamp + 9 * 3600 + (OpeningEventConfig.Days - 1) * 86400) :: any
	return string.format("%d/%d ~ %d/%d", first.month, first.day, last.month, last.day)
end

function OpeningEventConfig.rewardText(r: Reward): string
	if r.coins then return string.format("%d 코인", r.coins) end
	if r.frame then return "한정 포토 프레임" end
	if r.title then return "FOUNDING MEMBER" end
	return ""
end

return OpeningEventConfig

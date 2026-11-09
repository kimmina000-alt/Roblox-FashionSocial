--!strict
-- In-game coins (🪙, D-064). Rates and prices are explained in
-- docs/01_SYSTEMS/ECONOMY.md; change them here only.
--
-- Earning = a small passive amount while active + bigger bonuses for
-- activities (user, 2026-10-20: "머무르는 시간에 따라 조금씩 오르고 활동하면
-- 더 주는 방식"). Daily caps keep AFK/repeat farming in check.
-- Spending (sinks): coin frames (PhotoConfig.Frames, price = "coins") and
-- coin drinks (ClubConfig.Drinks[].coins).

local EconomyConfig = {}

EconomyConfig.CurrencyName = "코인"
EconomyConfig.Icon = "💰" -- 🪙 is not in the Roblox font (shows a box)
EconomyConfig.MaxBalance = 99999
-- Opening gift (user 2026-11-02, D-754): every player gets this many coins
-- once, on their first visit. Only for the opening period: set it to nil when
-- the period ends (docs/00_PROJECT/LAUNCH_CHECKLIST.md). It replaced the
-- testing top-up (D-418), which put anyone under 100 back at 100 on every visit.
EconomyConfig.WelcomeCoins = 50 -- (100 until D-758, user: not much to spend coins on yet)

-- (attendance coins StreakCoins D-775: removed with the whole system, D-803, user)

-- Economy v2, first test (user, 2026-10-22; ECONOMY.md, D-074/D-083):
-- 1 coin per minute online, whether the player moves or not, no daily cap,
-- activity bonuses off. XP back on (user 2026-10-27): 1 XP per minute online,
-- shown under the player's id above the avatar (NameTagService).
EconomyConfig.XPEnabled = true

-- (D-1101, user 2026-11-09: "음식 사 먹으면 xp 올라가는 시스템 추가. 몇씩 오르게
-- 하는 게 좋을지 게임 시스템 분석해서 논리적으로 계산해서 제안할 것")
-- XP for buying food and drinks, on top of 1 XP a minute online:
--   coin foods: half the price in XP, at least 1 (a coin is a minute online,
--   so spending every coin on food adds at most half again to the XP of time);
--   Robux foods: a flat 10 (paying is not a way up the level board);
--   free items: none (water, rice, barley tea: no farming by tapping);
--   at most DailyCap XP a day from food (= the XP of 50 minutes online).
-- Given when the order is paid (to the cafe staff too). Days are UTC.
EconomyConfig.FoodXP = {
	Enabled = true,
	Rate = 0.5, -- XP per coin of the price
	Min = 1,
	Robux = 10,
	DailyCap = 50,
}
EconomyConfig.BonusesEnabled = false
EconomyConfig.PassiveNeedsActivity = false

-- Passive: every PassiveSeconds (only while active when PassiveNeedsActivity,
-- i.e. moved or danced within ActiveWindow seconds). After PassiveFullMinutes
-- per day it drops to the reduced amount.
EconomyConfig.PassiveSeconds = 60
EconomyConfig.PassiveAmount = 1
EconomyConfig.PassiveFullMinutes = math.huge
EconomyConfig.PassiveReducedAmount = 1
EconomyConfig.ActiveWindow = 180

-- Activity bonuses: amount, how many per day at full amount, amount after.
export type Bonus = { amount: number, perDay: number, after: number, text: string }
EconomyConfig.Bonuses = {
	DailyLogin = { amount = 20, perDay = 1, after = 0, text = "오늘 첫 접속" },
	PhotoSaved = { amount = 15, perDay = 5, after = 3, text = "인생네컷 저장" },
	PhotoGroup = { amount = 10, perDay = 5, after = 0, text = "친구와 함께 찍기" },
	Dance5Min = { amount = 5, perDay = 12, after = 0, text = "클럽에서 5분 춤" },
	WallPost = { amount = 5, perDay = 3, after = 0, text = "포토월에 사진 붙이기" },
} :: {[string]: Bonus}

return EconomyConfig

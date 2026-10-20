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

-- Passive: every PassiveSeconds while active (moved or danced within
-- ActiveWindow seconds). After PassiveFullMinutes per day it drops to the
-- reduced amount.
EconomyConfig.PassiveSeconds = 60
EconomyConfig.PassiveAmount = 2
EconomyConfig.PassiveFullMinutes = 120
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

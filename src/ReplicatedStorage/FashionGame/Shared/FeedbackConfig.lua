--!strict
-- 💬 의견 보내기 (user 2026-11-01, D-725): players send bugs, ideas and
-- complaints; only the game's owner reads them (FeedbackService keeps them in
-- a DataStore, the owner's 📥 tab in the same window lists them).
-- Opened from three places: the 💬 button in the top row (TopButton, for the
-- first weeks: set false to hide it later), the guide NPC's question list
-- and, after NudgeMinutes of a visit, the window opening by itself once
-- (D-1031; the first one-time tip in GuideTips went with D-850).

return {
	TopButton = true,
	NudgeMinutes = 20,
	MaxLength = 300,
	CooldownSeconds = 90, -- between two messages from one player
	Kinds = {
		{ key = "bug", label = "🐞 버그" },
		{ key = "idea", label = "💡 개선" },
		{ key = "complaint", label = "😤 불만" },
		{ key = "other", label = "💬 기타" },
	},
	ListSize = 60, -- how many of the newest the owner's tab shows
	-- (D-1013, user 2026-11-08: "의견 주면 코인 드리자. 엉뚱한 거 보낼 수 잇으니까 확인 후 지급으로 할까" / "확인 후 지급, 50코인으로 해") the owner's 🎁 on a
	-- message in the 📥 tab gives its sender this many coins, once per message
	-- (online: at once with a toast; offline: on their next visit)
	RewardCoins = 50,
}

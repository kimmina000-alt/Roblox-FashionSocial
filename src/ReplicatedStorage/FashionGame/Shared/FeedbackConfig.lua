--!strict
-- 💬 의견 보내기 (user 2026-11-01, D-725): players send bugs, ideas and
-- complaints; only the game's owner reads them (FeedbackService keeps them in
-- a DataStore, the owner's 📥 tab in the same window lists them).
-- Opened from three places: the 💬 button in the top row (TopButton, for the
-- first weeks: set false to hide it later), the guide NPC's question list
-- and a one-time ask after NudgeMinutes of play (GuideTips, tip "feedbackAsk").

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
}

--!strict
-- (D-1133, user 2026-11-10: "각 장소마다 쓰레기통 만들어서 아이템 버릴 수 있게 하기 /
-- 쓰레기통 이름 Trashcan 으로 군데군데 배치해 놨음. / 버린 아이템은 1시간 보관하다가
-- 사라짐. 그 안에 다른 사람이 쓰레기통 열어서 가지고 갈 수 있음. / 각 쓰레기통 칸은
-- 개별임. 쓰레기통 아이템간 쓰레기통끼리 공유 안 함.")
-- Parts / models named "Trashcan" in Workspace (placed by hand) get an "열기"
-- prompt. The window shows what is in that can (tap = take it) and what you
-- carry that can go in (tap = throw it in). Each can keeps its own items.

local TrashConfig = {}

TrashConfig.Name = "Trashcan"
TrashConfig.KeepSeconds = 3600 -- 1시간, then the item is gone
TrashConfig.Distance = 12 -- studs from the can to throw in / take out
TrashConfig.MaxItems = 40 -- per can (the oldest goes first when it is full)

-- (D-1310, user 2026-11-11: "쓰레기통에 랜덤으로 구겨진 영수증이랑 빈플라스틱컵, 담배꽁초
-- 같은 아이템 넣어 줘") every can starts with a few bits of junk, chosen at
-- random, and gets one more now and then (up to JunkMax). No cigarette butts
-- (no tobacco in the game, content rule): a tissue and a snack bag instead.
-- They can be taken out (held, then thrown away again) like anything else.
TrashConfig.Junk = {
	{ key = "receipt", name = "구겨진 영수증" },
	{ key = "cup", name = "빈 플라스틱 컵" },
	{ key = "tissue", name = "구겨진 휴지" },
	{ key = "snackbag", name = "빈 과자 봉지" },
}
TrashConfig.JunkStart = { 1, 3 } -- how many at the start, at random
TrashConfig.JunkMax = 3 -- junk in a can at most (thrown-in items do not count)
TrashConfig.JunkEvery = 600 -- seconds: now and then one more, while under JunkMax

-- what may go in: bought / found things you carry, not passes or tools of a job
-- (a 야광봉 of the Glowstick pass, the guard's handcuffs, a photo of the album...)
function TrashConfig.canThrow(tool: Instance): boolean
	if not tool:IsA("Tool") then return false end
	if tool:GetAttribute("Junk") then return true end -- (D-1310)
	if tool:GetAttribute("CafeOrder") or tool:GetAttribute("Busy") or tool:GetAttribute("PhotoId") then return false end
	if tool:GetAttribute("HandSparkler") then return false end
	return tool:GetAttribute("Snack") ~= nil or tool:GetAttribute("Plate") ~= nil
		or tool:GetAttribute("Bottle") ~= nil or tool:GetAttribute("Cup") ~= nil
		or typeof(tool:GetAttribute("Count")) == "number"
end

return TrashConfig

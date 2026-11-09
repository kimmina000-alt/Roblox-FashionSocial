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

-- what may go in: bought / found things you carry, not passes or tools of a job
-- (a 야광봉 of the Glowstick pass, the guard's handcuffs, a photo of the album...)
function TrashConfig.canThrow(tool: Instance): boolean
	if not tool:IsA("Tool") then return false end
	if tool:GetAttribute("CafeOrder") or tool:GetAttribute("Busy") or tool:GetAttribute("PhotoId") then return false end
	if tool:GetAttribute("HandSparkler") then return false end
	return tool:GetAttribute("Snack") ~= nil or tool:GetAttribute("Plate") ~= nil
		or tool:GetAttribute("Bottle") ~= nil or tool:GetAttribute("Cup") ~= nil
		or typeof(tool:GetAttribute("Count")) == "number"
end

return TrashConfig

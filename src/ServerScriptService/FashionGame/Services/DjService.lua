--!strict
-- DJ booth time (D-052). One DJ per server at a time.
--
-- Buying "DJ" (Developer Product) gives MonetizationConfig.DJMinutes of DJ
-- time. If nobody is DJing the time starts now; the current DJ buying again
-- extends their time; anyone else is put in the queue and starts when the slot
-- frees up (time is never lost: it starts when the turn begins).
--
-- Public state (ReplicatedStorage.FashionGame attributes):
--   ClubDJ       userId of the DJ, 0 when nobody
--   ClubDJUntil  server time the current DJ's time ends
--   ClubDJQueue  number of people waiting
--
-- DJ abilities live in ClubService (music) today. Future DJ features (lights,
-- effects, announcements, crowd votes) hook in through DjService.IsDJ and the
-- DjService.Actions table — see docs/01_SYSTEMS/DJ_SYSTEM.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local MonetizationConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

local DjService = {}

type Slot = { userId: number, seconds: number }

local current: Slot? = nil
local currentUntil = 0
local queue: {Slot} = {}
local changed = Instance.new("BindableEvent")
DjService.Changed = changed.Event

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish()
	FashionGame:SetAttribute("ClubDJ", if current then current.userId else 0)
	FashionGame:SetAttribute("ClubDJUntil", if current then currentUntil else 0)
	FashionGame:SetAttribute("ClubDJQueue", #queue)
	changed:Fire()
end

local function startNext()
	current = nil
	currentUntil = 0
	while #queue > 0 do
		local slot = table.remove(queue, 1) :: Slot
		if Players:GetPlayerByUserId(slot.userId) then
			current = slot
			currentUntil = now() + slot.seconds
			break
		end
	end
	publish()
end

function DjService.IsDJ(player: Player): boolean
	return current ~= nil and current.userId == player.UserId and now() < currentUntil
end

function DjService.CurrentDJ(): number
	return if current then current.userId else 0
end

-- Adds DJ time for the player. Returns (true, message for the buyer).
function DjService.AddTime(player: Player): (boolean, string?)
	local seconds = MonetizationConfig.DJMinutes * 60
	if current and current.userId == player.UserId then
		currentUntil += seconds
		publish()
		return true, string.format("DJ 시간이 %d분 연장되었습니다.", MonetizationConfig.DJMinutes)
	end
	for _, slot in ipairs(queue) do
		if slot.userId == player.UserId then
			slot.seconds += seconds
			publish()
			return true, "대기 중인 DJ 시간이 늘어났습니다."
		end
	end
	if not current then
		current = { userId = player.UserId, seconds = seconds }
		currentUntil = now() + seconds
		publish()
		return true, string.format("지금부터 %d분 동안 DJ입니다! DJ 부스로 가세요.", MonetizationConfig.DJMinutes)
	end
	table.insert(queue, { userId = player.UserId, seconds = seconds })
	publish()
	return true, string.format("DJ 대기 %d번째입니다. 앞 DJ가 끝나면 바로 시작돼요.", #queue)
end

-- Future DJ abilities register here: DjService.Actions[name] = function(player, payload) ... end
-- ClubService routes Music remote calls whose action is not a music action to this table.
DjService.Actions = {} :: {[string]: (Player, any) -> (boolean, any)}

function DjService.Start()
	publish()
	Players.PlayerRemoving:Connect(function(player)
		for index = #queue, 1, -1 do
			if queue[index].userId == player.UserId then
				table.remove(queue, index)
			end
		end
		if current and current.userId == player.UserId then
			startNext()
		else
			publish()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if current and now() >= currentUntil then
				startNext()
			end
		end
	end)
end

return DjService

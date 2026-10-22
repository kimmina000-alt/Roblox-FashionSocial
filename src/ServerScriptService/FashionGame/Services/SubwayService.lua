--!strict
-- Subway exits (user, 2026-10-22): stepping on an exit pad asks "몇 번 출구로
-- 가시겠습니까?" and moves the player to the chosen exit.
--
--   * Parts tagged "SubwayExit": attributes ExitNumber (number), ExitName
--     (string), Out (Vector3, the way out of the exit; default LookVector).
--   * Touching a pad → SubwayNotify "Open", exitNumber (the client lists the
--     other exits from the tagged parts).
--   * Remote Subway (RemoteFunction) "Go", exitNumber: the player must still be
--     next to the pad they stepped on; then they are placed just outside the
--     chosen exit, facing out.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")

local SubwayService = {}

local NEAR = 12 -- studs from the pad that still count as "at the exit"
local REOPEN = 3 -- seconds before the same pad asks again
local lastPad: {[Player]: BasePart} = {}
local lastOpen: {[Player]: number} = {}

local function findExit(number: number): BasePart?
	for _, pad in ipairs(CollectionService:GetTagged("SubwayExit")) do
		if pad:IsA("BasePart") and pad:GetAttribute("ExitNumber") == number then return pad end
	end
	return nil
end

local function outOf(pad: BasePart): Vector3
	local out = pad:GetAttribute("Out")
	return if typeof(out) == "Vector3" and out.Magnitude > 0 then out.Unit else pad.CFrame.LookVector
end

local function onTouched(pad: BasePart, hit: BasePart)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end
	local now = os.clock()
	if lastPad[player] == pad and now - (lastOpen[player] or 0) < REOPEN then return end
	lastPad[player] = pad
	lastOpen[player] = now
	local notify = Remotes:FindFirstChild("SubwayNotify") :: RemoteEvent?
	if notify then notify:FireClient(player, "Open", pad:GetAttribute("ExitNumber")) end
end

local function go(player: Player, number: any): (boolean, string?)
	if typeof(number) ~= "number" then return false, "출구를 골라 주세요." end
	local from = lastPad[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not from or not root or not humanoid or (root.Position - from.Position).Magnitude > NEAR then
		return false, "출구 발판 위에서 골라 주세요."
	end
	local target = findExit(number)
	if not target then return false, "없는 출구예요." end
	if target == from then return false, "지금 이 출구에 있어요." end
	humanoid.Sit = false
	local out = outOf(target)
	local spot = target.Position + out * 4.5 + Vector3.new(0, 3.5, 0)
	-- arrive next to the pad (not on it), so it does not ask again right away
	lastPad[player] = target
	lastOpen[player] = os.clock() + 2
	character:PivotTo(CFrame.lookAt(spot, spot + out))
	return true, string.format("%d번 출구로 나왔어요.", number)
end

local function hook(pad: Instance)
	if not pad:IsA("BasePart") then return end
	pad.Touched:Connect(function(hit) onTouched(pad, hit) end)
end

function SubwayService.Start()
	local remote = Remotes:WaitForChild("Subway") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, number: any)
		if action == "Go" then return go(player, number) end
		return false, nil
	end
	for _, pad in ipairs(CollectionService:GetTagged("SubwayExit")) do hook(pad) end
	CollectionService:GetInstanceAddedSignal("SubwayExit"):Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		lastPad[player] = nil
		lastOpen[player] = nil
	end)
end

return SubwayService

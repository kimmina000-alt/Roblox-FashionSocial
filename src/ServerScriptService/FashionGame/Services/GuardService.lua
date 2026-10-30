--!strict
-- Club guard (user 2026-10-30, docs/01_SYSTEMS/GUARD.md, D-623). A player
-- with the "Guard" game pass wears a GUARD badge (NameTagService) and, inside
-- the club, can show a player who spoils the game out of the club: the
-- target is put on the sidewalk in front of the door and cannot come back in
-- for a minute ("1분 격리"; ClubAccessService keeps them out while the
-- attribute GuardOutUntil is in the future).
-- Limits so it cannot be used to bully: club only (both inside); not the
-- DJ, not another guard; a guard waits GuardCooldown between uses; a player
-- is shown out at most once per TargetCooldown by anyone; every use is
-- logged in the server output and told to the target with the guard's name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local MonetizationService = require(script.Parent.MonetizationService)
local DjService = require(script.Parent.DjService)

local GuardService = {}

GuardService.OutSeconds = 60 -- how long the target stays out
GuardService.GuardCooldown = 30 -- between two uses by the same guard
GuardService.TargetCooldown = 5 * 60 -- a player is shown out at most once in this time

local lastUse: {[Player]: number} = {}
local lastOut: {[number]: number} = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function toast(player: Player, message: string)
	local notify = Remotes:FindFirstChild("ClubNotify") :: RemoteEvent?
	if notify then notify:FireClient(player, "Toast", message) end
end

function GuardService.IsGuard(player: Player): boolean
	return MonetizationService.HasPass(player, "Guard")
end

-- the player was shown out and may not come in yet
function GuardService.IsOut(player: Player): boolean
	local untilAt = player:GetAttribute("GuardOutUntil")
	return typeof(untilAt) == "number" and untilAt > workspace:GetServerTimeNow()
end

local showOut: (Player, any) -> (boolean, string?)
function GuardService.ShowOut(guard: Player, targetId: any): (boolean, string?)
	local ok, message = showOut(guard, targetId)
	if not ok and message then toast(guard, message) end
	return ok, message
end

showOut = function(guard: Player, targetId: any): (boolean, string?)
	if not GuardService.IsGuard(guard) then return false, "가드 이용권이 있어야 해요." end
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId) or nil
	if not target or target == guard then return false, "내보낼 수 없는 사람이에요." end
	local mine, theirs = rootOf(guard), rootOf(target)
	if not mine or not theirs or not ClubConfig.isInClub(mine.Position) or not ClubConfig.isInClub(theirs.Position) then
		return false, "클럽 안에서만 쓸 수 있어요."
	end
	if DjService.IsDJ(target) then return false, "DJ는 내보낼 수 없어요." end
	if GuardService.IsGuard(target) then return false, "다른 가드는 내보낼 수 없어요." end
	local t = os.clock()
	if lastUse[guard] and t - lastUse[guard] < GuardService.GuardCooldown then
		return false, string.format("%d초 뒤에 다시 쓸 수 있어요.", math.ceil(GuardService.GuardCooldown - (t - lastUse[guard])))
	end
	if lastOut[target.UserId] and t - lastOut[target.UserId] < GuardService.TargetCooldown then
		return false, "이 사람은 조금 전에 이미 안내됐어요."
	end
	lastUse[guard] = t
	lastOut[target.UserId] = t
	target:SetAttribute("GuardOutUntil", workspace:GetServerTimeNow() + GuardService.OutSeconds)
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then weld:Destroy() end
	end
	if character then
		local exit = ClubConfig.NightEntry.ExitPosition
		character:PivotTo(CFrame.lookAt(exit, exit + Vector3.new(-1, 0, 0)))
	end
	toast(target, string.format("🛡 가드 %s님이 클럽 밖으로 안내했어요. %d초 뒤에 다시 들어갈 수 있어요.", guard.DisplayName, GuardService.OutSeconds))
	toast(guard, string.format("%s님을 클럽 밖으로 안내했어요.", target.DisplayName))
	print(string.format("[Guard] %s (%d) showed %s (%d) out of the club", guard.Name, guard.UserId, target.Name, target.UserId))
	return true, nil
end

function GuardService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return GuardService

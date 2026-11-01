--!strict
-- Club guard (user 2026-10-30, docs/01_SYSTEMS/GUARD.md, D-623). A player
-- with the "Guard" game pass wears a GUARD badge (NameTagService) and has two
-- tools on a player's card (user 2026-11-01, D-722):
--   들기 / 내려놓기  pick a player up in the arms (GuardController shows the
--            pose on every screen), walk, and put them down again. Carried out
--            of the club = shown out; a player outside can be carried in too
--            (the night-only entry lets a carried player in, ClubAccessService).
--   수갑     handcuffs: the player may not come into the club for a minute
--            (attribute GuardOutUntil; ClubAccessService puts them out on the
--            sidewalk if they are inside). A ⛓ shows before their id
--            (attribute Cuffed, NameTagService).
-- Limits so it cannot be used to bully: near the guard only; not the DJ, not
-- another guard; a carry ends by itself after CarrySeconds; handcuffs wait
-- GuardCooldown between uses and a player is cuffed at most once per
-- TargetCooldown by anyone; every use is logged in the server output and
-- told to the target with the guard's name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local MonetizationService = require(script.Parent.MonetizationService)
local DjService = require(script.Parent.DjService)

local GuardService = {}

GuardService.OutSeconds = 60 -- how long a cuffed player stays out
GuardService.GuardCooldown = 30 -- between two handcuffs by the same guard
GuardService.TargetCooldown = 5 * 60 -- a player is cuffed at most once in this time
GuardService.Reach = 12 -- studs: how near the target must be
GuardService.CarrySeconds = 30 -- a carry ends by itself after this

-- where the carried player lies: across the guard's arms, face up, head to
-- the guard's right (guard root space)
local HOLD = CFrame.fromMatrix(Vector3.new(0, 0.6, -1.9), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, -1, 0))

local lastUse: {[Player]: number} = {}
local lastOut: {[number]: number} = {}
type Carry = { target: Player, weld: Weld, saved: {[BasePart]: { boolean }}, wasInClub: boolean, token: number }
local carries: {[Player]: Carry} = {}
local tokens = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function toast(player: Player, message: string)
	local notify = Remotes:FindFirstChild("ClubNotify") :: RemoteEvent?
	if notify then notify:FireClient(player, "Toast", message) end
end

local function unsit(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then weld:Destroy() end
	end
end

function GuardService.IsGuard(player: Player): boolean
	return MonetizationService.HasPass(player, "Guard")
end

-- the player was cuffed and may not come in yet
function GuardService.IsOut(player: Player): boolean
	local untilAt = player:GetAttribute("GuardOutUntil")
	return typeof(untilAt) == "number" and untilAt > workspace:GetServerTimeNow()
end

-- the checks both tools share
local function targetFor(guard: Player, targetId: any): (Player?, string?)
	if not GuardService.IsGuard(guard) then return nil, "가드 패스가 있어야 해요." end
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId) or nil
	if not target or target == guard then return nil, "할 수 없는 사람이에요." end
	local mine, theirs = rootOf(guard), rootOf(target)
	if not mine or not theirs then return nil, "할 수 없는 사람이에요." end
	if (mine.Position - theirs.Position).Magnitude > GuardService.Reach then return nil, "조금 더 가까이 가야 해요." end
	if DjService.IsDJ(target) then return nil, "DJ에게는 쓸 수 없어요." end
	if GuardService.IsGuard(target) then return nil, "다른 가드에게는 쓸 수 없어요." end
	return target, nil
end

--------------------------------------------------
-- carrying
--------------------------------------------------
local drop: (Player, boolean?) -> ()

local function carry(guard: Player, targetId: any): (boolean, string?)
	if carries[guard] then return false, "이미 누군가를 들고 있어요." end
	local target, why = targetFor(guard, targetId)
	if not target then return false, why end
	if target:GetAttribute("CarriedBy") then return false, "다른 가드가 들고 있어요." end
	if target:GetAttribute("Carrying") then return false, "할 수 없는 사람이에요." end
	local mine, theirs = rootOf(guard), rootOf(target)
	local humanoid = humanoidOf(target)
	if not mine or not theirs or not humanoid or humanoid.Health <= 0 then return false, "할 수 없는 사람이에요." end
	unsit(target)
	-- light and out of the way while held (restored on drop)
	local saved: {[BasePart]: { boolean }} = {}
	for _, part in ipairs((target.Character :: Model):GetDescendants()) do
		if part:IsA("BasePart") then
			saved[part] = { part.Massless, part.CanCollide }
			part.Massless = true
			part.CanCollide = false
		end
	end
	humanoid.PlatformStand = true
	theirs.CFrame = mine.CFrame * HOLD
	local weld = Instance.new("Weld")
	weld.Name = "GuardCarry"
	weld.Part0 = mine
	weld.Part1 = theirs
	weld.C0 = HOLD
	weld.Parent = mine
	pcall(function() mine:SetNetworkOwner(guard) end)
	tokens += 1
	local token = tokens
	carries[guard] = { target = target, weld = weld, saved = saved, wasInClub = ClubConfig.isInClub(theirs.Position), token = token }
	target:SetAttribute("CarriedBy", guard.UserId)
	guard:SetAttribute("Carrying", target.UserId)
	toast(target, string.format("🛡 가드 %s님이 들어 올렸어요.", guard.DisplayName))
	print(string.format("[Guard] %s (%d) picked up %s (%d)", guard.Name, guard.UserId, target.Name, target.UserId))
	task.delay(GuardService.CarrySeconds, function()
		local c = carries[guard]
		if c and c.token == token then drop(guard, true) end
	end)
	return true, nil
end

drop = function(guard: Player, timedOut: boolean?)
	local c = carries[guard]
	if not c then return end
	carries[guard] = nil
	local target = c.target
	c.weld:Destroy()
	for part, was in pairs(c.saved) do
		if part.Parent then
			part.Massless = was[1]
			part.CanCollide = was[2]
		end
	end
	if guard.Parent then guard:SetAttribute("Carrying", nil) end
	if not target.Parent then return end
	target:SetAttribute("CarriedBy", nil)
	local humanoid = humanoidOf(target)
	if humanoid then humanoid.PlatformStand = false end
	local mine, theirs = rootOf(guard), rootOf(target)
	if theirs and target.Character then
		-- standing on the ground in front of the guard, facing them
		local at = if mine then (mine.CFrame * CFrame.new(0, 0, -3)).Position else theirs.Position
		local face = if mine then Vector3.new(mine.Position.X, at.Y, mine.Position.Z) else at + Vector3.new(0, 0, -1)
		target.Character:PivotTo(CFrame.lookAt(at, face))
		theirs.AssemblyLinearVelocity = Vector3.zero
		pcall(function() theirs:SetNetworkOwner(target) end)
	end
	local nowIn = theirs ~= nil and ClubConfig.isInClub(theirs.Position)
	if nowIn then
		target:SetAttribute("ClubInside", true) -- (brought in by a guard: may stay, night or day)
	end
	if c.wasInClub and not nowIn then
		toast(target, string.format("🛡 가드 %s님이 클럽 밖으로 데리고 나왔어요.", guard.DisplayName))
		if guard.Parent then toast(guard, string.format("%s님을 클럽 밖으로 데리고 나왔어요.", target.DisplayName)) end
		print(string.format("[Guard] %s (%d) carried %s (%d) out of the club", guard.Name, guard.UserId, target.Name, target.UserId))
	elseif timedOut then
		if guard.Parent then toast(guard, "오래 들고 있어서 내려놓았어요.") end
	end
end

--------------------------------------------------
-- handcuffs
--------------------------------------------------
local function cuff(guard: Player, targetId: any): (boolean, string?)
	local target, why = targetFor(guard, targetId)
	if not target then return false, why end
	local t = os.clock()
	if lastUse[guard] and t - lastUse[guard] < GuardService.GuardCooldown then
		return false, string.format("%d초 뒤에 다시 쓸 수 있어요.", math.ceil(GuardService.GuardCooldown - (t - lastUse[guard])))
	end
	if lastOut[target.UserId] and t - lastOut[target.UserId] < GuardService.TargetCooldown then
		return false, "이 사람은 조금 전에 이미 수갑을 찼어요."
	end
	lastUse[guard] = t
	lastOut[target.UserId] = t
	local untilAt = workspace:GetServerTimeNow() + GuardService.OutSeconds
	target:SetAttribute("GuardOutUntil", untilAt)
	target:SetAttribute("Cuffed", true)
	task.delay(GuardService.OutSeconds, function()
		if target.Parent and target:GetAttribute("GuardOutUntil") == untilAt then target:SetAttribute("Cuffed", nil) end
	end)
	toast(target, string.format("⛓ 가드 %s님이 수갑을 채웠어요. %d초 동안 클럽에 들어갈 수 없어요.", guard.DisplayName, GuardService.OutSeconds))
	toast(guard, string.format("%s님에게 수갑을 채웠어요 (%d초 클럽 입장 금지).", target.DisplayName, GuardService.OutSeconds))
	print(string.format("[Guard] %s (%d) cuffed %s (%d)", guard.Name, guard.UserId, target.Name, target.UserId))
	return true, nil
end

-- The remote's entry points (ServerMain, ClubShop actions): a refusal is told
-- to the guard as a toast too.
local function told(guard: Player, ok: boolean, message: string?): (boolean, string?)
	if not ok and message then toast(guard, message) end
	return ok, message
end
function GuardService.Carry(guard: Player, targetId: any): (boolean, string?)
	return told(guard, carry(guard, targetId))
end
function GuardService.Drop(guard: Player): (boolean, string?)
	if not carries[guard] then return false, nil end
	drop(guard)
	return true, nil
end
function GuardService.Cuff(guard: Player, targetId: any): (boolean, string?)
	return told(guard, cuff(guard, targetId))
end

function GuardService.Start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- a new character (reset, outfit respawn) ends any carry it was in
			if carries[player] then drop(player) end
			for guard, c in pairs(carries) do
				if c.target == player then drop(guard) end
			end
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					if carries[player] then drop(player) end
					for guard, c in pairs(carries) do
						if c.target == player then drop(guard) end
					end
				end)
			end
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do watch(player) end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		if carries[player] then drop(player) end
		for guard, c in pairs(carries) do
			if c.target == player then drop(guard) end
		end
		lastUse[player] = nil
	end)
end

return GuardService

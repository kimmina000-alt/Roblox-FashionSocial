--!strict
-- Paid club areas: VIP balcony (Game Pass "VIP") and DJ booth (DJ time).
--
-- Map parts (built by tools/graybox/build_main_social_graybox.lua):
--   tag "ClubGate"   + attribute Gate = "VIP" | "DJ": invisible barrier at
--                    the entrance. Touching it without access asks the
--                    player's client to show the purchase window.
--   tag "ClubRegion" + attribute Gate: box covering the area. A character
--                    inside without access is moved back out (safety net if a
--                    barrier is skipped, e.g. by a jump or lag).
--
-- Access works with collision groups: each character part is put in
-- "Char_<VIP><DJ>" and the barriers in "Gate_VIP"/"Gate_DJ"; the group pairs
-- that have access do not collide. Everything is decided on the server.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")

local MonetizationService = require(script.Parent.MonetizationService)
local DjService = require(script.Parent.DjService)
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local DayNightConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("DayNightConfig"))

local ClubAccessService = {}

--------------------------------------------------------------------------
-- Night-only entry (CLUB.md §20, D-320). No barrier at the door: a player
-- who comes into the club area from outside while it is day is put back on
-- the sidewalk with a notice. Whoever is inside may stay when the day comes
-- (attribute ClubInside on the player, cleared when they leave the club), and
-- leaving is always free. Teleports into the club (🏠, subway...) follow the
-- same rule; the DJ's "your turn" move is the one exception (SendToDJBooth).
local lastNightNotice: {[Player]: number} = {}

local function nightEntryActive(): boolean
	return ClubConfig.NightEntry.Enabled and DayNightConfig.isFlowing()
end

local function clubOpen(): boolean
	return not nightEntryActive() or ClubConfig.isNightOpen(DayNightConfig.clockNow())
end
ClubAccessService.ClubOpen = clubOpen

local function nightSweep()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and character then
			local inside = ClubConfig.isInClub(root.Position)
			if not inside then
				if player:GetAttribute("ClubInside") then player:SetAttribute("ClubInside", nil) end
			elseif not player:GetAttribute("ClubInside") then
				if clubOpen() then
					player:SetAttribute("ClubInside", true)
				else
					-- came in by day: back out to the sidewalk
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.SeatPart then humanoid.Sit = false end
					character:PivotTo(CFrame.lookAt(ClubConfig.NightEntry.ExitPosition, ClubConfig.NightEntry.ExitPosition + Vector3.new(-1, 0, 0)))
					local t = os.clock()
					if not lastNightNotice[player] or t - lastNightNotice[player] > 4 then
						lastNightNotice[player] = t
						local minutes = math.max(1, math.ceil(DayNightConfig.secondsUntil(ClubConfig.NightEntry.OpenHour) / 60))
						local notify = Remotes:FindFirstChild("ClubNotify") :: RemoteEvent?
						if notify then
							notify:FireClient(player, "Toast", string.format("🌙 클럽은 밤에 열려요 (18:00~06:00) · 오픈까지 약 %d분", minutes))
						end
					end
				end
			end
		end
	end
end

local GROUPS = { "Char_None", "Char_VIP", "Char_DJ", "Char_VIPDJ" }
local lastPrompt: {[Player]: number} = {}

local function hasAccess(player: Player, gate: string): boolean
	if gate == "VIP" then
		return MonetizationService.HasPass(player, "VIP")
	elseif gate == "DJ" then
		-- The DJ and the players the DJ invited (D-061).
		return DjService.IsDJ(player) or DjService.IsGuest(player)
	end
	return false
end
ClubAccessService.HasAccess = hasAccess

local function groupFor(player: Player): string
	local vip = hasAccess(player, "VIP")
	local dj = hasAccess(player, "DJ")
	if vip and dj then return "Char_VIPDJ" end
	if vip then return "Char_VIP" end
	if dj then return "Char_DJ" end
	return "Char_None"
end

local function applyGroup(player: Player)
	local character = player.Character
	if not character then return end
	local group = groupFor(player)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end
ClubAccessService.Refresh = applyGroup

local function setupGroups()
	for _, name in ipairs({ "Gate_VIP", "Gate_DJ", table.unpack(GROUPS) }) do
		pcall(function() PhysicsService:RegisterCollisionGroup(name) end)
	end
	for _, group in ipairs(GROUPS) do
		PhysicsService:CollisionGroupSetCollidable("Gate_VIP", group, not (group == "Char_VIP" or group == "Char_VIPDJ"))
		PhysicsService:CollisionGroupSetCollidable("Gate_DJ", group, not (group == "Char_DJ" or group == "Char_VIPDJ"))
		for _, other in ipairs(GROUPS) do
			PhysicsService:CollisionGroupSetCollidable(group, other, true)
		end
		PhysicsService:CollisionGroupSetCollidable("Default", group, true)
	end
end

-- Only regions in the live world count: copies kept in ServerStorage (map
-- backups) still carry the tags, at their old positions (2026-10-22 bug: the
-- backup's VIP region threw players out of the moved club into the void).
local function liveRegions(): {Instance}
	local list = {}
	for _, region in ipairs(CollectionService:GetTagged("ClubRegion")) do
		if region:IsDescendantOf(workspace) then table.insert(list, region) end
	end
	return list
end

local function insideBox(box: BasePart, position: Vector3): boolean
	local p = box.CFrame:PointToObjectSpace(position)
	local half = box.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local function promptPurchase(player: Player, gate: string)
	local t = os.clock()
	if lastPrompt[player] and t - lastPrompt[player] < 4 then return end
	lastPrompt[player] = t
	local notify = Remotes:FindFirstChild("ClubNotify") :: RemoteEvent?
	if notify then
		-- While someone is DJing the zone is for the DJ and their guests: the
		-- client explains that and offers a queue purchase instead of opening
		-- the purchase window straight away.
		if gate == "DJ" and DjService.CurrentDJ() ~= 0 then
			notify:FireClient(player, "GateQueue", gate)
			return
		end
		notify:FireClient(player, "Gate", gate)
	end
end

local function watchGate(part: Instance)
	if not part:IsA("BasePart") then return end
	local gate = part:GetAttribute("Gate")
	if gate ~= "VIP" and gate ~= "DJ" then return end
	part.CollisionGroup = "Gate_" .. gate
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then return end
		if not hasAccess(player, gate) then
			promptPurchase(player, gate)
		end
	end)
end

-- Moves anyone without access out of paid areas.
local function sweep()
	local regions = liveRegions()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			for _, region in ipairs(regions) do
				local gate = region:GetAttribute("Gate")
				if region:IsA("BasePart") and typeof(gate) == "string" and insideBox(region, root.Position)
					and not hasAccess(player, gate) then
					local exit = region:GetAttribute("Exit")
					if typeof(exit) == "Vector3" and character then
						-- (user 2026-10-30: guests stayed on the DJ stage after the DJ's
						-- time) stand up first: a seated character does not move
						local humanoid = character:FindFirstChildOfClass("Humanoid")
						if humanoid and humanoid.SeatPart then
							humanoid.Sit = false
							local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
							if weld then weld:Destroy() end
						end
						character:PivotTo(CFrame.new(exit))
					end
					if gate == "DJ" and DjService.CurrentDJ() == 0 then
						-- the DJ's time is over: say so instead of a purchase prompt
						local notify = Remotes:FindFirstChild("ClubNotify") :: RemoteEvent?
						if notify then notify:FireClient(player, "Toast", "🎧 DJ 시간이 끝나서 DJ 존에서 내려왔어요.") end
						continue
					end
					promptPurchase(player, gate)
				end
			end
		end
	end
end

-- Moves the DJ behind the booth (part tagged "DJSpot", facing the floor).
-- Only after the DJ said OK in the "DJ 차례" window (user, 2026-10-20: never
-- move people without asking). Skipped when they are already in the DJ zone.
function ClubAccessService.SendToDJBooth(player: Player)
	if not DjService.IsDJ(player) then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local spot: Instance? = nil
	for _, s in ipairs(CollectionService:GetTagged("DJSpot")) do
		if s:IsDescendantOf(workspace) then spot = s break end
	end
	if not character or not root or not spot or not spot:IsA("BasePart") then return end
	for _, region in ipairs(liveRegions()) do
		if region:IsA("BasePart") and region:GetAttribute("Gate") == "DJ" and insideBox(region, root.Position) then
			return
		end
	end
	applyGroup(player)
	-- (the DJ's turn may come by day: this move is the exception to night-only entry)
	player:SetAttribute("ClubInside", true)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then humanoid.Sit = false end
	character:PivotTo(spot.CFrame + Vector3.new(0, 3, 0))
end

-- Asks the DJ whether to go to the booth now. queued = their turn came from
-- the queue (the window then also offers passing the turn, no refund).
function ClubAccessService.OfferDJBooth(player: Player, queued: boolean)
	if not DjService.IsDJ(player) then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		for _, region in ipairs(liveRegions()) do
			if region:IsA("BasePart") and region:GetAttribute("Gate") == "DJ" and insideBox(region, root.Position) then
				return
			end
		end
	end
	local notify = Remotes:FindFirstChild("ClubNotify") :: RemoteEvent?
	if notify then notify:FireClient(player, "DJTurn", { queued = queued }) end
end

function ClubAccessService.Start()
	setupGroups()
	for _, part in ipairs(CollectionService:GetTagged("ClubGate")) do watchGate(part) end
	CollectionService:GetInstanceAddedSignal("ClubGate"):Connect(watchGate)

	local function onCharacter(player: Player, character: Model)
		applyGroup(player)
		character.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") then
				part.CollisionGroup = groupFor(player)
			end
		end)
	end
	local function onPlayer(player: Player)
		if player.Character then onCharacter(player, player.Character) end
		player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
		player:GetAttributeChangedSignal("Pass_VIP"):Connect(function() applyGroup(player) end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
	Players.PlayerRemoving:Connect(function(player)
		lastPrompt[player] = nil
		lastNightNotice[player] = nil
	end)
	-- (published for the door sign on the clients)
	FashionGame:SetAttribute("ClubNightEntry", ClubConfig.NightEntry.Enabled)

	-- A queued turn starting: ask the new DJ (OK = go, NO = pass, no refund).
	local lastDJ = 0
	DjService.Changed:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do applyGroup(player) end
		local dj = DjService.CurrentDJ()
		if dj ~= 0 and dj ~= lastDJ and DjService.StartedFromQueue() then
			local djPlayer = Players:GetPlayerByUserId(dj)
			if djPlayer then task.defer(ClubAccessService.OfferDJBooth, djPlayer, true) end
		end
		lastDJ = dj
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			sweep()
			nightSweep()
		end
	end)
end

return ClubAccessService

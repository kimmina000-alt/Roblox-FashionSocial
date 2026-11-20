--!strict
-- 여러 곳에서 시작하기 (D-1982; the spots and why: Shared/SpawnConfig).
-- The first character of each join is moved, right after the default spawn, to one SpawnConfig spot
-- picked at random for the game clock (SpawnConfig.Day / Night, ClubConfig.isNightOpen), or next to a
-- Roblox friend already on the server. Later respawns stay at the SpawnLocation by the guide.
-- The player attribute SpawnSpot keeps the key ("beach", "park", ..., "friend") for the analytics
-- (SpawnAt event and the spot field of FirstSession / FirstLeave, Analytics.lua).
-- Studio: off while the Studio test spawn (StudioTestSpawn attribute, D-1732) is on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local SpawnConfig = require(Shared:WaitForChild("SpawnConfig"))
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))

local SpawnService = {}
local rng = Random.new()

local function ground(at: Vector3, ignore: {Instance}): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(at + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else at
end

local function characters(): {Instance}
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(list, p.Character) end
	end
	return list
end

-- a friend already on the server, standing on their feet in the world (not seated on a ride, not watching)
local function friendSpot(player: Player): CFrame?
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not other:GetAttribute("Spectating") then
			local ok, isFriend = pcall(function() return player:IsFriendsWith(other.UserId) end)
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if ok and isFriend and root and humanoid and humanoid.Health > 0 and not humanoid.SeatPart then
				local beside = root.CFrame * CFrame.new(SpawnConfig.FriendOffset, 0, 0)
				local feet = ground(beside.Position, characters())
				-- (only when the ground beside them is about as high as their feet: not off a ledge)
				if math.abs(feet.Y - (root.Position.Y - 3)) < 4 then
					return CFrame.lookAt(feet, feet + root.CFrame.LookVector * Vector3.new(1, 0, 1))
				end
			end
		end
	end
	return nil
end

local function pick(): (SpawnConfig.Spot, boolean)
	local night = ClubConfig.isNightOpen(DayNightConfig.clockNow())
	local list = if night then SpawnConfig.Night else SpawnConfig.Day
	return list[rng:NextInteger(1, #list)], night
end

local function place(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end
	local key, feet: CFrame
	local night = ClubConfig.isNightOpen(DayNightConfig.clockNow())
	local friend = friendSpot(player)
	if friend then
		key, feet = "friend", friend
	else
		local spot
		spot, night = pick()
		local at = ground(spot.at, characters())
		key, feet = spot.key, CFrame.lookAt(at, Vector3.new(spot.face.X, at.Y, spot.face.Z))
	end
	-- load the place for the player first (StreamingEnabled), then move the character
	pcall(function() player:RequestStreamAroundAsync(feet.Position, 5) end)
	if character.Parent ~= workspace then return end
	local lift = humanoid.HipHeight + root.Size.Y / 2
	character:PivotTo(feet + Vector3.new(0, lift + 0.2, 0))
	player:SetAttribute("SpawnSpot", key)
	player:SetAttribute("SpawnNight", night)
end

function SpawnService.Start()
	local function onPlayer(player: Player)
		local first = true
		local function added(character: Model)
			if not first then return end
			first = false
			if not SpawnConfig.Enabled then return end
			if RunService:IsStudio() and FashionGame:GetAttribute("StudioTestSpawn") == true then return end
			task.wait(0.1) -- (after the default spawn has placed the character)
			local ok, err = pcall(place, player, character)
			if not ok then warn("[SpawnService] " .. tostring(err)) end
		end
		player.CharacterAdded:Connect(added)
		if player.Character then task.spawn(added, player.Character) end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
end

return SpawnService

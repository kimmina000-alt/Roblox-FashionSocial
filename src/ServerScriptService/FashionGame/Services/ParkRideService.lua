--!strict
-- PARK rides on the server (ParkConfig, docs/02_WORLDS/PARK.md): who sits
-- where, boarding checks, swing speed. The rides themselves move on the
-- clients from the shared clock.
--
-- Remote ParkRide (RemoteFunction) actions:
--   "Board", ride            ferris wheel: the cabin at the bottom now
--   "Board", ride, slot      carousel horse / swing / spring rider
--   "Leave"                  → exit CFrame (wheel: only near the bottom)
--   "Level", delta           swing speed −/+ (0..SwingLevels)
--   "Slid"                   came down the slide → "야호!" for everyone
-- Remote ParkNotify (RemoteEvent) to all: "Yahoo", player.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local ParkConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ParkConfig"))

local ParkRideService = {}

type Ride = { kind: string, model: Instance, slot: Instance, key: string }
local riding: {[Player]: Ride} = {}
local lastSlide: {[Player]: number} = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function kindOf(model: Instance): string?
	for _, tag in ipairs({ "ParkWheel", "ParkCarousel", "ParkSwing", "ParkSpring", "FloatTube" }) do
		if CollectionService:HasTag(model, tag) then return tag end
	end
	return nil
end

local function clear(player: Player)
	local ride = riding[player]
	if not ride then return end
	riding[player] = nil
	if ride.slot:GetAttribute(ride.key) == player.UserId then
		ride.slot:SetAttribute(ride.key, nil)
	end
	if ride.kind == "ParkSwing" then ride.slot:SetAttribute("Level", 0) end
end

local function near(player: Player, position: Vector3, distance: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= distance
end

local function board(player: Player, model: Instance, slot: Instance?): (boolean, any)
	if riding[player] then return false, "이미 타고 있어요." end
	local kind = kindOf(model)
	if not kind then return false, "탈 수 없어요." end
	local t = now()
	if kind == "ParkWheel" then
		local boardPoint = model:FindFirstChild("BoardPoint")
		if not boardPoint or not boardPoint:IsA("BasePart") or not near(player, boardPoint.Position, ParkConfig.BoardDistance) then
			return false, "탑승장에서 탈 수 있어요."
		end
		local index = ParkConfig.cabinAtBottom(model, t)
		local cabin = index and model:FindFirstChild("Cabin" .. index)
		if not cabin then return false, "다음 칸이 내려오면 탈 수 있어요." end
		for seat = 1, #ParkConfig.CabinSeats do
			local key = "Rider" .. seat
			if cabin:GetAttribute(key) == nil then
				cabin:SetAttribute(key, player.UserId)
				riding[player] = { kind = kind, model = model, slot = cabin, key = key }
				return true, { slot = cabin, key = key }
			end
		end
		return false, "이 칸은 가득 찼어요 (2명). 다음 칸을 기다려 주세요."
	end
	-- swings and spring riders are their own slot; horses are inside the carousel
	if not slot or (slot ~= model and not slot:IsDescendantOf(model)) then return false, "탈 수 없어요." end
	if slot:GetAttribute("Rider") ~= nil then return false, "다른 사람이 타고 있어요." end
	local position: Vector3?
	if kind == "ParkCarousel" then
		local index = tonumber(string.match(slot.Name, "^Horse(%d+)$"))
		local cf = index and ParkConfig.horseCFrame(model, index, t)
		position = cf and cf.Position
	elseif kind == "FloatTube" then
		local cf = ParkConfig.floatCFrame(model, t)
		position = cf and cf.Position
	elseif slot:IsA("Model") then
		position = slot:GetPivot().Position
	end
	if not position or not near(player, position, 10) then return false, "더 가까이 가 주세요." end
	slot:SetAttribute("Rider", player.UserId)
	if kind == "ParkSwing" then slot:SetAttribute("Level", ParkConfig.SwingStartLevel) end
	riding[player] = { kind = kind, model = model, slot = slot, key = "Rider" }
	return true, { slot = slot, key = "Rider" }
end

-- Where the rider is put down.
local function exitFor(ride: Ride): CFrame?
	local t = now()
	if ride.kind == "ParkWheel" then
		local boardPoint = ride.model:FindFirstChild("BoardPoint")
		return if boardPoint and boardPoint:IsA("BasePart") then boardPoint.CFrame + Vector3.new(0, 3, 0) else nil
	elseif ride.kind == "ParkCarousel" then
		local index = tonumber(string.match(ride.slot.Name, "^Horse(%d+)$"))
		local center = ride.model:FindFirstChild("Center")
		local cf = index and ParkConfig.horseCFrame(ride.model, index, t)
		if cf and center and center:IsA("BasePart") then
			local out = Vector3.new(cf.Position.X - center.Position.X, 0, cf.Position.Z - center.Position.Z)
			local radius = (ride.model:GetAttribute("Radius") :: number?) or 11
			local spot = center.Position + out.Unit * (radius + 7) + Vector3.new(0, 3, 0)
			return CFrame.lookAt(spot, spot + out)
		end
	elseif ride.kind == "FloatTube" then
		-- next to the tube, in the water (the player swims)
		local cf = ParkConfig.floatCFrame(ride.model, t)
		return cf and CFrame.new(cf.Position + Vector3.new(3, 0, 0))
	elseif ride.slot:IsA("Model") then
		-- in front of the swing / spring rider, on the ground, facing it
		local pivot = (ride.slot :: Model):GetPivot()
		local front = (pivot * CFrame.new(0, 0, -5)).Position
		return CFrame.lookAt(Vector3.new(front.X, 3, front.Z), Vector3.new(pivot.X, 3, pivot.Z))
	end
	return nil
end

local function leave(player: Player): (boolean, any)
	local ride = riding[player]
	if not ride then return true, nil end
	if ride.kind == "ParkWheel" then
		local index = tonumber(string.match(ride.slot.Name, "^Cabin(%d+)$"))
		if index and ParkConfig.cabinFromBottom(ride.model, index, now()) > ParkConfig.WheelBoardAngle * 1.6 then
			return false, "관람차가 아래로 내려오면 내릴 수 있어요."
		end
	end
	local exit = exitFor(ride)
	clear(player)
	return true, exit
end

function ParkRideService.Start()
	local remote = Remotes:WaitForChild("ParkRide") :: RemoteFunction
	local notify = Remotes:WaitForChild("ParkNotify") :: RemoteEvent
	remote.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
		if action == "Board" and typeof(a) == "Instance" then
			return board(player, a, if typeof(b) == "Instance" then b else nil)
		elseif action == "Leave" then
			return leave(player)
		elseif action == "Level" and typeof(a) == "number" then
			local ride = riding[player]
			if not ride or ride.kind ~= "ParkSwing" then return false, nil end
			local level = (ride.slot:GetAttribute("Level") :: number?) or 0
			level = math.clamp(level + (if a > 0 then 1 else -1), 0, ParkConfig.SwingLevels)
			ride.slot:SetAttribute("Level", level)
			return true, level
		elseif action == "Slid" then
			local t = os.clock()
			if lastSlide[player] and t - lastSlide[player] < 2 then return false, nil end
			lastSlide[player] = t
			notify:FireAllClients("Yahoo", player)
			return true, nil
		end
		return false, nil
	end
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function() clear(player) end)
	end
	for _, player in ipairs(Players:GetPlayers()) do watch(player) end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		lastSlide[player] = nil
	end)
end

return ParkRideService

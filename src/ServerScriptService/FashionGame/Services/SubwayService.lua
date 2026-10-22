--!strict
-- Subway exits and bus stops (user, 2026-10-22): stepping on a pad asks where
-- to go ("몇 번 출구로 가시겠습니까?" / "어느 정류장으로 가시겠습니까?") and
-- moves the player to the chosen exit / stop of the same network.
--
--   * Networks = CollectionService tags: "SubwayExit", "BusStop". Pad
--     attributes: ExitNumber (number), ExitName (string), Out (Vector3, the
--     way out; default LookVector).
--   * Subway: touching a pad → SubwayNotify "Open", tag, number (the client
--     lists the other pads with that tag).
--   * Bus: clicking (tapping) the bus stop sign does the same (user 2026-10-22:
--     "표지판 클릭하면 스포너"; the tagged part is the sign, not a floor pad).
--   * Remote Subway (RemoteFunction) "Go", tag, number: the player must still
--     be next to the pad they stepped on; then they are placed just outside the
--     chosen pad, facing out.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")

local SubwayService = {}

local NETWORKS = { SubwayExit = "출구", BusStop = "정류장" }
local NEAR = 12 -- studs from the pad that still count as "at the exit"
local REOPEN = 3 -- seconds before the same pad asks again
local lastPad: {[Player]: BasePart} = {}
local lastOpen: {[Player]: number} = {}

local function findPad(tag: string, number: number): BasePart?
	for _, pad in ipairs(CollectionService:GetTagged(tag)) do
		if pad:IsA("BasePart") and pad:GetAttribute("ExitNumber") == number then return pad end
	end
	return nil
end

local function outOf(pad: BasePart): Vector3
	local out = pad:GetAttribute("Out")
	return if typeof(out) == "Vector3" and out.Magnitude > 0 then out.Unit else pad.CFrame.LookVector
end

local function open(tag: string, pad: BasePart, player: Player)
	local now = os.clock()
	if lastPad[player] == pad and now - (lastOpen[player] or 0) < REOPEN then return end
	lastPad[player] = pad
	lastOpen[player] = now
	local notify = Remotes:FindFirstChild("SubwayNotify") :: RemoteEvent?
	if notify then notify:FireClient(player, "Open", tag, pad:GetAttribute("ExitNumber")) end
end

local function onTouched(tag: string, pad: BasePart, hit: BasePart)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if player then open(tag, pad, player) end
end

local function go(player: Player, tag: any, number: any): (boolean, string?)
	if typeof(tag) ~= "string" or not NETWORKS[tag] then return false, "잘못된 요청입니다." end
	if typeof(number) ~= "number" then return false, NETWORKS[tag] .. "을 골라 주세요." end
	local from = lastPad[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not from or not CollectionService:HasTag(from, tag) or not root or not humanoid or (root.Position - from.Position).Magnitude > NEAR then
		return false, if tag == "BusStop" then "정류장 표지판 가까이에서 골라 주세요." else "발판 위에서 골라 주세요."
	end
	local target = findPad(tag, number)
	if not target then return false, "없는 " .. NETWORKS[tag] .. "이에요." end
	if target == from then return false, "지금 여기 있어요." end
	humanoid.Sit = false
	local out = outOf(target)
	-- stand on the ground next to the pad / sign
	local spot = target.Position + out * 4.5
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character :: Model }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(spot + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	spot = if hit then hit.Position + Vector3.new(0, 3.2, 0) else spot + Vector3.new(0, 3.5, 0)
	-- arrive next to the pad (not on it), so it does not ask again right away
	lastPad[player] = target
	lastOpen[player] = os.clock() + 2
	character:PivotTo(CFrame.lookAt(spot, spot + out))
	local name = target:GetAttribute("ExitName")
	return true, if tag == "BusStop" then string.format("%s 정류장에 내렸어요.", tostring(name or number)) else string.format("%d번 출구로 나왔어요.", number)
end

local function hook(tag: string)
	return function(pad: Instance)
		if not pad:IsA("BasePart") then return end
		if tag == "BusStop" then
			local click = pad:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			click.MaxActivationDistance = NEAR
			click.Parent = pad
			click.MouseClick:Connect(function(player) open(tag, pad, player) end)
		else
			pad.Touched:Connect(function(hit) onTouched(tag, pad, hit) end)
		end
	end
end

function SubwayService.Start()
	local remote = Remotes:WaitForChild("Subway") :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, action: any, tag: any, number: any)
		if action == "Go" then return go(player, tag, number) end
		return false, nil
	end
	for tag in pairs(NETWORKS) do
		local h = hook(tag)
		for _, pad in ipairs(CollectionService:GetTagged(tag)) do h(pad) end
		CollectionService:GetInstanceAddedSignal(tag):Connect(h)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPad[player] = nil
		lastOpen[player] = nil
	end)
end

return SubwayService

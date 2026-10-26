--!strict
-- Club tables by touch (user 2026-10-26, CLUB.md §22): no buttons and no
-- windows near the tables any more.
--   * bottle in hand + tap a table           → 공개 범위 (모든 사람 / 친구만 / 나만),
--                                              then it goes on the table (tier 1 on
--                                              an edge slot, bucket drinks as
--                                              one bucket in the middle)
--   * tier-1 bottle in hand + tap elsewhere  → a drink straight from the bottle
--   * sparkler in hand + tap a bottle/bucket → sparks over it
--   * sparkler bucket set + tap a table      → the set goes on it
--   * tap a bucket                           → a cup of it in the hand
--   * tap your own tier-1 bottle             → back in the hand
-- Taps on the screen (TouchTapInWorld) or short mouse clicks; the server
-- checks everything again.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local ClubConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("ClubConfig"))
local ClubShop = FashionGame:WaitForChild("Remotes"):WaitForChild("ClubShop") :: RemoteFunction
-- (ClubShopController shows these like the server's toasts)
local localToast = script.Parent:WaitForChild("ClubLocalToast") :: BindableEvent
-- (ClubShopController asks 모든 사람 / 친구만 / 나만, then places the bottle)
local askVisibility = script.Parent:WaitForChild("ClubChooseVisibility") :: BindableEvent

local REACH = 14

local function toast(message: any)
	if typeof(message) == "string" and message ~= "" then localToast:Fire(message) end
end

local function held(): Tool?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

-- What was tapped: a placed bottle / bucket, a sparkler bucket, or a table.
local function classify(hit: Instance): (Instance?, BasePart?)
	local placed = if hit.Name == "PlacedBottle" or hit.Name == "SparklerBucket" then hit
		else (hit:FindFirstAncestor("PlacedBottle") or hit:FindFirstAncestor("SparklerBucket"))
	local node: Instance? = placed or hit
	while node and node ~= workspace do
		if node:IsA("BasePart") and CollectionService:HasTag(node, "DrinkTable") then return placed, node end
		node = node.Parent
	end
	return placed, nil
end

local busy = false
local function call(action: string, payload: any)
	if busy then return end
	busy = true
	task.spawn(function()
		local ok, _, message = pcall(function() return ClubShop:InvokeServer(action, payload) end)
		if ok then toast(message) end
		busy = false
	end)
end

local function tierOneBottle(tool: Tool): boolean
	local drink = ClubConfig.findDrink(tool:GetAttribute("Bottle"))
	return drink ~= nil and drink.tier == 1 and player:GetAttribute("Pass_VIP") ~= true
end

-- What a hit means for the thing in hand. One tap can arrive twice (the
-- screen tap and the held item's Activated): the second within 0.4 s is dropped.
local lastHandled = 0
local function handle(hit: Instance?, hitPosition: Vector3?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then return end
	local placed, tablePart = nil, nil
	if hit then placed, tablePart = classify(hit) end
	if hitPosition and (placed or tablePart) and (hitPosition - root.Position).Magnitude > REACH then
		placed, tablePart = nil, nil
	end
	if os.clock() - lastHandled < 0.4 then return end
	lastHandled = os.clock()
	local tool = held()
	if tool and tool:GetAttribute("Bottle") then
		if tablePart then
			askVisibility:Fire(tablePart)
		elseif tierOneBottle(tool) and not tool:GetAttribute("Drinking") then
			call("Swig", nil)
		end
	elseif tool and (tool:GetAttribute("Sparkler") or tool:GetAttribute("SparklerSet")) then
		if placed or tablePart then call("Tap", placed or tablePart) end
	elseif placed then
		call("Tap", placed)
	else
		lastHandled = 0 -- (nothing to do: let the other path try)
	end
end

local function rayHit(ray: Ray): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	return workspace:Raycast(ray.Origin, ray.Direction * 120, params)
end

local function onTap(screen: Vector2)
	local camera = workspace.CurrentCamera
	if not camera or not player.Character then return end
	-- touch positions may or may not include the top bar inset (phone test
	-- 2026-10-27: placing did not work on a phone): try both, keep the one
	-- that lands on a table or on something on it
	local best: RaycastResult? = nil
	for _, ray in ipairs({ camera:ScreenPointToRay(screen.X, screen.Y), camera:ViewportPointToRay(screen.X, screen.Y) }) do
		local result = rayHit(ray)
		if result then
			local placed, tablePart = classify(result.Instance)
			if placed or tablePart then best = result break end
			best = best or result
		end
	end
	handle(best and best.Instance, best and best.Position)
end

UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processed: boolean)
	if not processed then onTap(position) end
end)

-- The held bottle / sparkler itself: on phones a tap with a tool in hand
-- activates the tool; the mouse target then is where the finger was.
local mouse = player:GetMouse()
local function watchTool(tool: Instance)
	if not tool:IsA("Tool") then return end
	if not (tool:GetAttribute("Bottle") or tool:GetAttribute("Sparkler") or tool:GetAttribute("SparklerSet")) then return end
	if tool:GetAttribute("TapWatched") then return end
	tool:SetAttribute("TapWatched", true)
	tool.Activated:Connect(function()
		if tool.Parent ~= player.Character then return end
		local target = mouse.Target
		handle(target, if target then mouse.Hit.Position else nil)
	end)
end
local function watchCharacter(character: Model)
	for _, c in ipairs(character:GetChildren()) do watchTool(c) end
	character.ChildAdded:Connect(watchTool)
end
if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)

-- mouse: a short click without dragging
local downAt: Vector2? = nil
local downTime = 0
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
		downAt = Vector2.new(input.Position.X, input.Position.Y)
		downTime = os.clock()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local start = downAt
	downAt = nil
	if not start or os.clock() - downTime > 0.4 then return end
	local now = Vector2.new(input.Position.X, input.Position.Y)
	if (now - start).Magnitude > 8 then return end
	onTap(now)
end)

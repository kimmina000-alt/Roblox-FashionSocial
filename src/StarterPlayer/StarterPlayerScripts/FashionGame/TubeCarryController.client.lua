--!strict
-- The beach ring on this screen (D-1591, user 2026-11-17: "바다에서 타기 / 내려놓기·다시 들기 / 친구에게
-- 주기 / 반납하기 전부 구현"; the server side is TubeRentService):
--   * holding the ring and starting to swim: "Float" puts it on the water and ParkRidesController gets in
--     (its ParkBoardTube event);
--   * a tap with the ring in hand that is not on a person: "PutDown" (a tap on a person is GiveController's
--     🎁 주기);
--   * the heap's prompt reads "튜브 반납" while you hold a ring, "튜브 들기" otherwise.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("TubeRent") :: RemoteFunction
local TOOL_NAME = "🛟 튜브"

local function held(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(TOOL_NAME)
	return if tool and tool:IsA("Tool") then tool else nil
end

local function owns(): boolean
	if held() then return true end
	local backpack = player:FindFirstChildOfClass("Backpack")
	return backpack ~= nil and backpack:FindFirstChild(TOOL_NAME) ~= nil
end

local busy = false

-- into the sea with the ring in hand: ride it
local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then return end
	humanoid.StateChanged:Connect(function(_, new)
		if new ~= Enum.HumanoidStateType.Swimming or busy or not held() or humanoid.Sit then return end
		busy = true
		-- (hold still while the ring goes on the water and you get in: swimming on, you were out of reach)
		local speed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		task.spawn(function()
			local ok, model = remote:InvokeServer("Float")
			if ok and typeof(model) == "Instance" then
				local rides = script.Parent:FindFirstChild("ParkRidesController")
				local event = rides and rides:FindFirstChild("ParkBoardTube")
				if event and event:IsA("BindableEvent") then event:Fire(model) end
				for _ = 1, 30 do
					if humanoid.Sit then break end
					task.wait(0.1)
				end
			end
			if humanoid.WalkSpeed == 0 then humanoid.WalkSpeed = speed end
			task.wait(0.5)
			busy = false
		end)
	end)
end
if player.Character then task.spawn(onCharacter, player.Character) end
player.CharacterAdded:Connect(onCharacter)

-- a tap with the ring in hand: put it down, unless the tap is on a person (then GiveController offers it).
-- Only a short tap that did not move (a drag turns the camera on phones)
local downAt: {[InputObject]: { pos: Vector3, t: number }} = {}
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	downAt[input] = { pos = input.Position, t = os.clock() }
end)
UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
	local down = downAt[input]
	downAt[input] = nil
	if not down or processed or busy or not held() then return end
	if os.clock() - down.t > 0.35 or (input.Position - down.pos).Magnitude > 12 then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and Players:GetPlayerFromCharacter(model) then return end
	end
	busy = true
	task.spawn(function()
		remote:InvokeServer("PutDown")
		busy = false
	end)
end)

-- the heap's prompt: 반납 while holding one
local function label(prompt: ProximityPrompt)
	local text = if owns() then "튜브 반납" else "튜브 들기"
	if prompt.ActionText ~= text then prompt.ActionText = text end
end
while true do
	for _, pile in ipairs(CollectionService:GetTagged("TubePile")) do
		local prompt = pile:FindFirstChild("TubePrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then label(prompt) end
	end
	task.wait(0.3)
end

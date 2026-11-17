--!strict
-- The beach ring on this screen (D-1591; D-1654, user 2026-11-17; the server side is TubeRentService):
--   * holding the ring, a tap on the sea: "PutDown" with the tapped point floats it there;
--   * a tap on a person is GiveController's 🎁 주기;
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

-- (D-1654, user 2026-11-17: "튜브 들고 바다 가서 물 클릭해야 튜브 놔지게 수정") a short tap with the
-- ring in hand that lands on the sea (terrain water) puts the ring on the water there; a tap on a
-- person is GiveController's 🎁 주기, and anything else does nothing. Walking into the sea no longer
-- puts the ring down by itself. Only a short tap that did not move (a drag turns the camera on phones)
local busy = false
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
	params.IgnoreWater = false
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if not hit then return end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	if model and Players:GetPlayerFromCharacter(model) then return end
	if hit.Instance ~= workspace.Terrain or hit.Material ~= Enum.Material.Water then return end
	busy = true
	task.spawn(function()
		local ok, message = remote:InvokeServer("PutDown", hit.Position)
		if not ok and typeof(message) == "string" then
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", { Title = "튜브", Text = message, Duration = 3 })
			end)
		end
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

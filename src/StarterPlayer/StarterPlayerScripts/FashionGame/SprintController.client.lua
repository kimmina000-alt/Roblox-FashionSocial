--!strict
-- Running (user 2026-10-27: "달리기 기능 추가"). Until now there was one speed
-- (Roblox's default 16, the run animation at walking pace). Now 16 is the
-- walk and the run is faster:
--   * PC: hold Ctrl (Shift is Roblox's shift lock, EnableMouseLockOption is on)
--   * phone: the 🏃 button next to the jump button turns running on and off
--     (🚶 while it is on)
-- The client owns its character's movement, so the speed is set here.
-- FootstepsController hears the faster steps as a run.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local WALK_SPEED = 16
local RUN_SPEED = 26
local ACTION = "FashionSprint"

local player = Players.LocalPlayer
local running = false

local function apply()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = if running then RUN_SPEED else WALK_SPEED end
	ContextActionService:SetTitle(ACTION, if running then "🚶" else "🏃")
end

local function onAction(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if input.UserInputType == Enum.UserInputType.Touch then
		-- the touch button switches
		if state == Enum.UserInputState.Begin then
			running = not running
			apply()
		end
	else
		-- Ctrl (or a gamepad stick press) is held
		if state == Enum.UserInputState.Begin then
			running = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			running = false
		end
		apply()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(ACTION, onAction, true, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle(ACTION, "🏃")

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid", 10)
	apply()
end)
apply()

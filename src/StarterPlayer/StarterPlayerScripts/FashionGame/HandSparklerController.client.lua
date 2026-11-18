--!strict
-- "🔥" (user 2026-10-27, words dropped D-1593): holding an unlit hand sparkler shows this
-- button above the hotbar; pressing it lights the sparkler (SparkleService
-- "LightHandSparkler"), then the button goes. The sparkler burns down on its own.
-- (D-1724, user 2026-11-18: "손 스파클러 불 아이콘 지우고 화면 두번 누르면 불 붙는 걸로 수정") no 🔥 button any
-- more: holding an unlit hand sparkler, two taps (clicks) on the open screen within DOUBLE_TAP seconds
-- light it. Taps on buttons, the thumbstick or a drag of the camera do not count.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local DOUBLE_TAP = 0.4
local ClubShop = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("ClubShop") :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "HandSparklerGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

-- (D-1593, user 2026-11-17: "불 붙이기 삭제하고 앞에 불 모양 아이콘만 남기기. 불 모양 아이콘 흰색 외곽선 주고
-- 배경 지우기") only a 🔥 picture with a white outline (an emoji takes no outline: docs/04_ART/icons/
-- fire_outline.png, uploaded as Vantablack_Dev), no words, no background
local button = Instance.new("ImageButton")
button.Name = "Light"
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -110)
button.Size = UDim2.fromOffset(64, 64)
button.BackgroundTransparency = 1
button.Image = "rbxassetid://79006995744297"
button.Visible = false
button.Parent = gui

local function held(): Tool?
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return if tool and tool:GetAttribute("HandSparkler") then tool else nil
end

-- (D-1787, user 2026-11-18: a gifted hand sparkler told nothing about how to
-- light it) while an unlit hand sparkler is held, a line above the hotbar says
-- how: two taps on the screen. Gone once it burns or is put away.
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -168) -- (above the toasts)
hint.Size = UDim2.fromOffset(320, 30)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextSize = 17
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextStrokeTransparency = 0.35
hint.Text = "✨ 화면을 두 번 누르면 불이 붙어요"
hint.Visible = false
hint.Parent = gui

local function refresh()
	button.Visible = false -- (D-1724: the 🔥 button stays hidden)
	local tool = held()
	hint.Visible = tool ~= nil and not tool:GetAttribute("Lit")
end

local lighting = false
local function light()
	local tool = held()
	if lighting or not tool or tool:GetAttribute("Lit") then return end
	lighting = true
	pcall(function() ClubShop:InvokeServer("LightHandSparkler", nil) end)
	lighting = false
end

-- (D-1724) two taps on the open screen
local lastTap = 0
local function tapped()
	local tool = held()
	if not tool or tool:GetAttribute("Lit") then lastTap = 0 return end
	local now = os.clock()
	if now - lastTap <= DOUBLE_TAP then
		lastTap = 0
		task.spawn(light)
	else
		lastTap = now
	end
end
UserInputService.TouchTap:Connect(function(_, processed)
	if not processed then tapped() end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then tapped() end
end)

-- (D-1786) the sparkler is in the left hand (SparklerHands on the server): Roblox's
-- "tool held out" pose (Animate's ToolNoneAnim) would keep the empty right arm
-- out in front, so it is stopped while a hand sparkler is held (the Animate
-- script does not start it again for the same tool)
local function dropToolPose(character: Model, tool: Tool)
	for _ = 1, 10 do
		if tool.Parent ~= character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Animation and track.Animation.Name == "ToolNoneAnim" then track:Stop(0.2) end
			end
		end
		task.wait(0.1)
	end
end

local function watch(character: Model)
	character.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			if c:GetAttribute("HandSparkler") then task.spawn(dropToolPose, character, c) end
			refresh()
			c:GetAttributeChangedSignal("Lit"):Connect(refresh)
		end
	end)
	character.ChildRemoved:Connect(refresh)
	refresh()
end
player.CharacterAdded:Connect(watch)
if player.Character then watch(player.Character) end

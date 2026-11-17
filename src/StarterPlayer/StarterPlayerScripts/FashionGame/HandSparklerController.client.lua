--!strict
-- "🔥" (user 2026-10-27, words dropped D-1593): holding an unlit hand sparkler shows this
-- button above the hotbar; pressing it lights the sparkler (SparkleService
-- "LightHandSparkler"), then the button goes. The sparkler burns down on its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
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

local function refresh()
	local tool = held()
	button.Visible = tool ~= nil and not tool:GetAttribute("Lit")
end

button.MouseButton1Click:Connect(function()
	if not held() then return end
	button.Visible = false
	pcall(function() ClubShop:InvokeServer("LightHandSparkler", nil) end)
	refresh()
end)

local function watch(character: Model)
	character.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			refresh()
			c:GetAttributeChangedSignal("Lit"):Connect(refresh)
		end
	end)
	character.ChildRemoved:Connect(refresh)
	refresh()
end
player.CharacterAdded:Connect(watch)
if player.Character then watch(player.Character) end

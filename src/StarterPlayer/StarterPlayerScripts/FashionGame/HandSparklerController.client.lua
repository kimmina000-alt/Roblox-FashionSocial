--!strict
-- "🔥 불 붙이기" (user 2026-10-27): holding an unlit hand sparkler shows this
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

local button = Instance.new("TextButton")
button.Name = "Light"
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -110)
button.Size = UDim2.fromOffset(170, 50)
button.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
button.Text = "🔥 불 붙이기"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextScaled = true
button.Font = Enum.Font.GothamBlack
button.Visible = false
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 14)
do local p = Instance.new("UIPadding") p.PaddingTop = UDim.new(0, 8) p.PaddingBottom = UDim.new(0, 8) p.Parent = button end

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

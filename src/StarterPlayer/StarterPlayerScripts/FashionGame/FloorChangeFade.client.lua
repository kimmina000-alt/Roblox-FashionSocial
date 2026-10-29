--!strict
-- A short black fade when the player is moved between floors in one step
-- (오후네컷: the WHITE room is upstairs and its door is on the ground floor,
-- user 2026-10-30: "자연스럽게 이동한 것처럼"), so the jump reads as going
-- through the door instead of a cut.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "FloorFade"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 90
gui.Parent = player:WaitForChild("PlayerGui")
local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.new(0, 0, 0)
cover.BackgroundTransparency = 1
cover.BorderSizePixel = 0
cover.Active = false
cover.Parent = gui

local FADE = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local last: Vector3? = nil
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		last = nil
		return
	end
	local p = root.Position
	-- one frame, far, and a floor's height up or down
	if last and (p - last).Magnitude > 20 and math.abs(p.Y - last.Y) > 12 then
		cover.BackgroundTransparency = 0
		TweenService:Create(cover, FADE, { BackgroundTransparency = 1 }):Play()
	end
	last = p
end)

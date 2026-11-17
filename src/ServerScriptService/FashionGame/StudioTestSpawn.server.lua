--!strict
-- 테스트용 스포너 (D-1732, user 2026-11-18: "테스트용 스포너 한옥 마을 입구 안에 만들어줘").
-- Studio play tests only: every character (Player1, Player2, ... and a solo Play) appears just inside the
-- 광화문 gate of the hanok village, facing into the village, instead of the real spawn by the guide
-- (D-1696). Live servers never move anyone. Switch: attribute StudioTestSpawn on
-- ReplicatedStorage.FashionGame (true = on; nil / false = the real spawn).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then return end

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
-- just past the gate (the guide's 광화문 view runs from (120, 165) to the gate roof at (165, 215)); the
-- ground there is terrain at y 2.0 (checked 2026-11-18)
local AT = Vector3.new(178, 2 + 3, 230)
local INTO = Vector3.new(165 - 120, 0, 215 - 165).Unit

local function place(character: Model)
	if FashionGame:GetAttribute("StudioTestSpawn") ~= true then return end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then return end
	task.wait(0.2) -- (after the default spawn has placed the character)
	if character.Parent then character:PivotTo(CFrame.lookAt(AT, AT + INTO)) end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(place)
	if player.Character then task.spawn(place, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end

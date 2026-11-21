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
-- (D-1916, 2026-11-21) the hanok village behind the gate is gone and the map boundary runs along the
-- palace walls, so the old spot (178, 230) inside the gate is out of bounds: now on the 광화문 plaza in
-- front of the gate (PlazaStone, top y 0.3, checked 2026-11-21), facing the closed gate at (180.7, 184)
-- (D-1818o, user 2026-11-21: "테스트 스포너 포켓공원으로") now in the pocket park, on the plaza just south of the
-- neon stage's steps (ground y -1.98, checked 2026-11-21), facing the stage centre (-96, -128)
local AT = Vector3.new(-96, -1.98 + 3, -102)
local INTO = Vector3.new(0, 0, -1)

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

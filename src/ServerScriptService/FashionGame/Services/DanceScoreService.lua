--!strict
-- 안무 따라 하기 점수 "오늘의 곡 도전" (D-1816, DanceScoreConfig, docs/01_SYSTEMS/DANCE_SCORE.md).
-- Remote "DanceScore" (RemoteFunction):
--   "Start"  → only on the neon stage: the challenge starts CountIn seconds from now; character
--              attributes DanceChallenge = that server time, DanceChallengeTrack = the song's soundId,
--              so every screen keeps this dancer on their own song clock (RemoteChoreoSync).
--              Returns (true, start, soundId).
--   "Stop"   → the challenge ends (quit, walked off, the song ended).
--   "Finish" { perfect, great, miss, combo } → checked against the chart and the time played; the
--              score the server works out from it is returned (step 2 keeps the day's best).
-- The client judges the taps on its own clock (phones lag); the server only throws out what cannot be.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local DanceScoreConfig = require(Shared:WaitForChild("DanceScoreConfig"))
local NeonStageConfig = require(Shared:WaitForChild("NeonStageConfig"))

local DanceScoreService = {}

type Run = { start: number, soundId: number, total: number }
local runs: {[Player]: Run} = {}

local function setAttributes(player: Player, start: number?, soundId: number?)
	local character = player.Character
	if not character then return end
	character:SetAttribute("DanceChallenge", start)
	character:SetAttribute("DanceChallengeTrack", soundId)
end

local function stop(player: Player)
	runs[player] = nil
	setAttributes(player, nil, nil)
end

local function start(player: Player): (boolean, any, any)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not NeonStageConfig.onStage(root.Position) then
		return false, "네온 무대 위에서 도전할 수 있어요.", nil
	end
	local soundId = DanceScoreConfig.TodaySong
	local track = NeonStageConfig.trackById(soundId)
	if not track then return false, "오늘의 곡을 찾을 수 없어요.", nil end
	local at = workspace:GetServerTimeNow() + DanceScoreConfig.CountIn
	runs[player] = { start = at, soundId = soundId, total = #DanceScoreConfig.chart(track) }
	setAttributes(player, at, soundId)
	return true, at, soundId
end

local function finish(player: Player, result: any): (boolean, any)
	local run = runs[player]
	stop(player)
	if not run or typeof(result) ~= "table" then return false, nil end
	local perfect, great, miss, combo = result.perfect, result.great, result.miss, result.combo
	for _, v in ipairs({ perfect, great, miss, combo }) do
		if typeof(v) ~= "number" or v ~= v or v < 0 or v % 1 ~= 0 then return false, nil end
	end
	local track = NeonStageConfig.trackById(run.soundId)
	if not track then return false, nil end
	-- what cannot be: more judged notes than the chart has, a combo over the hits, or a finish before
	-- most of the song has played
	local played = workspace:GetServerTimeNow() - run.start
	if perfect + great + miss > run.total + 2 or combo > perfect + great
		or played < DanceScoreConfig.runLength(track) * 0.85 then
		return false, nil
	end
	local score = DanceScoreConfig.score(run.total, perfect, great)
	return true, { score = score, grade = DanceScoreConfig.grade(score) }
end

function DanceScoreService.Start()
	local Remotes = FashionGame:WaitForChild("Remotes")
	local remote = Remotes:FindFirstChild("DanceScore") :: RemoteFunction?
	if not remote then
		local r = Instance.new("RemoteFunction")
		r.Name = "DanceScore"
		r.Parent = Remotes
		remote = r
	end
	(remote :: RemoteFunction).OnServerInvoke = function(player: Player, action: any, payload: any)
		if action == "Start" then
			return start(player)
		elseif action == "Stop" then
			stop(player)
			return true
		elseif action == "Finish" then
			return finish(player, payload)
		end
		return false
	end
	Players.PlayerRemoving:Connect(function(player) runs[player] = nil end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function() runs[player] = nil end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function() runs[player] = nil end)
	end
end

return DanceScoreService

--!strict
-- Cafe grand piano (user 2026-10-25): a player sitting on the piano bench
-- plays notes from the on-screen keyboard (PianoController). Each note goes
-- to the server once and is passed on to everyone else, who hear it at the
-- piano. Remote PianoNote (RemoteEvent): client → server (midi), server →
-- clients (player, midi).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")

local PianoService = {}

local MIN_NOTE, MAX_NOTE = 48, 84
local MAX_PER_SECOND = 20

local recent: { [Player]: { t: number, n: number } } = {}

local function onPianoBench(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat.Name == "PianoBench"
end

function PianoService.Start()
	local remote = Remotes:WaitForChild("PianoNote") :: RemoteEvent
	remote.OnServerEvent:Connect(function(player: Player, midi: any)
		if typeof(midi) ~= "number" or midi ~= math.floor(midi) or midi < MIN_NOTE or midi > MAX_NOTE then return end
		if not onPianoBench(player) then return end
		local now = os.clock()
		local r = recent[player]
		if not r or now - r.t >= 1 then
			r = { t = now, n = 0 }
			recent[player] = r
		end
		r.n += 1
		if r.n > MAX_PER_SECOND then return end
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then remote:FireClient(other, player, midi) end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) recent[player] = nil end)
end

return PianoService

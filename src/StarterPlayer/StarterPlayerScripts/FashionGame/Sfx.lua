--!strict
-- Plays the small 2D sound effects of SoundConfig on this screen only
-- (Sfx.play("click")). One Sound per name in SoundService; playing it again
-- restarts it, so fast taps never pile up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("SoundConfig"))

local Sfx = {}

local VOLUME: {[string]: number} = {
	click = 0.35, open = 0.3, prompt = 0.35, error = 0.4, success = 0.45,
	earn = 0.3, spend = 0.45, teleport = 0.4,
}
local IDS: {[string]: number} = {
	click = SoundConfig.Ui.click, open = SoundConfig.Ui.open, prompt = SoundConfig.Ui.prompt,
	error = SoundConfig.Ui.error, success = SoundConfig.Ui.success,
	earn = SoundConfig.Coin.earn, spend = SoundConfig.Coin.spend,
	teleport = SoundConfig.Body.teleport,
}

local folder = Instance.new("Folder")
folder.Name = "FashionSfx"
folder.Parent = SoundService
local sounds: {[string]: Sound} = {}

function Sfx.play(name: string, volume: number?)
	local id = IDS[name]
	if not id then return end
	local s = sounds[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = "rbxassetid://" .. id
		s.Parent = folder
		sounds[name] = s
	end
	s.Volume = volume or VOLUME[name] or 0.4
	s.TimePosition = 0
	s:Play()
end

return Sfx

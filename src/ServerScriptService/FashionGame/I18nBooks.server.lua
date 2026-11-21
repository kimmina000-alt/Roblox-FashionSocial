--!strict
-- (D-1845, memory session + user 2026-11-21 "둘 다 진행해") each player gets only their own
-- translation table. The 16 tables (Shared/L, tools/i18n) live in ServerStorage.FashionGame.I18n;
-- a copy of the player's one goes into PlayerGui.I18nBook (PlayerGui replicates to that player
-- only), where Shared/L looks for it. Korean players get nothing.
-- Studio: the Lang attribute (ReplicatedStorage.FashionGame or the player) picks the language.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local L = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("L"))
local books = ServerStorage:WaitForChild("FashionGame"):WaitForChild("I18n")

local function give(player: Player)
	local lang = L.langOf(player)
	if lang == "ko" then return end
	local src = books:FindFirstChild(lang)
	if not src then return end
	local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 30)
	if not pg or not player.Parent then return end
	local box = pg:FindFirstChild("I18nBook")
	if not box then
		box = Instance.new("Folder")
		box.Name = "I18nBook"
	end
	if not box:FindFirstChild(lang) then
		src:Clone().Parent = box
	end
	box.Parent = pg
end

local function watch(player: Player)
	task.spawn(give, player)
	-- the locale can arrive a moment after joining; Studio tests may set Lang on the player
	player:GetPropertyChangedSignal("LocaleId"):Connect(function() task.spawn(give, player) end)
	player:GetAttributeChangedSignal("Lang"):Connect(function() task.spawn(give, player) end)
end

Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do watch(p) end

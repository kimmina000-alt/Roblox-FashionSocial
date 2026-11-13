--!strict
-- The items a player carries stay theirs across a rejoin and a respawn (user
-- 2026-11-03, D-790: "구매한 아이템 다 먹은 거 아니면 재접속했을 때 그 상태 그대로").
-- Foods and drinks (bites left, cake pieces, food put down on a table), whole
-- cake / 수육 plates, club bottles (cups left) and cups, unlit sparklers,
-- sparkler bucket sets and hand sparklers. Not saved: 알바 order cups, photos
-- (the album has them), the glowstick (its pass gives it on every spawn).
--
-- Each service lists its own items as plain entries (BagEntries) and makes
-- them again (BagRestore). The list is written into wallet.bag just before
-- every save (autosave and the leave-save; when leaving, the note taken every
-- 2 s, since the character and the tool in its hand are gone by then); on the
-- first spawn of a visit the saved list comes back, and after a death the list
-- noted when the character died.

local Players = game:GetService("Players")

local BagService = {}

type Source = { BagEntries: (Player) -> {any}, BagRestore: (Player, any) -> boolean }

local sources: {Source} = {}
local pending: {[Player]: {any}} = {} -- noted when a character went (respawn)
local restored: {[Player]: boolean} = {} -- the saved list came back this visit
local seen: {[Player]: {any}} = {} -- what was carried at the last look (every 2 s)

local function collect(player: Player): {any}
	local all = {}
	for _, src in ipairs(sources) do
		local ok, list = pcall(src.BagEntries, player)
		if ok and typeof(list) == "table" then
			for _, e in ipairs(list) do table.insert(all, e) end
		end
	end
	return all
end

local function give(player: Player, list: {any})
	for _, e in ipairs(list) do
		for _, src in ipairs(sources) do
			local ok, done = pcall(src.BagRestore, player, e)
			if ok and done then break end
		end
	end
end

-- (D-1396) the entries a player carries now, and making entries again for a player
-- (GiveService hands one item over with them: the item is written down and made again)
function BagService.collect(player: Player): {any}
	return collect(player)
end
function BagService.give(player: Player, list: {any})
	give(player, list)
end

function BagService.Start(playerData: any, snack: Source, drink: Source, sparkle: Source)
	sources = { snack, drink, sparkle }
	-- (only a visit whose saved list already came back writes a new one: a
	-- save before that would drop the items still waiting to be given)
	playerData.OnBeforeSave(function(player: Player)
		if not restored[player] then return end
		local w = playerData.Wallet(player)
		-- (by PlayerRemoving the character is gone, and the tool in the hand
		-- with it, measured in Play: then the note from up to 2 s before)
		w.bag = if player.Character then collect(player) else (seen[player] or collect(player))
		playerData.MarkDirty(player)
		-- (Studio: Studio has no saved data to rejoin with; the last list written
		-- is kept to read in a test)
		if game:GetService("RunService"):IsStudio() then
			game:GetService("ServerStorage"):SetAttribute("StudioLastBag", game:GetService("HttpService"):JSONEncode(w.bag))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if restored[player] and humanoid and humanoid.Health > 0 then seen[player] = collect(player) end
			end
		end
	end)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- (noted when the character dies: by CharacterRemoving the backpack
			-- has already been emptied; the game itself never respawns anyone)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					if player.Parent then pending[player] = collect(player) end
				end)
			end
			local backpack = player:WaitForChild("Backpack", 10)
			if not backpack then return end
			task.wait(1) -- (after the game's own spawn gifts, the glowstick)
			if not player.Parent then return end
			if not restored[player] then
				local w = playerData.Wallet(player)
				local list = if typeof(w.bag) == "table" then w.bag else {}
				restored[player] = true
				give(player, list)
			elseif pending[player] then
				local list = pending[player]
				pending[player] = nil
				give(player, list)
			end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		-- (the leave-save runs in PlayerDataService's own handler and notes the
		-- list first; this only lets go of the memory a moment later)
		task.delay(5, function()
			pending[player] = nil
			restored[player] = nil
			seen[player] = nil
		end)
	end)
end

return BagService

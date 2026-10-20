--!strict
-- In-game coins 🪙 (D-064, docs/01_SYSTEMS/ECONOMY.md).
--
-- The balance lives in the player's wallet (PlayerDataService) and is shown
-- to everyone as the player attribute "Coins". Unlocked frames are mirrored
-- as the JSON attribute "OwnedFrames" so the client can show locks.
--
--   * Passive: EconomyConfig.PassiveAmount every PassiveSeconds while the
--     player is active (moved or danced within ActiveWindow seconds).
--   * Bonuses: EconomyService.Award(player, "PhotoSaved") etc., each with a
--     daily count (EconomyConfig.Bonuses). Days are UTC.
--   * Spending: EconomyService.Spend(player, amount) → true when paid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local PhotoConfig = require(Shared:WaitForChild("PhotoConfig"))
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))

local EconomyService = {}

local playerData: any = nil
local lastPosition: {[Player]: Vector3} = {}
local lastActive: {[Player]: number} = {}
local danceSeconds: {[Player]: number} = {}

local function today(): string
	return os.date("!%Y%m%d") :: string
end

local function toast(player: Player, message: string)
	local remotes = FashionGame:FindFirstChild("Remotes")
	local notify = remotes and remotes:FindFirstChild("ClubNotify")
	if notify and notify:IsA("RemoteEvent") then notify:FireClient(player, "Toast", message) end
end

local function wallet(player: Player): any
	local w = playerData.Wallet(player)
	if w.daily.day ~= today() then
		w.daily.day = today()
		w.daily.counts = {}
	end
	return w
end

local function publish(player: Player)
	if not player.Parent then return end
	local w = playerData.Wallet(player)
	player:SetAttribute("Coins", w.coins)
	player:SetAttribute("OwnedFrames", HttpService:JSONEncode(w.frames))
	player:SetAttribute("AlbumSlots", w.slots)
end
EconomyService.Publish = publish

local function add(player: Player, amount: number)
	if amount <= 0 then return end
	local w = wallet(player)
	w.coins = math.min(EconomyConfig.MaxBalance, w.coins + amount)
	playerData.MarkDirty(player)
	publish(player)
end

function EconomyService.Balance(player: Player): number
	return playerData.Wallet(player).coins
end

-- Activity bonus. Returns the amount given (0 when capped).
function EconomyService.Award(player: Player, key: string): number
	local bonus = EconomyConfig.Bonuses[key]
	if not bonus then return 0 end
	local w = wallet(player)
	local count = w.daily.counts[key] or 0
	local amount = if count < bonus.perDay then bonus.amount else bonus.after
	w.daily.counts[key] = count + 1
	playerData.MarkDirty(player)
	if amount > 0 then
		add(player, amount)
		toast(player, string.format("%s +%d %s · %s", EconomyConfig.Icon, amount, EconomyConfig.CurrencyName, bonus.text))
	end
	return amount
end

function EconomyService.Spend(player: Player, amount: number): boolean
	if amount <= 0 then return true end
	local w = wallet(player)
	if w.coins < amount then return false end
	w.coins -= amount
	playerData.MarkDirty(player)
	publish(player)
	return true
end

-- Studio play tests only (never on live servers): give test coins.
function EconomyService.StudioGrant(player: Player, amount: any): (boolean, string?)
	if not game:GetService("RunService"):IsStudio() then return false, "Studio 테스트 전용이에요." end
	if typeof(amount) ~= "number" or amount <= 0 or amount > 10000 then return false, "잘못된 금액이에요." end
	add(player, math.floor(amount))
	return true, nil
end

-- Frames ------------------------------------------------------------------

function EconomyService.OwnsFrame(player: Player, key: string): boolean
	local frame = PhotoConfig.findFrame(key)
	if not frame then return false end
	if frame.price == "free" then return true end
	if frame.price == "pass" then return player:GetAttribute("Pass_FramePack") == true end
	return table.find(playerData.Wallet(player).frames, key) ~= nil
end

function EconomyService.BuyFrame(player: Player, key: any): (boolean, string?)
	local frame = PhotoConfig.findFrame(key)
	if not frame then return false, "없는 프레임이에요." end
	if EconomyService.OwnsFrame(player, frame.key) then return true, "이미 가지고 있는 프레임이에요." end
	if frame.price ~= "coins" or not frame.coins then return false, "프레임 팩으로 살 수 있어요." end
	if not EconomyService.Spend(player, frame.coins) then
		return false, string.format("%s이 부족해요 (%d 필요, 지금 %d).", EconomyConfig.CurrencyName, frame.coins, EconomyService.Balance(player))
	end
	table.insert(playerData.Wallet(player).frames, frame.key)
	playerData.MarkDirty(player)
	publish(player)
	return true, frame.name .. " 프레임을 샀어요!"
end

-- Album slots (Developer Product "AlbumSlots").
function EconomyService.AddAlbumSlots(player: Player, count: number)
	local w = playerData.Wallet(player)
	w.slots = math.min(PhotoConfig.HardMaxPhotos - PhotoConfig.MaxPhotos, w.slots + count)
	playerData.MarkDirty(player)
	publish(player)
end

--------------------------------------------------------------------------------

local function activityTick()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and character then
			local previous = lastPosition[player]
			if not previous or (root.Position - previous).Magnitude > 2 then
				lastActive[player] = now
			end
			lastPosition[player] = root.Position
			-- Dancing in the club counts as active and towards Dance5Min.
			if character:GetAttribute("DanceKey") ~= nil then
				lastActive[player] = now
				if ClubConfig.isInClub(root.Position) then
					danceSeconds[player] = (danceSeconds[player] or 0) + 10
					if danceSeconds[player] >= 300 then
						danceSeconds[player] = 0
						EconomyService.Award(player, "Dance5Min")
					end
				end
			end
		end
	end
end

local function passiveTick()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		if lastActive[player] and now - lastActive[player] <= EconomyConfig.ActiveWindow then
			local w = wallet(player)
			local minutes = w.daily.counts.Passive or 0
			w.daily.counts.Passive = minutes + 1
			add(player, if minutes < EconomyConfig.PassiveFullMinutes then EconomyConfig.PassiveAmount else EconomyConfig.PassiveReducedAmount)
		end
	end
end

function EconomyService.Start(dataService: any)
	playerData = dataService
	local function onPlayer(player: Player)
		task.spawn(function()
			publish(player)
			EconomyService.Award(player, "DailyLogin")
		end)
		player:GetAttributeChangedSignal("Pass_FramePack"):Connect(function() publish(player) end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
	Players.PlayerRemoving:Connect(function(player)
		lastPosition[player] = nil
		lastActive[player] = nil
		danceSeconds[player] = nil
	end)
	task.spawn(function()
		local elapsed = 0
		while true do
			task.wait(10)
			activityTick()
			elapsed += 10
			if elapsed >= EconomyConfig.PassiveSeconds then
				elapsed = 0
				passiveTick()
			end
		end
	end)
end

return EconomyService

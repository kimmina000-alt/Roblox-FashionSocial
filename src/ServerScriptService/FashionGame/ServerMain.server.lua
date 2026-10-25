--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")

local CatalogSearch = Remotes:WaitForChild("CatalogSearch")
local TryOnItem = Remotes:WaitForChild("TryOnItem")
local PlayerData = Remotes:WaitForChild("PlayerData")

local AvatarService = require(
	script.Parent.Services.AvatarService
)
local PlayerDataService = require(
	script.Parent.Services.PlayerDataService
)
PlayerDataService.Start()
local MonetizationService = require(script.Parent.Services.MonetizationService)
local DjService = require(script.Parent.Services.DjService)
local ClubAccessService = require(script.Parent.Services.ClubAccessService)
local DrinkService = require(script.Parent.Services.DrinkService)
local ClubService = require(
	script.Parent.Services.ClubService
)
local ClubScreenService = require(script.Parent.Services.ClubScreenService)
local EconomyService = require(script.Parent.Services.EconomyService)
local PhotoBoothService = require(script.Parent.Services.PhotoBoothService)
MonetizationService.Start()
EconomyService.Start(PlayerDataService)
DjService.Start()
ClubAccessService.Start()
DrinkService.Start()
ClubService.Start()
ClubScreenService.Start()
PhotoBoothService.Start(PlayerDataService)
require(script.Parent.Services.ParkRideService).Start()
-- XP name tags are locked with XP (EconomyConfig.XPEnabled, user 2026-10-22):
-- players keep Roblox's own name display.
if require(game:GetService("ReplicatedStorage").FashionGame.Shared.EconomyConfig).XPEnabled then
	require(script.Parent.Services.NameTagService).Start()
end
local SnackService = require(script.Parent.Services.SnackService)
SnackService.Start(EconomyService)
require(script.Parent.Services.CafeJobService).Start(EconomyService, SnackService)
require(script.Parent.Services.SubwayService).Start()
require(script.Parent.Services.PianoService).Start()
local SparkleService = require(script.Parent.Services.SparkleService)
SparkleService.Start()
local RankingService = require(script.Parent.Services.RankingService)
RankingService.Start()
local BusAdService = require(script.Parent.Services.BusAdService)
BusAdService.Start()

-- DJ time (Developer Product "DJ"): add time and tell the buyer. A buyer who
-- becomes DJ right away is asked whether to go to the booth; queued buyers
-- are asked when their turn starts (ClubAccessService). Nobody is moved
-- without saying OK (user, 2026-10-20).
local ClubNotify = Remotes:WaitForChild("ClubNotify") :: RemoteEvent
MonetizationService.RegisterProduct("DJ", function(player)
	local ok, message, kind = DjService.AddTime(player)
	if ok and message then
		ClubNotify:FireClient(player, "Toast", message)
	end
	if ok and kind == "start" then
		task.defer(ClubAccessService.OfferDJBooth, player, false)
	end
	return ok, message
end)

-- 1 hour of coin x2 (D-278).
MonetizationService.RegisterProduct("CoinBoost1h", function(player)
	EconomyService.AddBoost(player, 3600)
	ClubNotify:FireClient(player, "Toast", "⏱ 코인 x2 부스트 1시간이 시작됐어요!")
	return true, nil
end)
-- (the CoinX2 pass needs no handler: EconomyService reads Pass_CoinX2)

-- 인생네컷 album +10 slots.
local PhotoConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("PhotoConfig"))
MonetizationService.RegisterProduct("AlbumSlots", function(player)
	EconomyService.AddAlbumSlots(player, PhotoConfig.SlotsPerPurchase)
	ClubNotify:FireClient(player, "Toast", string.format("사진첩이 %d장 늘어났어요!", PhotoConfig.SlotsPerPurchase))
	return true, nil
end)

-- Club shop: drink orders, bottle placement, Studio test purchases.
local ClubShop = Remotes:WaitForChild("ClubShop") :: RemoteFunction
ClubShop.OnServerInvoke = function(player: Player, action: any, payload: any)
	if action == "StudioTestBuy" then
		if typeof(payload) ~= "table" then return false, "잘못된 요청입니다." end
		return MonetizationService.StudioTestBuy(player, payload.kind, payload.key)
	elseif action == "StudioGrantCoins" then
		-- Studio play tests only (EconomyService refuses on live servers).
		return EconomyService.StudioGrant(player, payload)
	end
	if typeof(action) ~= "string" then return false, "잘못된 요청입니다." end
	-- DJ 차례 window: OK → go to the booth, NO → pass the turn (no refund).
	if action == "DJGo" then
		ClubAccessService.SendToDJBooth(player)
		return true, nil
	elseif action == "DJPass" then
		if DjService.Pass(player) then
			return true, "DJ 차례를 다음 사람에게 넘겼어요."
		end
		return false, "지금 DJ 차례가 아니에요."
	end
	if action == "RankHidden" then
		-- "순위에 내 이름 숨기기" (the 💝 window)
		RankingService.SetHidden(player, payload == true)
		return true, nil
	end
	-- sparklers / cold spark / supporter gifts: the table and message picked before buying
	local ok, result, handled = SparkleService.Handle(player, action, payload)
	if handled then return ok, result end
	ok, result, handled = BusAdService.Handle(player, action, payload)
	if handled then return ok, result end
	return DrinkService.Handle(player, action, payload)
end

CatalogSearch.OnServerInvoke = function(
	player: Player,
	keyword: string
)
	return false, "Catalog search runs on the client."
end

-- One avatar mutation at a time per player (ISSUE-AUDIT-002).
local busyPlayers: {[Player]: boolean} = {}

local function runExclusive(player: Player, fn: () -> (boolean, any)): (boolean, any)
	if busyPlayers[player] then
		return false, "Please wait for the previous change to finish."
	end
	busyPlayers[player] = true
	local ok, result, message = pcall(fn)
	busyPlayers[player] = nil
	if not ok then
		warn("[FashionGame][Server] Avatar action error:", result)
		return false, "Avatar change failed."
	end
	return result, message
end

-- Typed item identity (ISSUE-AUDIT-001): Wear/Remove take {id, itemType}.
-- A bare number is still accepted and means an Asset.
local function typedItem(payload: any): (number?, string?)
	if typeof(payload) == "number" then
		return payload, "Asset"
	end
	if typeof(payload) == "table" and typeof(payload.id) == "number"
		and (payload.itemType == "Asset" or payload.itemType == "Bundle") then
		return payload.id, payload.itemType
	end
	return nil, nil
end

TryOnItem.OnServerInvoke = function(
	player: Player,
	action: string,
	payload: any
)
	if action == "GetCurrent" then
		return true, AvatarService.GetCurrentItems(player)
	end

	if action == "Wear" then
		local id, itemType = typedItem(payload)
		if not id then
			return false, "Invalid item."
		end
		return runExclusive(player, function()
			if itemType == "Bundle" then
				return AvatarService.WearBundle(player, id)
			end
			return AvatarService.TryOnItem(player, id)
		end)
	end

	if action == "WearBundle" or action == "WearShoeBundle" then
		return runExclusive(player, function()
			return AvatarService.WearBundle(player, payload)
		end)
	end

	if action == "Remove" then
		local id, itemType = typedItem(payload)
		if not id or itemType ~= "Asset" then
			return false, "Invalid item."
		end
		return runExclusive(player, function()
			return AvatarService.RemoveItem(player, id)
		end)
	end

	if action == "RemoveMany" then
		return runExclusive(player, function()
			return AvatarService.RemoveItems(player, payload)
		end)
	end

	if action == "GetEditState" then
		return AvatarService.GetEditState(player)
	end

	if action == "ApplyEdit" then
		return runExclusive(player, function()
			return AvatarService.ApplyEdit(player, payload)
		end)
	end

	-- Wardrobe restore replaces the whole appearance; it shares the same
	-- per-player gate as wear/remove/editor Apply (first request wins).
	if action == "RestoreOutfit" then
		local snapshot = PlayerDataService.GetOutfitSnapshot(player, payload)
		if not snapshot then
			return false, "저장된 코디를 찾을 수 없습니다. 이미 삭제되었을 수 있습니다."
		end
		return runExclusive(player, function()
			return AvatarService.RestoreSnapshot(player, snapshot)
		end)
	end

	if action == "GetAnimationPreview" then
		return AvatarService.GetAnimationPreview(player, payload)
	end

	if action == "SetLayerOrder" then
		return runExclusive(player, function()
			return AvatarService.SetLayerOrder(player, payload)
		end)
	end

	return false, "Invalid avatar action."
end

PlayerData.OnServerInvoke = function(player: Player, action: string, payload: any)
	if action == "SaveOutfit" then
		-- Read the confirmed applied look inside the avatar gate, then store it.
		local ok, snapshot = runExclusive(player, function()
			return AvatarService.CaptureSnapshot(player)
		end)
		if not ok then
			return false, snapshot
		end
		return PlayerDataService.SaveOutfit(player, if typeof(payload) == "table" then payload.name else nil, snapshot)
	end
	return PlayerDataService.Handle(player, action, payload)
end

-- Remember each character's own body so a worn body part can be removed.
local function watchAppearance(player: Player)
	player.CharacterAppearanceLoaded:Connect(function()
		AvatarService.RememberSpawnLook(player)
	end)
end
game:GetService("Players").PlayerAdded:Connect(watchAppearance)
for _, existing in ipairs(game:GetService("Players"):GetPlayers()) do
	watchAppearance(existing)
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	busyPlayers[player] = nil
end)

print("[FashionGame] Server initialized.")

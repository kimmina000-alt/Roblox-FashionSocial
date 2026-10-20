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
local PhotoBoothService = require(script.Parent.Services.PhotoBoothService)
MonetizationService.Start()
DjService.Start()
ClubAccessService.Start()
DrinkService.Start()
ClubService.Start()
ClubScreenService.Start()
PhotoBoothService.Start(PlayerDataService)

-- DJ time (Developer Product "DJ"): add time, tell the buyer, and move a
-- (new or extending) DJ straight to the booth. Queued buyers are moved when
-- their turn starts (ClubAccessService).
local ClubNotify = Remotes:WaitForChild("ClubNotify") :: RemoteEvent
MonetizationService.RegisterProduct("DJ", function(player)
	local ok, message = DjService.AddTime(player)
	if ok and message then
		ClubNotify:FireClient(player, "Toast", message)
	end
	if ok then
		task.defer(ClubAccessService.SendToDJBooth, player)
	end
	return ok, message
end)

-- Club shop: drink orders, bottle placement, Studio test purchases.
local ClubShop = Remotes:WaitForChild("ClubShop") :: RemoteFunction
ClubShop.OnServerInvoke = function(player: Player, action: any, payload: any)
	if action == "StudioTestBuy" then
		if typeof(payload) ~= "table" then return false, "잘못된 요청입니다." end
		return MonetizationService.StudioTestBuy(player, payload.kind, payload.key)
	end
	if typeof(action) ~= "string" then return false, "잘못된 요청입니다." end
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

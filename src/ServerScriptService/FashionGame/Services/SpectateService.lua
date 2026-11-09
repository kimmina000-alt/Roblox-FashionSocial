--!strict
-- 관전 mode for the game's owner (D-1097, user 2026-11-09: "개발자 존재 숨기고
-- 지켜볼 수 없음? 사람들 실시간으로 즐기는 거 보고 싶은데" → "둘 다 만들어 줘").
-- Type /관전 (or /spectate) in the chat: the owner's character turns invisible
-- to everyone (every part, face and accessory see-through, the name tag and
-- badges off), passes through people and things, takes no beach ball hits, is
-- left out of the rankings and the place analytics. Type it again to come
-- back. Look around with Roblox's own free camera (Shift + P on a PC; the
-- owner of a game has it in live servers). Roblox's own player list (top
-- right) still shows the name: Roblox does not let a game hide it.
-- Only the owner (game.CreatorId), and anyone in Studio tests.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local SpectateService = {}

local RankingService: any = nil

local function canSpectate(player: Player): boolean
	return RunService:IsStudio()
		or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end

local function hide(character: Model, on: boolean)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			if on then
				if d:GetAttribute("SpecT") == nil then
					d:SetAttribute("SpecT", d.Transparency)
					d:SetAttribute("SpecC", d.CanCollide)
					d:SetAttribute("SpecQ", d.CanQuery)
					d:SetAttribute("SpecTouch", d.CanTouch)
				end
				d.Transparency = 1
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			elseif d:GetAttribute("SpecT") ~= nil then
				d.Transparency = d:GetAttribute("SpecT") :: number
				d.CanCollide = d:GetAttribute("SpecC") == true
				d.CanQuery = d:GetAttribute("SpecQ") == true
				d.CanTouch = d:GetAttribute("SpecTouch") == true
				d:SetAttribute("SpecT", nil)
				d:SetAttribute("SpecC", nil)
				d:SetAttribute("SpecQ", nil)
				d:SetAttribute("SpecTouch", nil)
			end
		elseif d:IsA("Decal") then
			if on then
				if d:GetAttribute("SpecT") == nil then d:SetAttribute("SpecT", d.Transparency) end
				d.Transparency = 1
			elseif d:GetAttribute("SpecT") ~= nil then
				d.Transparency = d:GetAttribute("SpecT") :: number
				d:SetAttribute("SpecT", nil)
			end
		elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			if on then
				if d:GetAttribute("SpecOn") == nil then d:SetAttribute("SpecOn", d.Enabled) end
				d.Enabled = false
			elseif d:GetAttribute("SpecOn") ~= nil then
				d.Enabled = d:GetAttribute("SpecOn") == true
				d:SetAttribute("SpecOn", nil)
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
			if on then
				if d:GetAttribute("SpecOn") == nil then d:SetAttribute("SpecOn", (d :: any).Enabled) end
				(d :: any).Enabled = false
			elseif d:GetAttribute("SpecOn") ~= nil then
				(d :: any).Enabled = d:GetAttribute("SpecOn") == true
				d:SetAttribute("SpecOn", nil)
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local watching: {[Player]: RBXScriptConnection} = {}

function SpectateService.Set(player: Player, on: boolean): string
	if not canSpectate(player) then return "관전 모드는 게임 주인만 쓸 수 있어요." end
	player:SetAttribute("Spectating", if on then true else nil)
	local character = player.Character
	if character then hide(character, on) end
	-- (things put on later, a new accessory or tool, hidden too)
	if watching[player] then watching[player]:Disconnect() watching[player] = nil end
	if on and character then
		watching[player] = character.DescendantAdded:Connect(function()
			task.defer(function()
				if player:GetAttribute("Spectating") and player.Character == character then hide(character, true) end
			end)
		end)
	end
	if RankingService and RankingService.SetSpectating then RankingService.SetSpectating(player, on) end
	return if on
		then "👻 관전 모드: 다른 사람에게 안 보여요. PC는 Shift + P로 자유 카메라. 다시 /관전 하면 돌아와요."
		else "관전 모드를 끝냈어요. 다시 보여요."
end

function SpectateService.Start(rankingService: any)
	RankingService = rankingService
	-- the chat command (not sent to the chat as a message)
	local commands = TextChatService:FindFirstChild("TextChatCommands")
	if not commands then
		commands = Instance.new("Folder")
		commands.Name = "TextChatCommands"
		commands.Parent = TextChatService
	end
	local command = Instance.new("TextChatCommand")
	command.Name = "SpectateCommand"
	command.PrimaryAlias = "/관전"
	command.SecondaryAlias = "/spectate"
	command.Parent = commands
	command.Triggered:Connect(function(source: TextSource)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player then return end
		local message = SpectateService.Set(player, not player:GetAttribute("Spectating"))
		-- (only to them: the game's toast)
		local remotes = game:GetService("ReplicatedStorage"):WaitForChild("FashionGame"):WaitForChild("Remotes")
		local notify = remotes:FindFirstChild("ClubNotify")
		if notify and notify:IsA("RemoteEvent") then notify:FireClient(player, "Toast", message) end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			if player:GetAttribute("Spectating") then
				task.wait(0.5)
				SpectateService.Set(player, true)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if watching[player] then watching[player]:Disconnect() watching[player] = nil end
	end)
end

return SpectateService

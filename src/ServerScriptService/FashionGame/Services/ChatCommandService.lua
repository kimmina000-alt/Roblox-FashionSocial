--!strict
-- (D-1107, user 2026-11-09: "로블록스에서 공식 지원하는 TextChatCommand 사용하여
-- /re(제자리 리스폰) /sit(앉기) 명령어 추가.")
-- Chat commands (TextChatService.TextChatCommands, like /관전 in SpectateService;
-- a command is not sent to the chat as a message):
--   /re  (/리스폰): a new character on the spot where the old one stood, facing
--        the same way (a respawn: the player's own Roblox avatar, D-1032; the
--        items carried come back with it, BagService D-790)
--   /sit (/앉기): sits down where the player stands; jump to stand up
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatCommandService = {}

local RESPAWN_COOLDOWN = 3
local lastRespawn: {[Player]: number} = {}

local function command(name: string, primary: string, secondary: string, run: (Player) -> ())
	local folder = TextChatService:FindFirstChild("TextChatCommands")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TextChatCommands"
		folder.Parent = TextChatService
	end
	local c = Instance.new("TextChatCommand")
	c.Name = name
	c.PrimaryAlias = primary
	c.SecondaryAlias = secondary
	c.Parent = folder
	c.Triggered:Connect(function(source: TextSource)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then run(player) end
	end)
end

local function respawn(player: Player)
	local now = os.clock()
	if now - (lastRespawn[player] or -math.huge) < RESPAWN_COOLDOWN then return end
	lastRespawn[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = if root and root:IsA("BasePart") then root.CFrame else nil
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- (stood up first: a seat would keep the old body welded)
	if humanoid then humanoid.Sit = false end
	player:LoadCharacter()
	local new = player.Character
	if at and new then
		-- upright, the same way round
		local look = Vector3.new(at.LookVector.X, 0, at.LookVector.Z)
		local face = if look.Magnitude > 0.01 then CFrame.lookAt(at.Position, at.Position + look) else CFrame.new(at.Position)
		new:PivotTo(face)
	end
end

local function sit(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then return end
	humanoid.Sit = true
end

function ChatCommandService.Start()
	command("RespawnCommand", "/re", "/리스폰", respawn)
	command("SitCommand", "/sit", "/앉기", sit)
	Players.PlayerRemoving:Connect(function(player) lastRespawn[player] = nil end)
end

return ChatCommandService

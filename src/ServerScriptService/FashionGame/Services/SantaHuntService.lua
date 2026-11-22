--!strict
-- (D-1878) The mini Santa hunt (Shared/SantaHuntConfig). Today's Santa (SantaFactory) stands at its
-- spot in Workspace.SantaHunt on every server, dropped onto the floor below its configured point;
-- the day turns at 05:00 KST (checked every 20 s). Its ProximityPrompt "산타 찾기" records the find:
-- wallet.santa.found = a bit mask (bit n-1 = day n), published as the player attribute SantaFound.
-- A Santa counts only on its own day. Remote SantaHunt (RemoteFunction):
--   "Hold", n  → a plush of found Santa n in the hand (a Tool, one Santa plush at a time; not kept in
--               the bag: the album gives it again any time)
-- A Studio test never writes the find into the saved data (the days would be used up); the attribute
-- SantaStudioSave on ReplicatedStorage.FashionGame lets it through.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SantaHuntConfig"))
local SantaFactory = require(Shared:WaitForChild("SantaFactory"))

local SantaHuntService = {}

local data: any = nil
local studioFound: {[Player]: number} = {} -- (Studio: finds kept for this test only)

local function maskOf(player: Player): number
	if RunService:IsStudio() and not ReplicatedStorage.FashionGame:GetAttribute("SantaStudioSave") then
		return studioFound[player] or 0
	end
	local w = data.Wallet(player)
	local s = w.santa
	return if typeof(s) == "table" and typeof(s.found) == "number" then s.found else 0
end

local function setMask(player: Player, mask: number)
	if RunService:IsStudio() and not ReplicatedStorage.FashionGame:GetAttribute("SantaStudioSave") then
		studioFound[player] = mask
	else
		local w = data.Wallet(player)
		if typeof(w.santa) ~= "table" then w.santa = {} end
		w.santa.found = mask
		data.MarkDirty(player)
	end
	player:SetAttribute("SantaFound", mask)
end

-- today's Santa in the world
local folder: Folder
local shownDay: number? = nil

local function floorBelow(pos: Vector3, ignore: {Instance}): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else pos
end

local function show(day: number?)
	if day == shownDay then return end
	shownDay = day
	folder:ClearAllChildren()
	folder:SetAttribute("Day", day)
	if not day then return end
	local santa = Config.Santas[day]
	local model = SantaFactory.build(santa.look, 1)
	model.Name = "MiniSanta"
	model:SetAttribute("Day", day)
	local ignore: {Instance} = { folder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ignore, p.Character) end
	end
	local base = floorBelow(santa.pos, ignore)
	model:PivotTo(CFrame.new(base) * CFrame.Angles(0, math.rad(santa.yaw or 0), 0))
	-- a faint sparkle so a close look gives it away
	local body = model.PrimaryPart :: BasePart
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 3
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(0.5, 1.2)
	sparkle.Size = NumberSequence.new(0.35)
	sparkle.LightEmission = 0.8
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200))
	sparkle.Parent = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FindSanta"
	prompt.ActionText = "산타 찾기"
	prompt.ObjectText = santa.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = body
	prompt.Triggered:Connect(function(player: Player)
		local today = Config.dayNow()
		if today ~= day then return end
		local mask = maskOf(player)
		if Config.has(mask, day) then return end
		setMask(player, bit32.bor(mask, bit32.lshift(1, day - 1)))
		player:SetAttribute("SantaJustFound", day)
	end)
	model.Parent = folder
end

local function holdPlush(player: Player, n: any): boolean
	if typeof(n) ~= "number" then return false end
	n = math.floor(n)
	local santa = Config.Santas[n]
	if not santa or not Config.has(maskOf(player), n) then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	-- one Santa plush at a time
	for _, where in ipairs({ player:FindFirstChildOfClass("Backpack"), character }) do
		if where then
			for _, t in ipairs(where:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("SantaPlush") then t:Destroy() end
			end
		end
	end
	local tool = Instance.new("Tool")
	tool.Name = santa.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("SantaPlush", n)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.6, 0.6)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local model = SantaFactory.build(santa.look, 0.42)
	-- the plush sits on the hand: its bottom a little under the grip
	model:PivotTo(handle.CFrame * CFrame.new(0, -0.35, 0))
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = tool
	tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
	tool.Parent = player:FindFirstChildOfClass("Backpack")
	humanoid:EquipTool(tool)
	return true
end

function SantaHuntService.Start(playerData: any)
	data = playerData
	folder = Instance.new("Folder")
	folder.Name = "SantaHunt"
	folder.Parent = Workspace
	local remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "SantaHunt"
	remote.Parent = remotes
	remote.OnServerInvoke = function(player: Player, action: any, arg: any)
		if action == "Hold" then
			local ok, done = pcall(holdPlush, player, arg)
			return ok and done
		end
		return false
	end
	local function onPlayer(player: Player)
		task.spawn(function()
			data.Wallet(player) -- (waits for the data)
			if player.Parent then player:SetAttribute("SantaFound", maskOf(player)) end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player) studioFound[player] = nil end)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
	task.spawn(function()
		while true do
			pcall(show, Config.dayNow())
			task.wait(20)
		end
	end)
end

return SantaHuntService

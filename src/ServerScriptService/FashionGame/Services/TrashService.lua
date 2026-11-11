--!strict
-- (D-1133) trash cans (TrashConfig): parts / models named "Trashcan" in
-- Workspace. Each can has its own items, kept as the very tools in
-- ReplicatedStorage.FashionGame.Trash.<can id> (inert there; clients draw them
-- in the window), each for TrashConfig.KeepSeconds after it went in.
-- Remote Trash (RemoteFunction):
--   "Throw", can, tool  → into that can (the player's own tool, near the can)
--   "Take",  can, item  → out of that can into the player's hand
-- The can part's attribute TrashRev changes whenever its items change (an
-- open window refreshes on it).
-- (D-1311, user 2026-11-11: "아이템 클릭해서 자기 인벤토리로 옮기면 서버 전체에 ㅇㅇㅇ님이 쓰레기통에서 ㅇㅇㅇㅇ를
-- 주웠습니다 띄워") RemoteEvent TrashNotice (player's display name, the item's name) goes to everyone on a "Take".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local TrashConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("TrashConfig"))

local TrashService = {}

local store = Instance.new("Folder")
store.Name = "Trash"
store.Parent = FashionGame

local cans: {[BasePart]: Folder} = {}
local notice: RemoteEvent? = nil
local lastCall: {[Player]: number} = {}

-- the part of a can (a model's PrimaryPart or its biggest part)
local function canPart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		if inst.PrimaryPart then return inst.PrimaryPart end
		local best: BasePart? = nil
		for _, p in ipairs(inst:GetDescendants()) do
			if p:IsA("BasePart") and (not best or p.Size.Magnitude > best.Size.Magnitude) then best = p end
		end
		return best
	end
	return nil
end

local function bump(part: BasePart)
	part:SetAttribute("TrashRev", ((part:GetAttribute("TrashRev") :: number?) or 0) + 1)
end

local count = 0
local function addCan(inst: Instance)
	if inst.Name ~= TrashConfig.Name or not inst:IsDescendantOf(workspace) then return end
	local part = canPart(inst)
	if not part or cans[part] then return end
	count += 1
	local folder = Instance.new("Folder")
	folder.Name = "Can" .. count
	folder.Parent = store
	cans[part] = folder
	part:SetAttribute("TrashCan", folder.Name)
	CollectionService:AddTag(part, "TrashCan")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrashPrompt"
	prompt.ActionText = "열기"
	prompt.ObjectText = "쓰레기통"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TrashConfig.Distance - 2
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part
	bump(part)
end

local function near(player: Player, part: BasePart): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= TrashConfig.Distance + 4
end

local function canOf(value: any): (BasePart?, Folder?)
	if typeof(value) ~= "Instance" or not value:IsA("BasePart") then return nil, nil end
	local folder = cans[value]
	if not folder then return nil, nil end
	return value, folder
end

local function throw(player: Player, canValue: any, tool: any): (boolean, string?)
	local part, folder = canOf(canValue)
	if not part or not folder then return false, "쓰레기통을 찾을 수 없어요." end
	if not near(player, part) then return false, "쓰레기통 가까이에서 버려요." end
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then return false, nil end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if tool.Parent ~= backpack and tool.Parent ~= player.Character then return false, nil end
	if not TrashConfig.canThrow(tool) then return false, "이건 버릴 수 없어요." end
	if tool.Parent == player.Character then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
	end
	-- full: the oldest goes
	local items = folder:GetChildren()
	if #items >= TrashConfig.MaxItems then
		table.sort(items, function(a, b) return ((a:GetAttribute("TrashedAt") :: number?) or 0) < ((b:GetAttribute("TrashedAt") :: number?) or 0) end)
		items[1]:Destroy()
	end
	tool:SetAttribute("KeptBy", nil)
	tool:SetAttribute("TrashedAt", os.time())
	tool:SetAttribute("TrashedBy", player.DisplayName)
	tool.Parent = folder
	bump(part)
	return true, "🗑 버렸어요."
end

local function take(player: Player, canValue: any, item: any): (boolean, string?)
	local part, folder = canOf(canValue)
	if not part or not folder then return false, "쓰레기통을 찾을 수 없어요." end
	if not near(player, part) then return false, "쓰레기통 가까이에서 꺼내요." end
	if typeof(item) ~= "Instance" or not item:IsA("Tool") or item.Parent ~= folder then
		return false, "이미 누가 가져갔어요."
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, nil end
	item:SetAttribute("TrashedAt", nil)
	item:SetAttribute("TrashedBy", nil)
	item.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:EquipTool(item) end
	bump(part)
	-- (D-1311) the whole server sees who took what
	if notice then notice:FireAllClients(player.DisplayName, item.Name) end
	return true, nil
end

function TrashService.Start()
	for _, d in ipairs(workspace:GetDescendants()) do addCan(d) end
	workspace.DescendantAdded:Connect(function(d)
		if d.Name == TrashConfig.Name then task.defer(addCan, d) end
	end)
	local remote = Remotes:FindFirstChild("Trash") :: RemoteFunction?
	if not remote then
		local r = Instance.new("RemoteFunction")
		r.Name = "Trash"
		r.Parent = Remotes
		remote = r
	end
	local ev = Remotes:FindFirstChild("TrashNotice") :: RemoteEvent?
	if not ev then
		local e = Instance.new("RemoteEvent")
		e.Name = "TrashNotice"
		e.Parent = Remotes
		ev = e
	end
	notice = ev;
	(remote :: RemoteFunction).OnServerInvoke = function(player: Player, action: any, can: any, thing: any)
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.25 then return false, nil end
		lastCall[player] = now
		if action == "Throw" then return throw(player, can, thing) end
		if action == "Take" then return take(player, can, thing) end
		return false, nil
	end
	Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)
	-- an hour in the can, then gone
	task.spawn(function()
		while true do
			task.wait(30)
			local t = os.time()
			for part, folder in pairs(cans) do
				local changed = false
				for _, item in ipairs(folder:GetChildren()) do
					local at = item:GetAttribute("TrashedAt")
					if typeof(at) ~= "number" or t - at >= TrashConfig.KeepSeconds then
						item:Destroy()
						changed = true
					end
				end
				if changed and part.Parent then bump(part) end
			end
		end
	end)
end

return TrashService

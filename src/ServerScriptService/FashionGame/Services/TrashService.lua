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

-- (D-1310) the junk (TrashConfig.Junk): small tools made of plain parts
local function junkTool(key: string, name: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = name
	tool.CanBeDropped = false
	tool:SetAttribute("Junk", key)
	local function piece(nm: string, size: Vector3, color: Color3, offset: CFrame, shape: string?): BasePart
		local p = Instance.new("Part")
		p.Name = nm
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape == "ball" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		elseif shape == "cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
		if nm ~= "Handle" then
			local handle = tool:FindFirstChild("Handle") :: BasePart
			p.CFrame = handle.CFrame * offset
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, p
			weld.Parent = p
		end
		p.Parent = tool
		return p
	end
	local up = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder stood up)
	if key == "receipt" then
		-- a crumpled white ball of paper with a couple of creased corners
		local white = Color3.fromRGB(242, 240, 232)
		piece("Handle", Vector3.new(0.55, 0.45, 0.5), white, CFrame.new(), "ball")
		piece("Fold", Vector3.new(0.3, 0.06, 0.24), white, CFrame.new(0.12, 0.17, 0.05) * CFrame.Angles(0.5, 0.3, 0.6))
		piece("Fold", Vector3.new(0.26, 0.06, 0.22), Color3.fromRGB(230, 228, 218), CFrame.new(-0.14, 0.05, -0.16) * CFrame.Angles(-0.4, 0.8, -0.3))
		piece("Ink", Vector3.new(0.18, 0.02, 0.1), Color3.fromRGB(120, 120, 126), CFrame.new(0.05, 0.21, -0.04) * CFrame.Angles(0.3, 0.2, 0.1))
	elseif key == "cup" then
		-- a clear take-away cup, its lid and a straw, empty
		local cup = piece("Handle", Vector3.new(0.95, 0.62, 0.62), Color3.fromRGB(225, 235, 240), up, "cylinder")
		cup.Transparency = 0.45
		cup.Material = Enum.Material.Glass
		piece("Lid", Vector3.new(0.08, 0.68, 0.68), Color3.fromRGB(240, 244, 246), CFrame.new(0.5, 0, 0), "cylinder").Transparency = 0.3
		piece("Straw", Vector3.new(0.5, 0.06, 0.06), Color3.fromRGB(40, 120, 70), CFrame.new(0.7, 0.05, 0.06) * CFrame.Angles(0, 0, math.rad(-12)), "cylinder")
		piece("Drop", Vector3.new(0.06, 0.5, 0.5), Color3.fromRGB(150, 110, 80), CFrame.new(-0.44, 0, 0), "cylinder").Transparency = 0.5
	elseif key == "tissue" then
		local soft = Color3.fromRGB(250, 250, 252)
		piece("Handle", Vector3.new(0.6, 0.5, 0.58), soft, CFrame.new(), "ball")
		piece("Fold", Vector3.new(0.34, 0.05, 0.3), soft, CFrame.new(0.1, 0.2, 0.12) * CFrame.Angles(0.7, 0.2, 0.4))
		piece("Fold", Vector3.new(0.3, 0.05, 0.28), soft, CFrame.new(-0.16, 0.12, -0.1) * CFrame.Angles(-0.6, 0.5, -0.5))
	else -- snackbag
		-- a flattened, creased shiny bag, torn open at the top
		local bag = piece("Handle", Vector3.new(0.7, 0.1, 0.95), Color3.fromRGB(235, 120, 40), CFrame.Angles(0, 0, math.rad(8)))
		bag.Material = Enum.Material.Foil
		piece("Crease", Vector3.new(0.66, 0.1, 0.36), Color3.fromRGB(215, 100, 30), CFrame.new(0, 0.05, 0.3) * CFrame.Angles(0.35, 0, 0)).Material = Enum.Material.Foil
		piece("Label", Vector3.new(0.4, 0.02, 0.3), Color3.fromRGB(250, 220, 70), CFrame.new(0.02, 0.06, -0.12))
		piece("Seal", Vector3.new(0.72, 0.12, 0.06), Color3.fromRGB(200, 90, 30), CFrame.new(0, 0, -0.48)).Material = Enum.Material.Foil
	end
	return tool
end
local function junkIn(folder: Folder): number
	local n = 0
	for _, item in ipairs(folder:GetChildren()) do if item:GetAttribute("Junk") then n += 1 end end
	return n
end
local function addJunk(folder: Folder)
	local pick = TrashConfig.Junk[math.random(1, #TrashConfig.Junk)]
	local tool = junkTool(pick.key, pick.name)
	tool:SetAttribute("TrashedAt", os.time())
	tool.Parent = folder
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
	-- (D-1310) a few bits of junk to begin with
	for _ = 1, math.random(TrashConfig.JunkStart[1], TrashConfig.JunkStart[2]) do addJunk(folder) end
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
	(remote :: RemoteFunction).OnServerInvoke = function(player: Player, action: any, can: any, thing: any)
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.25 then return false, nil end
		lastCall[player] = now
		if action == "Throw" then return throw(player, can, thing) end
		if action == "Take" then return take(player, can, thing) end
		return false, nil
	end
	Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)
	-- (D-1310) now and then one more bit of junk in a can that has few
	task.spawn(function()
		while true do
			task.wait(TrashConfig.JunkEvery)
			for part, folder in pairs(cans) do
				if part.Parent and junkIn(folder) < TrashConfig.JunkMax and math.random() < 0.5 then
					addJunk(folder)
					bump(part)
				end
			end
		end
	end)
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

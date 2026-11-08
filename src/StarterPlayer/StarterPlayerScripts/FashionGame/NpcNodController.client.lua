--!strict
-- (D-1055, user 2026-11-09: "불꽃판매원은 박자 타는 것처럼 고개 까딱거리면서
-- 걸어다니게 해") NPCs tagged NodBeat (the 불꽃 판매원, DrinkService) bob their
-- head to a beat on every screen: a LookAt IK on the neck (UpperTorso → Head,
-- like the eating nod, EatMotionController) at a point ahead that dips sharply
-- on each beat and comes back up. Driven from Heartbeat, on this client only
-- (nothing to send).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BPM = 118 -- a club tempo
local PERIOD = 60 / BPM
local BOW_UP, BOW_DOWN = math.rad(-4), math.rad(24) -- head up a little between beats, down on the beat

type Rig = { ik: IKControl, goal: Attachment, holder: Part }
local rigs: {[Model]: Rig} = {}

local function remove(model: Model)
	local rig = rigs[model]
	if not rig then return end
	rigs[model] = nil
	rig.ik:Destroy()
	rig.holder:Destroy()
end

local function add(model: Instance)
	if not model:IsA("Model") or rigs[model] then return end
	local humanoid = model:WaitForChild("Humanoid", 10) :: Humanoid?
	local torso = model:WaitForChild("UpperTorso", 10) :: BasePart?
	local head = model:WaitForChild("Head", 10) :: BasePart?
	if not humanoid or not torso or not head or not model.Parent then return end
	local holder = Instance.new("Part")
	holder.Name = "NodTarget"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.identity
	holder.Parent = workspace
	local goal = Instance.new("Attachment")
	goal.Parent = holder
	local ik = Instance.new("IKControl")
	ik.Name = "BeatNod"
	ik.Type = Enum.IKControlType.LookAt
	ik.ChainRoot = torso
	ik.EndEffector = head
	ik.Target = goal
	ik.SmoothTime = 0
	ik.Weight = 0.9
	ik.Parent = humanoid
	rigs[model] = { ik = ik, goal = goal, holder = holder }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then remove(model) end
	end)
end

for _, m in ipairs(CollectionService:GetTagged("NodBeat")) do task.spawn(add, m) end
CollectionService:GetInstanceAddedSignal("NodBeat"):Connect(function(m) task.spawn(add, m) end)
CollectionService:GetInstanceRemovedSignal("NodBeat"):Connect(function(m) if m:IsA("Model") then remove(m) end end)

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow() -- (every screen on the same beat)
	local phase = (now / PERIOD) % 1
	-- down fast on the beat (the first fifth), back up slowly
	local k = if phase < 0.2 then math.sin(phase / 0.2 * math.pi / 2) else 0.5 + 0.5 * math.cos((phase - 0.2) / 0.8 * math.pi)
	local bow = BOW_UP + (BOW_DOWN - BOW_UP) * k
	for model, rig in pairs(rigs) do
		local torso = model:FindFirstChild("UpperTorso") :: BasePart?
		local head = model:FindFirstChild("Head") :: BasePart?
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if torso and head and root then
			local neck = torso.CFrame * Vector3.new(0, torso.Size.Y / 2 + head.Size.Y / 2, 0)
			local ahead = root.CFrame.LookVector
			rig.goal.WorldPosition = neck + (ahead * math.cos(bow) - Vector3.yAxis * math.sin(bow)) * 4
		end
	end
end)

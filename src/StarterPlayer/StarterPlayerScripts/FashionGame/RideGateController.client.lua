--!strict
-- Ride gates (D-1443, user 2026-11-15: "바이킹 운행 중에는 저 펜스 닫아 놓고 운행 멈출 때만 열어서
-- 입장할 수 있게 해. 반대쪽은 출구라 나올 수만 있게 해"). Gates are built by
-- tools/graybox/park_ride_gates_1115.lua: Models tagged "RideGate" inside a ride's own model (next
-- to its "Ride"), attributes Mode / Inward / Width, leaves Leaf1 / Leaf2 (Hinge, OpenYaw) and an
-- invisible Block across the opening.
--   * Entry: open while the ride stands still (ParkConfig.rideState), closed while it runs; the
--     Block stops this player while closed.
--   * Exit: the leaf swings out while anyone stands just inside it; the Block stops this player when
--     they are outside (so the exit only lets people out).
-- Every screen works this out by itself; the Block's CanCollide is set on this screen only, which is
-- what counts for this player's own character.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParkConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ParkConfig"))

local player = Players.LocalPlayer
local OPEN_RATE = 1 / 1.2 -- (open fraction per second: a leaf swings in 1.2 s)
local NEAR = 150 -- (gates further away are left as they are)
local EXIT_NEAR = 7 -- (someone this close inside opens the exit)

type Leaf = { model: Model, hinge: CFrame, yaw: number, parts: {[BasePart]: CFrame} }
type Gate = { model: Model, mode: string, inward: Vector3, leaves: {Leaf}, open: number, shown: number? }
local gates: {[Model]: Gate} = {}

local function trackLeaf(model: Model): Leaf?
	local hinge = model:GetAttribute("Hinge")
	if typeof(hinge) ~= "CFrame" then return nil end
	local leaf: Leaf = { model = model, hinge = hinge, yaw = (model:GetAttribute("OpenYaw") :: number?) or math.pi / 2, parts = {} }
	-- (parts that stream in later still come at the closed place the server keeps)
	local function add(d: Instance)
		if d:IsA("BasePart") then leaf.parts[d] = hinge:ToObjectSpace(d.CFrame) end
	end
	for _, d in ipairs(model:GetDescendants()) do add(d) end
	model.DescendantAdded:Connect(add)
	model.DescendantRemoving:Connect(function(d: Instance)
		if d:IsA("BasePart") then leaf.parts[d] = nil end
	end)
	return leaf
end

local function addGate(model: Instance)
	if not model:IsA("Model") or gates[model] or not model:IsDescendantOf(workspace) then return end
	local inward = model:GetAttribute("Inward")
	local gate: Gate = {
		model = model,
		mode = (model:GetAttribute("Mode") :: string?) or "Entry",
		inward = if typeof(inward) == "Vector3" then inward else Vector3.new(0, 0, -1),
		leaves = {},
		open = 0,
	}
	for _, name in ipairs({ "Leaf1", "Leaf2" }) do
		local m = model:FindFirstChild(name)
		if m and m:IsA("Model") then
			local leaf = trackLeaf(m)
			if leaf then table.insert(gate.leaves, leaf) end
		end
	end
	model.ChildAdded:Connect(function(c: Instance)
		if c:IsA("Model") and (c.Name == "Leaf1" or c.Name == "Leaf2") then
			local leaf = trackLeaf(c)
			if leaf then table.insert(gate.leaves, leaf) end
			gate.shown = nil
		end
	end)
	gates[model] = gate
end

for _, m in ipairs(CollectionService:GetTagged("RideGate")) do addGate(m) end
CollectionService:GetInstanceAddedSignal("RideGate"):Connect(function(m: Instance) task.defer(addGate, m) end)
CollectionService:GetInstanceRemovedSignal("RideGate"):Connect(function(m: Instance)
	if m:IsA("Model") then gates[m] = nil end
end)

local function rideOf(gate: Gate): Instance?
	local owner = gate.model.Parent and gate.model.Parent.Parent
	return owner and owner:FindFirstChild("Ride")
end

local function place(gate: Gate)
	local s = gate.open * gate.open * (3 - 2 * gate.open)
	if gate.shown and math.abs(gate.shown - s) < 1e-3 then return end
	gate.shown = s
	local ps, cfs = {}, {}
	for _, leaf in ipairs(gate.leaves) do
		local turned = leaf.hinge * CFrame.Angles(0, leaf.yaw * s, 0)
		for p, offset in pairs(leaf.parts) do
			table.insert(ps, p)
			table.insert(cfs, turned * offset)
		end
	end
	if #ps > 0 then workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end

-- anyone standing just inside the exit (within EXIT_NEAR of it, on the ride's side or in it)?
local function someoneLeaving(gate: Gate, center: Vector3): boolean
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local rel = root.Position - center
			local flat = Vector3.new(rel.X, 0, rel.Z)
			if flat.Magnitude < EXIT_NEAR and flat:Dot(gate.inward) > -1.5 and math.abs(rel.Y) < 8 then return true end
		end
	end
	return false
end

RunService.Heartbeat:Connect(function(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local t = workspace:GetServerTimeNow()
	for model, gate in pairs(gates) do
		if not model.Parent then
			gates[model] = nil
			continue
		end
		local center = model:GetPivot().Position
		if root and (root.Position - center).Magnitude > NEAR then continue end
		local want = 0
		local blocked = false
		if gate.mode == "Entry" then
			local ride = rideOf(gate)
			local still = if ride then ParkConfig.rideState(ride, t) else false
			want = if still then 1 else 0
			blocked = not still
		else
			want = if someoneLeaving(gate, center) then 1 else 0
			-- this player outside the exit: the Block stops them
			if root then
				local rel = root.Position - center
				blocked = Vector3.new(rel.X, 0, rel.Z):Dot(gate.inward) < 0
			end
		end
		gate.open = math.clamp(gate.open + (if want > gate.open then 1 else -1) * OPEN_RATE * dt, 0, 1)
		place(gate)
		local block = model:FindFirstChild("Block") :: BasePart?
		if block and block.CanCollide ~= blocked then block.CanCollide = blocked end
	end
end)

--!strict
-- Underwater lights with a small bubbling jet (user photos 2026-10-24, the
-- beach cafe's 물멍 pool): parts tagged "WaterJet" are the water mound above
-- each light. On each client the mound bobs up and down, and every so often a
-- ring spreads out from it over the water and fades, like the ripples in the
-- photo. Only runs for jets near the player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local NEAR = 140 -- studs: farther jets stay still
local RING_EVERY = 0.9 -- seconds between rings per jet
local RING_LIFE = 2.6
local RING_SIZE = 7

type Jet = { part: BasePart, base: Vector3, size: Vector3, phase: number, next: number }
local jets: { [BasePart]: Jet } = {}

local function add(inst: Instance)
	if not inst:IsA("BasePart") then return end
	jets[inst] = { part = inst, base = inst.Position, size = inst.Size, phase = math.random() * 6.28, next = os.clock() + math.random() * RING_EVERY }
end
local function remove(inst: Instance)
	if inst:IsA("BasePart") then jets[inst] = nil end
end
for _, p in ipairs(CollectionService:GetTagged("WaterJet")) do add(p) end
CollectionService:GetInstanceAddedSignal("WaterJet"):Connect(add)
CollectionService:GetInstanceRemovedSignal("WaterJet"):Connect(remove)

local ringFolder = Instance.new("Folder")
ringFolder.Name = "WaterJetRings"
ringFolder.Parent = workspace

local function ring(at: Vector3)
	local r = Instance.new("Part")
	r.Name = "Ripple"
	r.Shape = Enum.PartType.Cylinder
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = false
	r.Material = Enum.Material.SmoothPlastic
	r.Color = Color3.fromRGB(235, 245, 250)
	r.Transparency = 0.7 -- a faint light ring spreading over the terrain water
	r.Size = Vector3.new(0.03, 0.6, 0.6)
	r.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	r.Parent = ringFolder
	local tw = TweenService:Create(r, TweenInfo.new(RING_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.03, RING_SIZE, RING_SIZE), Transparency = 1 })
	tw.Completed:Connect(function() r:Destroy() end)
	tw:Play()
end

RunService.Heartbeat:Connect(function()
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	local from = if root then root.Position elseif cam then cam.CFrame.Position else nil
	if not from then return end
	local now = os.clock()
	for part, j in pairs(jets) do
		if part.Parent == nil then
			jets[part] = nil
		elseif (j.base - from).Magnitude < NEAR then
			-- the mound swells and settles
			local s = 0.75 + 0.25 * math.sin(now * 5 + j.phase) + 0.1 * math.sin(now * 13 + j.phase * 2)
			part.Size = Vector3.new(j.size.X, j.size.Y * s, j.size.Z)
			part.Position = j.base
			if now >= j.next then
				j.next = now + RING_EVERY * (0.8 + math.random() * 0.4)
				ring(Vector3.new(j.base.X, j.base.Y + 0.02, j.base.Z))
			end
		end
	end
end)

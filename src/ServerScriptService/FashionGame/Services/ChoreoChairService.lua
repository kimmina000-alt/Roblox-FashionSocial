--!strict
-- (D-1321, user 2026-11-12: "의자 안무는 백화요란 안무에만 의자 추가해서 영상처럼 의자 사용해서 추는 걸로
-- 구현해") A song whose track has `chair` (ClubPlaylist: 백화요란's chair intro) gives each dancer who follows
-- its choreography a black chair under their hips while that part plays. The dancer's client works out
-- where (ChoreoController: under the standing hips, the seat as high as its sitting hips) and asks for it
-- here, so everyone sees the same chair. Remote Remotes.ChoreoChair: ("On", seatTop: CFrame, seatHeight)
-- / ("Off"). One chair a player; gone when they stop, leave or respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChoreoChairService = {}

local BLACK = Color3.fromRGB(24, 24, 28)
local METAL = Color3.fromRGB(60, 60, 66)

local folder: Folder? = nil
local chairs: {[Player]: Model} = {}

local function piece(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
end

-- the video's chair: a black seat and a tall black back on four thin metal legs, facing the way the
-- dancer faces (the back behind them)
local function build(seatTop: CFrame, height: number): Model
	local m = Instance.new("Model")
	m.Name = "ChoreoChair"
	local W, D, T = 1.9, 1.8, 0.18
	local seat = seatTop * CFrame.new(0, -T / 2, 0)
	piece(m, "Seat", Vector3.new(W, T, D), seat, BLACK, Enum.Material.SmoothPlastic)
	piece(m, "Back", Vector3.new(W, 2.1, 0.16), seatTop * CFrame.new(0, 1.05, D / 2 - 0.08) * CFrame.Angles(math.rad(-8), 0, 0), BLACK, Enum.Material.SmoothPlastic)
	local legH = math.max(height - T, 0.2)
	for _, x in ipairs({ -W / 2 + 0.12, W / 2 - 0.12 }) do
		for _, z in ipairs({ -D / 2 + 0.12, D / 2 - 0.12 }) do
			piece(m, "Leg", Vector3.new(0.1, legH, 0.1), seatTop * CFrame.new(x, -T - legH / 2, z), METAL, Enum.Material.Metal)
		end
	end
	return m
end

local function remove(player: Player)
	local c = chairs[player]
	if c then c:Destroy() end
	chairs[player] = nil
end

function ChoreoChairService.Start()
	local remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ChoreoChair"
	remote.Parent = remotes
	local f = Instance.new("Folder")
	f.Name = "ChoreoChairs"
	f.Parent = workspace
	folder = f
	remote.OnServerEvent:Connect(function(player: Player, what: any, seatTop: any, height: any)
		if what == "Off" then remove(player) return end
		if what ~= "On" or typeof(seatTop) ~= "CFrame" or typeof(height) ~= "number" then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return end
		-- (only right by the dancer, a sane height)
		if (seatTop.Position - root.Position).Magnitude > 8 or height < 0.5 or height > 5 then return end
		remove(player)
		local m = build(seatTop, height)
		m.Name = "ChoreoChair_" .. tostring(player.UserId)
		m.Parent = folder
		chairs[player] = m
		character.AncestryChanged:Once(function() if chairs[player] == m then remove(player) end end)
	end)
	Players.PlayerRemoving:Connect(remove)
end

return ChoreoChairService

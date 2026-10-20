--!strict
-- Round LED pillars beside the DJ zone (user, 2026-10-20; reference photo of
-- a club with tall cylindrical portrait screens). Each pillar shows one
-- player who is inside the club, changing every few seconds in a shuffled
-- order so everyone gets a turn. With nobody in the club it shows the club
-- name.
--
-- Map (tools/graybox, 02_Club): a Model tagged "LEDPillar" whose screen
-- panels are Parts named "Panel" with attribute Slice = 0..SLICES-1 (the half
-- facing the dance floor, left → right as seen from the floor) or -1 (back).
-- The image is an avatar thumbnail cut into vertical slices, one per panel,
-- so the portrait wraps around the curve.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))

local ClubScreenService = {}

local SLICES = 8
local SECONDS_PER_PLAYER = 6
local IMAGE_SIZE = 420
-- Only the middle half of the square thumbnail is used, so the person keeps
-- their proportions on the tall pillar.
local CROP_X0, CROP_W = 105, 210

type Pillar = { model: Model, images: {ImageLabel}, idle: {TextLabel}, nameLabel: TextLabel?, showing: number }
local pillars: {Pillar} = {}
local order: {number} = {}

local function setupPillar(model: Instance)
	if not model:IsA("Model") then return end
	for _, entry in ipairs(pillars) do
		if entry.model == model then return end
	end
	local pillar: Pillar = { model = model, images = {}, idle = {}, nameLabel = nil, showing = 0 }
	for _, panel in ipairs(model:GetChildren()) do
		local slice = panel:GetAttribute("Slice")
		if panel:IsA("BasePart") and panel.Name == "Panel" and typeof(slice) == "number" and slice >= 0 then
			local surface = Instance.new("SurfaceGui")
			surface.Name = "Screen"
			surface.Face = Enum.NormalId.Front
			surface.LightInfluence = 0
			surface.Brightness = 2
			surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			surface.PixelsPerStud = 20
			surface.Parent = panel
			local background = Instance.new("Frame")
			background.Size = UDim2.fromScale(1, 1)
			background.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
			background.BorderSizePixel = 0
			background.Parent = surface
			local image = Instance.new("ImageLabel")
			image.Name = "Portrait"
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.ScaleType = Enum.ScaleType.Stretch
			image.ImageRectSize = Vector2.new(CROP_W / SLICES, IMAGE_SIZE)
			image.ImageRectOffset = Vector2.new(CROP_X0 + slice * CROP_W / SLICES, 0)
			image.Parent = background
			table.insert(pillar.images, image)
			-- Idle text: one letter per panel ("FASHION!" across the front).
			local letter = Instance.new("TextLabel")
			letter.Name = "Idle"
			letter.Size = UDim2.fromScale(1, 1)
			letter.BackgroundTransparency = 1
			letter.Text = string.sub("FASHION!", slice + 1, slice + 1)
			letter.TextScaled = true
			letter.Font = Enum.Font.GothamBlack
			letter.TextColor3 = Color3.fromRGB(255, 80, 200)
			letter.Parent = background
			table.insert(pillar.idle, letter)
		end
	end
	-- Name under the portrait.
	local anchor = model:FindFirstChild("NameAnchor")
	if anchor and anchor:IsA("BasePart") then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(200, 34)
		billboard.MaxDistance = 160
		billboard.LightInfluence = 0
		billboard.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
		label.BackgroundTransparency = 0.25
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = "CLUB"
		label.Parent = billboard
		pillar.nameLabel = label
	end
	table.insert(pillars, pillar)
end

local function show(pillar: Pillar, target: Player?)
	local userId = if target then target.UserId else 0
	if pillar.showing == userId then return end
	pillar.showing = userId
	local image = if target
		then string.format("rbxthumb://type=Avatar&id=%d&w=%d&h=%d", target.UserId, IMAGE_SIZE, IMAGE_SIZE)
		else ""
	for _, label in ipairs(pillar.images) do label.Image = image end
	for _, letter in ipairs(pillar.idle) do letter.Visible = target == nil end
	if pillar.nameLabel then
		pillar.nameLabel.Text = if target then "✨ " .. target.DisplayName else "CLUB"
	end
end

local function clubPlayers(): {Player}
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and ClubConfig.isInClub(root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

-- Next player in a shuffled round, skipping anyone no longer in the club.
local function nextPlayer(inClub: {Player}, avoid: {[number]: boolean}): Player?
	for _ = 1, 2 do
		while #order > 0 do
			local userId = table.remove(order, 1) :: number
			for _, player in ipairs(inClub) do
				if player.UserId == userId and not avoid[userId] then return player end
			end
		end
		-- New round: shuffle everyone currently in the club.
		for _, player in ipairs(inClub) do table.insert(order, player.UserId) end
		for i = #order, 2, -1 do
			local j = math.random(1, i)
			order[i], order[j] = order[j], order[i]
		end
	end
	return nil
end

function ClubScreenService.Start()
	for _, model in ipairs(CollectionService:GetTagged("LEDPillar")) do setupPillar(model) end
	CollectionService:GetInstanceAddedSignal("LEDPillar"):Connect(setupPillar)
	task.spawn(function()
		while true do
			local inClub = clubPlayers()
			local used: {[number]: boolean} = {}
			for _, pillar in ipairs(pillars) do
				-- Two pillars show two different people when possible.
				local target = nextPlayer(inClub, used) or inClub[1]
				if target then used[target.UserId] = true end
				show(pillar, target)
			end
			task.wait(SECONDS_PER_PLAYER)
		end
	end)
end

return ClubScreenService

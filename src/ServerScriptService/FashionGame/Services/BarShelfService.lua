--!strict
-- The club bar's back-wall shelves (user 2026-10-27, D-427): the club's own
-- bottles in every flavour stand on the three BarShelf boards instead of the
-- graybox BarBottle blocks. Bottom: tier 2, middle: tier 3, top: the VIP
-- 골목 공방 set. Labels face the bar counter. Built at server start, so a
-- rebuilt club zone gets them too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local BottleShapes = require(Shared:WaitForChild("BottleShapes"))

local BarShelfService = {}

local GAP = 3.6 -- studs between bottles along a shelf
local GLOW_HEIGHT = 4.6 -- the neon panel behind each row (user 2026-10-27, D-429)

-- every flavour of the drinks on one shelf row, as { key, colour }
local function row(match: (any) -> boolean): { { any } }
	local list = {}
	for _, d in ipairs(ClubConfig.Drinks) do
		if match(d) then
			if d.variants then
				for _, v in ipairs(d.variants) do table.insert(list, { d.key, v.color }) end
			else
				table.insert(list, { d.key, d.color })
			end
		end
	end
	return list
end

local function topOf(part: BasePart): number
	local c, s = part.CFrame, part.Size
	return part.Position.Y + math.abs(c.RightVector.Y) * s.X / 2 + math.abs(c.UpVector.Y) * s.Y / 2 + math.abs(c.LookVector.Y) * s.Z / 2
end

function BarShelfService.Start()
	task.spawn(function()
		local graybox = workspace:WaitForChild("Graybox_MainSocial", 30)
		local club = graybox and graybox:WaitForChild("02_Club", 30)
		if not club then return end
		local shelves: { BasePart } = {}
		local counter: BasePart? = nil
		for _, p in ipairs(club:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name == "BarShelf" then table.insert(shelves, p)
				elseif p.Name == "BarBottle" then p:Destroy() -- (graybox stand-ins)
				elseif p.Name == "BarSign" then p:Destroy() -- (the pink box above the shelves: gone, D-429)
				elseif p.Name == "BarCounterTop" and (not counter or p.Size.Magnitude > counter.Size.Magnitude) then counter = p end
			end
		end
		if #shelves == 0 then return end
		table.sort(shelves, function(a, b) return a.Position.Y < b.Position.Y end)
		local rows = {
			row(function(d) return d.tier == 2 and not d.vipOnly end),
			row(function(d) return d.tier == 3 and not d.vipOnly end),
			row(function(d) return d.vipOnly == true end),
		}
		local holder = Instance.new("Model")
		holder.Name = "BarShelfBottles"
		holder.Parent = club
		for i, shelf in ipairs(shelves) do
			local drinks = rows[math.min(i, #rows)]
			if #drinks == 0 then continue end
			-- the shelf's long side, and which way is the bar
			local along = if shelf.Size.X >= shelf.Size.Z then shelf.CFrame.RightVector else shelf.CFrame.LookVector
			local length = math.max(shelf.Size.X, shelf.Size.Z)
			local toBar = if counter then (counter.Position - shelf.Position) else shelf.CFrame.LookVector
			toBar = (toBar - along * toBar:Dot(along)) * Vector3.new(1, 0, 1)
			local front = if toBar.Magnitude > 0.01 then toBar.Unit else Vector3.new(1, 0, 0)
			local count = math.floor((length - 2) / GAP)
			local y = topOf(shelf)
			-- a neon panel on the wall behind the bottles: they glow against it
			local depth = math.min(shelf.Size.X, shelf.Size.Z)
			local glow = Instance.new("Part")
			glow.Name = "BarBackGlow"
			glow.Anchored = true
			glow.CanCollide = false
			glow.CanQuery = false
			glow.CastShadow = false
			glow.Material = Enum.Material.Neon
			-- (violet, half bright: white washed the bottles out)
			glow.Color = Color3.fromRGB(110, 70, 160)
			glow.Transparency = 0.25
			glow.Size = Vector3.new(length - 0.4, GLOW_HEIGHT, 0.1)
			local at = Vector3.new(shelf.Position.X, y + GLOW_HEIGHT / 2 + 0.1, shelf.Position.Z) - front * (depth / 2 - 0.08)
			glow.CFrame = CFrame.lookAt(at, at + front)
			glow.Parent = holder
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Front
			light.Color = Color3.fromRGB(200, 150, 255)
			light.Brightness = 1.2
			light.Range = 8
			light.Angle = 120
			light.Parent = glow
			for k = 1, count do
				local e = drinks[(k - 1) % #drinks + 1]
				local at = Vector3.new(shelf.Position.X, y, shelf.Position.Z) + along * (-(count - 1) / 2 + (k - 1)) * GAP
				BottleShapes.add(holder, CFrame.lookAt(at, at + front), e[1], e[2], 1)
			end
		end
	end)
end

return BarShelfService

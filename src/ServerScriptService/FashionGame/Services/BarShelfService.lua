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
-- the light puck under each bottle (D-433)
local PUCK_SIZE, PUCK_HEIGHT = 1.3, 0.12
local UPLIGHT_COLOR = Color3.fromRGB(255, 226, 185)
local SHELF_BOTTLE_TRANSPARENCY = 0.1

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
		-- glowing copies of the bottle pictures (Edit-made SurfaceAppearances with
		-- an emissive mask on the glass; place only)
		local art = game:GetService("ServerStorage"):FindFirstChild("ArtAssets")
		local glowSkins = art and art:FindFirstChild("BottleSkinsGlow")
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
			-- the board above this row (the top row gets a slim canopy board at the
			-- same spacing): the down light sits on its underside (D-435)
			local above = shelves[i + 1]
			if not above then
				local below = shelves[i - 1]
				local step = if below then shelf.Position.Y - below.Position.Y else 6
				local canopy = shelf:Clone()
				canopy.Name = "BarShelfCanopy"
				canopy:ClearAllChildren()
				canopy.CFrame = shelf.CFrame + Vector3.new(0, step, 0)
				canopy.Parent = holder
				above = canopy
			end
			local underside = 2 * above.Position.Y - topOf(above)
			for k = 1, count do
				local e = drinks[(k - 1) % #drinks + 1]
				local at = Vector3.new(shelf.Position.X, y, shelf.Position.Z) + along * (-(count - 1) / 2 + (k - 1)) * GAP
				-- uplight (user 2026-10-27, D-433, instead of the violet wall panel):
				-- a glowing puck under each bottle, its light shining up through it
				local puck = Instance.new("Part")
				puck.Name = "BarUplight"
				puck.Shape = Enum.PartType.Cylinder
				puck.Anchored = true
				puck.CanCollide = false
				puck.CanQuery = false
				puck.CastShadow = false
				puck.Material = Enum.Material.Neon
				puck.Color = UPLIGHT_COLOR
				puck.Size = Vector3.new(PUCK_HEIGHT, PUCK_SIZE, PUCK_SIZE)
				puck.CFrame = CFrame.new(at + Vector3.new(0, PUCK_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
				puck.Parent = holder
				local beam = Instance.new("SpotLight")
				beam.Face = Enum.NormalId.Right -- (the cylinder's axis: up after the turn)
				beam.Color = UPLIGHT_COLOR
				beam.Brightness = 5
				beam.Range = 7
				beam.Angle = 50
				beam.Shadows = false
				beam.Parent = puck
				local base = at + Vector3.new(0, PUCK_HEIGHT, 0)
				local parts = BottleShapes.add(holder, CFrame.lookAt(base, base + front), e[1], e[2], 1)
				-- display bottles only (D-434/D-435): a little see-through, and the
				-- glass glows (the emissive copy of the bottle's picture)
				for _, p in ipairs(parts) do
					p.Transparency = math.max(p.Transparency, SHELF_BOTTLE_TRANSPARENCY)
					local skin = p:FindFirstChildOfClass("SurfaceAppearance")
					local glowing = glowSkins and glowSkins:FindFirstChild(e[1])
					if skin and glowing then skin:Destroy() glowing:Clone().Parent = p end
				end
				-- the same light on the underside of the board above, shining down
				local over = puck:Clone()
				over.CFrame = CFrame.new(at.X, underside - PUCK_HEIGHT / 2, at.Z) * CFrame.Angles(0, 0, math.rad(-90))
				over.Parent = holder
			end
		end
	end)
end

return BarShelfService

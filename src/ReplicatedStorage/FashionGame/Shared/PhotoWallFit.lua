--!strict
-- (D-1322, user 2026-11-12: "사진이 벽에 안 붙고 공중에 붙어") a photo wall panel (tag
-- PhotoWall) is one flat plane across a whole wall, but some walls have recesses behind it
-- (오후네컷 hall: arched niches 3 studs deep, the photo niche, gaps between panels). A photo
-- stuck there hung in the air. `backed` tells whether a real surface is right behind the
-- photo (its middle and four points near its corners, within MaxGap of the panel's face).
-- Used by PhotoBoothService (refuses such a spot; photos already stuck there are moved
-- along their wall to the nearest backed spot when the server starts) and
-- PhotoWallController (red preview; a photo still on such a spot is not drawn).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local PhotoConfig = require(script.Parent:WaitForChild("PhotoConfig"))

local PhotoWallFit = {}

PhotoWallFit.MaxGap = 0.6 -- studs behind the panel's face a surface may be
PhotoWallFit.FrontClear = 0.32 -- (D-1535) how far out from the wall a part covers the photo
PhotoWallFit.SideAngle = 35 -- (D-1563) degrees off straight out a photo's edge must be seen from
PhotoWallFit.SideReach = 5 -- (D-1563) how far that side view must be clear
PhotoWallFit.EdgeMargin = 0.6 -- (D-1563) wall needed past each edge of a photo

-- a photo's size on the wall in studs (as PhotoWallController.photoSize: the strip's
-- aspect from PhotoRender.stripAspect, 3.4 high for 2x2, else 4.4)
function PhotoWallFit.photoSize(layoutKey: any): Vector2
	local layout = PhotoConfig.findLayout(layoutKey) or PhotoConfig.Layouts[1]
	local w = layout.cols * 4 + (layout.cols + 1) * 0.35
	local h = layout.rows * 3 + (layout.rows + 1) * 0.35 + 1.4
	local height = if layoutKey == "2x2" then 3.4 else 4.4
	return Vector2.new(height * w / h, height)
end

-- +1 when the photos are on the part's Back face (+Z), -1 on its Front face; and the
-- viewer's right in the part's X (as PhotoWallController.faceOf)
local function faceInfo(wall: BasePart): (number, number)
	if wall:GetAttribute("Face") == "Back" then return 1, 1 end
	return -1, -1
end

function PhotoWallFit.backed(wall: BasePart, u: number, v: number, halfW: number, halfH: number): boolean
	local zSign, right = faceInfo(wall)
	local normal = wall.CFrame:VectorToWorldSpace(Vector3.new(0, 0, zSign))
	local exclude: { Instance } = {}
	for _, w in ipairs(CollectionService:GetTagged("PhotoWall")) do table.insert(exclude, w) end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(exclude, p.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local cx = (u - 0.5) * wall.Size.X * right
	local cy = (0.5 - v) * wall.Size.Y
	-- (D-1370, user 2026-11-13 with a live screenshot: "포토월 사진 또 공중에 붙어 있음") a 1x4
	-- strip at the edge of the PHOTO niche passed with all five old points (middle + 80 % corners)
	-- on the niche's thin neon rim while it hung over the opening: now a 3 x 3 grid out to 95 %
	-- of the photo, so a rim or a trim strip can no longer stand in for the wall
	for _, o in ipairs({ { 0, 0 }, { -0.95, -0.95 }, { 0, -0.95 }, { 0.95, -0.95 }, { -0.95, 0 }, { 0.95, 0 }, { -0.95, 0.95 }, { 0, 0.95 }, { 0.95, 0.95 } }) do
		-- (D-1563, user 2026-11-17: the strip that covered the PHOTO niche's neon outline) the wall must go
		-- on EdgeMargin past the photo's edges too, so a photo keeps clear of a niche's rim
		local m = PhotoWallFit.EdgeMargin
		local point = wall.CFrame * Vector3.new(cx + o[1] * (halfW + m), cy + o[2] * (halfH + m), zSign * wall.Size.Z / 2)
		local hit = workspace:Raycast(point + normal * 0.3, -normal * (0.3 + PhotoWallFit.MaxGap), params)
		if not hit then return false end
	end
	-- (D-1535, user 2026-11-16 with a live screenshot: "오후네컷에 잘못 붙은 사진 오류 고쳐") nothing
	-- may stand in front of the photo either: the hall's north panel runs on behind the white
	-- PhotoFin pillar at its west end (2.4 studs out from the wall), and photos stuck there were
	-- buried in the pillar, only thin slivers showing (the rays above start inside the pillar and
	-- pass). A thin slab over the photo's face, FrontClear out from the wall, must touch no part (a
	-- ray from inside a part does not see that part, a box does): what stands on the wall and comes
	-- out further than that covers the photo (the pillar, the studio mirror, the room 2 booth
	-- machine, the hall's room arches); flat things on the wall (backdrops, signs, under 0.2 out)
	-- and things standing off it (plants, stools) do not count
	local slab = wall.CFrame * CFrame.new(cx, cy, zSign * (wall.Size.Z / 2 + PhotoWallFit.FrontClear))
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = exclude
	-- (D-1563, user 2026-11-17: "오후네컷 벽에 사진 다 사라짐") the box test sees a part's bounding box:
	-- the hall's pink wall is one union with the PHOTO niche cut through it, so its box covered the
	-- whole SHOP panel at the back of the niche and all 30 photos there were refused. A union or a
	-- mesh in the slab is now checked by its real shape: rays from in front of the photo onto it,
	-- and it covers the photo only where a ray stops more than FrontClear out from the wall.
	for _, part in ipairs(workspace:GetPartBoundsInBox(slab, Vector3.new(halfW * 1.9, halfH * 1.9, 0.1), overlap)) do
		if not (part:IsA("PartOperation") or part:IsA("MeshPart")) then return false end
		local only = RaycastParams.new()
		only.FilterType = Enum.RaycastFilterType.Include
		only.FilterDescendantsInstances = { part }
		local reach = 40
		for _, o in ipairs({ { 0, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { -1, 0 }, { 1, 0 } }) do
			local face = wall.CFrame * Vector3.new(cx + o[1] * halfW, cy + o[2] * halfH, zSign * wall.Size.Z / 2)
			local hit = workspace:Raycast(face + normal * reach, -normal * reach, only)
			if hit and (hit.Position - face):Dot(normal) > PhotoWallFit.FrontClear then return false end
		end
	end
	-- (D-1563) a neon line on the wall (the PHOTO niche's outline, NicheRim) lies flush with it, so the
	-- slab above does not see it: a photo may not cover a Neon part within half a stud of the face
	for _, part in ipairs(workspace:GetPartBoundsInBox(wall.CFrame * CFrame.new(cx, cy, zSign * wall.Size.Z / 2),
		Vector3.new(halfW * 2 + 0.2, halfH * 2 + 0.2, 1), overlap)) do
		if part.Material == Enum.Material.Neon then return false end
	end
	-- (D-1563) seen from the side: a photo at the edge of a niche (the PHOTO niche is 2.8 deep) hid
	-- half behind the niche's side wall unless you stood right in front of it. From the middle of each
	-- side edge a ray goes out at SideAngle towards that side: nothing may be within SideReach of it
	local side = wall.CFrame:VectorToWorldSpace(Vector3.new(right, 0, 0))
	local angle = math.rad(PhotoWallFit.SideAngle)
	for _, sx in ipairs({ -1, 1 }) do
		local edge = wall.CFrame * Vector3.new(cx + sx * right * halfW, cy, zSign * wall.Size.Z / 2) + normal * 0.05
		local dir = (normal * math.cos(angle) + side * sx * math.sin(angle)) * PhotoWallFit.SideReach
		if workspace:Raycast(edge, dir, params) then return false end
	end
	return true
end

return PhotoWallFit

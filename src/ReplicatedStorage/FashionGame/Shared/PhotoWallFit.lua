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
		local point = wall.CFrame * Vector3.new(cx + o[1] * halfW, cy + o[2] * halfH, zSign * wall.Size.Z / 2)
		local hit = workspace:Raycast(point + normal * 0.3, -normal * (0.3 + PhotoWallFit.MaxGap), params)
		if not hit then return false end
	end
	return true
end

return PhotoWallFit

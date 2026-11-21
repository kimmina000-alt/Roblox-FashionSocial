-- dance_board_1121.lua (D-1817, user 2026-11-21: "top10전광판 바로 옆 해변쪽 버스정류장 뒤쪽벽 사용")
-- The 오늘의 곡 TOP 10 board on the back of the beach-side bus stop next to the neon stage
-- (Hongdae_Layout.BusStop5, its back wall at x -149.4 faces east to the stage): one flat board over the
-- middle section (the route map and the back glass, between the posts at z -133 / -123), its face to
-- +X. The ad panels on either side stay. DanceScoreController draws the list on it (tag DanceTopBoard).
-- Workspace.DanceTopBoard, outside Hongdae_Layout (the chain does not touch it). Run again = same.

local CollectionService = game:GetService("CollectionService")

local old = workspace:FindFirstChild("DanceTopBoard")
if old then old:Destroy() end

local board = Instance.new("Part")
board.Name = "DanceTopBoard"
board.Anchored = true
board.CanCollide = false
board.CastShadow = false
board.Material = Enum.Material.SmoothPlastic
board.Color = Color3.fromRGB(11, 7, 20)
-- (D-1818c, user 2026-11-21: "세 칸 다 써서 더 크고 눈에 띄게") the whole back: both ad frames and the middle
-- (z -142.6 .. -113.4 between the end posts, y 2.4 .. 17.2 = the ad frames' height), just in front of the ad
-- frames' back faces (x -148.9)
board.Size = Vector3.new(0.3, 14.8, 29.2)
board.CFrame = CFrame.new(-148.6, 9.8, -128)
board.Parent = workspace
CollectionService:AddTag(board, "DanceTopBoard")

-- a thin pink neon edge round it
local edge = Instance.new("Part")
edge.Name = "Edge"
edge.Anchored = true
edge.CanCollide = false
edge.CastShadow = false
edge.Material = Enum.Material.Neon
edge.Color = Color3.fromRGB(255, 79, 180)
edge.Size = Vector3.new(0.2, 15.1, 29.5)
edge.CFrame = board.CFrame * CFrame.new(-0.1, 0, 0)
edge.Parent = board

print("[dance_board_1121] board at", board.Position)
return board.Position

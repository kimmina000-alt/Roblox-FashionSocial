--!strict
-- 여러 곳에서 시작하기 (D-1982, 2026-11-21: FirstLeave showed 70 % of new players leaving near the one
-- spawn by the guide (street 36 %, pocket park 35 %); the user decided to drop players in the middle of
-- something to do). On each join the server picks one spot at random for the game clock (day / night);
-- a player whose Roblox friend is already on the server appears next to that friend instead
-- (SpawnService). Respawns after that use the normal SpawnLocation by the guide (D-1696).
-- The real SpawnLocation part stays where it is (pocket park lot, off the walk areas).
-- at = the feet on the ground, face = a point the player looks at when they appear.

export type Spot = { key: string, name: string, at: Vector3, face: Vector3 }

local SpawnConfig = {}

-- the spots the user picked from the screenshots (D-1982, 2026-11-21; shots in the shared notes spawn_1..4):
-- beach sand by the seafront walk, the park plaza just inside the gate (tea cups and carousel ahead),
-- the sidewalk at 오후네컷's corner door, the club sidewalk in front of the door (outside the rope)
SpawnConfig.Day = {
	{ key = "beach", name = "해변", at = Vector3.new(-215, 1, -40), face = Vector3.new(-250, 1, -40) },
	{ key = "park", name = "놀이공원", at = Vector3.new(-97, 16.1, -296), face = Vector3.new(-97, 16.1, -330) },
	{ key = "photo", name = "오후네컷 앞", at = Vector3.new(44, 0.6, -50), face = Vector3.new(64, 3, -66) },
	-- (the hanok village inside 광화문 dropped, user 2026-11-21: the village is being removed except 광화문)
} :: {Spot}

-- no beach at night (players: "밤이 무서워요")
SpawnConfig.Night = {
	{ key = "park", name = "놀이공원", at = Vector3.new(-97, 16.1, -296), face = Vector3.new(-97, 16.1, -330) },
	{ key = "club", name = "클럽 입구", at = Vector3.new(34, 0.6, -210), face = Vector3.new(60, 0.6, -210) },
	{ key = "photo", name = "오후네컷 앞", at = Vector3.new(44, 0.6, -50), face = Vector3.new(64, 3, -66) },
} :: {Spot}

-- a friend already here: this far beside them
SpawnConfig.FriendOffset = 4
-- false = everyone at the SpawnLocation as before (a switch for the live game)
SpawnConfig.Enabled = true

return SpawnConfig

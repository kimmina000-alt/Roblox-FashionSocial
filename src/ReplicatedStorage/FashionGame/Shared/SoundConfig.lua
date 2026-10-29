--!strict
-- Sound effects for small actions and the background ambience (user
-- 2026-10-30: "a sound for every feature and every small action"). Picked
-- from the Creator Store, mostly Roblox's own UI pack and Pro Sound Effects
-- (licensed by Roblox). The list with what each one is for:
-- docs/04_ART/SOUNDS.md §3. Change a number here to swap a sound.
-- (user 2026-10-30 (2): no prompt pop, no window whoosh, no coin sounds, no
-- indoor crowd; quieter waves, birds and street)
return {
	Ui = {
		click = 15675032796, -- Roblox_UI_Small_Click: any button on screen (not at shop counters)
		error = 87047730068459, -- Access Denied (SodaBreadle): a red error message
		success = 15675043410, -- Roblox_UI_Tonal_Stinger: a purchase goes through, a banner shows
	},
	Body = {
		sit = 9116248517, -- Leather Bench 4 (Pro Sound Effects): sitting down
		outfit = 9119138453, -- Silk Shirt 3 (Pro Sound Effects): clothes change
		teleport = 15675046931, -- Roblox_UI_Sweep: 🏠 and other far jumps (not the subway)
	},
	Subway = 9117092623, -- New York City Subway 2 (Pro Sound Effects): the first seconds after a subway trip
	Clink = 9114076521, -- Dinner Plates 3 (Pro Sound Effects, glass): a bottle / bucket set on a club table
	Ambience = {
		waves = 9119677305, -- Surf Ocean Wave Impact On Zuma Beach 4 (Pro Sound Effects)
		city = 9112819963, -- Las Vegas Night Traffic 1 (Pro Sound Effects): street hum
		birds = 9112831284, -- Morning Birds 1 (Pro Sound Effects): parks and the hanok village
	},
}

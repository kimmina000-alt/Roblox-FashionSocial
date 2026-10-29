--!strict
-- Sound effects for small actions and the background ambience (user
-- 2026-10-30: "a sound for every feature and every small action"). Picked
-- from the Creator Store, mostly Roblox's own UI pack and Pro Sound Effects
-- (licensed by Roblox). The list with what each one is for:
-- docs/04_ART/SOUNDS.md §3. Change a number here to swap a sound.
return {
	Ui = {
		click = 15675032796, -- Roblox_UI_Small_Click: any button on screen
		open = 15675024286, -- Roblox_UI_Whoosh_01: a window opens (Popups)
		prompt = 15675055424, -- Roblox_UI_Cute_Pop: an E / tap prompt is used
		error = 87047730068459, -- Access Denied (SodaBreadle): a red error message
		success = 15675043410, -- Roblox_UI_Tonal_Stinger: a purchase goes through, a banner shows
	},
	Coin = {
		earn = 1169806635, -- Coin Collect 2 (Everyedit, free to use): coins go up
		spend = 101396758527961, -- Cash Register Cha Ching: coins go down
	},
	Body = {
		sit = 9116248517, -- Leather Bench 4 (Pro Sound Effects): sitting down
		outfit = 9119138453, -- Silk Shirt 3 (Pro Sound Effects): clothes change
		teleport = 15675046931, -- Roblox_UI_Sweep: 🏠, bus, subway and other jumps
	},
	Subway = 9117092623, -- New York City Subway 2 (Pro Sound Effects): the first seconds after a subway trip
	Clink = 9114076521, -- Dinner Plates 3 (Pro Sound Effects, glass): a bottle / bucket set on a club table
	Ambience = {
		waves = 9119677305, -- Surf Ocean Wave Impact On Zuma Beach 4 (Pro Sound Effects)
		city = 9112819963, -- Las Vegas Night Traffic 1 (Pro Sound Effects): street hum
		birds = 9112831284, -- Morning Birds 1 (Pro Sound Effects): parks and the hanok village
		indoor = 9112746245, -- Bar Walla Clinking Glasses Silverware 2 (Pro Sound Effects): cafes, 국밥집, OH24
	},
}

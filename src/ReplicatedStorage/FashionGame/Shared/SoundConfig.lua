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
		-- the tour / tips camera flight (D-718; Roblox_UI_Sweep until the user picks:
		-- candidates 127183292018512 whoosh!, 140334012603496 long whoosh,
		-- 138890894929151 Whoosh2, 137081214744553 whoosh, 127438224839678 cartoon whoosh)
		whoosh = 15675046931,
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
		-- (D-1459, user 2026-11-15: "놀이공원에 어울리는 배경음악 찾아서 추천해 줘. 놀이공원 입구 가까워지면
		-- 그때부터 들리게") the park's music, from the plaza in front of the gate in. Until the user picks:
		-- Amusement Park (APM, 128 s). Candidates (all load, Creator Store, free):
		--   1839237742 Amusement Park (APM, 128 s) · 1836351592 Disneyland (APM, 95 s)
		--   9046172743 Circus And Clowns (a) 60 (APM, 60 s) · 1841134066 Playful Twist (APM, 61 s)
		--   9046748008 Holiday Bliss (APM, 70 s) · 87883706305527 Amusement Park (DistroKid, 124 s)
		--   90761353490771 Amusement park (DistroKid, 88 s) · 103863683328306 Amusement park (DistroKid, 127 s)
		--   111710156976120 Amusement Park 147bpm (DistroKid, 198 s)
		park = 1839237742,
	},
	-- (D-1459, user: "바이킹 움직일 때 들리는 바람 소리" 101252896391536, 2 s, looped) the rides' wind:
	-- the vikings while they swing (louder the faster), the jumping star on its big drop
	RideWind = 101252896391536,
}

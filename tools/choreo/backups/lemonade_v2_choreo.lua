-- Backup (D-1960): aespa Lemonade choreography v2 as it was in ClubPlaylist before the v3 single-dancer rebuild.
-- The game does not read this file. To bring v2 back, put the block below in place of Lemonade-aespa's `choreo = { ... },`
-- in src/ReplicatedStorage/FashionGame/Shared/ClubPlaylist.lua (its ChoreoFixes / face offsets in ClubChoreo are keyed by
-- these ids and were left in place).
		choreo = { { id = 107871857436267, from = 1.45 }, { id = 85687535459003, at = 6.92, blend = 0.46 }, { id = 74096523961866, at = 15.92, blend = 0.4 },
		{ id = 123559029471758, at = 22.84 }, { id = 139260290712979, at = 31.92, blend = 1 }, { id = 131526768823490, at = 39.2 },
		-- (D-1062, user: 0:55 "훅 내려가는 걸 없애": 8 from 0.9 s at 56.82 (its deep bow at 0.1-0.85 skipped), 7 holds its
		-- last pose up to it; was 7 stop 55.75 → 55.92 slowed (D-1058), 8 at 55.92 slowIn { 0.35, 0.17 };
		-- 11 blends in over 0.5 s, was 1, so its straightened left arm at 86.3-86.9 shows in full)
		-- (D-1068, user: "0:55 … 내려가자마자 천천히 이어서 다시 올라오는 걸로"): 8 comes in at 56.0, the moment 7
		-- is down, over 1.0 s and its first 0.6 s played over 1.42 s, so it rises slowly and is back on
		-- the song from 57.42 (8 at 1.5 s, as before)
		{ id = 99422937735141, at = 47.49, blend = 0.51 }, { id = 99169381541568, at = 56.82, from = 0.9, blend = 1.0, slowIn = { 0.6, 0.82 } }, { id = 100397079318559, at = 67.05 }, { id = 135759185323713, at = 76.35, slowOut = { 0.4, 0.15 } },
		{ id = 83846438884132, at = 85.92, blend = 0.5 }, { id = 138502286160157, at = 94.39, blend = 1 }, { id = 107439323698577, at = 100.92, blend = 0.81 },
		{ id = 138612452549442, at = 111.39, blend = 0.43 }, { id = 118124487485279, at = 114.92, blend = 0.75 }, { id = 82680550952125, at = 127.65, blend = 0.43 },
		{ id = 132337331292488, at = 137.92, blend = 0.47 }, { id = 76195346888656, at = 145.92, blend = 1 }, { id = 116980798181063, at = 150.92, blend = 0.88 },
		{ id = 118071176218932, at = 160.92, blend = 0.5 }, { id = 76826604804095, at = 168.42, blend = 0.5 },
		{ id = 89070118321317, at = 177.49 } },

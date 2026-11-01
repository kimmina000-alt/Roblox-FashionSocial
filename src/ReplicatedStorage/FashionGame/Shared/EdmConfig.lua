--!strict
-- DJ EDM effects (user 2026-11-01, D-733): the DJ lays EDM effects over the
-- song that is playing, everyone in the club hears the same. The state is the
-- FashionGame attribute ClubEdm (JSON, EdmService); EdmController plays it on
-- every client, EdmPanel is the DJ's part of the turntable window.
-- (D-734, user: 박자 탭, 플랜저, 필터, 베이스 taken out; 킥 tempo slider, 배속)
--   kick    on/off a four-on-the-floor kick and off-beat hi-hats
--   bpm     the kick's tempo (the slider beside 킥), MinBpm..MaxBpm
--   pump    on/off the song ducks on every beat (sidechain)
--   echo    on/off an echo half a beat long
--   drop    a build-up (BuildBeats: bass cut away, a riser, hi-hats getting
--           faster) and then the drop: bass back, a big kick, the kick on for
--           DropBeats. Pressed again while it runs: off.
-- The beat: the kick tempo, else EdmConfig.Bpm[soundId] (the original song's
-- BPM as heard in the club) or Default, counted from the song's start.

return {
	Default = 120,
	-- the song's BPM as heard (the uploads play at x0.335 back to the original tempo).
	-- Numbers from songbpm.com / ruwiki (Tunebat); the DJ's kick slider fixes any that are off.
	Bpm = {
		[134942349436280] = 124, -- ATEEZ-BAD
		[119473981131981] = 99, -- RIIZE-Love 119
		[132067415333401] = 128, -- aespa-Lemonade
	} :: {[number]: number},
	BuildBeats = 16,
	DropBeats = 32,
	MinBpm = 60,
	MaxBpm = 180,
	-- the 배속 button cycles these (ClubConfig.MusicSpeeds has them all)
	Speeds = { 0.75, 1, 1.25, 1.5, 2 },
	-- sounds (Creator Store; APM Music / Roblox-licensed where there was one)
	Sounds = {
		kick = 1837831484, -- KICK-Basic Kick 02 (APM). Candidates: 108664024018025 Kick 5, 130299156805539 compressor kick
		hat = 140468458870544, -- 338_Hi-Hat_Closed_Hard. Candidates: 104860520282914 closed-hi-hat (2), 138676630567304 hithatclose
		riser = 1843490542, -- Critical Mass - SFX Riser 1 (APM). Candidates: 1843490108 Obliteration - SFX Riser 4, 130099689917261 risersfx1
	},
	Volumes = { kick = 1.6, hat = 0.5, riser = 1.2 },
	-- how deep the song ducks on each beat with pump on (0..1)
	PumpDepth = 0.55,
}

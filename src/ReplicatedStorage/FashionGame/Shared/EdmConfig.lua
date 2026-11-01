--!strict
-- DJ EDM effects (user 2026-11-01, D-733): the DJ lays EDM effects over the
-- song that is playing, everyone in the club hears the same. The state is the
-- FashionGame attribute ClubEdm (JSON, EdmService); EdmController plays it on
-- every client, EdmPanel is the DJ's part of the turntable window.
--   filter  0..1   low-pass: 0 = muffled (bass only), 1 = open
--   bass    0..1   bass boost
--   kick    on/off a four-on-the-floor kick and off-beat hi-hats on the song's beat
--   pump    on/off the song ducks on every beat (sidechain)
--   flange  on/off
--   echo    on/off an echo half a beat long
--   drop    a build-up (BuildBeats: bass cut away, a riser, hi-hats getting
--           faster) and then the drop: bass back, a big kick, the kick on for
--           DropBeats
--   tap     the DJ taps the beat: bpm and the time of a beat
-- The beat: EdmConfig.Bpm[soundId] (the original song's BPM as heard in the
-- club) or Default; a tap replaces it until the song changes.

return {
	Default = 120,
	-- the song's BPM as heard (the uploads play at x0.335 back to the original tempo).
	-- Numbers from songbpm.com / ruwiki (Tunebat); the DJ's tap fixes any that are off.
	Bpm = {
		[134942349436280] = 124, -- ATEEZ-BAD
		[119473981131981] = 99, -- RIIZE-Love 119
		[132067415333401] = 128, -- aespa-Lemonade
	} :: {[number]: number},
	BuildBeats = 16,
	DropBeats = 32,
	MinBpm = 60,
	MaxBpm = 200,
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

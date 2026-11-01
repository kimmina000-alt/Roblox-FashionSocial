--!strict
-- The DJ's EDM button (user 2026-11-01, D-733 → D-735: the kick / pump / drop /
-- echo effects are gone). EDM ON: everyone in the club hears the EDM track
-- below together with the song (D-736; instead of it in D-735); a slider sets
-- the EDM track's speed. The state is the
-- FashionGame attribute ClubEdm (JSON, EdmService); EdmController plays it on
-- every client; EdmPanel is the DJ's part of the turntable window, with the
-- song speed and volume sliders too.

return {
	-- the EDM track, until the user sends their EDM upload's id; `lab` as in
	-- ClubConfig.Playlist (speed × tempo, octave, boost).
	-- (D-739: Roblox's licensed "ECHOES OF THE BASS" in place of Get A Guitar)
	Track = {
		soundId = 134070050316863, -- ECHOES OF THE BASS (DistrokidOfficial)
		-- (D-745: default sound, as the playlist)
		lab = { speed = 1, tempo = 1, volume = 10, boost = 1, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" },
	},
	-- the sliders' ranges (the song speed and volume use ClubConfig.MusicSpeeds /
	-- MusicVolumes steps on the server)
	EdmSpeed = { min = 0.5, max = 2, step = 0.05 },
	SongSpeed = { min = 0.5, max = 2, step = 0.05 },
	Volume = { min = 0, max = 3, step = 0.1 },
}

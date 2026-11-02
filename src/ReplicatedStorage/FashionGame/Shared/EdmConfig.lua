--!strict
-- The DJ's EDM buttons (user 2026-11-01, D-733 → D-735: the kick / pump / drop /
-- echo effects are gone). EDM ON: everyone in the club hears an EDM track
-- below together with the song (D-736; instead of it in D-735); a slider sets
-- the EDM track's speed. The state is the
-- FashionGame attribute ClubEdm (JSON, EdmService); EdmController plays it on
-- every client; EdmPanel is the DJ's part of the turntable window, with the
-- song speed and volume sliders too.

-- default sound (D-745, as the playlist's Roblox tracks): `lab` as in
-- ClubConfig.Playlist (speed × tempo, octave, boost)
local DEFAULT = { speed = 1, tempo = 1, volume = 10, boost = 1, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }

return {
	-- (D-759, user 2026-11-02: three EDM tracks of their own, a button each; one
	-- plays at a time. ECHOES OF THE BASS (134070050316863) was the one track
	-- before.) name = the button's text.
	Tracks = {
		{ name = "EDM 1", soundId = 119641572301610, lab = DEFAULT }, -- 66 s
		{ name = "EDM 2", soundId = 129472912679102, lab = DEFAULT }, -- 325 s
		{ name = "EDM 3", soundId = 86899466245520, lab = DEFAULT }, -- 373 s
	},
	-- the sliders' ranges (the song speed and volume use ClubConfig.MusicSpeeds /
	-- MusicVolumes steps on the server)
	EdmSpeed = { min = 0.5, max = 2, step = 0.05 },
	EdmVolume = { min = 0, max = 3, step = 0.1 }, -- (D-764: the EDM track alone)
	SongSpeed = { min = 0.5, max = 2, step = 0.05 },
	Volume = { min = 0, max = 3, step = 0.1 },
}

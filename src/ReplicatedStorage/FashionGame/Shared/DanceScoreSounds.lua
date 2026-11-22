--!strict
-- 오늘의 곡 도전: button sounds per song (D-1984, user 2026-11-22: "노래에 맞는 드럼 소리나 edm 소리 ai로
-- 만든 후 리듬 게임에 적용").
-- Our own sounds (numpy synthesis, tools/art/dance_kits.py → docs/04_ART/sfx/kits): four kits of four
-- buttons, every pitched sound made in C. Each song names its kit and its key (measured from the
-- original audio, tools/art/song_key.py); the game plays a pitched sound at PlaybackSpeed
-- 2^(key / 12) so it sits in the song's key (key -5..6: the sound gets at most 1.41x faster / slower).
-- Power chords only (root + fifth), so they fit a major or a minor key alike.
-- A song not listed here, or a kit not uploaded yet (id 0), uses DanceScoreConfig.LaneSounds.

local DanceScoreSounds = {}

export type Lane = { id: number, pitched: boolean }
export type Play = { id: number, speed: number, volume: number }

-- lane 1 ◀/A, 2 ▼/S, 3 ▲/D, 4 ▶/F (ids: uploaded by Vantablack_Dev; 0 = not yet)
DanceScoreSounds.Kits = {
	-- supersaw power-chord stabs, I5 / IV5 / V5 / I5 high (like edm_5_stab)
	edm = { { id = 0, pitched = true }, { id = 0, pitched = true }, { id = 0, pitched = true }, { id = 0, pitched = true } },
	-- tuned 808 / snare / dark brass stab / clap (hip-hop songs)
	trap = { { id = 0, pitched = true }, { id = 0, pitched = false }, { id = 0, pitched = true }, { id = 0, pitched = false } },
	-- bright plucks I5 / IV5 / V5 and a bell
	pop = { { id = 0, pitched = true }, { id = 0, pitched = true }, { id = 0, pitched = true }, { id = 0, pitched = true } },
	-- synth-brass stabs I5 / IV5 / V5 and an orchestra hit (2009-2010 songs, funk)
	retro = { { id = 0, pitched = true }, { id = 0, pitched = true }, { id = 0, pitched = true }, { id = 0, pitched = true } },
} :: { [string]: { Lane } }

-- loudness of a kit next to DanceScoreConfig.LaneSoundVolume (the files are matched to edm_5_stab)
DanceScoreSounds.KitGain = { edm = 1, trap = 1, pop = 1, retro = 1 } :: { [string]: number }

-- soundId → kit and key (semitones from C: C 0, C# 1 .. F# 6, G -5 .. B -1); key measured from the
-- original song (major / minor in the comment only: the sounds fit both)
DanceScoreSounds.Songs = {
	[134942349436280] = { kit = "trap", key = 3 }, -- BAD-ATEEZ, D# minor
	[128270208751659] = { kit = "retro", key = 4 }, -- Genie-소녀시대, E major
	[70738014182544] = { kit = "trap", key = -4 }, -- Get A Guitar-RIIZE, G# major
	[85204387077332] = { kit = "pop", key = -2 }, -- Love 119-RIIZE, A# major
	[119002946047943] = { kit = "edm", key = -2 }, -- Catch Catch-YENA, A# major
	[97032815457241] = { kit = "pop", key = 4 }, -- Lemon Tang-Hearts2Hearts, E major
	[101586065131501] = { kit = "edm", key = 4 }, -- Lemonade-aespa, E major
	[140713297574648] = { kit = "edm", key = 0 }, -- NEON-A2O LITE, C minor
	[139044453511745] = { kit = "edm", key = 0 }, -- 체포하겠어-ILLIT, C minor
	[139330220515727] = { kit = "edm", key = -2 }, -- LOVE-ATTACK-RESCENE, A# minor
	[135553051649506] = { kit = "edm", key = 1 }, -- Looks Can Kill-IVE, C# minor
	[75344866720031] = { kit = "pop", key = 3 }, -- 갑자기-IOI, D# major
	[98124521559769] = { kit = "pop", key = 1 }, -- I SPY-NCT WISH, C# minor
	[76034005809699] = { kit = "trap", key = 2 }, -- REDRED-CORTIS, D minor
	[94774089824958] = { kit = "trap", key = -4 }, -- ANIMAL-BOYNEXTDOOR, G# major
	[140273876429390] = { kit = "edm", key = 5 }, -- Pretty Girl-RESCENE, F major
	[131620527618857] = { kit = "pop", key = 5 }, -- Pop Off-KiiiKiii, F major
	[112509101263761] = { kit = "pop", key = -1 }, -- With-RESCENE, B minor
	[86115718533153] = { kit = "edm", key = -2 }, -- CRASH-ALLDAY PROJECT, A# minor
	[117439533883778] = { kit = "trap", key = 0 }, -- BiiiG BiiiG-BIGBANG, C minor
	[94024099429072] = { kit = "edm", key = 4 }, -- SHOCK-TREASURE, E major
	[74619423082896] = { kit = "pop", key = -5 }, -- 백화요란-RESCENE, G major
	[136570075901439] = { kit = "retro", key = 2 }, -- BANG-After School, D minor
	[127479755620167] = { kit = "trap", key = 2 }, -- SHEESH-BABYMONSTER, D minor
	[81736514719301] = { kit = "edm", key = 4 }, -- Unbelievable-H1 KEY, E major
	[102947379971628] = { kit = "retro", key = 3 }, -- Boogie Woogie-NCT DREAM, D# major
	[129638210426239] = { kit = "pop", key = 4 }, -- Call My Name-TWS, E major
} :: { [number]: { kit: string, key: number } }

-- the four button sounds of a song: { id, speed, volume } per lane (id 0 = silent)
function DanceScoreSounds.lanes(soundId: number?, baseVolume: number, fallback: { number }): { Play }
	local song = soundId and DanceScoreSounds.Songs[soundId]
	local kit = song and DanceScoreSounds.Kits[song.kit]
	local out: { Play } = {}
	for lane = 1, 4 do
		local k = kit and kit[lane]
		if song and k and k.id ~= 0 then
			local speed = if k.pitched then 2 ^ (song.key / 12) else 1
			table.insert(out, { id = k.id, speed = speed, volume = baseVolume * (DanceScoreSounds.KitGain[song.kit] or 1) })
		else
			table.insert(out, { id = fallback[lane] or 0, speed = 1, volume = baseVolume })
		end
	end
	return out
end

return DanceScoreSounds

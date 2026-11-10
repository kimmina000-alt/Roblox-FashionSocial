--!strict
-- Club MVP data (Stage 4): dance list, tempo range, club music.
--
-- Dances are Roblox-made catalog emotes (creator "Roblox"), so any experience
-- may play them. Each animationId below is the clip inside the emote package,
-- resolved once with InsertService:LoadAsset in Studio (2026-10-20) and checked
-- to load on a character. Branded emotes (artists, films, TV) are left out.
--
-- Music: free Creator Store audio from the licensed distributors
-- (DistrokidOfficial, APMOfficial), checked to load in Studio (2026-10-20).
-- Lengths are rounded down from Sound.TimeLength; the server advances tracks
-- by these lengths.

local ClubConfig = {}

-- (D-888) the big tables live in their own files next to this one; their
-- fields are copied here one by one, so ClubConfig.X and the types still work
local ClubChoreo = require(script.Parent:WaitForChild("ClubChoreo"))
local ClubDances = require(script.Parent:WaitForChild("ClubDances"))
local ClubPlaylist = require(script.Parent:WaitForChild("ClubPlaylist"))
local ClubDrinks = require(script.Parent:WaitForChild("ClubDrinks"))
export type Dance = ClubDances.Dance
export type Track = ClubPlaylist.Track
export type Lab = ClubPlaylist.Lab
export type Joined = ClubPlaylist.Joined
export type DrinkVariant = ClubDrinks.DrinkVariant
export type Drink = ClubDrinks.Drink
ClubConfig.ChoreoSmoothing = ClubChoreo.ChoreoSmoothing
ClubConfig.ChoreoRetarget = ClubChoreo.ChoreoRetarget
ClubConfig.ChoreoDejitter = ClubChoreo.ChoreoDejitter
ClubConfig.ChoreoKeepDetail = ClubChoreo.ChoreoKeepDetail
ClubConfig.ChoreoHome = ClubChoreo.ChoreoHome
ClubConfig.ChoreoFrontLock = ClubChoreo.ChoreoFrontLock
ClubConfig.ChoreoDriftReturn = ClubChoreo.ChoreoDriftReturn
ClubConfig.ChoreoFixes = ClubChoreo.ChoreoFixes
ClubConfig.ChoreoCalm = ClubChoreo.ChoreoCalm
ClubConfig.ChoreoShake = ClubChoreo.ChoreoShake
ClubConfig.ChoreoSlideStill = ClubChoreo.ChoreoSlideStill
ClubConfig.Categories = ClubDances.Categories
ClubConfig.Dances = ClubDances.Dances
ClubConfig.TempoMin = ClubDances.TempoMin
ClubConfig.TempoMax = ClubDances.TempoMax
ClubConfig.TempoStep = ClubDances.TempoStep
ClubConfig.JoinRadius = ClubDances.JoinRadius
ClubConfig.SavedLabs = ClubPlaylist.SavedLabs
ClubConfig.Playlist = ClubPlaylist.Playlist
ClubConfig.Drinks = ClubDrinks.Drinks
ClubConfig.VipCoinRate = ClubDrinks.VipCoinRate
ClubConfig.TierNames = ClubDrinks.TierNames
ClubConfig.findVariant = ClubDrinks.findVariant
ClubConfig.coinPrice = ClubDrinks.coinPrice
ClubConfig.MaxBottlesCarried = ClubDrinks.MaxBottlesCarried
ClubConfig.BottleServings = ClubDrinks.BottleServings
ClubConfig.BottleLifetime = ClubDrinks.BottleLifetime
ClubConfig.bottleLifetime = ClubDrinks.bottleLifetime
ClubConfig.MaxCupsCarried = ClubDrinks.MaxCupsCarried
ClubConfig.DrinkSeconds = ClubDrinks.DrinkSeconds
ClubConfig.GulpSoundId = ClubDrinks.GulpSoundId
ClubConfig.Visibility = ClubDrinks.Visibility
ClubConfig.findDrink = ClubDrinks.findDrink


-- Skip vote (user 2026-11-01, D-694): votes needed to skip the song while
-- there is no DJ = half the people in the club, rounded up, and at least 2
-- once two or more are there (alone: your own vote is enough)
function ClubConfig.skipVotesNeeded(peopleInClub: number): number
	if peopleInClub <= 1 then return 1 end
	return math.max(2, math.ceil(peopleInClub / 2))
end

-- 🧪 (user 2026-11-01) the "Bubble Pop 틀기" test button in the club, for
-- trying the choreography on a phone: shown in Studio and, on live servers,
-- to the experience owner's account only. Set to false before the launch.
ClubConfig.TestChoreoButton = false -- (off 2026-11-01, user: "아래 테스트 삭제")
function ClubConfig.canTestChoreo(player: Player): boolean
	if not ClubConfig.TestChoreoButton then return false end
	if game:GetService("RunService"):IsStudio() then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- (D-849, user) who may move the song with the play bar: the DJ playing now,
-- the game's owner, anyone in Studio tests
-- (D-1187, user 2026-11-10: "ahchimsae한테 dj 권 영구로 줘. 테스트하다가 일시정지
-- 사라져버림") accounts with the owner's DJ rights on live servers: the play
-- bar's ⏸ / seek always (not only during their DJ time), and DJ time again
-- whenever the booth is free (DjService). Add a UserId to give it, remove to take it back.
ClubConfig.DJGranted = {
	[11350809588] = true, -- ahchimsae (test account, D-1166)
	[11584919561] = true, -- cortis_ian (D-1288, user 2026-11-11: "cortis_ian 한테도 dj 줘")
} :: {[number]: boolean}
function ClubConfig.canSeek(player: Player, isDJ: boolean): boolean
	if isDJ or game:GetService("RunService"):IsStudio() then return true end
	if ClubConfig.DJGranted[player.UserId] then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- The lab's apply(): the PlaybackSpeed really sent (speed × tempo, Roblox
-- stops at 20) and the PitchShift octave (octave ÷ the tempo that got
-- through: tempo is speed with the pitch put back, 1/32..32)
function ClubConfig.labEffective(lab: Lab): (number, number)
	local playSpeed = math.min(lab.speed * lab.tempo, 20)
	local tempo = playSpeed / lab.speed
	return playSpeed, math.clamp(lab.octave / tempo, 1 / 32, 32)
end

-- One PitchShiftSoundEffect reaches 0.5..2: a bigger octave is split into n
-- equal parts, n = ceil(|log2 octave|), at most 5 (the lab's octaveParts)
function ClubConfig.octaveParts(t: number): {number}
	if t >= 0.5 and t <= 2 then return { t } end
	local n = math.clamp(math.ceil(math.abs(math.log(t, 2)) - 1e-6), 1, 5)
	local part = t ^ (1 / n)
	local list = {}
	for i = 1, n do list[i] = part end
	return list
end

-- the name shown for a track: a 🎵 when its choreography is danced
-- (autoChoreo; Bubble Pop's older one is kept but not danced) (D-731).
-- (D-756, user: in front of the title and smaller) Rich text: the label needs
-- RichText = true; textSize = the label's TextSize (the mark is 70 % of it).
local function escape(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
ClubConfig.escapeRich = escape
function ClubConfig.showTitle(track: Track, textSize: number?): string
	local title = escape(track.title)
	if not (track.choreo and track.autoChoreo) then return title end
	return string.format('<font size="%d">🎵</font> %s', math.floor((textSize or 14) * 0.7 + 0.5), title)
end

-- how fast a track's audio runs: its own base speed (or its lab
-- PlaybackSpeed) times the DJ's speed
function ClubConfig.trackRate(track: Track?, djSpeed: any): number
	local base = if track and track.lab then (ClubConfig.labEffective(track.lab))
		elseif track and track.baseSpeed then track.baseSpeed else 1
	return base * (if typeof(djSpeed) == "number" then djSpeed else 1)
end

-- (D-876, user: "왜 안무랑 음악 타이밍이 안 맞는 상황이 발생하는지 연구 후 … 보완")
-- the user's uploads are the song sped up exactly 3 times (IVE: 64.33 s x 3
-- = 193.0 s, the original) and played back slower by each song's lab tempo,
-- set by ear (0.332..0.34), so a tempo other than 1/3 runs the heard song a
-- little slower or faster than the original (NEON 0.332: 0.4 %, 0.9 s over
-- 3:42). Choreography is cut from videos on the original's clock, so it
-- follows this clock: the original song's seconds per real second, as heard
-- (`fileSpeed` on a track overrides the uploads' 3)
ClubConfig.UploadSpeed = 3
-- (joined songs) a track uploaded as several clips (Track.joined): played by
-- Shared/JoinedSongPlayer instead of one Sound. (It was called here and in
-- DanceController / ChoreoController but missing, and the club music stopped.)
function ClubConfig.isJoined(track: Track?): boolean
	return track ~= nil and typeof(track.joined) == "table" and typeof(track.joined.parts) == "table" and #track.joined.parts > 0
end
function ClubConfig.fileSpeed(track: Track?): number
	if track and typeof(track.fileSpeed) == "number" then return track.fileSpeed end
	-- (joined songs) the clips are cut from the original as it is: x1
	if ClubConfig.isJoined(track) then return 1 end
	return if track and track.lab then ClubConfig.UploadSpeed else 1
end
function ClubConfig.songRate(track: Track?, djSpeed: any): number
	return ClubConfig.trackRate(track, djSpeed) * ClubConfig.fileSpeed(track)
end



-- Music volume inside the club; it fades out over FadeDistance studs outside
-- the club zone (parts tagged "ClubZone").
ClubConfig.MusicVolume = 0.55
-- Short fade: outside the club building it is silent (user, 2026-10-20:
-- music starts in the narrow corridor, quiet on the stairs, full in the hall).
ClubConfig.FadeDistance = 6
-- Volume per club zone (ClubZone part attribute "Zone"). Inside a zone that
-- zone's level is used (the quietest when zones overlap); outside, the loudest
-- fade wins. The rooftop is quieter, like music coming up from below.
ClubConfig.ZoneVolumes = { Hall = 1, Corridor = 0.45, Stairs = 0.12, Rooftop = 0.3, Locker = 0.5 }
-- (D-834, user) more music zones as world boxes, beside the tagged ClubZone
-- parts: the locker room and its passage (tools/graybox/club_locker_1103.lua,
-- under the 국밥집 lot, x 131.6..231, z -365..-289.9, floor -24, ceiling -3)
ClubConfig.ExtraZones = {
	{ zone = "Locker", min = Vector3.new(130, -24, -366.6), max = Vector3.new(232.6, -3, -289.9) },
}
-- (D-834, user) silent boxes: no club music inside them, even a fade from a
-- zone next door (the 국밥집 stands right over the locker room and by the club's
-- north wall). From y -2: the locker room's ceiling is at -3.
ClubConfig.QuietBoxes = {
	{ min = Vector3.new(39, -2, -377), max = Vector3.new(159, 46, -291) }, -- 국밥집 (Hongdae_Layout.Gukbap)
}

-- Club light colours the DJ can pick (user, 2026-10-22: "보통 클럽에서 쓰는
-- 조명 색"). Lasers and beat lights use the colour; "rainbow" = colour cycle.
ClubConfig.LightColors = {
	{ key = "rainbow", name = "무지개", color = nil :: Color3? },
	{ key = "magenta", name = "마젠타", color = Color3.fromRGB(255, 40, 200) },
	{ key = "uv", name = "UV 보라", color = Color3.fromRGB(140, 60, 255) },
	{ key = "blue", name = "딥 블루", color = Color3.fromRGB(40, 80, 255) },
	{ key = "cyan", name = "시안", color = Color3.fromRGB(40, 230, 255) },
	{ key = "red", name = "레드", color = Color3.fromRGB(255, 40, 60) },
	{ key = "green", name = "그린 레이저", color = Color3.fromRGB(60, 255, 90) },
	{ key = "white", name = "화이트 스트로브", color = Color3.fromRGB(255, 255, 255) },
}
function ClubConfig.findLightColor(key: any)
	for _, entry in ipairs(ClubConfig.LightColors) do
		if entry.key == key then return entry end
	end
	return nil
end


-- DJ sound controls (user 2026-10-30): the playback speed, cycled by a
-- button like the laser speed, and the pitch, up / down in the same steps
-- (user 2026-10-30, in place of the treble / bass boosts). The pitch is the
-- one heard: a PitchShiftSoundEffect makes up for what the speed does to it
-- (its octave = pitch / speed, 0.25..4 with two effects in a row).
-- (user 2026-10-30, later) finer steps: speed x0.25..x2 by 0.05, pitch
-- x0.5..x2 by 0.1, both with − / + buttons.
local function steps(from: number, to: number, step: number): {number}
	local list = {}
	for i = 0, math.floor((to - from) / step + 0.5) do
		table.insert(list, math.floor((from + i * step) * 100 + 0.5) / 100)
	end
	return list
end
-- (user 2026-11-01, later: all three up to x5)
ClubConfig.MusicSpeeds = steps(0.25, 5, 0.05)
ClubConfig.MusicPitches = steps(0.5, 5, 0.1)
-- (user 2026-11-01) the DJ's mixer on the turntable: speed, volume and the
-- PitchShift octave, each with − / +. The volume is a multiplier on the
-- track's own volume (0 = silent .. x2); the pitch is now the octave itself
-- (times the track's own octave), no longer made up for the speed.
ClubConfig.MusicVolumes = steps(0, 5, 0.1)

-- the place in a list nearest to a value (an old setting between two steps)
function ClubConfig.nearestStep(list: {number}, value: any): number
	local v = if typeof(value) == "number" then value else 1
	local best, bestDiff = 1, math.huge
	for i, x in ipairs(list) do
		if math.abs(x - v) < bestDiff then best, bestDiff = i, math.abs(x - v) end
	end
	return best
end

function ClubConfig.findDance(key: any): Dance?
	if typeof(key) ~= "string" then return nil end
	for _, dance in ipairs(ClubConfig.Dances) do
		if dance.key == key then return dance end
	end
	return nil
end

function ClubConfig.clampTempo(speed: any): number
	if typeof(speed) ~= "number" or speed ~= speed then return 1 end
	local stepped = math.floor(speed / ClubConfig.TempoStep + 0.5) * ClubConfig.TempoStep
	return math.clamp(stepped, ClubConfig.TempoMin, ClubConfig.TempoMax)
end

local function insideTagged(tag: string, position: Vector3): boolean
	for _, box in ipairs(game:GetService("CollectionService"):GetTagged(tag)) do
		if box:IsA("BasePart") then
			local p = box.CFrame:PointToObjectSpace(position)
			local half = box.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- Inside the club (hall or rooftop): boxes tagged "ClubInterior" by the
-- graybox script. The 💃 button and tapping players only work in here.
-- Club entry only at night (CLUB.md §20, D-264 / D-267, code D-320). It is on
-- by itself once the game clock flows (DayNightConfig.FixedClockTime = nil);
-- while the clock is pinned for building, the club stays open.
ClubConfig.NightEntry = {
	-- (on again, user 2026-10-30: the club opens only at night; was off for testing since 2026-10-27)
	Enabled = true,
	OpenHour = 18, -- 18:00 .. 06:00
	CloseHour = 6,
	-- where someone who walks in by day is put back: the sidewalk in front of the door
	-- (layout v8, 2026-10-27: the club moved 24 north, door z -186 → -210)
	ExitPosition = Vector3.new(41, 3.6, -210),
	DoorPosition = Vector3.new(46.5, 8, -210), -- the "opens in n min" sign
}

function ClubConfig.isNightOpen(clock: number): boolean
	local n = ClubConfig.NightEntry
	return clock >= n.OpenHour or clock < n.CloseHour
end

-- (D-846, user: "락커룸에서도 … 클럽 안에서 하는 기능 다 가능하게 해") the
-- locker room counts as inside the club too: the song banner, dances, song
-- list, skip vote, choreography (its ExtraZones box)
local function inLocker(position: Vector3): boolean
	for _, extra in ipairs(ClubConfig.ExtraZones) do
		local lo, hi = extra.min, extra.max
		if extra.zone == "Locker" and position.X >= lo.X and position.X <= hi.X and position.Y >= lo.Y and position.Y <= hi.Y
			and position.Z >= lo.Z and position.Z <= hi.Z then
			return true
		end
	end
	return false
end

function ClubConfig.isInClub(position: Vector3): boolean
	return insideTagged("ClubInterior", position) or inLocker(position)
end

-- Dancing is allowed in the club and on photo booth stages ("PhotoStage"
-- boxes), where the 인생네컷 pose panel uses the same dances.
function ClubConfig.canDance(position: Vector3): boolean
	return ClubConfig.isInClub(position) or insideTagged("PhotoStage", position)
end

-- How long a player must stay outside before their dance stops (doorways,
-- the rooftop elevator ride).
ClubConfig.OutsideGrace = 1.5

-- Where the 불꽃 판매원 stands, from the BartenderSpot (its +X runs along the
-- bar, its look faces the room). D-750, user's live screenshot: by the north
-- wall, just east of the hall doorway to the VIP stairs (world about 128,
-- -270), facing into the room. Before: 8 along the bar (76, -170).
ClubConfig.ItemSellerOffset = CFrame.new(-92, 0, -52) * CFrame.Angles(0, -math.pi / 2, 0)

-- A table (bottles, sparkler bucket) stays this long after its owner leaves the
-- game, so a quick rejoin finds it still theirs (D-770, user: 2-3 min, not
-- cleared at once). DrinkService / SparkleService.
ClubConfig.TableKeepSeconds = 180

return ClubConfig

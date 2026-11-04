--!strict
-- (D-888, user 2026-11-05: ClubConfig split up, one file per kind) The dance menu: categories, dances, tempo range, join radius.
-- ClubConfig re-exports every field below, so ClubConfig.Dances keeps working.

export type Dance = {
	key: string,
	name: string,
	category: string,
	animationId: number,
	looped: boolean,
}

local M = {}

M.Categories = { "댄스", "포즈·응원" }

M.Dances = {
	{ key = "shuffle", name = "셔플", category = "댄스", animationId = 10714371274, looped = true },
	{ key = "line", name = "라인 댄스", category = "댄스", animationId = 10714383856, looped = true },
	{ key = "break", name = "브레이크", category = "댄스", animationId = 10714003221, looped = true },
	{ key = "floss", name = "플로스", category = "댄스", animationId = 10714340543, looped = true },
	{ key = "dorky", name = "코믹 댄스", category = "댄스", animationId = 10714069471, looped = true },
	{ key = "dolphin", name = "돌고래", category = "댄스", animationId = 10714068222, looped = true },
	{ key = "air", name = "에어 댄스", category = "댄스", animationId = 10713957138, looped = true },
	{ key = "swan", name = "스완", category = "댄스", animationId = 10714352930, looped = true },
	{ key = "baby", name = "베이비", category = "댄스", animationId = 10713983178, looped = true },
	{ key = "sandwich", name = "샌드위치", category = "댄스", animationId = 10714384494, looped = true },
	{ key = "samba", name = "삼바", category = "댄스", animationId = 10714386947, looped = true },
	{ key = "chacha", name = "차차", category = "댄스", animationId = 6862001787, looped = true },
	{ key = "toprock", name = "톱록", category = "댄스", animationId = 10714336041, looped = true },
	{ key = "sidetoside", name = "사이드 투 사이드", category = "댄스", animationId = 10714366910, looped = true },
	{ key = "aroundtown", name = "흔들흔들", category = "댄스", animationId = 10713981723, looped = true },
	{ key = "robot", name = "로봇", category = "댄스", animationId = 10714392151, looped = true },
	{ key = "rockon", name = "락 온", category = "댄스", animationId = 10714403700, looped = true },
	{ key = "idol", name = "아이돌", category = "댄스", animationId = 10714372526, looped = true },
	{ key = "hyper5g", name = "초고속 무브", category = "댄스", animationId = 10714371264, looped = true },
	{ key = "blockparty", name = "블록 파티", category = "댄스", animationId = 10713988674, looped = true },
	{ key = "twirl", name = "빙그르르", category = "댄스", animationId = 10714293450, looped = true },
	{ key = "fashionable", name = "패셔니스타", category = "포즈·응원", animationId = 10714091938, looped = true },
	{ key = "iceskate", name = "패션 스핀", category = "포즈·응원", animationId = 131669256082047, looped = true },
	{ key = "greatest", name = "내가 제일 잘 나가", category = "포즈·응원", animationId = 10714349037, looped = false },
	{ key = "heisman", name = "하이즈먼 포즈", category = "포즈·응원", animationId = 10714357129, looped = false },
	{ key = "jumpcheer", name = "환호 점프", category = "포즈·응원", animationId = 5895324424, looped = true },
	{ key = "applaud", name = "박수", category = "포즈·응원", animationId = 10713966026, looped = true },
	{ key = "hello", name = "안녕", category = "포즈·응원", animationId = 10714359093, looped = false },
	{ key = "highwave", name = "크게 손 흔들기", category = "포즈·응원", animationId = 10714362852, looped = true },
	{ key = "curtsy", name = "인사", category = "포즈·응원", animationId = 10714061912, looped = false },
	{ key = "celebrate", name = "축하", category = "포즈·응원", animationId = 10714016223, looped = true },
} :: {Dance}

M.TempoMin = 0.5
M.TempoMax = 2.0
M.TempoStep = 0.1

-- How far away another player can be to show up under 같이 추기 (the panel
-- list). Clicking a player works anywhere inside the club.
M.JoinRadius = 90

return M

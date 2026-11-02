# 클럽 음원 목록 · 설정값 (2026-11-02, D-755)

코드: `src/ReplicatedStorage/FashionGame/Shared/ClubConfig.lua` 의 `ClubConfig.Playlist` (27곡).
예전 목록·안무 기록: `OLD_CLUB_PLAYLIST.md`.

## 설정값 2가지

| 이름 | 쓰는 곡 | 값 |
|---|---|---|
| 기본 | 로블록스 음악 12곡 | 설정값 없음. 올라온 그대로, 클럽 볼륨 0.55 (`ClubConfig.MusicVolume`) |
| 저장 값 `UP` | 사용자 업로드 3곡 (A2O LITE-NEON, SOYEON-퇴사할게여, ILLIT-체포하겠어; 나머지 10곡은 곡별 값, D-766) | `{ speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }` |

- `UP` = `ClubConfig.SavedLabs.userUpload`. 이 값을 쓰는 곡은 한꺼번에 바뀌어요.
- 한 곡만 다르게 하려면 그 곡의 `lab = UP` 를 `lab = { ... }` 로 바꾸면 돼요.
- 실제로 나가는 값: 재생 속도 = speed × tempo = **0.335**, 음높이는 PitchShift로 되돌림(octave ÷ tempo). 들리는 길이 = 길이(x1) ÷ 0.335.
- 템포 0.335 = RIIZE-Get A Guitar(53.6초)를 약 2분 40초로 맞춘 값. 부스트 3, 음색(저·중·고) 보정 없음 = 사용자 2026-11-03 (D-765; 그전엔 부스트 6, 저 -6 / 중 0.5 / 고 -7).

## 1. 로블록스 음악 12곡 (설정값 없음)

| # | 채널 | 곡 | soundId | 길이(초) |
|---|---|---|---|---|
| 1 | K-POP | K-Pop Party | 135361546383974 | 145 |
| 2 | K-POP | K-pop Cute Crush | 121416896999522 | 108 |
| 3 | K-POP | K-Pop Uprising | 72966738276299 | 130 |
| 4 | K-POP | Push & Pull (밀당의 고수) | 132502088493185 | 140 |
| 5 | K-POP | Secret Party | 75682100037866 | 146 |
| 6 | K-POP | Luminous Dance | 123336690588412 | 163 |
| 7 | EDM | LIGHT UP THE NIGHT | 102534983754242 | 235 |
| 8 | EDM | RUN THE NIGHT | 123336998544849 | 218 |
| 9 | EDM | ECHOES OF THE BASS (EDM 버튼 곡) | 134070050316863 | 203 |
| 10 | DISCO | Disco Inferno | 87243738678545 | 135 |
| 11 | EDM | Festival Fever | 136228548293465 | 103 |
| 12 | EDM | Euphoria Dance | 76814968175069 | 99 |

## 2. 사용자 업로드 15곡 (3곡 `UP`, 12곡 곡별 값; D-767에서 16곡 삭제, D-768에서 2곡 추가)

길이는 x1 기준(들리는 길이 = ÷ 0.335).

| # | 곡 | soundId | 길이(초) | 들리는 길이 | 안무 |
|---|---|---|---|---|---|
| 13 | ATEEZ-BAD | 134942349436280 | 51 | 2:32 | |
| 14 | 소녀시대-소원을 말해봐(Genie) | 128270208751659 | 76 | 3:47 | |
| 15 | 현아-Bubble Pop | 76388700698178 | 71 | 3:32 | 11개 (자동 아님) |
| 16 | RIIZE-Get A Guitar | 91762270038050 | 54 | 2:40 | 20개, 자동 🎵 |
| 17 | RIIZE-Love 119 | 119473981131981 | 58 | 2:53 | |
| 18 | YENA-Catch Catch | 80583279340768 | 61 | 3:02 | |
| 19 | Hearts2Hearts-Lemon Tang | 97032815457241 | 54 | 2:41 | |
| 20 | aespa-Lemonade | 132067415333401 | 62 | 3:05 | |
| 21 | IVE-Mirror | 139326796173276 | 67 | 3:20 | |
| 22 | A2O LITE-NEON | 74555169365877 | 74 | 3:41 | |
| 23 | SOYEON-퇴사할게여 | 113196766736048 | 71 | 3:32 | |
| 24 | ILLIT-체포하겠어 | 92011448544342 | 61 | 3:02 | |
| 25 | IOI-갑자기 | 73546697163709 | 65 | 3:14 | |
| 26 | NMIXX-긴 소원(Birthday Wish) | 107782871991364 | 67 | 3:20 | |
| 27 | NCT WISH-I SPY | 90694654380166 | 62 | 3:05 | |

## 곡별 값 (D-766, 2026-11-03)

speed 1, volume 10, octave 0.5, engine "sound" 는 공통.

| 곡 | 템포 | 부스트 | 저 | 중 | 고 |
|---|---|---|---|---|---|
| ATEEZ-BAD | 0.333 | 2.5 | 0 | 0 | 0 |
| 소녀시대-소원을 말해봐(Genie) | 0.334 | 2.5 | -5 | 2 | 0 |
| 현아-Bubble Pop | 0.333 | 2.5 | -6 | 0.5 | -7 |
| RIIZE-Get A Guitar | 0.333 | 3 | -7 | -3 | 1.5 |
| RIIZE-Love 119 | 0.333 | 3 | -7 | -3 | 1.5 |
| YENA-Catch Catch | 0.34 | 3 | -13 | 2.5 | 4 |
| Hearts2Hearts-Lemon Tang | 0.333 | 3 | -3 | 2 | 0 |
| aespa-Lemonade | 0.333 | 3 | -11 | 0 | -2.5 |
| IVE-Mirror | 0.332 | 3 | -10.5 | 5 | 4.5 |
| IOI-갑자기 (새 음원 73546697163709) | 0.333 | 2.4 | -9.5 | 6 | 0 |
| NMIXX-긴 소원 (107782871991364, D-768) | 0.333 | 3 | -3 | 2 | 0 |
| NCT WISH-I SPY (90694654380166, D-768) | 0.333 | 3 | -3 | 2 | 0 |

## 3. 턴테이블 랩(테스트 장소)에 넣을 때

테스트 장소 "테스트" 86558282086977 (tools/test_places/turntable_lab)의 저장 형식은 soundId별 표예요. 곡 목록(곡별 값이 있는 곡은 위 표 값):

```lua
local UP = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }
local LAB = {
	["134942349436280"] = UP, -- ATEEZ-BAD
	["128270208751659"] = UP, -- 소녀시대-소원을 말해봐(Genie)
	["76388700698178"] = UP, -- 현아-Bubble Pop
	["91762270038050"] = UP, -- RIIZE-Get A Guitar
	["119473981131981"] = UP, -- RIIZE-Love 119
	["80583279340768"] = UP, -- YENA-Catch Catch
	["97032815457241"] = UP, -- Hearts2Hearts-Lemon Tang
	["132067415333401"] = UP, -- aespa-Lemonade
	["139326796173276"] = UP, -- IVE-Mirror
	["74555169365877"] = UP, -- A2O LITE-NEON
	["113196766736048"] = UP, -- SOYEON-퇴사할게여
	["92011448544342"] = UP, -- ILLIT-체포하겠어
	["73546697163709"] = UP, -- IOI-갑자기
}
```

랩에서 곡별로 바꾼 값은 "곡 이름 + soundId + lab 값"으로 보내 주면 ClubConfig의 그 곡에만 넣을게요.

# 클럽 음원 목록 · 설정값 (2026-11-03, D-796까지)

코드: `src/ReplicatedStorage/FashionGame/Shared/ClubPlaylist.lua` (37곡; `ClubConfig.Playlist`로도 읽힘, D-888). 37번부터 = 아랄 음원 칸, 아래 4번.
예전 목록·안무 기록: `OLD_CLUB_PLAYLIST.md`.

## 설정값 2가지

| 이름 | 쓰는 곡 | 값 |
|---|---|---|
| 기본 | 로블록스 음악 12곡 | 설정값 없음. 올라온 그대로, 클럽 볼륨 0.55 (`ClubConfig.MusicVolume`) |
| 저장 값 `UP` | 지금 쓰는 곡 없음 (D-779부터 업로드 20곡 모두 곡별 값) | `{ speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }` |

- `UP` = `ClubConfig.SavedLabs.userUpload`. 이 값을 쓰는 곡은 한꺼번에 바뀌어요.
- 한 곡만 다르게 하려면 그 곡의 `lab = UP` 를 `lab = { ... }` 로 바꾸면 돼요.
- 실제로 나가는 값: 재생 속도 = speed × tempo, 음높이는 PitchShift로 되돌림(octave ÷ tempo). 들리는 길이 = 길이(x1) ÷ 템포.
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

## 2. 사용자 업로드 24곡 (모두 곡별 값; D-767 16곡 삭제, D-768 2곡, D-779 8곡, D-782 5곡, D-794 IU-이 별로부터 삭제)

길이는 x1 기준(들리는 길이 = ÷ 그 곡의 템포, 아래 곡별 값 표).

| # | 곡 | soundId | 길이(초) | 들리는 길이 | 안무 |
|---|---|---|---|---|---|
| 13 | ATEEZ-BAD | 134942349436280 | 51 | 2:32 | 23개(0:00~곡 끝), 자동 🎵, 이음새 blend + turn, 11번 from 1.3 (D-844) |
| 14 | 소녀시대-소원을 말해봐(Genie) | 128270208751659 | 76 | 3:47 | 26개(0:14~3:36), 자동 🎵, 커버 영상 시간(t = 클립 + 13.55초, 영상이 전주를 잘라 냄), blend, still (D-897) |
| 15 | 현아-Bubble Pop | 76388700698178 | 71 | 3:32 | 11개 (자동 아님) |
| 16 | RIIZE-Get A Guitar | 91762270038050 | 54 | 2:40 | 20개, 자동 🎵, 제자리에서 (D-802), 1:10에서 2초 잘라 이어 붙임 (D-810), 이음새 blend (D-807) |
| 17 | RIIZE-Love 119 | 119473981131981 | 58 | 2:53 | |
| 18 | YENA-Catch Catch | 80583279340768 | 61 | 3:02 | |
| 19 | Hearts2Hearts-Lemon Tang | 97032815457241 | 54 | 2:41 | |
| 20 | aespa-Lemonade | 132067415333401 | 62 | 3:05 | |
| 21 | IVE-Mirror | 139326796173276 | 67 | 3:20 | |
| 22 | A2O LITE-NEON (다섯시사십칠분) | 97511700575810 | 73.8 | 3:42 | 22개, 자동 🎵, 이음새 blend (D-809) |
| 23 | SOYEON-퇴사할게여 (다섯시사십팔분) | 96358497474432 | 70.5 | 3:31 | |
| 24 | ILLIT-체포하겠어 (다섯시사십구분) | 139044453511745 | 60.6 | 3:01 | 21개(0:00~3:01), 자동 🎵, 연습 영상 시간(`at` = 클립 − 2.38초), blend (D-914) |
| 25 | RESCENE-LOVE-ATTACK (다섯시오십이분) | 71873496902418 | 60.5 | 3:01 | 27개(0:00~3:01), 자동 🎵, 연습 영상 시간(t = 클립 − 0.45초), blend, still (D-903) |
| 26 | MY:RAKL-오색 낙원 (다섯시오십육분) | 108027306922001 | 61.3 | 3:04 | |
| 27 | Darla Jean-Dam Da Dee (다섯시오십칠분) | 78077595750886 | 72.9 | 3:38 | |
| 28 | 머무르-꿈꾸던 어른이 되었나요 (다섯시오십팔분) | 120160897793669 | 69.2 | 3:27 | |
| 29 | IVE-Looks Can Kill (다섯시오십구분) | 135553051649506 | 64.3 | 3:13 | 앞부분 7개(0:00~0:41), 자동 🎵, 이음새 blend (D-826) |
| 30 | IOI-갑자기 | 73546697163709 | 65 | 3:14 | |
| 31 | NMIXX-긴 소원(Birthday Wish) | 107782871991364 | 67 | 3:20 | |
| 32 | NCT WISH-I SPY | 90694654380166 | 62 | 3:05 | 30개(0:01~3:05), 자동 🎵, 연습 영상 시간(`at` = 클립 + 1.50초), blend, still (D-912) |
| 33 | CORTIS-REDRED (여섯시오분; D-890 이어 붙인 노래 시험 뒤 D-894에 이 파일로 되돌림) | 125703446596781 | 54.35 | 2:43 | 24개(0:00~2:43), 자동 🎵, 연습 영상 시간(`at` = 클립 − 0.40초), blend + turn, still (D-879) |
| 34 | BIG Naughty-노스탈지아 (여섯시육분) | 116539470869444 | 65.0 | 3:15 | |
| 35 | BIGBANG-BiiiG (여섯시칠분) | 113809029583519 | 54.8 | 2:44 | |
| 36 | BOYNEXTDOOR-ANIMAL (여섯시팔분) | 130804487358433 | 47.6 | 2:22 | 25개(0:00~2:23), 자동 🎵, 연습 영상 시간(`at` = 클립 + 0.23초), blend (D-916) |

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
| NMIXX-긴 소원 (107782871991364, D-768) | 0.333 | 3 | 0 | 0 | 0 |
| NCT WISH-I SPY (90694654380166, D-768) | 0.333 | 3 | 0 | 0 | 0 |
| A2O LITE-NEON (97511700575810, D-779) | 0.332 | 3 | -3 | 2 | 0 |
| SOYEON-퇴사할게여 (96358497474432, D-779) | 0.334 | 3 | -3 | 2 | 0 |
| ILLIT-체포하겠어 (139044453511745, D-779) | 0.335 | 3 | -1.5 | 0 | 0 |
| RESCENE-LOVE-ATTACK (71873496902418, D-779) | 0.334 | 3 | -11 | 0 | 0 |
| MY:RAKL-오색 낙원 (108027306922001, D-779) | 0.333 | 3 | 0 | 0 | 0 |
| Darla Jean-Dam Da Dee (78077595750886, D-779) | 0.335 | 3 | 0 | 0 | 0 |
| 머무르-꿈꾸던 어른이 되었나요 (120160897793669, D-779) | 0.334 | 3 | 0 | 0 | 0 |
| IVE-Looks Can Kill (135553051649506, D-779) | 0.333 | 3 | 0 | 0 | 0 |
| CORTIS-REDRED (125703446596781, D-782; octave 0.5, D-894) | 0.333 | 3 | -3 | 2 | 0 |
| BIG Naughty-노스탈지아 (116539470869444, D-782) | 0.333 | 3 | 0 | 0 | 0 |
| BIGBANG-BiiiG (113809029583519, D-782) | 0.334 | 3 | 0 | 0 | 0 |
| BOYNEXTDOOR-ANIMAL (130804487358433, D-782) | 0.335 | 3 | 0 | 0 | 0 |

## 3. 턴테이블 랩(테스트 장소)에 넣을 때

테스트 장소 "테스트" 86558282086977 (tools/test_places/turntable_lab)의 저장 형식은 soundId별 표예요. 업로드 24곡의 지금 값 그대로(ClubConfig에서 뽑음, 2026-11-03, D-793):

```lua
local LAB = {
	["134942349436280"] = { speed = 1, tempo = 0.333, volume = 10, boost = 2.5, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- ATEEZ-BAD
	["128270208751659"] = { speed = 1, tempo = 0.334, volume = 10, boost = 2.5, octave = 0.5, low = -5, mid = 2, high = 0, engine = "sound" }, -- 소녀시대-소원을 말해봐(Genie)
	["76388700698178"] = { speed = 1, tempo = 0.333, volume = 10, boost = 2.5, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" }, -- 현아-Bubble Pop
	["91762270038050"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -7, mid = -3, high = 1.5, engine = "sound" }, -- RIIZE-Get A Guitar
	["119473981131981"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -7, mid = -3, high = 1.5, engine = "sound" }, -- RIIZE-Love 119
	["80583279340768"] = { speed = 1, tempo = 0.34, volume = 10, boost = 3, octave = 0.5, low = -13, mid = 2.5, high = 4, engine = "sound" }, -- YENA-Catch Catch
	["97032815457241"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" }, -- Hearts2Hearts-Lemon Tang
	["132067415333401"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -11, mid = 0, high = -2.5, engine = "sound" }, -- aespa-Lemonade
	["139326796173276"] = { speed = 1, tempo = 0.332, volume = 10, boost = 3, octave = 0.5, low = -10.5, mid = 5, high = 4.5, engine = "sound" }, -- IVE-Mirror
	["97511700575810"] = { speed = 1, tempo = 0.332, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" }, -- A2O LITE-NEON
	["96358497474432"] = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" }, -- SOYEON-퇴사할게여
	["139044453511745"] = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = -1.5, mid = 0, high = 0, engine = "sound" }, -- ILLIT-체포하겠어
	["71873496902418"] = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = -11, mid = 0, high = 0, engine = "sound" }, -- RESCENE-LOVE-ATTACK
	["108027306922001"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- MY:RAKL-오색 낙원
	["78077595750886"] = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- Darla Jean-Dam Da Dee
	["120160897793669"] = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- 머무르-꿈꾸던 어른이 되었나요
	["135553051649506"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- IVE-Looks Can Kill
	["73546697163709"] = { speed = 1, tempo = 0.333, volume = 10, boost = 2.4, octave = 0.5, low = -9.5, mid = 6, high = 0, engine = "sound" }, -- IOI-갑자기
	["107782871991364"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- NMIXX-긴 소원(Birthday Wish)
	["90694654380166"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- NCT WISH-I SPY
	["125703446596781"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- CORTIS-REDRED
	["116539470869444"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- BIG Naughty-노스탈지아
	["113809029583519"] = { speed = 1, tempo = 0.334, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- BIGBANG-BiiiG
	["130804487358433"] = { speed = 1, tempo = 0.335, volume = 10, boost = 3, octave = 0.5, low = 0, mid = 0, high = 0, engine = "sound" }, -- BOYNEXTDOOR-ANIMAL
}
```

랩에서 곡별로 바꾼 값은 "곡 이름 + soundId + lab 값"으로 보내 주면 ClubConfig의 그 곡에만 넣을게요.

## 4. 음원 추가 칸 (ClubPlaylist.lua의 `★★★음원 추가★★★` 아래, 사용자가 직접 넣음; D-894 전 이름 `★★★아랄 음원 추가★★★`)

이어 붙인 곡(`joined`)은 30초 조각 여러 개를 한 곡처럼 틀어요(Shared/JoinedSongPlayer, D-887). `joined = { parts, segLen, tail, total, lead }`: 조각 soundId들, 조각 길이, 겹치는 꼬리(초), 전체 길이, 앞 여백. lab의 `boost`(첫 SoundGroup, 0..10)와 `boost2`(두 번째 SoundGroup, 0..10, 노래마다; 안 적으면 1)를 곱한 만큼 커져요(D-892). 이어 붙인 곡에서 boost2 없이 boost를 10 넘게 적으면 넘는 만큼 자동으로 boost2가 돼요(D-891). `volume`은 최대 10. 원곡보다 빠르게 줄인 파일을 조각으로 올렸으면 `fileSpeed`(예: 3)를 적어야 안무가 맞음.

| # | 채널 | 곡 | soundId (첫 조각) | 길이(초) | 조각 | lab | 기록 |
|---|---|---|---|---|---|---|---|
| 37 | K-POP | IU-이 별로부터(Unknown Planet) | 81568082292649 | 225.05 | 8 (segLen 30, tail 4, lead 0.09) | tempo 1, boost 1, octave 1 | D-887, D-889 |
| ~~33~~ | K-POP | ~~CORTIS-REDRED~~ (D-890에 6조각으로 했다가 D-894에 예전 54초 파일로 되돌림, 위 2번) | ~~130916906404688~~ | ~~163~~ | ~~6~~ | | D-890, D-894 |

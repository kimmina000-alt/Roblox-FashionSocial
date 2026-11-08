# 클럽 음원 목록 · 설정값 (2026-11-03, D-796까지)

코드: `src/ReplicatedStorage/FashionGame/Shared/ClubPlaylist.lua` (51곡, D-924; `ClubConfig.Playlist`로도 읽힘, D-888). 끝부분 `--★★★음원 추가★★★--` 아래 = 사용자 음원 칸, 아래 4번.
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
| 13-2 | ATEEZ-BAD 2 | 120615582016729 (ATEEZ-BAD와 같은 음원 · lab · fileSpeed 1.1) | 139.674 | 2:34 | 두 번째 안무 20개(곡 전체), 자동 🎵, 거울 연습 영상(ATEEZ_BAD_Mirrored, 영상 = 곡 + 0.00초)이라 `at` = 클립 시작, 이음새 blend, 무대 카메라는 ATEEZ-BAD 것 같이 씀(키 = soundId) (D-994). 목록에서 ATEEZ-BAD 바로 다음 |
| 14 | 소녀시대-소원을 말해봐(Genie) | 128270208751659 | 76 | 3:47 | 26개(0:14~3:36), 자동 🎵, 커버 영상 시간(t = 클립 + 13.55초, 영상이 전주를 잘라 냄), blend, still (D-897) |
| 15 | 현아-Bubble Pop | 76388700698178 | 71 | 3:32 | 11개 (자동 아님) |
| 16 | RIIZE-Get A Guitar | 133586602463513 | 147.285 | 2:40 | 새 업로드(D-919, 옛 3배 파일 91762270038050 대신): 원곡의 1.0908배 파일(fileSpeed 1.0908), lab tempo 0.921 / boost2 5.05. 20개, 자동 🎵, 제자리에서 (D-802), 1:10에서 2초 잘라 이어 붙임 (D-810), 이음새 blend (D-807), 무대 카메라 (D-900) |
| 17 | RIIZE-Love 119 | 119473981131981 | 58 | 2:53 | 지금 음원 85204387077332(D-933). 안무 33개(27번 다시 올림), 자동 🎵, `at` = (연습 영상 + 0.375) ÷ 1.005 (D-938) |
| 18 | YENA-Catch Catch | 80583279340768 | 61 | 3:02 | 안무 23개(곡 전체, 3 · 6 · 15 · 19 · 22번 다시 올림), 자동 🎵, `at` = 연습 영상 + 0.70초 (D-968) |
| 19 | Hearts2Hearts-Lemon Tang | 97032815457241 | 54 | 2:41 | |
| 20 | Hearts2Hearts-Next Chapter | 113170325006427 | 172.366 | 2:52 | x1 업로드, lab tempo 1 / volume 10 / boost 10 / boost2 5, fileSpeed 1 (D-920) |
| 21 | AND2BLE-French Kissing | 120866427099057 | 177.422 | 3:15 | lab tempo 0.91 / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.0991 (D-921) |
| 22 | RESCENE-With | 120039092597099 | 171.659 | 3:09 | lab tempo 1(사용자 저장값; 3:09로 들으려면 0.908) / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.101 (D-921) |
| 23 | K/DA - FIRESTARTER (Feat. Sophie Powers, MIYEON, SOYEON) | 102216920231649 | 181.643 | 3:20 | lab tempo 0.908 / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.1011 (D-921) |
| 24 | K/DA - NEVER GOING BACK (Feat. SOYEON, MIYEON) | 113680653484321 | 178.034 | 3:16 | lab tempo 0.908 / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.1009 (D-921) |
| 25 | LISA - Tarantino | 102033386205095 | 151.795 | 2:47 | lab tempo 0.909 / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.1002 (D-923) |
| 26 | K/DA - GIRLS (Feat. Sorana, Royal & the Serpent) | 127811970673239 | 112.3 | 2:16 | lab tempo 0.826 / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.211 (D-923) |
| 27 | izna - ROCK, PAPER, SCISSORS | 132951659748689 | 105.5 | 2:21 | lab tempo 0.748 / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.3365 (D-924) |
| 28 | LISA - Cobra | 95502375387883 | 131.638 | 2:25 | lab tempo 0.908 / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.1015 (D-924) |
| 29 | ALLDAY PROJECT - NO 한도 | 81251273866025 | 131.699 | 2:25 | lab tempo 0.908 / volume 10 / boost 10 / boost2 5, fileSpeed ≈ 1.101 (D-924) |
| 30 | aespa-Lemonade | 132067415333401 | 62 | 3:05 | 안무 19개(8 · 20 · 21번 없음), 자동 🎵, 1번 커버 영상(+1.45초) · 2번부터 연습 영상(`at` = 영상 − 1.08초) (D-970) |
| 31 | IVE-Mirror | 139326796173276 | 67 | 3:20 | |
| 32 | A2O LITE-NEON (다섯시사십칠분) | 74988982712396 | 201.19 | 3:42 | 새 업로드(D-922, 옛 3배 파일 97511700575810 대신): 원곡의 1.1배 파일(fileSpeed 1.1), lab tempo 0.91 / boost2 5. 22개, 자동 🎵, 이음새 blend (D-809) , 무대 카메라 (D-898) |
| 33 | SOYEON-퇴사할게여 (다섯시사십팔분) | 96358497474432 | 70.5 | 3:31 | |
| 34 | ILLIT-체포하겠어 (다섯시사십구분) | 139044453511745 | 60.6 | 3:01 | 21개(0:00~3:01), 자동 🎵, 연습 영상 시간(`at` = 클립 − 2.38초), blend (D-914) |
| 35 | RESCENE-LOVE-ATTACK (다섯시오십이분) | 71873496902418 | 60.5 | 3:01 | 27개(0:00~3:01), 자동 🎵, 연습 영상 시간(t = 클립 − 0.45초), blend, still (D-903) |
| 36 | MY:RAKL-오색 낙원 (다섯시오십육분) | 108027306922001 | 61.3 | 3:04 | |
| 37 | Darla Jean-Dam Da Dee (다섯시오십칠분) | 78077595750886 | 72.9 | 3:38 | |
| 38 | 머무르-꿈꾸던 어른이 되었나요 (다섯시오십팔분) | 120160897793669 | 69.2 | 3:27 | |
| 39 | IVE-Looks Can Kill (다섯시오십구분) | 135553051649506 | 64.3 | 3:13 | 앞부분 7개(0:00~0:41), 자동 🎵, 이음새 blend (D-826) |
| 40 | IOI-갑자기 | 73546697163709 | 65 | 3:14 | 안무 25개(곡 전체, 4 · 7번 다시 올림), 자동 🎵, `at` = 연습 영상 − 0.30초 (D-967) |
| 41 | NMIXX-긴 소원(Birthday Wish) | 107782871991364 | 67 | 3:20 | |
| 42 | NCT WISH-I SPY | 90694654380166 | 62 | 3:05 | 30개(0:01~3:05), 자동 🎵, 연습 영상 시간(`at` = 클립 + 1.50초), blend, still (D-912) |
| 43 | CORTIS-REDRED (여섯시오분; D-890 이어 붙인 노래 시험 뒤 D-894에 이 파일로 되돌림) | 125703446596781 | 54.35 | 2:43 | 24개(0:00~2:43), 자동 🎵, 연습 영상 시간(`at` = 클립 − 0.40초), blend + turn, still (D-879) |
| 44 | BIG Naughty-노스탈지아 (여섯시육분) | 116539470869444 | 65.0 | 3:15 | |
| 45 | BIGBANG-BiiiG (여섯시칠분) | 113809029583519 | 54.8 | 2:44 | |
| 46 | BOYNEXTDOOR-ANIMAL (여섯시팔분) | 130804487358433 | 47.6 | 2:22 | 25개(0:00~2:23), 자동 🎵, 연습 영상 시간(`at` = 클립 + 0.23초), blend (D-916) |

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
	["133586602463513"] = { speed = 1, tempo = 0.921, volume = 10, boost = 10, boost2 = 5.05, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- RIIZE-Get A Guitar (D-919, new upload; was 91762270038050)
	["119473981131981"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -7, mid = -3, high = 1.5, engine = "sound" }, -- RIIZE-Love 119
	["80583279340768"] = { speed = 1, tempo = 0.34, volume = 10, boost = 3, octave = 0.5, low = -13, mid = 2.5, high = 4, engine = "sound" }, -- YENA-Catch Catch
	["97032815457241"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -3, mid = 2, high = 0, engine = "sound" }, -- Hearts2Hearts-Lemon Tang
	["113170325006427"] = { speed = 1, tempo = 1, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- Hearts2Hearts-Next Chapter (D-920, x1 file)
	["120866427099057"] = { speed = 1, tempo = 0.91, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- AND2BLE-French Kissing (D-921)
	["120039092597099"] = { speed = 1, tempo = 1, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- RESCENE-With (D-921)
	["102216920231649"] = { speed = 1, tempo = 0.908, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- K/DA - FIRESTARTER (D-921)
	["113680653484321"] = { speed = 1, tempo = 0.908, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- K/DA - NEVER GOING BACK (D-921)
	["102033386205095"] = { speed = 1, tempo = 0.909, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- LISA - Tarantino (D-923)
	["127811970673239"] = { speed = 1, tempo = 0.826, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- K/DA - GIRLS (D-923)
	["132951659748689"] = { speed = 1, tempo = 0.748, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- izna - ROCK, PAPER, SCISSORS (D-924)
	["95502375387883"] = { speed = 1, tempo = 0.908, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- LISA - Cobra (D-924)
	["81251273866025"] = { speed = 1, tempo = 0.908, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- ALLDAY PROJECT - NO 한도 (D-924)
	["132067415333401"] = { speed = 1, tempo = 0.333, volume = 10, boost = 3, octave = 0.5, low = -11, mid = 0, high = -2.5, engine = "sound" }, -- aespa-Lemonade
	["139326796173276"] = { speed = 1, tempo = 0.332, volume = 10, boost = 3, octave = 0.5, low = -10.5, mid = 5, high = 4.5, engine = "sound" }, -- IVE-Mirror
	["74988982712396"] = { speed = 1, tempo = 0.91, volume = 10, boost = 10, boost2 = 5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" }, -- A2O LITE-NEON (D-922, new upload; was 97511700575810)
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
| 39 | K-POP | ALLDAY PROJECT-CRASH | 104827635407586 | 57.68 | 1 파일 | tempo 0.333, boost 3, boost2 1, octave 0.5, EQ -18.5 / -4 / -12.5; 안무 20개(0:00~2:50, 1번 다시 올림 D-918), 자동 🎵, `at` = 연습 영상 − 2.50초 | D-917, D-918 |
| 40 | K-POP | RESCENE-Pretty Girl | 89634330677538 | 70.01 | 1 파일 | tempo 0.333, boost 3, boost2 1, octave 0.5, EQ -18.5 / -4 / -12.5; 안무 26개(곡 전체), 자동 🎵, `at` = 연습 영상 − 0.12초 | D-917, D-937 |
| 41 | K-POP | 키키-Pop Off | 129996145931101 | 47.11 | 1 파일 | tempo 0.334, boost 3, boost2 1, octave 0.5, EQ -18.5 / -4 / -12.5; 안무 21개(곡 전체), 자동 🎵, `at` = 연습 영상 − 0.30초 | D-917, D-936 |

### 새 음원 (D-931, 예전 곡 바로 아래, 안무·무대 카메라 없음)

| 곡 | soundId | 길이(초) | fileSpeed | lab |
|---|---|---|---|---|
| CORTIS-REDRED (새 음원) | 76034005809699 | 153.821 | 1.06 | tempo 0.944, boost 10, boost2 5, octave 1, high -20 |
| RESCENE-LOVE-ATTACK (새 음원) | 139330220515727 | 172.955 | 1.05 | tempo 0.956, boost 10, boost2 5, octave 1, high -20 |
| NCT WISH-I SPY (새 음원) | 98124521559769 | 176.273 | 1.05 | tempo 0.953, boost 10, boost2 5, octave 1, high -23 |
| A2O LITE-NEON (새 음원) | 140713297574648 | 210.771 | 1.05 | tempo 0.954, boost 10, boost2 5, octave 1, high -20 |

### 새 음원 46곡 (D-1021, 2026-11-08, 목록 끝)

모두 volume 10 / boost 10 / boost2 5 / boost3 5 / octave 1 / EQ -34 -20 -34. tempo = 파일 ÷ 곡 길이, fileSpeed = 곡 길이 ÷ 파일.

| 곡 | soundId | 곡 길이 | 파일(초) | tempo | fileSpeed |
|---|---|---|---|---|---|
| K-DA-GIRLS | 133434812252990 | 2:16 | 129.391 | 0.951 | 1.0511 |
| ROCK PAPER SCISSORS | 108797026675247 | 2:20 | 133.713 | 0.955 | 1.047 |
| ALLDAY PROJECT-NO LIMIT | 79664669248816 | 2:25 | 137.95 | 0.951 | 1.0511 |
| RESCENE-With | 112509101263761 | 3:09 | 179.843 | 0.952 | 1.0509 |
| K-DA-FIRESTARTER | 94925181116487 | 3:20 | 190.271 | 0.951 | 1.0511 |
| K-DA-NEVER GOING BACK | 136982561112199 | 3:16 | 186.49 | 0.951 | 1.051 |
| LUMIN-HIDE | 93397731217867 | 3:53 | 221.449 | 0.95 | 1.0522 |
| AND2BLE-French Kissing | 88604783778178 | 3:15 | 185.849 | 0.953 | 1.0492 |
| 헤이즈-빈틈을 채워 준 너에게 | 79978358676881 | 4:05 | 233.453 | 0.953 | 1.0495 |
| Dam Da Dee | 92530611206857 | 3:39 | 208.349 | 0.951 | 1.0511 |
| LUMIN-88 | 131856022019788 | 2:44 | 156.627 | 0.955 | 1.0471 |
| Run the Night | 94663574971399 | 3:04 | 175.25 | 0.952 | 1.0499 |
| 머무르-꿈꾸던 어른이 되었나요 | 95913746283492 | 3:28 | 197.635 | 0.95 | 1.0524 |
| BIG Naughty-노스탈지아 | 138668506442693 | 3:15 | 185.738 | 0.953 | 1.0499 |
| TAEYEON-만찬가 | 124367047209689 | 3:39 | 208.614 | 0.953 | 1.0498 |
| NMIXX-Birthday Wish | 127918504252740 | 3:20 | 190.515 | 0.953 | 1.0498 |
| 송하영-처음 그 자리에 | 85563793488474 | 3:53 | 221.991 | 0.953 | 1.0496 |
| Lee Mujin-Come Rest With Me | 97747873047145 | 4:07 | 235.474 | 0.953 | 1.0489 |
| kennytheking-morae | 112834468757050 | 4:02 | 230.368 | 0.952 | 1.0505 |
| Even if it's slightly off | 94547707613847 | 3:23 | 192.973 | 0.951 | 1.052 |
| When We're Together | 113739077119161 | 3:47 | 215.75 | 0.95 | 1.0521 |
| 송유진-I Miss You | 107465969275795 | 4:13 | 241.019 | 0.953 | 1.0497 |
| URBAN ZAKAPA-거리 | 132434943798296 | 6:06 | 348.425 | 0.952 | 1.0504 |
| 20 Years of Age-Your Season | 118999584170024 | 3:41 | 210.575 | 0.953 | 1.0495 |
| 이민혁·보라미유-사랑일지도 몰라 | 108346448346476 | 4:01 | 229.723 | 0.953 | 1.0491 |
| 정승환-푸르른 계절도 내겐 의미 없어요 | 88022342248077 | 4:49 | 275.256 | 0.952 | 1.0499 |
| 나는 너라서 | 120378159122290 | 3:36 | 205.559 | 0.952 | 1.0508 |
| YOHAN-Song for you | 108378947159567 | 4:19 | 246.384 | 0.951 | 1.0512 |
| Adrian Macéus-Ask You Out | 76084016769694 | 2:27 | 139.683 | 0.95 | 1.0524 |
| becoming a star | 78610966959610 | 3:30 | 199.919 | 0.952 | 1.0504 |
| Just Another Love Song | 73680886300915 | 3:26 | 196.572 | 0.954 | 1.048 |
| Lionel Richie-Can't Slow Down | 119789957160678 | 3:04 | 175.5 | 0.954 | 1.0484 |
| Color Me Home | 131785918775462 | 3:04 | 175.235 | 0.952 | 1.05 |
| Light It Up | 110137761725603 | 3:18 | 188.997 | 0.955 | 1.0476 |
| ALLDAY PROJECT-CRASH | 86115718533153 | 2:53 | 164.773 | 0.952 | 1.0499 |
| KiiiKiii-Pop Off | 131620527618857 | 2:21 | 134.588 | 0.955 | 1.0476 |
| 그사람 | 139646189327476 | 3:55 | 224.251 | 0.954 | 1.0479 |
| CAR, THE GARDEN-Stay | 140222834511413 | 4:00 | 228.605 | 0.953 | 1.0498 |
| 이하이-손을 잡아줘요 | 78224880948150 | 3:30 | 200.36 | 0.954 | 1.0481 |
| Runaway Lights | 110210786180640 | 3:09 | 179.877 | 0.952 | 1.0507 |
| Small Town Ghost | 121184160009188 | 2:45 | 156.907 | 0.951 | 1.0516 |
| All On Me | 112267422115842 | 2:32 | 145.121 | 0.955 | 1.0474 |
| Secret Us | 82537293207913 | 2:08 | 122.199 | 0.955 | 1.0475 |
| ALLDAY PROJECT-CRASH | 127388006729309 | 2:53 | 164.773 | 0.952 | 1.0499 |
| BIGBANG-BiiiG BiiiG | 117439533883778 | 2:44 | 156.414 | 0.954 | 1.0485 |
| KiiiKiii-Pop Off | 122860036531672 | 2:21 | 134.588 | 0.955 | 1.0476 |

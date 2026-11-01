# 예전 클럽 노래 목록과 설정값 (2026-11-02 보관)

2026-11-02(D-739)에 클럽 노래를 Roblox 라이선스 음악 12곡으로 바꾸면서 뺀 K-POP 업로드 9곡과 그 설정값을 모아 둔 문서예요.
되돌리려면 아래 Lua 블록을 `src/ReplicatedStorage/FashionGame/Shared/ClubConfig.lua`의 `ClubConfig.Playlist`에 그대로 붙이면 돼요.
git에서도 꺼낼 수 있어요: `catalog-ui-redesign` 4747e9c 커밋의 ClubConfig.lua.

## 9곡

| 채널 | 제목 | soundId | length (파일 초, 설정값) | 안무 |
|---|---|---|---|---|
| K-POP | ATEEZ-BAD | 134942349436280 | 51 | |
| K-POP | 소녀시대-소원을 말해봐(Genie) | 128270208751659 | 76 | |
| K-POP | 현아-Bubble Pop | 76388700698178 | 71 | 11개 (버튼으로만, 자동 아님) |
| K-POP | RIIZE-Get A Guitar | 91762270038050 | 54 | 20개, 자동(autoChoreo) |
| K-POP | RIIZE-Love 119 | 119473981131981 | 58 | |
| K-POP | YENA-Catch Catch | 80583279340768 | 61 | |
| K-POP | Hearts2Hearts-Lemon Tang | 97032815457241 | 54 | |
| K-POP | aespa-Lemonade | 132067415333401 | 62 | |
| K-POP | IVE-Mirror | 139326796173276 | 67 | |

## 보정값 (lab, 9곡 모두 같음)

마지막 값 (D-735):

```lua
lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" }
```

- 업로드 파일은 빠르게 줄인 짧은 파일이에요. 클럽에서는 speed × tempo(0.335배)로 느리게 틀어 원래 빠르기로 들려요. 음 높이는 octave ÷ tempo로 되돌려요(`ClubConfig.labEffective`).
- 들리는 길이는 length ÷ 0.335예요. 예: Get A Guitar 53.55초 → 약 2분 40초.
- 바뀐 순서:
  - D-709: tempo 0.5, boost 1, low/mid/high 0
  - D-723: tempo 0.35, boost 2, low -6, mid 0.5, high -7
  - D-727: tempo 0.335
  - D-734: boost 4
  - D-735: boost 6

## 박자 (EDM 효과에 쓰던 원곡 BPM, D-733)

| 곡 | BPM | 출처 |
|---|---|---|
| ATEEZ-BAD | 124 | songbpm.com |
| RIIZE-Love 119 | 99 | ruwiki (Tunebat) |
| aespa-Lemonade | 128 | songbpm.com |
| 나머지 | 모름 (120으로 시작) | |

## 안무 animation id

현아-Bubble Pop (11개, 곡 처음부터 이어서):
```
100736920067826, 133384041896194, 83466816721074, 133279932519664, 106558407160210, 80189218624271,
74977996210534, 128213782788357, 133713883432071, 79851078896686, 85867632664929
```

RIIZE-Get A Guitar (20개, 순서대로; 처음 6개 D-726, 나머지 14개 D-728; 합계 약 162초):
```
119819611123433, 97097804325917, 119200924904137, 77403973851668, 73939357849033, 137390866303201,
121969021575883, 92148657532352, 96742563282745, 88430566939812, 108795638313983, 95813030011960, 135272998171625,
129447992418977, 82252722293006, 108611133102309, 117244778152210, 113505968174557, 112498417388469, 80874196383963
```

## EDM 버튼 임시 음원 (D-735 ~ D-738)

```lua
Track = {
	soundId = 91762270038050, -- RIIZE-Get A Guitar (temporary)
	lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" },
},
```

## 되돌릴 때 붙일 Lua (ClubConfig.Playlist)

```lua
ClubConfig.Playlist = {
	{ channel = "K-POP", title = "ATEEZ-BAD", soundId = 134942349436280, length = 51, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" } },
	{ channel = "K-POP", title = "소녀시대-소원을 말해봐(Genie)", soundId = 128270208751659, length = 76, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" } },
	{ channel = "K-POP", title = "현아-Bubble Pop", soundId = 76388700698178, length = 71, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" }, choreo = { 100736920067826, 133384041896194, 83466816721074, 133279932519664, 106558407160210, 80189218624271, 74977996210534, 128213782788357, 133713883432071, 79851078896686, 85867632664929 } },
	{ channel = "K-POP", title = "RIIZE-Get A Guitar", soundId = 91762270038050, length = 54, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" }, choreo = { 119819611123433, 97097804325917, 119200924904137, 77403973851668, 73939357849033, 137390866303201,
		121969021575883, 92148657532352, 96742563282745, 88430566939812, 108795638313983, 95813030011960, 135272998171625,
		129447992418977, 82252722293006, 108611133102309, 117244778152210, 113505968174557, 112498417388469, 80874196383963 }, autoChoreo = true },
	{ channel = "K-POP", title = "RIIZE-Love 119", soundId = 119473981131981, length = 58, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" } },
	{ channel = "K-POP", title = "YENA-Catch Catch", soundId = 80583279340768, length = 61, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" } },
	{ channel = "K-POP", title = "Hearts2Hearts-Lemon Tang", soundId = 97032815457241, length = 54, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" } },
	{ channel = "K-POP", title = "aespa-Lemonade", soundId = 132067415333401, length = 62, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" } },
	{ channel = "K-POP", title = "IVE-Mirror", soundId = 139326796173276, length = 67, lab = { speed = 1, tempo = 0.335, volume = 10, boost = 6, octave = 0.5, low = -6, mid = 0.5, high = -7, engine = "sound" } },
} :: {Track}
```

## 참고

- 보정값은 테스트 장소 "테스트"(86558282086977)의 턴테이블 실험실에서 귀로 맞췄어요(tools/test_places/turntable_lab, D-680).
- 이 곡들은 Roblox 라이선스 음악이 아니에요. 다시 쓰려면 권리를 먼저 확인해야 해요.

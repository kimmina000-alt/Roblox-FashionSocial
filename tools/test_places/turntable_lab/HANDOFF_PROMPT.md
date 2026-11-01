# 오후 클럽 음악에 턴테이블 랩 설정값 적용 — 작업 프롬프트

아래 "프롬프트" 블록을 새 Claude Code 세션(오후 작업)에 그대로 붙여 넣으세요.
처음 한 번은 1단계(코드 만들기)부터, 다음부터는 2단계(값만 반영)만 하면 됩니다.

## 프롬프트

```
오후 DJ 턴테이블(클럽 음악)이 곡을 틀 때, 테스트 장소의 "턴테이블 랩"에서 내가 귀로 맞춘
설정값 그대로 들리게 해 줘. 앞으로도 랩에서 값을 바꾸면 이 방식으로 오후에 반영할 거야.

## 랩이 뭔지
- 테스트 장소 "테스트" (placeId 86558282086977, Studio에 오후와 따로 열려 있음).
  코드: tools/test_places/turntable_lab/TurntableLab.client.lua (apply() / effective() 함수가 기준).
- 곡마다 저장된 값: 테스트 장소 DataStore "TurntableLabSettings", 키 "v1"
  = { ["<soundId>"] = { speed, tempo, volume, boost, octave, low, mid, high, humHz, hissHz, gate, engine } }.
  최신 값은 MCP로 테스트 장소(Edit 모드)에서 GetAsync("v1")로 읽어 와. 테스트 장소는 읽기만 하고 고치지 마.
- 랩은 2D Sound 하나로 재생해 (오후 ClubMusic도 2D Sound). 랩에서 들린 소리 = 오후 클럽 Hall 안,
  DJ 볼륨 x1, DJ 속도/음높이 x1 일 때 들리는 소리가 되게 맞추는 게 목표야.

## 랩 값의 뜻 (랩 apply() 그대로)
- 실제 PlaybackSpeed = min(speed × tempo, 20)
- 실제 템포 = 실제 PlaybackSpeed / speed
- PitchShift 옥타브 = clamp(octave ÷ 실제 템포, 1/32, 32). 효과 하나가 0.5~2라서
  0.5~2면 1개, 아니면 n = ceil(|log2 옥타브|)개(최대 5)에 옥타브^(1/n)씩 똑같이 나눠 걸어.
  옥타브가 1이면 효과는 꺼 (켜 두면 소리가 살짝 뭉개짐).
  (tempo는 Roblox에 없어서, 속도를 올리고 PitchShift로 음높이를 되돌리는 방식이야)
- Sound.Volume = volume (0~10), 그 위에 SoundGroup.Volume = boost (0~10) → 들리는 볼륨 = volume × boost (최대 100)
- EqualizerSoundEffect LowGain/MidGain/HighGain = low/mid/high (dB). 셋 다 0이면 꺼.
- engine = "sound" 이면 humHz / hissHz / gate(디노이즈)는 랩에서도 안 들렸던 값이니 무시해.
  engine = "audio"(AudioPlayer + AudioFilter Highpass24dB/Lowpass24dB + AudioGate) 곡이 생기면
  그때 나한테 먼저 물어봐 (오후 클럽은 지금 Sound만 써).

## 1단계: 오후 코드 (처음 한 번)
지금 오후 구조: ClubConfig.Playlist의 Track(baseSpeed / volume / octave),
ClubConfig.trackRate(서버 ClubService 시간 계산 + 클라 재생 속도),
DanceController.client.lua의 "Club music" 부분(ClubMusic Sound, DJPitch 효과 3개, TrackBoost EQ,
볼륨 = (track.volume 또는 MusicVolume) × DJ 볼륨 × 구역 레벨).
- Track에 `lab: {...}?` 필드를 추가해. lab이 있는 곡은 baseSpeed / volume / octave 대신 lab으로 계산해.
  - 속도: trackRate가 lab의 실제 PlaybackSpeed × DJ 속도를 돌려주게 (서버 곡 길이/시간 계산도 같이 맞게).
  - 음높이: lab 옥타브 × DJ 음높이. DJPitch 효과를 3개 → 5개로 (1/32~32), 나누는 방식은 위 규칙.
  - 볼륨: Sound.Volume = min(lab.volume × DJ 볼륨 × 구역 레벨, 10), boost는 ClubMusic 전용 SoundGroup.Volume으로.
    lab 곡에서는 기존 "10 넘으면 TrackBoost EQ로 dB 올리기"를 쓰지 마 (lab EQ와 섞이면 안 됨).
  - EQ: lab low/mid/high용 EqualizerSoundEffect를 따로 하나 두고, 곡이 바뀔 때마다 맞춰. lab 없는 곡은 꺼.
  - lab 없는 곡은 지금과 똑같이 동작해야 해.
- 고친 뒤 랩 곡 하나를 오후에서 틀어 PlaybackSpeed / PitchShift / Volume / SoundGroup / EQ 값이
  랩에서 같은 곡의 값과 똑같은지 숫자로 비교해서 보여 줘.

## 2단계: 값 반영 (매번)
- 테스트 장소 DataStore에서 최신 값을 읽어서, 같은 soundId 곡의 `lab = {...}`를 ClubConfig에 넣거나 바꿔.
  랩 화면 맨 아래 복사 칸도 같은 형식(`lab = { speed = .., ..., engine = "sound" },`)이라 내가 붙여 줄 수도 있어.
- lab 곡의 baseSpeed / volume / octave 옛 값은 지워 (lab이 대신함). length(초, x1 기준)는 그대로 둬.
- 오후 플레이리스트에 없는 soundId는 마음대로 추가하지 말고, 곡 이름과 함께 추가할지 나한테 물어봐.
- 반영한 곡 목록과 값을 표로 보여 줘.

## 진행 규칙
- CLAUDE.md / AGENTS.md 따르기: catalog-ui-redesign에서 새 브랜치, 테스트는 모바일 2P,
  내 승인 후 머지, DECISIONS / WORKLOG에 기록, 보고는 한국어.
- Studio 작업은 오후 장소(placeId 89906407011275)에서만. 테스트 장소는 읽기만.
```

## 2026-11-01 기준 저장된 값 (참고용 스냅숏)

DataStore에서 읽은 그대로입니다. 오후 세션은 위 프롬프트대로 DataStore에서 최신 값을 다시 읽습니다.

| 곡 | soundId | lab 값 |
|---|---|---|
| SAN FRANCISCO · DOM DOLLA | 113497657842744 | 공통 A |
| TANI TANI · TANI | 131058655527940 | 공통 A |
| LOVE ATTACK · RESCENE | 103905057186427 | 공통 A |
| GRIT X DIET COKE | 106119256110919 | 공통 A |
| CASH OUT | 140111630417316 | 공통 A |
| MY MIND | 106804146862342 | 공통 A |
| PLAIN JANE · A$AP FERG | 78832462526893 | 공통 A |
| PUMP IT UP | 125479000346000 | 공통 A |
| 404 (New Era) · KiiiKiii | 74181572220193 | 공통 A |
| LOVE LOVE LOVE · EPIC HIGH | 100033043291152 | `lab = { speed = 1, tempo = 0.5, volume = 2.3, boost = 1, octave = 1, low = -6, mid = 4, high = 2, engine = "sound" },` |
| BANG BANG · IVE | 126421508146335 | `lab = { speed = 1, tempo = 2, volume = 10, boost = 2.5, octave = 1, low = 0, mid = 0, high = 0, engine = "sound" },` |
| Love 119 / RIIZE (오후 플레이리스트에 없음) | 106367625479063 | `lab = { speed = 0.5, tempo = 0.65, volume = 10, boost = 2.5, octave = 1, low = 0, mid = 10, high = 10, engine = "sound" },` |

공통 A = `lab = { speed = 1, tempo = 0.5, volume = 2.2, boost = 1, octave = 1, low = 3, mid = 0, high = -24.5, engine = "sound" },`

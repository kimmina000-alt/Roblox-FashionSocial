# 이어 붙인 곡 (Joined songs) — 오후로 넘기는 정보

2026-11-03, 턴테이블 랩(테스트 장소 86558282086977)에서 만들고 확인함.

**권리가 있고, Roblox 업로드 길이 제한(7분)보다 긴 음원에만 써요** (긴 DJ 믹스, 긴 녹음 등). 7분보다 짧은 곡은 한 파일 그대로 올려요. 짧은 곡을 잘라 올리면 Roblox 저작권 검사가 원곡을 못 알아보게 되는 것 말고는 효과가 없어서, 그 용도로는 쓰지 않아요 (나누기 도구도 7분 이하 파일은 거부해요). 첫 테스트 '녹음본'(3:45)은 기능 확인용이었고 최종 묶음은 만들지 않아요.

## 무엇인가요
노래 하나를 30초 구간 여러 개로 나눠 올리고, 게임에서 다시 **한 곡처럼** 이어서 틀어요.
- 구간 n = 원본의 (n−1)×30초부터 30초 + **다음 구간 앞부분 4초**(꼬리)
- 플레이어 두 개(`Sound`)를 번갈아 써요. 구간 끝 2초 전에 다음 구간을 `4 − 2 + 0.05`초 지점부터 틀고, 2초 동안 직선으로 볼륨을 넘겨요. 겹치는 부분이 같은 소리라서 이음매가 맞물려요.
- 랩 측정(8구간, 원본 225.05초): 이어서 재생한 길이 225.16초, 이음매 7곳 모두 0.07초 이내로 맞물림.

## 파일
| 파일 | 하는 일 |
|---|---|
| `tools/audio/split_for_crossfade.ps1` | 음원 파일 → `1.mp3, 2.mp3, …`, `구간표.txt`, `song.lua`(붙여 넣을 줄, ID 자리는 0) |
| `tools/test_places/turntable_lab/JoinedSongPlayer.lua` | 이어 붙여 트는 모듈 (랩과 오후가 같은 파일) |
| `tools/test_places/turntable_lab/TurntableLab.client.lua` | 랩: 목록에서 한 곡으로 보이고, 전체 시간 표시 · 시간 바 이동 · 랩 값 적용 |

## 새 곡 만드는 순서
1. 음원 파일을 준다.
2. 나누기:
   ```powershell
   .\tools\audio\split_for_crossfade.ps1 -InputFile "<파일>" -Title "<노래 제목>"
   ```
   → `D:\Roblox\음원\<노래 제목>` 폴더에 `1.mp3 …`, `구간표.txt`, `song.lua`가 생김 (사용자 2026-11-03).
3. `1.mp3`부터 **순서대로** Roblox에 올림 (Vantablack_Dev 계정).
4. 음원 ID를 순서대로 `song.lua`의 `parts = { … }`에 넣음:
   ```lua
   { title = "노래 제목", joined = { parts = { id1, id2, id3, … }, segLen = 30, tail = 4, total = 225.05 } },
   ```
5. 랩: 이 줄을 `TurntableLab.client.lua`의 `TRACKS` 끝에 넣고 테스트 장소에 반영 → 목록에서 한 곡으로 들어 봄 (기본 볼륨 10, 💾로 랩 값 저장 가능; 저장 키 = 첫 구간 ID).
6. **길이 맞추기 (꼭 함)**: 랩에서 그 곡을 처음부터 끝까지 틀어 실제 길이를 재고, `구간표.txt`의 원본 길이(`total`)와 비교해요.
   - 차이 d = 잰 길이 − 원본 길이. |d| ≤ 0.05초면 끝.
   - 아니면 `lead = (지금 lead, 기본 0.05) + d ÷ (구간 수 − 1)` 로 곡 줄에 `lead = …`를 넣고 다시 반영해서 한 번 더 잼.
   - 예: 녹음본(8구간) 225.33초 / 원본 225.05초 → d = +0.28 → lead = 0.05 + 0.28 ÷ 7 = 0.09.
   - 재는 방법: Play에서 아래를 Client로 실행 → 그 곡을 처음부터 재생 → 다 끝나면 `SoundService:GetAttribute("JLog")` 읽기 (곡 길이만큼 기다려요).
     ```lua
     local SS = game:GetService("SoundService")
     local firstId = "<첫 구간 ID>"
     SS:SetAttribute("JLog", "")
     task.spawn(function()
       local js = SS:WaitForChild("JoinedSong")
       local tStart, tEnd, idle = nil, nil, 0
       local deadline = os.clock() + 900
       while os.clock() < deadline do
         local playing = {}
         for _, c in ipairs(js:GetChildren()) do if c:IsA("Sound") and c.IsPlaying then table.insert(playing, c) end end
         if not tStart then
           for _, c in ipairs(playing) do if c.SoundId:match("%d+$") == firstId and c.TimePosition < 1 then tStart = os.clock() - c.TimePosition end end
         elseif #playing == 0 then
           idle += 0.05
           if idle > 0.5 then tEnd = os.clock() - 0.5 break end
         else idle = 0 end
         task.wait(0.05)
       end
       SS:SetAttribute("JLog", string.format("total %.2f", (tStart and tEnd) and (tEnd - tStart) or -1))
     end)
     ```
7. **최종 묶음**: 맞춘 곡 줄(ID, total, lead, 랩 값)을 사용자에게 한 덩어리로 줌:
   ```lua
   { title = "…", joined = { parts = { … }, segLen = 30, tail = 4, total = …, lead = … }, lab = { … } },
   ```

## 모듈 쓰는 법
```lua
local JoinedSongPlayer = require(ReplicatedStorage.JoinedSongPlayer)
local player = JoinedSongPlayer.new(script)          -- Sound를 둘 곳
player:Load({ title = "…", joined = { parts = {…}, segLen = 30, tail = 4, total = 225.05 },
              lab = { speed = 1, tempo = 1, volume = 10, boost = 1, octave = 1, low = 0, mid = 0, high = 0 } })
player:Play(0)                 -- 곡 기준 초(x1 시간)부터; 건너뛸 때도 Play(초)
player:SetLevel(0.45)          -- 구역 음량 · DJ 볼륨 같은 추가 배율 (0..1+)
player:SetLab(lab)             -- 재생 중 소리 값 바꾸기
player:GetTime(), player:GetLength(), player:IsPlaying(), player:GetPart()
player:Pause() / player:Resume() / player:Stop()
player.Ended = function() end  -- 마지막 구간이 끝나면
player:Destroy()
```
- 여럿이 같이 듣는 곳(클럽)은 서버 시계로 맞춰요: `player:Play((GetServerTimeNow() − 시작 시각) × 실제 재생 속도)`. 실제 재생 속도 = `lab.speed × lab.tempo`.
- `lab`이 없으면 x1, 볼륨 10.

## 오후 세션에 붙여 넣을 프롬프트
```
오후 클럽 음악이 "이어 붙인 곡"도 틀 수 있게 해 줘. 노래 제목과 구간 ID만 넣으면 되게.
권리가 있는 음원(직접 녹음 · 제작 · 허락받은 곡)에만 쓰는 기능이야.

기준 코드 (턴테이블 랩에서 만들고 확인함):
- tools/test_places/turntable_lab/JoinedSongPlayer.lua — 이 모듈을 그대로
  src/ReplicatedStorage/FashionGame/Shared/JoinedSongPlayer.lua 로 가져와 (고치지 말고, 고칠 게 있으면 나한테 먼저 말해).
- 설명: tools/test_places/turntable_lab/JOINED_SONGS_HANDOFF.md

할 일:
1. ClubConfig.Track에 `joined: { parts: {number}, segLen: number, tail: number, total: number }?` 를 추가해.
   joined 곡은 soundId 대신 parts를 쓰고, length = joined.total 로 계산해 (서버의 곡 길이·끝 시간 계산, trackRate 그대로).
2. DanceController의 클럽 음악(ClubMusic Sound): 지금 곡이 joined면 ClubMusic 대신 JoinedSongPlayer로 틀어.
   - 위치 맞추기: syncMusic의 `(GetServerTimeNow() − ClubTrackStart) × speed` 를 player:Play(...)에 넣어.
   - 일시정지(ClubMusicPaused / PausedAt), DJ 속도·음높이는 player:SetLab(곡 lab에 DJ 값을 곱한 값)으로.
   - 음량: 지금 계산한 want(곡 볼륨 × DJ 볼륨 × 구역 레벨)를 lab.volume × player:SetLevel(...)로 나눠 넣어. 10 넘는 부분은 lab.boost.
   - 비트 조명은 PlaybackLoudness를 쓰니까, joined 곡일 때는 지금 재생 중인 구간 Sound(player.decks[player.cur].snd)에서 읽어.
   - 곡이 바뀌면 player:Stop(), joined가 아닌 곡은 지금처럼 ClubMusic.
3. ClubConfig.Playlist에 내가 주는 곡 줄을 넣어:
   { channel = "…", title = "노래 제목", joined = { parts = { … }, segLen = 30, tail = 4, total = … }, lab = { … } },
4. 모바일 2P 테스트: joined 곡 처음부터 끝까지, DJ 일시정지/속도, 늦게 들어온 사람의 위치 맞춤, 다음 곡 넘어감.
진행 규칙은 CLAUDE.md대로 (catalog-ui-redesign에서 새 브랜치, 승인 후 머지, 한국어 보고).
```

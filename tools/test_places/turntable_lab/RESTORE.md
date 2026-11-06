# 턴테이블 랩 복구 방법 (테스트 place 86558282086977)

2026-11-06: Studio가 멈췄을 때 저장 안 된 테스트 place를 되살리는 방법이에요.

## 어디에 무엇이 남아 있나요
- **스크립트**: 이 폴더의 파일이 Studio 스크립트와 같아요 (2026-11-06 마지막 작업까지, git에 커밋됨).
  - `TurntableLab.client.lua` → `StarterPlayer.StarterPlayerScripts.TurntableLab` (LocalScript). 곡 목록 TRACKS, 부스트 2 슬라이더 포함.
  - `TurntableLabStore.server.lua` → `ServerScriptService.TurntableLabStore` (Script). 저장 키에 boost2 포함.
  - `JoinedSongPlayer.lua` → 이어 붙인 곡 재생 ModuleScript (TurntableLab이 require하는 위치에 둬요).
  - `build_lab.lua` → DJ 콘솔 무대를 다시 만들어요 (Edit 모드 명령줄에서 실행).
- **곡별 설정값** (템포, 볼륨, 부스트, 부스트 2, 옥타브, EQ …): Studio 파일이 아니라 Roblox 클라우드의 DataStore
  `TurntableLabSettings` / 키 `v1`에 있어요. Studio가 꺼지거나 place가 저장되지 않아도 **사라지지 않아요**.
  Play를 시작하면 그대로 다시 불러와요 (게임 설정 → 보안 → Studio API 접근 켜기가 필요해요).
- 오후로 넘긴 값은 `src/ReplicatedStorage/FashionGame/Shared/ClubPlaylist.lua`와 `docs/04_ART/CLUB_PLAYLIST.md`에도 있어요.

## 복구 순서
1. 테스트 place(86558282086977)를 열어요. 클라우드에 마지막으로 저장된 버전이 열려요.
2. 스크립트 길이를 이 폴더 파일과 비교해요. 다르면 Edit 모드에서 위 파일 내용으로 바꿔요
   (Claude에게 "랩 스크립트 복구해"라고 하면 multi_edit로 넣어요).
3. 무대가 없으면 `build_lab.lua`를 실행해요.
4. Play → 곡 목록과 저장값이 돌아왔는지 확인 → Ctrl+S.

## 아직 로드되지 않는 곡 (Roblox 검토 대기)
- 소원2 100752194799727 (곡 길이 3:48)
- 잠자기전 83921467202322

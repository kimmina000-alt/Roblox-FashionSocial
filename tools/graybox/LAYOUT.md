# 건물 위치 직접 조정하기 (2026-10-22)

## 무엇을 옮길 수 있나
- `Workspace > Graybox_MainSocial` 안의 **구역(모델) 하나 전체**: 예) `02_Club`(클럽 건물 전체), `07_Hanok_Village`(한옥 마을 전체).
- 구역 안의 **모델 하나하나**: 건물·나무·놀이기구·파라솔 묶음 등. 예) `07_Hanok_Village > Hanok_A`, `OHU_HanokCafe`, `CherryTree`, `04_Beach_Aquarium > BeachCafe`, `IceCreamTruck`, `06_Park_Playground > FerrisWheel`.
- 낱개 파트(바닥 판, 담장 조각 등)는 구역을 통째로 옮길 때 같이 움직인다.

## 방법 (Studio)
1. 탐색기에서 모델을 클릭 (뷰포트에서 클릭하면 파트 하나만 잡힐 수 있으니 **탐색기에서 모델 선택** 권장).
2. 이동(Ctrl+2)·회전(Ctrl+4) 도구로 옮긴다. 회전은 Y축만 권장.
3. **Ctrl+S** 저장.

## 맵 스크립트로 다시 지어도 유지되나? → 예
- 지을 때 각 모델에 처음 위치(`BuiltPivot`)를 적어 둔다.
- 스크립트가 구역을 다시 지을 때, 지우기 전에 "처음 위치에서 얼마나 옮겼는지"를 읽어 **새로 지은 모델에 같은 이동을 다시 적용**한다.
- 미끄럼틀 경로, 튜브 기준점, 클럽 출구 같은 위치값(Vector3 속성)도 같이 옮겨진다.
- GitHub에도 남기려면: Studio 명령줄에서 `tools/graybox/export_layout.lua`를 실행 → 출력된 줄을 `build_main_social_graybox.lua`의 `LAYOUT_MOVES`에 붙인다 (Claude에게 "배치 저장해"라고 하면 대신 해 줌).

## 주의 (아직 위치를 따라가지 않는 것)
- **지하 클럽(02_Club)**: 땅(00_Ground)에 클럽 자리 구멍이 고정 좌표로 뚫려 있다. 클럽을 옮기면 구멍도 옮겨야 함 → 옮긴 뒤 Claude에게 알려 주면 땅을 다시 자름.
- 클럽 옥상 엘리베이터(GrayboxElevator) 도착 좌표, 🏠 스폰 위치(SpawnLocation)는 따로.
- 같은 이름 모델이 여러 개면(벚나무 등) 순서 번호로 구분한다. 스크립트에서 개수를 바꾸면 번호가 밀릴 수 있다.

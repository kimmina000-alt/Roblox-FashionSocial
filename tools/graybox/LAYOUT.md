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

## 소품 손으로 고치기 (D-105, 2026-10-22)
나무·관목·풀·화단·차·가로등·전봇대·신호등·버스 정류장은 하나씩 선택해서 옮기거나 지울 수 있다.
1. Studio(Edit 모드)에서 클릭하면 그 소품 하나가 선택된다(`Hongdae_Layout`, `StreetDress`는 폴더). 옮기거나(이동·회전) Delete로 지운다.
2. 끝나면 Claude에게 "저장해" → `tools/graybox/prop_save.lua`를 실행해 바뀐 것만 `ServerStorage.PropOverrides`에 기록하고, 같은 내용을 `tools/graybox/prop_overrides.json`(git)에 남긴다.
3. 이후 `build_hongdae_layout.lua` / `street_dress.lua`를 다시 돌려도 기록이 다시 적용된다.
- 각 소품의 이름표: 속성 `PropId`(예: `Tree@84,26` = 종류@처음 만들어진 x,z), `PropBase`(스크립트가 둔 위치).
- 되돌리기: `prop_save.lua`에 `"restore Tree@84,26"`(하나) 또는 `"clear"`(전부) → 스트리트 스크립트 다시 실행.
- 주의: 도로·인도·건물 같은 큰 구조는 기록되지 않는다(스크립트에서 바꾼다). 배치 스크립트가 소품의 원래 위치를 바꾸면(예: 도로를 옮기면) 그 소품의 이름표도 바뀌어 예전 기록이 맞지 않을 수 있다.
## 정식 맵 빌드 순서 (2026-10-23, D-111)
배치 v7c가 정식 맵이다. Studio Edit 모드에서 차례로 실행:
1. `build_main_social_graybox.lua` — 구역(클럽·한옥·해변·공원·카페 등) 생성. 각 구역에 BuiltPivot 저장.
2. `build_hongdae_layout.lua` (MODE `apply` / `revert`) — 강남 사거리 도로·인도·화단·자전거 도로, 지하철 출구·버스 정류장, 광안리 해변도로·계단, 광화문, 놀이공원 정문, 편의점, 구역 위치 이동(MOVES), 이동 경계(투명 벽)와 경계 밖 전경(한옥 담 연장, 가건물, 이어지는 해변). Workspace.Hongdae_Layout.
3. `street_dress.lua` (MODE `apply` / `revert`) — 실사 에셋(ServerStorage.ArtAssets): 아스팔트·보도블록 재질, 연석, 가로등, 신호등, 빌딩 외벽.
3-1. `build_gukbap.lua` — 클럽 북쪽 첫 필지의 국밥집(Workspace.Hongdae_Layout.Gukbap, D-314). 그 자리 가건물이 있으면 지우고, 그 필지만 이동 경계를 x 78까지 밀어요. 여러 번 실행해도 결과가 같아요(2단계를 다시 돌린 뒤에는 꼭 다시 실행).
4. 손 편집 기록(`ServerStorage.PropOverrides`, git `prop_overrides.json`)은 2·3단계에서 자동 적용. 다시 빌드하기 전에 항상 `prop_save.lua`로 먼저 저장.
- 필요한 Studio 자산: ServerStorage.ArtAssets(나무·관목·야자수·가로등·신호등 등, 스크립트 제거됨), ServerStorage.Cars(G70·G80), MaterialService(OHU_Asphalt, OHU_Concrete). 장소 파일에만 있으므로 Studio 저장 필수.
- 예전 이름: hongdae_v1_temp.lua / Workspace.Hongdae_v1_Temp (임시 단계). 새 스크립트의 revert가 예전 폴더도 지운다.
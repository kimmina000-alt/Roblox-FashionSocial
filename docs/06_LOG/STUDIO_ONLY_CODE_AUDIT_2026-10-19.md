# Studio-only code audit — 2026-10-19

## 왜 이 문서가 있나
Roblox Studio에 열려 있던 코드가 GitHub `catalog-ui-redesign`과 달랐다. 이전 작업 흐름(ChatGPT가 수정 → GitHub Desktop pull → Studio 실행)에서 Studio에만 반영되고 push되지 않은 변경이 있었다.
Studio MCP로 실제 스크립트를 읽어 그대로 복원했고, 6개 파일 모두 바이트 길이와 djb2 해시가 Studio와 일치하는 것을 확인했다.

- 백업 브랜치: `backup/studio-2026-10-19` (commit `62c17a3`)
- **참고용이다. 이 상태 그대로 머지하지 않는다.** 아래 충돌 항목을 결정에 맞게 고친 뒤 필요한 부분만 가져온다.

## Studio에만 있던 파일/변경
| 파일 | 상태 | 내용 |
|---|---|---|
| `CatalogController.client.lua` | 수정 (2222줄) | UI 스케일 1.5, 투명도 0.2, previewFrame을 mainFrame에 부착, "옷장" 버튼, 원형 화살표, 스크롤바 숨김, FashionData remote·AppearanceCodec require, browse 모드 forward local 선언(구현 없음). 823줄 이후는 GitHub와 동일 → **1392 버그 그대로 존재** |
| `CatalogConfig.lua` | 수정 | BundleTypes BodyParts/DynamicHead/Shoes + IncludeOffSale, PopularSorts, SortAggregationOptions |
| `ServerMain.server.lua` | 수정 | FashionData RemoteFunction, TryOnItem "Edit" 액션, ApplyOutfit / SaveCurrentOutfit, PlayerRemoving |
| `Services/AvatarService.lua` | 수정 | AppearanceCodec 연동, 액세서리 transform 보존, Serialize/ApplyAppearance, SetAccessoryTransform/Reset, SetBodyScales/Colors, SetLayerOrder/MakeupOrder, SwitchRig, HandleEdit |
| `Services/PlayerDataService.lua` | 신규 | DataStore `FashionGame_PlayerData_v1`, outfits/favorites/recents |
| `Shared/AppearanceCodec.lua` | 신규 | HumanoidDescription 직렬화/역직렬화 (scale, color, classic, animation, accessory transform, makeup, emote) |
| `Remotes/FashionData.model.json` | 신규 | RemoteFunction |

## 결정과 충돌하는 부분 (머지 전에 반드시 수정)
| # | Studio 코드 | 결정 문서 | 처리 |
|---|---|---|---|
| 1 | `MAX_OUTFITS = 10` | D-019: **50개** | 50으로 변경 |
| 2 | recents를 DataStore에 저장 (`MAX_RECENTS=40`, `viewedAt`) | D-020/D-023: 세션 한정, 재접속 시 초기화, "착용 성공" 기준 | 서버 저장 제거, 클라이언트 세션 목록으로 |
| 3 | `SwitchRig` (R6/R15 전환, player.Character 교체) 노출 | R6/R15 전환은 범위 밖(보류) | 제거 또는 비활성 |
| 4 | Transform scale 최소 0.05, 위치/회전 범위 없음 | GetAvatarRules 범위 + ConformToAvatarRules 사용 | 규칙 기반 clamp로 교체 |
| 5 | `SetAsync` 사용 | 저장은 UpdateAsync + 실패 원인별 처리 | UpdateAsync로 |
| 6 | 1392 forward-reference 버그 | Catalog P0 | 먼저 수정 |
| 7 | 편집기는 라이브 캐릭터에 직접 적용 | D-024: 클라이언트 프리뷰 → 서버 프리뷰 → KOYA 방식 순 | Studio 테스트로 방식 확정 후 연결 |
| 8 | Wardrobe/Editor 클라이언트 UI 없음 (서버 API만) | Stage 1.5 / 2 | UI는 새로 구현 |

## 쓸 만한 부분
- AppearanceCodec 직렬화 구조 (transform, makeup, emote 포함) — SavedOutfits 스냅샷 형식의 출발점으로 사용 가능.
- ApplyAppearance의 부분 복원(실패 ID 목록 반환) — 문서의 per-item partial restore와 방향이 같다.
- CatalogConfig의 BundleTypes/PopularSorts 추가, UI 스케일·레이아웃 개선.

## 새 작업 방식 (2026-10-19부터)
1. Claude가 로컬 repo에서 코드 수정
2. 사용자가 GitHub Desktop pull 후 `rojo serve catalog-ui-redesign.project.json` 실행 (Rojo는 `src/`만 매핑)
3. Claude가 Studio MCP로 실행·테스트·콘솔 확인
4. 사용자 확인/승인 후 push
- Studio에서 직접 수정한 코드는 Rojo가 덮어쓴다. Studio 전용 변경은 만들지 않는다.
- `backup/studio-2026-10-19`는 삭제하지 않는다.

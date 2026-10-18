# Avatar State and Persistence Contract

기준 브랜치: catalog-ui-redesign  
상태: **설계 기준 / 구현 완료를 의미하지 않음**  
범위: Catalog, Wearing, Current Outfit, Avatar Editor, Wardrobe/Outfit, respawn, persistent player data

## 1. 단일 원본 원칙

**현재 실제 아바타(Current Avatar)의 원본은 서버가 관리하고, 서버가 적용·확인한 현재 캐릭터의 Humanoid:GetAppliedDescription()을 외형 검증의 기준으로 삼는다.** 클라이언트의 currentWornItems, wornOrder, viewedOrder 및 UI 카드 상태는 독립적인 원본이 아니라 표시용 캐시/세션 메타데이터다.

- Catalog에서 착용/해제 성공을 보고하기 전, 서버는 실제 캐릭터에 적용한 뒤 적용 결과를 읽어 확인한다.
- 클라이언트는 요청을 보낸 순간 WORN 상태를 확정하지 않는다. 작업 중이면 가능할 때 "입는 중…" / "해제 중…" 상태를 보여 주고 관련 버튼을 비활성화한다.
- 성공 응답에는 가능한 한 적용 결과에서 재구성한 현재 외형 요약과 revision/request ID를 포함한다. 클라이언트는 응답을 받은 뒤 캐시와 카드를 교체한다.
- 실패하면 UI의 확정 상태를 바꾸지 않고 오류 문구를 표시한다. 로컬 예측 상태를 실제 상태처럼 남기지 않는다.
- 카탈로그를 다시 열거나, 서버 응답이 누락/순서 역전된 것으로 의심되거나, 캐릭터가 재생성되면 서버의 Current Avatar snapshot을 다시 요청한다.
- Wearing 목록과 Current Outfit 가로 목록은 동일한 snapshot에서 파생된다. 표현 방식만 다르며 별도의 착용 상태를 소유하지 않는다.

## 2. GetAppliedDescription()의 의미와 복구 기준

Roblox 공식 API의 Humanoid:GetAppliedDescription()은 해당 Humanoid에 현재 적용된 외형을 설명하는 **복사본인 HumanoidDescription**을 반환한다. 액세서리, 클래식 의상, 몸체 파츠, 체형 스케일, 신체 색상, 애니메이션 등 그 API가 표현하는 외형 값을 읽을 수 있다. 이것은 서버가 별도로 유지하는 UI 목록이 아니라 실제 적용 외형을 확인하는 방법이다.

복구 우선순위:
1. 현재 Character/Humanoid가 준비됐는지 확인한다.
2. 서버에서 GetAppliedDescription()으로 적용된 외형을 읽는다.
3. 해당 description에서 지원되는 아이템과 외형 속성을 정규화해 Current Avatar snapshot을 만든다.
4. 클라이언트 캐시를 이 snapshot으로 다시 만든다.
5. description으로 표현되지 않는 게임 전용 상태(예: 지원 API로 적용되지 않은 항목)는 성공으로 간주하지 않는다. 별도 상태가 필요하면 그 기능의 실제 적용/복구 API를 검증한 뒤 별도 타입으로 모델링한다.

서버가 별도 목록을 유지하더라도 그것은 명령/캐시 목적일 뿐, 실제 적용 결과와 충돌하면 실제 적용 description을 우선한다. 차이를 로그로 남기고 snapshot을 재구축한다. 다만 Roblox API에 표현되지 않는 메타데이터를 description만으로 복구할 수 있다고 가정하지 않는다.

## 3. Typed identity: ID 하나만으로 식별하지 않기

아이템 식별 키는 최소한 itemType + itemId다. 동일한 숫자 ID가 서로 다른 도메인에서 쓰일 수 있으므로 숫자 ID만으로 비교/삭제/즐겨찾기를 하지 않는다.

    CatalogItemRef {
      itemType: "Asset" | "Bundle" | "GameDefined",
      itemId: number,
      assetTypeId?: number,
      bundleType?: string | number,
      category?: string,
      isLayered?: boolean,
      accessoryType?: string,
      source?: "Catalog" | "CurrentAvatar" | "SavedOutfit"
    }

- Roblox 카탈로그 검색 결과는 반환된 Asset/Bundle 유형과 해당 타입 ID를 함께 보존한다.
- 현재 외형의 rigid/layered accessories는 HumanoidDescription:GetAccessories(true)에서 AssetId, AccessoryType, IsLayered, Order 등을 읽는다.
- 클래식 Shirt/Pants/TShirt, body parts/scales/colors, animation properties, emotes, makeup은 동일한 accessory record로 뭉개지 않는다. 유형별 adapter가 현재 description에서 읽고 쓸 수 있는 범위를 명시한다.
- Bundle은 카탈로그에서 하나의 검색/표시 단위일 수 있지만, 이것만으로 Bundle ID를 HumanoidDescription의 개별 착용 항목처럼 적용할 수 있다는 뜻은 아니다. 적용할 수 있는 실제 asset IDs/구성 요소를 확인해야 한다.
- 중복 허용 여부는 타입별 정책으로 정한다. 리스트의 동일 항목 판정은 typed key를 사용한다. layered order는 identity와 별도 속성이다.

## 4. Avatar Editor: draft / Apply / Cancel

- Avatar Editor는 현재 내 아바타를 편집한다. 변경은 편집 draft에 모으고, 실제 아바타/서버 Current Avatar에 확정하는 것은 Apply 요청이 성공한 뒤다.
- 값 변경이 없으면 Apply/변경 취소 확인 UI를 노출하지 않는다.
- 변경값이 있을 때 Apply와 Cancel을 표시한다. 창 닫기/다른 기능 진입 시 변경값이 남아 있으면 "Apply할까요?" 확인을 띄운다.
- Apply: draft 전체를 서버에 보내 검증·적용하고, 서버가 실제 적용 결과를 확인한 후 성공 응답을 준다. 성공하면 draft baseline을 갱신한다.
- Cancel/Apply하지 않고 닫기: draft를 버리고 마지막 server-confirmed baseline으로 돌아간다.
- Reset: 현재 선택된 항목만 해당 항목의 편집 시작값/기본값으로 되돌린다. 카테고리 전체를 초기화하지 않는다.
- Outfit restore 또는 Character 재생성 전에 미적용 draft가 있으면 draft를 폐기한다. 저장/복원되는 것은 Apply가 완료된 외형뿐이다.
- 편집 도중 respawn이 발생하면 서버에서 새 캐릭터의 현재 description을 읽어 baseline으로 설정하고, 이전 draft를 자동 적용하지 않는다. 사용자에게 draft가 취소되었음을 알린다.

## 5. Outfit/Wardrobe contract

- Outfit은 **이 게임 안에서만 저장/사용되는 코디**다. Roblox 계정의 플랫폼 Outfit 저장, Roblox-owned inventory, 구매/소유권 변경을 호출하거나 의미하지 않는다.
- 저장 시 서버가 확인한 Current Avatar의 지원 가능한 외형 snapshot을 versioned Outfit record로 저장한다. 단순 아이템 ID 목록만으로 충분하지 않다.
- Outfit restore는 저장된 지원 속성을 현재 외형에 대체 적용한다. 저장에 없는 착용 항목을 그대로 덧붙이는 방식이 아니다.
- restore 성공 후 Current Avatar snapshot을 다시 읽어 Wearing, Current Outfit, Catalog 카드 상태와 Avatar Editor baseline을 모두 갱신한다.
- restore 시작 시 새로운 wear/remove/editor Apply 요청은 **대기열에 쌓지 않고 첫 요청 우선(first request wins) 정책으로 거절/비활성화**한다. UI에서 진행 중임을 표시하고 완료/실패 후 다시 허용한다. 이 방식은 오래된 요청의 순서 역전, stale draft, 부분 중첩 적용을 줄인다.
- restore 중 각 항목 적용이 독립적으로 가능하고, 실패 항목을 식별할 수 있을 때는 유효 항목만 적용하고 부분 성공 결과를 보여준다. description 전체 적용이 실패해 결과를 신뢰할 수 없으면 저장 전 baseline description을 한 번 복구 시도하고, 복구 결과를 확인한다. 복구도 실패하면 "복원 중 오류가 발생했습니다. 현재 아바타를 다시 불러와 확인해 주세요."를 표시하고 새 snapshot을 조회한다.
- Outfit thumbnail은 이미지 캡처를 영구 저장한다고 가정하지 않는다. 저장된 Outfit data로 별도 미리보기 모델을 렌더링한다. 미리보기 생성 실패는 Outfit 데이터 저장/복원 성공 여부와 분리해 표시한다.

## 6. Character lifecycle and rig policy

- 플레이어의 리스폰은 Roblox 기본 아바타로 돌아가는 동작이다. 게임 내 Current Outfit은 세션 동안 유지될 수 있지만, 리스폰 후에는 플레이어의 기본 Roblox 아바타로 다시 시작한다. 리스폰 전의 임시 착장은 자동 재적용하지 않는다.
- Avatar Editor draft는 리스폰 시 취소한다. Saved Outfit은 저장 데이터에 그대로 남아 Wardrobe에서 다시 선택할 수 있다.
- R6/R15 전환은 현재 단계에서 Avatar Editor 내부의 개인 토글로 구현하지 않는다. 게임 전체의 캐릭터 정책을 바꾸는 별도 시스템 변경으로 취급한다.
- Rig policy 변경 전에는 Experience Avatar Settings, Studio/game settings, Main Social과 Runway Place 설정, layered clothing/rigid accessories, animations, camera, spawn/respawn을 함께 조사한다. 전환을 위한 안전한 플랫폼 경로와 지원 범위가 확인되기 전에는 UI 전환 기능을 노출하지 않는다.
- 게임 전체 정책 변경은 기존/신규 캐릭터, 모든 Place, 현재 Outfit 복구 및 회귀 테스트 계획과 함께 승인된 변경으로만 진행한다.

## 7. Request concurrency and UI feedback

- 동일 플레이어에 대해 외형을 바꾸는 작업은 서버의 단일 per-player action gate를 공유한다: wear, remove, Avatar Editor Apply, Outfit restore, rig/character appearance operation.
- 먼저 들어온 요청만 실행한다. 작업 중 후속 요청은 queue에 저장하지 않고 "다른 아바타 작업이 진행 중입니다."로 거절한다. 클라이언트는 관련 버튼을 비활성화해 중복 클릭을 줄인다.
- 서버는 각 요청을 validate하고 결과를 반환한다. 클라이언트의 로딩 표시만으로 성공을 추정하지 않는다.
- 작업 실패 시 실패 문구를 표시하고 실제 Current Avatar snapshot을 다시 읽는다.
- 버튼/카드/키보드/모바일 터치 입력은 동일한 request gate와 typed identity를 사용한다.

## 8. Persistence ownership

| Data | Lifetime | Store | Policy |
|---|---|---|---|
| Current Avatar / Wearing | Current character/session; reconstructed from applied description | Server runtime state + current Humanoid description | Not a second independent persistent item list |
| Recent | Current session only | Client/server session memory; cleared on leave | Only items the player actually wore, not search history |
| Favorites | Across sessions | Server DataStore per user | Typed item identity; toggle is idempotent and validated |
| Saved Outfits | Across sessions | Server DataStore per user | Up to 50 outfits per user; versioned restorable snapshots |
| Avatar Editor draft | Until Apply/Cancel/close/respawn | Client draft, server validates Apply | Never auto-saved; only applied state can be saved into Outfit |

### Saved Outfit limit and partial restore decision — 2026-10-18

- SavedOutfits has an initial product limit of **50 records per user**. This is an application policy, not a Roblox platform recommendation.
- Outfit names may repeat; each record must have a unique outfitId.
- If one or more saved entries are unsupported, deleted, unavailable or rejected, skip only those entries and apply the remaining valid appearance. Identify skipped items where possible.
- A partial restore must not delete, mutate or silently replace the original SavedOutfit. Only explicit user edit/delete actions may change that saved record.
- Save failure handling depends on cause: bounded retry/backoff for transient failures and throttling; validation/correction for invalid data; immediate size feedback for payload-too-large; follow-up cache-bypassing read when the write result is ambiguous.
- Empty Wardrobe and load/migration failure are distinct states. Never replace existing data with an empty default after a read or migration error.

## 9. API and test evidence

API support, project implementation, and Studio runtime verification are three separate claims. Track them in docs/05_TECH/API.md and docs/01_SYSTEMS/CATALOG_IMPLEMENTATION_STATUS.md. An API existing does not mean the project has wired it correctly; source code existing does not mean Studio behavior is verified.

Official references:
- https://create.roblox.com/docs/reference/engine/classes/Humanoid
- https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription
- https://create.roblox.com/docs/reference/engine/classes/AccessoryDescription
- https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService
- https://create.roblox.com/docs/reference/engine/classes/DataStoreService
- https://create.roblox.com/docs/reference/engine/classes/Player

No new game code or Roblox Studio tests are implied by this document.

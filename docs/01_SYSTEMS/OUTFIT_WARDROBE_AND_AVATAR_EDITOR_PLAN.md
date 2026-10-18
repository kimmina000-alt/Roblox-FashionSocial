# Outfit / Wardrobe — 앞으로 진행할 기능 명세

기준일: 2026-10-17  
대상 브랜치: `catalog-ui-redesign`  
상태: **계획/요구사항 문서 — 구현 완료를 의미하지 않음**

이 문서는 사용자가 붙여넣은 중단된 작업 메모 중 **Outfit 저장/복원과 Wardrobe** 요구사항을 실행 가능한 세부 기준으로 정리한다. Avatar Editor의 상세 기능 명세는 기존 `docs/01_SYSTEMS/AVATAR.md`의 `Avatar Editing UX — Planned` 및 관련 섹션을 기준 문서로 삼는다. 이 파일의 4장 Avatar Editor는 교차 참조용 요약이며, AVATAR.md를 대체하거나 그 상세 요구사항을 축약해 없애는 문서가 아니다. 카탈로그 탐색과 Recent/Popular/Wearing/Favorites는 `docs/01_SYSTEMS/CATALOG.md` 및 `CATALOG_IMPLEMENTATION_STATUS.md`를 기준으로 한다.

## 1. 작업 원칙
- 먼저 현재 `src/`의 실제 착용·해제·현재 착용 목록·HumanoidDescription 적용 구조를 조사한다.
- Roblox Creator Hub의 공식 문서에서 실제 속성/메서드, 적용 대상, 제한을 확인한다.
- UI만 만들고 실제 아바타나 저장 데이터에 반영하지 않은 기능은 완료로 처리하지 않는다.
- API가 지원하지 않는 기능을 임의로 흉내 내지 않는다. 특히 메이크업 transform 지원을 AccessoryDescription 속성으로 추정하지 않는다.
- 저장/복원 실패 시 성공한 것처럼 표시하지 않으며, 실패한 아이템과 성공한 아이템을 구분한다.
- 현재 카탈로그 검색/필터/페이지/착용·해제 기능을 보존한다.
- `default.project.json`, `workbench/catalog-ui-redesign/baseline/`은 수정하지 않는다. `main`에 병합하지 않는다.

## 2. 현재 확인된 상태
- 실제 게임 소스 `src/StarterPlayer/StarterPlayerScripts/FashionGame/CatalogController.client.lua`에는 Avatar Editor 및 Wardrobe 버튼이 있지만, 클릭 시 안내 문구를 출력하는 placeholder다.
- `workbench/catalog-ui-redesign/working-copy/CatalogController.client.lua`도 README상 Avatar Editor/Wardrobe placeholder를 포함한다.
- 현재 실제 착용 상태를 서버에서 관리하는 `AvatarService.lua`와 `TryOnItem` Remote 경로가 존재한다. 저장/복원은 이 흐름을 재사용할 수 있는지 조사해야 한다.
- Outfit 영구 저장 기능, 저장 당시 이미지 보존, 편집 도구가 완성되었다고 확인되지 않았다.

## 3. Wardrobe와 Outfit 저장 — 요구사항

### 3.1 역할 분리
- 기존 상단 탐색 버튼(Recent / Popular / Favorites / Wearing)과 같은 탐색 영역에 별도 **[Wardrobe/옷장]** 버튼을 둔다.
- [Wardrobe/옷장]을 누르면 저장된 Outfit 목록을 연다. 이 버튼은 즉시 저장 UI를 열지 않는다.
- 저장된 Outfit 목록 안에 별도의 **[Save Current Outfit / 현재 코디 저장]** 액션을 제공한다. 이 액션을 누르면 이름 입력 UI를 연다.
- 이름 입력 UI에는 이름 입력란, Save, Cancel을 제공한다. 사용자가 Save를 확정하기 전에는 저장하지 않는다.
- 카탈로그를 닫았다 다시 열면 기본 탐색 화면으로 돌아온다. 저장 목록은 유지되며 사용자가 Wardrobe를 다시 선택해 열 수 있다.

### 3.2 이름 및 중복 클릭
- 이름은 비어 있거나 공백뿐이면 거부한다.
- 앞뒤 공백을 제거하고 UI가 깨지지 않도록 최대 길이를 정한다.
- 같은 이름 허용; 각 Outfit은 고유 ID로 구분한다.
- 저장 요청을 시작한 직후 중복 클릭을 막는다. 저장 완료 후 새 저장을 다시 시작할 수 있다.
- 취소는 저장 데이터나 아바타 상태를 바꾸지 않는다.

### 3.3 저장 데이터
현재 실제 적용 코드와 공식 API를 조사해 복원 가능한 데이터를 확정한다. 최소 검토 대상:
- 고유 Outfit ID, 이름, 생성 시각
- Asset/Bundle 구분 및 아이템 ID/type
- 중복 아이템을 포함한 실제 착용 아이템 목록
- 적용 순서가 필요한 항목의 순서
- 지원되는 HumanoidDescription/BodyColors 외형 값
- 액세서리 transform/order 등 저장·복원이 실제 지원되는 값
- 저장 당시 썸네일의 참조/데이터
- 데이터 버전 및 향후 마이그레이션 고려

검색 결과 목록이나 기본 아바타 데이터를 저장 대상으로 대체하지 않는다. 빈 착장을 저장할 수 있는지, 저장 개수, 데이터 용량 및 DataStore 제한을 확인한다. 기술적 근거가 없으면 무조건 10개로 단정하지 말고 저장 용량/호출 제한을 조사해 기본 정책을 기록한다.

### 3.4 영구 저장
- 현재 서버 구조 및 DataStoreService 사용 여부를 조사한다.
- 클라이언트에서만 보관하는 임시 목록은 영구 저장이 아니다.
- 사용자별 저장, 서버 검증, 데이터 크기 제한, 실패/재시도, 동시 저장, 데이터 버전 및 오류 처리 정책을 정의한다.
- 카탈로그를 닫았다 다시 열어도 목록을 다시 조회한다.
- 게임 재접속 후 보존은 실제 DataStore 적용 및 Studio 테스트 전까지 검증 완료로 표시하지 않는다.

### 3.5 저장 당시 썸네일
- 각 카드 이미지는 저장 시점의 외형을 나타내야 한다.
- 이후 현재 아바타를 바꾸어도 기존 Outfit 카드의 이미지는 바뀌면 안 된다.
- 게임 내 커스텀 ViewportFrame 화면을 그대로 이미지로 캡처/영구 저장할 수 있다고 가정하지 않는다.
- Roblox의 공식 썸네일 API가 커스텀 착장을 지원하는지, 해당 사용자/아바타의 스냅샷이 필요한 모습과 일치하는지 조사한다.
- 지원하지 않으면 구현 가능한 대안(예: 저장된 착장 데이터 기반 미리보기 렌더링 등)을 검토하고, 실제로 가능한 방식과 제약을 사용자에게 보고한다. 단순히 모든 카드에 현재 실시간 아바타 이미지를 넣는 것은 요구사항을 만족하지 않는다.

### 3.6 Outfit 목록 카드
- 저장 당시 썸네일, Outfit 이름, 착용/복원 액션을 표시한다.
- Outfit 데이터는 일반 카탈로그 아이템이 아니다. 일반 아이템 착용 API에 Outfit ID를 전달하지 않는다.
- 같은 이름의 Outfit도 서로 다른 카드로 표시한다.
- 삭제/이름 변경은 범위가 확정되기 전에는 기본 구현에 포함하지 않아도 되지만, 데이터 구조는 향후 삭제를 고려한다.

### 3.7 복원 절차와 실패 처리
- Outfit 복원 중에는 다른 착용 동작과 저장 동작을 잠시 잠그고 진행 중임을 표시한다.
- 저장된 Outfit에 없는 기존 아이템을 해제하고, 저장된 아이템과 외형을 적용해 저장 시점의 착장으로 교체한다. 단순 추가 방식은 금지한다.
- 실패한 아이템은 사용자에게 이름/유형/원인을 가능한 범위에서 알리고, 실패 항목을 제외한 나머지 지원 아이템은 계속 적용한다.
- 삭제되었거나 더 이상 착용할 수 없는 아이템은 안내 후 제외한다.
- 완료 후 서버 확인 상태, Current Outfit 목록, 카드의 WORN 상태, 아바타 미리보기를 동기화한다.
- 부분 성공은 전체 성공이라고 표시하지 않는다.
- 저장 실패 시 기존 저장 데이터를 유지하고 재시도할 수 있도록 한다.

## 4. Avatar Editor 연동 규칙

Avatar Editor의 상세 기능과 수락 기준은 [AVATAR_EDITOR_IMPLEMENTATION_PLAN.md](AVATAR_EDITOR_IMPLEMENTATION_PLAN.md)가 소유한다. 이 문서에서는 Outfit과의 연동 계약만 정의한다.

- Outfit에 저장하는 Avatar Editor 값은 Apply가 성공해 Current Avatar에 확정된 값뿐이다. 미적용 draft는 저장하지 않는다.
- Outfit restore 후 Avatar Editor는 restore된 실제 적용 결과를 다시 읽어 baseline으로 사용한다.
- Restore/respawn으로 캐릭터가 재생성되면 미적용 draft를 폐기한다. Saved Outfit은 그대로 유지하며 필요할 때 Wardrobe에서 다시 불러온다.
- 저장/복원 가능한 범위는 HumanoidDescription이 실제로 표현하고 현재 project adapter가 읽고 재적용할 수 있는 속성으로 제한한다. Rigid accessory Position/Rotation/Scale은 공식 문서상 지원되지만 layered accessory와 makeup에 같은 변환 규칙이 적용된다고 가정하지 않는다.
- API상 읽기/저장/복원이 불가능하거나 현재 프로젝트에서 검증되지 않은 값은 성공으로 표시하지 않는다. 저장 전에 제한을 안내하거나 해당 필드를 지원 범위에서 제외하고 문서화한다.
- 공통 단일 원본 및 draft/apply/cancel 계약: [AVATAR_STATE_AND_PERSISTENCE.md](../05_TECH/AVATAR_STATE_AND_PERSISTENCE.md).

## 5. 공식 문서 검토 목록
구현 전에 현재 버전의 공식 문서를 확인하고, 확인한 속성/제약/적용 경로를 `docs/05_TECH/API.md` 또는 관련 문서에 기록한다.
- https://create.roblox.com/docs/reference/engine/classes/AccessoryDescription
- https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription
- https://create.roblox.com/docs/reference/engine/classes/Humanoid
- https://create.roblox.com/docs/reference/engine/classes/BodyColors
- https://create.roblox.com/docs/reference/engine/enums/HumanoidRigType
- https://create.roblox.com/docs/characters/appearance
- https://create.roblox.com/docs/players/avatar-editor
- DataStoreService 공식 문서 및 저장 제한

## 6. 통합 및 테스트
- [ ] 저장 후 목록 갱신
- [ ] 취소 시 데이터 변경 없음
- [ ] 같은 이름의 Outfit 복수 저장
- [ ] 저장 중 연속 클릭 방지
- [ ] 재접속 후 데이터 보존
- [ ] 저장 당시 썸네일이 이후 외형 변경에도 유지됨
- [ ] Outfit 복원 시 현재 착장 교체
- [ ] 일부 아이템 실패 시 나머지 적용 및 부분 성공 안내
- [ ] 복원 후 Current Outfit/Wearing/card/avatar preview 동기화
- [ ] 액세서리 transform 지원/미지원 유형
- [ ] 체형 조절 및 reset
- [ ] R6/R15 정책/실제 호환성
- [ ] 복장 레이어 재정렬이 실제 외형에 반영됨
- [ ] 메이크업 착용/해제 및 지원되는 레이어 순서
- [ ] 메이크업 transform 지원 여부를 공식 근거로 구분
- [ ] 피부색 전체/부위별 변경 및 reset
- [ ] PC/모바일
- [ ] 기존 검색/필터/착용/해제 회귀 테스트

Studio에서 직접 검증하지 않은 항목은 미검증으로 남긴다.


## 7. Catalog Quick Navigation dependency

The Recent/Popular/Wearing/Favorites behavior is specified in `docs/01_SYSTEMS/CATALOG_QUICK_NAVIGATION_IMPLEMENTATION_PLAN.md`. Wardrobe is a separate saved-Outfit mode/entry point; it must not be conflated with the Wearing grid or the Current Outfit strip. Outfit restore updates Wearing from the actual applied result, but does not automatically add items to Recent or Favorites.


## 8. Locked Outfit decisions — 2026-10-18

- Saved Outfit은 이 게임 안에서만 쓰이며 Roblox 계정 Outfit 저장 API나 플랫폼 소유권을 변경하지 않는다.
- 사용자당 초기 최대 저장 개수는 **50개**이며 설정값으로 둔다. 이는 게임의 제품 정책이지 Roblox 플랫폼 권장 개수가 아니다. Outfit delete 기능을 제공한다. 이름은 trim 후 공백 불가, 길이 제한을 검증하고 같은 이름은 허용한다. 각 Outfit은 고유 ID를 가진다.
- Outfit은 versioned SupportedAppearanceSnapshot을 저장한다. 단순 Asset ID 배열이 아니라 지원되는 HumanoidDescription 값, typed item refs, layered order, body/colors/animations/emotes/makeup 등 복원 가능한 속성을 분리한다.
- 미리보기는 저장된 appearance data에서 별도 모델을 렌더링한다. 저장 당시 bitmap/screenshot 자체를 영구 보존한다고 가정하지 않는다.
- Restore는 현재 외형을 저장된 모습으로 교체한다. 시작 전 baseline을 확보하고, 적용 후 실제 description을 다시 읽어 결과를 검증한다. 삭제·미지원·착용 불가 항목은 해당 항목만 제외하고 나머지 유효한 외형을 적용한다. 부분 복원은 원본 SavedOutfit을 변경하거나 삭제하지 않는다.
- 독립된 item 적용이 가능한 경우 유효 항목은 적용하고 실패 항목을 안내한다. description 전체 적용 실패로 결과가 불명확하면 baseline 복구를 시도하고 결과를 재조회한다. 복구까지 실패하면 오류 메시지를 띄우고 실제 상태를 다시 조회한다.
- Restore 중 wear/remove/Avatar Editor Apply 요청은 대기열에 넣지 않는다. 첫 요청만 실행하며 후속 요청은 차단/거절하고 완료 후 다시 허용한다.
- 일시적 저장 오류/요청 제한은 제한된 횟수로 backoff 재시도한다. 잘못된 데이터나 payload-too-large는 동일 요청을 무한 재시도하지 않는다. 쓰기 결과가 불명확하면 캐시를 우회한 후속 읽기로 확인한다.
- Load/migration failure는 빈 Wardrobe와 구분하고, 실패를 이유로 기존 데이터를 빈 기본값으로 덮어쓰지 않는다.
- 실제 DataStore 저장, 재접속 보존, thumbnail rendering, partial restore behavior는 아직 Studio 검증이 필요하다.

# Player Data Design

상태: **설계 기준 / 아직 구현 완료를 의미하지 않음**  
관련 계약: [Avatar State and Persistence Contract](AVATAR_STATE_AND_PERSISTENCE.md)  
공통 원칙: 데이터는 서버가 검증하고 저장한다. UI 캐시는 신뢰하지 않으며, 저장 성공 응답 전에는 성공 상태를 표시하지 않는다.

## 1. Storage ownership

- Recent: 세션 한정. 검색어/검색 결과 노출 기록이 아니라 실제 착용을 성공한 아이템만 기록한다. 플레이어가 나가면 폐기한다. DataStore에 쓰지 않는다.
- Favorites: 사용자별 영구 데이터. 현재 Roblox 계정의 Favorite 기능과는 무관한 게임 내부 즐겨찾기다.
- SavedOutfits: 사용자별 영구 데이터. 게임 내부에서만 불러와 착용하는 코디이며 Roblox 플랫폼 Outfit을 생성/저장하지 않는다.
- Current Avatar: 별도 영구 아이템 목록을 중복 저장하지 않는다. 현재 캐릭터의 적용된 description에서 snapshot을 재구성한다.
- Avatar Editor draft: 클라이언트 임시 상태. Apply 성공 전에는 Current Avatar나 Outfit에 반영하지 않는다.

## 2. One user record, separated domains

초기에는 사용자당 하나의 DataStore key를 사용하되, Favorites와 Outfits를 별도 domain으로 분리한 versioned envelope에 담는다. 이렇게 하면 같은 사용자 key의 업데이트를 UpdateAsync로 직렬화하면서 기능별 schema와 migration을 분리할 수 있다.

    PlayerData {
      schemaVersion: number,
      favorites: {
        items: CatalogItemRef[],
        updatedAt: number
      },
      outfits: {
        items: SavedOutfit[],
        updatedAt: number
      }
    }

SavedOutfit은 최소한 다음을 포함한다.

    SavedOutfit {
      outfitId: string,
      name: string,
      schemaVersion: number,
      appearance: SupportedAppearanceSnapshot,
      createdAt: number,
      updatedAt: number
    }

SupportedAppearanceSnapshot은 item list만이 아니라 지원되는 HumanoidDescription 속성, rigid/layered accessory data 및 order, classic clothing, body parts/scales/colors, animations, emotes, makeup 등 현재 구현에서 실제로 읽고 재적용 가능한 필드를 typed 형태로 담는다. 지원/복원 불가 속성은 임의로 버리거나 성공 처리하지 말고 저장 전 안내 또는 명시적 제한으로 처리한다. Thumbnail image bytes는 저장하지 않고 appearance snapshot으로 preview model을 다시 렌더링한다.

## 3. Schema version and migration

- Top-level schemaVersion과 각 SavedOutfit의 schemaVersion을 둔다.
- 읽을 때 현재 버전인지 검사한다. 이전 버전이면 순수 변환 함수로 새 구조로 migrate하고, 검증을 통과한 뒤에만 저장한다.
- 알 수 없는 미래 버전, 손상된 JSON/record, 검증 실패는 덮어쓰지 않는다. 저장 실패/불러오기 실패 문구를 표시하고 가능한 경우 재시도 버튼을 제공한다.
- migration 실패 시 원본 데이터를 보존하고 오류를 기록한다. 기본 빈 데이터로 자동 덮어쓰면 기존 사용자의 데이터가 사라질 수 있으므로 금지한다.
- schema 변경에는 fixture/sample record를 사용한 migration 테스트를 추가한다.

## 4. Validation and request safety

- 모든 Remote 요청은 서버에서 타입, ID 범위, itemType, asset/bundle type, Outfit ID ownership, 이름 길이, 필드 수, 허용 속성/수치 범위를 검증한다.
- 클라이언트가 전달한 description/instance 자체를 그대로 신뢰하거나 저장하지 않는다. 허용한 plain data만 받아 서버가 새 snapshot을 구성한다.
- 사용자별 외형 변경 작업에는 하나의 action gate를 공유한다. 첫 요청만 실행하고 작업 중 들어온 후속 요청은 대기열에 넣지 않고 거절한다.
- Favorite toggle은 typed identity를 기준으로 수행한다. 중복 저장을 막고, 반복 요청이 중복 레코드를 만들지 않도록 처리한다.
- DataStore 쓰기는 UpdateAsync와 보호된 pcall을 사용하고, 네트워크/서비스 호출 실패를 재시도할 때는 제한된 횟수와 지연을 둔다. 무한 재시도는 금지한다.
- DataStore는 서버 전용으로 접근한다. 클라이언트에 API key나 저장 권한을 주지 않는다.
- 요청 빈도 제한과 payload size 제한을 서버에서 둔다. 플랫폼 rate limits는 상한이지 앱이 무제한 요청을 보내도 된다는 뜻이 아니다.

## 5. Limits and byte size

- 초기 Saved Outfit 개수: 사용자당 최대 **50개**. 상수/설정으로 두어 나중에 바꿀 수 있게 한다.
- Favorite 최대 개수: 별도 수치 확정 전까지 저장/요청 크기를 방어적으로 제한하고, 한계에 도달하면 추가 실패 메시지를 표시한다. 무제한으로 간주하지 않는다.
- “데이터 크기”는 저장 record를 직렬화했을 때의 byte 수다. Saved Outfit 50개라는 개수 한도와는 별개다. Thumbnail bitmap을 저장하지 않고 필요한 appearance data만 저장해 payload를 줄인다.
- DataStore의 공식 per-key serialized value 최대치는 4,194,304 bytes(4 MiB)다. 이를 앱 목표치로 사용하지 않는다. HttpService:JSONEncode() 결과의 byte 크기를 확인하고 실제 snapshot sample을 측정해 더 작은 앱 내부 상한을 설정한다. 초과하면 저장을 거부하고 명확한 오류를 표시한다. UpdateAsync가 실패했다고 응답해도 저장 여부가 불확실할 수 있으므로, 모호한 오류는 후속 읽기로 확인하기 전까지 저장 실패/성공을 단정하지 않는다.

## 6. Stale/deleted/unwearable items

- 저장된 item ID가 검색 API에서 더 이상 반환되지 않거나 착용 요청이 거절돼도 다른 유효 항목의 식별자를 바꾸지 않는다.
- Outfit restore 전에 모든 entry를 검증하고, 유효/지원/미지원/삭제 의심 항목을 분류한다.
- 일부 항목이 적용 불가능하면 가능한 항목을 적용하고 실패 목록/부분 성공 문구를 표시한다. 외형 전체 적용 실패처럼 결과를 신뢰할 수 없으면 baseline restore를 시도하고 결과를 재조회한다.
- 데이터가 오래됐다는 이유만으로 저장된 Outfit 자체를 자동 삭제하지 않는다. 사용자가 직접 삭제할 때만 삭제한다.
- Favorite가 stale item을 가리키면 기록은 보존하되 “현재 사용할 수 없는 아이템”으로 표시하고, 상세 정보/착용이 실패해도 앱이 중단되지 않게 한다.

## 7. Failure and UI contract

- 불러오기 실패: “저장 데이터를 불러오지 못했습니다.”를 표시. 빈 목록과 오류를 같은 상태로 취급하지 않는다.
- 저장 실패: “저장하지 못했습니다. 다시 시도해 주세요.”를 표시하고 기존 성공 데이터를 보존한다.
- Outfit restore 부분 성공: 성공/실패 항목 수와 사용할 수 없는 항목을 안내하고, 실제 적용 후 snapshot으로 UI를 재구성한다.
- 전체 restore 실패: baseline 복구 후 snapshot 재조회. 복구도 실패하면 오류 문구를 띄우고 사용자에게 현재 아바타를 다시 확인하도록 안내한다.
- 작업 중 버튼은 비활성화하고, 완료/실패 후 재활성화한다.

## 8. Implementation status

현재 저장 schema, migration, DataStore read/write, limits, and retry behavior are design requirements, not confirmed implementation. Track implementation and rejoin persistence tests in CATALOG_IMPLEMENTATION_STATUS.md and WORKLOG.md.


## Official platform size reference
DataStore per-key value maximum: 4,194,304 bytes (4 MiB). This is a hard upper limit, not a target. Use JSONEncode-based byte measurement and a smaller application limit. Source: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits


## 9. Saved Outfit Limit and Restore Policy — 2026-10-18

- Product limit: **maximum 50 SavedOutfits per user**. This is a game design decision, not a Roblox platform recommendation.
- Each record has a unique outfitId even when names are duplicated. At the limit, never silently overwrite an existing Outfit; ask the player to delete one before saving another.
- On restore, skip only the individual entries that are unsupported, deleted/unavailable, or rejected by the platform. Apply the remaining valid appearance and report partial success. Preserve the original SavedOutfit unchanged; a partial restore is not permission to rewrite or delete the record.
- Save failures must be classified. Transient service/network errors and throttling may use bounded backoff retries; invalid/unserializable data and payload-too-large errors require correction, not blind retries. For an ambiguous write result, verify with a follow-up read that bypasses cache before declaring success/failure.
- Load/migration failure must not be displayed as an empty Wardrobe and must never overwrite existing data with an empty default.
- DataStore's 4,194,304-byte (4 MiB) per-key serialized-value maximum is a hard platform limit, not an app target. Measure JSON-encoded byte size and set a smaller internal safety limit after representative snapshots are measured.

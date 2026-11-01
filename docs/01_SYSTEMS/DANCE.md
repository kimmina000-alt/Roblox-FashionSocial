# DANCE (음원별 안무 재생)

## 목적
특정 음원(Audio asset ID)에 맞춘 안무를 등록해 두고, 그 음원이 재생되면 로컬 캐릭터가 음원 재생 위치에 맞춰 춘다.

## 등록 단위
- Key: 음원 Audio asset ID. 예: `91762270038050` = RIIZE - Get A Guitar
- Value: 안무 조각(Segment) 목록. 음원 시간 순서대로 이어 붙인다.

## 조각(Segment) 형식
| 필드 | 필수 | 설명 |
|---|---|---|
| `AnimationId` | O | `"rbxassetid://숫자"` 애니메이션 에셋 |
| `DurationSec` | 자동 이어붙이기 시 O | 조각 길이(초) |
| `StartSec` | X | 음원 기준 시작 시각(초). 생략하면 이전 조각 끝에 붙는다. 첫 조각 생략 시 0 |

조각을 `DurationSec`만으로 나열하면 순서대로 이어진다. 조각끼리 겹치면 `Resolve()`가 오류를 낸다.

## 파일
- `src/ReplicatedStorage/FashionGame/Shared/DanceRegistry.lua` — 등록 데이터, 이어붙이기 계산, 재생 위치 조회
- `src/StarterPlayer/StarterPlayerScripts/FashionGame/DanceController.client.lua` — 음원 감시, 애니메이션 재생/재동기화

## 동작
1. 음악 Sound에 CollectionService 태그 `DanceMusic`을 붙인다 (DJ 부스, 스피커 등).
2. 클라이언트가 태그된 Sound 중 재생 중이고 등록된 음원 ID를 가진 것을 찾는다.
3. 매 프레임 `Sound.TimePosition`으로 현재 조각과 조각 내 위치를 구한다.
4. 조각이 바뀌면 이전 트랙을 멈추고 새 트랙을 재생한다. 위치가 0.15초 이상 어긋나면 다시 맞춘다.
5. 음원이 멈추거나 캐릭터가 리스폰하면 정지/재로드한다.

애니메이션 우선순위는 `Action`이다. 걷기 등 이동 애니메이션 위에서 재생된다.

## 안무 등록 방법
1. Studio의 Animation Editor로 조각별 애니메이션을 만들고 업로드해 ID를 얻는다.
2. 조각의 `AnimationId`와 `DurationSec`(또는 음원 기준 `StartSec`)를 `DanceRegistry.lua`의 해당 음원 `Segments`에 순서대로 추가한다.
3. 음원을 재생하는 Sound에 `DanceMusic` 태그를 붙인다.

## 주의사항
- 애니메이션 에셋은 게임 소유자가 업로드했거나 공개 상태여야 다른 플레이어에게도 재생된다.
- R15 리그 기준으로 제작한다.
- 재생은 클라이언트 로컬이다. 각자 자기 캐릭터만 춘다.
- 음원 Sound가 서버에서 복제되어야 클라이언트가 재생 상태를 알 수 있다.

## 미정 / 다음 작업
- 조각 데이터 입력 (RIIZE - Get A Guitar, 91762270038050)
- 이동 중 안무 정지 여부 (현재는 계속 재생)
- 음원 Sound 배치 (클럽/DJ 부스) 및 태그 지정
- Studio에서 실제 재생 검증 (현재 코드는 로직만 단위 검증됨)

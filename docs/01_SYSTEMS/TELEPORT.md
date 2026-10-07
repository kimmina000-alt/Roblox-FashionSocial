# Teleport System

Experience:
- Main Social
- Runway
- 향후 필요 시 Club/Housing

Main→Runway는 server-side TeleportService:TeleportAsync() 방향.

Appearance:
Humanoid:GetAppliedDescription() → 서버 세션 스냅샷 → Teleport → Runway 서버 검증 → appearance 재현.

TeleportData에는 민감한 데이터를 넣지 않는다. secure state는 서버 측 저장소 사용.
Persistent: DataStoreService
Temporary/frequent session state: MemoryStoreService

Teleport는 published Roblox client에서 실제 테스트한다.

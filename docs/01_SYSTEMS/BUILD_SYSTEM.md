# Building System

Roblox에 완성된 자유 건축 시스템 API가 있는 것은 아니므로 건축 규칙과 UX는 직접 개발한다.

Roblox 기반 기능:
Models/BaseParts / Pivot & Transform / Raycast / Collision / Attributes / DataStore / Asset/Mesh 기능

단계:
1. 가구 배치/이동/회전/삭제
2. Grid/Snap
3. Floor/Wall/Ceiling 규칙
4. Wall/Floor 커스터마이징
5. Modular Building
6. Advanced Freeform

가구와 건축 로직을 분리한다. 가구는 ItemId, Category, Size, PlacementType, Rotatable, Scalable, GridSize 등의 데이터로 등록한다.

AI 활용:
디자인 시안, 3D asset 초안, 반복 에셋, 코드 초안, 데이터 등록을 가속한다.
최종적으로 Scale/Collision/Performance/Style/Placement를 검수한다.

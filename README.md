# Roblox Fashion Social Game — Documentation

이 폴더가 게임 기획의 Source of Truth다.

- `GAME_MASTER.md` — 전체 게임 핵심 규칙
- `00_PROJECT/` — 비전, 코어 루프, 원칙, 로드맵
- `01_SYSTEMS/` — 기능별 설계
- `02_WORLDS/` — 구역별 설계
- `03_CONTENT/` — 콘텐츠/에셋
- `04_ART/` — 아트 방향/레퍼런스
- `05_TECH/` — 기술 구조/API/데이터/보안
- `06_LOG/` — 결정/변경/이슈

원칙: `SYSTEMS`는 무엇을 하는가, `WORLDS`는 어디에서 경험하는가를 정의한다.

Recommended entry points for planning and implementation:
- `docs/00_PROJECT/DEVELOPMENT_ORDER.md` — whole-game dependency order; explicitly separates early graybox from full space production.
- `docs/06_LOG/DOC_CODE_AUDIT_2026-10-18.md` — source/document audit and current implementation gaps (static inspection only).
- `docs/04_ART/WORLD_DESIGN_EXPLORATION.md` — unresolved visual motifs, including optional Korean-inspired details.
- `docs/02_WORLDS/WORLD_CONCEPTS_AND_INTERACTIONS.md` — index of spaces and their canonical per-space documents.

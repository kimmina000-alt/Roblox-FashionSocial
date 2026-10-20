# Claude Code handoff

Read `AGENTS.md` first (catalog UI rules). The user writes in Korean; report in Korean.

## Workflow
- GitHub is the source of truth. Work on a feature branch, test in Studio, push, then merge into `catalog-ui-redesign` only after the user approves.
- Rojo project: `catalog-ui-redesign.project.json` (maps `src/` only). Run `rojo serve catalog-ui-redesign.project.json` and connect the Rojo plugin in Studio, so code syncs automatically (no pasting code into Studio).
- Workspace geometry is not in Rojo. The map is rebuilt from `tools/graybox/build_main_social_graybox.lua` (run in the Studio command bar / MCP in Edit mode). Change the script first, then run it.
- Studio MCP: `execute_luau` from the command bar `require`s a separate copy of ModuleScripts. Test through remotes from the Client datamodel instead.

## Where things stand (2026-10-21)
- Merged in `catalog-ui-redesign`: catalog, avatar editor, wardrobe, QA pass, graybox layout C.
- Not merged (stacked, waiting for the user's play test):
  - `feat/club-mvp-stage4` → `feat/club-vip-dj-drinks` → `feat/photobooth-club2` (latest; includes everything).
- `feat/photobooth-club2` has the 2026-10-20 night batch (WORKLOG): photo booth fixes, coins (ECONOMY.md), club rev3 (D-065), DJ OK/NO window, lasers, LED pillars, 🏠 button. Play-tested 2026-10-21 with server + 2 players (ISSUE-PHOTO-002, CLUB-001): passes, small fixes made. Docs lost by the branch split were restored from `fb478f3`.
- The saved Studio place (`로블록스-패션소셜.rbxl`) has this code and the two-floor club. Rojo plugin is not connected: check script lengths against the files before testing.
- Open items: phone layout of the new boxes, real 캡처 저장 on a device, product IDs (ISSUE-SHOP-001).
- Next: test + fix the batch → 인생네컷 P2 (`docs/01_SYSTEMS/PHOTO_BOOTH.md` §9).

## Key docs
- `docs/00_PROJECT/DEVELOPMENT_ORDER.md`: build order.
- `docs/06_LOG/DECISIONS.md`: D-001 to D-065.
- `docs/06_LOG/ISSUES.md`, `WORKLOG.md`, `CHANGELOG.md`.
- `docs/01_SYSTEMS/CLUB.md`, `DJ_SYSTEM.md`, `MONETIZATION.md`, `PHOTO_BOOTH.md`, `ECONOMY.md`.
- `docs/02_WORLDS/MAIN_SOCIAL_LAYOUT_PROPOSAL.md`, `CLUB_AREA.md`.

## Rules learned
- Content maturity: no alcohol (drinks are non-alcoholic), no small enclosed private rooms, no romance features.
- Luau 200-local-register limit in CatalogController: put new code in modules.
- Avatar shoulder `Motor6D.C0` is read-only on current avatars. Animate with tools or animations instead.
- Humanoids do not climb 1.5–2 stud steps reliably. Use invisible wedge ramps.
- ProximityPrompts only show when they are on screen.

# Claude Code handoff

Read `AGENTS.md` first (catalog UI rules). The user writes in Korean; report in Korean.

## Workflow
- GitHub is the source of truth. Work on a feature branch, test in Studio, push, then merge into `catalog-ui-redesign` only after the user approves.
- Rojo project: `catalog-ui-redesign.project.json` (maps `src/` only). Run `rojo serve catalog-ui-redesign.project.json` and connect the Rojo plugin in Studio, so code syncs automatically (no pasting code into Studio).
- Workspace geometry is not in Rojo. The map is rebuilt from `tools/graybox/build_main_social_graybox.lua` (run in the Studio command bar / MCP in Edit mode). Change the script first, then run it.
- Studio MCP: `execute_luau` from the command bar `require`s a separate copy of ModuleScripts. Test through remotes from the Client datamodel instead.

## Where things stand (2026-10-20)
- Merged in `catalog-ui-redesign`: catalog, avatar editor, wardrobe (DataStore persistence tested), QA pass, graybox layout C.
- Not merged, waiting for the user's play test:
  - `feat/club-mvp-stage4`: dance panel, 31 emotes, tempo, 같이 추기, seats, club music.
  - `feat/club-vip-dj-drinks` (on top of the above): VIP/DJ paid zones, DJ time + song requests, bartender drinks, bottles, cups, underground club, 인생네컷 plan.
- Open items: two-player tests (ISSUE-CLUB-001), mobile layout, product IDs (ISSUE-SHOP-001: VIP pass, DJ 30분, Drink_Fanta in `src/ReplicatedStorage/FashionGame/Shared/MonetizationConfig.lua`).
- Next by plan: finish club → 인생네컷 P1/P2 (`docs/01_SYSTEMS/PHOTO_BOOTH.md` §9).

## Key docs
- `docs/00_PROJECT/DEVELOPMENT_ORDER.md`: build order.
- `docs/06_LOG/DECISIONS.md`: D-001 to D-056.
- `docs/06_LOG/ISSUES.md`, `WORKLOG.md`, `CHANGELOG.md`.
- `docs/01_SYSTEMS/CLUB.md`, `DJ_SYSTEM.md`, `MONETIZATION.md`, `PHOTO_BOOTH.md`.
- `docs/02_WORLDS/MAIN_SOCIAL_LAYOUT_PROPOSAL.md`, `CLUB_AREA.md`.

## Rules learned
- Content maturity: no alcohol (drinks are non-alcoholic), no small enclosed private rooms, no romance features.
- Luau 200-local-register limit in CatalogController: put new code in modules.
- Avatar shoulder `Motor6D.C0` is read-only on current avatars. Animate with tools or animations instead.
- Humanoids do not climb 1.5–2 stud steps reliably. Use invisible wedge ramps.
- ProximityPrompts only show when they are on screen.

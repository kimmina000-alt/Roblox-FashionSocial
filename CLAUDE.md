# Claude Code handoff

Read `AGENTS.md` first (catalog UI rules). The user writes in Korean; report in Korean.

## Workflow
- GitHub is the source of truth. Work on a feature branch, test in Studio, push, then merge into `catalog-ui-redesign` only after the user approves.
- Rojo project: `catalog-ui-redesign.project.json` (maps `src/` only). Run `rojo serve catalog-ui-redesign.project.json` and connect the Rojo plugin in Studio, so code syncs automatically (no pasting code into Studio).
- Workspace geometry is not in Rojo. The map is rebuilt from `tools/graybox/build_main_social_graybox.lua` (run in the Studio command bar / MCP in Edit mode). Change the script first, then run it.
- Studio MCP: `execute_luau` from the command bar `require`s a separate copy of ModuleScripts. Test through remotes from the Client datamodel instead.
- Sync without Rojo (2026-10-22): serve the scratchpad with a small PowerShell HttpListener on localhost:8765, then in Edit mode switch `HttpService.HttpEnabled` on, `GetAsync` the file, `ScriptEditorService:UpdateSourceAsync` (or `loadstring` a graybox zone), and switch it back off. Much cheaper than pasting code into tool calls. `scratchpad/zones.ps1 -Zones 02_Club,...` writes only the chosen graybox zones. MCP cannot stop a multi-client (2-player) test; ask the user to restart it after code changes. Never run an execute_luau longer than ~60 s: on timeout MCP restores the camera it saw at the start (e.g. a Scriptable booth camera).

## Where things stand (2026-10-22)
- Merged in `catalog-ui-redesign`: catalog, avatar editor, wardrobe, QA pass, graybox layout C.
- Not merged (stacked, waiting for the user's play test):
  - `feat/club-mvp-stage4` → `feat/club-vip-dj-drinks` → `feat/photobooth-club2` (latest; includes everything).
- `feat/photobooth-club2` has the 2026-10-20 night batch (WORKLOG): photo booth fixes, coins (ECONOMY.md), club rev3 (D-065), DJ OK/NO window, lasers, LED pillars, 🏠 button. Play-tested 2026-10-21 with server + 2 players (ISSUE-PHOTO-002, CLUB-001): passes, small fixes made. Docs lost by the branch split were restored from `fb478f3`.
- The saved Studio place (`로블록스-패션소셜.rbxl`) has this code and the two-floor club. Rojo plugin is not connected: check script lengths against the files before testing.
- 2026-10-21 (2): props fix (ISSUE-PHOTO-003), 📸 photo/video capture button (D-067), Fashion Week Backstage in the graybox (D-066), PERFORMANCE.md. Cafe part-time job is a proposal waiting for the user (D-068, CAFE.md).
- 2026-10-22: photo booth fixes (front camera, props in saved cuts, photo wall), club rev4 from the user's 1F/2F plans (D-069), live LED pillars (D-070), PARK rides (D-071), planning docs: 3 cafes (D-072), 알바 on hold (D-068), OHU name (D-073), economy v2 doc (D-074, code still v1), PROP_SHOP.md, street buildings.
- 2026-10-22 (2): park E/V keys, club rebuilt in place (ISSUE-CLUB-008), pillars 30 s, XP name tags (D-078), beach with terrain sea/swim/tubes/parasols/palms/ice cream truck (D-075), shared cafe system + ocean-view cafe (D-076), hanok village (D-077).
- 2026-10-22 (3): booth host-only picking + copies step (D-079), live front-facing pillars + negative test ids (D-080), rides every frame / V fix / 🏠 leaves rides (D-081).
- Open items: two-player test of booth watching and pillars with different outfits (ISSUE-CLUB-001/009), two-player ride test, phone layout of the new boxes and ride buttons, real 캡처 저장 and 🎥 video on a device, product IDs (ISSUE-SHOP-001), economy v2 code, 야호 voice clip.
- Next: test + fix the batch → 인생네컷 P2 (`docs/01_SYSTEMS/PHOTO_BOOTH.md` §9).
- Start of next session: push works from this machine now (Git Credential Manager has the login). Check the Studio place was saved (graybox zones live in Workspace only). Ask whether to apply economy v2 coins in code.

## Key docs
- `docs/00_PROJECT/DEVELOPMENT_ORDER.md`: build order.
- `docs/06_LOG/DECISIONS.md`: D-001 to D-081.
- `docs/06_LOG/ISSUES.md`, `WORKLOG.md`, `CHANGELOG.md`.
- `docs/01_SYSTEMS/CLUB.md`, `DJ_SYSTEM.md`, `MONETIZATION.md`, `PHOTO_BOOTH.md`, `ECONOMY.md`.
- `docs/02_WORLDS/MAIN_SOCIAL_LAYOUT_PROPOSAL.md`, `CLUB_AREA.md`.

## Rules learned
- Content maturity: no alcohol (drinks are non-alcoholic), no small enclosed private rooms, no romance features.
- Luau 200-local-register limit in CatalogController: put new code in modules.
- Avatar shoulder `Motor6D.C0` is read-only on current avatars. Animate with tools or animations instead.
- Humanoids do not climb 1.5–2 stud steps reliably. Use invisible wedge ramps.
- ProximityPrompts only show when they are on screen.
- A ViewportFrame inside a SurfaceGui parented to a Workspace part is not drawn: parent the SurfaceGui to PlayerGui and set Adornee. ViewportFrames also do not support Rotation.
- Humanoid:AddAccessory only welds in Workspace; for rigs in a WorldModel weld by hand (PhotoProps.wear).
- Studio multi-client test players have negative UserIds: never test `id > 0` for "a player", use `id ~= 0`.
- Never drag graybox zones in Studio; change the script and rebuild (a moved club sank into the ground).
- Keep angles small before CFrame.Angles (single precision): use (t / period) % 1 with the server clock.

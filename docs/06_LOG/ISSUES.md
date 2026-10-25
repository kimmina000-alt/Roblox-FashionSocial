# Issues

이 문서는 재현 가능한 문제, 기대/실제 결과, 원인 조사 및 해결 결과를 기록한다. 계획/우선순위는 TODO.md, 요구사항/수락 기준은 기능 상세 명세, 실제 조사와 테스트 증거는 WORKLOG.md, 커밋 변경 내역은 CHANGELOG.md에 둔다.

## Template

### ISSUE-001 — Title
Status: Open
Area: System / World / Art / Tech
Description:
Steps:
Expected:
Actual:
Decision / Fix:

---

### ISSUE-AVATAR-001 — Makeup item rejected by wear service
Status: Closed 2026-10-19 (Studio: Face and Lip makeup wear succeed, appear in GetCurrent)
Area: Tech / Avatar / Catalog
Description: Face makeup was selected in the catalog, but the server rejected the wear request.
Steps:
1. Open the catalog in Studio.
2. Browse to Face Makeup, Lip Makeup, or Eye Makeup.
3. Press the wear action on a makeup item.
Expected: The supported makeup type is added through the MakeupDescription path and the avatar/card state updates after confirmation.
Actual: Output reports [CatalogController] Wear failed: false This item type is not supported yet.
Investigation notes:
- Makeup types are not ordinary AccessoryType values and should not depend on the generic accessory mapping.
- Review the server dispatcher and the placement/scope of the existing MakeupDescription handling before changing behavior.
Decision / Fix: Keep makeup Wear enabled only when the server path is verified. Add a type-specific handler and a matching remove path, then test each makeup type in Studio.

### ISSUE-CATALOG-002 — Animation subcategories return zero results
Status: Cause confirmed 2026-10-19 — individual Idle/Walk/Run/Mood animations are off-sale (sold in packs). With IncludeOffSale the API returns them; config already sets it and the off-sale fix keeps it. UI re-test pending
Area: Tech / Catalog
Description: Selecting individual animation subcategories in Studio returns 0 items loaded.
Steps:
1. Open the catalog.
2. Select an individual animation category such as Idle, Walk, Run, Jump, Fall, Climb, or Swim.
Expected: Results appear when Roblox's catalog API has matching items for the selected filters.
Actual: The category reports zero loaded items.
Investigation notes:
- Confirm whether the API returns individual assets for each AvatarAssetType filter in the current experience.
- Verify IncludeOffSale behavior for each animation subcategory.
- The current category selection path does not pass BundleTypes to the search function, so animation-pack search is also misconfigured.
Decision / Fix: Test asset filters and bundle filters separately; log the effective CatalogSearchParams and distinguish a legitimate empty result from an API/filter issue.

### ISSUE-CATALOG-003 — Off-sale toggle can be overwritten
Status: Fixed on `feat/catalog-ui-1019` (IncludeOffSale = user choice OR category default)
Area: Tech / Catalog
Description: Search sets IncludeOffSale from the user toggle and then overwrites it with the category default.
Expected: The explicit user choice should be preserved unless the UI clearly communicates a category-specific override.
Actual: The final search parameter can ignore the visible toggle state.
Decision / Fix: Define one precedence rule for the global toggle and category defaults, then test it across normal and animation categories.

### ISSUE-UI-004 — FoundationProvider warning from UIBlox
Status: Needs triage
Area: Tech / UI
Description: Studio Output showed a Roblox CorePackages UIBlox warning: FoundationProvider not found. Please ensure that the FoundationProvider is present in the component tree.
Expected: No relevant UI failure; if a Roblox internal warning remains, establish whether it affects this experience before assigning ownership.
Actual: Warning and CorePackages stack were observed during Play.
Decision / Fix: Check whether any in-game UI is visibly broken and capture a minimal reproduction. Do not classify as a game-code defect based on the warning alone.


## Audit findings — 2026-10-18

### ISSUE-AUDIT-001 — Wear/remove request does not preserve typed identity
Status: Partly fixed (2026-10-19). Favorites, Recent and SavedOutfits store `itemType + id`; bundles are never sent to the asset wear action (shoe bundles use `WearShoeBundle`, other bundles open CONTENTS). Still open: Wear/Remove requests carry a bare asset id, and the worn cache is keyed by asset id.
Area: Tech / Catalog / Avatar
Description: The active client request passes an action plus numeric assetId. Server detail lookup explicitly requests `Enum.AvatarItemType.Asset`; the UI's current worn state is keyed by numeric ID. Bundle and cross-type identity are not represented end-to-end.
Expected: Request and state preserve the item type and type-specific metadata; unsupported types are clearly disabled/rejected.
Actual: Asset-only request contract in the inspected active source.
Decision / Fix: Add a typed request/result contract or disable Bundle wear until a verified application route is implemented. Update Current Outfit, Wearing, Favorites and restore identity consistently.

### ISSUE-AUDIT-002 — Server does not gate concurrent avatar mutations
Status: Fixed on `feat/catalog-ui-1019` (per-player runExclusive in ServerMain)
Area: Tech / Avatar / Network
Description: Client uses a local busy flag, but the inspected server entry point has no per-player operation lock shared by wear/remove/current future Apply/restore operations.
Expected: One authoritative per-player mutation at a time; reject or disable later requests while one is in progress.
Actual: Local client guard only was found in the inspected path.
Decision / Fix: Add server-side action gate and test rapid duplicate/mixed requests and failure cleanup.

### ISSUE-AUDIT-003 — Applied appearance is read but not fully checked against requested change
Status: Fixed on `feat/catalog-editor-1019` (Wear confirms the asset in the applied description; ApplyEdit returns the read-back state)
Area: Tech / Avatar
Description: The service applies a HumanoidDescription and reads GetAppliedDescription(), but the inspected path logs accessory details and returns success without checking that the requested item/property is present in the resulting applied state.
Expected: Success means the intended change was verified in the actual applied description.
Actual: Post-apply read/logging is present; requested-change comparison was not found.
Decision / Fix: Implement type-specific post-apply verification and return a confirmed snapshot/result.

### ISSUE-AUDIT-004 — Active UI has placeholder discovery and Wardrobe controls
Status: Fixed on `feat/catalog-fixes-1019b` (Wardrobe implemented; the other controls were fixed on `feat/catalog-editor-1019`)
Area: UI / Catalog / Persistence
Description: Recent, Popular and Favorites handlers log placeholder messages; Wardrobe and Avatar Editor display planned-status text. Wearing has a partial list path.
Expected: Each enabled control performs its documented behavior, or is visibly marked disabled/not yet available.
Actual: Full behavior is not implemented in inspected active source.
Decision / Fix: Implement after the core typed-state/persistence gates, or disable/defer controls explicitly.

### ISSUE-AUDIT-005 — IncludeOffSale UI state is overwritten
Status: Fixed on `feat/catalog-ui-1019` (see ISSUE-CATALOG-003)
Area: Tech / Catalog / Search
Description: `searchCatalog()` sets `params.IncludeOffSale` from `currentIncludeOffSale` and later overwrites it with `currentCategoryIncludeOffSale`.
Expected: Effective API params match the visible filter state under one documented precedence rule.
Actual: Later assignment can ignore the user toggle.
Decision / Fix: Resolve the precedence and add regression tests across categories, including animation/bundle searches.

### ISSUE-AUDIT-006 — Persistence and world plans exceed active implementation
Status: Open
Area: Product / Systems / World
Description: Data schema and world plans are detailed, but the inspected active source has no confirmed DataStore implementation, and the source tree contains no dedicated implementation modules for the documented Club, Photo Spots, Beach/Aquarium, Cafe, Playground, Backstage, Runway or Housing features.
Expected: Planning status and implemented status remain separate.
Actual: These features remain plans/candidates based on this source inspection.
Decision / Fix: Follow `../00_PROJECT/DEVELOPMENT_ORDER.md`; implement one core loop/interaction at a time and update the audit/worklog only with new evidence.

### ISSUE-AUDIT-007 — Popular mode has no mode-specific aggregation yet
Status: Open
Area: Catalog / API / UX
Description: `CatalogConfig.SortAggregation` currently defaults to `AllTime`. The documented Popular behavior prefers `MostFavorited + PastMonth` with explicit fallback to `AllTime`, but the active and workbench Popular handlers are placeholders.
Expected: Popular mode explicitly applies its documented aggregation, handles runtime rejection/invalid results with a visible/logged fallback, and never labels other sorts as Popular.
Actual: Global config is AllTime; Popular mode-specific behavior is not implemented.
Decision / Fix: Implement a Popular-mode-specific sort/aggregation branch and verify the supported combinations in Studio. Keep ordinary catalog sort aggregation behavior separate.

### ISSUE-CATALOG-006 — CatalogController:1392 nil call (forward reference)
Status: Fixed on `fix/catalog-1392` (Studio-tested 2026-10-19, awaiting user approval to merge)
Area: Tech / Catalog
Description: Wear/remove flow errors at CatalogController line ~1392 (Studio copy) calling `refreshWornItems`.
Expected: Worn list refreshes after wear/remove.
Actual: `attempt to call a nil value` — `refreshWornItems` (and `searchCatalog`) are local functions defined after the functions that call them, so the call resolves to a nil global. `actionBusy` can stay locked after the error.
Decision / Fix: Forward-declare both locals at the top, assign later; ensure actionBusy is released on every path (pcall/finally). Regression test wear/remove/discovery in Studio. See `STUDIO_ONLY_CODE_AUDIT_2026-10-19.md`.

### ISSUE-CATALOG-007 — Shoes category showed CONTENTS instead of WEAR
Status: Fixed on `feat/catalog-ui-1019` (Studio-tested)
Area: Catalog / Avatar
Cause: Roblox sells shoes only as `Shoes` bundles; the individual Left/RightShoeAccessory assets are off-sale (search with on-sale assets only returns 0). All Shoes results were bundles, and every bundle card showed CONTENTS.
Fix: Shoes bundle cards show WEAR/WORN. Server `WearShoeBundle` reads the bundle on the server, adds both shoe assets in one apply (replacing shoes on the same side). Card WORN → `RemoveMany` removes both. The worn strip keeps separate left/right cards with separate remove.

### ISSUE-CATALOG-008 — 착용 중 view showed items that were not worn
Status: Fixed on `feat/catalog-editor-1019` (Studio-tested)
Cause: the 착용 중 view drew worn cards into the results list, but scrolling then triggered catalog pagination and appended normal search results.
Fix: browse modes; local lists (Recent/Favorites/Wearing) never page the catalog. Studio: 19 worn → 19 cards, still 19 after scrolling to the end.

### ISSUE-CATALOG-009 — 착용 중 card grid: layer drag moved the ghost but did not reorder
Status: Fixed on `feat/catalog-fixes-1019b` (Studio-tested with a touch drag: grid and server order both changed)
Cause: two overlapping `renderLocalMode` calls (mode switch + worn refresh) could both append cards, so the grid could hold duplicate cards and the drop sent a duplicated id list, which the server rejects.
Fix: a render generation token (stale renders stop and the grid is cleared again before cards are added). The drop order is merged into the full layered list, so a filtered grid still sends a complete, duplicate-free list.

### ISSUE-EDITOR-001 — Accessory adjustments only showed after Apply
Status: Fixed on `feat/catalog-fixes-1019b` (Studio-tested on a clone)
Cause: `ApplyDescriptionAsync` skips accessories whose asset id did not change, so transform-only drafts did nothing on the preview clone.
Fix: the preview clone uses `ApplyDescriptionResetAsync`.

### ISSUE-WARDROBE-001 — Outfit card previews not visually confirmed
Status: Resolved 2026-10-20 (PC play: the saved outfit card shows the avatar preview)
Description: in this Studio session ViewportFrame screenshots were stale (the main preview kept its old image after its model was moved), so the outfit card preview could not be checked visually. The preview model is built and framed (20 parts, camera in front). Please confirm the cards show the outfit.

## QA pass — 2026-10-20 (feat/qa-catalog-wardrobe-1020)
Played as a player in Studio (PC, real mouse) across all 37 categories plus Wardrobe; 31 categories wore/removed correctly before fixes.

### ISSUE-QA-001 — 전신/머리/얼굴 categories empty or unwearable
Status: Fixed (Studio-tested: body bundle wear → WORN, preview updated; remove restores spawn body; head bundle wear/remove)
Cause: Roblox search returns only stray off-sale limbs and no classic faces; the wear service had no body-part path. Fix: D-039.

### ISSUE-QA-002 — Wear failures and load-more failures were invisible
Status: Fixed. Errors went to a hidden status label; now a Korean toast.

### ISSUE-QA-003 — Category click dropped while a search was running
Status: Fixed (rapid clicks land on the last category). D-041.

### ISSUE-QA-004 — Worn strip kept pre-respawn items
Status: Fixed (after respawn 24 → 19 items, matching the server).

### ISSUE-QA-005 — Category click inside Wardrobe did nothing visible
Status: Fixed (leaves Wardrobe and shows the category).

### ISSUE-QA-006 — Known minor (open)
- Removing a head bundle can reset a mood animation the player already had.
- 50 outfit cards each build a ViewportFrame preview (heavy on low-end phones; consider lazy previews).
- Wardrobe dates use the server clock (Studio shows local machine time).
- DataStore persistence across rejoin still needs a published place with Studio API access.

### ISSUE-DATA-001 — Favourites changed after the last outfit write could be lost on server close
Status: Fixed 2026-10-20 (Studio-tested with API access: favourite added → stop → play → favourite present; outfit saved, restored after rejoin)
Cause: `BindToClose` returned while a `PlayerRemoving` save was still yielding, so the server closed before the write. Outfit changes were safe (written immediately); favourites are written on autosave/leave.
Fix: count in-flight leave saves; `BindToClose` saves remaining players in parallel and waits (≤25 s) until all saves finish.

### ISSUE-STUDIO-001 — Screen capture returns a white 3D view (open)
In this session every Studio screenshot (edit and play) showed a white 3D view with the UI drawn correctly. Graybox checks were done with pathfinding and raycasts instead. Needs a look on the user's machine (window minimised/covered, or graphics driver).

### ISSUE-CLUB-001 — 같이 추기 with two players (mostly verified)
2026-10-20 night, Studio server + 2 players driven through MCP: join, follow on dance and tempo change (frame error 0.02 s), others see the dance, tap a player → card, tempo touch → own dance, loop refused, leader stop → follower rests and resumes — all pass (CLUB.md §15.1). Still open with 2+ players: DJ guests/invite, DJ queue → extension blocked, photo booth group shooting, tap accuracy on a real phone.


2026-10-21 (server + 2 players): DJ queue → OK/NO window (NO passes the turn, no refund), extension blocked while someone waits, DJ guest invite → guest enters the DJ zone, 친구만 bottle and 친구와 booth refuse non-friends, group photo 모두와 (both save their own copy), 같이 추기 again — all pass. Real Roblox friends were not available to test the allowed case.

### ISSUE-CLUB-002 — "✕" glyph rendered as an empty box (fixed)
Same font issue as the editor's ↺. The dance panel close button uses "X".

### Repo note — 2026-10-20 accidental commit
An interrupted earlier run left the Club work uncommitted; a later `git add -A` committed it to `catalog-ui-redesign` as 417b717 under the Ferris-wheel message. Reverted by 01c300f; the work was rebuilt on `feat/club-mvp-stage4`.

### ISSUE-CLUB-003 — Shoulder joint C0 is read-only on current avatars (worked around)
Setting `RightShoulder.C0` errors ("Property is read only") with the new avatar joint system, so a scripted arm raise is impossible. The drink motion moves the cup (Tool.Grip) to the mouth instead. A real drink animation needs an uploaded animation asset.

### ISSUE-CLUB-004 — Steps of 1.5–2 studs are not climbable (fixed)
VIP stairs (2-stud steps) could not be climbed. Both staircases now have invisible wedge ramps; the steps are visual only. Verified walking up both.

### ISSUE-SHOP-001 — Product IDs not created (open, user action)
VIP pass, DJ 30분 and 환타 have ID 0. Create them on the Creator Dashboard and send the IDs.

### Note — ProximityPrompts only show when on screen
During tests the bartender prompt did not appear while the camera faced away; this is normal Roblox behaviour (prompts must be in view), not a bug.

### ISSUE-PHOTO-002 — 2026-10-20 batch play test (mostly verified 2026-10-21)
Tested in Studio with server + 2 players and a single player (WORKLOG 2026-10-21). Pass: booth barrier (walking out stops at the open front), 나가기 → outside, save → outside, WHITE → PINK in a row, ⏸/▶, poses and props stop after the last shot, pick/frame/album boxes (centred, 저장 inside the box), coin frame refused/bought/"이미 가지고 있음", Frame Pack frame, album → inventory item, photo wall post (Back face; tap, preview and SurfaceGui agree on left/right), 🏠, coin earning (daily 20, passive, photo 15, group 10, wall 5), club audio zones, VIP gate, DJ OK window / NO passes the turn, DJ console click → music window, lights on/off, lasers, LED pillars (after the CLUB-005 fix), seats (table, VIP sofa, bar stool), coin drink.
Fixed during the test: coin icon 🪙 showed as a box (the Roblox font lacks it) → 💰; a pick/frame screen could stay open after its session ended → it now closes when the booth no longer lists you (unless a save is running).
Not covered: phone layout of the new boxes, real "캡처 저장" on a device, 5-minute dance bonus, album +10 slot purchase.

### ISSUE-CLUB-005 — LED pillars blank with StreamingEnabled (fixed, verified 2026-10-21)
The client set up pillars before their panels streamed in (0 screens). ClubLightsController rebuilds when parts arrive; LEDPillar / DJ_Console use ModelStreamingMode Atomic. Studio check: 4 pillars × 16 screens with the portrait.

### ISSUE-CLUB-006 — Dance list invisible on phones (fixed 2026-10-20)
On a 705×338 viewport the panel had a 300 px minimum height and a fixed 150 px 같이 추기 area, leaving 14 px for the dance grid. Header row merged, 같이 추기 moved to a tab, the panel fits the screen height on short screens. Checked on Galaxy A06 (simulator) and a 1366×768 laptop view.

### ISSUE-STUDIO-002 — Rojo plugin not connected; MCP clicks ignored in the device simulator (open, note)
2026-10-20 night: `rojo serve` was running but the Studio plugin was not connected, so file changes did not reach Studio. The changed scripts were written into Studio through MCP with the exact file contents (lengths match the files). Connect the Rojo plugin before the next session. Separately, MCP mouse input does not reach GUI buttons while the Device Simulator (phone) is active; it works in a desktop view.

### ISSUE-PHOTO-001 — Studio capture showed no 3D inside ViewportFrames (resolved 2026-10-21)
On 2026-10-20 captures drew the GUI with a white 3D view. On 2026-10-21 captures showed the 3D world and the photo cells normally (both avatars, props, booth colour), so it was that Studio session.


### Note — Seats also sit you on touch (2026-10-21)
Roblox Seats seat a character that touches them; walking into a table stool sits you even without the 앉기 prompt. Not changed for now; can be switched to prompt-only seating later if players find it annoying.

### ISSUE-PHOTO-003 — 인생네컷 props invisible on the avatar (fixed 2026-10-21)
User report with screenshot: 왕관/선글라스/하트 안경 buttons were on but nothing showed. Cause: each prop's pieces were joined with WeldConstraints created before the accessory was in the world, so the pieces stayed where they were built (~94 studs from the head); only the invisible handle followed the head. The 2026-10-21 test only checked that the accessory existed and the saved-photo render, not the live avatar — that check was wrong. Fix: classic Welds with a fixed C0 offset; hat props are also lifted above big hair (PhotoProps.liftFor, used for the live avatar and the saved photo). Verified in Studio: all pieces on the head, crown visible above fluffy hair, sunglasses on the face. Also: other menus (e.g. the catalog editor) are hidden while the shooting screen is up.

### ISSUE-PHOTO-004 — Saved cut: props in the middle of the picture (fixed 2026-10-22)
User report: props are worn while shooting, but in the finished cuts they sit fixed in the centre. Cause: PhotoRender put props on with Humanoid:AddAccessory, which only welds inside Workspace; the rig is in a WorldModel, so the prop stayed at the stand origin. Fix: `PhotoProps.wear` welds the handle to the matching body attachment by hand. Verified in Studio (crown on the hair, sunglasses on the face).

### ISSUE-PHOTO-005 — Photo wall shows empty strips (fixed 2026-10-22)
Cause: the wall's SurfaceGui (with the photo ViewportFrames) was parented to the wall part; ViewportFrames there are not drawn. Also the photos were rotated, which ViewportFrames do not support. Fix: SurfaceGui in PlayerGui with Adornee = wall, no rotation. Verified: all four cuts visible. Same cause made the live LED pillar avatars invisible at first (fixed the same way).

### ISSUE-PARK-001 — Ferris wheel cabins frozen (fixed 2026-10-22)
Angles built from the server clock (~1.8e9 s) were huge; CFrame.Angles is single precision, so every cabin landed on the same spot. Fix: keep angles in 0..2π (ParkConfig).

### ISSUE-PARK-002 — Open: two-player ride test, phone buttons, "야호" voice clip
Single-player Studio test passed for all five rides (board, ride, leave, swing +/−, slide + 야호). Still to check: two people in one gondola / seeing other riders, button positions on a phone, choosing a licensed voice clip.

### ISSUE-CLUB-008 — Club sunk into the ground / VIP stair blocked (fixed 2026-10-22)
The saved place had the whole 02_Club model moved (2, -6, -29) relative to the graybox script, so it no longer matched the ground hole: the building sat 6 studs too low and Ground_N covered the top of the VIP stair. Rebuilt from the script; walked through the VIP wall and up to the 2F landing with a VIP pass. Tip: do not drag graybox zones in Studio — change the script.

### ISSUE-PARK-003 — Stuck in first person on the ferris wheel (fixed 2026-10-22)
LockFirstPerson locks the mouse, so the 3인칭 button could not be clicked. Fix: V toggles the view; the view button is Modal in first person (frees the mouse).

### ISSUE-CLUB-001 (update 2026-10-22) — Two-player pillar test still to do
Pillar rotation is now 30 s, random order, immediate switch when the shown player leaves. The two-player check (different outfits, both appear in turn) waits for a new 2-player test session: the running one used old code and could not be stopped from MCP.

### ISSUE-CLUB-009 — Pillars empty in the 2-player test (fixed 2026-10-22)
Studio test players have negative user ids; ClubLightsController treated only ids > 0 as players. Fixed (id ~= 0). Pillar now faces the camera and scrolls. Two-player visual check still to do in a new 2-player session.

### ISSUE-PARK-004 — Rides jerky, V did not return to 3rd person (fixed 2026-10-22)
Rides moved at 30 Hz while riders moved every frame → both every frame. Camera stayed zoomed in after Classic → push min zoom out briefly. Verified V on/off values in Studio.

### ISSUE-STUDIO-003 — Studio 3D view white after an MCP reconnect (open)
After a long execute_luau timed out and MCP reconnected, the play view rendered white (GUI only). Code unaffected; restart the play test.

### ISSUE-MOBILE-001 — Mobile 2-player test (2026-10-22, Studio phone emulation 705×338, touch)
Fixed:
- Cafe / ice cream menu cut off at the bottom → menu scales to the screen (SnackController).
- Photo booth boxes small on phones → on screens < 500 px tall the pick / frame / result / album box uses the full height and 66 % of the width.
- "몇 장 저장할까요?" texts and buttons overlapped → fixed-size content scaled to fit (PhotoCopiesPanel).
- Name tags (nickname + XP) showed inside the shooting window → hidden while shooting.
- Dance panel covered the thumbstick (no walking while open) → on phones it opens right of the thumbstick.
- Ride buttons: no "[E]" hint without a keyboard; on phones the bar sits low between the thumbstick and jump.
- World labels without "(E)" (tube, cafe counters).
Checked OK on mobile: wait bar, shooting screen, host picking + watching, copies → save, VIP purchase window, ferris wheel tap to board (내리기 / 1인칭 buttons).
Not checked by tap (Studio cannot inject taps at the right place in phone emulation): catalog C button, album, 📸 menu — please tap them once on a real phone.

Re-test after restart (2026-10-22, phone emulation 735×413 / 801×413): menu fits, booth boxes larger, copies panel clean, name tags hidden while shooting, dance panel right of the thumbstick (thumbstick visible), ride button low with no [E]. Pillars swapped after 30 s with two players (ISSUE-CLUB-001 done).

Real phone check by the user (2026-10-22): catalog C, 🖼 album and 📸 menu all work. ISSUE-MOBILE-001 closed.

## Mobile 2P test — 2026-10-26 (fixed the same day, re-test pending)

### ISSUE-2P-001 — DJ panel: 📺 전광판 button outside the panel on phones
In the compact DJ panel the row held the extend button (150) plus the screen button (96), which is wider than the panel (220). The 📺 button started at x -14. Fix: as DJ, both buttons take half the row each (ClubMusicController).

### ISSUE-2P-002 — Piano: no way to stand up on a phone
The piano keyboard (DisplayOrder 20) covers the touch jump button. Fix: a "일어나기" button on the keyboard panel (PianoController).

### ISSUE-2P-003 — Bus ad: the default poster flickers through the ad
The panel's own SurfaceGui (the default poster) and the client ad SurfaceGui draw on the same face, and which one wins depends on the camera. Fix: the client turns the panel's poster off while an ad is up (BusAdController).

### ISSUE-2P-004 — Live supporter vote window does not show my vote
The client asks VoteMine with kind "supporter", but the server only answered "busad" and "today". Fix: ServerMain routes "supporter" to RankingService.MyVote.

### ISSUE-2P-005 — 오늘의 큰손 votes fail in Studio
The vote id pattern `%d+` did not match negative Studio test ids. Fix: `%-?%d+` (RankingService).

### ISSUE-2P-006 — Bottle labels on one table overlap
Every bottle label sat at the same height. Fix: each new bottle's label sits 0.9 higher (DrinkService). Also the "나만" toast read "'나만'로"; it now reads "(공개: 나만)".

### ISSUE-2P-007 — A banner hides under the open 💝 window
Fix: Banner ZIndex 5 (BannerController).

Re-test 2026-10-26 (new 2P session, Player2 on a 705×338 phone): all 7 are verified fixed. ISSUE-2P-002 needed one more change: `Humanoid.Jump = true` from the button is reset by the control script in the same frame, so the button now sets `Humanoid.Sit = false`.

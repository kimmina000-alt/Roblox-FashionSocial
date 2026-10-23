# Design Decisions

D-001 — Dedicated Fashion Studio를 만들지 않는다.  
Reason: spontaneous social flow를 끊기 때문. Catalog는 Main Social에서 계속 사용할 수 있어야 한다.

D-002 — Runway는 별도 Place로 검토한다.  
Reason: round-based server state가 Main Social과 다르다. Status: future candidate; current MVP dependency가 아니다.

D-003 — Club은 초기 소셜 경험의 핵심 공간으로 Main Social 내부에 둔다.  
Reason: 인구가 적을 때 별도 서버가 비어 보일 수 있고, 다른 공간과의 자연스러운 이동이 중요하다.

D-004 — Housing은 보류하며 현재 MVP 범위에서 제외한다.  
Reason: 집 외형/구조/가구/저장/방문은 별도 복잡도를 가지며 현재 핵심인 카탈로그 기반 아바타 꾸미기와 소셜 플레이를 검증하는 데 필수적이지 않다. 재검토 시 색·패턴 변경과 구조 편집·가구 배치를 분리한다.

D-005 — Current Outfit은 Roblox ownership과 다르다.  
Reason: 게임 내 임시 착용과 저장 코디는 Roblox 계정의 구매/소유권을 변경하지 않는다.

D-006 — Roblox 공식 API를 우선 사용한다.  
Reason: 지원 범위와 제한은 공식 문서 및 Studio 테스트로 검증한다.

D-007 — Building System과 Furniture Asset을 분리한다.  
Status: historical architecture decision for a possible future Housing system; it does not authorize Housing work in the current MVP.

D-008 — AI를 월드/에셋 제작에 활용하되 최종 품질과 gameplay는 직접 검수한다.

D-009 — SavedOutfits는 초기 최대 50개/사용자로 설정한다.  
Reason: product limit chosen for this game; it is not a Roblox platform recommendation. Unique outfitId is required even when names repeat.

D-010 — Partial restore skips only unavailable/unsupported Outfit entries.  
Reason: preserve the rest of the selected appearance and the original SavedOutfit. Do not delete or rewrite the saved record after partial restore.

D-011 — RunwayOutfit is temporary.  
Reason: after a future Runway round, ask explicitly whether to save the look; save only on affirmative confirmation.

D-012 — Current core priority is Catalog → Avatar Editor → SavedOutfits/Wardrobe → Club → Photo Spots → Playground interactions (revised 2026-10-19).  
Runway is a future candidate; Housing is deferred and furthest priority.

D-013 — Public photo gallery posting, likes, and public style-copy feed are out of current scope.  
Photo-taking and in-world inspection/manual catalog try-on are separate features.


D-013 — Plan Main Social as connected themed areas with local interactions.  
Reason: players should do something meaningful with their customized avatar in each area, not only use backdrops for photos. Status: concept plan; exact layout and implementation order remain subject to blockout and prototype testing.

D-014 — Dream Aquarium and Beach are proposed as connected spaces.  
Reason: underwater exploration should lead naturally to the surface and beach. A limited underwater duration/breath meter is a prototype candidate, not yet a final mechanic; test clear guidance, generous recovery and PC/mobile navigation.

D-015 — Fashion Week Backstage can be useful before Runway exists.  
Reason: use the dressing-room/green-room environment as a social exploration area first, then consider adding a portal when Runway is reprioritized. Camper, tent and building set design remain undecided until surrounding environment design.

D-016 — Whole-world art direction is undecided.  
Reason: Korean-inspired street/market details, American vintage, global pop-stage and fantasy elements should be compared via moodboards and blockout rather than assuming one theme has proven higher demand. No reliable comparative demand statistic has been established for this specific game concept.


D-017 — Separate whole-game development order from per-space construction order.
Reason: The game-wide sequence determines system dependencies and milestone priority; each space's document determines its local blockout, interaction, validation and art-polish sequence. Whole-map grayboxing can begin early without implementing every space in parallel.

D-018 — Korean-inspired visual details remain optional and undecided.
Reason: The user wants some Korean elements to be considered for selected spaces or as background details, but does not want a global Korean theme decided yet. Compare moodboards and graybox fit before promoting a motif to a space-level decision.


D-019 — SavedOutfits limit is 50 per user everywhere (2026-10-19).
Reason: user decision; earlier log entries that said 20 were errors and are corrected.

D-020 — Recent = every item successfully worn at least once in the session (2026-10-19).
Reason: user decision. An item worn and removed immediately stays in Recent. Viewing, search exposure, failed wear and Outfit restore do not add entries.

D-021 — Avatar Editor precedes SavedOutfits/Wardrobe and is free (2026-10-19).
Reason: players adjust accessories first and then save the adjusted look. VIP never gates editing or saving.

D-022 — Entry points (2026-10-19).
Compact catalog: ⚙ (Avatar Editor) and Wardrobe buttons follow 최근/인기/즐겨찾기/착용 중 in the discovery strip. ⚙ opens the expanded catalog in edit mode and reuses the existing avatar preview. Wardrobe shows a "save outfit" card plus saved outfits in the existing result-card layout.

D-023 — Recent is not persisted (2026-10-19).
Reason: user decision. Recent resets when the player leaves; it is never written to DataStore.

D-024 — Avatar Editor preview fallback (2026-10-19).
Preferred: client-only preview humanoid in the expanded catalog preview. If Studio testing shows that is not possible, use a server-built preview model visible only to that player. If that also fails, the KOYA approach is allowed: apply the draft to the live character while editing, and restore the confirmed baseline on Discard/close.

D-025 — Shoes are worn as a pair (2026-10-19).
Reason: user decision; Roblox sells shoes only as Shoes bundles. Wearing from a card puts on left + right together. The worn strip shows left and right as separate cards and each can be removed on its own. A new shoe replaces the shoe on the same side.

D-026 — Layer order is edited in the expanded worn strip (2026-10-19).
Reason: user decision, KOYA "의상 레이어" reference. Layered clothing is listed first, outermost (drawn on top) on the left, with a number badge; other worn items follow and are not draggable. Drag a layered card to a new position (mouse: move 6px; touch: hold 0.3s) → server `SetLayerOrder` (outermost first → WrapLayer.Order, higher = on top). New layered items get a default per-type order (shoes 2, pants 4, shorts 5, T-shirt 6, shirt 7, dress/skirt 8, sweater 9, jacket 10).

D-027 — Catalog button on the right of the top bar; phone compact = 1/4 width (2026-10-19).
Reason: user decision. Voice chat adds a top-bar button that covered the old left-anchored C button. On phones the minimized catalog covered half the screen and hid the avatar.

D-028 — Phone minimized catalog = 2/5 of screen width (2026-10-19, supersedes the 1/4 width in D-027).
Reason: user decision after testing; 1/4 was too small.

D-029 — Worn order everywhere (2026-10-19).
Worn strip and the 착용 중 card list share one order: layered clothing (outermost first, draggable) → other worn items → animation poses (innermost) → emotes (last). A layer drag in either view calls SetLayerOrder and both re-render from the same server snapshot.

D-030 — Favorites storage (2026-10-19).
In-game Favorites are stored per user in DataStore `FashionGamePlayerData` (key `u_<userId>`, field `favorites`, typed `{id, itemType Asset|Bundle, addedAt}`), cap 200 (configurable). Writes use UpdateAsync on autosave (60s), leave and server close. If the DataStore cannot load (e.g. Studio API access off) favorites work for the session only and the player is told.

D-031 — Avatar Editor scope follows official rules (2026-10-19).
Accessory adjust only for rule types (hat, face, neck, shoulder, front, back); body scales Height/Width/Head/Proportion/BodyType (no Depth); skin colours from BasicBodyColorsPalette; makeup order only. Limits are read from GetAvatarRules at runtime and enforced on the server.

D-032 — Wardrobe snapshot format (2026-10-19).
SavedOutfit = `{id (GUID), name (1–30 chars, trimmed, duplicates allowed), createdAt, snapshot}`. The snapshot is versioned (`v = 1`) and typed by section: `assets` (classic clothing, face, body parts, animations), `scales`, `colors` (hex), `accessories` (id, type, layered, order, puffiness, position/rotation/scale), `makeup` (id, type, order), `emotes` + `equipped`. It is built on the server from the applied description, so only Applied Avatar Editor values are saved. Outfit cards render a preview from the snapshot (not a screenshot).

D-033 — Wardrobe writes are confirmed before success (2026-10-19).
Save/delete write the DataStore immediately (UpdateAsync, 3 attempts; after an error, a fresh read checks whether the change landed). A failed write rolls the session change back and shows an error. When the DataStore is unavailable (Studio without API access, load failure) the Wardrobe works for the session and says so; it never overwrites stored data with an empty list.

D-034 — Restore replaces the whole look (2026-10-19).
Restore applies the saved description with ApplyDescriptionResetAsync inside the same per-player gate as wear/remove/editor Apply. Items that are not present afterwards are reported as skipped; the saved outfit is never changed. If the apply errors, the pre-restore look is re-applied.

D-035 — Catalog always reopens on the first screen (2026-10-19, updated 2026-10-20).
User decision: closing and reopening shows 전체/전체 in normal catalog mode with an empty keyword and default sort/filters, and always in the minimized layout (2026-10-20: previously the expanded/compact choice was kept).

D-036 — Animation preview plays once (2026-10-19).
User decision: wearing an animation or emote plays it once on the preview avatar, never looped. Catalog asset IDs are packages, so the server loads the package (InsertService) and returns the first clip, only for an animation the player is wearing. Mood animations are facial clips and do not play on the preview.

D-037 — Accessory axis guide and per-axis reset (2026-10-20).
User decision (KOYA reference): while an adjustable accessory is selected, the preview draws a ring per axis, a short axis line and a small x/y/z label, coloured x red / y green / z blue; the matching slider labels and fills use the same colours. Axes follow the body attachment the accessory is attached to. Each position/rotation slider has its own reset to 0, and size resets to 1. While the editor is open the preview clone always applies the draft (needed to locate the accessory part with GetAppliedInstance).

D-038 — ⚙ toggles the Avatar Editor; filter popup closes on outside press (2026-10-20).
User decision. Closing the editor with un-applied changes still asks Apply / Discard / keep editing.

D-039 — Body and head are worn as bundles (2026-10-20).
Roblox catalog search does not return wearable individual body parts, heads or classic faces (QA: Face search returns 0 even with off-sale). 전신 lists BodyParts bundles and 머리 lists DynamicHead bundles; the card's WEAR applies every supported part of the bundle in one apply (body parts, animations, accessories, makeup). WORN is decided by the bundle's core parts. Removing reverts each part to the one the character spawned with. 얼굴 shows "준비 중".

D-040 — Wear/Remove use typed identity (2026-10-20).
Clients send `{id, itemType = "Asset" | "Bundle"}`. Bare numbers are still accepted as Asset. Remove accepts Assets only (bundles are removed by their asset ids).

D-041 — Newest catalog request wins (2026-10-20).
A category/search click while a search or page is loading is no longer ignored; the older request's results are discarded (generation token).

D-042 — Outfit rename (2026-10-20).
Each outfit card has ✏️; rename keeps id, snapshot and date. Same name rules as save (1–30 chars, trimmed, duplicates allowed). The write is confirmed before success; a failed write rolls back.

D-043 — Club drinks are non-alcoholic; no private spaces (2026-10-20, confirmed by user 12:37).
Roblox content maturity: depicting alcohol makes an experience Restricted (age-verified 18+); romantic themes are 18+; social hangouts with private spaces (bedrooms, bathroom stalls, small tents) are age-verified 18+. Proposal: the club bar is a juice/mocktail counter, lounges/VIP/backstage are open (visible) areas. See `docs/03_CONTENT/REFERENCE_MASS_CLUB_ANALYSIS.md`.

D-044 — World layout option C (2026-10-20, approved by user 12:37; graybox test still required).
Hub (Central Plaza) + City Street loop + two anchors (Club north, Beach west), quiet Cafe south-west, Park east, Neon Rooftop stacked on the Club. Not final until the user approves and a graybox is tested. See `docs/02_WORLDS/MAIN_SOCIAL_LAYOUT_PROPOSAL.md`.

D-045 — Paid VIP area is allowed, with conditions (2026-10-20, user asked; conditions proposed).
A separate area that VIP Pass owners can enter is allowed. Conditions (Roblox content maturity: a private space is an enclosed space designed for personal/secluded activity — sleeping, changing clothes, bathing — for one or very few people):
1. Large and open, not a small room: a raised VIP balcony/deck in the Club that overlooks the dance floor and stage, visible from below (glass rail, open sides). Status is seen by others (MASS lesson).
2. No beds, bathrooms, changing rooms or small booths for one or two people inside it.
3. Access is checked on the server (GamePass ownership via MarketplaceService); non-owners are blocked by a server-side gate, never by a client-only check. A purchase in the session opens it without rejoining.
4. VIP gives a place and a view, not gameplay power over others (no kicking or blocking non-VIP players).
5. Non-VIP players get an equally good free view of the stage elsewhere; free Catalog/Wardrobe/Club features are unaffected.
Product price and benefits stay in MONETIZATION.md.

D-046 — Art direction: general modern city + one Hanok Village (2026-10-20, user decision).
The world looks like a general modern city (not a specific country). One district is a Hanok Village, placed south-east on the quiet side of the loop with its gate facing the street. Moodboard references and rules are in WORLD_STYLE.md. Housing's reserved plot moves east beyond the park.

D-047 — Graybox lives in a build script (2026-10-20).
Workspace geometry is not synced by Rojo, so the graybox is rebuilt from `tools/graybox/build_main_social_graybox.lua`. Layout changes are made in that script first, then run in Studio.

D-048 — Club dances are Roblox-made emotes (2026-10-20).
The MVP dance list uses only emotes created by Roblox (playable in any experience). Branded emotes (artists, films, TV) are excluded. 31 clips in two tabs: 댄스 / 포즈·응원.

D-049 — Dance state is server-owned, played by the dancer's client (2026-10-20).
The server sets character attributes DanceKey / DanceStart (server time) / DanceSpeed; the dancer's client plays the clip at the shared frame, and Animator replication shows it to others. 같이 추기 copies another dancer's key, start and speed, so both dance in sync. Tempo 0.5x–2.0x. Moving, jumping or sitting stops the dance.

D-050 — Club music is one shared playlist heard only in the club (2026-10-20).
Free Creator Store tracks from licensed distributors; one server-wide clock so everyone hears the same part; volume fades to zero within 45 studs outside the club zone; NOW PLAYING shows channel and title. No player-uploaded or broadcast music.

D-051 — Club is underground and rotated (2026-10-20, user decision).
Ground-level entrance facing the plaza → foyer → stairs down on the left (24 studs) → corridor → door → hall facing the DJ zone. VIP balcony north, lounge and juice bar south. Stairs have invisible ramps.

D-052 — DJ time is a consumable purchase, 30 minutes, one DJ per server (2026-10-20, length and price proposed).
Proposal: 30 min for 75 R$ (test 49–99). Current DJ buying again extends; others queue. Only the curated playlist can be played. Future DJ abilities register in DjService.Actions. See DJ_SYSTEM.md.

D-053 — Song requests when there is no DJ (2026-10-20).
Anyone may queue one song at a time (max 10 in the queue); requests play before the automatic playlist. When a DJ starts, open requests are cleared and only the DJ chooses.

D-054 — Drinks: bartender, bottles on tables, cups (2026-10-20, user decision).
Bartender menu: free 물/사이다/콜라, paid 환타 (6 R$ test product). A bottle is placed on a table with 모든 사람/친구만/나만; allowed players pour a cup; using the cup shows the drink motion with a gulp sound and removes the cup. Limits: 3 bottles carried, 2 cups, 6 cups per bottle, bottles cleared after 10 min or when the owner leaves. Brand names are test-only.

D-055 — Purchases go through MonetizationService (2026-10-20).
All Game Pass / Developer Product IDs live in MonetizationConfig. Receipts are granted once (PurchaseId recorded). ID 0 = not created yet: Studio shows a labelled test purchase, live servers grant nothing.

D-056 — 인생네컷 photo booth becomes the Stage 5 photo feature (2026-10-20, proposed).
See PHOTO_BOOTH.md. MVP free; paid frames/stickers/poses later.

(Restored 2026-10-21 from fb478f3; D-064/D-065 change parts of D-061–D-063.)

D-057 — Dancing keeps going while moving; dancing is club-only (2026-10-20, user decision; replaces the "moving stops the dance" part of D-049).
Walking and jumping no longer stop a dance. A dance ends with 멈추기, picking the same dance again, sitting, respawn, or leaving the club (1.5 s grace). The 💃 button shows only inside the club (hall + rooftop, parts tagged ClubInterior); the server rejects Start/Join outside.

D-058 — 같이 추기 is a live follow link (2026-10-20, user decision; MIDNIGHT PLAZA reference).
The follower copies the leader's dance and tempo on every change (also chains A→B→C; loops are refused). Touching the tempo, picking a dance, 해제 or 멈추기 ends the link (own dance). Players can tap/click another player in the club to open their card and 같이 추기; the panel's third tab lists nearby players.

D-059 — Map distances pulled in; Neon Rooftop is the club roof (2026-10-20, user decision).
Layout rev3: all distances in the LAYOUT table of the graybox script (re-tunable later). Spawn → club door 14.2 s → 11.1 s. The rooftop is the club building's roof (elevator pad by the red carpet), part of the club.

D-060 — 🎵 panel only for the DJ; DJ purchase moves the buyer to the booth (2026-10-20, user decision).
Non-DJs buy DJ time at the DJ zone gate. A new DJ (purchase or queued turn) is moved behind the booth at once. No-DJ song requests keep their server code but have no screen entry for now.

D-061 — DJ extension only with an empty queue; DJ zone for the DJ's guests (2026-10-20, user decision).
The current DJ can extend only while nobody waits (a racing purchase becomes a new queued turn, never lost). Besides the DJ, only players the DJ invites (🎵 panel 👥 초대 or the player card, max 6) can enter the DJ zone; invites end when the DJ changes.

D-062 — 같이 추기 해제 stops and waits; bottles keep their cups; LED pillars; quieter rooftop (2026-10-20, user decision).
해제 ends the link and stops the dance. Clearing your bottle with cups left returns a bottle tool with that count. Two round LED pillars beside the DJ zone show club-goers' avatar portraits in turn. Club music on the rooftop plays at 30 %.

D-063 — 인생네컷 photo booth P1 + group (2026-10-20, implements D-056 / PHOTO_BOOTH.md).
Server-owned sessions (booth, people, 8-shot clock, shot data); photos are stored as redraw data (outfit snapshot, stand-relative position, dance frame, props) in the player's album (max 30), redrawn client-side in ViewportFrames. MVP is free: 2 layouts, 3 join modes, 31 poses, 6 code-built props, 10 frames. Photo wall, stickers and paid packs come later.

D-064 — 인생네컷 rules + coin economy (2026-10-20, user decision; numbers proposed).
Album: 10 free slots (+10 per paid product). People stay inside the booth (invisible barrier) from start/join until they save or press 나가기; saving moves them out; poses stop after the last shot; ⏸ freezes the pose. Photos can be taken out as an inventory item and stuck on the photo wall (the print is used up; photos may overlap). Frames: 블랙/화이트 free, colours/pastels bought with coins, glossy/glitter Robux (Frame Pack). Coins: passive while active + activity bonuses, see ECONOMY.md.

D-065 — Club rev3: two floors, VIP-only 2nd floor around the edges (2026-10-20, user floor plan).
Hall floor -24, VIP floor -2, ceiling 36, rooftop deck 37. Centre open to the ceiling. DJ zone east with turntable console (click → DJ music window), LED wall, ceiling lasers (DJ 조명 on/off). Tables under the north VIP, bar under the south-east VIP, lounge south-west. Four round LED pillars at the atrium corners show club players, turning 360°. Neon edge on every stair step. Music: hall 1, corridor 0.45, stairs 0.12, outside silent. A DJ whose queued turn starts is asked OK / NO (NO passes the turn, no refund) instead of being moved.

D-066 — Fashion Week Backstage between the club and the 인생네컷 shop (2026-10-21).
Measured walk: spawn 13.1 s, photo shop 3.7 s, club door 7.9 s (the old west plot was 18.1 s from spawn). Open green room with mirrors, sofas, racks, FASHION WEEK photo wall; a "RUNWAY (준비 중)" arch leads to a future runway plot north of it. See FASHION_WEEK_BACKSTAGE.md §7.

D-067 — 📸 capture button: Roblox screenshot and 30 s video (2026-10-21, user request).
Top bar 📸 → 사진 / 동영상, using CaptureService (TakeScreenshotCaptureAsync, StartVideoCaptureAsync) and Roblox's own save prompt (Captures gallery). The 인생네컷 album button becomes 🖼.

D-068 — Cafe part-time job (2026-10-21, proposed, waiting for the user).
Short drink-making mini-game for players at the cafe counter; 6 coins per order, 15 a day at full pay; no authority over other players. See CAFE.md.

D-068 (update 2026-10-22) — Cafe part-time job: planned only, on hold (user). Reward draft: serve 4, clear table 2, 60 a day; replaces the 2026-10-21 proposal. Waits for the economy v2 balance. CAFE.md §9.

D-069 — Club rev4 layout from the user's 1F/2F plans (2026-10-22).
Hall level = 1F. Hall door in the middle of the corridor; the corridor ends at a red see-through VIP wall (neon VIP sign, same gate/purchase logic) with the VIP stair behind it; 2F is only the VIP U; centre, DJ zone and pillars open to the ceiling; south-west lounge → table zone; DJ deck turned to face the DJ; white chevron neon stairs. CLUB.md §17.

D-070 — LED pillars: two, floor to ceiling, twice as thick, live avatar (2026-10-22).
Panels show a live copy of the shown player (pose copied every frame). SurfaceGuis holding ViewportFrames live in PlayerGui (Adornee), because under a Workspace part they are not drawn.

D-071 — PARK rides on the shared clock (2026-10-22).
Ferris wheel (2 per gondola, board/leave near the bottom, 1st-person button), carousel (ride any horse), swings (+/− speed 0..5, max 35°), spring riders, slide (auto slide, "야호!"). Rides move on every client from GetServerTimeNow; the server only keeps seats. Open gondolas (no closed rooms). PARK.md §8.

D-072 — Three cafes with shared systems (2026-10-22).
Glasshouse (first, full test), Hanok fusion cafe, Sunset Beach kiosk. Shared order/seat/photo/job/building modules; differences are look, menu, mood. CAFE.md §8.

D-073 — Game name 오후 · OHU (2026-10-22).
OHU PHOTO / OHU CLUB / OHU CAFE; OHU as the shop name on signs. VISION.md.

D-074 — Economy v2 first test (2026-10-22).
1 coin per minute online regardless of activity, no first-login bonus, photo/dance/wall rewards off, no daily cap; XP (never spent, shown above the name) separate from the coin balance; test prices 30–60 / 60–120 / 120–180. Code still v1. ECONOMY.md.

D-075 — Beach: Terrain-water sea with real swimming, floating tubes (ride with E) and ducks, varied parasol groups with sittable chairs and mats, palms, ice cream truck (💰15 cones) (2026-10-22). BEACH.md §8.

D-076 — Shared snack/cafe system (SnackConfig/Service/Controller): counter prompt → menu → hand-held item → sip/lick, sit anywhere. First used by the ocean-view beach cafe (full-glass west wall, replaces the kiosk idea of D-072), the hanok cafe and the ice cream truck (2026-10-22). CAFE.md §10.

D-077 — Hanok village graybox from the user's references: flower walls, gate with cherry trees, stone alley, lotus pond with pavilion and arched bridge, fusion OHU 한옥카페 with persimmon courtyard, window-frame spot, stone-stair alley to a hill lookout (2026-10-22). HANOK_VILLAGE.md.

D-078 — XP: +1 per minute online, shown with the nickname above the head (2026-10-22). ECONOMY.md §6.

D-079 — 인생네컷: the host alone picks the 4 shots and the frame, others watch live; then everyone chooses copies (1 free, 💰20 each after, max 5) (2026-10-22). PHOTO_BOOTH.md §12.

D-080 — LED pillars show the live avatar from the front (camera-like), the picture scrolling around the pillar; Studio's negative test ids count as players (2026-10-22). CLUB.md §19.

D-081 — The 🏠 button may take a rider off the ferris wheel (or any ride) at any height (2026-10-22).

D-082 — Art assets from the Creator Store: show the user a shortlist first, place only after they choose (user, 2026-10-22). First temporary pick: Falling Blossom Cherry Tree for the hanok village. 야호 voice: audio 130278670102424 chosen by the user. Default play test = 2-player in phone emulation.

D-083 — XP locked (on hold), coins 1 per minute regardless of activity, no cap, activity bonuses off (user, 2026-10-22). Flags in EconomyConfig. ECONOMY.md §7.

D-084 — Graybox buildings are movable by the user in Studio; rebuilding a zone re-applies the user's moves (BuiltPivot), export_layout.lua copies them into LAYOUT_MOVES (2026-10-22). tools/graybox/LAYOUT.md.

D-085 — Product naming: SKU AREA-TYPE-NAME (PASS / DP); Roblox IDs are assigned by Roblox and only pasted in; list + add-item steps in PRODUCTS.md. IDs are registered after testing the basic items (user, 2026-10-22).

D-086 — Layout proposal v1 modelled on Hongdae around Hongik Univ. station: spawn in an underground station concourse; exits ① club street ② hanok village ③ Han-river beach ④ Gyeongui forest park → Yeonnam cafes → park rides; walking street (red road) with 인생네컷, playground square, fashion week. Waiting for the user's review (HONGDAE_LAYOUT.md).

Note — Club bottles: a sign "🍾 @username 테이블" shows above a table while that player's bought bottle is on it (user, 2026-10-22).

D-087 — Layout v2 by sun direction (user, 2026-10-22): in Roblox the sun rises at +X (east) and sets at -X (west), so north = +Z. Beach and beach cafe face the west sea (sunset); club north of the plaza with its entrance and neon toward the plaza, runway beside it; hanok village south-east with the gate facing south-east (morning sun); photo booth on the street east of the plaza. Applied temporarily in Studio (tools/graybox/hongdae_v1_temp.lua, revertible).

D-088 — Day/night cycle: DayNightController moves Lighting.ClockTime a little every frame from the shared server time (smooth, same sky for everyone). Live: 1 day = 20 min; Studio tests: 1 day = 1 min (DayNightConfig.TestInStudio). The user's earlier ServerScriptService day/night script is switched off in the place (renamed DayNight_old_꺼짐), since two scripts fight over the clock.

D-089 — Map orientation = the Studio top view the user draws on: screen up = -Z (north), right = +X (east). Sun east/west is unchanged (rises +X, sets -X over the sea). Layout v4 (user's drawing: roundabout with a lawn, asphalt roads, subway exits 1-4 at its corners, background buildings) was rebuilt north-south flipped after the user saw it upside down (user, 2026-10-22). Supersedes the 'north = +Z' note in D-087.

D-090 — Subway exits are pads: stepping on one asks '몇 번 출구로 가시겠습니까?' and moves the player next to the chosen exit (SubwayService, tag SubwayExit). Layout v4b: building sizes kept, gaps / road widths / roundabout at about 1/3 (user chose this over shrinking buildings, which would make them smaller than avatars). Hanok village gets a second (back) gate on the west; a background building between exit 2 and the village may become the prop shop (user, 2026-10-22).

D-091 — Streets follow the user's photo of 강남대로61길: big roads from the roundabout get 2 lanes + parking both sides with parked cars, raised sidewalks (0.6 step), crosswalks, utility poles, traffic lights; background buildings become high-rises of mixed height; a fake building that will get a function later is shown as a construction site (white hoarding with a blue line mural, crane, cones). The convenience store is a real building with automatic sliding doors and a counter (user, 2026-10-22).

D-092 — Beach cafe v2 follows the user's cafe video (Cafe Uijeongbu): a large glass box facing the west sea (90×90, 30 high, about 6× the old cafe) with a mezzanine, an indoor water pool with stepped seating (물멍), white sofas, grand piano, marble table, bakery and window bars; the west part stands on piles over the sea. Street details follow the user's Roblox city video: brick sidewalks with yellow tactile strips, street lamps, ground-floor shop signs, bus stop, club queue ropes / tent / neon, alley props; the convenience store gets a blue sign band, picnic tables and a half-lowered shutter (user, 2026-10-22).

D-093 — Layout v7 (user board + videos, 2026-10-22): the spawn roundabout becomes a 강남역-style crossroads; subway exits are real stair entrances coming up in the arrow direction, first spawn in front of exit 1; four bus stops teleport between each other (same picker, tag BusStop); the seafront copies 광안리 (road with a red lane, promenade with round pine planters, bollards, drains, 광안대교 in the sea); the hanok village west entrance is a 광화문 with a stone plaza, lawns and 해태, hills behind the village; the amusement park gets an Everland-style gate, ticket booth, info booth, perimeter wall and a round symbol plaza.

D-094 — Subway exits (user, 2026-10-22): the canopy slopes down toward the back; the pad is the landing at the bottom of the stairs (go down as if to the platform, arrive at the foot of the stairs and walk up). Cars = the 9 Creator Store designs the user approved (Genesis G80 Sport, G80, G70, KIA K7, Mercedes S500, Sports GT, Bloxai Voyage, Bord Bullet, Roat 500), one each, anchored with scripts and drive seats removed, 15 long (ServerStorage.Cars). Club entry bug: the ServerStorage map backup kept its VIP-region tags at the old position and threw players into the void — ClubAccessService only uses regions in Workspace, and the backup's tags are parked in the BackupTags attribute.

D-095 — DJ (user, 2026-10-22): the 🎵 top-bar button is removed; a '디제잉하기' prompt (E) at the turntable opens the music window (non-DJs see DJ purchase / requests) and, for the DJ, starts DJing (moved to the DJ spot, character attribute Djing; ends when they walk away or their time ends). While DJing every client poses the DJ with IKControls: right hand working the platter / mixer, left hand at the ear, head nodding (no animation asset). The DJ can pick a light colour (rainbow, magenta, UV purple, deep blue, cyan, red, green laser, white strobe; attribute ClubLightColor) besides lights on/off. On short (phone) screens the music window uses two columns so the song list is always visible.

D-096 — DJ visibility (user, 2026-10-22): on phones the DJ window is split into a left '디제잉' popup and a right '음악' popup so the DJ in the middle stays visible; a DJ lift raises the DJ so their waist meets the turntable (any body size, max 6); the big LED wall behind the booth shows club visuals and, during DJ time, the DJ live from the waist up (DJ can switch it off, attribute ClubDJScreen); the laptop moves to a side table at the crowd's left end.

D-097 — Club screens follow outfits (user, 2026-10-22): both round LED pillars show the same player (one shuffled order, 30 s each); the pillar and DJ LED wall copies are rebuilt ~0.4 s after the shown character's accessories/clothing/parts change (catalog try-on, wardrobe); the DJ lift now puts the DJ's hips (top of the upper legs) level with the turntable desk top (max 8). Popups start below the top-bar button row (TopBar.bottom()), also on phones where the Roblox inset is 0.
D-098 — One popup at a time (user, 2026-10-22): opening any window (catalog, album, 💃 dance, 🎵/DJ, 📸 menu, player card, photo wall picker, photo booth setup/result, snack menu, subway/bus picker, club shop window) closes the one that was open (`Popups.lua`: opened(name, close) / closed(name)). The catalog closes its avatar editor without asking. A photo booth shooting session itself is not closed.
D-099 — Cafe part-time job (user, 2026-10-22: "카페 알바 시스템 구현하자"; lifts the D-068 hold): the user's CAFE.md §9 draft — start/stop at the counter, player and NPC orders, make (2.5 s) → serve → clear the empty cup; serve 4 / clean 2 coins, 60 a day, server-checked; anti-farm gaps (same customer 2 min, one order per customer per 45 s). Beach cafe and hanok cafe. Details in CAFE.md §9.
D-100 — 알바 XP (user, 2026-10-22): part-time job XP is saved for good apart from the capped coins — 1 per serve, 1 per table cleared, no cap — in PlayerData `wallet.jobs.cafe = { xp, served, cleaned }`, as the base for job levels and level perks later.
D-101 — Club dress-code event (입뺀) (user, 2026-10-22): seasonal periods only (e.g. Christmas 12/23–12/25, KST), colours picked per event (two colours = either passes); a door guard checks one by one, greets or rejects ("드레스 코드가 맞지 않습니다." / "당신은 입뺀.") and bounces 3 studs back; inside, a 30 s warning that clears live when a matching item is put on, then out; VIP and DJ pass, a future club job gets its own staff entrance; 1-coin random colour item (catalog search, try-on only), re-roll for 1 coin; entry only, no reward. Item check = colour words in the item name/description. Built after the game is finished, together with the guard (the user makes the guard avatar). Spec: docs/01_SYSTEMS/CLUB_DRESS_CODE.md.
D-102 — Art direction (user, 2026-10-22): build every space as realistically as possible from the photos and videos the user sends (real places and venues), instead of choosing between Korean / global fantasy / pop-stage moodboards. References are kept in docs/04_ART/references/ with an index in docs/04_ART/REFERENCES.md; new ones are added there.
D-103 — Street dressing with real assets (user, 2026-10-22: realistic Creator Store assets for window facades, roads, Korean traffic lights, street lights, bus stops; sidewalks different from roads; round sidewalk corners; utility poles): tools/graybox/street_dress.lua dresses the whole street after hongdae_v1_temp.lua — asphalt MaterialVariant, grey paver sidewalks, granite curbs + tactile lines, rounded crossroads corners, Korean signal gantries, cobra-head street lights, modern bus shelters, grey concrete utility poles with wires, curtain-wall / office window textures. All scripts stripped from the inserted assets. Day/morning/night variants are not needed (the 24-hour cycle shows them).
D-104 — Street layout v7c (user, 2026-10-22, Seoul / Gwangalli photos): sidewalks = furniture strip + walkway (outer edge 47; the purple club street becomes sidewalk) with buildings set back (photo booth 12 north, club 6 north, hanok + Gwanghwamun 12 south, construction site / towers / store moved); yellow box junction with inward ticks; planting beds (granite frame, soil, shrubs, grass, a street tree in the middle); every other street light; thinner light poles, thicker utility poles; only the Genesis G70 / G80 car models; the beach 2.4 lower (sea 3 lower) with granite edge + wooden steps from the promenade.
D-105 — Hand edits of street props (user, 2026-10-22): the street containers are Folders so one click selects one prop; every generated prop (trees, shrubs, grass, planter beds, cars, street lights, utility poles, traffic lights, bus shelters) gets PropId (kind@x,z of where it was generated) + PropBase; tools/graybox/prop_save.lua records moves/deletes in ServerStorage.PropOverrides (and tools/graybox/prop_overrides.json), and both street scripts apply them on every rebuild. How-to: tools/graybox/LAYOUT.md.
D-106 — Subway entrance / bus stop from photos (user, 2026-10-22): subway exits get the curved-roof glass entrance (granite base, dark mullions, grey roof sweeping down to the base, yellow number pole); bus stops get the Seoul shelter (louvered glass roof, station header, two ad lightboxes + route map, glass bench) and a bus stop sign pole (green bus disc, black name panel, route board, 금연). The bus picker opens by clicking / tapping the sign (ClickDetector on the tagged BusStopSign) instead of stepping on a floor pad; subway exits keep the pad at the bottom of the stairs. Planting beds keep clear of bus stops; shrubs larger with stems sunk into the soil.
D-107 — Street cross-section from the 다산동 photo (user, 2026-10-22): road | granite curb | planting strip (beds 16 long, almost continuous, trees + shrubs, street lights at 29.5) | bike lane 31–35 (dark asphalt, white edges, bike symbols, broken at subway exits and bus stops) | sidewalk with grey rectangular pavers in a grid (texture 133933193561069, replaces the herringbone). The yellow tactile line along the sidewalk is removed. The bus stop sign is half size and stands at the curb on the road side.
D-108 — Beach / sign details (user, 2026-10-22): bus stop sign pole thinner and ending inside the (thicker) sign so it never shows in front of the panels, a thicker disc with a white bus icon filling it, the green 금연 plate removed; beach steps 3 tiers; promenade bollards and all beach / promenade trees are hand-editable props; every beach and promenade tree is the realistic fan palm (Creator Store 8626962700, Washingtonia) like the Gwangalli photo (the blocky graybox palms are parked in the hidden folder).
D-109 — Play area boundary (user, 2026-10-23, red line on the v7c map): invisible walls (150 high, CanQuery off so the camera passes) along the drawn polygon; outside, only what can be seen is built: a 기와 돌담 (granite plinth, cut-stone wall, dark tiled roof) around the east/south of the hanok village, fake shop buildings (stacked shop signs per floor, glass/stone facades) beyond the south road and north-east, the south road carrying on, and the beach / promenade / palms continuing north and south past the line.
D-110 — Boundary round 2 (user, 2026-10-23): the beach road is closed at z -300 (smaller play space between the beach and the park); the hanok village wall (granite base, red brick, slate coping) is continued along its north line to the east end of the map and along its west line south as a 돌담길 (replaces the giwa wall); the south road runs on to z 640 with trees, sidewalks and bike lane, shops set back on the beach side, an empty lot on the hanok side, the closing building removed; fake shops next to the club along the north road, and along the beach road south of the Glasshouse cafe; the beach steps continue to both ends.
D-111 — Official map (user, 2026-10-23): layout v7c with the boundary rounds (D-104..D-110) is the official map. The temporary script hongdae_v1_temp.lua becomes tools/graybox/build_hongdae_layout.lua (folder Workspace.Hongdae_Layout); the build order is graybox → layout → street_dress, with hand-edited props kept by prop_save.lua (tools/graybox/LAYOUT.md).
D-112 — Crossroads road markings by Korean rules (user, 2026-10-23, docs/04_ART/ROAD_MARKINGS.md): right-hand traffic (incoming lanes, arrows, stop line and cars on the right of each approach); crosswalks 12 wide (4 m); stop line 1.2 wide on the incoming half, 6 behind the crosswalk; white solid lane line (진로변경제한선) 40 before the stop line, dashed further out; arrows 9 behind the stop line and again 73 further; ◇ crosswalk-ahead marks 165 out on long roads; the median safety zone tapers into the double yellow centre line; one white dashed left-turn guide curve per approach that turns inside the junction centre (도로교통법 제25조), so opposite left turns do not cross. The box junction stays yellow (user photo).
D-113 — Street trees by Korean rules (user, 2026-10-23, docs/04_ART/STREET_TREES.md): trees 17.3 apart (≈ 5.9 m, rule 4–8 m), trunk 1 m from the curb (v 27), planting beds 4.4 wide (tree pit ≥ 1.5 m), first tree 4 m past the crosswalk, street lights in the bed gaps ≈ 3 m from trees and kept off subway exits, none at bus stops; the bike lane moves to v 29.2–33.2 to stay against the beds. The 직진·좌회전 arrow gets a proper left branch with its own head (the old detached bar). The user's two deletions move to the new ids (Tree@27,-170, Shrub@27,-173).
D-114 — Rules across the whole map (user, 2026-10-23): side streets get a single yellow solid centre line and stop lines; the seafront road a single yellow centre line, 12-wide crosswalks with stop lines, a T junction crosswalk + stop line at the west road, bike symbols on the red lane; promenade palms ≤ 8 m apart (23.5), clear of crosswalks, lamps halfway between palms (also past the boundary). The signal positions were checked against the Seoul signal installation guide (far side, right, 10–40 m past the stop line: ours 27.5 m) and kept; the asset's tan concrete foot is replaced by a flush steel base plate. Not changed, reported: lane width 2.7 m (< 3.0 m urban minimum). Beach facility and building rules are only reported (docs/04_ART/BEACH_RULES.md): lifeguard towers ≥ 3 m, showers / foot wash, changing rooms are proposals; building heights and setbacks already comply.
D-115 — 오후네컷 building (user photo 2026-10-23, docs/04_ART/PHOTO_BOOTH_BUILDING.md): the photo booth shop is a three-storey white-brick corner building on a granite plinth (whole zone 1.2 up, one step + invisible ramps), cut corner with pink-framed glass and an AutoDoor, pink-framed poster window on the north-road face, white tiles with four pill windows and a wooden deck on the east-road face, dark-framed windows above, roof parapet with railing. Shop name 오후네컷 / OHU4cuts with an aperture logo, sign style like the 인생네컷 sign (white raised letters, lavender sides). No beer signs (no alcohol). Booth labels say 오후네컷.
D-116 — Street fixes round 3 (user, 2026-10-23): one dark asphalt for every road (seafront road included); every sidewalk corner that points into a junction is rounded (T junction) and side-street mouths get concave rounded corners (CSG fillets); the seafront crosswalk moves right to the T junction edge; cars park along the curb (never at bus stops) in black / grey paint, and the G70 asset's duplicate second car is removed; street trees 8 m apart (the widest allowed) so buildings show; the signal foot is a dark steel base cover right under the pole (the collar no longer floats). 오후네컷: steps parallel to the cut corner, shop floor and plinth follow the corner, pill windows cut through the wall (CSG) with clear glass and a white rim, signs are 3D channel letters (white face, light grey sides, real shadows) for 오후네컷 / OHU4cuts with an aperture logo, the lavender SurfaceGui sign is gone. Lane width 3.0 m was only previewed (docs/04_ART/lane_width_compare_*.jpg), not applied.
D-117 — Bike lanes, beach facilities, birches (user, 2026-10-23): bike paths keep the pavement's own colour and are dark red (암적색) only where they meet crossings and junctions (자전거 이용시설 구조·시설 기준 제15조, 설치·관리 지침 2022); every crossroads crosswalk gets a 7-wide dark red 자전거횡단도 on its outer side (white side line on the far side only, stop line 6 behind it), linked to the sidewalk bike lanes; at the seafront T junction a crosswalk + bike crossing pair carries the west road's sidewalk bike lanes to the promenade-side bike lane (user photo). Street trees are the Creator Store birch pack (11351912067, scripts checked: none), six models mixed with varied size / turn, first tree 4 m past the bike crossing. Promenade palms removed (sand palms kept). Beach: 세족장 granite steps with taps + sticker + banner and a granite 음수대 (z -200..-180), blank rules board and map board (SignContent parts for the user's design), straw-parasol rest spots (brick pad, round table, two curved benches) replace the striped parasol groups. 오후네컷: ceiling 19 high, shop name one band lower over the doors, letters 1.0 deep. Development clock fixed at 14:00 (DayNightConfig.FixedClockTime = 14; set nil when the game is finished).
D-118 — Photo booth interior, black club, fixes (user, 2026-10-23): 오후네컷 interior from the user's interior photos — white grid-tile walls and grey-beige tile floor, a tiled booth wall with a mint arch per booth (curtain, PHOTO 01/02 plate), a photo machine in each booth (red base, white body, light panel and bars, LOOK HERE lens, screen, OHU band; its front stays behind CameraPoint so it never shows in photos, the old CameraProp is hidden), mint arch niches with white wire shelves of plush/hats (OHU 4 CUT PLAYGROUND), an Accessory arch with headbands, blue light boxes with neon tubes, pink notice posters, a bulb vanity mirror on a yellow acrylic table; the photo wall moves 2.3 south in front of the club wall that reached into the shop. Shop sign band lowered over the doors with the letters (0.8 deep), cornice at the old height. Club front black like the KING CLUB photos (cladding, louvres, black-framed windows, sign band OHU ♛ CLUB with a gold crown, gold portal and strips, iron fence; pink marquee hidden, rooftop rails/sign dark). Beach parasol groups back to the originals (straw spots dropped). No red bike paint on sidewalks (only the crossings on the road). Birch bark tinted brown (SurfaceAppearance.Color on the Overlay trunk meshes). Ceiling lights: plain panels + PointLights (Neon panels + Bloom washed the room out).
D-119 — Fixes round 5 (user, 2026-10-23): signals stand without the asset's concrete block (block removed, whole signal lowered 1 so the collar sits on the pavement); crosswalk spacing by 도로교통법 시행규칙 제11조 4호 (no crosswalk within 100 m on 집산·국지도로, 200 m elsewhere, of another one; junction crosswalks stay) → the seafront road keeps only the T junction pair and one crossing at z -400; the 오후네컷 brick starts right on the sign band (upper floors are a brick shell on the street faces, the shop ceiling stays high inside); promenade benches have the wooden top along the bench with two seats side by side; the club's red carpet, rope posts and queue ropes are removed (graybox ones parked in the hidden folder). The club photo wall (graybox PhotoWall + PhotoSpot) is a placeholder only, no script uses it.
D-120 — OH24 convenience store (user references 2026-10-23, docs/02_WORLDS/OH24_STORE.md): the convenience store is OH24, rebuilt from the references — GS25-like black stone front (OH white + 24 cyan logo, cyan light boxes, brown awning, full glass, auto door, diamond plate step, window bar with stools) and a full interior (tile floor, white grid ceiling with LED strips, teal band, 8 glass-door drink fridges, wall shelf, 3 double gondolas with end caps, counter with candy racks and a gift card / goods wall, warmer, open chilled case, ice cream chest, umbrella stand, mirror, promo poster). Goods come from Shared/OH24Products: fictional products (real brand packs are trademarks), each with an image slot for its own artwork; placeholders show colour + name until then. No tobacco or alcohol.
D-121 — OH24 v2 (user, 2026-10-23): the store grows into the empty land (x -146..-52, z 48..86) with wide aisles (5 gondolas 12 apart); the north, east and west street sides are all glass fronts with the same OH24 sign (light bars, logo, awning, step; door on the north); POS monitor turned to the cashier on the inner (east) side, customer display and card terminal on the customer side.
D-122 — OH24 v3 (user, 2026-10-23): the west side touches the 노래방 tower, so it is a plain wall (store x -126..-52) and the counter moves against it (staff between wall and counter); shelves hold one pack per product with wider gaps (727 packs, 1,442 parts, about half of v2).
D-123 — Performance (user, 2026-10-23): seafront curb drains removed (430 parts); OH24 shelf rows are one part + one picture each (OH24Products.ROW_IMAGES per category, placeholder tiles until designed): OH24 1,442 → 465 parts, 726 → 144 SurfaceGuis. Palm candidates P4 (6 parts) / P5 (3 parts) checked vs the current palm (67 parts); both carried hidden scripts (LightConfig etc.), stripped.
D-124 — Beach palms (user pick P4, 2026-10-23): California fan palm (Creator Store 130498222865089, 6 meshes, hidden scripts CoreTextureSystem/Script stripped) as ServerStorage.ArtAssets.PalmTreeP4 with the pivot at the trunk foot; each palm is placed by a raycast onto the sand and sunk 0.6 (the old palms floated 0.7–1). 14 palms: 938 → 84 parts.
D-125 — Bollards by rule (user, 2026-10-23): 111 stone bollards along the promenade → 9, only at the crosswalk curb drops where a car could enter (3 per crosswalk, 4.4 apart ≈ 1.5 m), 2.6 tall (80–100 cm), 0.5 wide (10–20 cm), plastic with a yellow reflective band (교통약자의 이동편의 증진법 시행규칙 기준: no stone, not in the middle of the walk). Streaming: with the default StreamOutBehavior (LowMemory) a smaller radius barely changes what a PC keeps (10–11k of 12k parts); set StreamOutBehavior = Opportunistic for the radius to unload far parts.
D-126 — Club / street edges (user, 2026-10-23): north, south and east roads run on to 1000 from the junction (past the play area: every other bed, bare beds, no lamps / bike symbols) with fake shop rows on their far sides, so no road end shows; the fake shops next to the club stand on the club's front line (x 48) against the sidewalk and run on to the map edge; the club moves 8 further north (CLUB_DZ -14) leaving a 6-stud alley to the 오후네컷 building; the club's photo wall, doorman box, white tent and clock board are gone; the rooftop lift is inside: the corridor right of the entrance runs on (the entry fill is cut back) to a steel lift car with a gold frame, an automatic door and the ElevatorPadUp on its floor (arrivals from the roof land in the corridor).
D-127 — Park gate, gaps, plans (user, 2026-10-23): the park's main gate is an ADVENTURELAND-style arch (two tall sandstone towers with carved panels, domes and gold spires, an arched band with the gold OHU LAND sign, lower outer towers with half arches, black iron fences); the 노래방 tower is 6 narrower so OH24 has a gap on its west side; the 소품샵 construction site moves to the empty lot east of the 오후네컷 building (x 116..156, z -96..-58). Plans (docs/04_ART/plans/plan_*.png) are drawn from the built map: export footprints in Edit mode, render with tools/graybox/render_plan.ps1.
D-128 — 오후네컷 front (user 2026-10-23): the west poster fills the face up to the sign band; inner door posts thinner than the outer frame; the outer frame has light panels tagged NightGlow (new NightGlowController: Neon + SurfaceLight from 18:00 to 06:00); the white sign band is taller (F+11.4..F+17.6) with the names at 2/3 size in its middle and a lavender neon halo behind every letter stroke; one wooden deck step (the old right-hand deck wood) runs along all three street faces instead of the granite ledge and two steps.
D-129 — 오후네컷 interior v2 (user plan + photos 2026-10-23): pink plaster walls (255,192,188) instead of white tiles, white tile floor with a grey diagonal grid, ceiling lights at 0.3 (ten lights at 1.2 blew the room out); west wall: two recessed arches (CSG), sky-blue inside with a lit rim, glass shelves of caps and plush, a pill mirror between them; booth wall: smaller gold-rimmed arches near each booth's north end, curtains gone; each booth now shoots north → south: CameraPoint on the north wall (photo machine there), Stand south of it facing it, Backdrop on the south wall, an ExitPoint outside the arch (PhotoBoothService.exitFor uses it); south wall: two arched make-up vanities between the capsule windows (white tiles, gold rim, bulb mirror, floating counter), pink liner with pill holes around the windows; a white oval table in the hall. Revert restores OrigSize and removes LayoutAdded parts.

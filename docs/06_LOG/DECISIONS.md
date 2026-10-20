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

D-057 – D-063 — Made in the other (Cowork) session on 2026-10-20; their docs were never written. Reconstructed from code comments: D-061 DJ zone is for the DJ and invited guests only, extension only while nobody waits; D-062 같이 추기 해제 stops and waits; D-063 인생네컷 flow is server-owned (PhotoBoothService). The rest are not known.

D-064 — 인생네컷 rules + coin economy (2026-10-20, user decision; numbers proposed).
Album: 10 free slots (+10 per paid product). People stay inside the booth (invisible barrier) from start/join until they save or press 나가기; saving moves them out; poses stop after the last shot; ⏸ freezes the pose. Photos can be taken out as an inventory item and stuck on the photo wall (the print is used up; photos may overlap). Frames: 블랙/화이트 free, colours/pastels bought with coins, glossy/glitter Robux (Frame Pack). Coins: passive while active + activity bonuses, see ECONOMY.md.

D-065 — Club rev3: two floors, VIP-only 2nd floor around the edges (2026-10-20, user floor plan).
Hall floor -24, VIP floor -2, ceiling 36, rooftop deck 37. Centre open to the ceiling. DJ zone east with turntable console (click → DJ music window), LED wall, ceiling lasers (DJ 조명 on/off). Tables under the north VIP, bar under the south-east VIP, lounge south-west. Four round LED pillars at the atrium corners show club players, turning 360°. Neon edge on every stair step. Music: hall 1, corridor 0.45, stairs 0.12, outside silent. A DJ whose queued turn starts is asked OK / NO (NO passes the turn, no refund) instead of being moved.

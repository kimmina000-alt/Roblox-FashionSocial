# Teleport System

## Current MVP
Main Social is the primary Place. The Catalog, Current Outfit and Photo/Club flows should work without leaving the social world. A separate Runway Place is a future candidate, not a current MVP dependency.

## Future Main → Runway
If Runway is approved after core experience validation:
- Use server-side TeleportService:TeleportAsync().
- Capture a server-validated appearance snapshot and validate it at the destination before applying.
- Do not put sensitive or authoritative state in TeleportData; use it only for lightweight non-sensitive context. Use appropriate server-side storage for state that must be trusted.
- Persistent data: DataStoreService. Temporary/frequent cross-server session data: consider MemoryStoreService only where justified.
- Define teleport failure, player disconnect, destination validation failure and appearance restoration behavior before release.
- After the round, restore the Main appearance according to the approved state contract and offer an explicit RunwayOutfit save confirmation.

## Testing
Teleport flows must be tested in a published Roblox experience with real clients. Do not mark transfer/restore as verified based only on local source inspection.

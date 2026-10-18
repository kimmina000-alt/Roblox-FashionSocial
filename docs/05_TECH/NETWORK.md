# Network

## Authority
Client = input/presentation and temporary untrusted drafts. Server = authoritative validation, applied avatar state, persistence and final operation results.

## Server Validation
- Catalog wear/remove requests and item type/ID.
- Current Outfit snapshot and SavedOutfit ownership/schema/content.
- Saved Outfit writes, limit (50 per user), byte size and request rate.
- Favorites and other persistent user records.
- Runway participation/voting/rewards only if that future feature is approved.
- Housing placement/permissions only if Housing is reprioritized.

## Appearance Action Gate
Wear, remove, Avatar Editor Apply and Saved Outfit restore share a per-player action gate. Reject concurrent follow-up appearance mutations rather than queuing stale requests. UI success state follows the server-confirmed applied result.

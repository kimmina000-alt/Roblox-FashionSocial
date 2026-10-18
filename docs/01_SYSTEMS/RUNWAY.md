# Runway System

Status: **Future candidate / deferred; not part of the current MVP.**

Runway may be a separate Place because its round-based server state differs from Main Social. Do not implement it before the Catalog, Saved Outfits, Club and Photo Spots core experience has been evaluated.

## Candidate Round Flow
WAITING → THEME → DRESSING → RUNWAY → VOTING → RESULT → REWARD → WAITING

The flow is a future design reference, not proof that the system is implemented.

## Appearance Lifecycle
- Main Social appearance A is captured through a server-validated snapshot and transferred through the approved server-side flow.
- Runway uses temporary RunwayOutfit B.
- At the end of the round, restore Main appearance A according to the verified transfer/restore contract.
- RunwayOutfit must not overwrite CurrentOutfit, an existing SavedOutfit, or Roblox platform ownership.

## Save Runway Outfit
After a round, show a confirmation: **“이 라운드의 코디를 저장하시겠습니까?”**
- Save: open the Saved Outfit naming/save flow and create a new SavedOutfit only after explicit confirmation.
- Do not save: discard the temporary RunwayOutfit when the session ends.
- Closing/canceling the confirmation means do not save.
- Never silently overwrite an existing saved Outfit.
- If save fails, show the cause-specific error and offer retry where appropriate; do not claim it was saved.

## Before Implementation
Define minimum player count, late join/leave behavior, theme selection, dressing time, voting eligibility, server-validated rewards, teleport failure recovery, outfit transfer integrity and restoration tests.

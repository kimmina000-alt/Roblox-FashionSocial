---
name: verify-walkable
description: "after moving or adding stairs/paths/floors, check collision and walk them in Play before reporting"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 07d430b0-67f6-4420-8c67-520056ed5aeb
  modified: 2026-10-24T09:48:02.195Z
---

When stairs, paths or floors are moved, resized or cut, update everything tied to them (collision, leftover ground, scraps at the edges), not only what is visible, then walk the character over them in Play (Humanoid:MoveTo, read the feet height) before reporting.

**Why:** 2026-10-24 the user found an invisible floor over the moved stair (CSG hull collision) and paving scraps blocking the widened walk; they called the work careless.

**How to apply:** for every geometry change a player walks on, think about how a person uses it (up/down, through), remove what the change leaves behind, and verify by walking. See [[testing-mobile-2p]].

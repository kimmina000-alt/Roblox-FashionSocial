---
name: testing-mobile-2p
description: "Default play test setup is the 2-player test in mobile (phone) emulation, since most players are on phones"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 07d430b0-67f6-4420-8c67-520056ed5aeb
  modified: 2026-10-21T15:10:09.768Z
---

Run play tests as the Studio 2-player test with phone emulation by default (user, 2026-10-22: "모바일로 더 많이 하니까").

**Why:** the user's players mostly play on phones; earlier PC-only tests missed mobile layout bugs.

**How to apply:** check layouts with screen_capture on each client; Studio phone emulation cannot inject taps reliably on top-bar buttons, so open UIs through remotes/server events when needed and ask the user to tap the rest on a real phone. Related: [[asset-candidates-first]].

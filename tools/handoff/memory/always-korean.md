---
name: always-korean
description: "Every reply to the user must be in Korean, without exception"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 02a2d7d8-2cdc-4b1a-a21e-1d7d7ea5d38d
  modified: 2026-10-27T11:42:51.343Z
---

Write every user-facing reply in Korean, every time, including short status lines and final reports.

**Why:** Replies sometimes slipped into English; the user had to ask "한글로 말해" again and again, which wastes their time and tokens (2026-10-27).

**How to apply:** Before sending any reply, check the language. Code comments, commit messages and DECISIONS.md stay in English as before; only what the user reads in chat is Korean.

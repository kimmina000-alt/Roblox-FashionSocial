# Photo System

## Goal
Photo Spots let players show off their catalog-styled avatars through distinctive compositions, lighting, poses and backgrounds. Photo-taking is an in-world activity, not a public gallery feature.

## Current MVP
- A small set of visually distinct photo locations.
- Intentional framing and lighting that keep the avatar visible.
- A small set of useful poses.
- Camera controls that remain usable on PC and mobile.
- Group-photo feasibility where it can be implemented without destabilizing the core camera flow.
- Clear entry/exit and interaction points at each spot.

## Photo Spot Design Contract
For each location, define:
- Visual theme and background
- Camera angle, framing and distance
- Lighting and any intended time-of-day treatment
- Suitable poses and interaction points
- How players enter/leave and how multiple players share the area
- Mobile camera visibility and accessibility

Candidate locations: Flower Garden, Sunset Beach, Cafe Window, Rooftop, Fountain, Moon Garden, Flower Tunnel and Mirror Room. These are candidates, not a commitment to build all of them in the first pass.

## Out of Scope
- Public in-game photo gallery posting
- Likes/reactions on posted photos
- Public style-copy feed
- House Garden as a dependency while Housing is deferred
- Runway Entrance as a dependency while Runway is deferred
- Advanced filters, extensive weather/time controls until the core photo flow is validated

## Photo Booth (2026-10-20)
The first photo feature is the 인생네컷 photo booth — see `PHOTO_BOOTH.md` (reference video analysis, MVP scope, data design, build order).

## 📸 Roblox 캡처 버튼 (2026-10-21, D-067)
상단 바 📸 → **📷 사진 / 🎥 동영상(최대 30초)**.
- 사진: `CaptureService:TakeScreenshotCaptureAsync`(게임 화면만, 우리 UI 제외) → Roblox "캡처 저장" 창.
- 동영상: `StartVideoCaptureAsync` → 위쪽에 빨간 "● REC 0:12 / 0:30" + [■ 정지]. 30초가 되면 Roblox가 자동으로 멈춘다 → 저장 창.
- 저장한 것은 Roblox **캡처(Captures)** 갤러리(게임 메뉴)에 들어가고, 거기서 기기 갤러리 저장·공유를 한다. 녹화 중에는 Roblox가 음성 채팅을 끈다.
- Studio에서는 Roblox 저장 창이 뜨지 않을 수 있다. 실제 기기에서 확인 필요.
- 인생네컷 사진첩 버튼은 📷 → 🖼 로 바꿨다(카메라 아이콘이 둘이면 헷갈림).
코드: `CameraController.client.lua`.

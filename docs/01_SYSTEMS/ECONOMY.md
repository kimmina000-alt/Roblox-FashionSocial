# Economy — in-game coins 🪙 (D-064, proposal 2026-10-21)

Numbers live in `src/ReplicatedStorage/FashionGame/Shared/EconomyConfig.lua`
(earning) and in `PhotoConfig.Frames[].coins` / `ClubConfig.Drinks[].coins`
(prices). Code: `EconomyService` (server), wallet in `PlayerDataService`
(`data.wallet = { coins, frames, slots, daily }`), HUD pill in `HudController`.

## 1. Model (user, 2026-10-20)
"Time spent earns a little; activities earn more." One soft currency: 코인.

| Source | Amount | Daily cap |
|---|---|---|
| Passive, while active (moved or danced in the last 3 min) | 2 / min | 120 min at 2, then 1 / min |
| 오늘 첫 접속 | 20 | 1 |
| 인생네컷 저장 | 15 | 5 (then 3) |
| 친구와 함께 찍기 (2+ people in the photo) | +10 | 5 |
| 클럽에서 5분 춤 | 5 | 12 |
| 포토월에 사진 붙이기 | 5 | 3 |

AFK players earn nothing (no movement or dance for 3 min).

## 2. Typical day
| Player | Play | Coins/day |
|---|---|---|
| Light | 15 min, 1 photo | 30 + 20 + 15 ≈ **65** |
| Normal | 40 min, 2 photos (1 group), 10 min dancing | 80 + 20 + 30 + 10 + 10 ≈ **150** |
| Heavy | 2 h, 5 photos, 30 min dancing, 3 wall posts | 240 + 20 + 75 + 30 + 30 + 15 ≈ **410** |

Hard ceiling per day ≈ 240 + 120 × 1 (4 h) + bonuses ≈ 600.

## 3. Prices (sinks)
| Item | Price | Normal player needs |
|---|---|---|
| 블랙 / 화이트 frame | free | — |
| 그레이 frame | 120 | < 1 day |
| Pastel frame (핑크·하늘·민트·레몬·라일락) | 200 each | ~1.3 days each, all 5 ≈ 1 week |
| 글로시 / 반짝이 frames | Robux only: Frame Pack Game Pass 99 R$ | — |
| 환타 (paid drink) | 6 R$ **or** 300 coins | 2 days |
| Album +10 slots (first 10 free) | Robux only: 25 R$ product | — |

## 4. Why these numbers
- **First unlock on day 1** (gray 120) keeps new players interested; pastels are a 1-week goal.
- **Drinks are deliberately expensive in coins** (300 = 2 days) so the 6 R$ option stays attractive (user request). A bottle is a consumable (6 cups), so the coin price works as a sink and stops inflation.
- **Premium looks (gloss/glitter) are Robux-only**, so coins never replace paid items.
- Balance cap 99,999. Add new sinks (stickers, props, poses, wall highlights) before raising income.

## 5. Open
- Tune after real play data (average session length, coins at day 7).
- Product/Pass IDs are still 0 (ISSUE-SHOP-001): FramePack, AlbumSlots, VIP, DJ, Drink_Fanta.

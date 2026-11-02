# Jarful version 2 plan (branch `version-2`, from v0.3.2-alpha)

## Why
A design review on 2026-11-02 (game-design skill) found four problems, all measured:
- **Room 1 is too hard for a first room.** Its first level has words that read as another group ("Orchard" in
  *On a farm* next to *Parts of a tree*; "Hoot" and "Howl" in *Ways to laugh* next to a farm group). Herrings start
  at L7 although DESIGN.md says L21. A "Words after X" group appears at L5 with no teaching, and 17 of 30 levels
  carry one. The bots can't see any of this: levels 1–10 can't be lost, and a bot "knows" a category or doesn't.
- **Busywork after the aha.** Late boards need 11–18 moves after the player knows every group (target 8 or fewer).
- **The economy splits.** Free players get 51–67% of the Hints they want late; ad players end on about 7,600 coins
  with nothing to spend them on.
- **Difficulty is invisible.** Levels are tagged tricky and hard in the data, but the player is never told.

The ethics line in `docs/plan-m3.md` §1 stands: no energy, no timers, no hidden difficulty changes, no selling at
the moment of failure.

## Rules for every step
- One step, one commit on `version-2`. `main` stays as it is until a tested release.
- After each step: GUT tests, the level tools (`check_levels`, `audit_content`, `curve_report`) and phone-size
  screenshots of what changed.
- Level ids are kept, so progress survives. A save-format change gets a migration and a test.
- A half-played level resumes only if its content (fingerprint) and the rules version both match; otherwise it
  starts fresh.

## Steps
| # | Change | Reason | Check |
|---|---|---|---|
| 0 | This plan; baseline recorded | Something to measure against | 76 tests, 0 curve misses, audit 0 errors, economy gates pass |
| 1 | Re-make Room 1 (data only) | First impression; see Why | check_levels, audit of every room, curve, word review |
| 2 | Tutorial hand no longer covers the card under it | It hides a word the player needs | screenshot |
| 3 | `pour` on; rules version in the saved board | Cuts busywork; safe resume | tests, bot sims (moves after the aha) |
| 4 | One-tap move (decided after measuring 3) | Only if 3 isn't enough | bot sims |
| 5 | Tricky and Hard badges with their bonus coins | Failing a marked hard level feels fair; a win feels earned | screenshots |
| 6 | "Next up" line on the Win card | Curiosity pulls the next level without a timer | screenshot |
| 7 | Room finale preview on the last 3 levels of a room | A visible finish line | screenshot |
| 8 | Help ladder: the third fail starts one label at step 2 | A stuck player sees a way forward; shown openly, gold withheld | tests incl. resume |
| 9 | Release 0.4.0-alpha (version code 7) | Something to playtest | APK audit |
| 10 | Playtest with 5–10 people (Mehul runs it) | The bot is tuned on guesses | slips per level |
| 11 | Fit the bot to people; re-budget Rooms 2–17 | Budgets and gold from real play | curve report |
| 12 | Rank from jars filled; friends cut from v1.0 | One progress number you can see on the shelf | save migration test |
| 13 | Late-room coins up; a looks shop as the coin sink | Fixes both ends of the economy | economy sim gates |
| 14 | Jar of the Day with a share card | Daily reason to return; word of mouth | tests, bake checks |

Steps 10 and 11 need people. Steps 12–14 change saves and the economy, so they wait for the calibration in 11
where they depend on it.

## Status
| # | Outcome |
|---|---|
| 0 | Done. |
| 1 | Done. Room 1 averages 0.4 / 0.6 / 0.8 slips (normal / tricky / hard), was 0.6 / 0.7 / 1.0; the novice bot wins every level at least 76% (was 62%). room_gen gained `avoid_cats`, `avoid_words`, `pin`, `strict` and `min_budget`. Bank: Chlorine is an element. |
| 2 | Done. The hand covers at most the last letter of a long word below. |
| 3 | **Pour rejected by measurement.** On Room 14 it made the human-like bot loop: win rates fell by up to 50 points, moves rose from 30–100 to 200–450. Forced pour also broke the Hint walk on 10 levels; a pour limited to the run's own stack still collapsed the bot. Pour stays off. Kept: resume checks the rules an attempt was played under; Tidy plays solver paths as single moves. |
| 4 | Dropped: no measured case, and it can't touch moves whose destination isn't proven. Busywork moves to step 11: re-deal with a stronger long-tail penalty in settle (`after_med` is measured with no slip limit; `tools/sim.gd` applies the budget, so its after-aha column isn't comparable). |
| 5–7 | Done: peppers (`SpiceMark`), the Next button's label, the finale line. |
| 8 | Done: the head start after three fails; both rungs are announced. |
| 9 | 0.4.0-alpha (version code 7). |
| 13 (part) | Economy review (2026-11-02): first-solve coins now rise +2 a room (was +1). Free players get 86% of the Hints they want (was 73%; late rooms 68–74%, was 55–66%). A cap on "x2 coins" ads was tested and rejected: with a realistic ad player (stops watching above 1,500 coins), it cut ad views by about a fifth for no gain. economy_sim now models that player, reports ads watched a day, and gates on coins keeping their value late. Ad views are limited by what coins can buy, so the looks shop is the income lever; starter pack and Supporter are proposed with it. |

# UX research for M2 (2026-10-30)

A condensed version of a web-research pass on 2024–2026 casual puzzle UX: Royal Match, Two Dots, Magic Sort and
the water-sort games, Wordscapes, NYT Games, Block Blast, plus the Material, Apple HIG, NN/g and WCAG guidance.
Canvas units (u) are on the 720-wide base canvas, and 1 dp ≈ 1.8 u. Points marked *heuristic* are industry
practice, not a cited standard.

## Home
- **One dominant action:** a "Level N" pill about 65–70% of the screen wide and at least 104 u tall, centred in the
  bottom third (Royal Match, wandr.studio).
- **Corners:** rarely used things (settings, currency) go in the top corners. Edge targets need to be bigger
  (11–12 mm) than centre ones (about 7 mm) (Hoober, NN/g).
- **Show progress as a place, with empty slots.** Two Dots greys out the postcards still to come, and Royal Match's
  A/B test kept its area meta over "just a button".
- **Daily card:** second in importance, placed above Play, with the streak and today's state (NYT Games).
- **How to play** stays reachable after the tutorial (Apple onboarding guidance).
- **Crafted means** one hero scene per chapter, and rewards that fly to where they're kept.

## Onboarding
- **Start straight in:** no splash screens or menus first. Teach through play, one mechanic per step, with tips
  shown next to the thing they're about. Text is minimal, and no button is forced.
- **Tutorial completion** is healthy at 70–80%. Measure each step as a funnel.
- **Hand pointer** (*heuristic*):
  - shown only the first time a gesture appears;
  - loops every 1.2–1.5 s;
  - spotlights the source and target, with the rest dimmed 40–60%;
  - hides on the first touch, and comes back after about 10 s idle.
- **Sort games:** teach tap→tap first and drag second. After a failure, make the retry slightly easier.

## Drag and tap feel
- **Both gestures:** support tap→tap and drag. WCAG 2.5.7 requires a single-pointer alternative to dragging, and
  tap is the sort-genre convention.
- **Threshold:** about 10 u.
- **On press:**
  - respond in under 50 ms;
  - scale to 1.05–1.08 and grow the shadow;
  - draw the card above its neighbours.
- **Dragged card:** keep it 32–48 u above the touch point, never under the thumb.
- **Drop zones:** each jar's zone is its whole column, choosing the nearest jar. Highlight one target, and only
  while a card hovers over it. The highlight means "this jar has room", never "this is the right group".
- **Cancel:** fly back to the source in 150–250 ms, visibly different from the slip bounce.
- **Snap:** 150–200 ms with emphasised-decelerate easing, `cubic-bezier(0.05, 0.7, 0.1, 1)`.
- **Never block input during animation.** Buffer the next move.
- **Haptics:** crisp 10–20 ms ticks, the same haptic for the same action everywhere.

## Popups
- **Scrim tap cancels utility popups:** Pause, Settings, How to play, booster info.
- **Results need an explicit button:** Win, Lose, Chapter complete, Daily result.
- **A visible × as well,** top right, with an 88 u hit area. Never an × and a "Close" button together. Back closes
  the topmost popup. Never stack popups.
- **Motion:** enter 250–300 ms decelerating, exit 150–200 ms accelerating. The scrim is about 32% Ink.
- **Containers:** utilities as bottom sheets with a handle; celebrations as centred cards that grow from 0.92 to 1.
- **Corners:** large containers use a 28 dp (≈48 u) radius.

## Progression and meta
- **A light meta beats none.** Water-sort clones reach 40–50% D1 but under 10% D30 because their meta is weak.
- **Collections and reveals drive the sort-game leaders** (Sand Loop, Solitaire Associations Journey). The Pantry
  shelves fit this.
- **Rewards fly to their destination**, and each chapter gets its own place, as Two Dots does with its
  environments.
- **Help can be earned through play,** like Strands' hint after every 3 extra words.

## Visual craft
- **Polish is the revenue gap in sort games.** Magic Sort is the same core as the template water-sorts, with
  premium polish on top (Deconstructor of Fun, 2026).
- **Build a system, not a pile of assets.** Every value comes from a token.
- **Radii:** 8, 14, 22, 28 and 48 u. A nested shape uses the outer radius minus the padding.
- **Depth:**
  - one light direction and 2–3 elevation levels;
  - buttons get a darker 4–8 u bottom lip that compresses on press;
  - layered soft shadows instead of borders.
- **Press:** scale to 0.95–0.97 over about 120 ms. Disabled buttons never scale.
- **Type scale (u):**

  | Size | Use |
  |---|---|
  | 22 | minimum |
  | 26 | labels |
  | 30 | body |
  | 36 | cards and titles |
  | 44 | headings |
  | 56 | "Level N" |
  | 72 | hero numbers |
  | 96 | celebration |

- **Spacing:** a 4 u base with steps of 4, 8, 12, 16, 24, 32, 48, 64 and 96, and 32 u side gutters.
- **Idle motion:** slow and low-amplitude, never gratuitous.

## Accessibility
- **Contrast** (4.5:1 for text): Ink on Paper 12.5, Paprika on Paper 5.6, Teal on Paper 5.5, Ink on Apricot 5.5.
  **Apricot on Paper is 2.3** (decoration only) and **Ink on Teal is 2.3** (use Paper on Teal).
- **Targets:** at least 88 u. Colour is never the only cue.
- **Reduce motion:** swap slides for fades and drop repetitive motion. **Large text:** offer at least an option.
- **Avoid** hold-to-act, popups that close on a timer, and background motion you can't turn off.

## From the vetted design skills (frontend-design, game-design)
- **The generated-look trap:** our palette (cream paper plus a terracotta-like paprika) is the commonest
  "AI-default" look, and adding a high-contrast serif display face completes it. Keep Mehul's colours, but put the
  distinctiveness into the material world (glass, wood, kraft labels, lids), not a serif title font.
- **Other tells to avoid:**
  - "A · B · C" middle-dot stat strings (the current Win popup);
  - ALL-CAPS labels;
  - monospace for small labels;
  - one identical card, radius and shadow on everything.
- **Spend boldness in one place:** the jar and lid moment. Keep everything around it quiet.
- **Motion budget:** a transition that plays hundreds of times (a level win) must stay short and skippable.
- **Onboarding shape:** introduce → develop → twist → test.

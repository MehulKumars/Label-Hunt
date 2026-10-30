# M2 plan: Home, tutorial, progression and a crafted look (draft 3, reviewed)

Written after Mehul's first phone playtest of v0.1.0 (2026-10-30).
- **Supersedes:** the M2 section of the approved plan, and pulls part of M3a (Room 1 content) and M3b (the art
  direction) forward.
- **Inputs:** `docs/research-ux.md` (web research plus the vetted design skills) and `docs/DESIGN.md`.
- **Review:** an independent adversarial review of draft 2; its fixes are folded in below.

## What Mehul asked for, and where each ask lands
| Ask | Answer in this plan |
|---|---|
| A real Home page, designed properly | Home with a pantry cabinet hero, a wordmark and one dominant Play pill (§3) |
| A separate first-launch tutorial plus a guide button that replays 2–3 levels | 3 interactive boards, skippable, replayable from Home's How to play (§4) |
| Popups close without hunting for a button | **Done** (c964f34): × button, outside tap, Back. Results need an explicit choice. |
| UI/UX and art that look crafted | Style frames approved first, SVG material art, one token system (§2) |
| Drag that follows the finger | **Done** (c964f34, b7c879d): the card rides above the fingertip and drops into the jar under it |
| Proper progression | A sawtooth Room 1 of 30 levels, layered jars on shelves, gold lids, room reveal (§5) |
| Vetted Claude skills | `tools/install_skills.sh`, pinned to the reviewed commits (Mehul runs it) |

## 1. What's wrong now (critique plus review)
- **Outlines.** 2–3 px ink outlines on everything make it read as a wireframe; cards look like form fields in a box
  (INSET 9 u, so there's no visible glass beside the cards).
- **Flat jars and thin shelves.** The Courier title looks like debug text. The rail's dashed blanks look like
  empty inputs.
- **Dead band:** a wide strip above the board on 20:9 phones, because `BoardLayout` caps jar height (ASPECT 1.45,
  MAX_CARD_H 70) even on 1–2-row boards.
- **Win** is a dim screen and a box with a "0 slips · 2 moves · 2.7s" stat string.
- **Level order** (verified in `reports/sim_handmade.md`):
  - t04–t10 are seven interchangeable 3-group boards that every bot wins 100% of the time;
  - then m01–m08 jump to 5 groups, a budget, frost and labelled jars;
  - DESIGN schedules those ideas at L11–L96.
  - The result is no curve, then a wall.

## 2. Visual direction: "a sunlit pantry", decided by style frames
- **One stylised look.** Flat shapes with 2–3-tone gradients per material, one light from the top left, soft
  shadows. No noise or grain on small items, and no mixing of pseudo-real texture with flat UI.
- **Spend boldness in one place: the jar.** The lid screws on, the label letters itself in, and the jar joins its
  shelf. Everything around that stays quiet.
- **Avoid the generated-look trap.** Cream with a terracotta accent plus a serif display face is the commonest
  default. Mehul's palette stays, so the distinctiveness comes from the materials (glass, lids, labels, cabinet)
  and not from a title font. The other tells to avoid:
  - middle-dot stat strings;
  - ALL-CAPS labels;
  - monospace small labels;
  - one identical radius and shadow on everything.
- **Art is hand-written SVG; code does layout, text and motion.**
  - Material assets live in `assets/art/*.svg` with linear and radial gradients:
    - the jar back (glass tint) and jar front (rim, neck, highlights, edge);
    - lid, cork, label, shelf plank, the cabinet, the wordmark and icons.
  - They are rasterised at device scale with `Image.load_svg_from_string` (ThorVG, antialiased; `draw_polygon` has
    no AA).
  - Jar height stretches via NinePatch-style slicing.
  - ThorVG ignores SVG filters, so shadows are gradient shapes in the SVG.
  - A small `ArtCache` keys rasters by asset, size and colour.
  - The back/front jar layering stays: the glass tint and a streak are drawn **over** the cards.
- **Tokens** (`src/ui/style.gd` only; screens hold no raw numbers):
  - **Colour:** palette plus derived tones. Never Apricot text; Paper on Teal.
  - **Type scale:** 22 · 26 · 30 · 36 · 44 · 56 · 72 · 96.
  - **Spacing:** 4-unit grid, gutter 32.
  - **Radii:** 8 / 14 / 22 / 28 / 48.
  - **Elevation:** e1 / e2 / e3.
  - **Motion:** enter 250–300 ms, exit 150–200 ms, press 0.96 over 120 ms, snap 150–200 ms.
  - **Targets:** at least 88 u, and at least 104 u for primary buttons.
- **Type.**
  - **Atkinson Hyperlegible Next** for everything that's read during play, including the label rail, whose hints
    are the puzzle's key information.
  - **One hand-lettered OFL face** for *solved* labels only (lids, jar labels, pantry): Patrick Hand, Kalam or
    Gochi Hand, picked from a type-lab frame. Minimum 26 u, and no Caveat.
  - Rail blanks are drawn as shapes, not underscores. Courier Prime is retired.
- **Board layout fixes.**
  - Visible glass on both sides of the cards.
  - 1–2-row boards grow to use the height.
  - The rail docks as a **single ledge** just above the board, so rail and board read as one cabinet (no hanging
    strings). Tested with the 6-group worst case at 720×1280.

## 3. Screens and flow
**Boot:**
- **First launch:** the first tutorial board within about 5 s.
- **Later launches:** Home, where the Play pill reads "Continue · Level 13" when a board was in progress. No
  resume prompt.

**Home:**
- A **wordmark** at the top.
- A **full-bleed cabinet hero** for the current room: 3 shelves × 10 jar slots, one slot per level. Each solved
  level shows its jar, layered with one colour band per category solved there and a gold lid for a clean solve.
  Slot 10 of each shelf is a larger "hard" jar. Future slots are faint outlines. A plain progress line names the
  room and the count ("The Larder, 12 of 30").
- **Corners:** settings at top left. Nothing at top right until coins exist (no ★ total without a use).
- **Row above Play:** How to play (replays the interactive tutorial) and the Room view.
- **Play** is one dominant pill in the bottom third, gently breathing.

```
┌──────────────────────────────┐
│ ⚙                            │
│          J a r f u l         │  SVG wordmark
│ ┌──────────────────────────┐ │
│ │ ▣▣▣▣▣▣▣▣▣▣  shelf 1       │ │  layered jars, gold lids for clean solves,
│ │ ▣▣░░░░░░░░  shelf 2       │ │  faint outlines for levels to come
│ │ ░░░░░░░░░░  shelf 3       │ │
│ └──────────────────────────┘ │
│   The Larder, 12 of 30       │
│  [?] How to play  [▦] Room   │
│ ╭──────────────────────────╮ │
│ │   ▶  Continue · Level 13 │ │
│ ╰──────────────────────────╯ │
└──────────────────────────────┘
```

**Room view** (Levels and Pantry merged into one screen): the same cabinet, large. Tap a jar to see its level
number, its categories (each with its four words) and a Replay button.

**Play:**
- Top bar: Pause, "Level 13", then the slip jars.
- The rail ledge, then the board, then the bottom bar of labelled tools: Undo, Peek, +Jar, Tidy up.
- Captions are speech bubbles that point at what they describe.

**Win.** Times run from t=0, when the last card lands:
- **0–300 ms:** the lid screws on.
- **300–700 ms:** the label letters in.
- **700–1000 ms:** the jars hop once.
- **By 1200 ms:** a centred card shows the room's shelf strip, and this level's layered jar drops into its slot,
  plus one plain sentence ("Clean sort: gold lid.").
- **Buttons:** **Next** (primary), **Home** (small).
- **Input:** a tap anywhere skips straight to the buttons. An outside tap after that nudges Next instead of doing
  nothing.
- **Playtest flags:** small chips (test builds only).

**Lose:** "Out of slips". **Retry** is primary; **Continue +2 slips** is secondary and goes through `AdService`
(mock); **Home** is text only.

**Pause** (a bottom sheet):
- Resume, Restart, Home, and the Sound / Haptics / Reduce motion toggles.
- **Rules**, which opens a one-screen illustrated rules sheet. The interactive tutorial is never started mid-level.

**Settings** (from Home):
- Sound, Haptics, Reduce motion.
- How to play, Credits, Privacy.
- The version number, which opens the test menu after 5 taps.
- The 8 old test boards move into the test menu.

**Back** is a pure state machine with tests:
1. A lifted card goes down first.
2. The top sheet closes. On Win and Lose, Back goes Home.
3. Play opens Pause; the tutorial opens a Skip sheet; Room goes to Home.
4. Home backgrounds the app.

**Transitions** take 250 ms and never block input. **Ads** move behind an `AdService` interface with a
`MockAdProvider`: rewarded and opt-in, no interstitials.

## 4. Tutorial (first launch; replay from Home and Settings)
Three boards, about 90 s, shaped introduce → develop → twist, with Level 1 as the test. The spotlighted hand
pointer dims the rest of the board by about 50%, hides on the first touch, and comes back after 10 s idle.
1. **Tap, tap.** 2 obvious groups, 3 jars. The first lid screws on and its label letters in.
2. **Drag and dig.** Drag a card into the empty jar to free the one underneath.
3. **A wrong drop is a clue.** The board has no empty jar, and every top card is from a different group, so the
   first move is naturally a slip. No forced mistake. The card bounces, gets a tag, and a hint appears on the
   ledge.

**Then:** "You're ready", and Home, where the tutorial's three layered jars already sit on a starter shelf.

**Robustness:**
- Back opens a sheet with **Skip tutorial**.
- If the app is killed, it resumes at the same tutorial board.
- Replays never touch progress.

**Funnel log:** the playtest log records first-move time, each board's time and any skips.

## 5. Progression and content
- **Room 1 ("The Larder"): 30 levels following DESIGN's sawtooth.** In each pack of 10, levels 1–4 rise, level 5
  is tricky, level 6 is a rest level that brings in the new idea, levels 7–9 rise and level 10 is hard.
  - L1–10: no budget, 2→3 groups.
    - Undo is introduced at L2, +Jar at L4, the gentle herring at L7 and Peek at L8.
    - These use the best of t04–t10, re-dealt.
  - L11: the slip budget arrives.
  - L16: 4 groups.
  - L26: regular herrings.
  - Each level is checked by `check_levels` (unique cover, solvable, no adjacent pairs) and simulated by `sim`
    against the target bands. The report goes to `reports/`.
- **How the content gets built.** It starts **in parallel at step 0**.
  - The categories go into `data/bank/categories.csv`.
  - A small headless `tools/room_gen.gd` picks categories with reuse caps and a phantom check, then deals, solves
    and simulates.
  - Fallback: hand-author L11–30 in `handmade.json` with the same checks. Room 1 is complete either way.
  - The full ~60-level pipeline (Room 2) is a stretch goal; otherwise it moves to M3a.
- **Level identity.**
  - Progress is keyed by a stable **level id**, never an index.
  - Levels carry a data-driven `introduces` field, which replaces `index >= 2/4/7` in `play_screen.gd`.
  - The save migrates v1 → v2 (`tutorial_done` = true if the old level index was above 2), with a test.
- **Gold lid** (one mastery mark per level, from L11):
  - Earned by solving within that level's clean threshold, which is set from the average bot's p25 slips. Herring
    luck can't be required.
  - Peek and +Jar don't affect it; Continue rules it out.
  - L1–10 have none, because slips there are lessons.
  - No global ★ counter.
- **Room complete:** a reveal of the full cabinet with an explicit Continue, after which the next room's cabinet
  appears (Room 2 opens when its levels exist).
- **Save v2:**
  - level ids solved and gold lids;
  - `tutorial_done` and the tutorial board in progress;
  - settings;
  - the exact in-progress board, keyed by the level fingerprint and saved after every move.
- **Deferred to M2b, with no placeholders:** the daily (Jar of the Day) and coins.

## 6. Sound
- New UI sounds (screen whoosh, button tap, jar onto shelf, gold lid) are synthesised the same way as now.
- A music bed and Kenney packs wait for Mehul's manual download (optional ask). Otherwise they move to M3b.

## 7. Build order
**Step 0** (style-independent logic, tests first, alongside the content track):
- Router plus screen transitions;
- the Back state machine;
- Save v2 with its migration;
- the progression model (ids, `introduces`, gold-lid thresholds);
- tutorial gating;
- `AdService`.

**Steps 1–6:**
1. **Style frames:** 3 in-engine frames at 1080×2400 (Home, mid-game Play, Win) built from the SVG art, plus the
   type-lab frame. **Mehul OKs the look from screenshots** before the kit is rewritten. This is a quick reply, and
   step 0 carries on meanwhile.
2. **Kit and board art:** tokens, Button, IconButton, Sheet (bottom and centred), ArtCache, card, jar, shelf,
   rail ledge, layout fixes. Re-shoot every scenario.
3. **Screens:** Play, Win, Lose and Pause in the new style; Home, Room and Settings; the tutorial.
4. **Alpha APK (v0.2.0-alpha)** with Home, the tutorial and Play in the new look. Mehul plays it.
5. **Progression wiring:** layered jars, gold lids, room reveal, exact resume, kill test. Room 1 content lands.
6. **Release v0.2.0:**
   - screenshots at all 5 sizes, with and without `--safe` insets;
   - a fresh-agent design review of the screenshots (no author opinion), and fixes from it;
   - on-device checks;
   - the pre-release.

## 8. Validation
- **Unit tests:**
  - Back state machine;
  - save v2 and the v1 → v2 migration;
  - fingerprint mismatch;
  - progression ids, `introduces` gating and gold-lid thresholds;
  - tutorial resume after a kill.
- **Content:** `check_levels` and `sim` pass for all 30 Room 1 levels, and the curve sits in the target bands
  (report committed).
- **Screenshots:** 720×1280, 1080×2400, 1080×2520, 1536×2048 and 1812×2176, plus `--safe` variants. Every screen,
  plus the drag, tap, outside-tap and 6-group-ledge scenarios. I look at each image before claiming anything.
- **Device:**
  - cold start from tap to the first interactive frame;
  - FPS on the heaviest board (9 jars, drag + lid);
  - a kill mid-lid, then resume;
  - Back on every screen;
  - haptics;
  - install over USB.

## 9. Questions for Mehul
- **Fail model** (still open from M1): the slip budget from L11, or stars-only with no fail? The default stays the
  budget; the test-menu toggle remains.
- **Style frames** (step 1): a quick yes, or which direction to change.
- **Optional:** download a Kenney audio pack by hand (kenney.nl blocks scripted downloads) if you want real
  recorded sounds in this milestone.

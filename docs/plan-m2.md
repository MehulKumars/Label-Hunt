# M2 plan: Home, tutorial, progression and a crafted look (draft 4, reviewed)

Written after Mehul's first phone playtest of v0.1.0 (2026-10-30). Approved by Mehul on 2026-10-30, with full
rights to change anything in service of quality. Draft 4 adds the quality bar he asked for (§10–§15): the player
experience and reward cadence, feel, sound, performance, security and accessibility, worked through the installed
`game-design`, `game-feel` and `frontend-design` skills.
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
| Vetted Claude skills | **Installed** (bf8c264) and wired into CLAUDE.md and `.claude/rules/` so every session uses them |
| Test window that looks like a phone | **Done** (51e45a7): `PhoneWindow` fits a 20:9 window to the monitor |
| Sound, animation, performance, security, the reward loop | §10–§15 |

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
Pulled forward from M3b; the full sound design is §12.

## 7. Build order
**Step 0** (style-independent logic, tests first, alongside the content track):
- Router plus screen transitions;
- the Back state machine;
- Save v2 with its migration;
- the progression model (ids, `introduces`, gold-lid thresholds);
- tutorial gating;
- `AdService`;
- the security baseline from §14 (playtest-only test menu, save validation).

**Steps 1–6:**
1. **Style frames:** 3 in-engine frames in the phone window (Home, mid-game Play, Win) built from the SVG art,
   plus the type-lab frame. Mehul gave full rights, so the frames don't wait for his reply: a fresh-agent critique
   of the screenshots is the gate, and Mehul sees them in the progress note and can redirect.
2. **Kit and board art:** tokens, Button, IconButton, Sheet (bottom and centred), ArtCache, card, jar, shelf,
   rail ledge, layout fixes. Re-shoot every scenario.
3. **Screens:** Play, Win, Lose and Pause in the new style; Home, Room and Settings; the tutorial.
4. **Feel and sound pass:** the event table in §11, the sound set and mix in §12, checked with frame-by-frame
   captures and loudness reports.
5. **Alpha APK (v0.2.0-alpha)** with Home, the tutorial, Play, the feel and sound, and the minimum progression of §16.6. Mehul plays it.
6. **Progression wiring:** layered jars, gold lids, room reveal, exact resume, kill test. Room 1 content lands.
7. **Release v0.2.0:**
   - screenshots at all 5 sizes, with and without `--safe` insets;
   - a fresh-agent design review of the screenshots (no author opinion), and fixes from it;
   - the performance budget (§13) and the security audit (§14) on the release APK;
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

- **Feel, sound, performance, security:** the checks listed in §11–§14.

## 9. Decisions taken under Mehul's full rights (he can overrule any of them)
- **Fail model:** keep the slip budget from L11 (§10 explains why), with generous Room 1 budgets and the
  two-fails assist. The stars-only toggle stays in the test menu.
- **Style frames:** not blocking (step 1).
- **Recorded sounds:** Kenney's own CC0 uploads on OpenGameArt instead of a manual download (§12).

## 10. Player experience and reward loop (`game-design`)
**The experience, named.** In LeBlanc's terms, Jarful aims at *Discovery* first (the "aha" of a hidden category),
*Challenge* second (deduce under a slip budget) and *Submission* third (calm tidying). *Sensation* is spent only at
the payoffs.
- **Iconic mechanic:** a wrong drop writes part of the label.
- **Core dialectic:** guess or know. Spend a slip to learn, or reason from what's on the board. The same trade
  returns at every scale: probe or reason in a move, Peek or slip in a level, clean or quick for the gold lid.

**The loop stack.** Each layer's output feeds the next one.

| Loop | Time | Payoff | Feeds |
|---|---|---|---|
| Move | 1–3 s | the clink, or a bounce plus label letters | knowledge |
| Level | 2–4 min | the lid cascade and the label reveal | a layered jar for the shelf |
| Session | 10–15 min | the shelf filling, gold lids, "Shelf 1 full" every 10 levels | the room |
| Meta | days | the room reveal, then the next room (and the daily in M2b) | a collection that tells the player's story |

**Isolation test.** Is the bare move-and-lid loop fun on its own? That waits on Mehul's M1 answers. The known risk
is post-aha busywork: 5–18 moves on 5-group boards.
- **Gate:** every Room 1 level has a bot median of 8 or fewer moves after the aha.
- **Levers:**
  - at most 4 groups in Room 1;
  - "pour proven runs" on by default if the sim shows it cuts busywork (it moves only cards the player has proven
    alike, so it leaks nothing);
  - lid combos, so the cascade itself feels good.

**Why keep the slip budget.** Without a cost, random dragging solves every board, so the probe stops being a
decision (the "no opportunity cost" smell). The fair-challenge rules below keep the budget from feeling cruel:
- anything the board already proves is refused for free;
- Room 1 budgets are generous (the average bot's p90 slips + 1);
- Retry is instant and keeps the same deal;
- after two fails you get a free Peek and +1 slip, and the gold lid is withheld (an assist that removes the wall,
  not the pride).

**Reward cadence: the dopamine is made of competence and information, not slot-machine schedules.**

| Moment | How often | Kind of reward |
|---|---|---|
| Every touch answered within 100 ms | every action | control |
| A slip writes label letters | each slip | information: failure pays |
| First pair writes a letter | per group | information: careful play pays too |
| Lid, label, combo pitch | every 30–60 s | completion |
| Layered jar drops onto the shelf | per level | collection |
| Gold lid | per clean level from L11 | mastery |
| "Shelf 1 full" and a look at what's next ("Next shelf: 4 groups") | every 10 levels | progress, anticipation, a clean place to stop |
| Room reveal | every 30 levels | the big one |
| Surprises that are not currency (first gold lid, a perfect sort on a hard level) | rare | delight that doesn't crowd out the fun of playing (the over-justification guardrail) |

The next goal is always visible: Home shows the next empty slot, and the Win card names a new idea when one is
coming.

**The ethics line.** These fail the test "would the player have more fun fulfilling this than not", so they never ship:
- energy or lives;
- timers;
- login calendars;
- paid or random reward boxes;
- near-miss presentation;
- streak guilt;
- push notifications;
- fake urgency;
- upsells on the fail screen beyond the opt-in Continue;
- interstitial ads in M2.

**Respect the player's time.**
- Speed:
  - launch to an interactive Home in under 2 s;
  - one tap from Home to a board, and from Win to the next board;
  - Retry is instant;
  - the median level is under 4 minutes.
- Skipping: Win skips on a tap, and Pause opens instantly.
- Resume: the board resumes exactly after a kill.
- Confirmations: the only one is Reset progress (hold for 1.2 s).

**Copy.** Plain verbs and sentence case. A button names its action ("Next level", "Try again", "Play level 13").
Messages give direction, not mood. No exclamation spam.

## 11. Feel: every event, by tier (`game-feel`, `tween-animation`)
**Tiers:** S acknowledges a touch, M confirms a change of state, L celebrates (lid, gold), XL marks a milestone
(win, shelf, room).

**Rules:**
- Juice never blocks input, and always returns to rest.
- No screen shake or hit-stop anywhere. The one held beat is an 80 ms pause before a lid drops (anticipation).
- Everything is eased: back-out for pops, cubic-out for settling, sine in-out for slides.
- The durations live in one `Style` motion table.

| Event | Tier | Motion | Sound | Haptic |
|---|---|---|---|---|
| Press a jar | S | top card rises 10 u, scale 1.06 with a shadow, 80 ms back-out | paper lift, ±5% pitch | 8 ms |
| Drag | S | follows the finger (exp 32/s) and leans up to 8° with speed; target jar glows within 80 ms | soft tick on entering a jar with room | 4 ms |
| Valid drop | S/M | 150 ms cubic-out glide, landing squash 1.06/0.94 settling in 120 ms | glass clink whose pitch rises as the jar fills, like a filling bottle; 3 variants | 10 ms |
| Free refusal | S | card leans 6 u toward the target and back in 160 ms; the proving tag pulses | soft wooden tock | none |
| Slip | M | 220 ms arc home, jar wobble ±3° damped over 300 ms, tag pops in, rail letters write, a slip jar cracks | a knock, then a pencil scritch as the letters write (the sound turns positive) | 12 ms, soft |
| First pair | M | both tags pop, rail letters write | soft two-note chime | 10 ms |
| Lid | L | 80 ms hold, lid drops in 120 ms ease-in, one 300 ms screw turn, squash on seat, label at 25 ms per letter, 400 ms shine sweep, 8 sparkles | ratchet ×3, a seat thock, pencil; +1 semitone per lid within 4 s | 30 ms + 3 light ticks |
| Gold lid | L | gold sheen across the shelf jar | small bell | 20 ms |
| Win | XL | jars hop in a wave staggered 60 ms, 40 paper confetti for 1.2 s, the level's jar bounces into its shelf slot | a short warm stinger; music ducks 6 dB | 20-40-20 pattern |
| Shelf full, room reveal | XL | glow sweep along the shelf, cabinet reveal | longer stinger | pattern |
| Lose | M, subdued | slip jars dim, sheet rises in 250 ms | low two-note, never a buzzer | none |
| UI press | S | scale 0.96 in 80 ms, release back-out in 120 ms | soft tap | 6 ms |
| Screen change | none | 250 ms slide or crossfade; sheets rise in 250 ms and fall in 180 ms | a quiet whoosh | none |
| Pause | none | instant dim, nothing animates in the way | the game audio goes "behind glass" (low-pass, −6 dB) | none |

**Reduce motion** removes the wobble, lean, hops, confetti and sparkles, and turns slides into fades.

**Check:**
- `--frames` captures at 60 fps feed ffmpeg contact sheets, and each timing is checked against the table.
- A scenario taps during a lid to prove input still works.

## 12. Sound design (`game-feel`)
**The palette is a pantry:** glass, wood, cork, paper and pencil, under a warm, slow, unobtrusive music bed
(acoustic or electric piano, about 70 bpm, loopable). No casino or arcade sounds, and no buzzers.

**Sources.** Licence first, and every file goes in CREDITS.md.
1. **Kenney's CC0 packs, from Kenney's own OpenGameArt uploads:** Impact Sounds (glass, wood), Interface Sounds and
   UI Audio. This avoids the scripted-download block on kenney.nl. Each licence page is checked.
2. **ffmpeg synthesis (modal: decaying partials) for what the packs lack:** the rising-pitch clink series and the
   pencil scritch. These are formulas, not AI generation.
3. **Music: one CC0 loop.** If nothing clears the bar, M2 ships without music; silence beats a bad loop.

**Mix.**
- **Buses:** Master → Music, Sfx, Ui.
- **Ducking and pause:** music ducks 6 dB under stingers. Pause adds a low-pass at 800 Hz and −6 dB.
- **Levels:** peaks at or below −1 dBFS. Effects are loudness-matched within ±2 LU per tier (ffmpeg `ebur128`).
- **Variation and voices:**
  - pitch varies ±3–8%, with 2–3 variants of each frequent sound;
  - at most 3 voices of the same sound, so nothing machine-guns;
  - a pool of 12 players.
- **Formats:** WAV with QOA compression for effects; OGG with loop points for music.
- **Settings:** separate Music and Sound volumes, plus Haptics.

**Check:**
- `reports/audio.md` with per-file loudness.
- A scenario records a full level's mix through `AudioEffectRecord` to a WAV for a listen-through and a mix
  loudness check.

## 13. Performance budget (mobile)
- **Frame rate:** a steady 60 fps on Mehul's phone on the heaviest board (9 jars, drag + lid + confetti). Frame
  CPU stays at or under 8 ms, with no hitch over 33 ms.
- **Cold start:** tap to the first interactive frame in 2.5 s or less (`am start -W` plus an in-game timestamp).
- **Size and memory:** APK at most 35 MB (arm64; 26.8 MB today), RAM at most 250 MB PSS.
- **Battery:** idle screens don't redraw. Low-processor mode is measured both on and off.
- **How:**
  - SVGs are rasterised once per size into a cache, with no per-frame vector work;
  - `_draw` runs only on change;
  - particles are pooled (CPUParticles2D, 64 or fewer);
  - nothing is generated at runtime;
  - JSON loads once;
  - first-use hitches (a lid's first text, the first sound) are pre-warmed at boot.
- **Check:** a `--bench` scenario plays the heaviest scripted sequence and writes frame-time p50, p95 and max to
  `reports/perf.md`. The same numbers come from the phone through logcat.

## 14. Security and privacy
**Threat model:** an offline, single-player game with no accounts, no network and no purchases in M2. The real
risks:
- a corrupt or hand-edited save that crashes the game;
- debug features in a store build;
- a leaked signing key;
- the asset and dependency supply chain;
- personal data.

**Measures:**
- **No network:** the INTERNET permission stays off; only VIBRATE is requested. There's no analytics SDK. The
  playtest log stays on the phone until the tester copies it.
- **Safe save loading:**
  - JSON only. Never `str_to_var` or `bytes_to_var` with objects, and never load `.tres` or `.res` from `user://`;
    those can carry scripts.
  - Every field is type- and range-checked, unknown level ids are dropped, and files over 1 MB are rejected.
  - Writes are atomic, with a `.bak` fallback.
  - A fuzz test feeds corrupt saves.
- **Debug features:**
  - The test menu exists only in builds with the `playtest` feature tag; the store preset leaves it out.
  - Release exports aren't debuggable.
- **Keys:**
  - The release keystore is made only with Mehul's OK (M4) and lives outside the repo.
  - Passwords come from environment variables.
  - `.gitignore` covers `*.keystore`, `*.jks` and export credentials.
- **Supply chain:**
  - GUT and the skills are pinned.
  - Fonts and sounds ship with their licence files.
  - Nothing is downloaded at runtime.
  - CREDITS.md lists every third-party file with its source.
- **Export hygiene:** `tools/`, `tests/`, `docs/`, `reports/`, `.claude/` and `src/gen/` are excluded, and an APK
  listing proves it.
- **Later:** real purchases need server-side verification. That's Mehul's call with the accounts.

**Check:**
- `tools/audit_apk.sh`: permissions, debuggable flag, unexpected files.
- GUT fuzz tests for the save.

## 15. Accessibility (the Basic tier of the Game Accessibility Guidelines, in phone terms)
- **Text:** the smallest text is 22 u, which is 33 px on a 1080-wide phone, above the 28 px floor. Card words are
  at least 34 u.
- **Contrast:** at least 4.5:1 (Ink on Paper is 12.5). Apricot is never used for text.
- **Never carried by one channel alone:**
  - tags use both a colour and a glyph;
  - the slip and hot-jar states use shape as well as colour;
  - every sound has a visual.
- **Touch:** targets are at least 88 u (about 48 dp). Play controls sit in the lower two-thirds for one thumb;
  Pause at top left is the rare exception.
- **No time pressure** anywhere, and undo is unlimited back to the last lid.
- **Settings:** Music, Sound, Haptics and Reduce motion. Nothing flashes more than 3 times a second.
- **Check:** colour-vision-deficiency screenshots (a `--cvd=deutan|protan|tritan` filter in the shot tool) of the
  tag palette and the rail.

## 16. Review of draft 4: decisions folded in (these override the numbers above)
A fresh adversarial review (a mobile-game design lead and a Godot tech lead) checked draft 4 against the code, the
sim reports and the installed skills.

**Before building:**
1. **L1–10 must contain a discovery.** The old t04–t10 boards show 0 median slips and 100% wins even for the random
   prober: the bot knows every group from move 0, so the slip-writes-the-label mechanic never fires.
   - L1–3 are 2-group quickies of about 20 s.
   - From L3, every level has one non-obvious group (a tier-2 category or a gentle herring).
   - **Per-level targets:** average-bot median slips ≥ 1, and the aha arrives after ≥ 40% of moves.
   - Each level's deal is the one with the lowest post-aha median among about 50 seeded deals.
   - Pour isn't counted on to cut busywork.
2. **Tutorial board 3:** two empty jars plus the Cricket herring, which makes the natural first move an honest slip
   without making the board unsolvable. It gets no solver hint pointer, and every tutorial board shows a visible
   **Skip** link (not only Back).
3. **Android edge-swipe Back:** a canceled release (`event.is_canceled()`) puts the card back and is never a drop.
   The board's side gutter is at least 40 u, a token, because the gesture zone is about 24 dp.
4. **The SVG art must be exported as source.** Godot imports `.svg` as a texture and doesn't ship the text.
   - `assets/art/*.svg` joins the export `include_filter`, and is rasterised at runtime at device scale.
   - The cache is keyed by asset and size, and tints use `modulate`.
   - The wordmark is set in code in the display font, not drawn as SVG letters.
5. **Gold and budgets:**
   - The gold threshold is the largest k where 25–45% of average-bot runs earn it.
   - A gold notch on the slip meter shows it during play.
   - Until bot calibration reaches ρ ≥ 0.6, budgets come from the **novice** bot's p90 + 1.
6. **The alpha ships with minimum progression:** ids, the solved list, the jar flying to its shelf, and L1–10.
   Gold lids, the room reveal and the kill test can follow.
7. **Exact resume saves the whole attempt, not the board:**
   - The save keeps the attempt's action log (moves, slips, undos, peeks, +jars) and the fail count.
   - On load the log replays through `Session`, which rebuilds the knowledge, tags and slips exactly. A kill can't
     refund slips or forget what the player learned.
   - Writes are debounced (about 0.5 s after the animations settle) and forced on pause or focus loss.

**During the build:**
8. **Haptics:** only lift, drop, slip, lid and win, with a 15–20 ms floor. Godot 4.7 has `vibrate_handheld`
   only, and cheap ERM motors buzz on tiny pulses. No haptic on drag hover or UI presses.
9. **Audio:**
   - The landing clink starts `AudioServer.get_output_latency()` early, checked against a slow-motion video of the
     phone.
   - Stingers get reserved players.
   - Short clips are matched by peak and active RMS, because ebur128 is meaningless under 400 ms.
   - The music keeps processing during pause, behind glass.
10. **Feel events added to §11:**
    - the board's deal-in;
    - the +Jar relayout (jars glide to their new spots);
    - the undo rewind (the card flies back along its path);
    - put back, which looks different from a slip (no wobble or knock);
    - a last-slip warning (the final slip jar pulses once);
    - the stuck state (Undo and +Jar pulse);
    - the Tidy-up autoplay at 120 ms per move, with the combo pitch capped at +5 semitones.
11. **Battery:**
    - Frame rate capped at 60 fps (120 Hz phones otherwise render 120).
    - The Play pill breathes 3 times, then rests, and starts again after 20 s idle.
    - Low-processor mode on Home and Room.
12. **Double taps:** the outgoing screen ignores input once navigation starts. Win's Next ignores taps for the first
    400 ms, so the jar-to-shelf payoff is seen.
13. **Home:**
    - It shows the **current shelf** large (10 slots as 5×2, about 120 u each), and the cabinet itself opens Room.
    - How to play sits in the top-right "?", replacing the link row.
    - The button reads "Play level 13" (no middle dot).
    - No starter shelf: after the tutorial, slot 1 glows as the invitation.
14. **Type:**
    - Card text uses one quantised size per board (42, 38 or 34) instead of shrinking per card. This avoids glyph
      hitches and mismatched neighbours.
    - Lid labels are never under 26 u.
15. **Tidy up** finishes with a greedy sort (every group is proven by then), never the solver on the main thread.
16. **Backups and keys:**
    - Android backup is allowed, so a new phone keeps the collection; the save holds no secrets.
    - Play App Signing goes in M4.
    - Moving from the debug key to the release key forces an uninstall, which wipes test saves; that's planned for.
17. **Content fairness:** a fresh agent lists every Room 1 word that could fit another group in its level. Each
    one becomes a deliberate herring or gets swapped.
18. **Captures use Godot's Movie Maker** (`--write-movie … --fixed-fps 60`) for frame-timing sheets and the
    full-mix WAV. It's deterministic and records audio.

**Smaller contradictions:**
- Cold start to interactive is under 3 s everywhere.
- Reset progress uses a confirm sheet with the safe choice focused, not a hold.
- Pause dims instantly and its sheet rises in 150 ms.

**Scope cut order if time runs short:**
1. Room becomes a scroll of Home.
2. Music.
3. The room-reveal choreography.

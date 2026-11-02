# Jarful: design

**Pitch:** Sort word cards into glass jars by a hidden category. Only the top card moves, and a wrong drop
bounces back but shows you part of the label. When four cards belong together, the lid screws on and the label
types in.

Jarful is built from Mehul's *Word Jars* concept card. The closest game on the market is Tripledot's
*Bubble Word Sort*, which has hidden groups of 4 in pipes. Jarful differs in five ways:
1. **Strict jar rules.** Only the top card moves, and each drop is checked against the top card. A wrong drop is a *slip*.
2. **Labels you earn.** Slips, pairs you build and Hints each reveal the label one step at a time, like hangman.
3. **Lids and a Pantry.** Every category you solve becomes a labelled jar on your shelves.
4. **Jar types:** frosted, labelled and corked.
5. **A pantry to fill:** 17 rooms, each with its own look, a play streak and ranks (a daily puzzle comes later).

## Rules
- **Moving.** Tap a jar to lift its top card, then tap another jar to drop it. Drag works too. You can drop on an
  empty jar, or on a top card of the same hidden group.
- **Slips.** A wrong drop is a slip: the card bounces home, you lose one slip, and the card gets a tag that links it
  to its group's slot in the **label rail**. That label moves one step on.
- **Building pairs.** The first time you stack two cards of one group, the label also moves one step.
- **Label steps.** The rail shows each label in steps:
  1. blank;
  2. the context words plus the length of the key word ("Things with ▢▢▢▢");
  3. the key word's first letter;
  4. the full label, once the lid is on.
- **Lids.** Four cards of one group in one jar → the lid goes on. Lids are permanent and always correct.
- **No free information is punished.** A drop the board already proves wrong is refused for free. "Stuck" is
  judged only from what the player can know.
- **Undo** is free back to the last lid; knowledge stays. Once every remaining card's group is proven, **Tidy up**
  finishes the board for you.
- **Fail state.** From level 11, each level has a slip budget: the tightest one at which the average bot still wins
  at its room's floor rate (`data/rooms/curve.json`). Running out means **Retry** (one tap) or an optional
  **Continue** (+2 slips) for an ad or 150 coins you already have. Levels 1–10 can't be failed. A help ladder, always
  announced and never hidden (and no gold lid): after 2 fails on the same level the next try gives a free Hint and
  +1 slip; after 3, the hardest blank label also starts at its first step ("Things with ▢▢▢▢").
- **Difficulty is told up front.** Tricky levels carry one pepper and hard levels two, on their shelf slot and beside
  the title; the Win card's Next button names what comes next ("Next: hard level").
- **Fair deals.** No two cards of the same group start next to each other, and there are always 2 empty jars (a
  labelled jar replaces one of them).
- **Boosters** (`docs/plan-m3.md` §2): **Hint** (50 coins) points at a good next move and tags that card;
  **Complete** (250 coins) seals a label you tap on the rail, its four cards fly up into it; **+Jar** stays free once
  per level. Any help withholds the gold lid.

## First 60 seconds
1. Tap the icon. The splash shows, then the 3-board tutorial starts (Skip is top right).
2. Board 1 has 2 obvious groups. A glowing card and a hand pointer show tap → tap.
3. First move at about 8 s; first lid and label at about 30 s.
4. "You're ready", 150 coins to start, then **Play level 1**.

Captions only appear the first time something happens: first slip, first pair, first stuck. Each is short.

## Progression and meta (M3)
- **510 levels in 17 rooms of 30** (specs to 720 for later). Each room has its own walls, wood and jar style.
- **Sawtooth in packs of 10:** levels 1–4 rise, 5 is *tricky*, 6 is a rest level that brings in the next idea,
  7–9 rise, 10 is *hard*. Rooms rise from an easy on-ramp (Room 1) to very hard (rooms 14–17).
- **Room 1 is hand-made** (`data/rooms/room1_spec.json`): L1–10 teach sorting by meaning with everyday categories,
  L11–20 add the slip limit and lateral groups, L21–30 add herrings and 4 groups. Its levels are *strict* (no two
  cards of different groups share another bank category), and the spec keeps out words that read as another group
  ("Orchard" beside trees) or name their own weakly. It ends just under Room 2's difficulty.
- **When new ideas arrive:**

  | Level | New idea |
  |---|---|
  | L2, L4, L6 | Undo, +Jar, Hint |
  | L11 | slip budget (never below 3 in Room 1) |
  | L13 | Complete |
  | L16 | lateral groups ("Words after snow") |
  | L21 | herrings |
  | L26 | 4 groups |
  | L31–60 | the v0.2 levels ("The Kitchen") |
  | L66 | abstract categories |
  | L96 | 5 groups |
  | L126 | double herrings |
  | L186 | frosted jars |
  | L216 | wordplay |
  | L246 | labelled jars |
  | L276 | 6 groups |
  | L306 | corked jars |

- **Home:** the big Jarful jar fills with every label sorted in the room; the cabinet holds the current shelf (tap it
  for the room); the profile chip (rank, XP ring), coins, the play streak and today's gift; Levels, Play and Shop in
  the thumb zone.
- **Coins** (one currency, `src/rules/economy.gd`): first solves (14–66, rising with groups, level kind and room,
  because help is wanted more often in harder rooms), the daily gift, rank-ups, room completes, optional ads (capped;
  one ad is worth one Hint), and coin packs ($0.99–$9.99, mock until Play Billing). Spent on Hint, Complete, Continue.
  No energy, no timers, no paywalls, no loot boxes.
- **Play streak:** a day counts once you win any level. The daily gift opens after the first win of the day and
  grows over a 7-day ladder. Every 7 days earns a streak saver (at most 2) that covers a missed day. Bonuses at 10,
  15, 20, 30, 45, 60, 75 and 100 days, then every 50 days, are shown in advance on the Streak and Daily gift sheets.
- **Rank:** XP from first solves, hard levels and gold lids; titles and avatars unlock as you rank up.
- **Jar of the Day** (deferred): a daily puzzle will count toward the same streak.

## Difficulty and the level pipeline
- **Category bank.** Claude-drafted categories (target ~750), each with a key word, tier 1–4, domain and members.
  Linted (`tools/lint_bank.gd`) and reviewed by fresh-eyes reviewers for weak members and undeclared overlaps.
- **Fairness gates for every level:**
  - **Unique cover:** there is exactly one way to split the cards into the level's groups.
  - **No phantom groups:** a bank category outside the level must not hold 3 or more of its cards drawn from two or
    more groups. Three cards from one group mislead nobody.
  - **No label clashes:** a card must not read as naming another group's label.
  - **Pair rules:** categories that overlap too much never share a level.
  - **Wordplay rules:** another group's card must not obey a wordplay group's rule (checked from the spelling where
    the rule allows it), unless it is that level's declared herring.
- **Vocabulary rises with difficulty.** Room 1, Room 3 and every rest level leave out the hard-word list
  (`data/bank/hard_words.txt`), so early levels and breathers test thinking, not vocabulary.
- **Reuse:** a category may appear up to 5 times in the game, normally at least 60 levels apart. A repeat shares at
  most 2 of its 4 words with any earlier use, or 3 when that use is 150 or more levels back.
- **Offline, deterministic bake** (`tools/room_gen.gd`, two phases):
  1. **Pick** (fast, global reuse ledger over all rooms): categories, words and herrings per level.
  2. **Settle** (one process per room, in parallel): seeded deals with special jars, proven solvable, measured by
     a human-like bot; budget from the room's floor, gold from the average bot.
- **Reports:** `reports/pick.md`, `roomN_gen.md`, `curve.md` (all levels against their floors), `audit_content.md`
  (re-checks against the current bank, including a walk that only follows Hints) and `economy.md`.
- **Calibration.** Mehul's playtest log calibrates the bot. Until it ranks levels the way people do, Mehul's flags
  win.

## Screens
- **Home, Levels (rooms), a Room (3 shelves of 10), Profile (avatar, name, rank, pantry ledger), Play.**
- **Play:** pause, the level number with the slip meter under it, coins; the label rail; the board (3 columns,
  within thumb reach); Undo, Hint, +Jar, Complete (and Tidy up when every card is proven).
- **Sheets:** Win (jar, shelf, coin and XP chips, one line of news; test builds add a star to rate the level), Lose, Pause, Settings, Shop, Daily gift, Streak, avatar picker,
  a solved level's card, the room reveal.
- **Launch:** the tutorial on first launch, then Home. A level interrupted when the app is killed resumes exactly.
- **Back button:** puts down a lifted card or leaves Complete's choice; closes the open sheet; in Play opens Pause;
  a room goes back to where it was opened from; other screens go Home; Home moves the app to the background.

## Art, sound, feel
- **Look.** Mehul's palette: Paper `#FFF8EC`, Ink `#3D2C2E`, Paprika `#A9432C`, Glass teal `#3B6E6E`, and
  Apricot `#F28F3B` for decoration. Jars, lids, cards, shelves, coins and room walls are SVG built in code.
  Fonts: Atkinson Hyperlegible Next and Gochi Hand (OFL).
- **Feel.** Calm, with a flourish when you solve something. Juice goes on success only (lid ratchet and seat, label
  typed in, jar onto the shelf, coins flying into the coin pill).
- **Reduce motion** removes the wobble, the hops and the flights.
- **Sound.** Kenney and other CC0 effects, "Catmint" by Kistol (CC0) as the music bed.
- **Haptics:** 15–40 ms, only on lift, drop, slip, lid, win and coins landing.

## Monetisation (mock until accounts)
- Optional rewarded ads only (Mehul's call): free coins, a free Hint, ×2 win coins, ×2 daily gift, Continue.
  Capped at 12 a day, 30 s apart. No interstitials.
- Coin packs through a `Store` facade (mock in playtest builds). Real AdMob, Play Billing and Play Games (friends)
  need Mehul's accounts and the Gradle build.

## Milestones

| Milestone | Version | Contents |
|---|---|---|
| M1 | v0.1 | Find the fun: grey-box + toggles + bot |
| M2 | v0.2 | Home, tutorial, Room 1, the art direction. See `docs/plan-m2.md` |
| M3 | v0.3 | Coins, boosters, streak, rank, Levels and rooms, profile, 510 levels. See `docs/plan-m3.md` |
| M4 | v1.0-rc | Real ads/billing/Play Games (with Mehul's accounts), daily puzzle, polish, store kit |

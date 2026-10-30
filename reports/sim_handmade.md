# Bot simulation: handmade

200 games per profile per level. Win rate counts a loss when slips reach the level's budget (levels with no budget can't be lost, so read their slips instead). Moves after the aha = moves the bot still made once it believed every remaining card's true group (post-aha busywork; target 8 or fewer).

| level | grp | budget | par | novice win | average win | expert win | prober win | avg median slips | avg p90 slips | avg moves | avg after-known | avg secs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| t01 | 2 | 0 | 2 | 100% | 100% | 100% | 100% | 0 | 0 | 2 | 2 | 5 |
| t02 | 2 | 0 | 8 | 100% | 100% | 100% | 100% | 0 | 0 | 10 | 10 | 26 |
| t03 | 3 | 0 | 12 | 100% | 100% | 100% | 100% | 0 | 0 | 16 | 16 | 43 |
| t04 | 3 | 0 | 11 | 100% | 100% | 100% | 100% | 0 | 0 | 16 | 15 | 41 |
| t05 | 3 | 0 | 12 | 100% | 100% | 100% | 100% | 0 | 0 | 16 | 16 | 43 |
| t06 | 3 | 0 | 11 | 100% | 100% | 100% | 100% | 0 | 0 | 16 | 15 | 49 |
| t07 | 3 | 0 | 12 | 100% | 100% | 100% | 100% | 0 | 1 | 16 | 14 | 42 |
| t08 | 3 | 0 | 12 | 100% | 100% | 100% | 100% | 0 | 1 | 16 | 16 | 43 |
| t09 | 3 | 0 | 11 | 100% | 100% | 100% | 100% | 0 | 1 | 16 | 12 | 46 |
| t10 | 3 | 0 | 11 | 100% | 100% | 100% | 100% | 0 | 0 | 14 | 13 | 35 |
| m01 | 5 | 4 | 20 | 76% | 91% | 96% | 0% | 1 | 3 | 27 | 16 | 85 |
| m02 | 5 | 4 | 19 | 75% | 96% | 98% | 0% | 0 | 3 | 23 | 5 | 73 |
| m03 | 5 | 4 | 18 | 79% | 85% | 99% | 0% | 1 | 3 | 29 | 17 | 88 |
| m04 | 5 | 4 | 20 | 69% | 90% | 94% | 0% | 1 | 3 | 35 | 18 | 88 |
| m05 | 5 | 4 | 17 | 49% | 79% | 95% | 0% | 2 | 4 | 25 | 9 | 86 |
| m06 | 5 | 4 | 18 | 84% | 94% | 93% | 0% | 0 | 2 | 30 | 17 | 88 |
| m07 | 5 | 4 | 19 | 58% | 81% | 98% | 0% | 1 | 3 | 27 | 16 | 87 |
| m08 | 5 | 4 | 21 | 59% | 80% | 93% | 0% | 1 | 4 | 38 | 12 | 115 |

**Benchmark:** 14400 games in 73.5 s = 5.10 ms/game. A full bake (515 levels, about 319300 games) would take about 27 min on one process, or 5 min split over 6 processes.

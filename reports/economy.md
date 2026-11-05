# Economy simulation

510 levels, 10 a day. Prices: Hint 50, Complete 250, Continue 150 coins (or 10, 40, 25 diamonds). Ads: 12 a day at most. Win coins: per star, a share of win_coins by room [[1, 0.4], [8, 0.45], [14, 0.5]], times the stars the average bot earns (reports/stars.csv).

| after level | room | free player coins | ad player coins | one-purchase coins | free: Hints got | ads: Hints got |
|---|---|---|---|---|---|---|
| 30 | The Larder | 963 | 1551 (0 diamonds) | 963 (0 diamonds) | 100% | 100% |
| 60 | The Kitchen | 1452 | 2040 (0 diamonds) | 1452 (0 diamonds) | 100% | 100% |
| 90 | The Orchard Shed | 1432 | 2020 (0 diamonds) | 1432 (0 diamonds) | 100% | 100% |
| 120 | The Tea Room | 1634 | 2222 (0 diamonds) | 1634 (0 diamonds) | 100% | 100% |
| 150 | The Spice Market | 1803 | 2391 (0 diamonds) | 1803 (0 diamonds) | 100% | 100% |
| 180 | The Bakery | 1736 | 2324 (0 diamonds) | 1736 (0 diamonds) | 100% | 100% |
| 210 | The Winter Cellar | 1932 | 2520 (0 diamonds) | 1932 (0 diamonds) | 100% | 100% |
| 240 | The Greenhouse | 1755 | 2343 (0 diamonds) | 1755 (0 diamonds) | 100% | 100% |
| 270 | The Apothecary | 1754 | 2342 (0 diamonds) | 1754 (0 diamonds) | 100% | 100% |
| 300 | The Honey House | 2061 | 2649 (0 diamonds) | 2061 (0 diamonds) | 100% | 100% |
| 330 | The Root Cellar | 1782 | 2370 (0 diamonds) | 1782 (0 diamonds) | 100% | 100% |
| 360 | The Seaside Pantry | 1607 | 2195 (0 diamonds) | 1607 (0 diamonds) | 100% | 100% |
| 390 | The Night Market | 1034 | 1755 (0 diamonds) | 1034 (0 diamonds) | 100% | 100% |
| 420 | The Chocolatier | 285 | 1743 (0 diamonds) | 285 (0 diamonds) | 100% | 100% |
| 450 | The Clockmaker's Pantry | 456 | 1987 (0 diamonds) | 456 (0 diamonds) | 82% | 100% |
| 480 | The Royal Kitchen | 238 | 1745 (0 diamonds) | 238 (0 diamonds) | 81% | 100% |
| 510 | The Grand Pantry | 277 | 1789 (0 diamonds) | 277 (0 diamonds) | 79% | 100% |

- free: wanted 660 Hints, got 624 (95%); player level 40 at the end.
- ads: wanted 660 Hints, got 660 (100%); player level 40 at the end.
- once: wanted 660 Hints, got 634 (96%); player level 40 at the end.
- ad player watched 69 ads in 51 days (1.4 a day).

## Gates

- PASS free player can afford a Hint at the start of 100% of levels (gate: 33% or more)
- PASS ad player is never short of a Hint for more than 3 levels in a row (worst run 0)
- PASS free player's median balance is 1539 (gate: 100 to 2,000)
- PASS ad player's coins keep their value: at most 2707 after level 300 (gate: 5,000 or less)
- PASS free player gets 79% of the Hints it wants in its worst room (gate: 68% or more)
- PASS the $0.99 pack buys 10 Hints (gate: 10 or more)
- PASS ad player banks at most 0 diamonds a day from ads (gate: 25 or less)
- PASS ad player's diamonds get spent: 0 held at level 300 (gate: under 500)

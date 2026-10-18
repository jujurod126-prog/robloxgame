# Balance sheet

The numbers come from `src/ReplicatedStorage/Shared/Data` and the cost formula in
`Shared/Modules/Formulas.luau`:

```
next level cost = round(BaseCost * CostGrowth ^ (currentLevel - 1))
```

| Upgrade          | BaseCost | CostGrowth | Lv 1 -> Lv 10 value      |
|------------------|---------:|-----------:|--------------------------|
| Scoop Speed      | 25       | 1.60       | 1.00s -> 0.38s per scoop |
| Move Speed       | 40       | 1.55       | 16 -> 26 WalkSpeed       |
| Storage          | 60       | 1.70       | 1 -> 6 scoops per cone   |
| Tip Bonus        | 100      | 1.50       | +0% -> +60% tips         |
| Serving Capacity | 150      | 1.80       | +0 -> +5 customers       |

## Time to afford: first 20 upgrades

> **This is an estimate (Stage 1).** Serving doesn't exist yet, so income comes from a
> simple model. It will be re-measured once real serving lands in Stage 2.
>
> Model: Sunny Sidewalk, Vanilla only (10 Coins/scoop), customer always waiting,
> Regular orders of 1 to min(2, Storage) scoops, tip = 50% × 60% patience left × (1 + Tip Bonus),
> 4 s of walking per order at WalkSpeed 16 (shorter with Move Speed and Serving Capacity).
> The player always buys the cheapest available upgrade.

| # | Upgrade | New level | Cost | Income (Coins/min) | Wait | Total time |
|---|---------|----------:|-----:|-------------------:|-----:|-----------:|
| 1 | Scoop Speed | 2 | 25 | 156 | 10s | 0.2 min |
| 2 | Scoop Speed | 3 | 40 | 159 | 15s | 0.4 min |
| 3 | Move Speed | 2 | 40 | 162 | 15s | 0.7 min |
| 4 | Storage | 2 | 60 | 171 | 21s | 1.0 min |
| 5 | Move Speed | 3 | 62 | 236 | 16s | 1.3 min |
| 6 | Scoop Speed | 4 | 64 | 246 | 16s | 1.5 min |
| 7 | Move Speed | 4 | 96 | 252 | 23s | 1.9 min |
| 8 | Tip Bonus | 2 | 100 | 263 | 23s | 2.3 min |
| 9 | Scoop Speed | 5 | 102 | 266 | 23s | 2.7 min |
| 10 | Storage | 3 | 102 | 272 | 22s | 3.1 min |
| 11 | Move Speed | 5 | 149 | 272 | 33s | 3.6 min |
| 12 | Tip Bonus | 3 | 150 | 283 | 32s | 4.1 min |
| 13 | Serving Capacity | 2 | 150 | 287 | 31s | 4.6 min |
| 14 | Scoop Speed | 6 | 164 | 370 | 27s | 5.1 min |
| 15 | Storage | 4 | 173 | 382 | 27s | 5.5 min |
| 16 | Tip Bonus | 4 | 225 | 382 | 35s | 6.1 min |
| 17 | Move Speed | 6 | 231 | 386 | 36s | 6.7 min |
| 18 | Scoop Speed | 7 | 262 | 400 | 39s | 7.4 min |
| 19 | Serving Capacity | 3 | 270 | 412 | 39s | 8.0 min |
| 20 | Storage | 5 | 295 | 412 | 43s | 8.8 min |

## Pacing targets vs. this model

| Target                                   | Model result                      |
|------------------------------------------|-----------------------------------|
| First reward within 10 s                 | First order paid at about 5 s (13 Coins) ✅ |
| First upgrade under 50 Coins within 60 s | Scoop Speed for 25 Coins at about 10 s ✅ |
| Beach Boardwalk (2,500) in 10 - 15 min   | About 15 min (20 upgrades, then about 6 min of saving) ✅ borderline |

Tuning levers if playtests are off: `Flavors.Vanilla.CoinValue`, `Neighborhoods.BeachBoardwalk.UnlockCost`,
and each upgrade's `BaseCost` / `CostGrowth`.

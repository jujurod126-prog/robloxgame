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

> **Estimate (Stage 2 model).** It now follows the real serving loop, but it assumes a player
> who never wastes a second. Re-check it against playtests in Studio.
>
> How Stage 2 actually plays: the player can reach both the dispenser and the counter from one
> spot, so **walking doesn't limit income yet**. What limits it is how fast customers arrive
> (0.5-1.5 s delay + 2 s walk) and how fast you can scoop. That's why the model skips Move Speed
> (it matters once there's travel between neighborhoods in Stage 5) and why Serving Capacity is
> such a strong upgrade.
>
> Model: Sunny Sidewalk, Vanilla only (7 Coins per scoop), Regular customers ordering
> 1 to min(2, Storage) scoops, served with about 85% patience left (tip = 50% × 85% × (1 + Tip Bonus)),
> 0.6 s to press Serve. The player always buys the cheapest useful upgrade.

| # | Upgrade | New level | Cost | Income (Coins/min) | Wait | Total time |
|---|---------|----------:|-----:|-------------------:|-----:|-----------:|
| 1 | Scoop Speed | 2 | 25 | 166 | 9s | 0.2 min |
| 2 | Scoop Speed | 3 | 40 | 166 | 14s | 0.4 min |
| 3 | Storage | 2 | 60 | 166 | 22s | 0.8 min |
| 4 | Scoop Speed | 4 | 64 | 249 | 15s | 1.0 min |
| 5 | Tip Bonus | 2 | 100 | 249 | 24s | 1.4 min |
| 6 | Scoop Speed | 5 | 102 | 253 | 24s | 1.8 min |
| 7 | Storage | 3 | 102 | 253 | 24s | 2.2 min |
| 8 | Tip Bonus | 3 | 150 | 253 | 36s | 2.8 min |
| 9 | Serving Capacity | 2 | 150 | 257 | 35s | 3.4 min |
| 10 | Scoop Speed | 6 | 164 | 514 | 19s | 3.7 min |
| 11 | Storage | 4 | 173 | 514 | 20s | 4.0 min |
| 12 | Tip Bonus | 4 | 225 | 514 | 26s | 4.5 min |
| 13 | Scoop Speed | 7 | 262 | 521 | 30s | 5.0 min |
| 14 | Serving Capacity | 3 | 270 | 521 | 31s | 5.5 min |
| 15 | Storage | 5 | 295 | 521 | 34s | 6.1 min |
| 16 | Tip Bonus | 5 | 338 | 521 | 39s | 6.7 min |
| 17 | Scoop Speed | 8 | 419 | 528 | 48s | 7.5 min |
| 18 | Serving Capacity | 4 | 486 | 528 | 55s | 8.4 min |
| 19 | Storage | 6 | 501 | 729 | 41s | 9.1 min |
| 20 | Tip Bonus | 6 | 506 | 729 | 42s | 9.8 min |

## Pacing targets vs. this model

| Target                                   | Model result                                   |
|------------------------------------------|------------------------------------------------|
| First reward within 10 s                 | First order paid at about 6 s (10 Coins) ✅      |
| First upgrade under 50 Coins within 60 s | Scoop Speed for 25 Coins at about 9 s ✅        |
| Beach Boardwalk (2,500) in 10 - 15 min   | About 13 min with perfect play (20 upgrades + 3.4 min of saving). Real players will be a bit slower ✅ |

Tuning levers if playtests are off: `Flavors.Vanilla.CoinValue` (the others scale with it),
`Neighborhoods.BeachBoardwalk.UnlockCost`, each upgrade's `BaseCost` / `CostGrowth`, and the
customer flow timings in `GameConfig.CustomerFlow`.

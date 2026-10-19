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

## Orders, toppings and combo (Stage 4)

```
correct order = scoop value × topping multiplier × customer pay × area pay
                × area preference bonus (if it matches) × topping pay bonus (if it has a topping)
                × combo multiplier, then + tip
wrong order   = scoop value × topping multiplier × customer pay × area pay × 40%, no tip, combo resets
```

- **Combo:** x1.1 at 5 correct orders in a row, +0.1 per order after that, capped at x2 (14 in a row).
  A wrong order or a customer running out of patience resets it.
- **Toppings:** Sprinkles x1.1 (100 Coins) up to Gold Flakes x2 (1.5M). About 30% of Regular orders ask
  for a topping once you own one, so toppings are the next big income step after the first upgrades.
- **Reputation:** +0.02 per correct order, -0.03 per wrong one, -0.1 when a customer leaves angry (1 to 5 stars,
  starting at 3). More customer types unlock with stars in Stage 5.

The time-to-afford table above doesn't include toppings or combo yet. They make real income a bit higher than the model.

## Neighborhoods and customer types (Stage 5)

| Area | Unlock | Needs | Spots | Pay | Tips | Likes |
|------|-------:|-------|------:|----:|-----:|-------|
| Sunny Sidewalk | free | — | 3 | x1 | x1 | — |
| Beach Boardwalk | 2,500 | Sunny | 5 | x1.6 | x1.2 | Fruity, Cold flavors (+25%) |
| Carnival Square | 25,000 | Beach | 7 | x2.8 | x1.3 | Candy flavors; toppings pay +50% |
| Snowy Village | 250,000 | Carnival + Rebirth 1 | 8 | x5 | x2.5 | Warm toppings (+50%) |
| Candy Kingdom | 2,500,000 | Snowy + Rebirth 3 | 10 | x10 | x3 | Candy flavors; rare customers x2 |

| Customer | Appears at | Pay | Tips | Patience | Notes |
|----------|-----------|----:|-----:|---------:|-------|
| Regular | always | x1 | x1 | 30 s | |
| Kid | always | x0.7 | x0.5 | 18 s | Usually wants Sprinkles |
| Tourist | 3.5 stars | x1.4 | x2 | 45 s | More common at sunset (Stage 8) |
| Influencer | 4 stars, Rare+ flavor loaded | x3 | x1.5 | 30 s | +0.1 Reputation, camera flash |
| VIP Critic | 4.5 stars, Legendary flavor loaded | x8 | x3 | 60 s | Critic Trophy per Legendary flavor |

## Pets (Stage 6)

Equipped pets add their boost (golden pets x2.5). Boosts of the same kind add together:
Coins boosts multiply all Coin income, Speed boosts walk speed, Scoop cuts scoop time,
and Tips add to the Tip Bonus.

| Egg | Price | Best odds |
|-----|------:|-----------|
| Basic | 750 Coins | Penguin 35%, Cow 30%, Waffle Pup 20%, Polar Bear 8%, Cone Cat 5%, Cherry Chick 2% |
| Rainbow | 100 Gems | up to Marshmallow Ghost 4%, Gummy Bear 1% |
| Legendary | 500 Gems | Sprinkle Dragon 7%, Galaxy Unicorn 1% |

- 3 pet slots to start (+1 and +2 from the Extra Pet Slot rebirth skill in Stage 7), 100 pets max.
- Merge 5 unlocked normal copies of a pet into 1 golden one (2.5x boost).
- Example: 3 Penguins (+5% Coins each) = +15% Coins. One Golden Penguin = +12.5%.

## Rebirth, skills, quests, daily rewards (Stage 7)

- **Rebirth** needs 2.5M Coins, then x1.5 each time (3.75M, 5.6M, ...). Each rebirth gives a permanent
  +25% Coins (x1.25, x1.5, x1.75 ...) and 1 Rebirth Token. It resets Coins (to the Starting Coins skill),
  truck tier and upgrades, and keeps everything else.
- **Skills** (Tokens): Faster Customers (+10% to +50% arrival speed), Starting Coins (500 to 250K),
  Bigger Tips (+10% to +50%, needs Faster Customers 1), Longer Rush Hour (+10s to +50s, needs Faster
  Customers 2, takes effect in Stage 8), Extra Pet Slot (+1/+2, needs Starting Coins 2).
- **Daily quests**: 3 a day, re-rolled at 00:00 UTC, each at a random easy/medium/hard tier.
- **Daily login**: claim every 20 hours. Missing more than 48 hours resets the streak. Day 7 gives
  50 Gems and a Rainbow Egg, then the calendar loops.
- **Achievements**: 8, each with a Gem reward and an optional badge.

# UI contract

This file describes how the client (UI) and the server talk to each other. Update it
whenever a remote or the PlayerData shape changes.

## Ground rules

- **The server owns all data.** Coins, Gems, purchases, inventory and progression only
  change on the server. The client displays data and sends *requests*.
- Client requests never contain amounts or prices. They name *what* the player wants,
  e.g. `"ScoopSpeed"`, and the server works out cost, ownership, cooldowns and distance.
- Every client-to-server remote is rate-limited per player (`GameConfig.RateLimits`).
- Remote names are defined in one place: `Shared/Modules/Remotes.luau`. The server creates
  them under `ReplicatedStorage.Remotes` at startup.

## Data sync: snapshot + patches

There is **one** sync method, and every screen uses it through `DataController`.

1. The client connects `DataPatch` first and buffers any patch that arrives early.
2. The client invokes `GetSnapshot()` and receives `{ Seq, Data }`.
3. The client applies the buffered patches whose `seq > Seq`, in order, and drops the rest.
4. After that, each `DataPatch(seq, path, value)` sets `Data[path[1]][path[2]]... = value`.
   - `path = {}` means the whole data table was replaced (for example by a reset).
   - Patches send the **new value** of what changed. They never send a delta.

UI code never touches remotes for data. It uses:

```lua
local DataController = require(Controllers.DataController)
local data = DataController.waitForData()
DataController.observe("Coins", function(coins) ... end) -- now + on change
DataController.Changed:Connect(function(path, value) ... end)
```

## Remotes

| Name | Type | Direction | Arguments | Returns | Rate limit | Stage |
|------|------|-----------|-----------|---------|------------|-------|
| `GetSnapshot` | RemoteFunction | Client → Server | none | `{ Seq: number, Data: PlayerData }`, or `nil` if not loaded / rate-limited | 3 per 10 s | 1 |
| `DataPatch` | RemoteEvent | Server → Client | `seq: number, path: {string \| number}, value: any` | — | — | 1 |

*Later stages add rows here, for example `RequestScoop`, `BuyUpgrade(statId)`,
`UnlockFlavor(flavorId)` and `HatchEgg(eggId, count)`.*

## PlayerData shape (DataVersion 1)

The source of truth is `Shared/Types/PlayerData.luau`, and the defaults are in
`ServerScriptService/Modules/DataTemplate.luau`.

```text
DataVersion        number
Coins              number
Gems               number
RebirthTokens      number
Rebirths           number
Reputation         number (stars, 1 to 5, starts at 3)
Truck
  Tier             number (index into Shared/Data/Trucks)
  Upgrades         { MoveSpeed, ScoopSpeed, ServingCapacity, Storage, TipBonus: level 1-10 }
  Equipped         { Paint, Awning, Flag, Jingle: cosmetic id }
OwnedCosmetics     { [cosmeticId]: true }
Flavors
  Unlocked         { [flavorId]: true }
  Loadout          { flavorId } (one per truck flavor slot, in order)
Toppings.Unlocked  { [toppingId]: true }
Neighborhoods.Unlocked { [neighborhoodId]: true }
Pets
  Inventory        { [petGuid]: { PetId, Variant: "Normal" | "Golden", Locked } }
  Equipped         { petGuid }
Skills             { [skillId]: level }
Quests
  DayKey           number (UTC day the quests were rolled)
  Active           { { QuestId, Tier, Progress, Claimed } }
Daily              { Streak: number, LastClaimTime: os.time() }
Achievements       { [achievementId]: true } (reward claimed)
Collectibles       { GoldenSprinkles: { [id]: true }, CriticTrophies: { [id]: true } }
Stats              { CustomersServed, PerfectOrders, ScoopsMade, CoinsEarnedTotal,
                     HighestCombo, EggsHatched, GoldenSprinklesFound, PlaySeconds }
Settings           { MusicVolume 0-1, SfxVolume 0-1, ShowTips, ShowPopups }
Tutorial           { Completed, Step }
Purchases.ReceiptIds { purchaseId } (server bookkeeping; the UI ignores it)
```

## Static game data

The UI reads balance data straight from `ReplicatedStorage.Shared.Data` (flavors, prices,
odds and so on) and computes display values with `Shared/Modules/Formulas.luau`. These are
the same functions the server uses to charge and reward, so the shown and charged amounts
always match.

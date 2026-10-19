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
| `OrderResult` | RemoteEvent | Server → Client | `position: Vector3, coins: number, correct: boolean, comboMultiplier: number` (a customer just paid; coins already include multipliers) | — | — | 2, 4 |
| `Notify` | RemoteEvent | Server → Client | `message: string, kind: "Info" \| "Error"` (short toast text) | — | — | 2 |
| `BuyUpgrade` | RemoteFunction | Client → Server | `statId: string` (a key of `Shared/Data/Upgrades`) | `{ Ok: boolean, Message: string }` | 6 per second (shared with BuyTruckTier) | 3 |
| `BuyTruckTier` | RemoteFunction | Client → Server | `tier: number` (only the next tier is accepted) | `{ Ok: boolean, Message: string }` | 6 per second | 3 |
| `UnlockFlavor` | RemoteFunction | Client → Server | `flavorId: string` | `{ Ok, Message }` (auto-loads into a free truck slot) | Purchase limit | 4 |
| `EquipFlavor` | RemoteFunction | Client → Server | `flavorId: string, slot: number` (1..truck FlavorSlots; moving a loaded flavor swaps slots) | `{ Ok, Message }` | Purchase limit | 4 |
| `UnlockTopping` | RemoteFunction | Client → Server | `toppingId: string` | `{ Ok, Message }` | Purchase limit | 4 |
| `AddTopping` | RemoteFunction | Client → Server | `toppingId: string` (must be unlocked, near your truck, cone not empty, one per cone) | `{ Ok, Message }` | 12 per second (Action) | 4 |
| `SelectFlavor` | RemoteEvent | Client → Server | `slot: number` (which loaded flavor the dispenser scoops) | — | 12 per second (Action) | 4 |

*Later stages add rows here, for example
`UnlockFlavor(flavorId)` and `HatchEgg(eggId, count)`.*

## World interactions (no remotes)

Scooping and serving use **ProximityPrompts**, not remotes. The server handles
`Triggered`, checks ownership, distance, cooldowns and capacity, and ignores everyone
except the owner.

| Prompt | Where | Who can use it | Server checks |
|--------|-------|----------------|---------------|
| `ScoopPrompt` ("Scoop", key E, hold) | `Workspace.Trucks.Truck_<UserId>.Dispenser` | Truck owner | Within range, scoop cooldown (hold time × 0.85), cone not full |
| `ServePrompt` ("Serve", key F) | `Workspace.Customers.Customer.Root` | Customer's owner | Customer is waiting, within 16 studs, cone not empty |

The client hides other players' prompts locally. On touch-only devices it turns the scoop
prompt's hold into a tap.

## Replicated attributes (live, not saved)

**On the local Player** (set by ConeService):

| Attribute | Type | Meaning |
|-----------|------|---------|
| `ConeScoops` | number | Scoops currently on the cone |
| `ConeCapacity` | number | Max scoops (Storage upgrade) |
| `ConeFlavors` | string | Comma-separated flavor ids, bottom to top, e.g. `"Vanilla,Vanilla"` |
| `ConeTopping` | string? | Topping on the cone, or no attribute when there isn't one |
| `ActiveSlot`, `ActiveFlavor` | number, string | Which loaded flavor the dispenser scoops |
| `Combo` | number | Correct orders in a row (set by CustomerService; 0 after a wrong or lost customer) |

**On each truck model** in `Workspace.Trucks`: `OwnerUserId`, `OwnerName`, `Tier`,
`CounterZ`, `StandZ` and `Width`. The dispenser prompt also has a `ScoopSeconds` attribute.

**On each customer model** in `Workspace.Customers`:

| Attribute | Type | Meaning |
|-----------|------|---------|
| `OwnerUserId` | number | The player this customer belongs to |
| `CustomerName`, `CustomerType` | string | Display name; key into `Shared/Data/Customers` |
| `State` | string | `"Arriving"`, `"Waiting"` or `"Leaving"` |
| `OrderFlavor`, `OrderScoops`, `OrderTopping` | string, number, string? | The order (set before `State` becomes `"Waiting"`; no `OrderTopping` = no topping) |
| `PatienceTotal`, `PatienceEnd` | number | Seconds of patience, and the `Workspace:GetServerTimeNow()` time it runs out |
| `Mood` | string | `"Love"` (fast and correct), `"Happy"`, `"Sad"` (wrong order) or `"Angry"` (ran out of patience), set when leaving |

Customer models are pooled: a model leaving `Workspace.Customers` and coming back later is a
new customer.

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

## Purchases

The client never sends a price. `BuyUpgrade` and `BuyTruckTier` name *what* to buy; the
server looks up the price and requirements in `Shared/Modules/ShopRules.luau`, takes the
Coins through `EconomyService.trySpend`, and changes the data. The UI uses the same
`ShopRules` functions for the prices, locked states and the Shop button's red dot, so what's
shown always matches what's charged. The returned `Message` is shown as a toast.

## Static game data

The UI reads balance data straight from `ReplicatedStorage.Shared.Data` (flavors, prices,
odds and so on) and computes display values with `Shared/Modules/Formulas.luau`. These are
the same functions the server uses to charge and reward, so the shown and charged amounts
always match.

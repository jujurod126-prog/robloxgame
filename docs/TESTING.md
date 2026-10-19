# Testing checklist

Work through this before every release. Tick the boxes in your own copy.
Everything happens in Roblox Studio with Rojo connected (`dev.bat` running).

## 0. Studio setup (once)

- **Output window:** View → Output. Errors are red; every failed check here is a bug.
- **Saving in Studio:** Home → Game Settings → Security → turn on **Enable Studio Access to API Services**.
  The place must be published once (File → Publish to Roblox). Without this, data resets every Play.
- **Phones:** Test tab → **Device** emulator. Try a small phone (e.g. iPhone SE), a big phone and a
  tablet, in landscape.
- **More than one player:** Test tab → **Clients and Servers** → 2 or 3 players → Start. Each player
  gets their own window, and there's one server window.
- **Running code as the client** (for the exploit tests): while playing, click the **Client/Server**
  toggle on the Test tab until it says *Client*. Code typed in the **Command Bar** (View → Command Bar)
  then runs as that player, just like an exploiter's script.

Handy chat commands (Studio only): `/data`, `/coins <n>`, `/gems <n>`, `/rep <stars>`, `/skipday`,
`/wipe`, `/pass <id>`, `/rush`, `/weather <kind>`, `/time <hour>`.

## 1. Smoke test (5 minutes, every time you change something)

- [ ] Press Play. The loading screen appears and fades out within a few seconds.
- [ ] No red errors in Output (yellow warnings about missing sounds or DataStores are OK in Studio).
- [ ] Output shows `[DataController] Data received` and `[Dev] Studio commands ready`.
- [ ] You stand behind your truck in Sunny Sidewalk, and customers start walking up.
- [ ] Scoop (hold E at the dispenser), serve (F at a customer), and Coins go up with a popup.
- [ ] Open and close every HUD window (Shop, Pets, Flavors, Quests, Rebirth, Daily, Store, Settings).
      Only one is open at a time, and each one opens and closes with a tween.

## 2. Feature checklist

### Saving (Stage 1)
- [ ] `/coins 5000`, stop, Play again: you still have the Coins.
- [ ] Buy something, then leave right away (within 1 s). Rejoin and it's still bought.
- [ ] `/wipe` resets you to a new player, and the HUD, truck and windows all update.
- [ ] Clients and Servers with 2 players: each player's data is separate.

### Truck, scooping and serving (Stages 2 and 4)
- [ ] You can't scoop more than the cone holds (Storage upgrade).
- [ ] Holding the scoop prompt faster than the scoop time does nothing extra.
- [ ] A correct order pays more and builds the combo. From 5 in a row you get x1.1, up to x2.
- [ ] A wrong order pays less, the customer looks sad and the combo resets.
- [ ] A customer who runs out of patience leaves angry, and Reputation drops.
- [ ] Toppings: unlock one in the Flavor Lab, add it to the cone, and only one fits per cone.
- [ ] Flavor slots: switching the active flavor at the dispenser scoops that flavor.
- [ ] Player 2 can't scoop at your truck or serve your customers (their prompts are hidden).

### Shop and upgrades (Stage 3)
- [ ] Every upgrade shows the right price and level and stops at max level.
- [ ] Buying without enough Coins shows a red error toast and changes nothing.
- [ ] Buying a truck tier rebuilds the truck, you get moved behind it, and confetti plays.
- [ ] The Shop button's red dot shows only when you can afford something.

### Flavors and toppings (Stage 4)
- [ ] Locked flavors show their price. Rebirth-locked flavors say so.
- [ ] Unlocking a flavor auto-loads it into a free slot. Moving flavors between slots swaps them.

### Neighborhoods and customers (Stage 5)
- [ ] Gates show their price, unlock with confetti, and the barrier opens only for you.
- [ ] Teleport pads take you and your truck to the area. Locked areas refuse with a toast.
- [ ] The lighting and the HUD area name change per area.
- [ ] `/rep 5`: special customers (Tourist, VIP Critic, Influencer) appear, with their announcements.

### Pets (Stage 6)
- [ ] Hatch 1 and hatch 3: the animation plays, and the pets appear in My Pets.
- [ ] Equip up to the slot limit. Pets follow you, and their boosts show and apply.
- [ ] Lock a pet: it can't be deleted or merged.
- [ ] Merge 5 copies into a golden one, with confetti. Equipped copies stay equipped as the golden one.
- [ ] Inventory full (100): hatching refuses.

### Rebirth, quests, daily, achievements (Stage 7)
- [ ] `/coins 2500000` → Rebirth. Coins, tier and upgrades reset; the multiplier and Token go up; confetti.
- [ ] Skills: prerequisites are enforced, and Tokens are spent.
- [ ] Quests progress as you play, can be claimed once, and `/skipday` gives new ones within a minute.
- [ ] Daily reward claims once, then shows a countdown. `/skipday` lets you claim day 2.
- [ ] Achievements unlock and can be claimed once.

### Events, audio, store, tutorial (Stage 8)
- [ ] `/rush`: the banner counts down, customers come faster, +5 Gems, and the music switches if set.
- [ ] `/weather Rain` shows rain and slower customers. `/weather Heatwave` shows a warm tint and more
      customers. `/weather Clear` turns it off.
- [ ] `/time 18`, then `/time 2`: the sky moves smoothly into sunset and then night.
- [ ] `/pass VipTruck` makes the truck gold and adds a [VIP] chat tag. `/pass DoubleCoins` doubles
      payouts. `/pass AutoServe` serves customers for you. `/pass ExtraPetSlots` adds 2 slots.
- [ ] Settings: the sliders change the volume while dragging, and everything is remembered after a rejoin.
- [ ] Turning "Coin popups" off hides the floating coins.
- [ ] Store: placeholder items say "Coming soon"; real ones open the Roblox purchase prompt.
- [ ] Tutorial (after `/wipe` and a rejoin): it walks through scoop → serve → upgrade → Flavor Lab,
      Skip ends it for good, and turning "Show tips" off hides it.
- [ ] The leaderboard wall in the Hub fills in (only in a published place with API access).

## 3. Phones and tablets (Device emulator)

- [ ] Nothing overlaps on the smallest phone: currencies, the area badge, the 8 menu buttons, the
      order bar, toasts, the event banner and the tutorial tip.
- [ ] Every button is easy to tap (44 px or bigger), including the window X buttons.
- [ ] Windows fit on screen, and long lists scroll.
- [ ] The scoop prompt works with a tap, and the Settings sliders work with a finger.
- [ ] Rotating or resizing the window keeps the layout sane.

## 4. Multiplayer (Clients and Servers, 3 players)

- [ ] Each player gets their own truck lot. Trucks never overlap.
- [ ] Pets, trucks and VIP tags of other players are visible.
- [ ] One player leaving doesn't break anyone else's customers or truck.
- [ ] Rush Hour and weather happen for everyone at once.
- [ ] Friend bonus: test in a live server with a real friend; the "Friend bonus" chip appears.

## 5. Exploit tests (run as the CLIENT in the command bar)

Each line should do **nothing** except maybe show an error toast. Coins, Gems and pets must not
change unfairly, and the server Output must not show red errors.

```lua
local R = game.ReplicatedStorage.Remotes
R.BuyUpgrade:InvokeServer(0/0)                -- NaN
R.BuyUpgrade:InvokeServer({})                 -- wrong type
R.BuyTruckTier:InvokeServer(99)               -- skip ahead
R.EquipFlavor:InvokeServer("Vanilla", -1)     -- bad slot
R.HatchEgg:InvokeServer("Basic", 1000)        -- huge count
R.HatchEgg:InvokeServer("Basic", 0.5)         -- fraction
R.ClaimDaily:InvokeServer()                   -- twice in a row: the second must fail
R.ClaimQuest:InvokeServer(1)                  -- unfinished quest
R.UpdateSettings:InvokeServer({ MusicVolume = 1e309, Coins = 999999 })
R.TutorialProgress:InvokeServer(1e9, "yes")
for i = 1, 500 do R.BuyUpgrade:InvokeServer("MoveSpeed") end  -- spam: rate limited
```

Also try these:
- [ ] Prompts: exploiters can trigger a ProximityPrompt from any distance. Studio can't do this, so it
      was checked in the code review instead: the server re-checks distance, ownership and cooldown on
      every scoop, serve and unlock.
- [ ] Setting an attribute on yourself in the client (`game.Players.LocalPlayer:SetAttribute("ConeScoops", 99)`)
      changes nothing on the server. Serving still uses the real cone.

## 6. Performance

- [ ] **F9 → Memory:** play for 10 minutes. `PlaceMemory` and the instance count level off and keep no
      steady climb.
- [ ] **Ctrl+F6 (MicroProfiler)** on a phone emulator: no frame spikes over 16 ms while serving.
- [ ] **Shift+F5 → Network:** data received per player stays low (a few KB/s) while serving.
- [ ] **View → Stats:** the part count in the Hub stays under about 5,000.

## 7. Before you publish

- [ ] All IDs you want are filled in `Shared/Modules/Assets.luau` (music, SFX, passes, products, badges).
- [ ] `GameConfig.Data.ForceMockInStudio` is `false`, and `StoreName` hasn't changed (changing it wipes everyone).
- [ ] Game Settings → Security: API services on, and HTTP off (not needed).
- [ ] Game passes and Gem packs are created and **on sale** in the Creator Dashboard.
- [ ] Publish, then join the live game from the website on a phone and a PC, and run the smoke test there.

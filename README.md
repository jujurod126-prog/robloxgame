# Ice Cream Truck Simulator

A cozy cartoon Roblox simulator written in Luau and synced into Studio with Rojo.
Start as a tiny pushcart and build the biggest ice cream empire in town.

## Setup (once)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run this in the repo folder:
   ```sh
   rokit install
   ```
   This installs the pinned versions of Rojo, Selene and StyLua from `rokit.toml`.
2. Install the Rojo plugin in Studio:
   ```sh
   rojo plugin install
   ```
3. Create or open your place in Studio and **publish it** (File → Publish to Roblox).
4. In Studio, go to *Game Settings → Security* and turn on **Enable Studio Access to API Services**.
   You need this to test saving.

## Daily workflow

```sh
rojo serve            # then click "Connect" in the Rojo plugin inside Studio
selene src            # lint
stylua src            # format
```

Files on disk sync into Studio live. Edit code here, not in Studio, or your Studio changes
will be overwritten.

## Auto-updating code (Windows)

Clone the repo with Git once, then double-click **`dev.bat`**. It starts Rojo and pulls the
latest code from GitHub every 30 seconds, so new changes appear in Studio on their own.
Code changes don't affect a game that's already running in Play mode, so press Stop and Play
again after an update.

Don't edit files in this folder by hand, or the automatic update will stop (it tells you
when that happens).

## Project layout

```text
src/
  ReplicatedStorage/Shared/        -> ReplicatedStorage.Shared (server + client)
    Data/      balance tables: flavors, toppings, trucks, upgrades, neighborhoods,
               customers, pets, eggs, rebirth skills, quests, achievements, daily
               rewards, cosmetics, Robux products, GameConfig (global knobs)
    Modules/   Assets (ALL asset IDs), Formulas (all math), Remotes (all remote
               names), Signal, TableUtil
    Types/     Luau types for PlayerData and every data table
  ServerScriptService/
    Main.server.luau   boots every service (Init, then Start)
    Services/  DataService (saving + sync) and stubs for later stages
    Modules/   DataTemplate, DataMigrations, RateLimiter, GameDataValidation, Orders,
               Customer/CustomerRig/CustomerPicker, World/ (WorldBuilder + Props)
    Packages/  ProfileStore (vendored, unmodified, see third_party/)
  StarterPlayer/StarterPlayerScripts/
    Main.client.luau   boots every controller
    Controllers/       DataController (client data copy), HUD, shop, notifications, ...
    UI/                Theme (colors/fonts/sizes), UILib (UI builders), WindowManager, Cleaner
docs/
  UI_CONTRACT.md   remotes, their arguments, the PlayerData shape and how it syncs
  BALANCE.md       upgrade costs and time-to-afford table
```

## The world

`WorldBuilder` builds the Hub and the 5 neighborhood islands from `Shared/Data/WorldLayout.luau`
(where each area is) every time the server starts. To use your own map instead, build it in
Studio inside a Folder named **`World`** in Workspace. Then the generated one is skipped. Keep the
tags described at the top of `ServerScriptService/Modules/World/WorldBuilder.luau`: `TravelPad`
parts, `Gate_<id>` models, and `SignText` / `OpensWindow` attributes. Also keep each area's
`LotRowZ` row free for trucks.

## Code rules

- Use `task.wait` / `task.spawn` / `task.delay`, never `wait` / `spawn` / `delay`.
- The server validates every request. The client never sends amounts or prices.
- Saved data changes only through `DataService.set / update / increment`.
- Asset IDs are only ever written in `Shared/Modules/Assets.luau`, and
  placeholders are `"rbxassetid://0"` or `0`.
- All UI is created in code (Stage 3+). `StarterGui` stays empty.

## Studio test commands

These only work in Studio and are typed into chat:

| Command          | Effect                                   |
|------------------|------------------------------------------|
| `/data`          | Print your saved data to the Output      |
| `/coins <n>`     | Add n Coins (negative to remove)          |
| `/gems <n>`      | Add n Gems                                |
| `/rep <stars>`   | Set your Reputation (1-5) to test special customers |
| `/skipday`       | Pretend a day passed (daily reward ready, new quests within a minute) |
| `/wipe`          | Reset your data to a brand-new player     |

## Art (sprite sheets)

UI art is packed into a few 1024×1024 sprite sheets, so you upload 4 images instead of dozens.

```text
assets/sprites/source/   your original art sheets
assets/sprites/parts/    one transparent PNG per sprite (PetPenguin.png, TruckUfo.png, ...)
assets/sprites/SpriteSheet1-4.png   <- upload these to Roblox
```

1. In Studio, open **View → Asset Manager → Images → Bulk Import** and pick the 4 `SpriteSheet` PNGs.
2. Right-click each uploaded image, choose **Copy Asset ID**, and paste it into
   `src/ReplicatedStorage/Shared/Modules/Assets.luau` as `SPRITE_SHEET_1` … `SPRITE_SHEET_4`.
   Use the matching numbers: SpriteSheet1.png goes in SPRITE_SHEET_1, and so on.

**Adding new art:** put a transparent PNG named after the sprite into `assets/sprites/parts`,
run `python3 tools/sprites/pack.py` (needs Python and `pip install pillow`), and re-upload any sheets
that changed. Or send me the art and I'll do it.

## Third-party code

- [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) by loleris, Apache-2.0.
  See `third_party/ProfileStore/`.

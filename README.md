# Icebox (`dj-icebox`)

Rebel Roleplay jewelry business for **qbx_core**, **ox_lib**, **ox_inventory**, and **ox_target**.

## What you get

- Icebox job (Apprentice → Owner) with duty, vault, showcase stash, and boss menu
- **Player-owned stock**: employees buy materials, craft pieces, and put them in the showcase. Customers only buy what is in the case — nothing auto-restocks
- Separate dock **supplier** for metals and stones (Icebox job only, not at the store)
- Workshop NUI: unique recipes per piece, batch craft (up to 5), or pay a rush fee to skip materials
- Wearable male Icebox chains (component 7 drawables 278–287) plus watches
- ox_target snatch on players who are actually wearing a chain
- Fence ped that only buys snatched (`hot`) pieces
- Diamond tester to inspect someone else's neck
- Server-side anti-exploit: distance, job/duty, rate limits, catalog whitelist, craft/snatch tokens, money/item rollback

## Wearables

Chains use **clothing component 7** (accessories) on **male** freemode only this update. Watches use **prop 6**.

The live Icebox book is the custom male pack:

| Item | Label | Drawable | Texture |
| --- | --- | ---: | ---: |
| `icebox_trapper` | Trapper Chain | 278 | 0 |
| `icebox_block_baby` | Block Baby | 279 | 0 |
| `icebox_smokey` | Smokey | 280 | 0 |
| `icebox_smokey_2` | Smokey 2 | 280 | 2 |
| `icebox_self_made` | Self Made | 281 | 0 |
| `icebox_dumb_rich` | Dumb Rich | 282 | 0 |
| `icebox_face_shot` | Face Shot | 283 | 0 |
| `icebox_slime` | Slime | 284 | 0 |
| `icebox_est` | EST | 285 | 0 |
| `icebox_sharky` | Sharky | 286 | 0 |
| `icebox_capalot` | Capalot | 287 | 0 |

Start the clothing stream resource **before** `dj-icebox` so those drawables exist:

```cfg
ensure icebox_chains
ensure dj-icebox
```

Rename `icebox_chains` if your pack folder is named something else. Female chain visuals are not in this drop — using a chain on a female ped still equips the item (snatch/tester work) but does not change clothing.

To run **item-only** (no clothing change) while you source a pack:

```lua
Config.Wear.visual = false
```

Equip still marks the piece as worn, so snatch and the tester keep working. Use the item from ox_inventory to put it on or take it off. One chain and one watch at a time.

Snatched pieces are flagged `hot` and cannot be worn (`Config.Wear.allowHot = false`).

## Install

1. Drop this folder into `resources` as **`dj-icebox` only**. Do not also start `djfivem-icebox` — two copies spawn double peds and ox_lib callback errors.
2. Merge `install/job.lua` into `qbx_core/shared/jobs.lua`.
3. Merge `install/items.lua` into `ox_inventory/data/items.lua` (replace any old Icebox chain names — vanilla placeholders are gone).
4. Copy `install/images/*.png` into `ox_inventory/web/images/`. Chain icons are small transparent cutouts of the pack photos.
5. Add to `server.cfg` **after** ox_lib, qbx_core, ox_inventory, ox_target. Start the clothing pack first:

```cfg
ensure icebox_chains
ensure dj-icebox
```

6. Store coords are already set for Rebel Icebox:
   - blip `-603.81, -253.49, 36.38`
   - duty `-617.88, -256.33, 36.38`
   - showroom `-610.42, -251.46, 36.38` and `-605.79, -259.56, 36.38`
   - workshop `-606.56, -270.48, 37.04`
   - vault `-613.40, -264.24, 36.38`
   - boss `-612.18, -261.97, 36.38`
   - clerk `-613.11, -258.72, 36.38, 293.67`
   - fence `-1471.96, -362.05, 40.13, 215.87`
   - supplier (Elysian Island docks) `1234.42, -3204.91, 5.63, 271.18`
7. Restart `ox_inventory` then `dj-icebox`.

Society payouts auto-detect `Renewed-Banking`, `qb-banking`, or `fd_banking`. Boss menu uses `qbx_management` when it is started.

## Player-owned loop

Nothing appears in the showroom until Icebox employees put a finished piece in the **Showcase Stock** stash (`icebox_showcase`). Buying a chain takes that exact item (serial included) out of the case. If the case is empty, the UI shows out of stock.

1. On-duty Icebox goes to the **supplier ped** at the docks (job blip: Icebox Supplier) and buys gold, silver, platinum, diamonds, rubies, links, and polish with **personal cash**.
2. Back at the **workshop**, craft 1–5 of a piece in one session. Each chain has its own recipe. Batch time is `base + (count-1) * base * 0.55`, not a full 5× wait.
3. **Rush craft** skips materials and charges `prices.rush` cash on finish. Still requires the bench, job, grade, and craft time. Server computes the price — the NUI never sends it.
4. Put finished pieces into **Showcase Stock**. Customers cop them from the showroom / clerk.

| Who | ox_target | Result |
| --- | --- | --- |
| Anyone | Browse Icebox | Showroom UI; cash buy **only if stocked** |
| Icebox employee | Duty | Clock in/out |
| On-duty employee | Workshop | Batch craft, rush craft, infuse |
| On-duty employee | Icebox Supplier (docks) | Buy crafting materials |
| On-duty employee | Vault / Showcase | ox_inventory stashes |
| Boss grade | Management | qbx_management |
| Anyone with a worn chain | Use chain item | Toggle wear |
| Anyone | Snatch Chain on a player | Skill check, then steal worn chain as hot |
| Anyone with hot ice | Quiet buyer ped | Fence for a cut of retail |
| Anyone with `icebox_tester` | Test Chain | Clean vs snatched |

## Anti-exploit

- Prices, recipes, and payouts never come from the client
- Craft and snatch use one-time server tokens and reject instant completes
- Every money/item action re-checks distance, job, duty, and inventory
- Failed `AddItem` after a payment or material remove is refunded
- Rate limits on UI, buy, craft, fence, equip, snatch, and supplier
- Snatch requires the victim's **server** wear state, not a client flag

## Config you will actually touch

- `config.lua` — locations, distances, snatch cooldown, duty rules, wear visuals
- `data/catalog.json` — pieces, prices, ingredients, wearable drawables
- `locales/en.json` — copy

## Development

```bash
node tests/run.mjs
```

NUI can be opened in a browser for layout work; it loads `data/catalog.json` in demo mode.

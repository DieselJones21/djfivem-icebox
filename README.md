# Icebox (`dj-icebox`)

Qbox jewelry business for **Icebox**. Employees craft and sell chains. Anyone can wear a piece, get it snatched, and dump hot ice with a quiet buyer.

Built for **qbx_core**, **ox_lib**, **ox_inventory**, and **ox_target**.

## What you get

- Icebox job (Apprentice → Owner) with duty, vault, showcase stash, and boss menu
- Showroom NUI to browse and buy serialized pieces
- Workshop NUI to craft from materials and infuse diamonds/rubies
- Wearable chains and watches (GTA accessory component / watch prop)
- ox_target snatch on players who are actually wearing a chain
- Fence ped that only buys snatched (`hot`) pieces
- Diamond tester to inspect someone else's neck
- Server-side anti-exploit: distance, job/duty, rate limits, catalog whitelist, craft/snatch tokens, money/item rollback

## Wearables

Chains use **clothing component 7** (accessories). Watches use **prop 6**. Default drawable IDs are vanilla freemode values so the script works without a custom chain pack.

If you stream a chain clothing pack, open `data/catalog.json` and set each piece's `wear.male` / `wear.female` `drawable` / `texture` to that pack's numbers.

```json
"wear": {
  "slot": "chain",
  "male": { "type": "component", "id": 7, "drawable": 22, "texture": 0 },
  "female": { "type": "component", "id": 7, "drawable": 22, "texture": 0 }
}
```

To run **item-only** (no clothing change) while you source a pack:

```lua
Config.Wear.visual = false
```

Equip still marks the piece as worn, so snatch and the tester keep working. Use the item from ox_inventory to put it on or take it off. One chain and one watch at a time.

Snatched pieces are flagged `hot` and cannot be worn (`Config.Wear.allowHot = false`).

## Install

1. Drop this folder into `resources` as `dj-icebox`.
2. Merge `install/job.lua` into `qbx_core/shared/jobs.lua`.
3. Merge `install/items.lua` into `ox_inventory/data/items.lua`.
4. Copy `install/images/*.png` into `ox_inventory/web/images/` (optional).
5. Add to `server.cfg` **after** ox_lib, qbx_core, ox_inventory, ox_target:

```cfg
ensure dj-icebox
```

6. Set `Config.Locations` in `config.lua` to your Icebox MLO / storefront. Defaults are a Rockford Hills placeholder.
7. Restart `ox_inventory` then `dj-icebox`.

Society payouts auto-detect `Renewed-Banking`, `qb-banking`, or `fd_banking`. Boss menu uses `qbx_management` when it is started.

## Player flow

| Who | ox_target | Result |
| --- | --- | --- |
| Anyone | Browse Icebox | Showroom UI, cash buy |
| Icebox employee | Duty | Clock in/out |
| On-duty employee | Workshop | Craft + infuse |
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
- Rate limits on UI, buy, craft, fence, equip, and snatch
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

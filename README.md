# rsg-bathing

Interactive bathhouse system for RedM servers running the RSG Framework. Players pay for a bath, scrub themselves clean using the original RDR2 bathing animations, and can upgrade to an NPC-assisted deluxe bath.

## Features

- Bathhouses in Saint Denis, Valentine, Annesburg, Strawberry, Blackwater, Van Horn, Rhodes and Tumbleweed (Tumbleweed uses its own `Pbl_Regular_Outro`)
- Tub steam and per-body-part soap foam effects (from the RDR2 bathing script)
- Attendant voice lines (knock/offer, accept, scrub responses, small talk, farewell) and player sighs
- Health/stamina cores refilled and stress cleared on exit, deluxe bath also fortifies cores (configurable)
- Standard and deluxe (assisted) baths using the native RDR2 anim scenes and move networks
- Server-authorised payments (`RemoveMoney` result checked) with per-player rate limiting
- One player per tub and one bath per player, sessions freed on exit, disconnect or resource stop
- Server-side distance checks on every paid request; deluxe can only be bought once per session
- Undress/redress via rsg-wardrobe, only allowed during an active session
- Cleanliness metadata set to 100 server-side when the bath ends, HUD updated client-side
- Dirt, blood, decals and wetness cleared on exit; health and stamina preserved
- Invincible while bathing
- Map blips (toggleable) and distance-gated proximity loop
- Full cleanup of props, peds, cameras, anim scenes, prompts and blips on resource stop
- Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-wardrobe](https://github.com/Rexshack-RedM/rsg-wardrobe)
- [rsg-hud](https://github.com/Rexshack-RedM/rsg-hud) (optional, for the cleanliness HUD update)

No ox_lib required.

## Installation

1. Place `rsg-bathing` in your `resources/[rsg]` folder.
2. Add to `server.cfg` after its dependencies:
   ```cfg
   ensure rsg-core
   ensure rsg-wardrobe
   ensure rsg-bathing
   ```
3. Set the language with `setr rsg:locale en` (any of the shipped locales).

## Configuration (`config.lua`)

| Option | Description |
|---|---|
| `Config.NormalBathPrice` | Cash price of a standard bath (default `1`) |
| `Config.DeluxeBathPrice` | Cash price of the deluxe upgrade (default `5`) |
| `Config.InteractDistance` | How close to the tub the player must be to see the prompt |
| `Config.ServerMaxDistance` | Max distance the server accepts when paying |
| `Config.ShowBlips` | Show bathhouse blips on the map |
| `Config.Effects` | Toggle tub `steam` and scrub `foam` effects |
| `Config.Speech` | Toggle voice lines and set the attendant small-talk interval |
| `Config.Rewards` | Per bath type: `refillCores`, `fortify` (overpower amount, 0 = off) and `clearStress` |
| `Config.BathingZones` | Anim scene dict, optional `outro`, coords, optional `steam` position, door hash, attendant models and `maidVoice` |
| `Config.BathingModes` | Scrub stages, their transitions and scrub frequency (`deluxe = true` stages are skipped unassisted) |
| `Config.Prompts` | Prompt labels, controls and hold times |

## Usage

Walk up to the tub in any bathhouse and hold the prompt to pay and get in. Hold **Scrub** to clean each body part, buy the **Luxury Service** for an attendant, and use **Get Out** to finish.

## Exports / State

```lua
-- client
LocalPlayer.state.isBathingActive          -- preferred
exports['rsg-bathing']:IsBathingActive()   -- deprecated, kept for compatibility
```

## License

GPL-3.0

Support: https://buymeacoffee.com/rexshack

# rsg-bathing – Docs (v3.0.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports and events
5. Security
6. Server owner how-tos
7. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-wardrobe` |
| `config.lua` | Prices, effects, speech, rewards, bathing zones, prompts |
| `client/client.lua` | Prompts, anim scenes, camera, effects, speech |
| `client/structs.js` | Native struct helper |
| `server/server.lua` | Payment, sessions, undress/redress, cleanliness |
| `server/versionchecker.lua` | GitHub version check |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- Bathhouses: Saint Denis, Valentine, Annesburg, Strawberry, Blackwater, Van Horn, Rhodes and Tumbleweed (own `Pbl_Regular_Outro`).
- Walk to the tub for the bath prompt. A standard bath scrubs yourself with the RDR2 bathing animations; a deluxe bath adds an NPC attendant.
- Tub steam and per-part soap foam effects, attendant voice lines and player sighs.
- On exit: health/stamina cores refilled and stress cleared (deluxe also fortifies cores), dirt, blood, decals and wetness cleared, `cleanliness` metadata set to 100 server-side.
- The player is invincible while bathing. Clothes come off and back on through rsg-wardrobe.
- One player per tub and one bath per player. Sessions free on exit, disconnect or resource stop.

## 3. Configuration
`config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `NormalBathPrice` | `1` | Cash, standard bath |
| `DeluxeBathPrice` | `5` | Cash, deluxe bath |
| `InteractDistance` | `1.0` | Client prompt range |
| `ServerMaxDistance` | `3.0` | Server max distance when paying |
| `ShowBlips` | `true` | Map blips |
| `Effects` | table | `steam`, `foam` |
| `Speech` | table | `enabled`, `chatInterval` (ms) |
| `Rewards` | table | `regular` / `deluxe`: `refillCores`, `fortify`, `clearStress` |
| `BathingZones` | table | Per town: `dict`, `rag`, `consumer`, `lady`, `guy`, `maidVoice`, `door` |
| `BathingModes`, `Prompts` | tables | Modes and prompt labels |

## 4. Exports and events
| Name | Side | Notes |
|---|---|---|
| `IsBathingActive()` | client export | True while bathing |
| `rsg-bathing:client:StartBath` | client event | `(town)` |
| `rsg-bathing:client:StartDeluxeBath` | client event | `(town)` |
| `rsg-bathing:client:ToggleInvincibility` | client event | `(state)` |
| `rsg-bathing:client:RestorePrompts` / `HideDeluxePrompt` | client events | Prompt state |
| `rsg-bathing:server:canEnterBath` | server event | `(town)`; checks money, distance, tub free |
| `rsg-bathing:server:canEnterDeluxeBath` | server event | Deluxe once per session |
| `rsg-bathing:server:setBathAsFree` | server event | Releases the tub |
| `rsg-bathing:server:undressPlayer` / `dressPlayer` | server events | Only in an active session |

## 5. Security
Payments are server-authorised (the `RemoveMoney` result is checked) with per-player rate limiting. Every paid request checks distance on the server. Deluxe can only be bought once per session. Undress/redress is only allowed during an active session.

## 6. How-tos
- Change prices: edit `NormalBathPrice` and `DeluxeBathPrice`.
- Make deluxe stronger: raise `Rewards.deluxe.fortify`.
- Optional: rsg-hud updates the cleanliness display.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| No prompt | Stand at the tub within `InteractDistance`; check the tub isn't in use |
| Player stays undressed | Check rsg-wardrobe is running; restart the resource |
| No steam/foam | Check `Effects` |
| Bath refused | Not enough cash, or too far from the tub |

Support the Project : https://rexshack.tebex.store/

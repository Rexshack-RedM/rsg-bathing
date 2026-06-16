# rsg-bathing

Interactive bathing system for RedM servers using RSG Core.

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)
- [rsg-wardrobe](https://github.com/Rexshack-RedM/rsg-wardrobe)
- [rsg-appearance](https://github.com/Rexshack-RedM/rsg-appearance)

## Installation

1. Place `rsg-bathing` inside your `resources/[rsg]` folder.
2. Ensure all dependencies are installed and started.
3. Adjust bath prices and zone coordinates in `config.lua`.
4. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-wardrobe
   ensure rsg-appearance
   ensure rsg-bathing
   ```
5. Restart your server.

## Configuration

- `Config.NormalBathPrice` — price for a standard bath (default: 1)
- `Config.DeluxeBathPrice` — price for an assisted deluxe bath (default: 5)
- `Config.BathingZones` — bathhouse locations, animations, door hashes, and NPC models
- `Config.BathingModes` — scrub animations and their scrub frequencies

## Features

- Bathhouses in Saint Denis, Valentine, Annesburg, Strawberry, Blackwater, Vanhorn, and Rhodes
- Normal and deluxe (NPC-assisted) baths with unique animations
- Server-authorised payment with session locking to prevent concurrent use
- Invincibility toggled server-side during bathing
- Automatic undress/dress via rsg-wardrobe exports
- Wetness cleared on bath exit
- Localised prompts and notifications via ox_lib
- Server-side validation of all incoming events

## Exports

```lua
exports('IsBathingActive', function()
    return LocalPlayer.state.isBathingActive
end)
```

## License

GPL-3.0

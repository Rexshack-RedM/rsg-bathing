<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🛁 rsg-bathing
**Interactive bathing system for RedM servers using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Immersive bathhouses where players can pay for a normal or deluxe bath.  
> Includes realistic animations, NPC attendants, and localized prompts for Saint Denis, Valentine, and Annesburg.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠
- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️ *(for prompts and notifications)*
- [**oxmysql**](https://github.com/overextended/oxmysql) 🗄️ *(for character data)*

**Locales:** `locales/en.json, fr.json, el.json, pt-br.json` (loaded via `lib.locale()`).

---

## ✨ Features

### 🧭 Bathing System
- Available in **Saint Denis**, **Valentine**, and **Annesburg**.
- Choose between:
  - **Normal Bath** → base price (default `$1`)
  - **Deluxe Bath** → assisted version (default `$5`)
- Dynamic **NPC attendants** spawn at each bathhouse.
- Integrated **blips and prompts** for easy interaction.

### 💰 Payment Logic
- Server-side validation via RSG Core (`Player.Functions.RemoveMoney('cash')`).
- Prevents simultaneous use — only one player per bath at a time.
- Notifies players if:
  - insufficient funds (`notify_not_enough_money`)
  - bath is already occupied (`notify_occupied`).

### 🎬 Immersive Animations
- Uses RDR2 native bathing animations:
  - `script@mini_game@bathing@BATHING_INTRO_OUTRO_ST_DENIS`
  - `script@mini_game@bathing@BATHING_INTRO_OUTRO_VALENTINE`
  - `script@mini_game@bathing@BATHING_INTRO_OUTRO_ANNESBURG`
- Includes door closing, ragdoll positioning, and fade effects.

### ⚙️ Config Overview
```lua
Config.NormalBathPrice = 1
Config.DeluxeBathPrice = 5

Config.BathingZones = {
    ["SaintDenis"] = {
        dict = "script@mini_game@bathing@BATHING_INTRO_OUTRO_ST_DENIS",
        rag = vector4(2629.4, -1223.33, 58.57, -92.66),
        consumer = vector3(2632.6, -1223.79, 59.59),
        lady = `CS_BATHINGLADIES_01`,
        guy = `CS_LeviSimon`,
        door = 779421929
    },
    ["Valentine"] = {
        dict = "script@mini_game@bathing@BATHING_INTRO_OUTRO_VALENTINE",
        rag = vector4(-317.37, 761.8, 116.44, 10.365),
        consumer = vector3(-320.56, 762.41, 117.44),
        lady = `CS_BATHINGLADIES_01`,
        guy = `CS_LeviSimon`,
        door = 142240370
    },
    ["Annesburg"] = {
        dict = "script@mini_game@bathing@BATHING_INTRO_OUTRO_ANNESBURG",
        rag = vector4(2952.65, 1334.7, 43.44, -291.27),
        consumer = vector3(2950.42, 1332.15, 44.44),
        lady = `CS_BATHINGLADIES_01`,
        guy = `CS_LeviSimon`,
        door = 1041746010
    }
}
```

---

## 📂 Installation
1. Place `rsg-bathing` inside your `resources/[rsg]` folder.
2. Ensure **rsg-core**, **ox_lib**, and **oxmysql** are installed.
3. Adjust bath prices and zone coordinates in `config.lua`.
4. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-bathing
   ```
5. Restart your server.

---

## 🌍 Locales
Provided in `locales/`: `en`, `fr`, `el`, `pt-br`.  
Uses `lib.locale()` for multilingual notifications and prompts.

---

## 🧩 Developer Notes
Exports a state variable:
```lua
exports('IsBathingActive', function()
    return LocalPlayer.state.isBathingActive
end)
```
Use this to check if a player is currently in a bathing sequence.

---

## 💎 Credits
- Original RSG adaptation by **Rexshack Gaming**  
- Base idea origin unknown (if you build this resource and have any issues with it please contact me)  
- Community testers and translators  
- License: GPL‑3.0  

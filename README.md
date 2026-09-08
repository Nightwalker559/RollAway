# RollAway

Bonus Roll automation, loot history cleanup, and group quality-of-life tools for World of Warcraft (Midnight, Season 2).

**Author:** Nightwalker559
**Optional dependency:** ElvUI (native skin support throughout)

---

## Features

### Bonus Roll Auto-Pass
Automatically passes on the Bonus Roll prompt for content you've checked off:
- Dungeons (Season 1 & 2, matched by map)
- Delves (Season 1 & 2)
- Raid bosses (per-boss toggle, or auto-pass an entire raid difficulty — combinable)
- Open World / Prey encounters
- World Bosses / Lairs fought as raid instances (e.g. Tidebound Grotto) are treated as regular raid bosses

### Legacy Auto-Roll
Auto-rolls Need/Greed/Transmog on loot from legacy Dragonflight & The War Within raids. Priority chain: Need → Greed → Transmog, all combinable. Optional account-wide setting.

### Group Loot History
Cleans up and controls visibility of the Group Loot History frame — auto-hide per raid difficulty (LFR/Normal/Heroic/Mythic), visible by default.

### Reminders
- **Bonus Roll reminder** on entering a Mythic dungeon/raid — shows Voidcore currency and available rolls.
- **Instance join reminder** with optional auto-open of your keystone companion addon (BigWigs Keystones or Details! Keystones).
- **Ready Check talent reminder.**
- **Great Vault reminder** — popup on login if you have unclaimed rewards (once per weekly reset). Manual check: `/rawvault`
- **Paragon Bag reminder** — popup when Paragon quests are available across all Midnight factions, with turn-in NPC & zone. Manual check: `/rawparagon`

### Quality of Life
- **LFG Quick Create** — one-click dungeon listing buttons in Group Finder, with default playstyle auto-apply.
- **Automatic Combat Logging** — enables `LoggingCombat` based on zone/difficulty (Scenarios, M+/Mythic dungeons, raid difficulties, Delves, Arena), individually togglable. Makes MRT's logging unnecessary.
- **Auction House filter** — keeps "Current Expansion Only" enforced.
- Durability warning, Omniumfoliant & Great Vault character frame buttons, and more.

---

## Slash Commands

| Command | Description |
| --- | --- |
| `/raw` or `/rollaway` | Open options |
| `/rawvault` | Manually check Great Vault status |
| `/rawparagon` | Manually check Paragon Bag availability |
| `/rawwhats` | Show the "What's New" window |

---

## Options

Access via `/raw` or **Interface > AddOns > RollAway**. Settings are organized by tab: General, Dungeons, Raids, Delves, Open World, Legacy, and QoL (Filter, LFG, Logs, Reminder).

---

## Installation

1. Download and extract to `Interface/AddOns/RollAway`.
2. Ensure the folder is named exactly `RollAway`.
3. Restart or reload WoW (`/reload`).

---

## Changelog

Full version history in `CHANGELOG.md` (same package/repo).

---

## Support

Report bugs or suggest features via CurseForge or Wago.

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
- Prey encounters in the open world (Midnight zones only, including the Coiled Isle)
- World Bosses / Lairs fought as raid instances (e.g. Tidebound Grotto) are treated as regular raid bosses

### Legacy Auto-Roll
Auto-rolls Need/Greed/Transmog on loot from legacy Dragonflight & The War Within raids. Priority chain: Need → Greed → Transmog, all combinable, or Pass. Optional account-wide setting.

### Group Loot History
Cleans up and controls visibility of the Group Loot History frame — auto-hide per raid difficulty (LFR/Normal/Heroic/Mythic) in current raids, plus a separate switch to always hide it in legacy raids. Visible by default.

### Reminders
- **Bonus Roll reminder** on entering a Mythic dungeon/raid — shows Voidcore currency and available rolls, and whether a Bonus Roll auto-pass is active there. A separate safety-net warning (on by default) appears only when an auto-pass is active, so a forgotten checkbox does not cost you a roll.
- **Instance join reminder** (Group Finder M+ only, shows the listed key level such as +14) with optional auto-open of your keystone companion addon (BigWigs Keystones, Details! Keystones, or RollAway's own Teleport Reminder showing the exact dungeon portal).
- **RollAway Portal Overview** — own portal reference frame (current season or all learned dungeons by expansion), open anytime with `/rat`.
- **Ready Check talent reminder**, optionally showing your active spec/talent build.
- **Great Vault reminder** — popup on login at max level if you have unclaimed rewards (once per weekly reset). Manual check: `/rawvault`
- **Paragon Bag reminder** — popup when Paragon quests are available across all Midnight factions, with turn-in NPC & zone. Manual check: `/rawparagon`
- Reminder positions can be locked and reset to default from the options.

### Quality of Life
- **LFG Quick Create** — one-click dungeon listing buttons in Group Finder, with default playstyle auto-apply.
- **Automatic Combat Logging** — enables `LoggingCombat` based on zone/difficulty (Scenarios & Delves, M+/Mythic dungeons, raid difficulties), individually togglable. Makes MRT's logging unnecessary.
- **Tank marker** — in current-season Mythic dungeons a popup offers to put a raid marker (default: square) on your group's tank. It needs your click: since 12.0 addons cannot set markers themselves. Off by default.
- **Automatic quests** — accepts regular / daily / weekly quests and turns in finished ones at NPCs (never quests that cost gold or currency or have several rewards to choose from), optional modifier key to pause or require.
- **Hide Blizzard UI elements** — red error text (important errors stay visible, optionally the yellow quest-progress messages too), Talking Head, boss banner, event toasts (incl. the bonus objective banner), alert pop-ups (loot, achievements), world map trackers (bounty board, faction button, eye), crafting output log. Everything is off by default.
- **Auction House filter** — keeps "Current Expansion Only" enforced.
- Durability warning, Omniumfoliant & Great Vault character frame buttons, and more.

---

## Slash Commands

| Command | Description |
| --- | --- |
| `/raw` or `/rollaway` | Open options |
| `/rat` | Toggle RollAway Portal Overview |
| `/rawvault` | Manually check Great Vault status |
| `/rawparagon` | Manually check Paragon Bag availability |
| `/rawtank` | Show the tank marker popup right now |

---

## Options

Access via `/raw` or **Interface > AddOns > RollAway**. Settings are organized by tab: General, Dungeons, Raids, Delves, Open World, Legacy, plus the QoL (Character, Filter, Hide, LFG, Logs, Misc, Quests, Reminder) and Profile subcategories.

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

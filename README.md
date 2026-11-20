# RollAway & Tools

Auto-pass bonus rolls, confirm or auto-roll loot, tidy the loot history, plus small helpers for groups, crafting and vendors. Switch every feature on or off in one window.

For World of Warcraft: Midnight (Season 2, 12.1 and 12.1.5). English and German. Optional: ElvUI (native skin).

**Author:** Nightwalker559 · **License:** MIT with AI restriction

---

## At a glance

- **One window.** `/raw` or a right click on the minimap button opens the options; `/raw features` (or a left click) opens the feature overview with every feature, its state and a checkbox.
- **Everything has its own switch.** Most helpers are off by default.
- **Profiles.** Share settings between characters or keep separate setups, with text export and import. Bonus roll selections are always per character.

## Loot and bonus rolls

- **Bonus roll auto-pass** for the Midnight content you tick: dungeons, delves, raid bosses (per boss or a whole difficulty) and Prey hunts. World bosses and lairs fought as raid instances count as raid bosses. A popup on entering a Mythic dungeon or raid shows your Voidcore currency and rolls, with an optional warning when an auto-pass is active.
- **Roll confirmation:** a popup before you roll Need, Greed, Transmog or Pass on group loot, for any raid.
- **Legacy auto-roll** for older raids (Dragonflight, The War Within): Need, then Greed, then Transmog, or Pass; optionally account-wide.
- **Group loot history:** closes after the last roll with your delay and a safety timeout, optionally hidden per raid difficulty.

## Group and instances

- **LFG quick create** buttons for your dungeons; **auto-accept invites** from guild and friends.
- **Tank marker** popup in current-season Mythic dungeons (off by default; it needs your click).
- **Instance join reminder** with the listed key level and a button for your keystone addon or the built-in portal reminder.
- **Portal overview** (`/rat`) for the season or by expansion, optionally with your group's keystones.
- **Group item level** (with ElvUI) in unit frames via the tags `[raw:ilvl]` and `[raw:ilvl:plain]`.
- **Ready check reminder** for talents; **automatic combat logging** by zone and difficulty.

## Quests, crafting and vendors

- **Automatic quests** at NPCs; it never takes quests that cost gold or currency or offer several rewards. A modifier key pauses or requires it.
- **Crafting salvage slot:** fills salvage recipes with the first item you ticked and refills it (off by default).
- **Vendor filter:** dims recipes, toys, mounts, heirlooms, housing decor, pets and transmog you already know or own.
- **Auto repair** (yourself or guild funds); the Auction House keeps **Current Expansion Only** on.

## Reminders and clutter

- **Great Vault** popup on login (`/rawvault`), **Paragon bag** popup (`/rawparagon`), durability warning and buttons on the character frame, optional **Hunter pet reminder**. Positions can be locked or reset.
- **Hide clutter** (all off by default): red error text (important errors stay), Talking Head, boss banner, event toasts, alert pop-ups, world map trackers, crafting output log.

## Commands

| Command | What it does |
| --- | --- |
| `/raw`, `/rollaway` | Open or close the options |
| `/raw features` | Feature overview |
| `/rat` | Portal overview |
| `/rawvault`, `/rawparagon` | Check the Great Vault / Paragon bags now |
| `/rawtank` | Show the tank marker popup now |

---

See the [changelog](https://github.com/Nightwalker559/RollAway/blob/main/CHANGELOG.md) for the version history.

## Feedback

Found a bug or have an idea? [Open an issue on GitHub](https://github.com/Nightwalker559/RollAway/issues).

## License

MIT with AI restriction (no use for AI or machine learning), see [LICENSE.md](https://github.com/Nightwalker559/RollAway/blob/main/LICENSE.md).

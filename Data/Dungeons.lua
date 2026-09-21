-- RollAway - Data/Dungeons.lua
-- Dungeon definitions, indexed by season number: RA.DUNGEONS[seasonNumber].
-- Add a new season by appending RA.DUNGEONS[n] = { ... } below.

_G["RollAway"] = _G["RollAway"] or {}
local RA = _G["RollAway"]

RA.DUNGEONS = RA.DUNGEONS or {}

------------------------------------------------------------------------
-- Season 1 dungeon definitions
-- portalSpellID: M+20 achievement teleport spell (same mechanic as
-- Season 2, see Modules\TeleportReminder.lua). Kept for the "all learned
-- dungeon teleports" overview even after the season rotates out.
------------------------------------------------------------------------
RA.DUNGEONS[1] = {
    { key = "windrunner_spire",    mapID = 2805, cmID = 557, lfgID = 1542, portalSpellID = 1254400, expansion = "midnight" },
    { key = "maisara_caverns",     mapID = 2874, cmID = 560, lfgID = 1764, portalSpellID = 1254559, expansion = "midnight" },
    { key = "magisters_terrace",   mapID = 2811, cmID = 558, lfgID = 1760, portalSpellID = 1254572, expansion = "midnight" }, -- reworked for Midnight, counts as new content
    { key = "nexus_point_xenas",   mapID = 2915, cmID = 559, lfgID = 1768, portalSpellID = 1254563, expansion = "midnight" },
    { key = "algeth_ar_academy",   mapID = 2526, cmID = 402, lfgID = 1160, portalSpellID = 393273,  expansion = "dragonflight" }, -- revived DF dungeon, kept its DF teleport
    { key = "seat_of_triumvirate", mapID = 1753, cmID = 239, lfgID = 486,  portalSpellID = 1254551, expansion = "legion"   }, -- Argus dungeon, revived for Midnight S1
    { key = "skyreach",            mapID = 1209, cmID = 161, lfgID = 182,  portalSpellID = 159898,  expansion = "wod"      }, -- revived WoD dungeon, kept its WoD teleport
    { key = "pit_of_saron",        mapID = 658,  cmID = 556, lfgID = 1770, portalSpellID = 1254555, expansion = "wrath"    }, -- revived Wrath dungeon, new S1 achievement
}

------------------------------------------------------------------------
-- Season 2 dungeon definitions (12.1)
-- portalSpellID: Mythic+20 achievement teleport spell (used by the
-- teleport reminder in Modules\TeleportReminder.lua). Only known to
-- players who have timed a +20 in that dungeon this season.
------------------------------------------------------------------------
RA.DUNGEONS[2] = {
    { key = "altar_of_fangs",       mapID = 2993, cmID = 588, lfgID = 1933, portalSpellID = 1286812, expansion = "midnight" },
    { key = "kings_rest",           mapID = 1762, cmID = 249, lfgID = 514,  portalSpellID = 1286831, expansion = "bfa"      }, -- revived BfA dungeon, new S2 achievement
    { key = "ruby_life_pools",      mapID = 2521, cmID = 399, lfgID = 1176, portalSpellID = 393256,  expansion = "dragonflight" }, -- revived DF dungeon, kept its DF teleport
    { key = "temple_of_sethraliss", mapID = 1877, cmID = 250, lfgID = 504,  portalSpellID = 1286828, expansion = "bfa"      }, -- revived BfA dungeon, new S2 achievement
    { key = "murder_row",           mapID = 2813, cmID = 587, lfgID = 1950, portalSpellID = 1286809, expansion = "midnight" },
    { key = "den_of_nalorakk",      mapID = 2825, cmID = 586, lfgID = 1952, portalSpellID = 1286807, expansion = "midnight" },
    { key = "blinding_vale",        mapID = 2859, cmID = 584, lfgID = 1949, portalSpellID = 1286801, expansion = "midnight" },
    { key = "voidscar_arena",       mapID = 2923, cmID = 585, lfgID = 1951, portalSpellID = 1286804, expansion = "midnight" },
}

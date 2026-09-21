-- RollAway - Data/LegacyDungeonTeleports.lua
-- M+20 achievement teleport spells for dungeons outside the current and
-- previous season pool (RA.DUNGEONS). Not season-indexed - append new
-- entries here once a dungeon rotates out of RA.DUNGEONS. Used for the
-- "all learned dungeon teleports" overview, separate from the current-
-- season portal reminder in Modules\TeleportReminder.lua.
-- `expansion` groups entries into category headers in Modules\PortalOverview.lua.
-- Faction-specific teleports (Siege of Boralus / The MOTHERLODE!!) are
-- intentionally omitted - resolving those needs the player's faction at
-- runtime, not a static ID.

_G["RollAway"] = _G["RollAway"] or {}
local RA = _G["RollAway"]

RA.LEGACY_DUNGEON_TELEPORTS = {
    -- Cataclysm
    { key = "vortex_pinnacle",             portalSpellID = 410080,  expansion = "cataclysm"    },
    { key = "throne_of_the_tides",         portalSpellID = 424142,  expansion = "cataclysm"    },
    { key = "grim_batol",                  portalSpellID = 445424,  expansion = "cataclysm"    },
    -- Mists of Pandaria
    { key = "temple_of_the_jade_serpent",  portalSpellID = 131204,  expansion = "mop"          },
    { key = "siege_of_niuzao",             portalSpellID = 131228,  expansion = "mop"          },
    { key = "scholomance",                 portalSpellID = 131232,  expansion = "mop"          },
    { key = "scarlet_monastery",           portalSpellID = 131229,  expansion = "mop"          },
    { key = "scarlet_halls",               portalSpellID = 131231,  expansion = "mop"          },
    { key = "gate_of_the_setting_sun",     portalSpellID = 131225,  expansion = "mop"          },
    { key = "mogushan_palace",             portalSpellID = 131222,  expansion = "mop"          },
    { key = "shado_pan_monastery",         portalSpellID = 131206,  expansion = "mop"          },
    { key = "stormstout_brewery",          portalSpellID = 131205,  expansion = "mop"          },
    -- Warlords of Draenor
    { key = "shadowmoon_burial_grounds",   portalSpellID = 159899,  expansion = "wod"          },
    { key = "everbloom",                   portalSpellID = 159901,  expansion = "wod"          },
    { key = "bloodmaul_slag_mines",        portalSpellID = 159895,  expansion = "wod"          },
    { key = "auchindoun",                  portalSpellID = 159897,  expansion = "wod"          },
    { key = "upper_blackrock_spire",       portalSpellID = 159902,  expansion = "wod"          },
    { key = "grimrail_depot",              portalSpellID = 159900,  expansion = "wod"          },
    { key = "iron_docks",                  portalSpellID = 159896,  expansion = "wod"          },
    -- Legion
    { key = "darkheart_thicket",           portalSpellID = 424163,  expansion = "legion"       },
    { key = "black_rook_hold",             portalSpellID = 424153,  expansion = "legion"       },
    { key = "halls_of_valor",              portalSpellID = 393764,  expansion = "legion"       },
    { key = "neltharions_lair",            portalSpellID = 410078,  expansion = "legion"       },
    { key = "court_of_stars",              portalSpellID = 393766,  expansion = "legion"       },
    { key = "karazhan_lower",              portalSpellID = 373262,  expansion = "legion"       },
    -- Battle for Azeroth
    { key = "atal_dazar",                  portalSpellID = 424187,  expansion = "bfa"          },
    { key = "freehold",                    portalSpellID = 410071,  expansion = "bfa"          },
    { key = "waycrest_manor",              portalSpellID = 424167,  expansion = "bfa"          },
    { key = "underrot",                    portalSpellID = 410074,  expansion = "bfa"          },
    { key = "operation_mechagon",          portalSpellID = 373274,  expansion = "bfa"          },
    -- Shadowlands
    { key = "necrotic_wake",               portalSpellID = 354462,  expansion = "shadowlands"  },
    { key = "plaguefall",                  portalSpellID = 354463,  expansion = "shadowlands"  },
    { key = "mists_of_tirna_scithe",       portalSpellID = 354464,  expansion = "shadowlands"  },
    { key = "halls_of_atonement",          portalSpellID = 354465,  expansion = "shadowlands"  },
    { key = "spires_of_ascension",         portalSpellID = 354466,  expansion = "shadowlands"  },
    { key = "theatre_of_pain",             portalSpellID = 354467,  expansion = "shadowlands"  },
    { key = "de_other_side",               portalSpellID = 354468,  expansion = "shadowlands"  },
    { key = "sanguine_depths",             portalSpellID = 354469,  expansion = "shadowlands"  },
    { key = "tazavesh_veiled_market",      portalSpellID = 367416,  expansion = "shadowlands"  },
    -- Dragonflight
    { key = "nokhud_offensive",            portalSpellID = 393262,  expansion = "dragonflight" },
    { key = "azure_vault",                 portalSpellID = 393279,  expansion = "dragonflight" },
    { key = "uldaman",                     portalSpellID = 393222,  expansion = "dragonflight" },
    { key = "neltharus",                   portalSpellID = 393276,  expansion = "dragonflight" },
    { key = "brackenhide_hollow",          portalSpellID = 393267,  expansion = "dragonflight" },
    { key = "halls_of_infusion",           portalSpellID = 393283,  expansion = "dragonflight" },
    { key = "dawn_of_the_infinite",        portalSpellID = 424197,  expansion = "dragonflight" },
    -- The War Within
    { key = "city_of_threads",             portalSpellID = 445416,  expansion = "tww"          },
    { key = "ara_kara",                    portalSpellID = 445417,  expansion = "tww"          },
    { key = "stonevault",                  portalSpellID = 445269,  expansion = "tww"          },
    { key = "dawnbreaker",                 portalSpellID = 445414,  expansion = "tww"          },
    { key = "the_rookery",                 portalSpellID = 445443,  expansion = "tww"          },
    { key = "darkflame_cleft",             portalSpellID = 445441,  expansion = "tww"          },
    { key = "cinderbrew_brewery",          portalSpellID = 445440,  expansion = "tww"          },
    { key = "priory_of_the_sacred_flame",  portalSpellID = 445444,  expansion = "tww"          },
    { key = "operation_floodgate",         portalSpellID = 1216786, expansion = "tww"          },
    { key = "echo_dome_aldani",            portalSpellID = 1237215, expansion = "tww"          },
}

-- RollAway - Data/LegacyDungeonTeleports.lua
-- M+20 teleport spells of dungeons outside the season pools (RA.DUNGEONS), for the "all
-- learned teleports" overview; append entries when a dungeon rotates out. `expansion`
-- groups them in PortalOverview.lua. Siege of Boralus / The MOTHERLODE!! have separate
-- Horde/Alliance spells, resolved below via UnitFactionGroup(). `mapID` = instance map ID
-- (GetInstanceInfo), only used by /rawnames to check the locale names.

_G["RollAway"] = _G["RollAway"] or {}
local RA = _G["RollAway"]

local faction = UnitFactionGroup("player")
local SIEGE_OF_BORALUS_SPELL = (faction == "Horde") and 464256 or 445418
local THE_MOTHERLODE_SPELL   = (faction == "Horde") and 467555 or 467553

RA.LEGACY_DUNGEON_TELEPORTS = {
    -- Cataclysm
    { key = "vortex_pinnacle",             mapID = 657, portalSpellID = 410080,  expansion = "cataclysm"    },
    { key = "throne_of_the_tides",         mapID = 643, portalSpellID = 424142,  expansion = "cataclysm"    },
    { key = "grim_batol",                  mapID = 670, portalSpellID = 445424,  expansion = "cataclysm"    },
    -- Mists of Pandaria
    { key = "temple_of_the_jade_serpent",  mapID = 960, portalSpellID = 131204,  expansion = "mop"          },
    { key = "siege_of_niuzao",             mapID = 1011, portalSpellID = 131228,  expansion = "mop"          },
    { key = "scholomance",                 mapID = 1007, portalSpellID = 131232,  expansion = "mop"          },
    { key = "scarlet_monastery",           mapID = 1004, portalSpellID = 131229,  expansion = "mop"          },
    { key = "scarlet_halls",               mapID = 1001, portalSpellID = 131231,  expansion = "mop"          },
    { key = "gate_of_the_setting_sun",     mapID = 962, portalSpellID = 131225,  expansion = "mop"          },
    { key = "mogushan_palace",             mapID = 994, portalSpellID = 131222,  expansion = "mop"          },
    { key = "shado_pan_monastery",         mapID = 959, portalSpellID = 131206,  expansion = "mop"          },
    { key = "stormstout_brewery",          mapID = 961, portalSpellID = 131205,  expansion = "mop"          },
    -- Warlords of Draenor
    { key = "shadowmoon_burial_grounds",   mapID = 1176, portalSpellID = 159899,  expansion = "wod"          },
    { key = "everbloom",                   mapID = 1279, portalSpellID = 159901,  expansion = "wod"          },
    { key = "bloodmaul_slag_mines",        mapID = 1175, portalSpellID = 159895,  expansion = "wod"          },
    { key = "auchindoun",                  mapID = 1182, portalSpellID = 159897,  expansion = "wod"          },
    { key = "upper_blackrock_spire",       mapID = 1358, portalSpellID = 159902,  expansion = "wod"          },
    { key = "grimrail_depot",              mapID = 1208, portalSpellID = 159900,  expansion = "wod"          },
    { key = "iron_docks",                  mapID = 1195, portalSpellID = 159896,  expansion = "wod"          },
    -- Legion
    { key = "darkheart_thicket",           mapID = 1466, portalSpellID = 424163,  expansion = "legion"       },
    { key = "black_rook_hold",             mapID = 1501, portalSpellID = 424153,  expansion = "legion"       },
    { key = "halls_of_valor",              mapID = 1477, portalSpellID = 393764,  expansion = "legion"       },
    { key = "neltharions_lair",            mapID = 1458, portalSpellID = 410078,  expansion = "legion"       },
    { key = "court_of_stars",              mapID = 1571, portalSpellID = 393766,  expansion = "legion"       },
    { key = "karazhan_lower",              mapID = 1651, portalSpellID = 373262,  expansion = "legion"       },
    -- Battle for Azeroth
    { key = "atal_dazar",                  mapID = 1763, portalSpellID = 424187,  expansion = "bfa"          },
    { key = "freehold",                    mapID = 1754, portalSpellID = 410071,  expansion = "bfa"          },
    { key = "waycrest_manor",              mapID = 1862, portalSpellID = 424167,  expansion = "bfa"          },
    { key = "underrot",                    mapID = 1841, portalSpellID = 410074,  expansion = "bfa"          },
    { key = "operation_mechagon",          mapID = 2097, portalSpellID = 373274,  expansion = "bfa"          },
    { key = "siege_of_boralus",            mapID = 1822, portalSpellID = SIEGE_OF_BORALUS_SPELL, expansion = "bfa" },
    { key = "the_motherlode",              mapID = 1594, portalSpellID = THE_MOTHERLODE_SPELL,   expansion = "bfa" },
    -- Shadowlands
    { key = "necrotic_wake",               mapID = 2286, portalSpellID = 354462,  expansion = "shadowlands"  },
    { key = "plaguefall",                  mapID = 2289, portalSpellID = 354463,  expansion = "shadowlands"  },
    { key = "mists_of_tirna_scithe",       mapID = 2290, portalSpellID = 354464,  expansion = "shadowlands"  },
    { key = "halls_of_atonement",          mapID = 2287, portalSpellID = 354465,  expansion = "shadowlands"  },
    { key = "spires_of_ascension",         mapID = 2285, portalSpellID = 354466,  expansion = "shadowlands"  },
    { key = "theatre_of_pain",             mapID = 2293, portalSpellID = 354467,  expansion = "shadowlands"  },
    { key = "de_other_side",               mapID = 2291, portalSpellID = 354468,  expansion = "shadowlands"  },
    { key = "sanguine_depths",             mapID = 2284, portalSpellID = 354469,  expansion = "shadowlands"  },
    { key = "tazavesh_veiled_market",      mapID = 2441, portalSpellID = 367416,  expansion = "shadowlands"  },
    -- Dragonflight
    { key = "nokhud_offensive",            mapID = 2516, portalSpellID = 393262,  expansion = "dragonflight" },
    { key = "azure_vault",                 mapID = 2515, portalSpellID = 393279,  expansion = "dragonflight" },
    { key = "uldaman",                     mapID = 2451, portalSpellID = 393222,  expansion = "dragonflight" },
    { key = "neltharus",                   mapID = 2519, portalSpellID = 393276,  expansion = "dragonflight" },
    { key = "brackenhide_hollow",          mapID = 2520, portalSpellID = 393267,  expansion = "dragonflight" },
    { key = "halls_of_infusion",           mapID = 2527, portalSpellID = 393283,  expansion = "dragonflight" },
    { key = "dawn_of_the_infinite",        mapID = 2579, portalSpellID = 424197,  expansion = "dragonflight" },
    -- The War Within
    { key = "city_of_threads",             mapID = 2669, portalSpellID = 445416,  expansion = "tww"          },
    { key = "ara_kara",                    mapID = 2660, portalSpellID = 445417,  expansion = "tww"          },
    { key = "stonevault",                  mapID = 2652, portalSpellID = 445269,  expansion = "tww"          },
    { key = "dawnbreaker",                 mapID = 2662, portalSpellID = 445414,  expansion = "tww"          },
    { key = "the_rookery",                 mapID = 2648, portalSpellID = 445443,  expansion = "tww"          },
    { key = "darkflame_cleft",             mapID = 2651, portalSpellID = 445441,  expansion = "tww"          },
    { key = "cinderbrew_brewery",          mapID = 2661, portalSpellID = 445440,  expansion = "tww"          },
    { key = "priory_of_the_sacred_flame",  mapID = 2649, portalSpellID = 445444,  expansion = "tww"          },
    { key = "operation_floodgate",         mapID = 2773, portalSpellID = 1216786, expansion = "tww"          },
    { key = "echo_dome_aldani",            mapID = 2830, portalSpellID = 1237215, expansion = "tww"          },
}

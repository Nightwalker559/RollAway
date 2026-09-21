-- RollAway - Data/LegacyRaids.lua
-- Legacy raid boss definitions (Dragonflight + The War Within), used for
-- account-wide old-content farming. Not season-indexed - append new tiers
-- here once they become "legacy" (i.e. superseded by a new expansion/tier).

_G["RollAway"] = _G["RollAway"] or {}
local RA = _G["RollAway"]

RA.LEGACY_RAIDS = {
    -- Vault of the Incarnates (Dragonflight)
    { key = "eranog",               encounterID = 2587, raid = "vault_of_incarnates"    },
    { key = "terros",               encounterID = 2639, raid = "vault_of_incarnates"    },
    { key = "primal_council",       encounterID = 2590, raid = "vault_of_incarnates"    },
    { key = "sennarth",             encounterID = 2592, raid = "vault_of_incarnates"    },
    { key = "dathea",               encounterID = 2635, raid = "vault_of_incarnates"    },
    { key = "kurog_grimtotem",      encounterID = 2605, raid = "vault_of_incarnates"    },
    { key = "broodkeeper_diurna",   encounterID = 2614, raid = "vault_of_incarnates"    },
    { key = "raszageth",            encounterID = 2607, raid = "vault_of_incarnates"    },
    -- Aberrus, the Shadowed Crucible (Dragonflight)
    { key = "kazzara",              encounterID = 2688, raid = "aberrus"                },
    { key = "amalgamation_chamber", encounterID = 2687, raid = "aberrus"                },
    { key = "forgotten_experiments",encounterID = 2693, raid = "aberrus"                },
    { key = "zaqali_assault",       encounterID = 2682, raid = "aberrus"                },
    { key = "rashok",               encounterID = 2680, raid = "aberrus"                },
    { key = "zskarn",               encounterID = 2689, raid = "aberrus"                },
    { key = "magmorax",             encounterID = 2683, raid = "aberrus"                },
    { key = "echo_of_neltharion",   encounterID = 2684, raid = "aberrus"                },
    { key = "sarkareth",            encounterID = 2685, raid = "aberrus"                },
    -- Amirdrassil, the Dream's Hope (Dragonflight)
    { key = "gnarlroot",            encounterID = 2820, raid = "amirdrassil"            },
    { key = "igira",                encounterID = 2709, raid = "amirdrassil"            },
    { key = "volcoross",            encounterID = 2737, raid = "amirdrassil"            },
    { key = "council_of_dreams",    encounterID = 2728, raid = "amirdrassil"            },
    { key = "larodar",              encounterID = 2731, raid = "amirdrassil"            },
    { key = "nymue",                encounterID = 2708, raid = "amirdrassil"            },
    { key = "smolderon",            encounterID = 2824, raid = "amirdrassil"            },
    { key = "tindral",              encounterID = 2786, raid = "amirdrassil"            },
    { key = "fyrakk",               encounterID = 2677, raid = "amirdrassil"            },
    -- Nerub-ar Palace (The War Within)
    { key = "ulgrax",               encounterID = 2898, raid = "nerubar_palace"         },
    { key = "bloodbound_horror",    encounterID = 2917, raid = "nerubar_palace"         },
    { key = "sikran",               encounterID = 2899, raid = "nerubar_palace"         },
    { key = "rashanan",             encounterID = 2918, raid = "nerubar_palace"         },
    { key = "ovinax",               encounterID = 2919, raid = "nerubar_palace"         },
    { key = "kyveza",               encounterID = 2920, raid = "nerubar_palace"         },
    { key = "silken_court",         encounterID = 2921, raid = "nerubar_palace"         },
    { key = "queen_ansurek",        encounterID = 2922, raid = "nerubar_palace"         },
    -- Liberation of Undermine (The War Within)
    { key = "vexie",                encounterID = 3009, raid = "liberation_undermine"   },
    { key = "cauldron_carnage",     encounterID = 3010, raid = "liberation_undermine"   },
    { key = "rik_reverb",           encounterID = 3011, raid = "liberation_undermine"   },
    { key = "stix",                 encounterID = 3012, raid = "liberation_undermine"   },
    { key = "sprocketmonger",       encounterID = 3013, raid = "liberation_undermine"   },
    { key = "one_armed_bandit",     encounterID = 3014, raid = "liberation_undermine"   },
    { key = "mugzee",               encounterID = 3015, raid = "liberation_undermine"   },
    { key = "gallywix",             encounterID = 3016, raid = "liberation_undermine"   },
    -- Manaforge Omega (The War Within)
    { key = "plexus_sentinel",      encounterID = 3129, raid = "manaforge_omega"        },
    { key = "loomi_thar",           encounterID = 3131, raid = "manaforge_omega"        },
    { key = "naazindhri",           encounterID = 3130, raid = "manaforge_omega"        },
    { key = "forgeweaver_araz",     encounterID = 3132, raid = "manaforge_omega"        },
    { key = "soul_hunters",         encounterID = 3122, raid = "manaforge_omega"        },
    { key = "fractillus",           encounterID = 3133, raid = "manaforge_omega"        },
    { key = "nexus_king_salhadaar", encounterID = 3134, raid = "manaforge_omega"        },
    { key = "dimensius",            encounterID = 3135, raid = "manaforge_omega"        },
}

------------------------------------------------------------------------
-- Raid teleport ("Return to <raid>") achievement spells, keyed by the
-- same `raid` identifier used above. Only raids with a confirmed spell
-- are listed - Nerub-ar Palace and all Midnight-era raids (Voidspire,
-- Dreamrift, March on Quel'Danas, Sporefall, Venomous Abyss, Tidebound
-- Grotto, Unbinding of Kith'ix) are unconfirmed for now.
------------------------------------------------------------------------
RA.LEGACY_RAID_TELEPORTS = {
    vault_of_incarnates  = 432254,
    aberrus              = 432257,
    amirdrassil          = 432258,
    liberation_undermine = 1226482,
    manaforge_omega      = 1239155,
}

-- RollAway - Data/Raids.lua
-- Current-tier raid boss definitions, indexed by season number: RA.RAIDS[seasonNumber].
-- Add a new season by appending RA.RAIDS[n] = { ... } below.
-- For old/legacy raid tiers (account-wide farming), see Data/LegacyRaids.lua.

_G["RollAway"] = _G["RollAway"] or {}
local RA = _G["RollAway"]

RA.RAIDS = RA.RAIDS or {}

-- Season 1 raid bosses
RA.RAIDS[1] = {
    { key = "imperator_averzian",    encounterID = 3176, raid = "voidspire"       },
    { key = "vorasius",              encounterID = 3177, raid = "voidspire"       },
    { key = "vaelgor_ezzorak",       encounterID = 3178, raid = "voidspire"       },
    { key = "fallen_king_salhadaar", encounterID = 3179, raid = "voidspire"       },
    { key = "lightblinded_vanguard", encounterID = 3180, raid = "voidspire"       },
    { key = "crown_of_the_cosmos",   encounterID = 3181, raid = "voidspire"       },
    { key = "chimaerus",             encounterID = 3306, raid = "dreamrift"       },
    { key = "beloren",               encounterID = 3182, raid = "march_queldanas" },
    { key = "midnight_falls",        encounterID = 3183, raid = "march_queldanas" },
    { key = "rotmire",               encounterID = 3159, raid = "sporefall"       }, -- Sporefall (12.0.7)
}

-- Season 2 raid bosses (The Venomous Abyss, mapID 3004)
RA.RAIDS[2] = {
    { key = "nekzali_the_soulcoiler", encounterID = 3470, raid = "venomous_abyss" },
    { key = "entombed_sentinels",     encounterID = 3445, raid = "venomous_abyss" },
    { key = "vashnik_the_malignant",  encounterID = 3455, raid = "venomous_abyss" },
    { key = "the_lost_explorers",     encounterID = 3497, raid = "venomous_abyss" },
    { key = "sszorak",                encounterID = 3420, raid = "venomous_abyss" },
    { key = "the_twin_fangs",         encounterID = 3421, raid = "venomous_abyss" },
    { key = "the_coiled_altar",       encounterID = 3429, raid = "venomous_abyss" },
    { key = "ulatek",                 encounterID = 3492, raid = "venomous_abyss" },
}

-- Season 2 lair (Tidebound Grotto, mapID 2987, one boss), matched like a regular raid boss.
RA.RAIDS[2][#RA.RAIDS[2] + 1] =
    { key = "nymrissa_wavecaller", encounterID = 3379, raid = "tidebound_grotto" }

-- The Unbinding of Kith'ix (12.1.5, mapID 3095): single-boss mid-season raid;
-- encounterID 3513 confirmed on the PTR (Developer > raid dump).
RA.RAIDS[2][#RA.RAIDS[2] + 1] =
    { key = "kithix", encounterID = 3513, raid = "unbinding_of_kithix" }

-- Raid map IDs (instanceID of GetInstanceInfo) that get the reminder -> raid key above.
-- Read by Reminder.lua, PetReminder.lua and /rawnames; one entry per raid of a season.
RA.REMINDER_RAID_MAP_IDS = {
    [2912] = "voidspire",        -- The Voidspire (S1)
    [2939] = "dreamrift",        -- The Dreamrift (S1)
    [2913] = "march_queldanas",  -- March on Quel'Danas (S1)
    [1592] = "sporefall",        -- Sporefall (12.0.7, S1)
    [3004] = "venomous_abyss",   -- The Venomous Abyss (S2)
    [2987] = "tidebound_grotto", -- Tidebound Grotto (S2, one boss)
    [3095] = "unbinding_of_kithix", -- The Unbinding of Kith'ix (12.1.5, one boss)
}

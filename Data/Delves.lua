-- RollAway - Data/Delves.lua
-- Delve definitions, indexed by season number: RA.DELVES[seasonNumber].
-- Add a new season by appending RA.DELVES[n] = { ... } below.

_G["RollAway"] = _G["RollAway"] or {}
local RA = _G["RollAway"]

RA.DELVES = RA.DELVES or {}

------------------------------------------------------------------------
-- Season 1 delve definitions
------------------------------------------------------------------------
RA.DELVES[1] = {
    { key = "academic_unrest",       mapID = 2933 },
    { key = "shadow_enclave",        mapID = 2952 },
    { key = "parhelion_plaza",       mapID = 2953 },
    { key = "grufts_twilight_blade", mapID = 2961 },
    { key = "atal_aman",             mapID = 2962 },
    { key = "the_grudge_pit",        mapID = 2963 },
    { key = "gulf_of_memory",        mapID = 2964 },
    { key = "sunkiller_sanctum",     mapID = 2965 },
    { key = "torments_rise",         mapID = 2966, removedAfterS1 = true }, -- Nemesis Delve; removed from the game pool as of Season 2 (12.1)
    { key = "shadowguard_point",     mapID = 2979 },
    { key = "the_darkway",           mapID = 3003 },
}

------------------------------------------------------------------------
-- Season 2 delve definitions (12.1)
------------------------------------------------------------------------
RA.DELVES[2] = {
    { key = "ring_of_glory",    mapID = 3077 },
    { key = "gnarldor_isle",    mapID = 3038 },
    -- Venomfall Deeps (Nemesis Delve) – mapID not yet known
    { key = "venomfall_deeps" },
    -- Labyrinth of Kindo'jan (12.1.5) – mega-delve, own tiered floors ("Tiefen"/Depths)
    { key = "labyrinth_of_kindojan", mapID = 3043, pendingTest = true },
}

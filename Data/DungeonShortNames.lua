-- RollAway - Data/DungeonShortNames.lua
-- Short names of the dungeons (the usual M+ abbreviations), shown on the portal buttons.
-- Keyed by dungeon key (Data/Dungeons.lua, Data/LegacyDungeonTeleports.lua); a dungeon
-- without an entry gets no label. Same in every client language.

_G["RollAway"] = _G["RollAway"] or {}
local RA = _G["RollAway"]

RA.DUNGEON_SHORT_NAMES = {
    -- Midnight
    windrunner_spire = "WS",   maisara_caverns = "MC",    magisters_terrace = "MT",
    nexus_point_xenas = "NPX", altar_of_fangs = "AOF",    murder_row = "MR",
    den_of_nalorakk = "DON",   blinding_vale = "BV",      voidscar_arena = "VSA",
    -- revived old dungeons (Season 1 / 2)
    algeth_ar_academy = "AA",  seat_of_triumvirate = "SEAT", skyreach = "SR",
    pit_of_saron = "POS",      kings_rest = "KR",         ruby_life_pools = "RLP",
    temple_of_sethraliss = "TOS",
    -- Cataclysm
    vortex_pinnacle = "VP",    throne_of_the_tides = "TOTT", grim_batol = "GB",
    -- Mists of Pandaria
    temple_of_the_jade_serpent = "TJS", siege_of_niuzao = "SNT", scholomance = "SCHOLO",
    scarlet_monastery = "SM",  scarlet_halls = "SH",      gate_of_the_setting_sun = "GSS",
    mogushan_palace = "MSP",   shado_pan_monastery = "SPM", stormstout_brewery = "SSB",
    -- Warlords of Draenor
    shadowmoon_burial_grounds = "SBG", everbloom = "EB",  bloodmaul_slag_mines = "BSM",
    auchindoun = "AUCH",       upper_blackrock_spire = "UBRS", grimrail_depot = "GD",
    iron_docks = "ID",
    -- Legion
    darkheart_thicket = "DHT", black_rook_hold = "BRH",   halls_of_valor = "HOV",
    neltharions_lair = "NL",   court_of_stars = "COS",    karazhan_lower = "LOWR",
    -- Battle for Azeroth
    atal_dazar = "AD",         freehold = "FH",           waycrest_manor = "WM",
    underrot = "UNDR",         operation_mechagon = "MECH", siege_of_boralus = "SIEGE",
    the_motherlode = "ML",
    -- Shadowlands
    necrotic_wake = "NW",      plaguefall = "PF",         mists_of_tirna_scithe = "MISTS",
    halls_of_atonement = "HOA", spires_of_ascension = "SOA", theatre_of_pain = "TOP",
    de_other_side = "DOS",     sanguine_depths = "SD",    tazavesh_veiled_market = "TAZ",
    -- Dragonflight
    nokhud_offensive = "NO",   azure_vault = "AV",        uldaman = "ULD",
    neltharus = "NELT",        brackenhide_hollow = "BH", halls_of_infusion = "HOI",
    dawn_of_the_infinite = "DOTI",
    -- The War Within
    city_of_threads = "COT",   ara_kara = "ARAK",         stonevault = "SV",
    dawnbreaker = "DAWN",      the_rookery = "ROOK",      darkflame_cleft = "DFC",
    cinderbrew_brewery = "BREW", priory_of_the_sacred_flame = "PSF",
    operation_floodgate = "FLOOD", echo_dome_aldani = "EDA",
}

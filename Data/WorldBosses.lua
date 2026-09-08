-- RollAway - Data/WorldBosses.lua
-- Reserved for future genuine open-world bosses (not fought as a raid
-- instance). As of 2.9.0, Tidebound Grotto's Nymrissa Wavecaller moved to
-- Data/Raids.lua and the raid-difficulty-bucket system, since it's fought
-- as a raid instance (GetInstanceInfo reports instanceType "raid").

_G["RollAway"] = _G["RollAway"] or {}
local RA = _G["RollAway"]

RA.WORLD_BOSSES = {}

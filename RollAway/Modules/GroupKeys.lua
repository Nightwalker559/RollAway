-- RollAway - Modules/GroupKeys.lua
-- The party's keystones, kept per player. Used by the teleport reminder (key level of a
-- joined group) and the portal overview (key list under the season portals).
-- Transport: LibKeystone (embedded in Libs\, shared with BigWigs and other keystone addons,
-- so everyone with one of them sees everyone else).

local RA = _G["RollAway"]

local keys      = {}   -- short name -> { level, mapID } (mapID = challenge mode ID = a dungeon's cmID)
local owner     = {}   -- the table LibKeystone wants as "addon" for Register
local listeners = {}   -- fn() called whenever a key arrives
local registered = false

-- fn() runs whenever a member's key arrives (also our own, on every request).
function RA.OnGroupKeys(fn)
    listeners[#listeners + 1] = fn
end

-- Asks the party for their keys; the answers come in over the next moments. Our own key is
-- delivered right away, also when ungrouped.
function RA.RequestGroupKeys()
    local LKS = LibStub("LibKeystone", true)
    if not LKS then return end
    if not registered then
        registered = true
        LKS.Register(owner, function(level, mapID, _, name, channel)
            if channel ~= "PARTY" then return end
            keys[name] = { level = level, mapID = mapID }
            for i = 1, #listeners do listeners[i]() end
        end)
    end
    LKS.Request("PARTY")
end

-- The shared key of a group unit ("player", "party1" ...): { level, mapID }, nil when none
-- arrived. level 0 = the member has no keystone.
function RA.GetGroupKey(unit)
    local name
    if unit == "player" then
        name = UnitName("player")
    else
        local full = UnitExists(unit) and GetUnitName(unit, true)
        name = full and Ambiguate(full, "none")
    end
    return name and keys[name] or nil
end

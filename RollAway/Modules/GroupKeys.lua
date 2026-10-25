-- RollAway - Modules/GroupKeys.lua
-- The party's keystones. Members who run BigWigs (or any addon with LibKeystone) share
-- theirs in the party; this keeps the latest per player. Optional: without LibKeystone
-- nothing arrives. Used by the teleport reminder (key level of a joined group) and the
-- portal overview (key list under the season portals).

local RA = _G["RollAway"]

local keys      = {}   -- short name -> { level, mapID } (mapID = challenge mode ID = a dungeon's cmID)
local owner     = {}   -- the table LibKeystone wants as "addon" for Register
local listeners = {}   -- fn() called whenever a key arrives
local registered = false

-- Looked up late: BigWigs may load after us.
local function GetLib()
    return LibStub and LibStub("LibKeystone", true)
end

function RA.GroupKeysAvailable()
    return GetLib() ~= nil
end

-- fn() runs whenever a member's key arrives (also our own, on every request).
function RA.OnGroupKeys(fn)
    listeners[#listeners + 1] = fn
end

-- Asks the party for their keys; the answers come in over the next moments. No-op without
-- LibKeystone. Our own key is delivered right away, also when ungrouped.
function RA.RequestGroupKeys()
    local LKS = GetLib()
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

-- RollAway - Core/Season.lua
-- Questions about the running season: the addon's own season data (RA.DUNGEONS, Data/) and
-- the game's current season, read from the Encounter Journal. Loads after Core/Helpers.lua.

local RA = _G["RollAway"]

-- The dungeons of RA.ACTIVE_SEASON (Data/Dungeons.lua); never nil.
function RA.GetActiveSeasonDungeons()
    return RA.DUNGEONS[RA.ACTIVE_SEASON] or {}
end

-- The active season's dungeon whose `field` (cmID, lfgID, mapID, portalSpellID) equals
-- `value`, or nil.
function RA.FindSeasonDungeon(field, value)
    for _, d in ipairs(RA.GetActiveSeasonDungeons()) do
        if d[field] == value then return d end
    end
end

-- Current season from the game: the Encounter Journal's last tier ("Current Season")
-- lists the running season's raids and dungeons by map ID (= instanceID of
-- GetInstanceInfo). Nothing to maintain; the legacy list (Data/LegacyRaids.lua) is the
-- fallback.
local seasonInstances = {}  -- [isRaid] = { [mapID] = true }, filled once the journal answers

-- Map IDs of the current season's raids (isRaid) or dungeons; nil while the journal has no
-- data. The journal's selected tier is put back.
function RA.GetCurrentSeasonInstances(isRaid)
    isRaid = isRaid and true or false
    if seasonInstances[isRaid] then return seasonInstances[isRaid] end
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return nil end

    local lastTier = EJ_GetNumTiers()
    if not lastTier or lastTier < 1 then return nil end
    local previous = EJ_GetCurrentTier()
    EJ_SelectTier(lastTier)

    local set, index = {}, 1
    while true do
        local journalID, _, _, _, _, _, _, _, _, _, mapID = EJ_GetInstanceByIndex(index, isRaid)
        if not journalID then break end
        if mapID then set[mapID] = true end
        index = index + 1
    end
    if previous then EJ_SelectTier(previous) end

    if next(set) then
        seasonInstances[isRaid] = set
        return set
    end
    return nil
end

-- Is this raid in the current season? Without journal data: not on the legacy list.
function RA.IsCurrentSeasonRaid(instanceID)
    local set = RA.GetCurrentSeasonInstances(true)
    if set then return set[instanceID] == true end
    return RA.LEGACY_RAID_INSTANCES[instanceID] == nil
end

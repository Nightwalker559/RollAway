-- RollAway - Modules/GroupKeys.lua
-- The party's keystones, kept per player, for the portal overview (key list under the season
-- portals).
-- Our own implementation, no library. Only the wire format matches the one BigWigs and
-- other keystone addons use (addon prefix "LibKS"), so they and we see each other:
--   "<level>,<challengeMapID>,<rating>"  a member's key        "R"  please send yours

local RA = _G["RollAway"]

local PREFIX = "LibKS"
local MIN_GAP = 3        -- seconds between two messages of the same kind

local keys      = {}     -- short name -> { level, mapID } (mapID = challenge mode ID = a dungeon's cmID)
local listeners = {}     -- fn() called whenever a key arrives
local lastSent  = { key = 0, ask = 0 }
local eventFrame

-- fn() runs whenever a member's key arrives (also our own, on every request).
function RA.OnGroupKeys(fn)
    listeners[#listeners + 1] = fn
end

local function Store(name, level, mapID)
    keys[name] = { level = level, mapID = mapID }
    for i = 1, #listeners do listeners[i]() end
end

-- True when a message of this kind may go out now (and remembers the time).
local function MaySend(kind)
    local now = GetTime()
    if now - lastSent[kind] < MIN_GAP then return false end
    lastSent[kind] = now
    return true
end

-- Our own keystone: level, challenge map ID, season rating (0 where there is none).
local function OwnKey()
    local level  = C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID  = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local rating = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    rating = rating and rating.currentSeasonScore
    return tonumber(level) or 0, tonumber(mapID) or 0, tonumber(rating) or 0
end

local function OnAddonMessage(_, _, prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "PARTY" then return end
    if text == "R" then
        -- Others only get ours while the feature is on.
        if RollAwayDB and RollAwayDB.portalGroupKeys and IsInGroup() and MaySend("key") then
            C_ChatInfo.SendAddonMessage(PREFIX, string.format("%d,%d,%d", OwnKey()), "PARTY")
        end
        return
    end
    local level, mapID = text:match("^(%d+),(%d+),%d+$")
    if level then Store(Ambiguate(sender, "none"), tonumber(level), tonumber(mapID)) end
end

-- Asks the party for their keys; the answers come in over the next moments. Our own key
-- counts as received right away, also when ungrouped.
function RA.RequestGroupKeys()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", OnAddonMessage)
        eventFrame:RegisterEvent("CHAT_MSG_ADDON")
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    local level, mapID = OwnKey()
    Store(UnitName("player"), level, mapID)
    if IsInGroup() and MaySend("ask") then
        C_ChatInfo.SendAddonMessage(PREFIX, "R", "PARTY")
    end
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

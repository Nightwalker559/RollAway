-- RollAway - Modules/GroupKeys.lua
-- The party's keystones, kept per player. Used by the teleport reminder (key level of a
-- joined group) and the portal overview (key list under the season portals).
-- Transport: the LibKeystone protocol (addon prefix "LibKS"), which BigWigs, Details!
-- Keystones and others speak. With LibKeystone loaded we use it; without it we speak the
-- protocol ourselves (below), so it works without BigWigs.

local RA = _G["RollAway"]

local PREFIX   = "LibKS"
local THROTTLE = 3   -- seconds between our sends (same as the library)

local keys      = {}   -- short name -> { level, mapID } (mapID = challenge mode ID = a dungeon's cmID)
local owner     = {}   -- the table LibKeystone wants as "addon" for Register
local listeners = {}   -- fn() called whenever a key arrives
local libRegistered = false

-- fn() runs whenever a member's key arrives (also our own, on every request).
function RA.OnGroupKeys(fn)
    listeners[#listeners + 1] = fn
end

local function Deliver(name, level, mapID)
    keys[name] = { level = level, mapID = mapID }
    for i = 1, #listeners do listeners[i]() end
end

-- Own protocol (no LibKeystone): "level,mapID,rating" to PARTY, "R" asks everyone to send theirs.

local ownFrame
local lastSend, lastRequest = 0, 0

-- Our own keystone: level, challenge map ID, season rating (0 = none).
local function GetOwnKey()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    local rating = summary and summary.currentSeasonScore
    return type(level) == "number" and level or 0,
           type(mapID) == "number" and mapID or 0,
           type(rating) == "number" and rating or 0
end

local function SendOwnKey()
    if not IsInGroup() or GetTime() - lastSend < THROTTLE then return end
    lastSend = GetTime()
    C_ChatInfo.SendAddonMessage(PREFIX, string.format("%d,%d,%d", GetOwnKey()), "PARTY")
end

local function OnAddonMessage(_, _, prefix, msg, channel, sender)
    if prefix ~= PREFIX or channel ~= "PARTY" then return end
    if msg == "R" then
        -- Only share ours while the feature is on (BigWigs users get it unasked).
        if RollAwayDB and RollAwayDB.portalGroupKeys then SendOwnKey() end
        return
    end
    local level, mapID = msg:match("^(%d+),(%d+),%d+$")
    if level then Deliver(Ambiguate(sender, "none"), tonumber(level), tonumber(mapID)) end
end

local function RequestOwnProtocol()
    if not ownFrame then
        ownFrame = CreateFrame("Frame")
        ownFrame:RegisterEvent("CHAT_MSG_ADDON")
        ownFrame:SetScript("OnEvent", OnAddonMessage)
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    -- Our own key counts as received, also when ungrouped.
    local level, mapID = GetOwnKey()
    Deliver(UnitName("player"), level, mapID)
    if IsInGroup() and GetTime() - lastRequest >= THROTTLE then
        lastRequest = GetTime()
        C_ChatInfo.SendAddonMessage(PREFIX, "R", "PARTY")
    end
end

-- Asks the party for their keys; the answers come in over the next moments. Our own key is
-- delivered right away, also when ungrouped.
function RA.RequestGroupKeys()
    -- Looked up late: BigWigs may load after us.
    local LKS = LibStub and LibStub("LibKeystone", true)
    if not LKS then
        RequestOwnProtocol()
        return
    end
    if not libRegistered then
        libRegistered = true
        LKS.Register(owner, function(level, mapID, _, name, channel)
            if channel == "PARTY" then Deliver(name, level, mapID) end
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

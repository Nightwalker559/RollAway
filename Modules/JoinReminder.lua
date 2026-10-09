-- RollAway - JoinReminder.lua
-- Group Finder join detection: shows the instance name when you join an M+/raid
-- group and either hands off to the Teleport Reminder (TeleportReminder.lua) or
-- opens a keystone companion addon (BigWigs or Details! Keystones, one of them,
-- RollAwayDB.joinReminderKeyAddon).

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

------------------------------------------------------------------------
-- Keystone companion addon (BigWigs / Details!). Calls SlashCmdList directly, not typed text.
------------------------------------------------------------------------

-- Availability, exposed so Options can grey out the checkbox.
local function IsBigWigsKeyAvailable()
    return _G["BigWigsLoader"] ~= nil and SlashCmdList["key"] ~= nil
end
RA.IsBigWigsKeyAvailable = IsBigWigsKeyAvailable

local function IsDetailsKeyAvailable()
    return _G["Details"] ~= nil and SlashCmdList["KEYSTONE"] ~= nil
end
RA.IsDetailsKeyAvailable = IsDetailsKeyAvailable

-- "bigwigs" / "details" if the selected companion addon is available, else nil.
local function GetActiveKeyAddon()
    local choice = RollAwayDB and RollAwayDB.joinReminderKeyAddon
    if choice == "bigwigs" and IsBigWigsKeyAvailable() then return "bigwigs" end
    if choice == "details" and IsDetailsKeyAvailable() then return "details" end
    return nil
end

-- Opens the companion addon's keystone frame. No-op if already open for Details!;
-- BigWigs only has a toggle command (state unknown), so it is called unconditionally.
local function OpenKeyAddon()
    local which = GetActiveKeyAddon()
    if which == "bigwigs" then
        DBG("[QoL] Opening BigWigs Keystones via SlashCmdList[key]")
        SlashCmdList["key"]("")
        return true
    elseif which == "details" then
        local f = _G["DetailsKeystoneSmallFrame"]
        if not (f and f:IsShown()) then
            DBG("[QoL] Opening Details! Keystones via SlashCmdList[KEYSTONE]")
            SlashCmdList["KEYSTONE"]("")
        end
        return true
    end
    return false
end

-- Counterpart to OpenKeyAddon (same BigWigs caveat).
local function CloseKeyAddon()
    local which = GetActiveKeyAddon()
    if which == "bigwigs" then
        DBG("[QoL] Closing BigWigs Keystones via SlashCmdList[key]")
        SlashCmdList["key"]("")
        return true
    elseif which == "details" then
        local f = _G["DetailsKeystoneSmallFrame"]
        if f and f:IsShown() then
            DBG("[QoL] Closing Details! Keystones (direct Hide)")
            f:Hide()
        end
        return true
    end
    return false
end

------------------------------------------------------------------------
-- Companion addon safety-close: an addon we opened stays open until a known M+
-- portal is cast (closes at once) or a 20s timer runs out.
------------------------------------------------------------------------

local portalWatcher = CreateFrame("Frame")  -- listens for portal casts only while the addon is held open
local keyAddonReminderOpen = false           -- true while we hold it open

local function SetKeyAddonHeld(held)
    keyAddonReminderOpen = held
    if held then
        portalWatcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    else
        portalWatcher:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end
end

local keyAddonSafetyTimer = RA.CreateOneShotTimer(20, function()
    if keyAddonReminderOpen then
        DBG("[QoL] Safety timer expired – closing keystone companion addon")
        SetKeyAddonHeld(false)
        CloseKeyAddon()
    end
end)

-- Closes the companion addon if we hold it open and stops the timer (timeout, portal cast).
local function CloseKeyAddonReminder()
    keyAddonSafetyTimer.Stop()
    if keyAddonReminderOpen then
        SetKeyAddonHeld(false)
        DBG("[QoL] Closing keystone companion addon")
        CloseKeyAddon()
    end
end

-- Starts (or restarts) the 20s timer.
local function StartKeyAddonSafetyTimer()
    SetKeyAddonHeld(true)
    keyAddonSafetyTimer.Start()
end

-- Is spellID one of the current season's M+ portal spells?
local function IsKnownPortalSpell(spellID)
    if not RA.IsAccessible(spellID) then return false end
    for _, d in ipairs(RA.DUNGEONS[RA.ACTIVE_SEASON] or {}) do
        if d.portalSpellID == spellID then return true end
    end
    return false
end

-- Closes early when the player casts a portal, however it was started.
portalWatcher:SetScript("OnEvent", function(_, _, _, _, spellID)
    if keyAddonReminderOpen and IsKnownPortalSpell(spellID) then
        DBG("[QoL] Portal cast detected – closing keystone companion addon early")
        CloseKeyAddonReminder()
    end
end)

------------------------------------------------------------------------
-- Instance Join reminder – shows instance name when joining a group
------------------------------------------------------------------------

local joinFrame, joinHideTimer   -- QoL toast, created on first show
local keyAddonOpenedByCreation      = false -- own listing active (M+ or raid)
local keyAddonOpenedByCreationMplus = false -- own M+ listing opened the companion addon

-- Party groups: the hide timer starts once the group is full (5), or after 30s.
-- One wait at a time; a newer reminder replaces an older one.
local pendingHideStart              -- fn to run when the wait is over
local FinishGroupWait
local groupWaitFallback = RA.CreateOneShotTimer(30, function()
    DBG("[QoL] Fallback – starting hide timer after 30s")
    FinishGroupWait()
end)
local groupWaitFrame = CreateFrame("Frame")
groupWaitFrame:SetScript("OnEvent", function()
    -- Let the roster count update first
    C_Timer.After(0.3, function()
        if pendingHideStart and GetNumGroupMembers() >= 5 then FinishGroupWait() end
    end)
end)

local function CancelGroupWait()
    pendingHideStart = nil
    groupWaitFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
    groupWaitFallback.Stop()
end

FinishGroupWait = function()
    local start = pendingHideStart
    CancelGroupWait()
    if start then start() end
end

local function ShowJoinReminder(instanceName, forceTimer, keyLevel)
    if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
    if not instanceName or instanceName == "" then return end
    -- Not for the leader's own listing
    if keyAddonOpenedByCreation then
        DBG("[QoL] Join reminder skipped – own listing active")
        return
    end

    DBG("[QoL] Join reminder:", instanceName)
    if not joinFrame then
        joinFrame, joinHideTimer = RA.CreateToastFrame("RollAwayJoinFrame", 400, 36, 220)
    end
    joinHideTimer.Stop()
    CancelGroupWait()

    local fontPath, fontSize = RA.GetQoLFont()
    joinFrame.text:SetFont(fontPath, fontSize, "OUTLINE")
    joinFrame.text:SetText("|cffFFFFFF" .. RA.FormatInstanceWithKey(instanceName, keyLevel) .. "|r")
    joinFrame:Show()

    -- Companion addon: party only (no keystone teleports in raids), not if the listing opened it.
    local keyAddonOpened = false
    if not IsInRaid() and not keyAddonOpenedByCreation and GetActiveKeyAddon() then
        keyAddonOpened = true
        C_Timer.After(0.3, OpenKeyAddon)
    end

    -- Hides the banner after 6s; the companion addon (if opened) goes to the 20s timer.
    local function StartHideTimer()
        joinHideTimer.Start()
        if keyAddonOpened then
            StartKeyAddonSafetyTimer()
            keyAddonOpened = false -- ownership passed to the safety timer
        end
    end

    -- Raids: at once. Party: wait for a full group. forceTimer (test) skips the check.
    if forceTimer or IsInRaid() or GetNumGroupMembers() >= 5 then
        DBG("[QoL] Timer starting immediately (force: "..tostring(forceTimer)..
            " / raid: "..tostring(IsInRaid()).." / full: "..tostring(GetNumGroupMembers() >= 5)..")")
        StartHideTimer()
    else
        DBG("[QoL] Waiting for full group before starting hide timer")
        pendingHideStart = StartHideTimer
        groupWaitFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        groupWaitFallback.Start()
    end
end
RA.ShowJoinReminder = ShowJoinReminder

-- Current-season dungeon entry for an LFG activity ID (activityID == dungeon.lfgID).
local function GetDungeonEntryByLfgID(activityID)
    for _, d in ipairs(RA.DUNGEONS[RA.ACTIVE_SEASON] or {}) do
        if d.lfgID == activityID then return d end
    end
    return nil
end

-- name, isMythicPlus, dungeon for an LFG activity ID; nil if it is neither an M+
-- dungeon nor a current raid. M+ names come from RA_L (the addon's language).
local function GetNameFromActivityID(activityID)
    local act = activityID and C_LFGList.GetActivityInfoTable(activityID)
    if not act then return nil end
    if not (act.isMythicPlusActivity or act.isCurrentRaidActivity) then
        DBG("[QoL] Join reminder filtered out – not M+ or current raid (activityID: "..tostring(activityID)..")")
        return nil
    end

    local blizzardName = act.fullName ~= "" and act.fullName or nil
    if act.isMythicPlusActivity then
        local dungeon = GetDungeonEntryByLfgID(activityID)
        if dungeon then
            return RA_L["dungeon_"..dungeon.key], true, dungeon
        end
        -- M+ activity outside the season pool: Blizzard's name.
        return blizzardName, true, nil
    end
    return blizzardName, false, nil
end

-- The API has no keystone level for a listing: read it from the title or comment
-- ("+14", "M+14"). nil if not written or not readable (secret strings).
local function ParseKeyLevel(info)
    if not info then return nil end
    for _, field in ipairs({ "name", "comment" }) do
        local text = info[field]
        if type(text) == "string" and text ~= "" and RA.IsAccessible(text) then
            local level = tonumber(text:match("%+%s*(%d+)"))
            if level and level >= 2 and level <= 40 then return level end
        end
    end
    return nil
end

-- Teleport reminder for M+ when selected, else the instance-name reminder (raids
-- always that one). keyLevel is for M+ only.
local function DispatchJoinReminder(name, isMythicPlus, dungeon, keyLevel)
    if not isMythicPlus then keyLevel = nil end
    if isMythicPlus and RollAwayDB and RollAwayDB.joinReminderKeyAddon == "teleport" then
        RA.ShowTeleportReminder(name, dungeon, keyLevel)
    else
        ShowJoinReminder(name, nil, keyLevel)
    end
end

------------------------------------------------------------------------
-- Group Finder join detection. Two ways into an LFG group:
--  1. You post your own listing (LFG_LIST_ACTIVE_ENTRY_UPDATE).
--  2. You apply to a listing, or you are in the party of whoever applied
--     (LFG_LIST_APPLICATION_STATUS_UPDATED and LFG_LIST_JOINED_GROUP reach every member).
-- In the group, C_LFGList.GetActiveEntryInfo() also shows the group's listing for
-- every member; GROUP_ROSTER_UPDATE can come before it is readable, so a poll
-- (3s) runs while a group is unresolved.
------------------------------------------------------------------------

local POLL_INTERVAL = 3

function RA.InitJoinReminder()
    local f = CreateFrame("Frame")
    f:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    f:RegisterEvent("LFG_LIST_JOINED_GROUP")

    -- Per-group state, reset together on ungroup (ResetGroupState).
    local resolvedEntryID   = nil   -- activityID already shown/dispatched
    -- searchResultID -> { name, isMythicPlus, dungeon } (false = not M+/raid), filled
    -- as early as the application is readable: the browse cache can be purged by
    -- "inviteaccepted".
    local applicationDungeons = {}
    -- A join through an application was handled: the listing update that follows
    -- is not one of our own listings.
    local joinedViaApplication = false
    -- Joins already announced (status update and LFG_LIST_JOINED_GROUP report the same).
    local announcedJoins = {}
    local pollTicker

    local function StopPoll()
        if pollTicker then pollTicker:Cancel(); pollTicker = nil end
    end

    local function ResetGroupState()
        resolvedEntryID = nil
        joinedViaApplication = false
        wipe(applicationDungeons)
        wipe(announcedJoins)
        StopPoll()
    end

    -- Reads the activity of a search result once into applicationDungeons.
    local function ResolveApplication(searchResultID, status)
        if applicationDungeons[searchResultID] ~= nil then return end
        local resultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
        local activityID = resultInfo and resultInfo.activityIDs and resultInfo.activityIDs[1]
        if activityID then
            local name, isMythicPlus, dungeon = GetNameFromActivityID(activityID)
            applicationDungeons[searchResultID] = name and {
                name = name, isMythicPlus = isMythicPlus, dungeon = dungeon,
                keyLevel = ParseKeyLevel(resultInfo),
            } or false
            DBG("[QoL] Application resolved: searchResultID=", searchResultID, "activityID=", activityID, "name=", name or "nil")
        else
            DBG("[QoL] Application: no search result info yet for searchResultID=", searchResultID, "status=", status)
        end
    end

    -- Announces a join through an application, once per searchResultID.
    local function AnnounceApplicationJoin(searchResultID)
        if announcedJoins[searchResultID] then return end
        local resolved = applicationDungeons[searchResultID]
        applicationDungeons[searchResultID] = nil
        if not resolved then
            DBG("[QoL] Join reminder: application never resolved to a name (searchResultID=", searchResultID, "- not applicant / not M+ / cache purged)")
            return
        end
        announcedJoins[searchResultID] = true
        resolvedEntryID = true -- no TryResolveAndShow/poll for this join
        joinedViaApplication = true
        StopPoll()
        DispatchJoinReminder(resolved.name, resolved.isMythicPlus, resolved.dungeon, resolved.keyLevel)
    end

    -- Resolves and shows from the group's current listing (any member can read it).
    -- Groups without a Group Finder listing get no reminder, by design. Called from
    -- GROUP_ROSTER_UPDATE and the poll; the poll runs until resolved or ungrouped.
    local function TryResolveAndShow()
        if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
        if not IsInGroup() then
            ResetGroupState()
            return
        end
        if resolvedEntryID then StopPoll(); return end -- already shown for this group

        -- Not resolved yet: keep checking.
        if not pollTicker then pollTicker = C_Timer.NewTicker(POLL_INTERVAL, TryResolveAndShow) end

        local entryInfo = C_LFGList.GetActiveEntryInfo()
        local entryID = entryInfo and entryInfo.activityIDs and entryInfo.activityIDs[1]
        if not entryID then return end
        local name, isMythicPlus, dungeon = GetNameFromActivityID(entryID)
        DBG("[QoL] Join reminder (active entry): resolved name=", name or "nil")
        if name then
            resolvedEntryID = entryID
            StopPoll()
            DispatchJoinReminder(name, isMythicPlus, dungeon, ParseKeyLevel(entryInfo))
        end
    end

    f:SetScript("OnEvent", function(_, event, searchResultID, newStatus)
        if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
            DBG("[QoL] LFG_LIST_APPLICATION_STATUS_UPDATED: searchResultID=", searchResultID, "status=", newStatus)
            -- Resolve early (applied/invited), not only at inviteaccepted.
            ResolveApplication(searchResultID, newStatus)

            if newStatus ~= "inviteaccepted" then return end
            AnnounceApplicationJoin(searchResultID)

        elseif event == "LFG_LIST_JOINED_GROUP" then
            -- Blizzard's "you joined this group" signal, also for members whose leader applied.
            if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
            DBG("[QoL] LFG_LIST_JOINED_GROUP: searchResultID=", searchResultID)
            ResolveApplication(searchResultID, "joined")
            AnnounceApplicationJoin(searchResultID)

        elseif event == "GROUP_ROSTER_UPDATE" then
            TryResolveAndShow()

        elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
            local entryInfo = C_LFGList.GetActiveEntryInfo()
            local activityID = entryInfo and entryInfo.activityIDs and entryInfo.activityIDs[1]

            if activityID then
                if joinedViaApplication then
                    DBG("[QoL] Listing update ignored – joined via application, not own listing")
                    return
                end
                -- Only a leader (or someone alone) owns a listing; members see it too.
                if IsInGroup() and not UnitIsGroupLeader("player") then
                    DBG("[QoL] Listing update ignored – member of someone else's group")
                    return
                end
                -- Own listing created or updated
                local name, isMythicPlus, dungeon = GetNameFromActivityID(activityID)
                if isMythicPlus == nil then return end  -- neither M+ nor current raid
                if keyAddonOpenedByCreation then return end  -- already open
                keyAddonOpenedByCreation = true

                -- Teleport reminder first (no companion addon bookkeeping, no timer).
                if isMythicPlus and RollAwayDB and RollAwayDB.joinReminderKeyAddon == "teleport" then
                    DBG("[QoL] Own M+ listing created – showing teleport reminder:", name or "nil")
                    RA.ShowTeleportReminder(name, dungeon, ParseKeyLevel(entryInfo))
                    return
                end

                -- Companion addon: M+ only
                if isMythicPlus and GetActiveKeyAddon() then
                    DBG("[QoL] Own M+ listing created – opening keystone companion addon")
                    keyAddonOpenedByCreationMplus = true
                    OpenKeyAddon()
                end
            else
                -- Listing removed (cancelled or full). joinedViaApplication stays until
                -- you leave: a re-posted listing is still not ours.
                if not keyAddonOpenedByCreation then return end
                keyAddonOpenedByCreation = false
                keyAddonSafetyTimer.Stop()
                -- Only if the M+ creation opened it
                if keyAddonOpenedByCreationMplus then
                    keyAddonOpenedByCreationMplus = false
                    if GetNumGroupMembers() >= 5 then
                        DBG("[QoL] Group full – starting keystone companion addon safety timer")
                        StartKeyAddonSafetyTimer()
                    else
                        DBG("[QoL] Listing cancelled – closing keystone companion addon immediately")
                        CloseKeyAddon()
                    end
                end
            end
        end
    end)

    DBG("[QoL] Instance join reminder initialized")
end

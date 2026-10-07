-- RollAway - JoinReminder.lua
-- Group Finder (LFG) join detection: shows the instance name when you join
-- an M+/raid group (RollAwayDB.instanceJoinReminder), and either hands off
-- to the Teleport Reminder (Modules\TeleportReminder.lua) or auto-opens a
-- keystone companion addon - BigWigs Keystones or Details! Keystones,
-- mutually exclusive via RollAwayDB.joinReminderKeyAddon.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

------------------------------------------------------------------------
-- Keystone companion addon – BigWigs Keystones or Details! Keystones.
-- Calls SlashCmdList directly (not typed text) to avoid triggering other addons.
------------------------------------------------------------------------

-- Availability checks, exposed via RA so Options can grey out the
-- corresponding checkbox when the addon isn't installed/loaded.
local function IsBigWigsKeyAvailable()
    return _G["BigWigsLoader"] ~= nil and SlashCmdList["key"] ~= nil
end
RA.IsBigWigsKeyAvailable = IsBigWigsKeyAvailable

local function IsDetailsKeyAvailable()
    return _G["Details"] ~= nil and SlashCmdList["KEYSTONE"] ~= nil
end
RA.IsDetailsKeyAvailable = IsDetailsKeyAvailable

-- Returns "bigwigs" / "details" if the selected companion addon is loaded
-- and its toggle command is available, otherwise nil.
local function GetActiveKeyAddon()
    local choice = RollAwayDB and RollAwayDB.joinReminderKeyAddon
    if choice == "bigwigs" and IsBigWigsKeyAvailable() then return "bigwigs" end
    if choice == "details" and IsDetailsKeyAvailable() then return "details" end
    return nil
end

-- Opens the selected companion addon's keystone frame. Idempotent (no-op if
-- already open) for "details" - important since the trigger can fire while
-- the frame is already open from something outside our own bookkeeping.
-- BigWigs only exposes a toggle command with no reliable way to check its
-- frame's shown state, so it's called unconditionally there - same caveat
-- applies to it, unavoidable for now.
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

-- Closes it - idempotent counterpart to OpenKeyAddon (same BigWigs caveat).
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
-- Keystone companion addon – safety-close timer.
-- Whenever we auto-open BigWigs/Details Keystones for the player, it stays
-- open until either they cast a known M+ portal spell (closes immediately)
-- or a 20s safety timer runs out (closes automatically either way).
------------------------------------------------------------------------

local keyAddonReminderOpen = false -- true while we're holding it open

-- Pending 20s safety-close timer (Start()/Stop() handle).
local keyAddonSafetyTimer = RA.CreateOneShotTimer(20, function()
    if keyAddonReminderOpen then
        DBG("[QoL] Safety timer expired – closing keystone companion addon")
        keyAddonReminderOpen = false
        CloseKeyAddon()
    end
end)

-- Closes the keystone companion addon if we're the ones holding it open,
-- and cancels any pending safety timer. Called on timeout or portal cast.
local function CloseKeyAddonReminder()
    keyAddonSafetyTimer.Stop()
    if keyAddonReminderOpen then
        keyAddonReminderOpen = false
        DBG("[QoL] Closing keystone companion addon")
        CloseKeyAddon()
    end
end

-- Starts (or restarts) the 20s safety-close timer.
local function StartKeyAddonSafetyTimer()
    keyAddonReminderOpen = true
    keyAddonSafetyTimer.Start()
end

-- Checks if spellID is one of the current season's M+ portal spells.
local function IsKnownPortalSpell(spellID)
    if not RA.IsAccessible(spellID) then return false end
    for _, d in ipairs(RA.DUNGEONS[RA.ACTIVE_SEASON] or {}) do
        if d.portalSpellID == spellID then return true end
    end
    return false
end

-- Closes early the moment the player actually casts a portal, regardless of
-- whether it was clicked in BigWigs/Details, RollAway's own teleport
-- reminder, the spellbook, or a macro.
local portalWatcher = CreateFrame("Frame")
portalWatcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
portalWatcher:SetScript("OnEvent", function(_, _, _, _, spellID)
    if keyAddonReminderOpen and IsKnownPortalSpell(spellID) then
        DBG("[QoL] Portal cast detected – closing keystone companion addon early")
        CloseKeyAddonReminder()
    end
end)

------------------------------------------------------------------------
-- Instance Join reminder – shows instance name when joining a group
------------------------------------------------------------------------

local joinFrame, joinHideTimer   -- QoL toast (RA.CreateToastFrame), created on first show
local keyAddonOpenedByCreation      = false -- shared: own listing active (M+ or raid)
local keyAddonOpenedByCreationMplus = false -- true only when own M+ listing opened the companion addon

-- Party groups: the hide timer only starts once the group is full (5), with
-- a 30s fallback if it never fills. One wait at a time - a newer reminder
-- supersedes an older pending one.
local pendingHideStart              -- fn to run when the wait is over
local FinishGroupWait
local groupWaitFallback = RA.CreateOneShotTimer(30, function()
    DBG("[QoL] Fallback – starting hide timer after 30s")
    FinishGroupWait()
end)
local groupWaitFrame = CreateFrame("Frame")
groupWaitFrame:SetScript("OnEvent", function()
    -- Small delay so WoW has time to update the roster count
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
    -- Don't show reminder if we are the group leader (own listing creation)
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

    -- Auto-open companion addon for party only (no keystone teleports in raid);
    -- skip if already opened by listing creation.
    local keyAddonOpened = false
    if not IsInRaid() and not keyAddonOpenedByCreation and GetActiveKeyAddon() then
        keyAddonOpened = true
        C_Timer.After(0.3, OpenKeyAddon)
    end

    -- Hides the join text banner after 6s. The keystone companion addon (if
    -- opened) is handed off to the 20s safety timer instead, so it stays
    -- open independently until a portal is cast or it times out.
    local function StartHideTimer()
        joinHideTimer.Start()
        if keyAddonOpened then
            StartKeyAddonSafetyTimer()
            keyAddonOpened = false -- ownership passed to the safety timer
        end
    end

    -- Raids: start immediately. Party: wait for full group (5). forceTimer
    -- (test mode) skips the group check.
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

-- Finds the current-season dungeon entry (Data\Dungeons.lua) matching an
-- LFG activity ID. activityID == dungeon.lfgID (see LFGQuickCreate.lua).
local function GetDungeonEntryByLfgID(activityID)
    for _, d in ipairs(RA.DUNGEONS[RA.ACTIVE_SEASON] or {}) do
        if d.lfgID == activityID then return d end
    end
    return nil
end

-- Resolve name/isMythicPlus/dungeon from an LFG activity ID. Returns nil if
-- the activity is not a Mythic+ dungeon or current raid. For M+ dungeons the
-- name comes from our own locale table (RA_L), not the Blizzard client
-- string, so it always matches the addon's own language setting instead of
-- the game client's.
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
        -- Fallback for a M+ activity outside the tracked season pool
        -- (shouldn't normally happen) - use the Blizzard string as-is.
        return blizzardName, true, nil
    end
    return blizzardName, false, nil
end

-- The API has no keystone level for a listing, so read it from the title or
-- comment the group leader wrote ("+14", "M+14", "+14 Altar ..."). info is a
-- search result / active entry table. Returns a number or nil (not written,
-- or the text is not readable - 12.x secret strings).
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

-- Routes to the teleport reminder for Mythic+ when selected, otherwise the
-- default instance-name join reminder. Raids always use the default one -
-- BigWigs/Details/teleport portals don't apply to raid teleports.
-- keyLevel only applies to Mythic+ (nil for raids).
local function DispatchJoinReminder(name, isMythicPlus, dungeon, keyLevel)
    if not isMythicPlus then keyLevel = nil end
    if isMythicPlus and RollAwayDB and RollAwayDB.joinReminderKeyAddon == "teleport" then
        RA.ShowTeleportReminder(name, dungeon, keyLevel)
    else
        ShowJoinReminder(name, nil, keyLevel)
    end
end

------------------------------------------------------------------------
-- Group Finder (LFG) join detection.
--
-- Two ways to end up in an LFG-sourced M+/raid group, both handled below:
--  1. You post your own listing (LFG_LIST_ACTIVE_ENTRY_UPDATE).
--  2. You apply to someone else's listing, or you're simply a party member
--     of whoever applied (their application is a party-wide event - every
--     member's client receives LFG_LIST_APPLICATION_STATUS_UPDATED for it,
--     not just the one who clicked "Apply"). See applicationDungeons below.
--
-- Once in the group, C_LFGList.GetActiveEntryInfo() also reflects the
-- group's listing for every member while it's still active/recruiting -
-- not just for whoever created it - so GROUP_ROSTER_UPDATE alone should
-- resolve it. In practice that resolution can race with the roster/LFG
-- state actually being ready, so a short poll (see below) re-checks it
-- every few seconds as a safety net until it succeeds.
------------------------------------------------------------------------

local POLL_INTERVAL = 3

function RA.InitJoinReminder()
    local f = CreateFrame("Frame")
    f:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

    -- Per-group state, all reset together on ungroup (see ResetGroupState).
    local resolvedEntryID   = nil   -- activityID we've already shown/dispatched for
    -- searchResultID -> { name, isMythicPlus, dungeon } (or false for
    -- "resolved, not M+/raid"), filled as soon as an application's
    -- activityIDs can be read (as early as "applied"/"invited"), so
    -- "inviteaccepted" never has to re-resolve from a possibly-already-purged
    -- browse cache entry.
    local applicationDungeons = {}
    -- true once an application-accepted join was handled: the listing update
    -- that follows (also fired for members) isn't one of our own creations.
    local joinedViaApplication = false

    local function ResetGroupState()
        resolvedEntryID = nil
        joinedViaApplication = false
        wipe(applicationDungeons)
    end

    -- Tries to resolve + show from the group's current LFG listing
    -- (GetActiveEntryInfo works for any member while a listing is active,
    -- not just whoever created it). Manually-formed groups with no LFG
    -- listing at all get no reminder - Group Finder M+ only, by design.
    -- Called from GROUP_ROSTER_UPDATE and the poll ticker.
    local function TryResolveAndShow()
        if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
        if not IsInGroup() then
            ResetGroupState()
            return
        end
        if resolvedEntryID then return end -- already shown for this group

        local entryInfo = C_LFGList.GetActiveEntryInfo()
        local entryID = entryInfo and entryInfo.activityIDs and entryInfo.activityIDs[1]
        if not entryID then return end
        local name, isMythicPlus, dungeon = GetNameFromActivityID(entryID)
        DBG("[QoL] Join reminder (active entry): resolved name=", name or "nil")
        if name then
            resolvedEntryID = entryID
            DispatchJoinReminder(name, isMythicPlus, dungeon, ParseKeyLevel(entryInfo))
        end
    end

    -- Safety-net poll: GROUP_ROSTER_UPDATE can fire before the LFG listing
    -- state is actually queryable yet (a member added to an already-active
    -- listing doesn't get a creation event of its own to react to). Cheap
    -- early-exits inside TryResolveAndShow() make this a no-op once resolved
    -- or ungrouped, so it's safe to just leave running for the session.
    C_Timer.NewTicker(POLL_INTERVAL, TryResolveAndShow)

    f:SetScript("OnEvent", function(_, event, searchResultID, newStatus)
        if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
            DBG("[QoL] LFG_LIST_APPLICATION_STATUS_UPDATED: searchResultID=", searchResultID, "status=", newStatus)
            -- Resolve as early as possible (applied/invited), not just at
            -- inviteaccepted - the search-result cache backing
            -- GetSearchResultInfo can already be gone by then, especially
            -- for a party member who never personally browsed/applied.
            if applicationDungeons[searchResultID] == nil then
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
                    DBG("[QoL] Application: no search result info yet for searchResultID=", searchResultID, "status=", newStatus)
                end
            end

            if newStatus ~= "inviteaccepted" then return end
            local resolved = applicationDungeons[searchResultID]
            applicationDungeons[searchResultID] = nil
            if not resolved then
                DBG("[QoL] Join reminder: application never resolved to a name (searchResultID=", searchResultID, "- not applicant / not M+ / cache purged)")
                return
            end
            resolvedEntryID = true -- suppress TryResolveAndShow/poll for this join
            joinedViaApplication = true
            DispatchJoinReminder(resolved.name, resolved.isMythicPlus, resolved.dungeon, resolved.keyLevel)

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
                -- Own listing created or updated (M+ or raid)
                local name, isMythicPlus, dungeon = GetNameFromActivityID(activityID)
                if isMythicPlus == nil then return end  -- neither M+ nor current raid
                if keyAddonOpenedByCreation then return end  -- already open
                keyAddonOpenedByCreation = true

                -- Teleport reminder takes priority for M+ when selected -
                -- doesn't use the companion-addon open/close bookkeeping
                -- below since it has no auto-close timer.
                if isMythicPlus and RollAwayDB and RollAwayDB.joinReminderKeyAddon == "teleport" then
                    DBG("[QoL] Own M+ listing created – showing teleport reminder:", name or "nil")
                    RA.ShowTeleportReminder(name, dungeon, ParseKeyLevel(entryInfo))
                    return
                end

                -- Only open the companion addon for M+ (raids have no keystone teleports)
                if isMythicPlus and GetActiveKeyAddon() then
                    DBG("[QoL] Own M+ listing created – opening keystone companion addon")
                    keyAddonOpenedByCreationMplus = true
                    OpenKeyAddon()
                end
            else
                -- Listing removed (cancelled or group full)
                joinedViaApplication = false
                if not keyAddonOpenedByCreation then return end
                keyAddonOpenedByCreation = false
                keyAddonSafetyTimer.Stop()
                -- Only toggle the companion addon if it was opened by M+ creation
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

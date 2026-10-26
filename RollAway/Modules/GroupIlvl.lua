-- RollAway - Modules/GroupIlvl.lua
-- Item level of the group's members for ElvUI's unit frames (the [gilvl] tags live in
-- Core/ElvUI_Tags.lua). Your own level is read from the character sheet; everyone else is
-- inspected one at a time: pick the first member whose entry is missing or stale, send
-- NotifyInspect, wait for INSPECT_READY, store the result, repeat. There is no queue: each
-- step rescans the (at most 40) roster tokens, so a roster change cannot leave a stale unit
-- token behind. The step timer only runs while somebody still needs an inspect.
--
-- Active only with ElvUI and RollAwayDB.groupIlvl (QoL page "Group"); the events are
-- registered only then (RA.ApplyGroupIlvl). The color steps are ours (BANDS), not a setting.
-- /gilvl: rescan, status.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local TTL           = 600  -- seconds until a known level is inspected again
local STEP_DELAY    = 2    -- spacing between inspects; the server throttles faster requests
local REPLY_TIMEOUT = 5    -- no INSPECT_READY after this long counts as a failure
local RANGE_RETRY   = 5    -- out of inspect range / offline: look again later, not a failure
local MAX_AGE       = 3600 -- cache entries older than this are dropped when the roster changes

-- Colors below the first threshold and from each threshold up: grey, white, green, blue,
-- purple, orange, gold.
local COLORS = { "|cff9d9d9d", "|cffffffff", "|cff1eff00", "|cff3d9bff", "|cffa335ee",
    "|cffff8000", "|cffe6cc80" }
-- Item level where each color step starts (six ascending numbers). Every season moves them:
-- adjust here (see SEASON_WECHSEL.md).
local BANDS = { 250, 275, 295, 310, 320, 330 }

local PARTY_UNITS, RAID_UNITS = {}, {}
for i = 1, 4 do PARTY_UNITS[i] = "party" .. i end
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local cache = {}               -- guid -> { ilvl = number, at = GetTime() }
local listeners = {}           -- fn(guid) when a level changed
local retryAt, fails, dirty = {}, {}, {}
local loggedRange = {}         -- guid -> true once "cannot be inspected" was logged (once per spell out of range)
local pending                  -- { guid, unit } while an inspect request is in flight
local generation = 0           -- the latest scheduled step wins
local playerGUID
local eventFrame

local function IsActive()
    return ElvUI ~= nil and RollAwayDB ~= nil and RollAwayDB.groupIlvl == true
end

-- UnitGUID can hand back a secret inside instances, and a secret as a table key throws.
local function UnitGUIDSafe(unit)
    if not unit then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not guid or not RA.IsAccessible(guid) then return nil end
    return guid
end
RA.SafeUnitGUID = UnitGUIDSafe

-- A secret InCombatLockdown() reads as true in every conditional, so it counts as "not in
-- combat": waiting on it would block inspecting for the whole stay in an instance.
local function InCombat()
    local v = InCombatLockdown()
    if not RA.IsAccessible(v) then return false end
    return v
end

-- Level cache

local function Notify(guid)
    for i = 1, #listeners do listeners[i](guid) end
end

local function SetIlvl(guid, ilvl)
    ilvl = math.floor(ilvl + 0.5)
    local entry = cache[guid]
    local changed = not entry or entry.ilvl ~= ilvl
    if not entry then
        entry = {}
        cache[guid] = entry
    end
    entry.ilvl = ilvl
    entry.at = GetTime()
    if changed then Notify(guid) end
end

-- After a setting changed: every displayed level may look different now.
local function NotifyAll()
    for guid in pairs(cache) do Notify(guid) end
end

local function PruneCache()
    local now = GetTime()
    for guid, entry in pairs(cache) do
        if guid ~= playerGUID and now - entry.at > MAX_AGE then cache[guid] = nil end
    end
end

-- Colors

local function ColorFor(ilvl)
    local step = 1
    for i = 1, #BANDS do
        if ilvl >= BANDS[i] then step = i + 1 else break end
    end
    return COLORS[step]
end

-- The scale in its own colors, for the options and /gilvl status.
function RA.GetGroupIlvlLegend()
    local parts = { COLORS[1] .. "<" .. BANDS[1] .. "|r" }
    for i = 1, #BANDS do parts[i + 1] = COLORS[i + 1] .. BANDS[i] .. "+|r" end
    return table.concat(parts, " ")
end

-- The text of a tag for `unit`; nil, never "", when there is nothing to show: oUF prints a
-- tag's prefix/suffix literals for every non-nil return, even an empty string.
-- mode: nil = colored (if enabled), "plain" = never colored, "brackets" = [284]
function RA.FormatGroupIlvl(unit, mode)
    if not IsActive() then return nil end
    local guid = UnitGUIDSafe(unit)
    local entry = guid and cache[guid]
    if not entry then return nil end

    local text = tostring(entry.ilvl)
    if mode == "brackets" then text = "[" .. text .. "]" end
    if mode ~= "plain" and RollAwayDB.groupIlvlColored then
        text = ColorFor(entry.ilvl) .. text .. "|r"
    end
    return text
end

-- fn(guid) runs when a level changed (the tags redraw their frames).
function RA.OnGroupIlvlChanged(fn)
    listeners[#listeners + 1] = fn
end

-- Redraws the tags after the "colored" switch changed.
function RA.RefreshGroupIlvlTags()
    NotifyAll()
end

-- Inspecting

local Step

-- Latest call wins, which also debounces bursts of roster events.
local function Schedule(delay)
    generation = generation + 1
    local mine = generation
    C_Timer.After(delay, function()
        if mine == generation then Step() end
    end)
end

local function Kick(delay)
    if pending then return end
    Schedule(delay or 0.5)
end

local function Fail(guid)
    local count = (fails[guid] or 0) + 1
    fails[guid] = count
    retryAt[guid] = GetTime() + math.min(15 * 2 ^ (count - 1), 300)
end

local function Succeed(guid)
    fails[guid], retryAt[guid], dirty[guid], loggedRange[guid] = nil, nil, nil, nil
end

local function Inspectable(unit)
    return UnitIsConnected(unit) and CanInspect(unit) and CheckInteractDistance(unit, 1)
end

function Step()
    if not IsActive() or not IsInGroup() then return end

    if pending then -- the reply never came
        DBG("[GroupIlvl] no reply from", pending.unit)
        Fail(pending.guid)
        pending = nil
    end

    -- PLAYER_REGEN_ENABLED starts the next step.
    if InCombat() then return end
    -- Never steal the inspect target from the player's own inspect window.
    if InspectFrame and InspectFrame:IsShown() then return Schedule(3) end

    local units, count
    if IsInRaid() then
        units, count = RAID_UNITS, GetNumGroupMembers()
    else
        units, count = PARTY_UNITS, GetNumSubgroupMembers()
    end

    local now = GetTime()
    local soonest
    for i = 1, count do
        local unit = units[i]
        local guid = UnitGUIDSafe(unit)
        if not guid then
            -- Identity not readable (hidden in a restricted state, or the member is not loaded
            -- yet): look again later, nothing else would wake us up for a group that stays as is.
            DBG("[GroupIlvl] GUID of", unit, "not readable - retry later")
            local wake = now + RANGE_RETRY
            soonest = soonest and math.min(soonest, wake) or wake
        elseif guid ~= playerGUID then
            local entry = cache[guid]
            -- Fresh entries still set the wake-up time of their own expiry.
            local wake = entry and not dirty[guid] and entry.at + TTL
            if not wake or wake <= now then
                wake = retryAt[guid]
                if not wake or wake <= now then
                    local ok, usable = pcall(Inspectable, unit)
                    if ok and usable then
                        DBG("[GroupIlvl] inspecting", unit)
                        pending = { guid = guid, unit = unit }
                        NotifyInspect(unit)
                        return Schedule(REPLY_TIMEOUT)
                    end
                    if not loggedRange[guid] then
                        loggedRange[guid] = true
                        DBG("[GroupIlvl]", unit, "cannot be inspected now (offline / out of range), checking again every", RANGE_RETRY, "s")
                    end
                    wake = now + RANGE_RETRY
                    retryAt[guid] = wake
                end
            end
            soonest = soonest and math.min(soonest, wake) or wake
        end
    end

    if soonest then Schedule(math.max(1, soonest - now)) end
end

local function OnInspectReady(guid)
    if not pending or not RA.IsAccessible(guid) or pending.guid ~= guid then return end

    local unit = pending.unit
    pending = nil

    local ok, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
    if ok and type(ilvl) == "number" and RA.IsAccessible(ilvl) and ilvl > 0
        and UnitGUIDSafe(unit) == guid then
        Succeed(guid)
        SetIlvl(guid, ilvl)
        DBG("[GroupIlvl]", unit, "item level", ilvl)
    else
        DBG("[GroupIlvl] no item level for", unit, "in the reply")
        Fail(guid)
    end

    if not (InspectFrame and InspectFrame:IsShown()) then ClearInspectPlayer() end
    Schedule(STEP_DELAY)
end

local function UpdateSelf()
    local _, equipped = GetAverageItemLevel()
    if type(equipped) == "number" and equipped > 0 and playerGUID then
        SetIlvl(playerGUID, equipped)
    end
end

local function OnGroupChanged()
    PruneCache()
    if not IsInGroup() then
        pending = nil
        wipe(retryAt)
        wipe(fails)
        wipe(dirty)
        wipe(loggedRange)
        return
    end
    Kick()
end

local function OnInventoryChanged(unit)
    if unit == "player" or type(unit) ~= "string" then return end
    if not (unit:find("^party%d$") or unit:find("^raid%d+$")) then return end
    local guid = UnitGUIDSafe(unit)
    if guid then
        dirty[guid] = true
        Kick(2)
    end
end

-- Forget what is known and inspect everybody again.
local function Rescan()
    wipe(retryAt)
    for guid in pairs(cache) do
        if guid ~= playerGUID then dirty[guid] = true end
    end
    Kick()
end

local function OnEvent(_, event, arg1)
    if event == "INSPECT_READY" then
        OnInspectReady(arg1)
    elseif event == "UNIT_INVENTORY_CHANGED" then
        OnInventoryChanged(arg1)
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupChanged()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Kick()
    elseif event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUIDSafe("player")
        UpdateSelf()
        wipe(retryAt)   -- a zone change usually brings the group together: look at once
        OnGroupChanged()
    else -- PLAYER_EQUIPMENT_CHANGED, PLAYER_AVG_ITEM_LEVEL_UPDATE
        UpdateSelf()
    end
end

local EVENTS = { "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "INSPECT_READY",
    "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE" }

-- Starts or stops everything according to the setting (at login and when it is toggled).
function RA.ApplyGroupIlvl()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", OnEvent)
    end
    if IsActive() then
        for _, event in ipairs(EVENTS) do eventFrame:RegisterEvent(event) end
        playerGUID = UnitGUIDSafe("player")
        UpdateSelf()
        OnGroupChanged()
    else
        eventFrame:UnregisterAllEvents()
        generation = generation + 1   -- a scheduled step does nothing any more
        pending = nil
        wipe(retryAt)
        wipe(fails)
        wipe(dirty)
        wipe(loggedRange)
    end
    NotifyAll()
end

-- /gilvl

local function Print(text)
    print("|cff33ccffRollAway|r " .. text)
end

function RA.InitGroupIlvl()
    RA.ApplyGroupIlvl()

    SLASH_ROLLAWAYGILVL1 = "/gilvl"
    SlashCmdList["ROLLAWAYGILVL"] = function(msg)
        local cmd = msg:lower():match("^%s*(%S*)")
        if cmd == "scan" then
            if IsActive() then
                Rescan()
                Print(RA_L["gilvl_rescan"])
            else
                Print(RA_L["gilvl_inactive"])
            end
        elseif cmd == "status" then
            local count = 0
            for _ in pairs(cache) do count = count + 1 end
            Print(string.format(RA_L["gilvl_thresholds"], RA.GetGroupIlvlLegend()))
            Print(string.format(RA_L["gilvl_status"], count, ElvUI and RA_L["gilvl_found"] or RA_L["gilvl_no_elvui"]))
        else
            Print(RA_L["gilvl_help"])
        end
    end
end

-- RollAway - Modules/GroupIlvl.lua
-- Item level of the group's members for ElvUI's unit frames (the [raw:ilvl] tags live in
-- Core/ElvUI_Tags.lua). Your own level is read from the character sheet; everyone else is
-- inspected one at a time: pick the first member who has no level yet (or whose gear
-- changed), send NotifyInspect, wait for INSPECT_READY, store the result, repeat. A member
-- is scanned once and the level stays cached while he is in the group: no periodic asking.
-- Inspect replies that other addons or the inspect window triggered are used as well.
-- The cache is also kept per character (RollAwayDBChar.groupIlvlCache) and survives /reload;
-- it is dropped when a member leaves, when you leave the group and on a fresh login.
-- There is no queue: each step rescans the (at most 40) roster tokens, so a roster change
-- cannot leave a stale unit token behind. The step timer only runs while somebody still
-- needs an inspect.
--
-- Active only with ElvUI and RollAwayDB.groupIlvl (QoL page "Group"); the events are
-- registered only then (RA.ApplyGroupIlvl). The color steps are ours (BANDS), not a setting.
-- /rawilvl: rescan, status.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local STEP_DELAY    = 1    -- spacing between inspects; the server throttles faster requests
local REPLY_TIMEOUT = 3    -- no INSPECT_READY after this long counts as a failure (a late reply is still used)
local RANGE_RETRY   = 3    -- out of inspect range / offline: look again later, not a failure

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

local cache = {}               -- guid -> item level
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

-- The saved copy of the cache (per character): guid -> item level.
local function Saved()
    local saved = RollAwayDBChar and RollAwayDBChar.groupIlvlCache
    return type(saved) == "table" and saved or nil
end

local function SetIlvl(guid, ilvl)
    ilvl = math.floor(ilvl + 0.5)
    local changed = cache[guid] ~= ilvl
    cache[guid] = ilvl
    -- Your own level is read from the character sheet at once, no need to save it.
    local saved = guid ~= playerGUID and Saved()
    if saved then saved[guid] = ilvl end
    if changed then Notify(guid) end
end

-- Takes the saved levels into the cache (damaged entries are dropped).
local function LoadSaved()
    local saved = Saved()
    if not saved then return end
    for guid, ilvl in pairs(saved) do
        if type(ilvl) == "number" then
            if not cache[guid] then cache[guid] = ilvl end
        else
            saved[guid] = nil
        end
    end
end

-- After a setting changed: every displayed level may look different now.
local function NotifyAll()
    for guid in pairs(cache) do Notify(guid) end
end

-- The unit tokens and head count of the current group (party or raid).
local function GroupUnits()
    if IsInRaid() then return RAID_UNITS, GetNumGroupMembers() end
    return PARTY_UNITS, GetNumSubgroupMembers()
end

-- Drops every level (saved copy included) except yours and those of the guids in `keep`.
local function Drop(keep)
    for guid in pairs(cache) do
        if guid ~= playerGUID and not keep[guid] then cache[guid] = nil end
    end
    local saved = Saved()
    if saved then
        for guid in pairs(saved) do
            if not keep[guid] then saved[guid] = nil end
        end
    end
end

-- Forgets the levels of everybody who is not in the group (any more). A member whose identity
-- is not readable yet could not be told from a stranger: keep everything until it is.
local present, NONE = {}, {}
local function PruneCache()
    wipe(present)
    local units, count = GroupUnits()
    for i = 1, count do
        local guid = UnitGUIDSafe(units[i])
        if not guid then return end
        present[guid] = true
    end
    Drop(present)
end

-- Colors

local function ColorFor(ilvl)
    local step = 1
    for i = 1, #BANDS do
        if ilvl >= BANDS[i] then step = i + 1 else break end
    end
    return COLORS[step]
end

-- The scale in its own colors, for the options and /rawilvl status.
function RA.GetGroupIlvlLegend()
    local parts = { COLORS[1] .. "<" .. BANDS[1] .. "|r" }
    for i = 1, #BANDS do parts[i + 1] = COLORS[i + 1] .. BANDS[i] .. "+|r" end
    return table.concat(parts, " ")
end

-- The text of a tag for `unit`; nil, never "", when there is nothing to show: oUF prints a
-- tag's prefix/suffix literals for every non-nil return, even an empty string.
-- mode: nil = colored (if enabled), "plain" = never colored
function RA.FormatGroupIlvl(unit, mode)
    if not IsActive() then return nil end
    local guid = UnitGUIDSafe(unit)
    local ilvl = guid and cache[guid]
    if not ilvl then return nil end

    local text = tostring(ilvl)
    if mode ~= "plain" and RollAwayDB.groupIlvlColored then
        text = ColorFor(ilvl) .. text .. "|r"
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
    retryAt[guid] = GetTime() + math.min(3 * 2 ^ (count - 1), 120)
end

local function Succeed(guid)
    fails[guid], retryAt[guid], dirty[guid], loggedRange[guid] = nil, nil, nil, nil
end

-- UnitInRange reaches about 40 m (friendly spell range), far more than the 28 m of
-- CheckInteractDistance. Its result can be secret or unchecked (checkedRange false): then the
-- shorter interact distance decides.
local function Inspectable(unit)
    if not (UnitIsConnected(unit) and CanInspect(unit)) then return false end
    local inRange, checked = UnitInRange(unit)
    if RA.IsAccessible(inRange) and RA.IsAccessible(checked) and checked then return inRange end
    return CheckInteractDistance(unit, 1)
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

    local units, count = GroupUnits()

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
            -- Already scanned (and the gear did not change): nothing to ask.
            if not cache[guid] or dirty[guid] then
                local wake = retryAt[guid]
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
                soonest = soonest and math.min(soonest, wake) or wake
            end
        end
    end

    if soonest then Schedule(math.max(1, soonest - now)) end
end

-- Stores the inspect result for `unit` (must still be `guid`); false when there is none.
local function StoreInspected(unit, guid)
    local ok, ilvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
    if ok and type(ilvl) == "number" and RA.IsAccessible(ilvl) and ilvl > 0
        and UnitGUIDSafe(unit) == guid then
        Succeed(guid)
        SetIlvl(guid, ilvl)
        DBG("[GroupIlvl]", unit, "item level", ilvl)
        return true
    end
    return false
end

-- An inspect somebody else asked for (the inspect window, another addon): the answer is free,
-- keep it for group members. Reading only, our own request stays untouched.
local function HarvestInspect(guid)
    if guid == playerGUID then return end
    local units, count = GroupUnits()
    for i = 1, count do
        if UnitGUIDSafe(units[i]) == guid then
            StoreInspected(units[i], guid)
            return
        end
    end
end

local function OnInspectReady(guid)
    if not RA.IsAccessible(guid) then return end
    if not pending or pending.guid ~= guid then return HarvestInspect(guid) end

    local unit = pending.unit
    pending = nil

    if not StoreInspected(unit, guid) then
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
        if arg1 then Drop(NONE) end   -- arg1 = isInitialLogin: only a /reload keeps the levels
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
        LoadSaved()
        UpdateSelf()
        OnGroupChanged()
    else
        eventFrame:UnregisterAllEvents()
        generation = generation + 1   -- a scheduled step does nothing any more
        pending = nil
        Drop(NONE)
        wipe(retryAt)
        wipe(fails)
        wipe(dirty)
        wipe(loggedRange)
    end
    if RA.SetElvUITags then RA.SetElvUITags(IsActive()) end   -- only defined with ElvUI
    NotifyAll()
end

-- /rawilvl

function RA.InitGroupIlvl()
    RA.ApplyGroupIlvl()
    if not ElvUI then return end   -- no tags to feed: no command either

    SLASH_ROLLAWAYGILVL1 = "/rawilvl"
    SlashCmdList["ROLLAWAYGILVL"] = function(msg)
        local cmd = msg:lower():match("^%s*(%S*)")
        if cmd == "scan" then
            if IsActive() then
                Rescan()
                RA.Print(RA_L["gilvl_rescan"])
            else
                RA.Print(RA_L["gilvl_inactive"])
            end
        elseif cmd == "status" then
            local count = 0
            for _ in pairs(cache) do count = count + 1 end
            RA.Print(string.format(RA_L["gilvl_thresholds"], RA.GetGroupIlvlLegend()))
            RA.Print(string.format(RA_L["gilvl_status"], count))
        else
            RA.Print(RA_L["gilvl_help"])
        end
    end
end

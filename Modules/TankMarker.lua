-- RollAway - TankMarker.lua
-- Offers to put a raid marker (default: square) on the group's tank. Since
-- 12.0 SetRaidTarget is protected: addon code cannot call it, only a secure
-- button running the "/tm" macro command can. A secure button needs a real
-- click, so the addon shows a small popup with a "Mark" button instead of
-- marking by itself.
--
-- Settings: RollAwayDB.tankMarkEnabled / tankMarkIcon (1-8)
-- Only 5-man groups; the popup shows once per tank and marker per group, and
-- only in a dungeon (instance type "party").
--
-- Test tools (the feature is experimental, it has to be tried on live):
--   /rawtank       shows the popup right now, in any place
--   /rawtank test  toggles a test mode until /reload: works solo (your own
--                  spec role counts as tank) and writes to the debug log why
--                  the popup did or did not show, and whether the marker was
--                  set after the click.
--   /rawtank auto  (in test mode) clicks the button from code instead of
--                  showing the popup, never during a running M+ key; the log
--                  also reports taint blocks (ADDON_ACTION_BLOCKED/FORBIDDEN).

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local TIMER_DURATION = 20
local CHECK_DELAY    = 1.5   -- roles / roster settle a moment after the event

local markFrame
local eventFrame
local checkPending
local lastOffer   -- "guid:icon" already offered in this group
local testMode    -- session only, see header
local autoMode    -- session only, test mode + /rawtank auto: no popup, click from code

-- Inline texture of raid marker `index`, for popup text and the options list.
function RA.RaidIconText(index)
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:16|t"):format(index)
end

-- Test-mode output only (debug log).
local function TestSay(msg)
    if testMode then DBG("[TankMarker test] " .. msg) end
end

------------------------------------------------------------------------
-- Popup with the secure "Mark" button
------------------------------------------------------------------------

-- Macro variants for the button (test mode can switch: /rawtank variant 2).
-- 1: marker straight onto the unit; 2: via targeting (and back), in case
-- "/tm [@unit]" does not work in that spot.
local MACROS = {
    "/tm [@%s] %d",
    "/target %s\n/tm %d\n/targetlasttarget",
}
local macroVariant = 1

-- Current marker of `unit` (nil = none). 12.0 can hand back "secret values"
-- that must not be compared; those, and errors, count as "unknown" (nil) and
-- the second result says what happened.
local function ReadMarker(unit)
    local ok, index = pcall(GetRaidTargetIndex, unit)
    if not ok then return nil, "error: " .. tostring(index) end
    if issecretvalue and issecretvalue(index) then return nil, "secret value" end
    return index, "ok"
end

-- After the click: did the marker really arrive? (test mode only)
local function VerifyMarker(unit, icon)
    TestSay(("Click received: variant %d, group %s, macro %q"):format(
        macroVariant, tostring(IsInGroup()), (MACROS[macroVariant]:format(unit, icon):gsub("\n", " | "))))
    for _, delay in ipairs({ 0.5, 2 }) do
        C_Timer.After(delay, function()
            local now, state = ReadMarker(unit)
            TestSay(("After %.1fs: %s marker read = %s (%s) - %s"):format(
                delay, unit, tostring(now), state, now == icon and "SET" or "not confirmed by reading"))
        end)
    end
end

local function CreateMarkFrame()
    if markFrame then return end

    markFrame = RA.CreatePopupFrame({
        name      = "RollAwayTankMarkFrame",
        okayName  = "RollAwayTankMarkOkay",
        width     = 300,
        height    = 100,
        yOffset   = -340,
        duration  = TIMER_DURATION,
        fitHeight = function(self)
            return RA.POPUP_CHROME_HEIGHT + self.msg:GetStringHeight() + 10
        end,
    })

    markFrame.msg = RA.CreatePopupBodyText(markFrame)

    -- The macro runs on the click itself; PostClick only closes the popup.
    -- Registered for both phases: a secure button only fires in the one that
    -- matches the "ActionButtonUseKeyDown" CVar (so it still runs once), and
    -- an up-only button never fires when that CVar is on.
    local btn = CreateFrame("Button", "RollAwayTankMarkBtn", markFrame, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetPoint("RIGHT", markFrame.okayBtn, "LEFT", -6, 0)
    btn:SetText(RA_L["tankmark_button"])
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "macro")
    btn:SetScript("PostClick", function(_, _, down)
        -- Only the phase that ran the macro closes the popup.
        if (down and true or false) ~= (GetCVarBool("ActionButtonUseKeyDown") and true or false) then return end
        if testMode then VerifyMarker(markFrame.unit, markFrame.icon) end
        markFrame:Hide()
    end)
    if RA.SkinPopupButton then RA.SkinPopupButton(btn) end
    markFrame.markBtn = btn

    RA.SetupInstanceReminderLifecycle(markFrame, "tankMarkShown")
end

-- Points the button at `unit` / `icon`. Attributes of a secure button can
-- only change out of combat; returns false then.
local function PrepareMark(unit, icon)
    CreateMarkFrame()
    if InCombatLockdown() then return false end

    markFrame.unit, markFrame.icon = unit, icon
    markFrame.markBtn:SetAttribute("macrotext", MACROS[macroVariant]:format(unit, icon))
    markFrame.msg:SetText(RA_L["tankmark_msg"]:format(UnitName(unit), RA.RaidIconText(icon)))
    return true
end

local function ShowMarkFrame(unit, icon)
    if not PrepareMark(unit, icon) then return end
    RA.StackPopupFrame(markFrame, { "RollAwayGreatVaultFrame", "RollAwayParagonFrame", "RollAwayReminderFrame" }, -340)
    markFrame:Show()
    DBG("[TankMarker] Offering marker " .. icon .. " for " .. unit)
end

-- Experiment (test mode, /rawtank auto): click the secure button from code,
-- without a popup. Never during a running Mythic+ key. The test log shows
-- whether the marker arrived and whether Blizzard blocked anything.
local function AutoMark(unit, icon)
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive() then
        return TestSay("Auto: a Mythic+ key is running, skipped.")
    end
    if not PrepareMark(unit, icon) then return TestSay("Auto: in combat, skipped.") end

    TestSay("Auto: clicking the button from code.")
    local ok, err = pcall(markFrame.markBtn.Click, markFrame.markBtn, "LeftButton",
        GetCVarBool("ActionButtonUseKeyDown") and true or false)
    if not ok then TestSay("Auto: Click() failed: " .. tostring(err)) end
end

------------------------------------------------------------------------
-- Logic
------------------------------------------------------------------------

-- Your own role: solo (or without a group role) the spec decides.
local function GetRole(unit)
    local role = UnitGroupRolesAssigned(unit)
    if role == "NONE" and unit == "player" then
        local spec = GetSpecialization()
        role = spec and GetSpecializationRole(spec) or role
    end
    return role
end

local function FindTank()
    if GetRole("player") == "TANK" then return "player" end
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        if GetRole(unit) == "TANK" then return unit end
    end
end

-- manual = true (/rawtank): ignores the setting, the instance check and the
-- "already offered" memory, and says why nothing is shown.
local function Check(manual)
    local db = RollAwayDB
    if not db or not (manual or testMode or db.tankMarkEnabled) then return end

    -- show: after /rawtank also tell the player (localized message)
    local function Skip(msg, show)
        if manual and show then RA.Print(msg) else TestSay(msg) end
    end

    local grouped = IsInGroup()
    if InCombatLockdown() then return Skip("In combat.") end
    if IsInRaid() then return Skip("Raid group: only 5-man groups are handled.") end
    if not grouped and not (manual or testMode) then return end

    if not manual then
        local _, instanceType = IsInInstance()
        if instanceType ~= "party" then
            return Skip("Not in a dungeon (instance type: " .. tostring(instanceType) .. ").")
        end
    end

    local unit = FindTank()
    if not unit then return Skip(RA_L["tankmark_none"], true) end

    local icon = db.tankMarkIcon
    if ReadMarker(unit) == icon then return Skip(RA_L["tankmark_already"], true) end

    if not manual then
        local key = UnitGUID(unit) .. ":" .. icon
        if key == lastOffer then return end
        lastOffer = key
    end
    if testMode and autoMode and not manual then
        TestSay("Tank is " .. unit .. ", marking automatically.")
        return AutoMark(unit, icon)
    end
    TestSay("Tank is " .. unit .. ", offering the popup.")
    ShowMarkFrame(unit, icon)
end

local function ScheduleCheck()
    if checkPending then return end
    checkPending = true
    C_Timer.After(CHECK_DELAY, function()
        checkPending = false
        Check()
    end)
end

-- Registers events only while the option (or the test mode) is on. Called at
-- load and whenever the option changes.
function RA.ApplyTankMarker()
    if not eventFrame then return end
    local on = testMode or (RollAwayDB and RollAwayDB.tankMarkEnabled)
    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
        if on then
            eventFrame:RegisterEvent(event)
        else
            eventFrame:UnregisterEvent(event)
        end
    end
    eventFrame:RegisterEvent("GROUP_LEFT")   -- always: keeps lastOffer honest
    -- Test mode: fires whenever any marker changes, readable value or not.
    -- Also Blizzard's taint blocks (the auto experiment), only for RollAway.
    for _, event in ipairs({ "RAID_TARGET_UPDATE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
        if testMode then
            eventFrame:RegisterEvent(event)
        else
            eventFrame:UnregisterEvent(event)
        end
    end
    if on then ScheduleCheck() end
end

local function SlashHandler(msg)
    local arg, value = strtrim(msg or ""):lower():match("^(%S*)%s*(%S*)$")
    if arg == "test" then
        testMode = not testMode
        lastOffer = nil
        DBG("[TankMarker] Test mode " .. (testMode and "ON" or "OFF"))
        RA.ApplyTankMarker()
    elseif arg == "auto" then
        autoMode = not autoMode
        lastOffer = nil
        DBG("[TankMarker] Auto mode " .. (autoMode and "ON (needs test mode)" or "OFF"))
        if testMode then ScheduleCheck() end
    elseif arg == "variant" and MACROS[tonumber(value)] then
        macroVariant = tonumber(value)
        lastOffer = nil
        DBG("[TankMarker] Macro variant " .. macroVariant)
    else
        Check(true)
    end
end

function RA.InitTankMarker()
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event, addonName, funcName)
        if event == "GROUP_LEFT" then
            lastOffer = nil
        elseif event == "RAID_TARGET_UPDATE" then
            TestSay("RAID_TARGET_UPDATE: a marker was set or changed.")
        elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
            if addonName == "RollAway" then
                TestSay(("%s: %s tried %s"):format(event, tostring(addonName), tostring(funcName)))
            end
        else
            ScheduleCheck()
        end
    end)
    RA.ApplyTankMarker()

    SLASH_RAWTANK1 = "/rawtank"
    SlashCmdList["RAWTANK"] = SlashHandler
end

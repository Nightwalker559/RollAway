-- RollAway - TankMarker.lua
-- Offers to put a raid marker (default: square) on the group's tank. Since
-- 12.0 SetRaidTarget is protected: addon code cannot call it, only a secure
-- button running the "/tm" macro command can. A secure button needs a real
-- click, so the addon shows a small popup with a "Mark" button instead of
-- marking by itself.
--
-- Settings: RollAwayDB.tankMarkEnabled / tankMarkIcon (1-8)
-- Only 5-man groups; the popup shows once per tank and marker per dungeon
-- visit, only in a Mythic dungeon of the current season (RA.ACTIVE_SEASON),
-- and never once a Mythic+ key is running (it belongs to entering).
--
-- /rawtank       shows the popup right now, in any place (everyone)
-- /rawtank test  dev chars only: toggles a test mode until /reload. Works solo
--                (your own spec role counts as tank) and writes to the debug
--                log why the popup did or did not show, and whether the
--                marker changed after the click (RAID_TARGET_UPDATE).
--
-- Tried and ruled out: clicking the button from code (Button:Click) to mark
-- without a popup. The click is insecure, so RunMacroText is blocked with
-- ADDON_ACTION_FORBIDDEN; only a real click works.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local TIMER_DURATION = 20
local CHECK_DELAY    = 1.5   -- roles / roster settle a moment after the event
local RECHECK_DELAY = 3
local MAX_RECHECKS    = 60  -- 3 minutes of waiting for the instance data / the tank

local markFrame
local eventFrame
local checkPending
local ScheduleCheck   -- defined below, Check() needs it for the re-check
local rechecks = 0  -- re-checks in a row (instance data not settled / tank not here yet)
local lastOffer   -- "guid:icon" already offered on this dungeon visit
local testMode    -- session only, see header

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

-- Marker onto the unit. Setting a marker the unit already has would take it
-- off again (SetRaidTarget toggles), and in an instance the current marker
-- cannot be read (secret value) - so the macro clears first (0), then sets:
-- the result is the same marker whatever was there before.
local function MacroFor(unit, icon)
    return ("/tm [@%s] 0\n/tm [@%s] %d"):format(unit, unit, icon)
end

-- What the group's markers look like right now, for the test log. In an
-- instance a marker's number is a secret value, but "no marker" reads as a
-- plain nil (seen in the log) - so: "none", "set" (hidden) or the number.
local function MarkerSummary()
    local parts = {}
    local units = { "player" }
    for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    for _, unit in ipairs(units) do
        local ok, index = pcall(GetRaidTargetIndex, unit)
        local state
        if not ok then
            state = "error"
        elseif issecretvalue and issecretvalue(index) then
            state = "set"
        else
            state = index and tostring(index) or "none"
        end
        parts[#parts + 1] = unit .. "=" .. state
    end
    return table.concat(parts, " ")
end

-- After the click (test mode only). The proof that the marker arrived is the
-- RAID_TARGET_UPDATE line from the event frame below.
local function LogClick(unit, icon)
    TestSay(("Click received: group %s, macro %q"):format(
        tostring(IsInGroup()), (MacroFor(unit, icon):gsub("\n", " | "))))
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
    markFrame.okayBtn:SetText(NO)  -- it is a yes/no question here: "Mark" or "No"

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
        if testMode then LogClick(markFrame.unit, markFrame.icon) end
        markFrame:Hide()
    end)
    if RA.SkinPopupButton then RA.SkinPopupButton(btn) end
    markFrame.markBtn = btn

    RA.SetupInstanceReminderLifecycle(markFrame, "tankMarkShown")
end

local function ShowMarkFrame(unit, icon)
    CreateMarkFrame()
    -- Attributes of a secure button can only change out of combat.
    if InCombatLockdown() then return end

    markFrame.unit, markFrame.icon = unit, icon
    markFrame.markBtn:SetAttribute("macrotext", MacroFor(unit, icon))
    markFrame.msg:SetText(RA_L["tankmark_msg"]:format(UnitName(unit), RA.RaidIconText(icon)))
    RA.StackPopupFrame(markFrame, { "RollAwayGreatVaultFrame", "RollAwayParagonFrame", "RollAwayReminderFrame" }, -340)
    markFrame:Show()
    DBG("[TankMarker] Offering marker " .. icon .. " for " .. unit)
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

-- Only a Mythic dungeon of the current season gets the offer. Returns why
-- not (for the test log), or nil when it fits; the second result is true when
-- the instance data has not settled yet (look again shortly).
local function NotWorthMarking()
    RA.UpdateInstanceCache()  -- right now, not the copy from the last zone event
    if RA.cachedInstanceType ~= "party" then
        return "Not in a dungeon (instance type: " .. tostring(RA.cachedInstanceType) .. ")."
    end
    -- Just after the loading screen the difficulty still reads 0 for a moment.
    if RA.cachedDiffID == 0 then
        return "Dungeon difficulty not known yet.", true
    end
    if not RA.MYTHIC_DUNGEON_DIFFICULTY_IDS[RA.cachedDiffID] then
        return "Dungeon is not Mythic (difficulty " .. tostring(RA.cachedDiffID) .. ")."
    end
    for _, dungeon in ipairs(RA.DUNGEONS[RA.ACTIVE_SEASON] or {}) do
        if dungeon.mapID == RA.cachedInstanceID then return nil end
    end
    return "Not a dungeon of the current season (instance " .. tostring(RA.cachedInstanceID) .. ")."
end

-- manual = true (/rawtank): ignores the setting, the instance check and the
-- "already offered" memory, and logs why nothing is shown (debug log).
local function Check(manual)
    local db = RollAwayDB
    if not db or not (manual or testMode or db.tankMarkEnabled) then return end

    local function Skip(msg)
        if manual then DBG("[TankMarker] " .. msg) else TestSay(msg) end
    end

    local grouped = IsInGroup()
    if InCombatLockdown() then return Skip("In combat.") end
    if IsInRaid() then return Skip("Raid group: only 5-man groups are handled.") end
    if not grouped and not (manual or testMode) then return end

    if not manual then
        -- The offer belongs to entering the dungeon, not to the key start.
        if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive() then
            return Skip("A Mythic+ key is running.")
        end
        local reason, settling = NotWorthMarking()
        if reason then
            if settling and rechecks < MAX_RECHECKS then
                rechecks = rechecks + 1
                ScheduleCheck(RECHECK_DELAY)
            end
            return Skip(reason)
        end
    end

    local unit = FindTank()
    if not unit then return Skip("No tank found in the group.") end

    -- The tank must be here too: still outside, offline or far away means
    -- the marker cannot be set (yet). Look again shortly, a while at most.
    local connected, visible = UnitIsConnected(unit), UnitIsVisible(unit)
    if not (connected and visible) then
        if not manual and rechecks < MAX_RECHECKS then
            rechecks = rechecks + 1
            ScheduleCheck(RECHECK_DELAY)
        end
        return Skip(("The tank (%s) is not here yet: connected=%s visible=%s, check %d/%d."):format(
            unit, tostring(connected), tostring(visible), rechecks, MAX_RECHECKS))
    end
    rechecks = 0

    local icon = db.tankMarkIcon

    if not manual then
        local key = UnitGUID(unit) .. ":" .. icon
        if key == lastOffer then return end
        lastOffer = key
    end
    TestSay("Tank is " .. unit .. ", offering the popup.")
    ShowMarkFrame(unit, icon)
end

function ScheduleCheck(delay)
    if checkPending then return end
    checkPending = true
    C_Timer.After(delay or CHECK_DELAY, function()
        checkPending = false
        Check()
    end)
end

-- Registers events only while the option (or the test mode) is on. Called at
-- load and whenever the option changes.
function RA.ApplyTankMarker()
    if not eventFrame then return end
    local on = testMode or (RollAwayDB and RollAwayDB.tankMarkEnabled)
    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do
        if on then
            eventFrame:RegisterEvent(event)
        else
            eventFrame:UnregisterEvent(event)
        end
    end
    eventFrame:RegisterEvent("GROUP_LEFT")   -- always: keeps lastOffer honest
    -- Test mode: fires whenever any marker changes, readable value or not.
    if testMode then
        eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
    else
        eventFrame:UnregisterEvent("RAID_TARGET_UPDATE")
    end
    if on then ScheduleCheck() end
end

local function SlashHandler(msg)
    if strtrim(msg or ""):lower() == "test" and RA.DEV_CHARS[UnitName("player")] then
        testMode = not testMode
        lastOffer = nil
        DBG("[TankMarker] Test mode " .. (testMode and "ON" or "OFF"))
        RA.ApplyTankMarker()
    else
        Check(true)
    end
end

function RA.InitTankMarker()
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "GROUP_LEFT" then
            lastOffer = nil
        elseif event == "RAID_TARGET_UPDATE" then
            TestSay("RAID_TARGET_UPDATE: " .. MarkerSummary())
        else
            -- Outside an instance = the last visit is over: the next dungeon
            -- (even with the same group) gets its own offer.
            if event == "PLAYER_ENTERING_WORLD" and not IsInInstance() then lastOffer = nil end
            rechecks = 0
            ScheduleCheck()
        end
    end)
    RA.ApplyTankMarker()

    SLASH_RAWTANK1 = "/rawtank"
    SlashCmdList["RAWTANK"] = SlashHandler
end

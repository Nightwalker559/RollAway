-- RollAway - TankMarker.lua
-- Offers to put a raid marker (default: square) on the group's tank. Since 12.0
-- SetRaidTarget is protected: only a secure button running the "/tm" macro can set
-- it, and it needs a real click, so a small popup with a "Mark" button is shown.
-- (Clicking the button from code does not work: RunMacroText is blocked.)
--
-- Settings: RollAwayDB.tankMarkEnabled / tankMarkIcon (1-8).
-- Only 5-man groups, once per tank and marker per dungeon visit, only in a Mythic
-- dungeon of the current season, never once a key is running (the popup closes when
-- it starts). Nothing is offered for a tank that already has a marker, and the popup
-- closes when the tank gets one (also set by others): RAID_TARGET_UPDATE, no addon
-- messages needed.
--
-- /rawtank       shows the popup now, anywhere
-- /rawtank test  dev chars: test mode until /reload; works solo (your spec role counts)
--                and logs why the popup did or did not show and whether the marker changed

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local TIMER_DURATION = 20
local CHECK_DELAY     = 1.5  -- roles / roster settle after the event
local RECHECK_DELAY   = 3
local MAX_RECHECKS    = 60   -- 3 minutes of waiting for the instance data / the tank

local markFrame
local eventFrame
local checkPending
local ScheduleCheck      -- defined below, Check() needs it for the re-check
local rechecks = 0       -- re-checks in a row (instance data not settled / tank not here yet)
local lastOffer          -- "guid:icon" already offered on this dungeon visit
local testMode           -- session only, see header

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

-- Marker onto the unit. SetRaidTarget toggles and the current marker is a secret value
-- in instances, so the macro clears (0) first, then sets.
local function MacroFor(unit, icon)
    return ("/tm [@%s] 0\n/tm [@%s] %d"):format(unit, unit, icon)
end

-- Does the unit carry any marker? In instances the number is secret but "none" is
-- nil, so anything but nil counts as marked.
local function HasMarker(unit)
    local ok, index = pcall(GetRaidTargetIndex, unit)
    if not ok then return false end
    if issecretvalue and issecretvalue(index) then return true end  -- set, number hidden
    return index ~= nil
end

-- The group's markers for the test log: "none", "set" (hidden) or the number.
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

-- After the click (test mode); the proof is the RAID_TARGET_UPDATE line below.
local function LogClick(unit, icon)
    TestSay(("Click received: group %s, macro %q"):format(
        tostring(IsInGroup()), (MacroFor(unit, icon):gsub("\n", " | "))))
end

-- The popup holds a secure button: closed through RA.SafeSetShown (deferred in combat).
local function ClosePopup(frame)
    RA.SafeSetShown(frame, false)
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
        hide      = ClosePopup,
        fitHeight = function(self)
            return RA.POPUP_CHROME_HEIGHT + self.msg:GetStringHeight() + 10
        end,
    })

    markFrame.msg = RA.CreatePopupBodyText(markFrame)
    markFrame.okayBtn:SetText(NO)  -- it is a yes/no question here: "Mark" or "No"

    -- The macro runs on the click; PostClick closes the popup. Registered for both
    -- phases: the button only fires in the one matching "ActionButtonUseKeyDown".
    local btn = CreateFrame("Button", "RollAwayTankMarkBtn", markFrame, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetPoint("RIGHT", markFrame.okayBtn, "LEFT", -6, 0)
    btn:SetText(RA_L["tankmark_button"])
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "macro")
    btn:SetScript("PostClick", function(_, _, down)
        -- Only the phase that ran the macro closes.
        if (down and true or false) ~= (GetCVarBool("ActionButtonUseKeyDown") and true or false) then return end
        if testMode then LogClick(markFrame.unit, markFrame.icon) end
        ClosePopup(markFrame)
    end)
    RA.Skin.Button(btn)
    markFrame.markBtn = btn

    -- Closes on a pull, on leaving the group and when the key starts.
    markFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    markFrame:RegisterEvent("GROUP_LEFT")
    markFrame:RegisterEvent("CHALLENGE_MODE_START")
    markFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" or event == "GROUP_LEFT" or event == "CHALLENGE_MODE_START" then
            ClosePopup(self)
        end
    end)
end

local function ShowMarkFrame(unit, icon)
    CreateMarkFrame()
    -- Secure attributes only change out of combat.
    if InCombatLockdown() then return end

    markFrame.unit, markFrame.icon = unit, icon
    markFrame.markBtn:SetAttribute("macrotext", MacroFor(unit, icon))
    markFrame.msg:SetText(RA_L["tankmark_msg"]:format(UnitName(unit), RA.RaidIconText(icon)))
    RA.StackPopupFrame(markFrame)
    markFrame:Show()
    DBG("[TankMarker] Offering marker " .. icon .. " for " .. unit)
end

------------------------------------------------------------------------
-- Logic
------------------------------------------------------------------------

-- Your own role: without a group role the spec decides.
local function GetRole(unit)
    local role = UnitGroupRolesAssigned(unit)
    if role == "NONE" and unit == "player" then
        local spec = C_SpecializationInfo.GetSpecialization()
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

-- Only a Mythic dungeon of the current season gets the offer. Returns why not (test
-- log) or nil; the second result is true while the instance data has not settled.
local function NotWorthMarking()
    RA.UpdateInstanceCache()  -- current, not the last zone event's copy
    if RA.cachedInstanceType ~= "party" then
        return "Not in a dungeon (instance type: " .. tostring(RA.cachedInstanceType) .. ")."
    end
    -- Right after the loading screen the difficulty reads 0.
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

-- manual = true (/rawtank): ignores the setting, the instance check and the memory.
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
        -- The offer belongs to entering, not to the key start.
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

    -- The tank is already marked.
    if not manual and HasMarker(unit) then return Skip("The tank already has a marker.") end

    -- The tank must be here: outside, offline or far away cannot be marked (yet); look again.
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
        local guid = UnitGUID(unit)
        local key = (RA.IsAccessible(guid) and guid or unit) .. ":" .. icon
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

-- Events only while the option (or test mode) is on; at load and on option change.
function RA.ApplyTankMarker()
    if not eventFrame then return end
    local on = testMode or (RollAwayDB and RollAwayDB.tankMarkEnabled)
    -- RAID_TARGET_UPDATE: closes the popup once the tank is marked; feeds the test log.
    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "RAID_TARGET_UPDATE" }) do
        if on then
            eventFrame:RegisterEvent(event)
        else
            eventFrame:UnregisterEvent(event)
        end
    end
    eventFrame:RegisterEvent("GROUP_LEFT")   -- always: keeps lastOffer honest
    if on then ScheduleCheck() end
end

-- Test mode (dev chars), also used by the Developer settings.
function RA.IsTankMarkerTest()
    return testMode and true or false
end

function RA.SetTankMarkerTest(on)
    testMode = on and true or false
    lastOffer = nil
    DBG("[TankMarker] Test mode " .. (testMode and "ON" or "OFF"))
    RA.ApplyTankMarker()
end

local function SlashHandler(msg)
    if strtrim(msg or ""):lower() == "test" and RA.DEV_CHARS[UnitName("player")] then
        RA.SetTankMarkerTest(not testMode)
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
            if testMode then TestSay("RAID_TARGET_UPDATE: " .. MarkerSummary()) end
            if markFrame and markFrame:IsShown() and markFrame.unit and HasMarker(markFrame.unit) then
                DBG("[TankMarker] The tank got a marker – closing the popup")
                ClosePopup(markFrame)
            end
        else
            -- Outside an instance: the next dungeon gets its own offer.
            if event == "PLAYER_ENTERING_WORLD" and not IsInInstance() then lastOffer = nil end
            rechecks = 0
            ScheduleCheck()
        end
    end)
    RA.ApplyTankMarker()

    SLASH_RAWTANK1 = "/rawtank"
    SlashCmdList["RAWTANK"] = SlashHandler
end

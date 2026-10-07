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
--                  spec role counts as tank), prints in chat why the popup
--                  did or did not show, and whether the marker was set after
--                  the click.

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

-- Inline texture of raid marker `index`, for popup text and the options list.
function RA.RaidIconText(index)
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:16|t"):format(index)
end

-- Test-mode output only.
local function TestSay(msg)
    if testMode then RA.Print("|cffD4AF37[Tank marker test]|r " .. msg) end
end

------------------------------------------------------------------------
-- Popup with the secure "Mark" button
------------------------------------------------------------------------

-- After the click: did the marker really arrive? (test mode only)
local function VerifyMarker(unit, icon)
    C_Timer.After(0.5, function()
        local now = GetRaidTargetIndex(unit)
        if now == icon then
            TestSay("|cff00ff00Marker set.|r The click works here.")
        else
            TestSay("|cffff4040Marker NOT set|r (unit " .. unit .. " has marker " .. tostring(now) .. ").")
        end
    end)
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
    -- Up-only: a second run on key-down would toggle the marker off again.
    local btn = CreateFrame("Button", "RollAwayTankMarkBtn", markFrame, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetPoint("RIGHT", markFrame.okayBtn, "LEFT", -6, 0)
    btn:SetText(RA_L["tankmark_button"])
    btn:RegisterForClicks("AnyUp")
    btn:SetAttribute("type", "macro")
    btn:SetScript("PostClick", function()
        if testMode then VerifyMarker(markFrame.unit, markFrame.icon) end
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
    markFrame.markBtn:SetAttribute("macrotext", ("/tm [@%s] %d"):format(unit, icon))
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

-- manual = true (/rawtank): ignores the setting, the instance check and the
-- "already offered" memory, and says why nothing is shown.
local function Check(manual)
    local db = RollAwayDB
    if not db or not (manual or testMode or db.tankMarkEnabled) then return end

    local function Skip(msg)
        if manual then RA.Print(msg) else TestSay(msg) end
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
    if not unit then return Skip(RA_L["tankmark_none"]) end

    local icon = db.tankMarkIcon
    if GetRaidTargetIndex(unit) == icon then return Skip(RA_L["tankmark_already"]) end

    if not manual then
        local key = UnitGUID(unit) .. ":" .. icon
        if key == lastOffer then return end
        lastOffer = key
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
    if on then ScheduleCheck() end
end

local function SlashHandler(msg)
    if strtrim(msg or ""):lower() == "test" then
        testMode = not testMode
        lastOffer = nil
        RA.Print("Tank marker test mode " .. (testMode and "|cff00ff00ON|r" or "|cffff4040OFF|r")
            .. (testMode and ": enter a dungeon (also solo), the result is printed here." or "."))
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
        else
            ScheduleCheck()
        end
    end)
    RA.ApplyTankMarker()

    SLASH_RAWTANK1 = "/rawtank"
    SlashCmdList["RAWTANK"] = SlashHandler
end

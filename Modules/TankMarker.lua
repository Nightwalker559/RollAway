-- RollAway - TankMarker.lua
-- Offers to put a raid marker (default: square) on the group's tank. Since
-- 12.0 SetRaidTarget is protected: addon code cannot call it, only a secure
-- button running the "/tm" macro command can. A secure button needs a real
-- click, so the addon shows a small popup with a "Mark" button instead of
-- marking by itself.
--
-- Settings: RollAwayDB.tankMarkEnabled / tankMarkIcon (1-8)
-- Only 5-man groups; the popup shows once per tank and marker per group, and
-- only in a dungeon (instance type "party") unless started with /rawtank.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local TIMER_DURATION = 20
local CHECK_DELAY    = 1.5   -- roles / roster settle a moment after the event

local markFrame
local eventFrame
local checkPending
local lastOffer   -- "guid:icon" already offered in this group

-- Inline texture of raid marker `index`, for popup text and the options list.
function RA.RaidIconText(index)
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:16|t"):format(index)
end

------------------------------------------------------------------------
-- Popup with the secure "Mark" button
------------------------------------------------------------------------

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
    local btn = CreateFrame("Button", "RollAwayTankMarkBtn", markFrame, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetPoint("RIGHT", markFrame.okayBtn, "LEFT", -6, 0)
    btn:SetText(RA_L["tankmark_button"])
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "macro")
    btn:SetScript("PostClick", function() markFrame:Hide() end)
    if RA.SkinPopupButton then RA.SkinPopupButton(btn) end
    markFrame.markBtn = btn

    RA.SetupInstanceReminderLifecycle(markFrame, "tankMarkShown")
end

local function ShowMarkFrame(unit, icon)
    CreateMarkFrame()
    -- Attributes of a secure button can only change out of combat.
    if InCombatLockdown() then return end

    markFrame.markBtn:SetAttribute("macrotext", ("/tm [@%s] %d"):format(unit, icon))
    markFrame.msg:SetText(RA_L["tankmark_msg"]:format(UnitName(unit), RA.RaidIconText(icon)))
    RA.StackPopupFrame(markFrame, { "RollAwayGreatVaultFrame", "RollAwayParagonFrame", "RollAwayReminderFrame" }, -340)
    markFrame:Show()
    DBG("[TankMarker] Offering marker " .. icon .. " for " .. unit)
end

------------------------------------------------------------------------
-- Logic
------------------------------------------------------------------------

local function FindTank()
    if UnitGroupRolesAssigned("player") == "TANK" then return "player" end
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        if UnitGroupRolesAssigned(unit) == "TANK" then return unit end
    end
end

-- manual = true (/rawtank): ignores the setting, the instance check and the
-- "already offered" memory, and says why nothing is shown.
local function Check(manual)
    local db = RollAwayDB
    if not db or not (manual or db.tankMarkEnabled) then return end
    if InCombatLockdown() or not IsInGroup() or IsInRaid() then return end
    if not manual then
        local _, instanceType = IsInInstance()
        if instanceType ~= "party" then return end
    end

    local unit = FindTank()
    if not unit then
        if manual then RA.Print(RA_L["tankmark_none"]) end
        return
    end

    local icon = db.tankMarkIcon
    if GetRaidTargetIndex(unit) == icon then
        if manual then RA.Print(RA_L["tankmark_already"]) end
        return
    end

    local key = UnitGUID(unit) .. ":" .. icon
    if not manual then
        if key == lastOffer then return end
        lastOffer = key
    end
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

-- Registers events only while the option is on. Called at load and whenever
-- the option changes.
function RA.ApplyTankMarker()
    if not eventFrame then return end
    local on = RollAwayDB and RollAwayDB.tankMarkEnabled
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
    SlashCmdList["RAWTANK"] = function() Check(true) end
end

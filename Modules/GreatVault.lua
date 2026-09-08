-- RollAway - GreatVault.lua
-- Popup reminder when unclaimed Great Vault rewards are available.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local C_Timer_After = RA.C_Timer_After

local TIMER_DURATION = 30

------------------------------------------------------------------------
-- Frame (mirrors Reminder.lua / Paragon.lua layout)
------------------------------------------------------------------------

local vaultFrame
local vaultTimer  -- RA.CreateTimerBar handle (Start/Stop), set in CreateVaultFrame

local function CreateVaultFrame()
    if vaultFrame then return end

    vaultFrame = RA.CreatePopupFrame({
        name     = "RollAwayGreatVaultFrame",
        okayName = "RollAwayGreatVaultOkay",
        width    = 300,
        height   = 110,
        yOffset  = -260,
    })
    vaultTimer = vaultFrame.timer

    -- Message text
    vaultFrame.msg = vaultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    vaultFrame.msg:SetPoint("TOPLEFT",  vaultFrame, "TOPLEFT",  10, -40)
    vaultFrame.msg:SetPoint("TOPRIGHT", vaultFrame, "TOPRIGHT", -10, -40)
    vaultFrame.msg:SetJustifyH("LEFT")
    vaultFrame.msg:SetNonSpaceWrap(true)

    vaultFrame:SetScript("OnShow", function(self)
        if C_Timer_After then
            C_Timer_After(0, function()
                if not self:IsShown() then return end
                local msgH = self.msg:GetStringHeight()
                -- top(10) + header(24) + gap(6) + msg + gap(10) + btn(22) + bar(8) + pad(18)
                self:SetHeight(math.max(110, 10 + 24 + 6 + msgH + 10 + 22 + 8 + 18))
            end)
        end
        vaultTimer.Start(TIMER_DURATION)
    end)

    vaultFrame:SetScript("OnHide", vaultTimer.Stop)
end

------------------------------------------------------------------------
-- Logic
------------------------------------------------------------------------

function RA.ShowGreatVaultFrame()
    CreateVaultFrame()

    -- Stack below Reminder/Paragon frames if shown, to avoid overlap.
    vaultFrame:ClearAllPoints()
    local paragonFrame  = _G["RollAwayParagonFrame"]
    local reminderFrame = _G["RollAwayReminderFrame"]
    if paragonFrame and paragonFrame:IsShown() then
        vaultFrame:SetPoint("TOP", paragonFrame, "BOTTOM", 0, -10)
    elseif reminderFrame and reminderFrame:IsShown() then
        vaultFrame:SetPoint("TOP", reminderFrame, "BOTTOM", 0, -10)
    else
        vaultFrame:SetPoint("TOP", UIParent, "TOP", 0, -260)
    end

    vaultFrame.msg:SetText(RA_L["greatvault_alert_msg"])
    vaultFrame:Show()
    DBG("[GreatVault] Showing frame")
end

-- Returns true if the player currently has an unclaimed Great Vault reward.
local function HasUnclaimedRewards()
    if not (C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards) then return false end
    local ok, result = pcall(C_WeeklyRewards.HasAvailableRewards)
    return ok and result or false
end

-- Weekly reward period ID, used so the reminder only re-shows once per new
-- reset instead of every login within the same week.
local function GetRewardPeriod()
    if GetServerWeeklyResetTimeRemaining then
        local remaining = GetServerWeeklyResetTimeRemaining()
        if remaining then
            return math.floor((time() + remaining) / 604800)
        end
    end
    return nil
end

local function CheckAndShow()
    if not (RollAwayDB and RollAwayDB.greatVaultAlert) then return end
    if RA.vaultAlertShownThisSession then return end  -- already shown/handled this session
    if not HasUnclaimedRewards() then return end

    local period = GetRewardPeriod()
    if period and RollAwayDB.lastVaultAlertPeriod == period then return end

    RollAwayDB.lastVaultAlertPeriod   = period
    RA.vaultAlertShownThisSession = true
    RA.ShowGreatVaultFrame()
end

-- Manual check: always runs regardless of the greatVaultAlert setting.
local function ManualCheck()
    if HasUnclaimedRewards() then
        RA.ShowGreatVaultFrame()
    else
        print("|cff33ff99RollAway:|r " .. RA_L["greatvault_none"])
    end
end

------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------

function RA.InitGreatVault()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("WEEKLY_REWARDS_UPDATE")

    f:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_ENTERING_WORLD" then
            -- arg1 = isInitialLogin, arg2 = isReloadingUi.
            -- Only fire on actual login, never on /reload or zoning.
            if not arg1 then return end

            -- Delay so weekly rewards data is populated before checking.
            -- WEEKLY_REWARDS_UPDATE below acts as a retry if data still
            -- isn't ready by then.
            if C_Timer_After then
                C_Timer_After(3, CheckAndShow)
            else
                CheckAndShow()
            end

        elseif event == "WEEKLY_REWARDS_UPDATE" then
            -- Kept registered for the whole session: retries the login check
            -- if data wasn't ready yet, AND fires again when a reward is
            -- claimed. CheckAndShow()'s session flag makes sure we only ever
            -- actually pop the reminder once per session either way.
            CheckAndShow()
        end
    end)

    -- /rawvault – manual check, available to all users
    SLASH_RAWGREATVAULT1 = "/rawvault"
    SlashCmdList["RAWGREATVAULT"] = ManualCheck

    DBG("[GreatVault] Initialized")
end

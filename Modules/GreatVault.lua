-- RollAway - GreatVault.lua
-- Popup reminder when unclaimed Great Vault rewards are available.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local TIMER_DURATION = 30

------------------------------------------------------------------------
-- Frame (mirrors Reminder.lua / Paragon.lua layout)
------------------------------------------------------------------------

local vaultFrame

local function CreateVaultFrame()
    if vaultFrame then return end

    vaultFrame = RA.CreatePopupFrame({
        name     = "RollAwayGreatVaultFrame",
        okayName = "RollAwayGreatVaultOkay",
        width    = 300,
        height   = 110,
        yOffset  = -260,
        duration = TIMER_DURATION,
        fitHeight = function(self)
            return RA.POPUP_CHROME_HEIGHT + self.msg:GetStringHeight() + 10
        end,
    })

    vaultFrame.msg = RA.CreatePopupBodyText(vaultFrame)
end

------------------------------------------------------------------------
-- Logic
------------------------------------------------------------------------

function RA.ShowGreatVaultFrame()
    CreateVaultFrame()

    -- Stack below Reminder/Paragon frames if shown, to avoid overlap.
    RA.StackPopupFrame(vaultFrame, { "RollAwayParagonFrame", "RollAwayReminderFrame" }, -260)

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
    local remaining = GetServerWeeklyResetTimeRemaining and GetServerWeeklyResetTimeRemaining()
    if remaining then
        return math.floor((time() + remaining) / 604800)
    end
end

local function CheckAndShow()
    if not (RollAwayDB and RollAwayDB.greatVaultAlert) then return end
    if not RA.IsMaxLevel() then return end  -- no Great Vault rewards below max level
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
        RA.Print(RA_L["greatvault_none"])
    end
end

------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------

function RA.InitGreatVault()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("WEEKLY_REWARDS_UPDATE")

    f:SetScript("OnEvent", function(_, event, isInitialLogin)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Only fire on actual login, never on /reload or zoning.
            if not isInitialLogin then return end

            -- Delay so weekly rewards data is populated before checking.
            -- WEEKLY_REWARDS_UPDATE below acts as a retry if data still
            -- isn't ready by then.
            C_Timer.After(3, CheckAndShow)

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

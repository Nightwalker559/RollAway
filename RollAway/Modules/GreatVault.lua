-- RollAway - GreatVault.lua
-- Popup reminder when unclaimed Great Vault rewards are available.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local TIMER_DURATION = 30

-- Frame (like Reminder.lua / Paragon.lua)

local vaultFrame

local function CreateVaultFrame()
    if vaultFrame then return end

    vaultFrame = RA.CreatePopupFrame({
        name     = "RollAwayGreatVaultFrame",
        title    = RA_L["popup_title_vault"],
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

-- Logic

function RA.ShowGreatVaultFrame()
    CreateVaultFrame()

    -- Stacked with the other popups.
    RA.StackPopupFrame(vaultFrame)

    vaultFrame.msg:SetText(RA_L["greatvault_alert_msg"])
    vaultFrame:Show()
    DBG("[GreatVault] Showing frame")
end

-- Does the player have an unclaimed Great Vault reward?
local function HasUnclaimedRewards()
    if not (C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards) then return false end
    local ok, result = pcall(C_WeeklyRewards.HasAvailableRewards)
    return ok and result or false
end

-- Shows on every login (once per session) until the vault is emptied.
local function CheckAndShow()
    if not (RollAwayDB and RollAwayDB.greatVaultAlert) then return end
    if not RA.IsMaxLevel() then return end  -- no Great Vault rewards below max level
    if RA.vaultAlertShownThisSession then return end  -- already handled this session
    if not HasUnclaimedRewards() then return end

    RA.vaultAlertShownThisSession = true
    RA.ShowGreatVaultFrame()
end

-- The vault was opened (or changed): the reminder has done its job for this session,
-- so it hides and stays away until the next login.
local function VaultHandled()
    RA.vaultAlertShownThisSession = true
    if vaultFrame and vaultFrame:IsShown() then vaultFrame:Hide() end
end

-- Manual check, independent of the greatVaultAlert setting.
local function ManualCheck()
    if HasUnclaimedRewards() then
        RA.ShowGreatVaultFrame()
    else
        RA.Print(RA_L["greatvault_none"])
    end
end

-- Initialization

function RA.InitGreatVault()
    -- Login window: WEEKLY_REWARDS_UPDATE retries the check while the data loads. After
    -- it, the event means the vault was opened or claimed from.
    local loginWindow = false

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")

    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Only on a real login (arg1 = isInitialLogin).
            if not arg1 then return end

            -- Next frame, with a 3s fallback in case the weekly rewards data isn't
            -- there yet (the session flag in CheckAndShow() prevents a double show).
            loginWindow = true
            RunNextFrame(CheckAndShow)
            C_Timer.After(3, CheckAndShow)
            C_Timer.After(10, function() loginWindow = false end)

        elseif event == "WEEKLY_REWARDS_UPDATE" then
            if loginWindow then
                CheckAndShow()
            else
                VaultHandled()
            end

        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local wr = Enum.PlayerInteractionType and Enum.PlayerInteractionType.WeeklyRewards
            if wr and arg1 == wr then VaultHandled() end
        end
    end)

    -- /rawvault: manual check, for everyone
    SLASH_RAWGREATVAULT1 = "/rawvault"
    SlashCmdList["RAWGREATVAULT"] = ManualCheck

    DBG("[GreatVault] Initialized")
end

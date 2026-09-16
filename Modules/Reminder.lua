-- RollAway - Reminder.lua
-- Popup reminder when entering Mythic dungeons or raids (Season 1 & 2).

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local DUNGEON_MAP = RA.DUNGEON_MAP

local VOIDCORE_CURRENCY_ID = RA.VOIDCORE_CURRENCY_ID
local VOIDCORE_COST = { dungeons = 1, raids = 2 }

-- Raid instance mapIDs (= instanceID from GetInstanceInfo) that qualify for the reminder.
local REMINDER_RAID_MAP_IDS = {
    [2912] = true,  -- The Voidspire (S1)
    [2939] = true,  -- The Dreamrift (S1)
    [2913] = true,  -- March on Quel'Danas (S1)
    [1592] = true,  -- Sporefall (12.0.7, S1)
    [3004] = true,  -- The Venomous Abyss (S2)
}

-- Dungeon difficulty IDs that qualify for the reminder.
local MYTHIC_DIFFICULTY_IDS = {
    [8]  = true,  -- Mythic
    [23] = true,  -- Mythic Keystone (M+)
}

local TIMER_DURATION = 20

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

local reminderFrame
local reminderTimer  -- RA.CreateTimerBar handle (Start/Stop), set in CreateReminderFrame
local currentTabKey  = nil  -- stored so OnClick closure is created only once

------------------------------------------------------------------------
-- Frame creation (once, reused on every show)
------------------------------------------------------------------------

local function CreateReminderFrame()
    if reminderFrame then return end

    reminderFrame = RA.CreatePopupFrame({
        name     = "RollAwayReminderFrame",
        okayName = "RollAwayReminderOkay",
        width    = 300,
        height   = 130,
        yOffset  = -180,
    })
    reminderTimer = reminderFrame.timer

    -- Message text
    reminderFrame.msg = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    reminderFrame.msg:SetPoint("TOPLEFT",  reminderFrame, "TOPLEFT",  10, -40)
    reminderFrame.msg:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", -10, -40)
    reminderFrame.msg:SetJustifyH("LEFT")
    reminderFrame.msg:SetNonSpaceWrap(true)

    -- Separator between message and currency line
    reminderFrame.sep = reminderFrame:CreateTexture(nil, "ARTWORK")
    reminderFrame.sep:SetHeight(1)
    reminderFrame.sep:SetPoint("TOPLEFT",  reminderFrame.msg, "BOTTOMLEFT",  0, -10)
    reminderFrame.sep:SetPoint("TOPRIGHT", reminderFrame.msg, "BOTTOMRIGHT", 0, -10)
    reminderFrame.sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Currency / rolls available line
    reminderFrame.currency = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    reminderFrame.currency:SetPoint("TOPLEFT",  reminderFrame.sep, "BOTTOMLEFT",  0, -10)
    reminderFrame.currency:SetPoint("TOPRIGHT", reminderFrame.sep, "BOTTOMRIGHT", 0, -10)
    reminderFrame.currency:SetJustifyH("LEFT")

    -- Open options button (left of the factory's Okay button)
    reminderFrame.btn = CreateFrame("Button", "RollAwayReminderBtn", reminderFrame, "UIPanelButtonTemplate")
    reminderFrame.btn:SetSize(130, 22)
    reminderFrame.btn:SetPoint("RIGHT", reminderFrame.okayBtn, "LEFT", -6, 0)
    reminderFrame.btn:SetScript("OnClick", function()
        reminderFrame:Hide()
        if RA.OpenOptionsTab and currentTabKey then
            RA.OpenOptionsTab(currentTabKey)
        end
    end)
    if RA.SkinPopupButton then RA.SkinPopupButton(reminderFrame.btn) end

    -- OnShow: resize to fit text content, then start countdown timer
    reminderFrame:SetScript("OnShow", function(self)
        if RA.C_Timer_After then
            RA.C_Timer_After(0, function()
                if not self:IsShown() then return end
                local msgH      = self.msg:GetStringHeight()
                local currencyH = self.currency:GetStringHeight()
                -- top(10) + header(24) + gap(6) + msg + sep(1+20) + currency + gap(8) + btn(22) + bar(8) + pad(18)
                self:SetHeight(math.max(130, 10 + 24 + 6 + msgH + 21 + currencyH + 8 + 22 + 8 + 18))
            end)
        end
        reminderTimer.Start(TIMER_DURATION)
    end)

    reminderFrame:SetScript("OnHide", reminderTimer.Stop)

    RA.SetupInstanceReminderLifecycle(reminderFrame, "lastReminderInstID")
end

------------------------------------------------------------------------
-- Show reminder for current content
------------------------------------------------------------------------

function RA.ShowReminder()
    if not RollAwayDB or not RollAwayDB.showReminder then return end
    if not RA.BONUS_ROLLS_ENABLED then return end

    local instanceType = RA.cachedInstanceType
    local instanceID   = RA.cachedInstanceID

    -- Hide if not in supported dungeon/raid content
    if not (instanceType == "party" or instanceType == "raid") then
        if reminderFrame and reminderFrame:IsShown() then reminderFrame:Hide() end
        return
    end

    -- Only show once per instance (persists through /reload, resets on GROUP_LEFT)
    if RollAwayDB.lastReminderInstID == instanceID then return end

    local tabKey, msgKey

    if instanceType == "party" and DUNGEON_MAP[instanceID] then
        -- Dungeons: Mythic and Mythic+ only – use cached diffID
        if not MYTHIC_DIFFICULTY_IDS[RA.cachedDiffID] then
            DBG("Reminder: dungeon not Mythic (diffID:", RA.cachedDiffID, ") – skipping")
            return
        end
        tabKey = "dungeons"
        msgKey = "reminder_dungeon"

    elseif instanceType == "raid" and REMINDER_RAID_MAP_IDS[instanceID] then
        tabKey = "raids"
        msgKey = "reminder_raid"
    end

    if not tabKey then return end

    -- Skip if player has no Voidcores
    local voidcoreInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(VOIDCORE_CURRENCY_ID)
    local voidcoreQty  = voidcoreInfo and voidcoreInfo.quantity or 0
    if voidcoreQty == 0 then
        DBG("Reminder: no Voidcores – skipping")
        return
    end

    local rollsPossible = math.floor(voidcoreQty / VOIDCORE_COST[tabKey])
    local rollColor     = rollsPossible > 1 and "|cff00cc00" or "|cffffff00"

    RollAwayDB.lastReminderInstID = instanceID
    DBG("Showing reminder | tabKey:", tabKey, "| instanceID:", instanceID,
        "| Voidcores:", voidcoreQty, "| rolls:", rollsPossible)

    CreateReminderFrame()

    -- Stack below the Paragon frame if it's currently shown, to avoid
    -- both notifications overlapping at the same default position.
    RA.StackPopupFrame(reminderFrame, { "RollAwayParagonFrame" }, -180)

    -- Update content (no new closures created here)
    currentTabKey = tabKey
    reminderFrame.msg:SetText(RA_L[msgKey])
    reminderFrame.btn:SetText(RA_L["reminder_btn_"..tabKey])
    reminderFrame.currency:SetText(string.format(
        RA_L["reminder_voidcore"],
        voidcoreQty,
        rollColor .. rollsPossible .. "|r",
        rollsPossible == 1 and RA_L["reminder_roll_singular"] or RA_L["reminder_roll_plural"]))

    reminderFrame:Show()
end

------------------------------------------------------------------------
-- Initialization – called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitReminder()
    DBG("Reminder initialized")
end

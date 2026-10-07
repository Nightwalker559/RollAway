-- RollAway - Reminder.lua
-- Popup reminder when entering Mythic dungeons or raids (Season 1 & 2).

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local DUNGEON_MAP = RA.DUNGEON_MAP

local VOIDCORE_COST = { dungeons = 1, raids = 2 }

-- Raid instance mapIDs (= instanceID from GetInstanceInfo) that qualify for the
-- reminder, mapped to the raid key used in Data\Raids.lua.
local REMINDER_RAID_MAP_IDS = {
    [2912] = "voidspire",        -- The Voidspire (S1)
    [2939] = "dreamrift",        -- The Dreamrift (S1)
    [2913] = "march_queldanas",  -- March on Quel'Danas (S1)
    [1592] = "sporefall",        -- Sporefall (12.0.7, S1)
    [3004] = "venomous_abyss",   -- The Venomous Abyss (S2)
}

local TIMER_DURATION = 20

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

local reminderFrame
local currentTabKey  -- stored so OnClick closure is created only once

------------------------------------------------------------------------
-- Auto-pass status for the current instance - what this character has set,
-- so a forgotten checkbox (or one carried over from another setup) is seen
-- before the first boss. Mirrors the matching in Modules\AutoPass.lua.
------------------------------------------------------------------------

local COLOR_ACTIVE = "|cffff5050"
local COLOR_NONE   = "|cff00cc00"

-- Returns the status text and whether any auto-pass is active here.
local function BuildAutoPassStatus(tabKey, instanceID)
    local char = RollAwayDBChar
    if not char then return nil, false end
    local lines = {}

    if tabKey == "dungeons" then
        local key = DUNGEON_MAP[instanceID]
        if char.dungeonAutoPassAll then
            lines[1] = COLOR_ACTIVE .. RA_L["reminder_ap_dungeon_all"] .. "|r"
        elseif key and (char.dungeons[key] or char.dungeons_s2[key]) then
            lines[1] = COLOR_ACTIVE .. RA_L["reminder_ap_dungeon"] .. "|r"
        end
    else
        local bucket = RA.RAID_DIFFICULTY_BUCKET[RA.cachedDiffID]
        local diffActive = bucket and char.raidAutoPassDifficulty[bucket]
        if diffActive then
            lines[#lines + 1] = COLOR_ACTIVE
                .. string.format(RA_L["reminder_ap_difficulty"], RA_L["raid_diff_" .. bucket]) .. "|r"
        end
        -- Individually checked bosses of this raid (redundant when the whole
        -- difficulty is already on).
        if not diffActive then
            local raidKey, names = REMINDER_RAID_MAP_IDS[instanceID], {}
            for _, bosses in pairs(RA.RAIDS) do
                for _, b in ipairs(bosses) do
                    if b.raid == raidKey and char.raids[b.key] then
                        names[#names + 1] = RA_L["boss_" .. b.key] or b.key
                    end
                end
            end
            if #names > 0 then
                lines[#lines + 1] = COLOR_ACTIVE
                    .. string.format(RA_L["reminder_ap_bosses"], table.concat(names, ", ")) .. "|r"
            end
        end
    end

    if #lines == 0 then
        return COLOR_NONE .. RA_L["reminder_ap_none"] .. "|r", false
    end
    return table.concat(lines, "\n"), true
end

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
        duration = TIMER_DURATION,
        fitHeight = function(self)
            -- Warning-only popup: just the status text as the message.
            if self.warnOnly then
                return RA.POPUP_CHROME_HEIGHT + self.msg:GetStringHeight() + 8
            end
            -- message + separator(1+20) + currency line + status (+6 gap)
            -- + gap before the button
            local statusH = self.status:GetText() ~= "" and (6 + self.status:GetStringHeight()) or 0
            return RA.POPUP_CHROME_HEIGHT + self.msg:GetStringHeight() + 21
                + self.currency:GetStringHeight() + statusH + 8
        end,
    })

    -- Message text
    reminderFrame.msg = RA.CreatePopupBodyText(reminderFrame)

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

    -- Auto-pass status line(s) (see BuildAutoPassStatus)
    reminderFrame.status = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    reminderFrame.status:SetPoint("TOPLEFT",  reminderFrame.currency, "BOTTOMLEFT",  0, -6)
    reminderFrame.status:SetPoint("TOPRIGHT", reminderFrame.currency, "BOTTOMRIGHT", 0, -6)
    reminderFrame.status:SetJustifyH("LEFT")

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

    RA.SetupInstanceReminderLifecycle(reminderFrame, "lastReminderInstID")
end

------------------------------------------------------------------------
-- Show reminder for current content
------------------------------------------------------------------------

-- Shown when "showReminder" is on, or - independent of it - when the
-- "autoPassWarning" safety net is on and an auto-pass is active for this
-- instance (so a forgotten checkbox does not cost a bonus roll).
function RA.ShowReminder()
    if not RollAwayDB or not RollAwayDBChar then return end

    local instanceType = RA.cachedInstanceType
    local instanceID   = RA.cachedInstanceID

    -- Outside dungeon/raid content: hide, and forget the "already shown"
    -- mark so the next entry (even into the same instance, with the same
    -- group) shows the reminder again.
    if not (instanceType == "party" or instanceType == "raid") then
        RollAwayDBChar.lastReminderInstID = nil
        if reminderFrame and reminderFrame:IsShown() then reminderFrame:Hide() end
        return
    end

    if not (RollAwayDB.showReminder or RollAwayDB.autoPassWarning) then return end
    if not RA.BONUS_ROLLS_ENABLED then return end

    -- Only show once per instance visit (kept through /reload; cleared on
    -- login, group leave and when leaving the instance)
    if RollAwayDBChar.lastReminderInstID == instanceID then return end

    local tabKey, msgKey

    if instanceType == "party" and DUNGEON_MAP[instanceID] then
        -- Dungeons: Mythic and Mythic+ only – use cached diffID
        if not RA.MYTHIC_DUNGEON_DIFFICULTY_IDS[RA.cachedDiffID] then
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
    local voidcoreInfo = C_CurrencyInfo.GetCurrencyInfo(RA.VOIDCORE_CURRENCY_ID)
    local voidcoreQty  = voidcoreInfo and voidcoreInfo.quantity or 0
    if voidcoreQty == 0 then
        DBG("Reminder: no Voidcores – skipping")
        return
    end

    local statusText, autoPassActive = BuildAutoPassStatus(tabKey, instanceID)
    if not RollAwayDB.showReminder and not autoPassActive then
        DBG("Reminder: no auto-pass active – warning not needed")
        return
    end

    local rollsPossible = math.floor(voidcoreQty / VOIDCORE_COST[tabKey])
    local rollColor     = rollsPossible > 1 and "|cff00cc00" or "|cffffff00"
    -- A warning is pointless when no roll can happen anyway (e.g. 1 Voidcore
    -- in a raid, which costs 2).
    if not RollAwayDB.showReminder and rollsPossible < 1 then return end

    RollAwayDBChar.lastReminderInstID = instanceID
    DBG("Showing reminder | tabKey:", tabKey, "| instanceID:", instanceID,
        "| Voidcores:", voidcoreQty, "| rolls:", rollsPossible)

    CreateReminderFrame()

    -- Stacked in the shared popup order (Core/Helpers.lua), so the
    -- notifications never overlap.
    RA.StackPopupFrame(reminderFrame)

    -- Update content (no new closures created here)
    currentTabKey = tabKey
    reminderFrame.btn:SetText(RA_L["reminder_btn_"..tabKey])

    -- Only the safety-net warning is on (not the general reminder): the popup
    -- is just the "auto-pass ACTIVE" text, without the generic hint and the
    -- Voidcore line.
    local warnOnly = not RollAwayDB.showReminder
    reminderFrame.warnOnly = warnOnly
    reminderFrame.sep:SetShown(not warnOnly)
    reminderFrame.currency:SetShown(not warnOnly)
    reminderFrame.status:SetShown(not warnOnly)
    if warnOnly then
        reminderFrame.msg:SetText(statusText or "")
        reminderFrame.currency:SetText("")
        reminderFrame.status:SetText("")
    else
        reminderFrame.msg:SetText(RA_L[msgKey])
        reminderFrame.currency:SetText(string.format(
            RA_L["reminder_voidcore"],
            voidcoreQty,
            rollColor .. rollsPossible .. "|r",
            rollsPossible == 1 and RA_L["reminder_roll_singular"] or RA_L["reminder_roll_plural"]))
        -- The red / green auto-pass status line belongs to the warning
        -- option; with it off this is the plain reminder.
        reminderFrame.status:SetText(RollAwayDB.autoPassWarning and statusText or "")
    end

    reminderFrame:Show()
end

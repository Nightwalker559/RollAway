-- RollAway - TeleportReminder.lua
-- Alternative join reminder (RollAwayDB.joinReminderKeyAddon == "teleport", see
-- JoinReminder.lua): the season's portal button for the dungeon you joined, or all of
-- them when it is unknown. Group Finder joins only. Stays open until a portal is
-- clicked or it is closed (no timer).

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local BUTTON_SIZE = 32
local BUTTON_GAP  = 6

-- State

local reminderFrame
local portalButtons = {}  -- one per season dungeon
local buttonByKey    = {} -- dungeon.key -> button

-- Frame creation (once)

local function CreatePortalButtons(parent, dungeons)
    for i, dungeon in ipairs(dungeons) do
        local btn = RA.CreatePortalButton("RollAwayTeleportButton"..i, parent, BUTTON_SIZE)
        RA.SetPortalSpell(btn, dungeon.portalSpellID)
        btn.nameKey = "dungeon_"..dungeon.key

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(RA_L[self.nameKey], 1, 0.82, 0)
            if not C_SpellBook.IsSpellInSpellBook(self.spellID) then
                GameTooltip:AddLine(RA_L["teleport_reminder_locked"], 1, 0, 0)
            end
            GameTooltip:Show()
        end)

        -- Closes once a portal is used.
        btn:HookScript("OnClick", function() RA.SafeSetShown(reminderFrame, false) end)

        RA.SafeSetShown(btn, false)
        portalButtons[i]         = btn
        buttonByKey[dungeon.key] = btn
    end
end

local function CreateReminderFrame()
    if reminderFrame then return end

    reminderFrame = CreateFrame("Frame", "RollAwayTeleportReminderFrame", UIParent, "BackdropTemplate")
    reminderFrame:SetSize(340, 92)
    reminderFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    reminderFrame:SetFrameStrata("HIGH")
    reminderFrame:SetClampedToScreen(true)
    RA.MakeDraggable(reminderFrame)
    RA.SafeSetShown(reminderFrame, false)

    -- Not in UISpecialFrames: Esc closed it by accident. X button, portal click or /reload close it.
    RA.ApplyPopupBackdrop(reminderFrame)

    local closeBtn = CreateFrame("Button", "RollAwayTeleportReminderClose", reminderFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", reminderFrame, "TOPRIGHT", 2, 2)

    -- Title
    local titleText = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", reminderFrame, "TOP", 0, -10)
    titleText:SetText("|cffD4AF37RollAway|r")

    -- Message text
    reminderFrame.msg = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    reminderFrame.msg:SetPoint("TOP", reminderFrame, "TOP", 0, -26)
    reminderFrame.msg:SetJustifyH("CENTER")

    CreatePortalButtons(reminderFrame, RA.DUNGEONS[RA.ACTIVE_SEASON] or {})

    -- Combat and GROUP_LEFT hide it. Not GROUP_JOINED: it fires when we join the very
    -- group the reminder is for.
    reminderFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    reminderFrame:RegisterEvent("GROUP_LEFT")
    reminderFrame:SetScript("OnEvent", function(self, event)
        -- (RA.SafeSetShown also uses PLAYER_REGEN_ENABLED here)
        if event == "PLAYER_REGEN_DISABLED" then
            RA.SafeSetShown(self, false)
        elseif event == "GROUP_LEFT" then
            -- Accepting an LFG invite from a party leaves the old party: GROUP_LEFT can
            -- come after the new group's reminder. Hide only if we ended up ungrouped.
            C_Timer.After(1, function()
                if not IsInGroup() then
                    DBG("Teleport reminder hidden - left group")
                    RA.SafeSetShown(self, false)
                end
            end)
        end
    end)
end

-- Layout: only the given buttons, centered in a row, with locked/cooldown state.

local function LayoutAndUpdate(visibleButtons)
    local count      = #visibleButtons
    local totalWidth = (count * BUTTON_SIZE) + ((count - 1) * BUTTON_GAP)
    local startX     = -(totalWidth / 2) + (BUTTON_SIZE / 2)

    for _, btn in ipairs(portalButtons) do
        RA.SafeSetShown(btn, false)
        btn:ClearAllPoints()
    end

    for i, btn in ipairs(visibleButtons) do
        btn:SetPoint("TOP", reminderFrame, "TOP", startX + ((i - 1) * (BUTTON_SIZE + BUTTON_GAP)), -46)
        RA.UpdatePortalButtonState(btn, C_SpellBook.IsSpellInSpellBook(btn.spellID), 0.5)
        RA.SafeSetShown(btn, true)
    end
end

-- Show reminder
-- instanceName: localized dungeon name (nil = generic message).
-- dungeon: season entry; only its portal is shown, nil shows all portals.
-- keyLevel: listed key level or nil, shown as "+N".
function RA.ShowTeleportReminder(instanceName, dungeon, keyLevel)
    if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
    if RollAwayDB.joinReminderKeyAddon ~= "teleport" then return end
    -- Secure buttons: no re-layout in combat.
    if InCombatLockdown() then
        DBG("Teleport reminder skipped - in combat")
        return
    end

    CreateReminderFrame()

    local dungeonButton = dungeon and buttonByKey[dungeon.key]

    -- Dungeon known and its portal on cooldown (already used): no reminder again.
    if dungeonButton and RA.IsPortalOnCooldown(dungeonButton.spellID) then
        DBG("Teleport reminder skipped - portal on cooldown:", dungeon.key)
        return
    end

    DBG("Showing teleport reminder | instance:", instanceName or "n/a",
        "| dungeon:", dungeon and dungeon.key or "all")

    reminderFrame.msg:SetText(instanceName
        and ("|cffFFFFFF"..RA.FormatInstanceWithKey(instanceName, keyLevel).."|r")
        or RA_L["teleport_reminder_generic"])

    LayoutAndUpdate(dungeonButton and { dungeonButton } or portalButtons)

    RA.SafeSetShown(reminderFrame, true)
end

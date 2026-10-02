-- RollAway - TeleportReminder.lua
-- Alternative to the default instance-join reminder: shows the Mythic+
-- Season 2 dungeon portal button for the dungeon you're actually queued
-- for (or all of them, if the specific dungeon can't be determined - e.g.
-- an M+ activity outside the tracked season pool). Selected via
-- RollAwayDB.joinReminderKeyAddon == "teleport" (JoinReminder.lua). Group
-- Finder (LFG) join only - manually formed groups get no reminder at all.
-- Stays open until a portal is clicked or the frame is manually closed -
-- no auto-hide timer.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local BUTTON_SIZE = 32
local BUTTON_GAP  = 6

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

local reminderFrame
local portalButtons = {}  -- ordered array, one per RA.DUNGEONS[season] entry
local buttonByKey    = {} -- dungeon.key -> button

------------------------------------------------------------------------
-- Frame creation (once, reused on every show)
------------------------------------------------------------------------

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

        -- Manual close on use - the reminder's whole purpose is fulfilled
        -- once a portal has been taken.
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

    -- Deliberately NOT added to UISpecialFrames: Esc is used constantly
    -- while playing (canceling casts, closing other windows, etc.) and
    -- was closing this reminder unintentionally. Closing it now requires
    -- the explicit X button, a portal click, or /reload.
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

    -- Combat → hide. GROUP_LEFT → hide (stale reminder for a group we've
    -- since left). Deliberately NOT GROUP_JOINED - that event fires at the
    -- exact moment we join the very group this reminder is being shown
    -- for, which used to hide it again immediately after RA.ShowTeleportReminder()
    -- displayed it.
    reminderFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    reminderFrame:RegisterEvent("GROUP_LEFT")
    reminderFrame:SetScript("OnEvent", function(self, event)
        -- (RA.SafeSetShown also registers PLAYER_REGEN_ENABLED on this frame)
        if event == "PLAYER_REGEN_DISABLED" then
            RA.SafeSetShown(self, false)
        elseif event == "GROUP_LEFT" then
            -- Accepting an LFG invite while already in a party (e.g. a
            -- 3-man applying together) leaves the old party: GROUP_LEFT can
            -- arrive right AFTER the reminder for the new group was shown,
            -- followed by GROUP_JOINED. Only hide if we ended up ungrouped.
            C_Timer.After(1, function()
                if not IsInGroup() then
                    DBG("Teleport reminder hidden - left group")
                    RA.SafeSetShown(self, false)
                end
            end)
        end
    end)
end

------------------------------------------------------------------------
-- Layout: shows only the given buttons, centered in a row, and updates
-- their locked/cooldown state.
------------------------------------------------------------------------

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

------------------------------------------------------------------------
-- Show reminder
------------------------------------------------------------------------

-- instanceName: localized dungeon name (or nil for a generic message).
-- dungeon: matched entry from RA.DUNGEONS[RA.ACTIVE_SEASON] - when given,
-- only that dungeon's portal is shown; when nil (dungeon not resolved,
-- e.g. an M+ activity outside the tracked season pool), all portals are
-- shown so the correct one can still be picked manually.
function RA.ShowTeleportReminder(instanceName, dungeon)
    if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
    if RollAwayDB.joinReminderKeyAddon ~= "teleport" then return end
    -- The portal buttons are secure frames: no re-layout in combat.
    if InCombatLockdown() then
        DBG("Teleport reminder skipped - in combat")
        return
    end

    CreateReminderFrame()

    local dungeonButton = dungeon and buttonByKey[dungeon.key]

    -- Specific dungeon known and its portal already on cooldown (i.e. we
    -- already used it) - don't pop the reminder back up for the same key.
    if dungeonButton and RA.IsPortalOnCooldown(dungeonButton.spellID) then
        DBG("Teleport reminder skipped - portal on cooldown:", dungeon.key)
        return
    end

    DBG("Showing teleport reminder | instance:", instanceName or "n/a",
        "| dungeon:", dungeon and dungeon.key or "all")

    reminderFrame.msg:SetText(instanceName and ("|cffFFFFFF"..instanceName.."|r")
        or RA_L["teleport_reminder_generic"])

    LayoutAndUpdate(dungeonButton and { dungeonButton } or portalButtons)

    RA.SafeSetShown(reminderFrame, true)
end

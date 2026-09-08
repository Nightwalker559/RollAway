-- RollAway - TeleportReminder.lua
-- Alternative to the default instance-join reminder: shows the Mythic+
-- Season 2 dungeon portal button for the dungeon you're actually queued
-- for (or all of them, if the specific dungeon can't be determined - e.g.
-- a manually formed premade group). Selected via
-- RollAwayDB.joinReminderKeyAddon == "teleport" (QoL.lua).
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
        local btn = CreateFrame("Button", "RollAwayTeleportButton"..i, parent, "SecureActionButtonTemplate")
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        btn.spellID = dungeon.portalSpellID
        btn.nameKey = "dungeon_"..dungeon.key

        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local iconTexture = C_Spell.GetSpellTexture(dungeon.portalSpellID)
        tex:SetTexture(iconTexture)
        btn.iconTexture = tex

        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.25)

        btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.cooldown:SetAllPoints()
        btn.cooldown:SetDrawEdge(false)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(RA_L[self.nameKey], 1, 0.82, 0)
            if not C_SpellBook.IsSpellInSpellBook(self.spellID) then
                GameTooltip:AddLine(RA_L["teleport_reminder_locked"], 1, 0, 0)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", dungeon.portalSpellID)

        -- Manual close on use - the reminder's whole purpose is fulfilled
        -- once a portal has been taken.
        btn:HookScript("OnClick", function() reminderFrame:Hide() end)

        btn:Hide()
        portalButtons[i]        = btn
        buttonByKey[dungeon.key] = btn
    end
end

local function CreateReminderFrame()
    if reminderFrame then return end

    local dungeons = RA.DUNGEONS[RA.ACTIVE_SEASON] or {}

    reminderFrame = CreateFrame("Frame", "RollAwayTeleportReminderFrame", UIParent, "BackdropTemplate")
    reminderFrame:SetSize(340, 92)
    reminderFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    reminderFrame:SetFrameStrata("HIGH")
    reminderFrame:SetClampedToScreen(true)
    RA.MakeDraggable(reminderFrame)
    reminderFrame:Hide()

    tinsert(UISpecialFrames, "RollAwayTeleportReminderFrame")

    reminderFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    reminderFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    reminderFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

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

    CreatePortalButtons(reminderFrame, dungeons)

    -- Combat → hide. GROUP_LEFT/GROUP_JOINED → hide (new group, new keys).
    reminderFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    reminderFrame:RegisterEvent("GROUP_LEFT")
    reminderFrame:RegisterEvent("GROUP_JOINED")
    reminderFrame:SetScript("OnEvent", function(self) self:Hide() end)
end

------------------------------------------------------------------------
-- Layout: shows only the given buttons (nil = all), centered in a row,
-- and updates their locked/cooldown state.
------------------------------------------------------------------------

local function LayoutAndUpdate(visibleButtons)
    local count      = #visibleButtons
    local totalWidth = (count * BUTTON_SIZE) + ((count - 1) * BUTTON_GAP)
    local startX     = -(totalWidth / 2) + (BUTTON_SIZE / 2)

    for _, btn in ipairs(portalButtons) do
        btn:Hide()
        btn:ClearAllPoints()
    end

    for i, btn in ipairs(visibleButtons) do
        btn:SetPoint("TOP", reminderFrame, "TOP", startX + ((i - 1) * (BUTTON_SIZE + BUTTON_GAP)), -46)

        local isKnown = C_SpellBook.IsSpellInSpellBook(btn.spellID)
        btn.iconTexture:SetDesaturated(not isKnown)
        btn:SetAlpha(isKnown and 1.0 or 0.5)

        if isKnown then
            local cdInfo = C_Spell.GetSpellCooldown(btn.spellID)
            if cdInfo and cdInfo.startTime > 0 and cdInfo.duration > 0 then
                btn.cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration)
            else
                btn.cooldown:Clear()
            end
        else
            btn.cooldown:Clear()
        end

        btn:Show()
    end
end

------------------------------------------------------------------------
-- Show reminder
------------------------------------------------------------------------

-- instanceName: localized dungeon name (or nil for a generic message).
-- dungeon: matched entry from RA.DUNGEONS[RA.ACTIVE_SEASON] - when given,
-- only that dungeon's portal is shown; when nil (dungeon not resolved,
-- e.g. a manually formed premade group), all portals are shown so the
-- correct one can still be picked manually.
function RA.ShowTeleportReminder(instanceName, dungeon)
    if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
    if RollAwayDB.joinReminderKeyAddon ~= "teleport" then return end

    CreateReminderFrame()

    DBG("Showing teleport reminder | instance:", instanceName or "n/a",
        "| dungeon:", dungeon and dungeon.key or "all")

    reminderFrame.msg:SetText(instanceName and ("|cffFFFFFF"..instanceName.."|r")
        or RA_L["teleport_reminder_generic"])

    if dungeon and buttonByKey[dungeon.key] then
        LayoutAndUpdate({ buttonByKey[dungeon.key] })
    else
        LayoutAndUpdate(portalButtons)
    end

    reminderFrame:Show()
end

function RA.HideTeleportReminder()
    if reminderFrame and reminderFrame:IsShown() then reminderFrame:Hide() end
end

------------------------------------------------------------------------
-- Initialization – called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitTeleportReminder()
    DBG("Teleport reminder initialized")
end

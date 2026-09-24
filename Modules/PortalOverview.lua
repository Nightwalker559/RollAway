-- RollAway - Modules/PortalOverview.lua
-- RollAway's own portal frame - an alternative to BigWigs/Details Keystones
-- for players who don't run either. Purely manual, opened via /rat - no
-- automatic trigger (the join reminder in Modules\TeleportReminder.lua
-- handles Group Finder (LFG) joins instead, which can resolve the exact
-- dungeon via the LFG activity ID).
--
-- Two tabs:
--   1) Current season  - RA.DUNGEONS[RA.ACTIVE_SEASON], same layout/locked
--      state as the join reminder.
--   2) All dungeons     - every dungeon teleport the player has ever
--      learned (RA.DUNGEONS[*] + Data\LegacyDungeonTeleports.lua),
--      grouped by expansion; unlearned ones and empty categories are
--      hidden entirely.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local BUTTON_SIZE  = 48
local BUTTON_GAP   = 8
local BUTTONS_PER_ROW = 4
local HEADER_HEIGHT   = 18
local HEADER_GAP      = 4

local FRAME_WIDTH   = 260
local FRAME_HEIGHT  = 260  -- fixed - content scrolls instead of growing the frame
local CONTENT_WIDTH = FRAME_WIDTH - 20 -- minus margins; scrollbar is hidden, not reserved

-- Display order for tab 2's category headers - newest expansion first.
local CATEGORY_ORDER = {
    "midnight", "tww", "dragonflight", "shadowlands", "bfa", "legion",
    "wod", "mop", "cataclysm", "wrath", "tbc",
}

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

local overviewFrame
local activeTab   = 1
local portalPool  = {}   -- reusable icon-button pool
local headerPool  = {}   -- reusable category-header pool (tab 2 only)

------------------------------------------------------------------------
-- Data sources for tab 2 - built once per refresh, cheap to rebuild.
------------------------------------------------------------------------

-- All dungeon teleports ever handed out, tagged with an `expansion` key
-- for category grouping. Both RA.DUNGEONS and Data\LegacyDungeonTeleports.lua
-- carry their own `expansion` field per dungeon - several current-season
-- dungeons are revived older-expansion instances (e.g. Pit of Saron =
-- Wrath, Algeth'ar Academy = Dragonflight) and are tagged accordingly,
-- not lumped into "midnight" just because they're in this season's pool.
-- Skips entries with no portalSpellID (faction-specific ones resolved to
-- 0, or season entries not yet filled in).
local function GetAllDungeonTeleports()
    local list = {}
    for _, d in ipairs(RA.LEGACY_DUNGEON_TELEPORTS or {}) do
        if d.portalSpellID and d.portalSpellID ~= 0 then
            list[#list + 1] = { key = d.key, spellID = d.portalSpellID, nameKey = "dungeon_"..d.key, expansion = d.expansion, lfgID = d.lfgID }
        end
    end
    for s = 1, RA.ACTIVE_SEASON do
        for _, d in ipairs(RA.DUNGEONS[s] or {}) do
            if d.portalSpellID and d.portalSpellID ~= 0 then
                list[#list + 1] = { key = d.key, spellID = d.portalSpellID, nameKey = "dungeon_"..d.key, expansion = d.expansion or "midnight", lfgID = d.lfgID }
            end
        end
    end
    return list
end

-- Buckets a flat, already-known-filtered entry list into ordered
-- { expansion, entries } groups per CATEGORY_ORDER. Empty categories are
-- left out entirely. Entries within each group are sorted alphabetically
-- by localized name; the group order itself (newest expansion first)
-- is untouched.
local function GroupByExpansion(entries)
    local buckets = {}
    for _, e in ipairs(entries) do
        buckets[e.expansion] = buckets[e.expansion] or {}
        table.insert(buckets[e.expansion], e)
    end
    local groups = {}
    for _, exp in ipairs(CATEGORY_ORDER) do
        if buckets[exp] then
            local sorted = RA.SortByLabel(buckets[exp], function(e) return RA_L[e.nameKey] or e.key end)
            groups[#groups + 1] = { expansion = exp, entries = sorted }
        end
    end
    return groups
end

-- The Mythic+ keystone currently in the player's bags, if any - matched
-- via lfgID like the proven helper in Modules\LFGQuickCreate.lua
-- (RefreshGlow), since that's the API/field combo confirmed to work here
-- rather than C_MythicPlus.GetOwnedKeystoneChallengeMapID()/mapID.
local function GetOwnedKeystone()
    if not C_LFGList then return nil, nil end
    local ownLfgID, _, ownLevel = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
    return ownLfgID, ownLevel
end

------------------------------------------------------------------------
-- Button pool
------------------------------------------------------------------------

local function AcquireButton(i, parent)
    local btn = portalPool[i]
    if btn then return btn end

    btn = CreateFrame("Button", "RollAwayPortalOverviewButton"..i, parent, "SecureActionButtonTemplate")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)

    local tex = btn:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.iconTexture = tex

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.25)

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    btn.cooldown:SetDrawEdge(false)

    -- Gold overlay shown when this dungeon's keystone is currently in the
    -- player's bags - same look as the Quick Select glow in
    -- Modules\LFGQuickCreate.lua (a plain tinted color texture over the
    -- icon, not a separate border ring).
    local keyBorder = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    keyBorder:SetAllPoints()
    keyBorder:SetColorTexture(1, 0.82, 0, 0.38)
    keyBorder:Hide()
    btn.keyBorder = keyBorder

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(RA_L[self.nameKey] or self.nameKey, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "spell")

    portalPool[i] = btn
    return btn
end

local function AcquireHeader(i, parent)
    local fs = headerPool[i]
    if fs then return fs end
    fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetTextColor(0.82, 0.68, 0.2, 1)
    headerPool[i] = fs
    return fs
end

------------------------------------------------------------------------
-- Frame creation
------------------------------------------------------------------------

local function SelectTab(index)
    activeTab = index
    RA.RefreshPortalOverview()
end

local function CreateOverviewFrame()
    if overviewFrame then return end

    overviewFrame = CreateFrame("Frame", "RollAwayPortalOverviewFrame", UIParent, "BackdropTemplate")
    overviewFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    local pos = RollAwayDB and RollAwayDB.portalOverviewPos
    if pos then
        overviewFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        overviewFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end
    overviewFrame:SetFrameStrata("HIGH")
    overviewFrame:SetClampedToScreen(true)
    overviewFrame:SetMovable(true)
    RA.MakeDraggable(overviewFrame)
    overviewFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if RollAwayDB then
            RollAwayDB.portalOverviewPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    RA.SafeSetShown(overviewFrame, false)

    overviewFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    overviewFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    overviewFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local closeBtn = CreateFrame("Button", "RollAwayPortalOverviewClose", overviewFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", overviewFrame, "TOPRIGHT", 2, 2)

    local titleText = overviewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", overviewFrame, "TOP", 0, -10)
    titleText:SetText("|cffD4AF37"..RA_L["portal_overview_title"].."|r")

    -- Tabs (standard Blizzard tab template - PanelTemplates_* handles the
    -- active/inactive textures). Button names must follow
    -- "<frameName>Tab<index>" for PanelTemplates_UpdateTabs to find them.
    local frameName = overviewFrame:GetName()
    local tabLabels = {
        RA_L["portal_overview_tab_season"],
        RA_L["portal_overview_tab_dungeons"],
    }
    overviewFrame.numTabs = #tabLabels
    local prevTab
    for i, label in ipairs(tabLabels) do
        local tab = CreateFrame("Button", frameName.."Tab"..i, overviewFrame, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(label)
        PanelTemplates_TabResize(tab, 14)
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", overviewFrame, "BOTTOMLEFT", 10, 2)
        end
        tab:SetScript("OnClick", function(self)
            PanelTemplates_SetTab(overviewFrame, self:GetID())
            SelectTab(self:GetID())
        end)
        prevTab = tab
    end
    PanelTemplates_SetTab(overviewFrame, 1)

    -- Scrollable content area - the frame itself stays a fixed size;
    -- everything (icons, expansion headers) is anchored inside `content`,
    -- which grows to fit and scrolls when it exceeds the visible area.
    local scrollFrame = CreateFrame("ScrollFrame", frameName.."ScrollFrame", overviewFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", overviewFrame, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", overviewFrame, "BOTTOMRIGHT", -10, 12)

    -- Scrolling still works via mouse wheel (below); the visual scrollbar
    -- just eats width we'd rather give to the icons. Force it hidden even
    -- though the template shows/hides it automatically on its own.
    local scrollBar = _G[scrollFrame:GetName().."ScrollBar"]
    if scrollBar then
        scrollBar:Hide()
        scrollBar:SetScript("OnShow", scrollBar.Hide)
    end

    local content = CreateFrame("Frame", frameName.."Content", scrollFrame)
    content:SetSize(CONTENT_WIDTH, 1)
    scrollFrame:SetScrollChild(content)
    overviewFrame.content = content

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local newScroll = self:GetVerticalScroll() - delta * 30
        newScroll = math.max(0, math.min(newScroll, self:GetVerticalScrollRange()))
        self:SetVerticalScroll(newScroll)
    end)

    -- Empty-state text (tab 2 with nothing learned yet)
    overviewFrame.emptyText = overviewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    overviewFrame.emptyText:SetPoint("CENTER", overviewFrame, "CENTER", -10, -10)
    overviewFrame.emptyText:SetText(RA_L["portal_overview_empty"])
    overviewFrame.emptyText:Hide()

    overviewFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    overviewFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    overviewFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            RA.SafeSetShown(self, false)
        elseif event == "BAG_UPDATE_DELAYED" then
            RA.RefreshPortalOverview()
        end
    end)
end

------------------------------------------------------------------------
-- Layout - flat mode (tab 1): wraps buttons into rows of BUTTONS_PER_ROW.
------------------------------------------------------------------------

local function HideAllButtons()
    for _, btn in pairs(portalPool) do
        RA.SafeSetShown(btn, false)
        btn:ClearAllPoints()
    end
    for _, fs in pairs(headerPool) do
        fs:Hide()
        fs:ClearAllPoints()
    end
end

local function PlaceButton(btn, entry, isKnown, x, y, ownedLfgID)
    btn.spellID = entry.spellID
    btn.nameKey = entry.nameKey
    btn:SetAttribute("spell", entry.spellID)
    btn.iconTexture:SetTexture(C_Spell.GetSpellTexture(entry.spellID))
    btn.iconTexture:SetDesaturated(not isKnown)
    btn:SetAlpha(isKnown and 1.0 or 0.4)

    local ownsThisKey = entry.lfgID ~= nil and entry.lfgID == ownedLfgID
    btn.keyBorder:SetShown(ownsThisKey)

    if isKnown then
        local cdInfo = C_Spell.GetSpellCooldown(entry.spellID)
        if cdInfo and cdInfo.startTime > 0 and cdInfo.duration > 3 then
            btn.cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration)
        else
            btn.cooldown:Clear()
        end
    else
        btn.cooldown:Clear()
    end

    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", overviewFrame.content, "TOPLEFT", x, y)
    RA.SafeSetShown(btn, true)
end

local function LayoutFlatButtons(entries)
    HideAllButtons()

    -- Season header, same style/height as tab 2's expansion headers (reuses
    -- the same header pool slot 1) so button rows start at the identical Y
    -- offset in both tabs - no visual jump when switching tabs.
    local header = AcquireHeader(1, overviewFrame.content)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", overviewFrame.content, "TOPLEFT", 0, 0)
    header:SetText(string.format(RA_L["portal_overview_current_season"] or "Season %d", RA.ACTIVE_SEASON))
    header:Show()

    if #entries == 0 then
        overviewFrame.emptyText:Show()
        overviewFrame.content:SetHeight(HEADER_HEIGHT)
        return
    end
    overviewFrame.emptyText:Hide()

    local ownedLfgID = GetOwnedKeystone()
    local rows = math.ceil(#entries / BUTTONS_PER_ROW)
    overviewFrame.content:SetHeight(HEADER_HEIGHT + rows * (BUTTON_SIZE + BUTTON_GAP))

    local btnIndex = 0
    for i, entry in ipairs(entries) do
        btnIndex = btnIndex + 1
        local btn = AcquireButton(btnIndex, overviewFrame.content)
        local isKnown = C_SpellBook.IsSpellInSpellBook(entry.spellID)

        local row = math.floor((i - 1) / BUTTONS_PER_ROW)
        local col = (i - 1) % BUTTONS_PER_ROW
        local rowCount = math.min(BUTTONS_PER_ROW, #entries - row * BUTTONS_PER_ROW)
        local rowWidth = (rowCount * BUTTON_SIZE) + ((rowCount - 1) * BUTTON_GAP)
        local startX = (CONTENT_WIDTH - rowWidth) / 2
        PlaceButton(btn, entry, isKnown,
            startX + col * (BUTTON_SIZE + BUTTON_GAP), -HEADER_HEIGHT - row * (BUTTON_SIZE + BUTTON_GAP), ownedLfgID)
    end
end

------------------------------------------------------------------------
-- Layout - grouped mode (tab 2): one left-aligned header per expansion,
-- its portals wrapped into rows underneath. Entries here are already
-- filtered to known spells only, so every button shown is fully lit.
------------------------------------------------------------------------

local function LayoutGroupedButtons(groups)
    HideAllButtons()

    if #groups == 0 then
        overviewFrame.emptyText:Show()
        overviewFrame.content:SetHeight(1)
        return
    end
    overviewFrame.emptyText:Hide()

    local ownedLfgID = GetOwnedKeystone()
    local y = 0
    local btnIndex, hdrIndex = 0, 0

    for _, group in ipairs(groups) do
        hdrIndex = hdrIndex + 1
        local header = AcquireHeader(hdrIndex, overviewFrame.content)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", overviewFrame.content, "TOPLEFT", 0, y)
        header:SetText(RA_L["expansion_"..group.expansion] or group.expansion)
        header:Show()
        y = y - HEADER_HEIGHT

        local rowsInGroup = math.ceil(#group.entries / BUTTONS_PER_ROW)
        for i, entry in ipairs(group.entries) do
            btnIndex = btnIndex + 1
            local btn = AcquireButton(btnIndex, overviewFrame.content)
            local row = math.floor((i - 1) / BUTTONS_PER_ROW)
            local col = (i - 1) % BUTTONS_PER_ROW
            local rowCount = math.min(BUTTONS_PER_ROW, #group.entries - row * BUTTONS_PER_ROW)
            local rowWidth = (rowCount * BUTTON_SIZE) + ((rowCount - 1) * BUTTON_GAP)
            local startX = (CONTENT_WIDTH - rowWidth) / 2
            PlaceButton(btn, entry, true,
                startX + col * (BUTTON_SIZE + BUTTON_GAP),
                y - row * (BUTTON_SIZE + BUTTON_GAP), ownedLfgID)
        end
        y = y - rowsInGroup * (BUTTON_SIZE + BUTTON_GAP) - HEADER_GAP
    end

    overviewFrame.content:SetHeight(-y)
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

function RA.RefreshPortalOverview()
    if not overviewFrame or not overviewFrame:IsShown() then return end
    if activeTab == 1 then
        local dungeons = RA.DUNGEONS[RA.ACTIVE_SEASON] or {}
        local entries = {}
        for _, d in ipairs(dungeons) do
            if d.portalSpellID then
                entries[#entries + 1] = { key = d.key, spellID = d.portalSpellID, nameKey = "dungeon_"..d.key, lfgID = d.lfgID }
            end
        end
        entries = RA.SortByLabel(entries, function(e) return RA_L[e.nameKey] or e.key end)
        LayoutFlatButtons(entries)
    else
        local known = {}
        for _, e in ipairs(GetAllDungeonTeleports()) do
            if C_SpellBook.IsSpellInSpellBook(e.spellID) then known[#known + 1] = e end
        end
        LayoutGroupedButtons(GroupByExpansion(known))
    end
end

function RA.ShowPortalOverview()
    CreateOverviewFrame()
    PanelTemplates_SetTab(overviewFrame, 1)
    SelectTab(1)
    RA.SafeSetShown(overviewFrame, true)
    RA.RefreshPortalOverview()
end

function RA.HidePortalOverview()
    if overviewFrame then RA.SafeSetShown(overviewFrame, false) end
end

function RA.TogglePortalOverview()
    if overviewFrame and overviewFrame:IsShown() then
        RA.HidePortalOverview()
    else
        RA.ShowPortalOverview()
    end
end

------------------------------------------------------------------------
-- Slash command - manual open/close, independent of group state.
------------------------------------------------------------------------

SLASH_ROLLAWAYPORTALS1 = "/rat"
SlashCmdList["ROLLAWAYPORTALS"] = function()
    RA.TogglePortalOverview()
end

------------------------------------------------------------------------
-- Initialization - called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitPortalOverview()
    DBG("Portal overview initialized")
end

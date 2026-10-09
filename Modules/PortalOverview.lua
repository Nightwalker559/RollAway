-- RollAway - Modules/PortalOverview.lua
-- RollAway's own portal frame, an alternative to BigWigs/Details Keystones. Manual
-- only (/rat); Group Finder joins are handled by TeleportReminder.lua.
-- Tabs: 1) current season (RA.DUNGEONS[RA.ACTIVE_SEASON]), same look as the join
-- reminder; 2) all learned dungeon teleports (RA.DUNGEONS[*] + LegacyDungeonTeleports),
-- grouped by expansion, unlearned ones and empty groups hidden.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

local BUTTON_SIZE  = 48
local BUTTON_GAP   = 8
local ROW_STEP     = BUTTON_SIZE + BUTTON_GAP
local BUTTONS_PER_ROW = 4
local HEADER_HEIGHT   = 18
local HEADER_GAP      = 4

local FRAME_WIDTH   = 260
local FRAME_HEIGHT  = 260  -- fixed, content scrolls
local CONTENT_WIDTH = FRAME_WIDTH - 20 -- minus margins (the scrollbar is hidden)

-- Tab 2 header order, newest first.
local CATEGORY_ORDER = {
    "midnight", "tww", "dragonflight", "shadowlands", "bfa", "legion",
    "wod", "mop", "cataclysm", "wrath", "tbc",
}

-- State

local overviewFrame
local activeTab   = 1
local portalPool  = {}   -- icon button pool
local headerPool  = {}   -- category header pool
local usedButtons = 0    -- pool slots used in the current layout pass

-- Data sources

-- Appends one entry per dungeon with a teleport spell to `list`, tagged with its own
-- `expansion` (revived old dungeons keep theirs). Skips entries without portalSpellID.
local function CollectEntries(list, dungeons, defaultExpansion)
    for _, d in ipairs(dungeons) do
        if d.portalSpellID and d.portalSpellID ~= 0 then
            list[#list + 1] = {
                key = d.key, spellID = d.portalSpellID, nameKey = "dungeon_"..d.key,
                expansion = d.expansion or defaultExpansion, lfgID = d.lfgID,
            }
        end
    end
    return list
end

local function EntryLabel(e)
    return RA_L[e.nameKey] or e.key
end

-- All dungeon teleports ever handed out.
local function GetAllDungeonTeleports()
    local list = CollectEntries({}, RA.LEGACY_DUNGEON_TELEPORTS or {})
    for s = 1, RA.ACTIVE_SEASON do
        CollectEntries(list, RA.DUNGEONS[s] or {}, "midnight")
    end
    return list
end

-- Buckets known entries into { expansion, entries } groups in CATEGORY_ORDER (empty
-- ones left out), sorted by localized name within each group.
local function GroupByExpansion(entries)
    local buckets = {}
    for _, e in ipairs(entries) do
        buckets[e.expansion] = buckets[e.expansion] or {}
        table.insert(buckets[e.expansion], e)
    end
    local groups = {}
    for _, exp in ipairs(CATEGORY_ORDER) do
        if buckets[exp] then
            groups[#groups + 1] = { expansion = exp, entries = RA.SortByLabel(buckets[exp], EntryLabel) }
        end
    end
    return groups
end

-- Pools

local function AcquireButton(i, parent)
    local btn = portalPool[i]
    if btn then return btn end

    btn = RA.CreatePortalButton("RollAwayPortalOverviewButton"..i, parent, BUTTON_SIZE)

    -- Gold overlay while this dungeon's keystone is in the bags (same as the
    -- Quick Select glow in LFGQuickCreate.lua).
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

    -- Close after using a teleport (they share one cooldown). PostClick runs after
    -- the secure click, so plain Lua is safe.
    btn:HookScript("PostClick", function()
        RA.HidePortalOverview()
    end)

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

-- Frame creation

local function SelectTab(index)
    activeTab = index
    PanelTemplates_SetTab(overviewFrame, index)
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
    RA.MakeDraggable(overviewFrame)
    overviewFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if RollAwayDB then
            RollAwayDB.portalOverviewPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    RA.SafeSetShown(overviewFrame, false)
    RA.ApplyPopupBackdrop(overviewFrame)

    local closeBtn = CreateFrame("Button", "RollAwayPortalOverviewClose", overviewFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", overviewFrame, "TOPRIGHT", 2, 2)

    local titleText = overviewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", overviewFrame, "TOP", 0, -10)
    titleText:SetText("|cffD4AF37"..RA_L["portal_overview_title"].."|r")

    -- Tabs (Blizzard tab template; names must be "<frameName>Tab<index>" for
    -- PanelTemplates_UpdateTabs).
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
        tab:SetScript("OnClick", function(self) SelectTab(self:GetID()) end)
        prevTab = tab
    end
    PanelTemplates_SetTab(overviewFrame, 1)

    -- Scrollable content: icons and headers are anchored inside `content`, which grows
    -- to fit.
    local scrollFrame = CreateFrame("ScrollFrame", frameName.."ScrollFrame", overviewFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", overviewFrame, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", overviewFrame, "BOTTOMRIGHT", -10, 12)

    -- Mouse wheel scrolls; the scrollbar is forced hidden (the width goes to the icons).
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

    -- Tab 2 with nothing learned
    overviewFrame.emptyText = overviewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    overviewFrame.emptyText:SetPoint("CENTER", overviewFrame, "CENTER", -10, -10)
    overviewFrame.emptyText:SetText(RA_L["portal_overview_empty"])
    overviewFrame.emptyText:Hide()

    -- Bag changes (keystone highlight) and new teleports (SPELLS_CHANGED) only matter
    -- while open; OnShow also covers a Show deferred until after combat.
    overviewFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    overviewFrame:SetScript("OnShow", function(self)
        self:RegisterEvent("BAG_UPDATE_DELAYED")
        self:RegisterEvent("SPELLS_CHANGED")
        RA.RefreshPortalOverview()
    end)
    overviewFrame:SetScript("OnHide", function(self)
        self:UnregisterEvent("BAG_UPDATE_DELAYED")
        self:UnregisterEvent("SPELLS_CHANGED")
    end)
    overviewFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            RA.SafeSetShown(self, false)
        elseif event == "BAG_UPDATE_DELAYED" or event == "SPELLS_CHANGED" then
            RA.RefreshPortalOverview()
        end
    end)
end

-- Layout

local function HideAllButtons()
    usedButtons = 0
    for _, btn in pairs(portalPool) do
        RA.SafeSetShown(btn, false)
        btn:ClearAllPoints()
    end
    for _, fs in pairs(headerPool) do
        fs:Hide()
        fs:ClearAllPoints()
    end
end

local function PlaceHeader(index, y, text)
    local header = AcquireHeader(index, overviewFrame.content)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", overviewFrame.content, "TOPLEFT", 0, y)
    header:SetText(text)
    header:Show()
end

local function PlaceButton(btn, entry, isKnown, x, y, ownedLfgID)
    btn.nameKey = entry.nameKey
    RA.SetPortalSpell(btn, entry.spellID)
    RA.UpdatePortalButtonState(btn, isKnown, 0.4)
    btn.keyBorder:SetShown(entry.lfgID ~= nil and entry.lfgID == ownedLfgID)

    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", overviewFrame.content, "TOPLEFT", x, y)
    RA.SafeSetShown(btn, true)
end

-- Places `entries` as icon rows of BUTTONS_PER_ROW (last row centered), first row at y.
-- allKnown: all entries are learned spells (tab 2), else each is checked. Returns the height.
local function PlaceRows(entries, y, ownedLfgID, allKnown)
    for i, entry in ipairs(entries) do
        usedButtons = usedButtons + 1
        local btn = AcquireButton(usedButtons, overviewFrame.content)

        local row = math.floor((i - 1) / BUTTONS_PER_ROW)
        local col = (i - 1) % BUTTONS_PER_ROW
        local rowCount = math.min(BUTTONS_PER_ROW, #entries - row * BUTTONS_PER_ROW)
        local rowWidth = (rowCount * BUTTON_SIZE) + ((rowCount - 1) * BUTTON_GAP)
        local startX = (CONTENT_WIDTH - rowWidth) / 2

        PlaceButton(btn, entry, allKnown or C_SpellBook.IsSpellInSpellBook(entry.spellID),
            startX + col * ROW_STEP, y - row * ROW_STEP, ownedLfgID)
    end
    return math.ceil(#entries / BUTTONS_PER_ROW) * ROW_STEP
end

-- Tab 1: one season header, then all entries.
local function LayoutFlatButtons(entries)
    HideAllButtons()

    -- Same style and pool slot as tab 2's headers: rows start at the same Y in both tabs.
    PlaceHeader(1, 0, string.format(RA_L["portal_overview_current_season"] or "Season %d", RA.ACTIVE_SEASON))

    if #entries == 0 then
        overviewFrame.emptyText:Show()
        overviewFrame.content:SetHeight(HEADER_HEIGHT)
        return
    end
    overviewFrame.emptyText:Hide()

    local usedHeight = PlaceRows(entries, -HEADER_HEIGHT, RA.GetOwnedKeystone(), false)
    overviewFrame.content:SetHeight(HEADER_HEIGHT + usedHeight)
end

-- Tab 2: one header per expansion, its portals in rows below (known spells only).
local function LayoutGroupedButtons(groups)
    HideAllButtons()

    if #groups == 0 then
        overviewFrame.emptyText:Show()
        overviewFrame.content:SetHeight(1)
        return
    end
    overviewFrame.emptyText:Hide()

    local ownedLfgID = RA.GetOwnedKeystone()
    local y = 0

    for i, group in ipairs(groups) do
        PlaceHeader(i, y, RA_L["expansion_"..group.expansion] or group.expansion)
        y = y - HEADER_HEIGHT
        y = y - PlaceRows(group.entries, y, ownedLfgID, true) - HEADER_GAP
    end

    overviewFrame.content:SetHeight(-y)
end

-- Public API

function RA.RefreshPortalOverview()
    if not overviewFrame or not overviewFrame:IsShown() then return end
    -- Secure buttons: no re-layout in combat (a deferred Show refreshes via OnShow).
    if InCombatLockdown() then return end

    if activeTab == 1 then
        local entries = CollectEntries({}, RA.DUNGEONS[RA.ACTIVE_SEASON] or {}, "midnight")
        LayoutFlatButtons(RA.SortByLabel(entries, EntryLabel))
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
    activeTab = 1
    PanelTemplates_SetTab(overviewFrame, 1)
    RA.SafeSetShown(overviewFrame, true)  -- OnShow lays it out
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

-- /rat: open/close

SLASH_ROLLAWAYPORTALS1 = "/rat"
SlashCmdList["ROLLAWAYPORTALS"] = function()
    RA.TogglePortalOverview()
end

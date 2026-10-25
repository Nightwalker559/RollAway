-- RollAway - Modules/PortalOverview.lua
-- RollAway's own portal frame, an alternative to BigWigs/Details Keystones. Manual
-- only (/rat); Group Finder joins are handled by TeleportReminder.lua.
-- Tabs: 1) current season (RA.DUNGEONS[RA.ACTIVE_SEASON]), same look as the join
-- reminder; 2) all learned dungeon teleports (RA.DUNGEONS[*] + LegacyDungeonTeleports),
-- grouped by expansion, unlearned ones and empty groups hidden; 3) options (icon size,
-- icons per row, short name labels, group keystones; RollAwayDB.portal*).
-- Tab 1 can list the group's keystones below the portals (GroupKeys.lua).

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

local buttonGap    = 2   -- between the icon edges, set by ApplyMetrics()
local HEADER_HEIGHT   = 18
local HEADER_GAP      = 4

local MIN_FRAME_WIDTH = 300  -- the three tabs need the room
local MARGINS         = 20   -- both sides together (the scrollbar is hidden)

-- Icon size / row layout from the saved options (clamped); refreshed by ApplyMetrics().
local buttonSize, perRow, labelSize = 48, 4, 10
local rowStep, contentWidth, frameWidth = 56, 240, MIN_FRAME_WIDTH

local function Clamp(value, lo, hi, default)
    value = tonumber(value) or default
    return math.max(lo, math.min(hi, math.floor(value)))
end

-- Tab 2 header order, newest first.
local CATEGORY_ORDER = {
    "midnight", "tww", "dragonflight", "shadowlands", "bfa", "legion",
    "wod", "mop", "cataclysm", "wrath", "tbc",
}

-- State

local overviewFrame
local settingsPanel          -- tab 3
local activeTab   = 1
local TAB_SETTINGS = 3

local function ApplyMetrics()
    local db = RollAwayDB or {}
    buttonSize = Clamp(db.portalIconSize, 32, 64, 48)
    perRow     = Clamp(db.portalPerRow, 3, 8, 4)
    labelSize  = Clamp(db.portalLabelSize, 8, 16, 10)
    buttonGap  = Clamp(db.portalGap, 0, 16, 2)
    rowStep    = buttonSize + buttonGap
    local rowWidth = perRow * buttonSize + (perRow - 1) * buttonGap
    -- Tab 3 keeps the minimum width so the sliders stay put while they are dragged.
    frameWidth   = math.max(MIN_FRAME_WIDTH, rowWidth + MARGINS + 8)
    contentWidth = frameWidth - MARGINS
    if overviewFrame then
        -- Square; content that does not fit scrolls.
        local size = activeTab == TAB_SETTINGS and MIN_FRAME_WIDTH or frameWidth
        overviewFrame:SetSize(size, size)
        overviewFrame.content:SetWidth(contentWidth)
    end
end
local portalPool  = {}   -- icon button pool
local headerPool  = {}   -- category header pool
local keyRowPool  = {}   -- group key row pool: { name, level, dungeon } font strings
local usedButtons = 0    -- pool slots used in the current layout pass

local KEY_ROW_HEIGHT = 15
local KEY_LEVEL_X    = 112   -- columns of a key row: name | +level | dungeon
local KEY_DUNGEON_X  = 146
local GROUP_UNITS    = { "player", "party1", "party2", "party3", "party4" }

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

-- The group's shared keystones, highest level first (GroupKeys.lua; members without a key left out).
local function CollectGroupKeys()
    local rows = {}
    for _, unit in ipairs(GROUP_UNITS) do
        local key = UnitExists(unit) and RA.GetGroupKey(unit)
        if key and key.level > 0 then
            local _, class = UnitClass(unit)
            rows[#rows + 1] = { name = UnitName(unit), class = class, level = key.level, mapID = key.mapID }
        end
    end
    table.sort(rows, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)
    return rows
end

local function KeyDungeonName(mapID)
    for _, d in ipairs(RA.DUNGEONS[RA.ACTIVE_SEASON] or {}) do
        if d.cmID == mapID then return RA_L["dungeon_"..d.key] or d.key end
    end
    return C_ChallengeMode.GetMapUIInfo(mapID)
end

-- Pools

local function AcquireButton(i, parent)
    local btn = portalPool[i]
    if btn then return btn end

    btn = RA.CreatePortalButton("RollAwayPortalOverviewButton"..i, parent, buttonSize)

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

local function AcquireKeyRow(i, parent)
    local row = keyRowPool[i]
    if row then return row end
    local function NewText()
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    row = { name = NewText(), level = NewText(), dungeon = NewText() }
    keyRowPool[i] = row
    return row
end

-- Group keys: only while the option is on, in a party (LibKeystone shares in the party only).
local function ShowGroupKeys()
    return RollAwayDB.portalGroupKeys and IsInGroup() and not IsInRaid()
end

local function RequestGroupKeys()
    if ShowGroupKeys() then RA.RequestGroupKeys() end
end

-- Keys arrive one message per member and the roster changes in bursts: one refresh per frame.
local refreshPending = false
local function QueueRefresh()
    if refreshPending then return end
    refreshPending = true
    RunNextFrame(function()
        refreshPending = false
        RA.RefreshPortalOverview()
    end)
end

RA.OnGroupKeys(function()
    if RollAwayDB and RollAwayDB.portalGroupKeys then QueueRefresh() end
end)

-- Frame creation

-- Tab 3: the options widgets of the options window (RA.OptionsUI, loaded later but
-- available by the time the frame is first opened). Every change saves to the profile and
-- re-lays-out; the frame resizes when you switch back to a portal tab.
local function CreateSettingsPanel()
    local UI = RA.OptionsUI
    settingsPanel = CreateFrame("Frame", nil, overviewFrame)
    settingsPanel:SetPoint("TOPLEFT", overviewFrame, "TOPLEFT", 10, -36)
    settingsPanel:SetPoint("BOTTOMRIGHT", overviewFrame, "BOTTOMRIGHT", -10, 12)
    settingsPanel:Hide()

    local cb = UI.MakeCB(settingsPanel, RA_L["portal_cfg_labels"], RollAwayDB.portalLabels ~= false,
        function(checked)
            RollAwayDB.portalLabels = checked
            RA.RefreshPortalOverview()
        end, MIN_FRAME_WIDTH - MARGINS)
    cb.frame:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 0, 0)

    local keysCB = UI.MakeCB(settingsPanel, RA_L["portal_cfg_groupkeys"], RollAwayDB.portalGroupKeys == true,
        function(checked)
            RollAwayDB.portalGroupKeys = checked
            RequestGroupKeys()
            RA.RefreshPortalOverview()
        end, MIN_FRAME_WIDTH - MARGINS)
    keysCB.frame:SetPoint("TOPLEFT", cb.frame, "BOTTOMLEFT", 0, -2)

    local defaults = RA.defaults.profile
    local sliders  = {}   -- [dbKey] = slider frame, for the default button
    local function AddSlider(anchor, dbKey, min, max, step, labelKey)
        local slider = UI.MakeValueSlider(settingsPanel, anchor, 0, -4, {
            min = min, max = max, step = step, value = Clamp(RollAwayDB[dbKey], min, max, defaults[dbKey]),
            formatLabel = function(v) return string.format(RA_L[labelKey], v) end,
            onChange = function(v)
                RollAwayDB[dbKey] = v
                RA.RefreshPortalOverview()
            end,
        })
        slider:SetWidth(MIN_FRAME_WIDTH - MARGINS)
        sliders[dbKey] = slider
        return slider
    end
    local s1 = AddSlider(keysCB.frame, "portalIconSize",  32, 64, 2, "portal_cfg_iconsize")
    local s2 = AddSlider(s1,       "portalGap",        0, 16, 1, "portal_cfg_gap")
    local s3 = AddSlider(s2,       "portalPerRow",     3,  8, 1, "portal_cfg_perrow")
    AddSlider(s3,                  "portalLabelSize",  8, 16, 1, "portal_cfg_labelsize")

    -- Back to the defaults: the sliders' own callbacks save the values.
    local reset = UI.MakeSkinnedButton(settingsPanel, RA_L["portal_cfg_default"], 100)
    reset:SetPoint("BOTTOMLEFT", settingsPanel, "BOTTOMLEFT", 0, 0)
    RA.Skin.LiftedButton(reset, RA.Skin.ClassColor())
    reset:SetScript("OnClick", function()
        RollAwayDB.portalLabels = defaults.portalLabels
        cb:SetValue(defaults.portalLabels)
        RollAwayDB.portalGroupKeys = defaults.portalGroupKeys
        keysCB:SetValue(defaults.portalGroupKeys)
        for dbKey, slider in pairs(sliders) do
            RollAwayDB[dbKey] = defaults[dbKey]
            slider.Slider:SetValue(defaults[dbKey])
        end
        RA.RefreshPortalOverview()
    end)
end

local function SelectTab(index)
    activeTab = index
    PanelTemplates_SetTab(overviewFrame, index)
    -- Every tab starts at the top (the other tab's scroll position would be past the end here).
    overviewFrame.scrollFrame:SetVerticalScroll(0)
    RA.RefreshPortalOverview()
end

local function CreateOverviewFrame()
    if overviewFrame then return end

    ApplyMetrics()
    overviewFrame = RA.CreatePanelWindow("RollAwayPortalOverviewFrame", UIParent, frameWidth, frameWidth,
        RA_L["portal_overview_title"])
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

    -- Tabs (Blizzard tab template; names must be "<frameName>Tab<index>" for
    -- PanelTemplates_UpdateTabs).
    local frameName = overviewFrame:GetName()
    local tabLabels = {
        RA_L["portal_overview_tab_season"],
        RA_L["portal_overview_tab_dungeons"],
        RA_L["portal_overview_tab_settings"],
    }
    overviewFrame.numTabs = #tabLabels
    local prevTab
    local tabs = {}
    for i, label in ipairs(tabLabels) do
        local tab = CreateFrame("Button", frameName.."Tab"..i, overviewFrame, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(label)
        PanelTemplates_TabResize(tab, 8)
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", overviewFrame, "BOTTOMLEFT", 10, 2)
        end
        tab:SetScript("OnClick", function(self) SelectTab(self:GetID()) end)
        prevTab = tab
        tabs[i] = tab
    end
    RA.Skin.TabRow(tabs)
    PanelTemplates_SetTab(overviewFrame, 1)

    -- Scrollable content: icons and headers are anchored inside `content`, which grows
    -- to fit.
    -- Mouse wheel scrolls, no scrollbar (the width goes to the icons).
    local scrollFrame = CreateFrame("ScrollFrame", frameName.."ScrollFrame", overviewFrame)
    scrollFrame:SetPoint("TOPLEFT", overviewFrame, "TOPLEFT", 10, -34)
    scrollFrame:SetPoint("BOTTOMRIGHT", overviewFrame, "BOTTOMRIGHT", -10, 12)

    local content = CreateFrame("Frame", frameName.."Content", scrollFrame)
    content:SetSize(contentWidth, 1)
    scrollFrame:SetScrollChild(content)
    overviewFrame.content     = content
    overviewFrame.scrollFrame = scrollFrame

    CreateSettingsPanel()

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

    -- Bag changes (keystone highlight), new teleports (SPELLS_CHANGED) and group changes
    -- (key list) only matter while open; OnShow also covers a Show deferred until after combat.
    overviewFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    overviewFrame:HookScript("OnShow", function(self)
        self:RegisterEvent("BAG_UPDATE_DELAYED")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        RequestGroupKeys()
        RA.RefreshPortalOverview()
    end)
    overviewFrame:SetScript("OnHide", function(self)
        self:UnregisterEvent("BAG_UPDATE_DELAYED")
        self:UnregisterEvent("SPELLS_CHANGED")
        self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    end)
    overviewFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            RA.SafeSetShown(self, false)
        elseif event == "BAG_UPDATE_DELAYED" or event == "SPELLS_CHANGED" then
            RA.RefreshPortalOverview()
        elseif event == "GROUP_ROSTER_UPDATE" then
            RequestGroupKeys()
            QueueRefresh()
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
    for _, row in pairs(keyRowPool) do
        for _, fs in pairs(row) do
            fs:Hide()
            fs:ClearAllPoints()
        end
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
    btn:SetSize(buttonSize, buttonSize)
    RA.SetPortalLabel(btn, entry.key, labelSize)
    RA.SetPortalSpell(btn, entry.spellID)
    RA.UpdatePortalButtonState(btn, isKnown, 0.4)
    -- Gold highlight while this dungeon's keystone is in the bags.
    RA.SetPortalKeyHighlight(btn, entry.lfgID ~= nil and entry.lfgID == ownedLfgID)

    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", overviewFrame.content, "TOPLEFT", x, y)
    RA.SafeSetShown(btn, true)
end

-- Places `entries` as icon rows of `perRow` (last row centered), first row at y.
-- allKnown: all entries are learned spells (tab 2), else each is checked. Returns the height.
local function PlaceRows(entries, y, ownedLfgID, allKnown)
    for i, entry in ipairs(entries) do
        usedButtons = usedButtons + 1
        local btn = AcquireButton(usedButtons, overviewFrame.content)

        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        local rowCount = math.min(perRow, #entries - row * perRow)
        local rowWidth = (rowCount * buttonSize) + ((rowCount - 1) * buttonGap)
        local startX = (contentWidth - rowWidth) / 2

        PlaceButton(btn, entry, allKnown or C_SpellBook.IsSpellInSpellBook(entry.spellID),
            startX + col * rowStep, y - row * rowStep, ownedLfgID)
    end
    return math.ceil(#entries / perRow) * rowStep
end

-- One key row at y: class-colored name, "+level", dungeon.
local function PlaceKeyRow(i, y, entry)
    local content = overviewFrame.content
    local row = AcquireKeyRow(i, content)
    local color = RAID_CLASS_COLORS[entry.class]
    row.name:SetText(color and color:WrapTextInColorCode(entry.name) or entry.name)
    row.level:SetText("|cffFFD100+"..entry.level.."|r")
    row.dungeon:SetText(KeyDungeonName(entry.mapID) or "")
    row.name:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    row.name:SetWidth(KEY_LEVEL_X - 6)
    row.level:SetPoint("TOPLEFT", content, "TOPLEFT", KEY_LEVEL_X, y)
    row.level:SetWidth(KEY_DUNGEON_X - KEY_LEVEL_X)
    row.dungeon:SetPoint("TOPLEFT", content, "TOPLEFT", KEY_DUNGEON_X, y)
    row.dungeon:SetWidth(contentWidth - KEY_DUNGEON_X)
    row.name:Show()
    row.level:Show()
    row.dungeon:Show()
end

-- Header and key rows from y down (a grey hint when none arrived). Returns the height.
local function PlaceGroupKeys(y)
    PlaceHeader(2, y, RA_L["portal_groupkeys_header"])
    y = y - HEADER_HEIGHT
    local rows = CollectGroupKeys()
    if #rows == 0 then
        local row = AcquireKeyRow(1, overviewFrame.content)
        row.name:SetText("|cff999999"..RA_L["portal_groupkeys_none"].."|r")
        row.name:SetPoint("TOPLEFT", overviewFrame.content, "TOPLEFT", 0, y)
        row.name:SetWidth(contentWidth)
        row.name:Show()
        return HEADER_HEIGHT + KEY_ROW_HEIGHT
    end
    for i, entry in ipairs(rows) do
        PlaceKeyRow(i, y - (i - 1) * KEY_ROW_HEIGHT, entry)
    end
    return HEADER_HEIGHT + #rows * KEY_ROW_HEIGHT
end

-- Tab 1: one season header, then all entries, then the group's keys (option).
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

    local height = HEADER_HEIGHT + PlaceRows(entries, -HEADER_HEIGHT, RA.GetOwnedKeystone(), false)
    if ShowGroupKeys() then
        height = height + HEADER_GAP + PlaceGroupKeys(-(height + HEADER_GAP))
    end
    overviewFrame.content:SetHeight(height)
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

    -- Tab 3 shows the options instead of the scrolling portal list.
    local isSettings = activeTab == TAB_SETTINGS
    RA.SafeSetShown(overviewFrame.scrollFrame, not isSettings)
    RA.SafeSetShown(settingsPanel, isSettings)
    ApplyMetrics()
    if isSettings then
        HideAllButtons()
        overviewFrame.emptyText:Hide()
        return
    end

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
    overviewFrame.scrollFrame:SetVerticalScroll(0)
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

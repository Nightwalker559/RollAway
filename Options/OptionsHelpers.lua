-- RollAway - Options/OptionsHelpers.lua
-- Shared UI builder helpers used by Options.lua and Options/OptionsQoL.lua.
-- Extracted from Options.lua (no behavior change) so both files can reuse
-- the same widget builders instead of duplicating them.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

-- Resolved once at file load (Libs load before Options per the .toc),
-- reused by every checkbox/slider/dropdown instead of repeated LibStub calls.
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

------------------------------------------------------------------------
-- Grid layout constants (shared across all tabs)
------------------------------------------------------------------------
local ENTRY_W = 255
local ENTRY_H = 26
local COL_GAP = 24
local ROW_GAP = 6

------------------------------------------------------------------------
-- UI helpers
------------------------------------------------------------------------

local function MakeSectionHeader(parent, anchorFrame, anchorOffsetY, text)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    lbl:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, anchorOffsetY)
    lbl:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetWidth(560)
    line:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    return lbl, line
end

-- Creates a self-contained AceGUI checkbox (own textures per instance, no
-- ElvUI template-skin dependency). Caller positions it via cb.frame:SetPoint().
-- Falls back to nil (with a debug warning) if AceGUI somehow isn't available;
-- AceGUI-3.0 is hard-bundled in the .toc so this should never trigger live.
local function MakeCB(parent, label, checked, onChange, widthOverride)
    if not AceGUI then
        DBG("WARNING: AceGUI-3.0 unavailable - checkbox '"..tostring(label).."' skipped")
        return nil
    end
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(label)
    cb:SetValue(checked)
    cb:SetWidth(widthOverride or (24 + (cb.text:GetStringWidth() or 200) + 10))
    cb:SetCallback("OnValueChanged", function(widget, _, value)
        if onChange then onChange(value) end
        -- Re-neutralize color on every click too - ElvUI's AceGUI skin
        -- hook likely re-applies class color on SetValue, which runs
        -- before this callback fires.
        if RA.ForceCheckboxDefaultColor then RA.ForceCheckboxDefaultColor(cb) end
    end)
    cb.frame:SetParent(parent)
    cb.frame:ClearAllPoints()
    cb.frame:Show()
    -- Neutralize ElvUI's global AceGUI skin (class-colored checkmark) back
    -- to ElvUI's own default accent color, if ElvUI is loaded. Re-applied
    -- one frame later too, in case ElvUI's own skin hook runs after ours,
    -- and tracked so it can be re-applied again on every panel OnShow.
    if RA.ForceCheckboxDefaultColor then
        RA.ForceCheckboxDefaultColor(cb)
        C_Timer.After(0, function() RA.ForceCheckboxDefaultColor(cb) end)
        RA.AllCheckboxes = RA.AllCheckboxes or {}
        table.insert(RA.AllCheckboxes, cb)
    end
    return cb
end

local function MakeHintText(parent, anchorLine, text)
    local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", anchorLine, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(560)
    hint:SetJustifyH("LEFT")
    hint:SetNonSpaceWrap(true)
    hint:SetText(text)
    return hint
end

-- Lays out a row of checkboxes side by side below anchorFrame. Returns the
-- row's own invisible container frame (full width), suitable as a wide
-- anchor for whatever comes next (e.g. MakeSeasonTabs), plus a list of the
-- individual AceGUI checkbox widgets (for callers that need to e.g. disable
-- them as a group later).
local function MakeCheckboxRow(parent, anchorFrame, items, dbTable, onClickKeyOf, gap)
    gap = gap or 20
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -8)
    row:SetSize(560, 24)

    local checkboxes = {}
    local prevFrame = nil
    for _, item in ipairs(items) do
        local capturedKey = item.key
        local cb = MakeCB(row, item.label, dbTable and dbTable[item.key], function(checked)
            onClickKeyOf(capturedKey, checked)
        end)
        if cb then
            if prevFrame then
                cb.frame:SetPoint("LEFT", prevFrame, "RIGHT", gap, 0)
            else
                cb.frame:SetPoint("LEFT", row, "LEFT", 0, 0)
            end
            prevFrame = cb.frame
            table.insert(checkboxes, cb)
        end
    end
    return row, checkboxes
end

-- Creates season sub-tabs inside a parent panel, anchored below anchorFrame.
-- Returns: panels table (panels[key] = contentFrame), tabRowFrame
local function MakeSeasonTabs(S, parent, anchorFrame, seasons)
    local TAB_H   = 22
    local TAB_GAP = 4
    local panels  = {}
    local buttons = {}
    local buttonOrder = {}

    local classColor = S and (RAID_CLASS_COLORS and RAID_CLASS_COLORS[select(2, UnitClass("player"))])

    local GOLD = { r = 0.85, g = 0.73, b = 0.25 }
    local GRAY = { r = 0.5,  g = 0.5,  b = 0.5  }

    -- devOnly season tabs (S1/S3) gate on debug mode; checkbox is already dev-only.
    local devDebugActive = RollAwayDB and RollAwayDB.debug

    -- Tab row frame
    local tabRow = CreateFrame("Frame", nil, parent)
    tabRow:SetPoint("TOPLEFT",  anchorFrame, "BOTTOMLEFT",  0, -10)
    tabRow:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -10)
    tabRow:SetHeight(TAB_H)

    local function ShowSeason(key)
        for k, panel in pairs(panels) do panel:SetShown(k == key) end
        for k, btn in pairs(buttons) do
            if k == key then
                if btn.RA_ApplyActive then btn.RA_ApplyActive()
                else
                    local t = btn:GetFontString()
                    if t then t:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1) end
                end
            else
                if btn.RA_ApplyInactive then btn.RA_ApplyInactive()
                else
                    local t = btn:GetFontString()
                    if t then t:SetTextColor(GRAY.r, GRAY.g, GRAY.b, 1) end
                end
            end
        end
    end

    -- Re-anchors visible tabs left-to-right, closing gaps from hidden ones.
    local function ReflowTabButtons()
        local prevVisible = nil
        for _, btn in ipairs(buttonOrder) do
            if btn:IsShown() then
                btn:ClearAllPoints()
                if prevVisible then
                    btn:SetPoint("LEFT", prevVisible, "RIGHT", TAB_GAP, 0)
                else
                    btn:SetPoint("LEFT", tabRow, "LEFT", 0, 0)
                end
                prevVisible = btn
            end
        end
    end

    for _, s in ipairs(seasons) do
        local btn = CreateFrame("Button", nil, tabRow, "UIPanelButtonTemplate")
        btn:SetSize(100, TAB_H)
        btn:SetText(s.label)

        -- OnClick must be set BEFORE ElvSkinTab so ElvUI's HandleButton doesn't clobber it
        local key = s.key
        btn:SetScript("OnClick", function() ShowSeason(key) end)
        buttons[key] = btn
        buttonOrder[#buttonOrder + 1] = btn

        -- Apply ElvUI skin or default styling
        if S and RA.ElvSkinTab then
            RA.ElvSkinTab(btn, panels, s.key, classColor)
        end

        -- Hide season sub-tabs when Bonus Rolls are disabled
        if not RA.BONUS_ROLLS_ENABLED then btn:Hide() end

        -- Track season tab buttons so the debug checkbox can enable/disable all.
        RA.SeasonTabButtons = RA.SeasonTabButtons or {}
        table.insert(RA.SeasonTabButtons, btn)
        if devDebugActive then btn:Enable() else btn:Disable() end

        -- Hide devOnly season sub-tabs (e.g. legacy S1 / unreleased S3)
        -- unless this is a dev/tester char with debug mode enabled.
        if s.devOnly then
            if not devDebugActive then btn:Hide() end
            RA.DevOnlyTabButtons = RA.DevOnlyTabButtons or {}
            table.insert(RA.DevOnlyTabButtons, btn)
        end

        -- Content panel
        local panel = CreateFrame("Frame", nil, tabRow)
        panel:SetPoint("TOPLEFT",  tabRow, "BOTTOMLEFT",  0, -10)
        panel:SetPoint("TOPRIGHT", tabRow, "BOTTOMRIGHT", 0, -10)
        panel:SetHeight(500)
        panel:SetClipsChildren(true)
        panel:Hide()
        panels[key] = panel
    end

    ReflowTabButtons()

    -- Register so the debug checkbox can re-flow every season tab row
    -- (Dungeons + Raids) after toggling S1/S3 visibility.
    RA.SeasonTabReflows = RA.SeasonTabReflows or {}
    table.insert(RA.SeasonTabReflows, ReflowTabButtons)

    local devOnlyKeys = {}
    local defaultKey

    for _, s in ipairs(seasons) do
        if s.devOnly then devOnlyKeys[s.key] = true end
        if s.default then defaultKey = s.key end
    end

    -- Fall back to default season if debug turns off while on a devOnly tab.
    local function EnsureValidSeasonSelected()
        if RollAwayDB and RollAwayDB.debug then return end
        for k, panel in pairs(panels) do
            if devOnlyKeys[k] and panel:IsShown() then
                if defaultKey then ShowSeason(defaultKey) end
                return
            end
        end
    end

    RA.SeasonTabDebugChecks = RA.SeasonTabDebugChecks or {}
    table.insert(RA.SeasonTabDebugChecks, EnsureValidSeasonSelected)

    -- Show default
    for _, s in ipairs(seasons) do
        if s.default then ShowSeason(s.key) end
    end

    return panels, tabRow
end

local function MakeCheckboxGrid(parent, anchorFrame, anchorOffsetY, items, dbTable, keyPrefix)
    local leftEntries = {}
    local checkboxes  = {}
    for i, item in ipairs(items) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local entry = CreateFrame("Frame", nil, parent)
        entry:SetSize(ENTRY_W, ENTRY_H)
        if col == 0 then
            local yOff   = (row == 0) and anchorOffsetY or -ROW_GAP
            local anchor = (row == 0) and anchorFrame or leftEntries[row - 1]
            entry:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
            leftEntries[row] = entry
        else
            entry:SetPoint("LEFT", leftEntries[row], "RIGHT", COL_GAP, 0)
        end
        local capturedKey = item.key
        local cb = MakeCB(entry, RA_L[keyPrefix..item.key], dbTable[item.key], function(checked)
            dbTable[capturedKey] = checked
        end)
        if cb then
            cb.frame:SetPoint("LEFT", entry, "LEFT", 0, 0)
            table.insert(checkboxes, cb)
        end
    end
    return leftEntries, checkboxes
end

-- Renders a vertical stack of grouped boss-checkbox sections (section
-- header + 2-column checkbox grid per raid) below anchorFrame, flowing
-- downward. Sections with zero bosses are skipped entirely.
-- sections: { { key = "voidspire", bosses = { {key=..}, ... } }, ... }
-- labelSuffixes: optional { [sectionKey] = "|cff888888(12.0.7)|r", ... }
-- Extracted from Options.lua where Season 1 and Season 2 raid tabs each
-- had their own copy of this exact loop (no behavior change).
local function MakeBossSectionGrid(parent, anchorFrame, sections, dbTable, labelSuffixes)
    local prevAnchor  = anchorFrame
    local prevOffsetY = -8
    for _, section in ipairs(sections) do
        if #section.bosses > 0 then
            local secLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            secLabel:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, prevOffsetY)
            local labelText = RA_L["raid_"..section.key]
            if labelSuffixes and labelSuffixes[section.key] then
                labelText = labelText.." "..labelSuffixes[section.key]
            end
            secLabel:SetText(labelText)

            local leftEntries = {}
            for i, b in ipairs(section.bosses) do
                local col = (i - 1) % 2
                local row = math.floor((i - 1) / 2)
                local entry = CreateFrame("Frame", nil, parent)
                entry:SetSize(ENTRY_W, ENTRY_H)
                if col == 0 then
                    local yOff   = (row == 0) and -8 or -ROW_GAP
                    local anchor = (row == 0) and secLabel or leftEntries[row - 1]
                    entry:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
                    leftEntries[row] = entry
                else
                    entry:SetPoint("LEFT", leftEntries[row], "RIGHT", COL_GAP, 0)
                end
                local capturedKey = b.key
                local isPending = b.pendingTest
                local labelText = RA_L["boss_"..b.key]
                if isPending then
                    labelText = labelText .. " |cff888888(coming soon)|r"
                    dbTable[capturedKey] = false
                end
                local cb = MakeCB(entry, labelText, dbTable[b.key], function(checked)
                    dbTable[capturedKey] = checked
                end)
                if cb then
                    cb.frame:SetPoint("LEFT", entry, "LEFT", 0, 0)
                    if isPending then cb:SetDisabled(true) end
                end
                if i == #section.bosses then
                    prevAnchor  = (col == 0) and entry or leftEntries[row]
                    prevOffsetY = -16
                end
            end
        end
    end
    return prevAnchor, prevOffsetY
end

------------------------------------------------------------------------
-- Public exports - consumed by Options.lua and Options/OptionsQoL.lua
------------------------------------------------------------------------
RA.OptionsUI = {
    AceGUI            = AceGUI,
    ENTRY_W           = ENTRY_W,
    ENTRY_H           = ENTRY_H,
    COL_GAP           = COL_GAP,
    ROW_GAP           = ROW_GAP,
    MakeSectionHeader = MakeSectionHeader,
    MakeCB            = MakeCB,
    MakeHintText      = MakeHintText,
    MakeCheckboxRow   = MakeCheckboxRow,
    MakeSeasonTabs    = MakeSeasonTabs,
    MakeCheckboxGrid  = MakeCheckboxGrid,
    MakeBossSectionGrid = MakeBossSectionGrid,
}

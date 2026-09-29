-- RollAway - Options/OptionsHelpers.lua
-- Shared UI builder helpers used by Options.lua, Options/OptionsQoL.lua and
-- Options/OptionsProfile.lua.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

-- Resolved once at file load (Libs load before Options per the .toc; the
-- AceGUI-3.0 checkbox/dropdown/slider widgets are bundled with the addon).
local AceGUI = LibStub("AceGUI-3.0")

------------------------------------------------------------------------
-- Grid layout constants (shared across all tabs)
------------------------------------------------------------------------
local ENTRY_W = 255
local ENTRY_H = 26
local COL_GAP = 24
local ROW_GAP = 6

-- Tab label colors (active / inactive), also used by ElvUI_Skin.lua.
local GOLD = { r = 0.85, g = 0.73, b = 0.25 }
local GRAY = { r = 0.5,  g = 0.5,  b = 0.5  }

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
local function MakeCB(parent, label, checked, onChange, widthOverride)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(label)
    cb:SetValue(checked)
    cb:SetWidth(widthOverride or (24 + (cb.text:GetStringWidth() or 200) + 10))
    cb:SetCallback("OnValueChanged", function(_, _, value)
        if onChange then onChange(value) end
    end)
    cb.frame:SetParent(parent)
    cb.frame:ClearAllPoints()
    cb.frame:Show()
    return cb
end

-- Gray descriptive text below a checkbox/dropdown/label - the addon's most
-- common options-panel element (~20 uses). Anchor, offsets and width are
-- passed through as-is (they vary per call site), so this only removes the
-- 5 repeated font/color/justify lines, never changes actual layout.
local function MakeInfoText(parent, anchor, xOffset, yOffset, width, text)
    local info = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    info:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    info:SetWidth(width)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.6, 0.6, 0.6, 1)
    info:SetText(text)
    return info
end

-- Checkbox bound to the boolean RollAwayDB[opts.dbKey], with its gray
-- description (opts.info) indented below it. The checkbox is placed
-- (xOffset, yOffset) below `anchor`, or at (xOffset, yOffset) from the
-- parent's top-left when anchor is nil. opts.onChange(checked) runs after
-- the setting is saved; opts.width overrides the checkbox width and
-- opts.infoWidth (default 400) the description's. Returns checkbox, info.
local function MakeToggle(parent, anchor, xOffset, yOffset, opts)
    local cb = MakeCB(parent, opts.label, RollAwayDB[opts.dbKey], function(checked)
        RollAwayDB[opts.dbKey] = checked
        if opts.onChange then opts.onChange(checked) end
    end, opts.width)
    if anchor then
        cb.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    else
        cb.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    end
    local info = MakeInfoText(parent, cb.frame, 20, -6, opts.infoWidth or 400, opts.info)
    return cb, info
end

-- Shell for an AceGUI Dropdown widget: create, blank label (the real label
-- is always a separate FontString placed above it), width, and position.
-- SetList/SetValue/SetCallback are left to the caller - some dropdowns fill
-- those in immediately, others (e.g. the profile switcher) refresh them
-- later from a separate function, so there's no one shape to share there.
local function MakeDropdown(parent, anchor, xOffset, yOffset, width)
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel("")
    dd:SetWidth(width)
    dd.frame:SetParent(parent)
    dd.frame:ClearAllPoints()
    dd.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    dd.frame:Show()
    return dd
end

-- AceGUI's layout pass calls Show() on a Slider's numeric editbox; hook
-- OnShow to keep it hidden (RollAway shows only the slider + its own value
-- label instead, not Ace's editbox).
local function HideSliderEditbox(slider)
    if not slider.editbox then return end
    slider.editbox:SetScript("OnShow", function(self) self:Hide() end)
    C_Timer.After(0, function() if slider.editbox then slider.editbox:Hide() end end)
end

-- AceGUI slider whose current value is part of its label, placed
-- (xOffset, yOffset) below `anchor`. opts: min, max, step, value,
-- formatLabel(value) -> label text, onChange(value) with the rounded value.
local function MakeValueSlider(parent, anchor, xOffset, yOffset, opts)
    local slider = AceGUI:Create("Slider")
    slider:SetLabel(opts.formatLabel(opts.value))
    slider:SetSliderValues(opts.min, opts.max, opts.step)
    slider:SetValue(opts.value)
    slider:SetWidth(220)
    slider:SetCallback("OnValueChanged", function(widget, _, value)
        local v = math.floor(value)
        widget:SetLabel(opts.formatLabel(v))
        opts.onChange(v)
    end)
    slider.frame:SetParent(parent)
    slider.frame:ClearAllPoints()
    slider.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    slider.frame:Show()
    HideSliderEditbox(slider)
    return slider
end

-- Creates a UIPanelButtonTemplate button and, if ElvUI's Skins module is
-- available, applies its HandleButton skin. HandleButton alone doesn't strip
-- the template's native textures, so the red/gray Blizzard look would still
-- show through underneath ElvUI's backdrop - clear those too.
local function MakeSkinnedButton(parent, label, width, S)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 110, 22)
    btn:SetText(label)
    if S and S.HandleButton then
        S:HandleButton(btn)
        btn:SetNormalTexture("")
        btn:SetPushedTexture("")
        btn:SetHighlightTexture("")
        btn:SetDisabledTexture("")
    end
    return btn
end

-- Blizzard OptionsSliderTemplate slider (label-less: the caller shows a live
-- value label above it instead) with optional min/max footer labels. Hides
-- the template's own text/low/high labels and wires OnValueChanged. Returns
-- slider, minLabel, maxLabel (the latter two nil if opts.minText wasn't given).
local function MakeTemplateSlider(parent, globalName, anchor, opts)
    local slider = CreateFrame("Slider", globalName, parent, "OptionsSliderTemplate")
    slider:SetWidth(opts.width or 200)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    slider:SetMinMaxValues(opts.min, opts.max)
    slider:SetValueStep(opts.step)
    slider:SetValue(opts.value)
    _G[globalName.."Text"]:Hide()
    _G[globalName.."Low"]:SetText("")
    _G[globalName.."High"]:SetText("")

    local minLabel, maxLabel
    if opts.minText then
        minLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
        minLabel:SetText(opts.minText)
        maxLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
        maxLabel:SetJustifyH("RIGHT")
        maxLabel:SetText(opts.maxText)
    end

    slider:SetScript("OnValueChanged", function(_, value) opts.onChange(value) end)
    if opts.S and opts.S.HandleSliderFrame then opts.S:HandleSliderFrame(slider) end
    return slider, minLabel, maxLabel
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

-- Wires an AceGUI-free scroll bar (UIPanelScrollFrameTemplate) so the bar
-- shows only when there is something to scroll (never with forceHide), and
-- skins it if ElvUI's Skins module (S) is given.
local function SetupScrollBar(scroll, bar, S, forceHide)
    if not bar then return end
    scroll:SetScript("OnScrollRangeChanged", function(_, _, yRange)
        local max = math.max(0, yRange or 0)
        bar:SetMinMaxValues(0, max)
        bar:SetValue(math.min(bar:GetValue(), max))
        bar:SetShown((not forceHide) and max > 1)
    end)
    scroll:SetScript("OnVerticalScroll", function(_, offset) bar:SetValue(offset) end)
    bar:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)

    local barName = bar:GetName()
    local upBtn   = _G[barName.."ScrollUpButton"]
    local downBtn = _G[barName.."ScrollDownButton"]
    if upBtn then
        upBtn:SetScript("OnClick", function()
            scroll:SetVerticalScroll(math.max(0, scroll:GetVerticalScroll() - 20))
        end)
    end
    if downBtn then
        downBtn:SetScript("OnClick", function()
            local _, max = bar:GetMinMaxValues()
            scroll:SetVerticalScroll(math.min(max, scroll:GetVerticalScroll() + 20))
        end)
    end
    if S and S.HandleScrollBar then S:HandleScrollBar(bar) end
    if forceHide then bar:Hide() end
end

-- Gold label for the active tab, gray for the others. ElvUI-skinned buttons
-- (RA.ElvSkinTab) supply their own RA_ApplyActive/RA_ApplyInactive, which
-- restyle the backdrop as well.
local function SetTabButtonActive(btn, active)
    if active and btn.RA_ApplyActive then
        btn.RA_ApplyActive()
    elseif not active and btn.RA_ApplyInactive then
        btn.RA_ApplyInactive()
    else
        local color = active and GOLD or GRAY
        local text = btn:GetFontString()
        if text then text:SetTextColor(color.r, color.g, color.b, 1) end
    end
end

-- Returns a function(key) that shows panels[key] (hiding the other panels)
-- and styles buttons[key] as the active tab. Both tables may still be
-- filled in after this call - they are only read when a tab is selected.
local function MakeTabSelector(panels, buttons)
    return function(key)
        for k, panel in pairs(panels) do panel:SetShown(k == key) end
        for k, btn in pairs(buttons) do SetTabButtonActive(btn, k == key) end
    end
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
        local key = item.key
        local cb = MakeCB(row, item.label, dbTable and dbTable[key], function(checked)
            onClickKeyOf(key, checked)
        end)
        if prevFrame then
            cb.frame:SetPoint("LEFT", prevFrame, "RIGHT", gap, 0)
        else
            cb.frame:SetPoint("LEFT", row, "LEFT", 0, 0)
        end
        prevFrame = cb.frame
        table.insert(checkboxes, cb)
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

    -- devOnly season tabs (S1/S3) gate on debug mode; checkbox is already dev-only.
    local devDebugActive = RollAwayDB and RollAwayDB.debug

    -- Tab row frame
    local tabRow = CreateFrame("Frame", nil, parent)
    tabRow:SetPoint("TOPLEFT",  anchorFrame, "BOTTOMLEFT",  0, -10)
    tabRow:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -10)
    tabRow:SetHeight(TAB_H)

    local ShowSeason = MakeTabSelector(panels, buttons)

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

    local devOnlyKeys = {}
    local defaultKey

    for _, s in ipairs(seasons) do
        local key = s.key
        local btn = CreateFrame("Button", nil, tabRow, "UIPanelButtonTemplate")
        btn:SetSize(100, TAB_H)
        btn:SetText(s.label)

        -- OnClick must be set BEFORE ElvSkinTab so ElvUI's HandleButton doesn't clobber it
        btn:SetScript("OnClick", function() ShowSeason(key) end)
        buttons[key] = btn
        buttonOrder[#buttonOrder + 1] = btn

        -- Apply ElvUI skin or default styling
        if S and RA.ElvSkinTab then
            RA.ElvSkinTab(btn, panels, key, classColor)
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
            devOnlyKeys[key] = true
            if not devDebugActive then btn:Hide() end
            RA.DevOnlyTabButtons = RA.DevOnlyTabButtons or {}
            table.insert(RA.DevOnlyTabButtons, btn)
        end
        if s.default then defaultKey = key end

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
    if defaultKey then ShowSeason(defaultKey) end

    return panels, tabRow
end

-- Creates entry `i` (1-based) of a two-column checkbox grid: even entries
-- start a new row below the previous row's left entry (or below
-- firstAnchor, firstOffsetY for the very first row), odd ones sit to the
-- right of theirs. `leftEntries[row]` (0-based) collects each row's left
-- entry - the caller reads leftEntries[math.floor((n - 1) / 2)] afterwards
-- to anchor whatever comes next below the grid.
local function CreateGridEntry(parent, i, leftEntries, firstAnchor, firstOffsetY)
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local entry = CreateFrame("Frame", nil, parent)
    entry:SetSize(ENTRY_W, ENTRY_H)
    if col == 0 then
        local yOff   = (row == 0) and firstOffsetY or -ROW_GAP
        local anchor = (row == 0) and firstAnchor or leftEntries[row - 1]
        entry:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        leftEntries[row] = entry
    else
        entry:SetPoint("LEFT", leftEntries[row], "RIGHT", COL_GAP, 0)
    end
    return entry
end

-- Places a checkbox inside a grid entry, bound to dbTable[key].
local function MakeGridCheckbox(entry, label, dbTable, key)
    local cb = MakeCB(entry, label, dbTable[key], function(checked)
        dbTable[key] = checked
    end)
    cb.frame:SetPoint("LEFT", entry, "LEFT", 0, 0)
    return cb
end

local function MakeCheckboxGrid(parent, anchorFrame, anchorOffsetY, items, dbTable, keyPrefix)
    local leftEntries = {}
    local checkboxes  = {}
    for i, item in ipairs(items) do
        local entry = CreateGridEntry(parent, i, leftEntries, anchorFrame, anchorOffsetY)
        checkboxes[#checkboxes + 1] = MakeGridCheckbox(entry, RA_L[keyPrefix..item.key], dbTable, item.key)
    end
    return leftEntries, checkboxes
end

-- Renders a vertical stack of grouped boss-checkbox sections (section
-- header + 2-column checkbox grid per raid) below anchorFrame, flowing
-- downward. Sections with zero bosses are skipped entirely.
-- sections: { { key = "voidspire", bosses = { {key=..}, ... } }, ... }
-- labelSuffixes: optional { [sectionKey] = "|cff888888(12.0.7)|r", ... }
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
                local entry = CreateGridEntry(parent, i, leftEntries, secLabel, -8)
                local bossLabelText = RA_L["boss_"..b.key]
                if b.pendingTest then
                    bossLabelText = bossLabelText .. " |cff888888(coming soon)|r"
                    dbTable[b.key] = false
                end
                local cb = MakeGridCheckbox(entry, bossLabelText, dbTable, b.key)
                if b.pendingTest then cb:SetDisabled(true) end
            end
            prevAnchor  = leftEntries[math.floor((#section.bosses - 1) / 2)]
            prevOffsetY = -16
        end
    end
    return prevAnchor, prevOffsetY
end

------------------------------------------------------------------------
-- Public exports - consumed by Options.lua, Options/OptionsQoL.lua and
-- Options/OptionsProfile.lua
------------------------------------------------------------------------
RA.OptionsUI = {
    ENTRY_W           = ENTRY_W,
    ENTRY_H           = ENTRY_H,
    COL_GAP           = COL_GAP,
    ROW_GAP           = ROW_GAP,
    GOLD              = GOLD,
    GRAY              = GRAY,
    MakeSectionHeader = MakeSectionHeader,
    MakeCB            = MakeCB,
    MakeInfoText      = MakeInfoText,
    MakeToggle        = MakeToggle,
    MakeDropdown      = MakeDropdown,
    MakeValueSlider   = MakeValueSlider,
    MakeSkinnedButton = MakeSkinnedButton,
    MakeTemplateSlider = MakeTemplateSlider,
    MakeHintText      = MakeHintText,
    SetupScrollBar    = SetupScrollBar,
    MakeTabSelector   = MakeTabSelector,
    MakeCheckboxRow   = MakeCheckboxRow,
    MakeSeasonTabs    = MakeSeasonTabs,
    CreateGridEntry   = CreateGridEntry,
    MakeGridCheckbox  = MakeGridCheckbox,
    MakeCheckboxGrid  = MakeCheckboxGrid,
    MakeBossSectionGrid = MakeBossSectionGrid,
}

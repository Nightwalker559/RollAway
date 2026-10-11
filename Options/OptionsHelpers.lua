-- RollAway - Options/OptionsHelpers.lua
-- Shared UI builders for Options, OptionsQoL, OptionsDev and OptionsProfile.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

-- Resolved at file load (Libs load first; the AceGUI widgets are bundled).
local AceGUI = LibStub("AceGUI-3.0")

-- Grid layout constants (all tabs)
local ENTRY_W = 255
local ENTRY_H = 26
local COL_GAP = 24
local ROW_GAP = 6

-- Tab label colors (active / inactive), also used by ElvUI_Skin.lua.
local GOLD = { r = 0.85, g = 0.73, b = 0.25 }
local GRAY = { r = 0.5,  g = 0.5,  b = 0.5  }

-- UI helpers

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

-- Full single-line width of `text` in the font `fs` uses (a label's own GetStringWidth is
-- cut by the checkbox width and ElvUI's re-fonting: long labels ended in "...").
local widthProbe
local function MeasureLabelWidth(fs, text)
    widthProbe = widthProbe or UIParent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    local font, size, flags = fs:GetFont()
    if font then widthProbe:SetFont(font, size, flags) end
    widthProbe:SetText(text)
    return widthProbe:GetStringWidth()
end

local CB_BOX_WIDTH  = 24  -- checkbox graphic left of the label
local CB_SLACK      = 16  -- breathing room after the label
local CB_LINE_H     = 14

-- Sizes the checkbox to its label (up to widthOverride / maxWidth); a longer label wraps
-- onto more lines (frame and label grow, so what hangs below moves down).
local function SetCBLines(cb, lines)
    local text = cb.text
    text:SetWordWrap(true)
    text:ClearAllPoints()
    if lines > 1 then
        -- Top-anchored: the first line stays beside the box.
        text:SetPoint("TOPLEFT", cb.checkbg, "TOPRIGHT", 0, -4)
        text:SetPoint("TOPRIGHT", cb.frame, "TOPRIGHT", 0, -4)
        text:SetJustifyV("TOP")
        text:SetHeight(lines * CB_LINE_H)
        cb.frame:SetHeight(lines * CB_LINE_H + 8)
    else
        -- AceGUI's CheckBox anchors.
        text:SetPoint("LEFT", cb.checkbg, "RIGHT")
        text:SetPoint("RIGHT")
        text:SetJustifyV("MIDDLE")
        text:SetHeight(18)
        cb.frame:SetHeight(24)
    end
    cb.raLines = lines
end

local function FitCB(cb, label, widthOverride, maxWidth)
    local textW   = MeasureLabelWidth(cb.text, label)
    local width   = widthOverride or math.min(CB_BOX_WIDTH + textW + CB_SLACK, maxWidth)
    local lines   = math.max(1, math.ceil(textW / (width - CB_BOX_WIDTH - 6)))
    cb:SetWidth(width)
    SetCBLines(cb, lines)
end

-- Safety net for the estimate: a label still cut off ("...") gets another line (max 4);
-- checked a few frames in a row and on every show (hidden tabs do not lay out).
local function GrowCBIfTruncated(cb, tries)
    if not cb.text:IsVisible() then return end
    if cb.text:IsTruncated() and (cb.raLines or 1) < 4 then
        SetCBLines(cb, (cb.raLines or 1) + 1)
        if tries > 0 then
            RunNextFrame(function() GrowCBIfTruncated(cb, tries - 1) end)
        end
    end
end

-- Self-contained AceGUI checkbox (own textures, no ElvUI template dependency); the caller
-- positions cb.frame. widthOverride: fixed width, else sized to the label, at most
-- maxWidth (default 520, the General tab's room).
local function MakeCB(parent, label, checked, onChange, widthOverride, maxWidth)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(label)
    cb:SetValue(checked)
    maxWidth = maxWidth or 520
    FitCB(cb, label, widthOverride, maxWidth)
    -- Again after ElvUI skinned it (font change).
    RunNextFrame(function()
        FitCB(cb, label, widthOverride, maxWidth)
        RunNextFrame(function() GrowCBIfTruncated(cb, 3) end)
    end)
    cb:SetCallback("OnValueChanged", function(_, _, value)
        if onChange then onChange(value) end
    end)
    cb.frame:SetParent(parent)
    cb.frame:ClearAllPoints()
    cb.frame:Show()
    cb.frame:HookScript("OnShow", function()
        RunNextFrame(function() GrowCBIfTruncated(cb, 3) end)
    end)
    -- AceGUI moves the label anchor on press and does not restore it.
    cb.frame:HookScript("OnMouseUp", function() SetCBLines(cb, cb.raLines or 1) end)
    return cb
end

-- Gray description text below a checkbox/dropdown/label; anchor, offsets and width
-- are passed through.
local function MakeInfoText(parent, anchor, xOffset, yOffset, width, text)
    local info = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    info:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    info:SetWidth(width)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.6, 0.6, 0.6, 1)
    info:SetText(text)
    return info
end

-- Width of a QoL category's content (between nav and scrollbar); descriptions are indented 20.
local QOL_CONTENT_W = 470
local QOL_INFO_W    = QOL_CONTENT_W - 20

-- Checkbox bound to RollAwayDB[opts.dbKey] with its gray description (opts.info) below.
-- Placed (xOffset, yOffset) below `anchor` (nil: from the parent's top-left).
-- opts.onChange(checked) runs after saving; opts.width / opts.infoWidth set the widths,
-- else the box grows with its label up to opts.maxWidth (default QOL_CONTENT_W) and wraps.
-- Returns checkbox, info.
local function MakeToggle(parent, anchor, xOffset, yOffset, opts)
    local cb = MakeCB(parent, opts.label, RollAwayDB[opts.dbKey], function(checked)
        RollAwayDB[opts.dbKey] = checked
        if opts.onChange then opts.onChange(checked) end
    end, opts.width, opts.maxWidth or QOL_CONTENT_W)
    if anchor then
        cb.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    else
        cb.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    end
    local info = MakeInfoText(parent, cb.frame, 20, -6, opts.infoWidth or QOL_INFO_W, opts.info)
    return cb, info
end

-- AceGUI Dropdown shell: blank label (the real one is a FontString above), width,
-- position. SetList/SetValue/SetCallback are left to the caller.
local function MakeDropdown(parent, anchor, xOffset, yOffset, width)
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel("")
    dd:SetWidth(width)
    dd.frame:SetParent(parent)
    dd.frame:ClearAllPoints()
    dd.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    dd.frame:Show()
    if RA.SkinDropdownList then RA.SkinDropdownList(dd) end  -- ElvUI only
    return dd
end

-- Slider in the game's current style (MinimalSliderWithSteppersTemplate, like the game's
-- settings) with its value in the label above the track. Returns the slider frame.
-- (xOffset, yOffset) below `anchor`. opts: min, max, step, value, formatLabel(value) -> text,
-- onChange(rounded value).
local function MakeValueSlider(parent, anchor, xOffset, yOffset, opts)
    local frame = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    frame:SetSize(300, 40) -- room for the longest label ("Transparenz bekannter Items 100%")
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    frame:Init(opts.value, opts.min, opts.max, (opts.max - opts.min) / opts.step, {
        [MinimalSliderWithSteppersMixin.Label.Top] = function(v) return opts.formatLabel(math.floor(v)) end,
    })
    frame:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged,
        function(_, value) opts.onChange(math.floor(value)) end, frame)
    if RA.SkinStepSlider then RA.SkinStepSlider(frame) end
    return frame
end

-- UIPanelButtonTemplate button, with ElvUI's HandleButton skin when available (its native
-- textures are cleared too, they would show through).
local function MakeSkinnedButton(parent, label, width, S)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetText(label)
    -- At least as wide as the label (German is longer).
    btn:SetSize(math.max(width or 110, btn:GetTextWidth() + 24), 22)
    if S and S.HandleButton then
        S:HandleButton(btn)
        btn:SetNormalTexture("")
        btn:SetPushedTexture("")
        btn:SetHighlightTexture("")
        btn:SetDisabledTexture("")
    end
    return btn
end

-- Slider in the game's current style without label (the caller shows a live value label)
-- and optional min/max footers. Returns slider frame (SetEnabled/SetAlpha), minLabel,
-- maxLabel (nil without opts.minText).
local function MakeTemplateSlider(parent, globalName, anchor, opts)
    local slider = CreateFrame("Frame", globalName, parent, "MinimalSliderWithSteppersTemplate")
    slider:SetSize(opts.width or 200, 24)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    slider:Init(opts.value, opts.min, opts.max, (opts.max - opts.min) / opts.step, nil)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged,
        function(_, value) opts.onChange(value) end, slider)

    local minLabel, maxLabel
    if opts.minText then
        minLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 19, -2)
        minLabel:SetText(opts.minText)
        maxLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -19, -2)
        maxLabel:SetJustifyH("RIGHT")
        maxLabel:SetText(opts.maxText)
    end

    if RA.SkinStepSlider then RA.SkinStepSlider(slider) end
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

-- ScrollFrame in the game's current style (ScrollFrameTemplate: slim scroll bar at its
-- right edge: end the frame ~12px before the panel edge); the bar shows only when there is something to
-- scroll. Skinned with ElvUI's Skins module (S) if given.
local function MakeScrollFrame(parent, name, S)
    local scroll = CreateFrame("ScrollFrame", name, parent, "ScrollFrameTemplate")
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    if S and S.HandleTrimScrollBar then S:HandleTrimScrollBar(scroll.ScrollBar) end
    return scroll
end

-- Tab buttons left to right, `gap` apart, closing gaps of hidden ones. placeFirst(btn)
-- anchors the first visible one; placeHidden(btn), if given, hidden ones (valid anchor).
local function ReflowTabRow(order, gap, placeFirst, placeHidden)
    local prevVisible = nil
    for _, btn in ipairs(order) do
        if btn:IsShown() then
            btn:ClearAllPoints()
            if prevVisible then
                btn:SetPoint("LEFT", prevVisible, "RIGHT", gap, 0)
            else
                placeFirst(btn)
            end
            prevVisible = btn
        elseif placeHidden then
            placeHidden(btn)
        end
    end
end

-- Gold label for the active tab, gray for the others (ElvUI-skinned buttons restyle the
-- backdrop too, via RA_ApplyActive/RA_ApplyInactive).
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

-- function(key) that shows panels[key] (hiding the others) and styles buttons[key] as
-- active. Both tables may be filled later; they are read on selection.
local function MakeTabSelector(panels, buttons)
    return function(key)
        for k, panel in pairs(panels) do panel:SetShown(k == key) end
        for k, btn in pairs(buttons) do SetTabButtonActive(btn, k == key) end
    end
end

-- A row of checkboxes below anchorFrame. Returns the row's invisible full-width container
-- (an anchor for what comes next, e.g. MakeSeasonTabs) and the AceGUI checkboxes.
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

-- Season sub-tabs in a parent panel below anchorFrame. Returns panels[key] = contentFrame, tabRowFrame.
local function MakeSeasonTabs(S, parent, anchorFrame, seasons)
    local TAB_H   = 22
    local TAB_GAP = 4
    local panels  = {}
    local buttons = {}
    local buttonOrder = {}

    local classColor = S and (RAID_CLASS_COLORS and RAID_CLASS_COLORS[select(2, UnitClass("player"))])

    -- devOnly season tabs (S1/S3) need debug mode.
    local devDebugActive = RollAwayDB and RollAwayDB.debug

    -- Tab row
    local tabRow = CreateFrame("Frame", nil, parent)
    tabRow:SetPoint("TOPLEFT",  anchorFrame, "BOTTOMLEFT",  0, -10)
    tabRow:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -10)
    tabRow:SetHeight(TAB_H)

    local ShowSeason = MakeTabSelector(panels, buttons)

    -- Re-anchors the visible tabs without gaps.
    local function ReflowTabButtons()
        ReflowTabRow(buttonOrder, TAB_GAP, function(btn)
            btn:SetPoint("LEFT", tabRow, "LEFT", 0, 0)
        end)
    end

    local devOnlyKeys = {}
    local defaultKey

    for _, s in ipairs(seasons) do
        local key = s.key
        local btn = CreateFrame("Button", nil, tabRow, "UIPanelButtonTemplate")
        btn:SetSize(100, TAB_H)
        btn:SetText(s.label)

        -- OnClick before ElvSkinTab (HandleButton would overwrite it)
        btn:SetScript("OnClick", function() ShowSeason(key) end)
        buttons[key] = btn
        buttonOrder[#buttonOrder + 1] = btn

        -- ElvUI skin or default style
        if S and RA.ElvSkinTab then
            RA.ElvSkinTab(btn, panels, key, classColor)
        end

        -- No season sub-tabs without bonus rolls
        if not RA.BONUS_ROLLS_ENABLED then btn:Hide() end

        -- Tracked so the debug checkbox can enable/disable all.
        RA.SeasonTabButtons = RA.SeasonTabButtons or {}
        table.insert(RA.SeasonTabButtons, btn)
        if devDebugActive then btn:Enable() else btn:Disable() end

        -- devOnly sub-tabs (legacy S1 / unreleased S3) only for dev characters with debug mode.
        if s.devOnly then
            devOnlyKeys[key] = true
            if not devDebugActive then btn:Hide() end
            RA.DevOnlyTabButtons = RA.DevOnlyTabButtons or {}
            table.insert(RA.DevOnlyTabButtons, btn)
        end
        if s.default then defaultKey = key end

        -- Content
        local panel = CreateFrame("Frame", nil, tabRow)
        panel:SetPoint("TOPLEFT",  tabRow, "BOTTOMLEFT",  0, -10)
        panel:SetPoint("TOPRIGHT", tabRow, "BOTTOMRIGHT", 0, -10)
        panel:SetHeight(500)
        panel:SetClipsChildren(true)
        panel:Hide()
        panels[key] = panel
    end

    ReflowTabButtons()

    -- Registered so the debug checkbox can re-flow the rows (Dungeons + Raids).
    RA.SeasonTabReflows = RA.SeasonTabReflows or {}
    table.insert(RA.SeasonTabReflows, ReflowTabButtons)

    -- Default season if debug turns off on a devOnly tab.
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

    -- Default season
    if defaultKey then ShowSeason(defaultKey) end

    return panels, tabRow
end

-- Entry `i` (1-based) of a two-column checkbox grid: even entries start a row below the
-- previous left entry (the first below firstAnchor, firstOffsetY), odd ones sit right of
-- theirs. `leftEntries[row]` (0-based) collects the left entries; the caller anchors what
-- follows to leftEntries[math.floor((n - 1) / 2)].
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

-- Checkbox inside a grid entry, bound to dbTable[key].
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

-- Stack of boss checkbox sections (header + 2-column grid per raid) below anchorFrame;
-- empty sections are skipped.
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
                    bossLabelText = bossLabelText .. " |cff888888" .. RA_L["label_coming_soon"] .. "|r"
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

-- One page of a left-nav settings panel (QoL, Developer): a scrolling area next to the
-- nav. Its height hugs the lowest element, measured on every show (a hidden page has no
-- layout; checkboxes settle a few frames after creation).
--   panel, headerLine  the panel and the line under its header
--   navWidth           width of the nav buttons
--   prefix, name       global name of the scroll frame: <prefix><name>Scroll
--   pages, key         the nav's pages table; the page is stored there
-- Returns the scroll child for the page's content.
local function MakeCategoryPage(panel, headerLine, navWidth, prefix, name, pages, key, S)
    local function FitContentHeight(content)
        local top = content:GetTop()
        if not top then return end
        local lowest = top
        local function Consider(obj)
            if obj:IsShown() then
                local bottom = obj:GetBottom()
                if bottom and bottom < lowest then lowest = bottom end
            end
        end
        for _, child in ipairs({ content:GetChildren() }) do Consider(child) end
        for _, region in ipairs({ content:GetRegions() }) do Consider(region) end
        content:SetHeight(math.max(1, (top - lowest) + 12))
    end

    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT",     headerLine, "BOTTOMLEFT", navWidth + 16, -14)
    page:SetPoint("BOTTOMRIGHT", panel,      "BOTTOMRIGHT", 0, 0)
    page:Hide()

    local scroll = MakeScrollFrame(page, prefix .. name .. "Scroll", S)
    scroll:SetPoint("TOPLEFT",     page, "TOPLEFT",     0,   0)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(QOL_CONTENT_W, 1)  -- real height set by FitContentHeight
    scroll:SetScrollChild(content)

    page:SetScript("OnShow", function()
        RunNextFrame(function() FitContentHeight(content) end)
        C_Timer.After(0.3, function() FitContentHeight(content) end)
    end)

    pages[key] = page
    return content
end

-- Public exports (Options, OptionsQoL, OptionsDev, OptionsProfile)
RA.OptionsUI = {
    MakeCategoryPage  = MakeCategoryPage,
    ENTRY_W           = ENTRY_W,
    COL_GAP           = COL_GAP,
    GOLD              = GOLD,
    QOL_CONTENT_W     = QOL_CONTENT_W,
    QOL_INFO_W        = QOL_INFO_W,
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
    MakeScrollFrame   = MakeScrollFrame,
    MakeTabSelector   = MakeTabSelector,
    ReflowTabRow      = ReflowTabRow,
    MakeCheckboxRow   = MakeCheckboxRow,
    MakeSeasonTabs    = MakeSeasonTabs,
    CreateGridEntry   = CreateGridEntry,
    MakeGridCheckbox  = MakeGridCheckbox,
    MakeCheckboxGrid  = MakeCheckboxGrid,
    MakeBossSectionGrid = MakeBossSectionGrid,
}

-- RollAway - Options/Options.lua
-- Settings UI: the main "RollAway" category (header, tabs General / Dungeons / Raids /
-- Delves / Prey / Legacy) and the QoL, Profile and Developer subcategories
-- (OptionsQoL / OptionsProfile / OptionsDev). Shared widget builders: OptionsHelpers.lua.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local SEASON1_DUNGEONS     = RA.DUNGEONS[1]
local SEASON2_DUNGEONS     = RA.DUNGEONS[2]
local SEASON1_DELVES       = RA.DELVES[1]
local SEASON2_DELVES       = RA.DELVES[2]
local SEASON1_RAIDS        = RA.RAIDS[1]
local SEASON2_RAIDS        = RA.RAIDS[2]

-- Shared helpers/constants (OptionsHelpers.lua)
local UI                = RA.OptionsUI
local ENTRY_W            = UI.ENTRY_W
local COL_GAP            = UI.COL_GAP
local MakeSectionHeader  = UI.MakeSectionHeader
local MakeCB             = UI.MakeCB
local MakeInfoText       = UI.MakeInfoText
local MakeTemplateSlider = UI.MakeTemplateSlider
local MakeHintText       = UI.MakeHintText
local MakeCheckboxRow    = UI.MakeCheckboxRow
local MakeSeasonTabs     = UI.MakeSeasonTabs
local MakeCheckboxGrid   = UI.MakeCheckboxGrid
local MakeBossSectionGrid = UI.MakeBossSectionGrid
local CreateGridEntry    = UI.CreateGridEntry
local MakeGridCheckbox   = UI.MakeGridCheckbox

-- The four raid difficulty buckets, as checkbox-row items.
local RAID_DIFF_ITEMS = {
    { key = "lfr",    label = RA_L["raid_diff_lfr"]    },
    { key = "normal", label = RA_L["raid_diff_normal"] },
    { key = "heroic", label = RA_L["raid_diff_heroic"] },
    { key = "mythic", label = RA_L["raid_diff_mythic"] },
}

-- Season sub-tabs of the Dungeons and Raids tabs; other seasons are dev-only (debug mode).
local function SeasonTabDefs()
    return {
        { key = "s1", label = RA_L["season1_title"], devOnly = (RA.ACTIVE_SEASON ~= 1), default = (RA.ACTIVE_SEASON == 1) },
        { key = "s2", label = RA_L["season2_tab"],   devOnly = (RA.ACTIVE_SEASON ~= 2), default = (RA.ACTIVE_SEASON == 2) },
        { key = "s3", label = RA_L["season3_tab"],   devOnly = true },
    }
end

-- Invisible 1x1 frame at a season panel's top-left.
local function MakeSeasonAnchor(seasonPanel)
    local anchor = CreateFrame("Frame", nil, seasonPanel)
    anchor:SetSize(1, 1)
    anchor:SetPoint("TOPLEFT", seasonPanel, "TOPLEFT", 0, 0)
    return anchor
end

local function MakeComingSoonLabel(seasonPanel)
    local label = seasonPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", seasonPanel, "TOPLEFT", 0, -8)
    label:SetTextColor(0.5, 0.5, 0.5, 1)
    label:SetText(RA_L["season_coming_soon"])
end

-- `list` sorted by the localized name RA_L[keyPrefix..entry.key].
local function SortedByName(list, keyPrefix)
    return RA.SortByLabel(list, function(e) return RA_L[keyPrefix..e.key] or e.key end)
end

-- Debug mode was switched (Developer settings): dev-only tabs and season sub-tabs show
-- or hide at once.
function RA.OnDebugModeChanged(checked)
    for _, b in ipairs(RA.DevOnlyTabButtons or {}) do
        b:SetShown(checked)
    end
    for _, b in ipairs(RA.SeasonTabButtons or {}) do
        if checked then b:Enable() else b:Disable() end
        if b.RA_Refresh then b.RA_Refresh() end
    end
    for _, reflow in ipairs(RA.SeasonTabReflows or {}) do reflow() end
    for _, check in ipairs(RA.SeasonTabDebugChecks or {}) do check() end
end

-- Main init (Core.lua, ADDON_LOADED)

function RA.InitOptions()
    local S    = ElvUI and unpack(ElvUI):GetModule("Skins", true)

    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(panel, RA_L["addon_title"])
    local RA_CategoryID = category:GetID()

    -- /raw, /rollaway → options (queued in combat)
    SLASH_ROLLAWAY1 = "/raw"
    SLASH_ROLLAWAY2 = "/rollaway"
    SlashCmdList["ROLLAWAY"] = function()
        RA.RunProtectedOrQueue(function() Settings.OpenToCategory(RA_CategoryID) end)
    end

    -- Header
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\AddOns\\RollAway\\Media\\Icon")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText(RA_L["addon_title"])

    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT",  panel, "TOPLEFT",  16,  -54)
    headerLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -54)
    headerLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Tab definitions
    local tabDefs = {
        { key = "general",  label = RA_L["tab_general"]  },
        { key = "dungeons", label = RA_L["tab_dungeons"] },
        { key = "raids",    label = RA_L["tab_raids"]    },
        { key = "delves",   label = RA_L["tab_delves"]   },
        { key = "prey",     label = RA_L["tab_prey"]     },
        { key = "legacy",   label = RA_L["tab_legacy"]   },
    }

    local tabPanels  = {}
    local tabButtons = {}
    local ShowTab = UI.MakeTabSelector(tabPanels, tabButtons)

    for _, def in ipairs(tabDefs) do
        local p = CreateFrame("Frame", nil, panel)
        p:SetPoint("TOPLEFT",     panel, "TOPLEFT",     16,  -96)
        p:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16,  16)
        p:Hide()
        tabPanels[def.key] = p
    end

    -- Class color (ElvUI tab highlight)
    local classColor
    if S then
        local _, className = UnitClass("player")
        classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[className]
    end

    -- Bonus roll tabs: hidden without bonus rolls this season or below max level (dev
    -- characters bypass the level check only with debug mode on). Registered in
    -- DevOnlyTabButtons/SeasonTabReflows (like the season sub-tabs), so toggling debug
    -- updates them at once.
    local BONUS_ROLL_TABS = { dungeons = true, raids = true, delves = true, prey = true }
    local isDevChar = RA.DEV_CHARS[UnitName("player")]
    local devOverride = isDevChar and RollAwayDB.debug
    local isMaxLevel = RA.IsMaxLevel()
    local belowMaxLevel = not devOverride and not isMaxLevel
    -- Only a dev char below max level follows debug live; at max level the tabs are always
    -- shown (never forced hidden by SetShown(RollAwayDB.debug)).
    local devLiveGate = isDevChar and RA.BONUS_ROLLS_ENABLED and not isMaxLevel

    -- Tab buttons
    local TAB_GAP = 4
    local tabButtonOrder = {}
    for _, def in ipairs(tabDefs) do
        local key = def.key
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(90, 26)
        btn:SetText(def.label)
        tabButtonOrder[#tabButtonOrder + 1] = btn

        -- Bonus roll tabs: disabled or below max level
        local hidden = BONUS_ROLL_TABS[key] and (not RA.BONUS_ROLLS_ENABLED or belowMaxLevel)
        if hidden then btn:Hide() end

        btn:SetScript("OnClick", function() ShowTab(key) end)

        if S and RA.ElvSkinTab then
            RA.ElvSkinTab(btn, tabPanels, key, classColor)
        end
        tabButtons[key] = btn

        if BONUS_ROLL_TABS[key] and devLiveGate then
            RA.DevOnlyTabButtons = RA.DevOnlyTabButtons or {}
            table.insert(RA.DevOnlyTabButtons, btn)
        end
    end

    -- Re-anchors the visible tabs left to right (no gaps); re-run when debug shows/hides tabs.
    local function PlaceTopTab(btn)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60)
    end
    local function ReflowTopTabButtons()
        UI.ReflowTabRow(tabButtonOrder, TAB_GAP, PlaceTopTab, PlaceTopTab)
    end
    ReflowTopTabButtons()

    RA.SeasonTabReflows = RA.SeasonTabReflows or {}
    table.insert(RA.SeasonTabReflows, ReflowTopTabButtons)

    -- General tab if debug turns off while a now hidden bonus roll tab is active.
    local function EnsureValidTopTabSelected()
        if not devLiveGate then return end
        if RollAwayDB.debug then return end
        for key in pairs(BONUS_ROLL_TABS) do
            if tabPanels[key]:IsShown() then
                ShowTab("general")
                return
            end
        end
    end
    RA.SeasonTabDebugChecks = RA.SeasonTabDebugChecks or {}
    table.insert(RA.SeasonTabDebugChecks, EnsureValidTopTabSelected)

    -- Tab: General (in a ScrollFrame)
    local genScroll = UI.MakeScrollFrame(tabPanels["general"], "RollAwayGenScroll", S)
    genScroll:SetPoint("TOPLEFT",     tabPanels["general"], "TOPLEFT",     0,   0)
    genScroll:SetPoint("BOTTOMRIGHT", tabPanels["general"], "BOTTOMRIGHT", -12, 0)

    local gen = CreateFrame("Frame", nil, genScroll)
    gen:SetWidth(580)
    gen:SetHeight(1) -- placeholder; recalculated dynamically once content is laid out
    genScroll:SetScrollChild(gen)


    -- Visibility section
    local visMainLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    visMainLabel:SetPoint("TOPLEFT", 0, -10)
    visMainLabel:SetText(RA_L["visibility_section_title"])

    local visMainInfo = MakeInfoText(gen, visMainLabel, 0, -6, 560, RA_L["visibility_info"])

    -- Master switch: turns the Group Loot History auto-close/auto-hide off (timer,
    -- watchdog, hide-in-raid): plain default WoW. Wired up below, once the controls it
    -- touches exist.
    local SetLootFrameFeatureEnabled

    local cbFrameFeatureDisable = MakeCB(gen, RA_L["lootframe_feature_disable_label"], RollAwayDB.lootFrameAutoCloseDisabled, function(checked)
        RollAwayDB.lootFrameAutoCloseDisabled = checked
        if SetLootFrameFeatureEnabled then SetLootFrameFeatureEnabled(not checked) end
    end)
    cbFrameFeatureDisable.frame:SetPoint("TOPLEFT", visMainInfo, "BOTTOMLEFT", 0, -14)

    -- Row 1: delay (left), safety timeout (right)
    local delayLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    delayLabel:SetPoint("TOPLEFT", cbFrameFeatureDisable.frame, "BOTTOMLEFT", 0, -14)
    delayLabel:SetText(RA_L["delay_section_title"])

    local sliderDelayVal = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sliderDelayVal:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -4)
    sliderDelayVal:SetJustifyH("LEFT")
    sliderDelayVal:SetText(string.format(RA_L["slider_label"], RollAwayDB.delay))

    local slider, delayMin = MakeTemplateSlider(gen, "RollAwayDelaySlider", sliderDelayVal, {
        min = 5, max = 20, step = 1, value = RollAwayDB.delay,
        minText = RA_L["slider_min"], maxText = RA_L["slider_max"],
        onChange = function(value)
            RollAwayDB.delay = math.floor(value)
            sliderDelayVal:SetText(string.format(RA_L["slider_label"], RollAwayDB.delay))
        end,
    })

    local timeoutLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    timeoutLabel:SetPoint("TOPLEFT", delayLabel, "TOPLEFT", 280, 0)
    timeoutLabel:SetText(RA_L["timeout_section_title"])

    local sliderTimeoutVal = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sliderTimeoutVal:SetPoint("TOPLEFT", timeoutLabel, "BOTTOMLEFT", 0, -4)
    sliderTimeoutVal:SetJustifyH("LEFT")
    sliderTimeoutVal:SetText(string.format(RA_L["timeout_slider_label"], RollAwayDB.rollTimeout))

    local sliderTimeout = MakeTemplateSlider(gen, "RollAwayTimeoutSlider", sliderTimeoutVal, {
        min = 30, max = 180, step = 5, value = RollAwayDB.rollTimeout,
        minText = RA_L["timeout_min"], maxText = RA_L["timeout_max"],
        onChange = function(value)
            RollAwayDB.rollTimeout = math.floor(value)
            sliderTimeoutVal:SetText(string.format(RA_L["timeout_slider_label"], RollAwayDB.rollTimeout))
        end,
    })

    -- Row 2: hide the loot history per raid difficulty
    local hideLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hideLabel:SetPoint("TOPLEFT", delayMin, "BOTTOMLEFT", 0, -20)
    hideLabel:SetText(RA_L["hide_in_raid_label"])

    local hideInfo = MakeInfoText(gen, hideLabel, 0, -4, 480, RA_L["hide_in_raid_info"])

    local hideRow, hideRowCheckboxes = MakeCheckboxRow(gen, hideInfo, RAID_DIFF_ITEMS,
        RollAwayDB.hideInRaidBuckets, function(k, checked)
            if type(RollAwayDB.hideInRaidBuckets) ~= "table" then RollAwayDB.hideInRaidBuckets = {} end
            RollAwayDB.hideInRaidBuckets[k] = checked
        end)

    -- Legacy raids: their own switch (the boxes above are for current raids).
    local cbHideLegacy = MakeCB(gen, RA_L["hide_in_legacy_label"], RollAwayDB.hideInLegacyRaids, function(checked)
        RollAwayDB.hideInLegacyRaids = checked
    end)
    cbHideLegacy.frame:SetPoint("TOPLEFT", hideRow, "BOTTOMLEFT", 0, -14)
    local hideLegacyInfo = MakeInfoText(gen, cbHideLegacy.frame, 20, -6, 460, RA_L["hide_in_legacy_info"])

    -- Master switch logic and initial state.
    SetLootFrameFeatureEnabled = function(enabled)
        local alpha = enabled and 1 or 0.4
        slider:SetEnabled(enabled)
        slider:SetAlpha(alpha)
        sliderTimeout:SetEnabled(enabled)
        sliderTimeout:SetAlpha(alpha)
        for _, cb in ipairs(hideRowCheckboxes) do
            cb:SetDisabled(not enabled)
        end
        hideInfo:SetAlpha(alpha)
        hideLabel:SetAlpha(alpha)
        cbHideLegacy:SetDisabled(not enabled)
        hideLegacyInfo:SetAlpha(alpha)
    end
    SetLootFrameFeatureEnabled(not RollAwayDB.lootFrameAutoCloseDisabled)

    -- Bonus roll reminder (own section: shown when entering a Mythic dungeon/raid).
    local reminderSectionLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    reminderSectionLabel:SetPoint("TOPLEFT", hideLegacyInfo, "BOTTOMLEFT", -20, -16)
    reminderSectionLabel:SetText(RA_L["bonusroll_reminder_section_title"])

    local cbReminder = MakeCB(gen, RA_L["reminder_label"], RollAwayDB.showReminder, function(checked)
        RollAwayDB.showReminder = checked
        -- Else a shown reminder stays open (ShowReminder re-checks on the next zone change).
        if not checked then
            local frame = _G["RollAwayReminderFrame"]
            if frame and frame:IsShown() then frame:Hide() end
        end
    end)
    cbReminder.frame:SetPoint("TOPLEFT", reminderSectionLabel, "BOTTOMLEFT", 0, -10)

    local reminderInfo = MakeInfoText(gen, cbReminder.frame, 20, -6, 480, RA_L["reminder_info"])

    -- Safety net: warns when entering content with an active auto-pass.
    local cbWarn = MakeCB(gen, RA_L["autopass_warning_label"], RollAwayDB.autoPassWarning, function(checked)
        RollAwayDB.autoPassWarning = checked
    end)
    cbWarn.frame:SetPoint("TOPLEFT", reminderInfo, "BOTTOMLEFT", -20, -10)
    local warnInfo = MakeInfoText(gen, cbWarn.frame, 20, -6, 480, RA_L["autopass_warning_info"])

    -- Hidden without bonus rolls or below max level (like the tabs above).
    local showBonusRollReminder = RA.BONUS_ROLLS_ENABLED and not belowMaxLevel
    if not showBonusRollReminder then
        reminderSectionLabel:Hide()
        cbReminder.frame:Hide()
        reminderInfo:Hide()
        cbWarn.frame:Hide()
        warnInfo:Hide()
    end

    -- Row 3: Legacy
    local legacyLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    -- warnInfo / hideLegacyInfo are indented 20: -20 returns to the margin. The label hangs
    -- below hideLegacyInfo (below hideRow it would cover the legacy-hide checkbox).
    if showBonusRollReminder then
        legacyLabel:SetPoint("TOPLEFT", warnInfo, "BOTTOMLEFT", -20, -14)
    else
        legacyLabel:SetPoint("TOPLEFT", hideLegacyInfo, "BOTTOMLEFT", -20, -14)
    end
    legacyLabel:SetText(RA_L["legacy_section_title"])

    -- onChange is set below (cbLegacy:SetCallback) once legacyTabBtn exists; the
    -- widget has a single OnValueChanged slot, one given here would be overwritten.
    local cbLegacy = MakeCB(gen, RA_L["legacy_enable_label"], RollAwayDB.legacy, nil)
    cbLegacy.frame:SetPoint("TOPLEFT", legacyLabel, "BOTTOMLEFT", 0, -10)


    -- Scroll child height = last General element, one frame later (GetTop/GetBottom need the layout).
    local lastGenElement = cbLegacy.frame
    local function UpdateGenScrollHeight()
        local top, bottom = gen:GetTop(), lastGenElement:GetBottom()
        if top and bottom then
            local contentHeight = (top - bottom) + 20 -- bottom padding
            gen:SetHeight(math.max(contentHeight, genScroll:GetHeight()))
        end
        -- Re-check the scrollbar (OnScrollRangeChanged timing).
        if scrollBar then
            scrollBar:SetShown((genScroll:GetVerticalScrollRange() or 0) > 1)
        end
    end
    -- Again later and on every show: checkboxes settle (wrapped labels) after a few frames; a
    -- hidden tab has no layout.
    RunNextFrame(UpdateGenScrollHeight)
    C_Timer.After(0.3, UpdateGenScrollHeight)
    genScroll:HookScript("OnShow", function()
        RunNextFrame(UpdateGenScrollHeight)
        C_Timer.After(0.3, UpdateGenScrollHeight)
    end)

    -- Tab: Dungeons
    local dng = tabPanels["dungeons"]
    local dngHint = MakeHintText(dng, dng, RA_L["season1_hint"])
    dngHint:SetPoint("TOPLEFT", dng, "TOPLEFT", 0, -10)

    -- Forward-declared: the master checkbox locks/unlocks them; MakeCheckboxGrid fills them.
    local dngS1Checkboxes = {}
    local dngS2Checkboxes = {}
    local function ApplyDungeonAllLock()
        local locked = RollAwayDBChar.dungeonAutoPassAll
        for _, cb in ipairs(dngS1Checkboxes) do cb:SetDisabled(locked) end
        for _, cb in ipairs(dngS2Checkboxes) do cb:SetDisabled(locked) end
    end

    -- All dungeons (any season): OR with the per-dungeon boxes, like the raid difficulty switch.
    local dngAllCB = MakeCB(dng, RA_L["dungeon_autopass_all_label"], RollAwayDBChar.dungeonAutoPassAll, function(checked)
        RollAwayDBChar.dungeonAutoPassAll = checked
        ApplyDungeonAllLock()
    end)
    dngAllCB.frame:SetPoint("TOPLEFT", dngHint, "BOTTOMLEFT", 0, -10)

    -- Full-width (560) anchor for the season tabs (MakeSeasonTabs takes the panel width from it).
    local dngSeasonAnchor = CreateFrame("Frame", nil, dng)
    dngSeasonAnchor:SetPoint("TOPLEFT", dngAllCB.frame, "BOTTOMLEFT", 0, 0)
    dngSeasonAnchor:SetSize(560, 1)

    local dngSeasons = MakeSeasonTabs(S, dng, dngSeasonAnchor, SeasonTabDefs())

    -- Season 1 / Season 2 content
    local _, dngS1CB = MakeCheckboxGrid(dngSeasons["s1"], MakeSeasonAnchor(dngSeasons["s1"]), -8,
        SortedByName(SEASON1_DUNGEONS, "dungeon_"), RollAwayDBChar.dungeons, "dungeon_")
    dngS1Checkboxes = dngS1CB

    local _, dngS2CB = MakeCheckboxGrid(dngSeasons["s2"], MakeSeasonAnchor(dngSeasons["s2"]), -8,
        SortedByName(SEASON2_DUNGEONS, "dungeon_"), RollAwayDBChar.dungeons_s2, "dungeon_")
    dngS2Checkboxes = dngS2CB

    ApplyDungeonAllLock()

    MakeComingSoonLabel(dngSeasons["s3"])

    -- Tab: Delves
    local dlv = tabPanels["delves"]
    local dlvHint = MakeHintText(dlv, dlv, RA_L["season1_delve_hint"])
    dlvHint:SetPoint("TOPLEFT", dlv, "TOPLEFT", 0, -10)

    -- All delves (any season): OR with the per-delve boxes.
    local dlvAllCheckboxes = {}
    local function ApplyDelveAllLock()
        local locked = RollAwayDBChar.delveAutoPassAll
        for _, cb in ipairs(dlvAllCheckboxes) do cb:SetDisabled(locked) end
    end

    local dlvAllCB = MakeCB(dlv, RA_L["delve_autopass_all_label"], RollAwayDBChar.delveAutoPassAll, function(checked)
        RollAwayDBChar.delveAutoPassAll = checked
        ApplyDelveAllLock()
    end)
    dlvAllCB.frame:SetPoint("TOPLEFT", dlvHint, "BOTTOMLEFT", 0, -10)

    -- One page grouped by patch; 12.1 (Season 2) delves stay hidden until RA.ACTIVE_SEASON is 2.
    local dlvSections = {
        { titleKey = "patch_12_0", items = SortedByName(SEASON1_DELVES, "delve_"), dbTable = RollAwayDBChar.delves },
    }
    if RA.ACTIVE_SEASON >= 2 then
        table.insert(dlvSections, { titleKey = "patch_12_1", items = SortedByName(SEASON2_DELVES, "delve_"), dbTable = RollAwayDBChar.delves_s2 })
    end

    local dlvPrevAnchor   = dlvAllCB.frame
    local dlvPrevOffsetY  = -14
    for _, section in ipairs(dlvSections) do
        local secLabel = dlv:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        secLabel:SetPoint("TOPLEFT", dlvPrevAnchor, "BOTTOMLEFT", 0, dlvPrevOffsetY)
        secLabel:SetText(RA_L[section.titleKey])

        local leftEntries = {}
        for i, item in ipairs(section.items) do
            local entry = CreateGridEntry(dlv, i, leftEntries, secLabel, -8)
            local labelText = RA_L["delve_"..item.key]
            if item.key == "venomfall_deeps" or item.key == "torments_rise" then
                labelText = labelText .. " |cff888888" .. RA_L["nemesis_delve_label"] .. "|r"
            end
            if item.key == "labyrinth_of_kindojan" then
                labelText = labelText .. " |cff888888[12.1.5]|r"
            end
            local isRemoved = item.removedAfterS1 and RA.ACTIVE_SEASON >= 2
            if isRemoved then
                labelText = labelText .. " |cff888888" .. RA_L["label_removed"] .. "|r"
            end
            local isPending = item.pendingTest
            if isPending then
                labelText = labelText .. " |cff888888" .. RA_L["label_coming_soon"] .. "|r"
            end
            if isRemoved or isPending then
                section.dbTable[item.key] = false
            end

            local dlvCB = MakeGridCheckbox(entry, labelText, section.dbTable, item.key)
            if isRemoved or isPending then
                dlvCB:SetDisabled(true) -- permanently/temporarily disabled, not affected by the master lock
            else
                table.insert(dlvAllCheckboxes, dlvCB)
            end
        end

        if #section.items == 0 then
            dlvPrevAnchor, dlvPrevOffsetY = secLabel, -8
        else
            dlvPrevAnchor, dlvPrevOffsetY = leftEntries[math.floor((#section.items - 1) / 2)], -16
        end
    end
    ApplyDelveAllLock()

    -- Tab: Raids
    local raidPanel = tabPanels["raids"]
    local raidHint = MakeHintText(raidPanel, raidPanel, RA_L["raid_hint"])
    raidHint:SetPoint("TOPLEFT", raidPanel, "TOPLEFT", 0, -10)

    -- Roll confirmation popups (any loot roll, not tied to season data).
    local rollConfirmLabel = raidPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rollConfirmLabel:SetPoint("TOPLEFT", raidHint, "BOTTOMLEFT", 0, -12)
    rollConfirmLabel:SetText(RA_L["confirm_roll_title"])

    local rollConfirmHint = MakeHintText(raidPanel, rollConfirmLabel, RA_L["confirm_roll_hint"])

    local rollConfirmRow = MakeCheckboxRow(raidPanel, rollConfirmHint, {
        { key = "need",     label = RA_L["confirm_type_need"] },
        { key = "greed",    label = RA_L["confirm_type_greed"] },
        { key = "transmog", label = RA_L["confirm_type_transmog"] },
        { key = "pass",     label = RA_L["confirm_type_pass"] },
    }, RollAwayDB.confirmRoll, function(k, checked)
        if type(RollAwayDB.confirmRoll) ~= "table" then RollAwayDB.confirmRoll = {} end
        RollAwayDB.confirmRoll[k] = checked
        RA.SetRollConfirmEnabled(k, checked)
    end)

    -- Auto-pass by raid difficulty (all seasons/bosses, OR with the per-boss boxes).
    local raidDiffLabel = raidPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    raidDiffLabel:SetPoint("TOPLEFT", rollConfirmRow, "BOTTOMLEFT", 0, -12)
    raidDiffLabel:SetText(RA_L["raid_diff_autopass_title"])

    local raidDiffHint = MakeHintText(raidPanel, raidDiffLabel, RA_L["raid_diff_autopass_hint"])

    local raidDiffRow = MakeCheckboxRow(raidPanel, raidDiffHint, RAID_DIFF_ITEMS,
        RollAwayDBChar.raidAutoPassDifficulty, function(k, checked)
            if type(RollAwayDBChar.raidAutoPassDifficulty) ~= "table" then RollAwayDBChar.raidAutoPassDifficulty = {} end
            RollAwayDBChar.raidAutoPassDifficulty[k] = checked
        end)

    -- Full-width (560) anchor for the season tabs (MakeSeasonTabs takes the panel width from it).
    local raidSeasonAnchor = CreateFrame("Frame", nil, raidPanel)
    raidSeasonAnchor:SetPoint("TOPLEFT", raidDiffRow, "BOTTOMLEFT", 0, 0)
    raidSeasonAnchor:SetSize(560, 1)

    local raidSeasons = MakeSeasonTabs(S, raidPanel, raidSeasonAnchor, SeasonTabDefs())

    -- Groups bosses into `sections` (boss.raid == section.key), in section order.
    local function FillRaidSections(sections, bosses)
        for _, b in ipairs(bosses) do
            for _, s in ipairs(sections) do
                if b.raid == s.key then table.insert(s.bosses, b); break end
            end
        end
        return sections
    end

    -- Season 1 content
    local raidSections = FillRaidSections({
        { key = "voidspire",       bosses = {} },
        { key = "dreamrift",       bosses = {} },
        { key = "march_queldanas", bosses = {} },
        { key = "sporefall",       bosses = {} },
    }, SEASON1_RAIDS)

    MakeBossSectionGrid(raidSeasons["s1"], MakeSeasonAnchor(raidSeasons["s1"]), raidSections, RollAwayDBChar.raids,
        { sporefall = "|cff888888(12.0.7)|r" })

    -- Season 2 (The Venomous Abyss + Tidebound Grotto, grouped by raid like Season 1).
    local raidS2MainSections = FillRaidSections({
        { key = "venomous_abyss", bosses = {} },
    }, SEASON2_RAIDS)
    -- Tidebound Grotto and Kith'ix are single-boss side content: side by side.
    local raidS2PairSections = FillRaidSections({
        { key = "tidebound_grotto",    bosses = {} },
        { key = "unbinding_of_kithix", bosses = {} },
    }, SEASON2_RAIDS)

    local raidS2MainAnchor, raidS2MainOffsetY =
        MakeBossSectionGrid(raidSeasons["s2"], MakeSeasonAnchor(raidSeasons["s2"]), raidS2MainSections, RollAwayDBChar.raids)

    local raidS2PairAnchor = CreateFrame("Frame", nil, raidSeasons["s2"])
    raidS2PairAnchor:SetSize(1, 1)
    raidS2PairAnchor:SetPoint("TOPLEFT", raidS2MainAnchor, "BOTTOMLEFT", 0, raidS2MainOffsetY)

    local raidS2PairRightAnchor = CreateFrame("Frame", nil, raidSeasons["s2"])
    raidS2PairRightAnchor:SetSize(1, 1)
    raidS2PairRightAnchor:SetPoint("TOPLEFT", raidS2PairAnchor, "TOPLEFT", ENTRY_W + COL_GAP, 0)

    MakeBossSectionGrid(raidSeasons["s2"], raidS2PairAnchor,
        { raidS2PairSections[1] }, RollAwayDBChar.raids)
    MakeBossSectionGrid(raidSeasons["s2"], raidS2PairRightAnchor,
        { raidS2PairSections[2] }, RollAwayDBChar.raids,
        { unbinding_of_kithix = "|cff888888[12.1.5]|r" })

    MakeComingSoonLabel(raidSeasons["s3"])

    -- Tab: Prey
    local preyPanel = tabPanels["prey"]
    local preyLabel = preyPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    preyLabel:SetPoint("TOPLEFT", preyPanel, "TOPLEFT", 0, -10)
    preyLabel:SetText(RA_L["prey_title"])
    local preyHint = MakeHintText(preyPanel, preyLabel, RA_L["prey_hint"])

    local preyCB = MakeCB(preyPanel, RA_L["prey_toggle_label"], RollAwayDBChar.prey, function(checked)
        RollAwayDBChar.prey = checked
    end)
    preyCB.frame:SetPoint("TOPLEFT", preyHint, "BOTTOMLEFT", 0, -14)

    -- Tab: Legacy raids
    local legacyPanel = tabPanels["legacy"]
    local _, legacyLine = MakeSectionHeader(legacyPanel, legacyPanel, -10, RA_L["legacy_tab_title"])
    local legacyHint = MakeHintText(legacyPanel, legacyLine, RA_L["legacy_tab_hint"])

    local legacyRaidCBs = {}
    local function RefreshLegacyRaidCheckboxes()
        local db = RA.GetLegacyRaidsDB()
        for _, entry in ipairs(legacyRaidCBs) do
            entry.cb:SetValue(db and db[entry.key])
        end
    end

    local legacyAccountWideCB = MakeCB(legacyPanel, RA_L["legacy_account_wide_label"], RA.db.global.legacyAccountWide, function(checked)
        if checked then
            -- Carry the current character's selection over to the account-wide table.
            for k, v in pairs(RollAwayDBChar.legacy_raids) do
                RA.db.global.legacy_raids[k] = v
            end
        end
        RA.db.global.legacyAccountWide = checked
        RefreshLegacyRaidCheckboxes()
    end)
    legacyAccountWideCB.frame:SetPoint("TOPLEFT", legacyHint, "BOTTOMLEFT", 0, -14)

    local legacyRollLabel = legacyPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    legacyRollLabel:SetPoint("TOPLEFT", legacyAccountWideCB.frame, "BOTTOMLEFT", 0, -14)
    legacyRollLabel:SetText(RA_L["legacy_roll_label"])

    -- Need / Greed / Transmog are the fallback chain; Pass replaces it (the others grey out).
    local rollDefs = {
        { dbKey = "legacyNeed",     labelKey = "legacy_roll_need"     },
        { dbKey = "legacyGreed",    labelKey = "legacy_roll_greed"    },
        { dbKey = "legacyTransmog", labelKey = "legacy_roll_transmog" },
        { dbKey = "legacyPass",     labelKey = "legacy_roll_pass"     },
    }
    local chainCBs = {}
    local function RefreshRollChainState()
        for _, cb in ipairs(chainCBs) do cb:SetDisabled(RollAwayDB.legacyPass == true) end
    end
    local prevRollCB = nil
    for _, rd in ipairs(rollDefs) do
        local dbKey = rd.dbKey
        local rollCB = MakeCB(legacyPanel, RA_L[rd.labelKey], RollAwayDB[dbKey], function(checked)
            RollAwayDB[dbKey] = checked
            DBG("[Legacy UI]", dbKey, "=", tostring(checked))
            if dbKey == "legacyPass" then RefreshRollChainState() end
        end)
        if not prevRollCB then
            rollCB.frame:SetPoint("TOPLEFT", legacyRollLabel, "BOTTOMLEFT", 0, -10)
        else
            rollCB.frame:SetPoint("LEFT", prevRollCB, "RIGHT", 16, 0)
        end
        prevRollCB = rollCB.frame
        if dbKey ~= "legacyPass" then chainCBs[#chainCBs + 1] = rollCB end
    end
    RefreshRollChainState()

    local legacyRaidLine = legacyPanel:CreateTexture(nil, "ARTWORK")
    legacyRaidLine:SetHeight(1)
    legacyRaidLine:SetWidth(560)
    legacyRaidLine:SetPoint("TOPLEFT", legacyRollLabel, "BOTTOMLEFT", 0, -44)
    legacyRaidLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- One expansion column: header, then its raids' checkboxes, bound to the legacy raid table
    -- active at click time (character or account-wide).
    local function MakeLegacyRaidColumn(xOffset, headerKey, raids)
        local header = legacyPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", legacyRaidLine, "BOTTOMLEFT", xOffset, -14)
        header:SetText(RA_L[headerKey])

        local prev = header
        for _, r in ipairs(raids) do
            local key = r.key
            local legCB = MakeCB(legacyPanel, RA_L[r.label], RA.GetLegacyRaidsDB()[key], function(checked)
                RA.GetLegacyRaidsDB()[key] = checked
            end)
            legCB.frame:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
            table.insert(legacyRaidCBs, { cb = legCB, key = key })
            prev = legCB.frame
        end
    end

    MakeLegacyRaidColumn(0, "legacy_col_dragonflight", {
        { key = "vault_of_incarnates", label = "legacy_raid_vault_of_incarnates" },
        { key = "aberrus",             label = "legacy_raid_aberrus"              },
        { key = "amirdrassil",         label = "legacy_raid_amirdrassil"          },
    })
    MakeLegacyRaidColumn(ENTRY_W + COL_GAP, "legacy_col_tww", {
        { key = "nerubar_palace",       label = "legacy_raid_nerubar_palace"       },
        { key = "liberation_undermine", label = "legacy_raid_liberation_undermine" },
        { key = "manaforge_omega",      label = "legacy_raid_manaforge_omega"      },
    })

    -- Legacy tab: only while Legacy is enabled
    local legacyTabBtn = tabButtons["legacy"]
    legacyTabBtn:SetShown(RollAwayDB.legacy == true)

    cbLegacy:SetCallback("OnValueChanged", function(_, _, checked)
        RollAwayDB.legacy = checked
        legacyTabBtn:SetShown(checked)
        if not checked and tabPanels["legacy"]:IsShown() then
            ShowTab("general")
        end
    end)

    -- OpenOptionsTab, for Reminder.lua
    function RA.OpenOptionsTab(key)
        RA.RunProtectedOrQueue(function()
            Settings.OpenToCategory(RA_CategoryID)
            ShowTab(key)
        end)
    end

    -- Subcategories: QoL (OptionsQoL.lua), Profile (OptionsProfile.lua), Developer (dev
    -- characters, OptionsDev.lua)
    RA.BuildQoLOptions(category, S, classColor)
    RA.BuildProfileOptions(category, S)
    if isDevChar then RA.BuildDevOptions(category, S, classColor) end

    ShowTab("general")
    Settings.RegisterAddOnCategory(category)
end

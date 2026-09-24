-- RollAway - Options.lua
-- Settings UI. Builds the main "RollAway" Settings category: header, tabs
-- (General / Dungeons / Raids / Delves / Prey / Legacy), and wires up the
-- QoL subcategory built in Options/OptionsQoL.lua.
-- Shared widget builders (MakeCB, MakeSeasonTabs, etc.) live in
-- Options/OptionsHelpers.lua, both loaded before this file per the .toc.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local SEASON1_DUNGEONS     = RA.DUNGEONS[1]
local SEASON2_DUNGEONS     = RA.DUNGEONS[2]
local SEASON1_DELVES       = RA.DELVES[1]
local SEASON2_DELVES       = RA.DELVES[2]
local SEASON1_RAIDS        = RA.RAIDS[1]
local SEASON2_RAIDS        = RA.RAIDS[2]

-- Shared helpers/constants from Options/OptionsHelpers.lua
local UI                = RA.OptionsUI
local ENTRY_W            = UI.ENTRY_W
local ENTRY_H            = UI.ENTRY_H
local COL_GAP            = UI.COL_GAP
local ROW_GAP            = UI.ROW_GAP
local MakeSectionHeader  = UI.MakeSectionHeader
local MakeCB             = UI.MakeCB
local MakeHintText       = UI.MakeHintText
local MakeCheckboxRow    = UI.MakeCheckboxRow
local MakeSeasonTabs     = UI.MakeSeasonTabs
local MakeCheckboxGrid   = UI.MakeCheckboxGrid
local MakeBossSectionGrid = UI.MakeBossSectionGrid

------------------------------------------------------------------------
-- Main init function – called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitOptions()
    local S    = ElvUI and unpack(ElvUI):GetModule("Skins", true)

    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(panel, RA_L["addon_title"])
    local RA_CategoryID = category:GetID()
    RA.RA_CategoryID = RA_CategoryID

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

    for _, def in ipairs(tabDefs) do
        local p = CreateFrame("Frame", nil, panel)
        p:SetPoint("TOPLEFT",     panel, "TOPLEFT",     16,  -96)
        p:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16,  16)
        p:Hide()
        tabPanels[def.key] = p
    end

    -- Class color for ElvUI tab highlight
    local classColor
    if S then
        local _, className = UnitClass("player")
        classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[className]
    end

    local function GetElvUIColors()
        if RA.GetElvUIColors then return RA.GetElvUIColors() end
        return {0.1,0.1,0.1,0.8}, {0.1,0.1,0.1}
    end

    local GOLD = { r = 0.85, g = 0.73, b = 0.25 }
    local GRAY = { r = 0.5,  g = 0.5,  b = 0.5  }

    local function SetTabActive(btn)
        local t = btn:GetFontString()
        if t then t:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1) end
    end

    local function SetTabInactive(btn)
        local t = btn:GetFontString()
        if t then t:SetTextColor(GRAY.r, GRAY.g, GRAY.b, 1) end
        if S and btn.SetBackdropColor then
            local bg, bd = GetElvUIColors()
            btn:SetBackdropColor(unpack(bg))
            btn:SetBackdropBorderColor(unpack(bd))
        end
    end

    local function ShowTab(key)
        for k, p in pairs(tabPanels) do p:SetShown(k == key) end
        for k, b in pairs(tabButtons) do
            if k == key then
                if b.RA_ApplyActive then b.RA_ApplyActive() else SetTabActive(b) end
            else
                if b.RA_ApplyInactive then b.RA_ApplyInactive() else SetTabInactive(b) end
            end
        end
    end

    -- Bonus Roll tabs: hidden when Bonus Rolls are disabled for the current
    -- season, or when the current character is below max level (Bonus Rolls
    -- only exist at max level, so the auto-pass config is meaningless
    -- otherwise). Dev/test characters only bypass the level check with
    -- debug mode on - otherwise they're gated like everyone else. Since the
    -- debug checkbox is toggled live (no reload), these tabs are wired into
    -- the same DevOnlyTabButtons/SeasonTabReflows registries the season
    -- sub-tabs (OptionsHelpers.lua MakeSeasonTabs) use for their own
    -- debug-gated tabs, so toggling debug updates them immediately too.
    local BONUS_ROLL_TABS = { dungeons = true, raids = true, delves = true, prey = true }
    local isDevChar = RA.DEV_CHARS and RA.DEV_CHARS[UnitName("player")]
    local devOverride = isDevChar and RollAwayDB and RollAwayDB.debug
    local belowMaxLevel = not devOverride and not (RA.IsMaxLevel and RA.IsMaxLevel())
    -- Only a dev char who is currently below max level needs live debug
    -- toggling; a dev char at max level always sees the tabs regardless of
    -- debug, so it must never be forced hidden by SetShown(RollAwayDB.debug).
    local devLiveGate = isDevChar and RA.BONUS_ROLLS_ENABLED and not (RA.IsMaxLevel and RA.IsMaxLevel())

    -- Tab buttons
    local TAB_GAP = 4
    local tabButtonOrder = {}
    for _, def in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(90, 26)
        btn:SetText(def.label)
        tabButtonOrder[#tabButtonOrder + 1] = btn

        -- Hide bonus roll tabs when disabled or below max level
        local hidden = BONUS_ROLL_TABS[def.key] and (not RA.BONUS_ROLLS_ENABLED or belowMaxLevel)
        if hidden then btn:Hide() end

        local capturedKey = def.key
        btn:SetScript("OnClick", function() ShowTab(capturedKey) end)

        if S and RA.ElvSkinTab then
            RA.ElvSkinTab(btn, tabPanels, capturedKey, classColor)
        end
        tabButtons[def.key] = btn

        if BONUS_ROLL_TABS[def.key] and devLiveGate then
            RA.DevOnlyTabButtons = RA.DevOnlyTabButtons or {}
            table.insert(RA.DevOnlyTabButtons, btn)
        end
    end

    -- Re-anchors visible top-level tabs left-to-right, closing gaps from
    -- hidden ones. Re-run after the debug checkbox shows/hides dev-gated
    -- tabs so the row doesn't leave a blank gap or overlap.
    local function ReflowTopTabButtons()
        local prevVisible = nil
        for _, btn in ipairs(tabButtonOrder) do
            if btn:IsShown() then
                btn:ClearAllPoints()
                if prevVisible then
                    btn:SetPoint("LEFT", prevVisible, "RIGHT", TAB_GAP, 0)
                else
                    btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60)
                end
                prevVisible = btn
            else
                btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60)
            end
        end
    end
    ReflowTopTabButtons()

    RA.SeasonTabReflows = RA.SeasonTabReflows or {}
    table.insert(RA.SeasonTabReflows, ReflowTopTabButtons)

    -- Falls back to the General tab if debug turns off while a now-hidden
    -- bonus-roll tab is active (mirrors EnsureValidSeasonSelected below).
    local function EnsureValidTopTabSelected()
        if not devLiveGate then return end
        if RollAwayDB and RollAwayDB.debug then return end
        for key in pairs(BONUS_ROLL_TABS) do
            if tabPanels[key]:IsShown() then
                ShowTab("general")
                return
            end
        end
    end
    RA.SeasonTabDebugChecks = RA.SeasonTabDebugChecks or {}
    table.insert(RA.SeasonTabDebugChecks, EnsureValidTopTabSelected)

    ------------------------------------------------------------
    -- Tab: General – wrapped in a ScrollFrame so content never clips
    ------------------------------------------------------------
    local genScroll = CreateFrame("ScrollFrame", "RollAwayGenScroll", tabPanels["general"], "UIPanelScrollFrameTemplate")
    genScroll:SetPoint("TOPLEFT",     tabPanels["general"], "TOPLEFT",     0,   0)
    genScroll:SetPoint("BOTTOMRIGHT", tabPanels["general"], "BOTTOMRIGHT", -26, 0)

    local gen = CreateFrame("Frame", nil, genScroll)
    gen:SetWidth(580)
    gen:SetHeight(1) -- placeholder; recalculated dynamically once content is laid out
    genScroll:SetScrollChild(gen)

    local scrollBar = _G["RollAwayGenScrollScrollBar"]

    genScroll:SetScript("OnScrollRangeChanged", function(self, xRange, yRange)
        local max = math.max(0, yRange or 0)
        if scrollBar then
            scrollBar:SetMinMaxValues(0, max)
            scrollBar:SetValue(math.min(scrollBar:GetValue(), max))
            scrollBar:SetShown(max > 1)
        end
    end)

    genScroll:SetScript("OnVerticalScroll", function(self, offset)
        if scrollBar then scrollBar:SetValue(offset) end
    end)

    if scrollBar then
        scrollBar:SetScript("OnValueChanged", function(self, value)
            genScroll:SetVerticalScroll(value)
        end)
        local upBtn   = _G["RollAwayGenScrollScrollBarScrollUpButton"]
        local downBtn = _G["RollAwayGenScrollScrollBarScrollDownButton"]
        if upBtn then
            upBtn:SetScript("OnClick", function()
                genScroll:SetVerticalScroll(math.max(0, genScroll:GetVerticalScroll() - 20))
            end)
        end
        if downBtn then
            downBtn:SetScript("OnClick", function()
                local _, max = scrollBar:GetMinMaxValues()
                genScroll:SetVerticalScroll(math.min(max, genScroll:GetVerticalScroll() + 20))
            end)
        end
    end

    if S and S.HandleScrollBar and scrollBar then
        S:HandleScrollBar(scrollBar)
    end

    -- Visibility section header
    local visMainLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    visMainLabel:SetPoint("TOPLEFT", 0, -10)
    visMainLabel:SetText(RA_L["visibility_section_title"])

    local visMainInfo = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    visMainInfo:SetPoint("TOPLEFT", visMainLabel, "BOTTOMLEFT", 0, -6)
    visMainInfo:SetWidth(560)
    visMainInfo:SetJustifyH("LEFT")
    visMainInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    visMainInfo:SetText(RA_L["visibility_info"])

    -- Master switch: disables the entire auto-close/auto-hide feature for
    -- the Group Loot History frame (delay timer, safety-timeout watchdog,
    -- hide-in-raid), so it behaves like plain default WoW - always shown,
    -- closed only manually. Placed above the sliders it controls; the actual
    -- enable/disable function is wired up further below once the sliders and
    -- hideRow checkboxes it touches exist (forward-declared here).
    local SetLootFrameFeatureEnabled

    local cbFrameFeatureDisable = MakeCB(gen, RA_L["lootframe_feature_disable_label"], RollAwayDB.lootFrameAutoCloseDisabled, function(checked)
        RollAwayDB.lootFrameAutoCloseDisabled = checked
        if SetLootFrameFeatureEnabled then SetLootFrameFeatureEnabled(not checked) end
    end)
    cbFrameFeatureDisable.frame:SetPoint("TOPLEFT", visMainInfo, "BOTTOMLEFT", 0, -14)

    -- Row 1: Delay (left) + Safety timeout (right)
    local delayLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    delayLabel:SetPoint("TOPLEFT", cbFrameFeatureDisable.frame, "BOTTOMLEFT", 0, -14)
    delayLabel:SetText(RA_L["delay_section_title"])

    local sliderDelayVal = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sliderDelayVal:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -4)
    sliderDelayVal:SetJustifyH("LEFT")
    sliderDelayVal:SetText(string.format(RA_L["slider_label"], RollAwayDB.delay))

    local slider = CreateFrame("Slider", "RollAwayDelaySlider", gen, "OptionsSliderTemplate")
    slider:SetWidth(200)
    slider:SetPoint("TOPLEFT", sliderDelayVal, "BOTTOMLEFT", 0, -8)
    slider:SetMinMaxValues(5, 20)
    slider:SetValueStep(1)
    slider:SetValue(RollAwayDB.delay)
    _G["RollAwayDelaySliderText"]:Hide()
    _G["RollAwayDelaySliderLow"]:SetText("")
    _G["RollAwayDelaySliderHigh"]:SetText("")
    local delayMin = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    delayMin:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    delayMin:SetText(RA_L["slider_min"])
    local delayMax = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    delayMax:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    delayMax:SetJustifyH("RIGHT")
    delayMax:SetText(RA_L["slider_max"])
    slider:SetScript("OnValueChanged", function(_, value)
        RollAwayDB.delay = math.floor(value)
        sliderDelayVal:SetText(string.format(RA_L["slider_label"], RollAwayDB.delay))
    end)
    if S and S.HandleSliderFrame then S:HandleSliderFrame(slider) end

    local timeoutLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    timeoutLabel:SetPoint("TOPLEFT", delayLabel, "TOPLEFT", 280, 0)
    timeoutLabel:SetText(RA_L["timeout_section_title"])

    local sliderTimeoutVal = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sliderTimeoutVal:SetPoint("TOPLEFT", timeoutLabel, "BOTTOMLEFT", 0, -4)
    sliderTimeoutVal:SetJustifyH("LEFT")
    sliderTimeoutVal:SetText(string.format(RA_L["timeout_slider_label"], RollAwayDB.rollTimeout))

    local sliderTimeout = CreateFrame("Slider", "RollAwayTimeoutSlider", gen, "OptionsSliderTemplate")
    sliderTimeout:SetWidth(200)
    sliderTimeout:SetPoint("TOPLEFT", sliderTimeoutVal, "BOTTOMLEFT", 0, -8)
    sliderTimeout:SetMinMaxValues(30, 180)
    sliderTimeout:SetValueStep(5)
    sliderTimeout:SetValue(RollAwayDB.rollTimeout)
    _G["RollAwayTimeoutSliderText"]:Hide()
    _G["RollAwayTimeoutSliderLow"]:SetText("")
    _G["RollAwayTimeoutSliderHigh"]:SetText("")
    local timeoutMin = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    timeoutMin:SetPoint("TOPLEFT", sliderTimeout, "BOTTOMLEFT", 0, -2)
    timeoutMin:SetText(RA_L["timeout_min"])
    local timeoutMax = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    timeoutMax:SetPoint("TOPRIGHT", sliderTimeout, "BOTTOMRIGHT", 0, -2)
    timeoutMax:SetJustifyH("RIGHT")
    timeoutMax:SetText(RA_L["timeout_max"])
    sliderTimeout:SetScript("OnValueChanged", function(_, value)
        RollAwayDB.rollTimeout = math.floor(value)
        sliderTimeoutVal:SetText(string.format(RA_L["timeout_slider_label"], RollAwayDB.rollTimeout))
    end)
    if S and S.HandleSliderFrame then S:HandleSliderFrame(sliderTimeout) end

    -- Row 2: Sichtbarkeit - hide the Group Loot History frame, per raid difficulty.
    local hideLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hideLabel:SetPoint("TOPLEFT", delayMin, "BOTTOMLEFT", 0, -20)
    hideLabel:SetText(RA_L["hide_in_raid_label"])

    local hideInfo = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hideInfo:SetPoint("TOPLEFT", hideLabel, "BOTTOMLEFT", 0, -4)
    hideInfo:SetWidth(480)
    hideInfo:SetJustifyH("LEFT")
    hideInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    hideInfo:SetText(RA_L["hide_in_raid_info"])

    local hideRow, hideRowCheckboxes = MakeCheckboxRow(gen, hideInfo, {
        { key = "lfr",    label = RA_L["raid_diff_lfr"]    },
        { key = "normal", label = RA_L["raid_diff_normal"] },
        { key = "heroic", label = RA_L["raid_diff_heroic"] },
        { key = "mythic", label = RA_L["raid_diff_mythic"] },
    }, RollAwayDB.hideInRaidBuckets, function(k, checked)
        if type(RollAwayDB.hideInRaidBuckets) ~= "table" then RollAwayDB.hideInRaidBuckets = {} end
        RollAwayDB.hideInRaidBuckets[k] = checked
    end)

    -- Now that the sliders and hideRow checkboxes exist, wire up the actual
    -- enable/disable logic for the master switch above and apply its
    -- initial state.
    SetLootFrameFeatureEnabled = function(enabled)
        local alpha = enabled and 1 or 0.4
        if enabled then slider:Enable() else slider:Disable() end
        slider:SetAlpha(alpha)
        if enabled then sliderTimeout:Enable() else sliderTimeout:Disable() end
        sliderTimeout:SetAlpha(alpha)
        for _, cb in ipairs(hideRowCheckboxes) do
            if cb.SetDisabled then cb:SetDisabled(not enabled) end
        end
        hideInfo:SetAlpha(alpha)
        hideLabel:SetAlpha(alpha)
    end
    SetLootFrameFeatureEnabled(not RollAwayDB.lootFrameAutoCloseDisabled)

    -- Bonus Roll reminder (own section: this popup is specifically the
    -- auto-pass reminder shown when entering a Mythic dungeon/raid).
    local reminderSectionLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    reminderSectionLabel:SetPoint("TOPLEFT", hideRow, "BOTTOMLEFT", 0, -16)
    reminderSectionLabel:SetText(RA_L["bonusroll_reminder_section_title"])

    local cbReminder = MakeCB(gen, RA_L["reminder_label"], RollAwayDB.showReminder, function(checked)
        RollAwayDB.showReminder = checked
    end)
    cbReminder.frame:SetPoint("TOPLEFT", reminderSectionLabel, "BOTTOMLEFT", 0, -10)

    local reminderInfo = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    reminderInfo:SetPoint("TOPLEFT", cbReminder.frame, "BOTTOMLEFT", 20, -6)
    reminderInfo:SetWidth(480)
    reminderInfo:SetJustifyH("LEFT")
    reminderInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    reminderInfo:SetText(RA_L["reminder_info"])

    -- Hide reminder option when Bonus Rolls are disabled, or below max level
    -- (Bonus Roll reminder is meaningless before max level; same gating as
    -- the Dungeons/Raids/Delves/Prey tabs above).
    local showBonusRollReminder = RA.BONUS_ROLLS_ENABLED and not belowMaxLevel
    if not showBonusRollReminder then
        reminderSectionLabel:Hide()
        cbReminder.frame:Hide()
        reminderInfo:Hide()
    end

    -- Row 3: Legacy
    local legacyLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    -- reminderInfo is indented +20 from the outer margin, so -20 undoes that
    -- indent back to the margin; hideRow is already at the outer margin, so
    -- it needs a plain 0 offset - reusing the same -20 here previously
    -- pushed the label off the left edge of the scroll frame.
    if showBonusRollReminder then
        legacyLabel:SetPoint("TOPLEFT", reminderInfo, "BOTTOMLEFT", -20, -14)
    else
        legacyLabel:SetPoint("TOPLEFT", hideRow, "BOTTOMLEFT", 0, -14)
    end
    legacyLabel:SetText(RA_L["legacy_section_title"])

    local cbLegacy = MakeCB(gen, RA_L["legacy_enable_label"], RollAwayDB.legacy, function(checked)
        RollAwayDB.legacy = checked
    end)
    cbLegacy.frame:SetPoint("TOPLEFT", legacyLabel, "BOTTOMLEFT", 0, -10)

    -- Entwickler section: only visible to dev/tester characters
    -- (isDevChar already computed above, for the Bonus Roll tab gating)
    local cmdInfo

    if isDevChar then
        local debugLabel = gen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        debugLabel:SetPoint("TOPLEFT", cbLegacy.frame, "BOTTOMLEFT", 0, -30)
        debugLabel:SetText(RA_L["debug_section_title"])

        local cbDebug = MakeCB(gen, RA_L["debug_label"], RollAwayDB.debug, function(checked)
            RollAwayDB.debug = checked
            if RA.DevOnlyTabButtons then
                for _, b in ipairs(RA.DevOnlyTabButtons) do
                    b:SetShown(RollAwayDB.debug)
                end
            end
            if RA.SeasonTabButtons then
                for _, b in ipairs(RA.SeasonTabButtons) do
                    if RollAwayDB.debug then b:Enable() else b:Disable() end
                    if b.RA_Refresh then b.RA_Refresh() end
                end
            end
            if RA.SeasonTabReflows then
                for _, reflow in ipairs(RA.SeasonTabReflows) do reflow() end
            end
            if RA.SeasonTabDebugChecks then
                for _, check in ipairs(RA.SeasonTabDebugChecks) do check() end
            end
        end)
        cbDebug.frame:SetPoint("TOPLEFT", debugLabel, "BOTTOMLEFT", 0, -10)

        cmdInfo = gen:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        cmdInfo:SetPoint("TOPLEFT", cbDebug.frame, "BOTTOMLEFT", 0, -14)
        cmdInfo:SetWidth(560)
        cmdInfo:SetJustifyH("LEFT")
        cmdInfo:SetTextColor(0.6, 0.6, 0.6, 1)
        cmdInfo:SetText("|cffFFFFFF/rawtest|r  " .. RA_L["cmd_rawtest_info"] .. "\n"
                     .. "|cffFFFFFF/rawreminder|r  " .. RA_L["cmd_rawreminder_info"] .. "\n"
                     .. "|cffFFFFFF/rawreset|r  " .. RA_L["cmd_rawreset_info"] .. "\n"
                     .. "|cffFFFFFF/rawqol|r  " .. RA_L["cmd_rawqol_info"] .. "\n"
                     .. "|cffFFFFFF/rawwhats|r  " .. RA_L["cmd_rawwhats_info"] .. "\n"
                     .. "|cffFFFFFF/rawparagon|r  " .. RA_L["cmd_rawparagon_info"])
    end

    -- Dynamically size the scroll child to hug the last General-tab element,
    -- instead of a fixed oversized height. Deferred one frame so GetTop/GetBottom
    -- reflect actual layout (incl. wrapped multi-line text). Re-run whenever the
    -- dev/tester block visibility (and thus the last element) changes.
    local lastGenElement = isDevChar and cmdInfo or cbLegacy.frame
    local function UpdateGenScrollHeight()
        local top, bottom = gen:GetTop(), lastGenElement:GetBottom()
        if top and bottom then
            local contentHeight = (top - bottom) + 20 -- bottom padding
            gen:SetHeight(math.max(contentHeight, genScroll:GetHeight()))
        end
        -- Explicitly re-check scrollbar visibility instead of relying solely
        -- on the engine's OnScrollRangeChanged timing.
        if scrollBar then
            local yRange = genScroll:GetVerticalScrollRange()
            scrollBar:SetShown((yRange or 0) > 1)
        end
    end
    if RA.C_Timer_After then
        RA.C_Timer_After(0, UpdateGenScrollHeight)
    end

    ------------------------------------------------------------
    -- Tab: Dungeons
    ------------------------------------------------------------
    local dng = tabPanels["dungeons"]
    local dngHint = MakeHintText(dng, dng, RA_L["season1_hint"])
    dngHint:SetPoint("TOPLEFT", dng, "TOPLEFT", 0, -10)

    -- Forward-declared so the master checkbox's onChange (below) can lock/unlock
    -- them once they exist; MakeCheckboxGrid fills these same tables further down.
    local dngS1Checkboxes = {}
    local dngS2Checkboxes = {}
    local function ApplyDungeonAllLock()
        local locked = RollAwayDBChar.dungeonAutoPassAll
        for _, cb in ipairs(dngS1Checkboxes) do cb:SetDisabled(locked) end
        for _, cb in ipairs(dngS2Checkboxes) do cb:SetDisabled(locked) end
    end

    -- Auto-pass ALL dungeons (any season) - OR'd together with the
    -- per-dungeon checkboxes below, same pattern as the raid difficulty switch.
    local dngAllCB = MakeCB(dng, RA_L["dungeon_autopass_all_label"], RollAwayDBChar.dungeonAutoPassAll, function(checked)
        RollAwayDBChar.dungeonAutoPassAll = checked
        ApplyDungeonAllLock()
    end)
    dngAllCB.frame:SetPoint("TOPLEFT", dngHint, "BOTTOMLEFT", 0, -10)

    -- Full-width anchor for the season tab row - MUST be wide (560), since
    -- MakeSeasonTabs derives the content panels' width from this frame.
    local dngSeasonAnchor = CreateFrame("Frame", nil, dng)
    dngSeasonAnchor:SetPoint("TOPLEFT", dngAllCB.frame, "BOTTOMLEFT", 0, 0)
    dngSeasonAnchor:SetSize(560, 1)

    local dngSeasons = MakeSeasonTabs(S, dng, dngSeasonAnchor, {
        { key = "s1", label = RA_L["season1_title"], devOnly = (RA.ACTIVE_SEASON ~= 1), default = (RA.ACTIVE_SEASON == 1) },
        { key = "s2", label = RA_L["season2_tab"], devOnly = (RA.ACTIVE_SEASON ~= 2), default = (RA.ACTIVE_SEASON == 2) },
        { key = "s3", label = RA_L["season3_tab"], devOnly = true },
    })

    -- Season 1 content
    local dngS1Anchor = CreateFrame("Frame", nil, dngSeasons["s1"])
    dngS1Anchor:SetSize(1, 1)
    dngS1Anchor:SetPoint("TOPLEFT", dngSeasons["s1"], "TOPLEFT", 0, 0)
    local _, dngS1CB = MakeCheckboxGrid(dngSeasons["s1"], dngS1Anchor, -8, SEASON1_DUNGEONS, RollAwayDBChar.dungeons, "dungeon_")
    dngS1Checkboxes = dngS1CB

    -- Season 2 content
    local dngS2Anchor = CreateFrame("Frame", nil, dngSeasons["s2"])
    dngS2Anchor:SetSize(1, 1)
    dngS2Anchor:SetPoint("TOPLEFT", dngSeasons["s2"], "TOPLEFT", 0, 0)

    -- Sort alphabetically by the localized dungeon name (current client
    -- locale), not insertion order in Core.lua.
    local sortedS2Dungeons = {}
    for i, d in ipairs(SEASON2_DUNGEONS) do sortedS2Dungeons[i] = d end
    table.sort(sortedS2Dungeons, function(a, b)
        return (RA_L["dungeon_"..a.key] or a.key) < (RA_L["dungeon_"..b.key] or b.key)
    end)

    local _, dngS2CB = MakeCheckboxGrid(dngSeasons["s2"], dngS2Anchor, -8, sortedS2Dungeons, RollAwayDBChar.dungeons_s2, "dungeon_")
    dngS2Checkboxes = dngS2CB

    ApplyDungeonAllLock()

    -- Season 3 placeholder
    local dngS3Label = dngSeasons["s3"]:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    dngS3Label:SetPoint("TOPLEFT", dngSeasons["s3"], "TOPLEFT", 0, -8)
    dngS3Label:SetTextColor(0.5, 0.5, 0.5, 1)
    dngS3Label:SetText(RA_L["season_coming_soon"])

    ------------------------------------------------------------
    -- Tab: Delves
    ------------------------------------------------------------
    local dlv = tabPanels["delves"]
    local dlvHint = MakeHintText(dlv, dlv, RA_L["season1_delve_hint"])
    dlvHint:SetPoint("TOPLEFT", dlv, "TOPLEFT", 0, -10)

    -- Auto-pass ALL delves (any season) - OR'd together with the
    -- per-delve checkboxes below, same pattern as the dungeons tab.
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

    -- Sort Season 2 delves alphabetically by localized name (current
    -- client locale), not insertion order in Core.lua.
    local sortedS2Delves = {}
    for i, d in ipairs(SEASON2_DELVES) do sortedS2Delves[i] = d end
    table.sort(sortedS2Delves, function(a, b)
        return (RA_L["delve_"..a.key] or a.key) < (RA_L["delve_"..b.key] or b.key)
    end)

    -- Single page, grouped by patch version instead of separate tabs.
    -- 12.1 (Season 2) delves stay hidden until RA.ACTIVE_SEASON reaches 2.
    local dlvSections = {
        { titleKey = "patch_12_0", items = SEASON1_DELVES, dbTable = RollAwayDBChar.delves    },
    }
    if RA.ACTIVE_SEASON >= 2 then
        table.insert(dlvSections, { titleKey = "patch_12_1", items = sortedS2Delves, dbTable = RollAwayDBChar.delves_s2 })
    end

    local dlvPrevAnchor   = dlvAllCB.frame
    local dlvPrevOffsetY  = -14
    for _, section in ipairs(dlvSections) do
        local secLabel = dlv:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        secLabel:SetPoint("TOPLEFT", dlvPrevAnchor, "BOTTOMLEFT", 0, dlvPrevOffsetY)
        secLabel:SetText(RA_L[section.titleKey])
        local leftEntries = {}
        for i, item in ipairs(section.items) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local entry = CreateFrame("Frame", nil, dlv)
            entry:SetSize(ENTRY_W, ENTRY_H)
            if col == 0 then
                local yOff   = (row == 0) and -8 or -ROW_GAP
                local anchor = (row == 0) and secLabel or leftEntries[row - 1]
                entry:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
                leftEntries[row] = entry
            else
                entry:SetPoint("LEFT", leftEntries[row], "RIGHT", COL_GAP, 0)
            end
            local labelText = RA_L["delve_"..item.key]
            if item.key == "venomfall_deeps" or item.key == "torments_rise" then
                labelText = labelText .. " |cff888888" .. RA_L["nemesis_delve_label"] .. "|r"
            end
            if item.key == "labyrinth_of_kindojan" then
                labelText = labelText .. " |cff888888[12.1.5]|r"
            end
            local isRemoved = item.removedAfterS1 and RA.ACTIVE_SEASON >= 2
            if isRemoved then
                labelText = labelText .. " |cff888888(removed)|r"
                section.dbTable[item.key] = false
            end
            local isPending = item.pendingTest
            if isPending then
                labelText = labelText .. " |cff888888(coming soon)|r"
                section.dbTable[item.key] = false
            end
            local capturedKey = item.key
            local capturedDB  = section.dbTable
            local dlvCB = MakeCB(entry, labelText, capturedDB[item.key], function(checked)
                capturedDB[capturedKey] = checked
            end)
            if dlvCB then
                dlvCB.frame:SetPoint("LEFT", entry, "LEFT", 0, 0)
                if isRemoved or isPending then
                    dlvCB:SetDisabled(true) -- permanently/temporarily disabled, not affected by the master lock
                else
                    table.insert(dlvAllCheckboxes, dlvCB)
                end
            end
            if i == #section.items then
                dlvPrevAnchor  = (col == 0) and entry or leftEntries[row]
                dlvPrevOffsetY = -16
            end
        end
        if #section.items == 0 then
            dlvPrevAnchor  = secLabel
            dlvPrevOffsetY = -8
        end
    end
    ApplyDelveAllLock()

    ------------------------------------------------------------
    -- Tab: Raids
    ------------------------------------------------------------
    local raidPanel = tabPanels["raids"]
    local raidHint = MakeHintText(raidPanel, raidPanel, RA_L["raid_hint"])
    raidHint:SetPoint("TOPLEFT", raidPanel, "TOPLEFT", 0, -10)

    -- Roll confirmation popups. Global - not tied to season/boss data,
    -- applies to any loot roll (current-tier and legacy raids alike).
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
        if RA.SetRollConfirmEnabled then RA.SetRollConfirmEnabled(k, checked) end
    end)

    -- Auto-pass by whole raid difficulty (applies across all seasons/bosses,
    -- OR'd together with the per-boss checkboxes below).
    local raidDiffLabel = raidPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    raidDiffLabel:SetPoint("TOPLEFT", rollConfirmRow, "BOTTOMLEFT", 0, -12)
    raidDiffLabel:SetText(RA_L["raid_diff_autopass_title"])

    local raidDiffHint = MakeHintText(raidPanel, raidDiffLabel, RA_L["raid_diff_autopass_hint"])

    local raidDiffRow = MakeCheckboxRow(raidPanel, raidDiffHint, {
        { key = "lfr",    label = RA_L["raid_diff_lfr"]    },
        { key = "normal", label = RA_L["raid_diff_normal"] },
        { key = "heroic", label = RA_L["raid_diff_heroic"] },
        { key = "mythic", label = RA_L["raid_diff_mythic"] },
    }, RollAwayDBChar.raidAutoPassDifficulty, function(k, checked)
        if type(RollAwayDBChar.raidAutoPassDifficulty) ~= "table" then RollAwayDBChar.raidAutoPassDifficulty = {} end
        RollAwayDBChar.raidAutoPassDifficulty[k] = checked
    end)

    -- Full-width anchor for the season tab row - MUST be wide (560), since
    -- MakeSeasonTabs derives the content panels' width from this frame.
    local raidSeasonAnchor = CreateFrame("Frame", nil, raidPanel)
    raidSeasonAnchor:SetPoint("TOPLEFT", raidDiffRow, "BOTTOMLEFT", 0, 0)
    raidSeasonAnchor:SetSize(560, 1)

    local raidSeasons = MakeSeasonTabs(S, raidPanel, raidSeasonAnchor, {
        { key = "s1", label = RA_L["season1_title"], devOnly = (RA.ACTIVE_SEASON ~= 1), default = (RA.ACTIVE_SEASON == 1) },
        { key = "s2", label = RA_L["season2_tab"], devOnly = (RA.ACTIVE_SEASON ~= 2), default = (RA.ACTIVE_SEASON == 2) },
        { key = "s3", label = RA_L["season3_tab"], devOnly = true },
    })

    -- Season 1 content
    local raidS1Anchor = CreateFrame("Frame", nil, raidSeasons["s1"])
    raidS1Anchor:SetSize(1, 1)
    raidS1Anchor:SetPoint("TOPLEFT", raidSeasons["s1"], "TOPLEFT", 0, 0)

    local raidSections = {
        { key = "voidspire",       bosses = {} },
        { key = "dreamrift",       bosses = {} },
        { key = "march_queldanas", bosses = {} },
        { key = "sporefall",       bosses = {} },
    }
    for _, b in ipairs(SEASON1_RAIDS) do
        for _, s in ipairs(raidSections) do
            if b.raid == s.key then table.insert(s.bosses, b); break end
        end
    end

    MakeBossSectionGrid(raidSeasons["s1"], raidS1Anchor, raidSections, RollAwayDBChar.raids,
        { sporefall = "|cff888888(12.0.7)|r" })

    -- Season 2 content (The Venomous Abyss + Tidebound Grotto Lair, grouped
    -- by raid like Season 1, since S2 now spans more than one raid).
    local raidS2Anchor = CreateFrame("Frame", nil, raidSeasons["s2"])
    raidS2Anchor:SetSize(1, 1)
    raidS2Anchor:SetPoint("TOPLEFT", raidSeasons["s2"], "TOPLEFT", 0, 0)

    local raidS2MainSections = {
        { key = "venomous_abyss", bosses = {} },
    }
    -- Tidebound Grotto and Kith'ix are both single-boss side content; render
    -- them side by side (left/right column) instead of stacked full-width.
    local raidS2PairSections = {
        { key = "tidebound_grotto",    bosses = {} },
        { key = "unbinding_of_kithix", bosses = {} },
    }
    for _, b in ipairs(SEASON2_RAIDS) do
        for _, s in ipairs(raidS2MainSections) do
            if b.raid == s.key then table.insert(s.bosses, b); break end
        end
        for _, s in ipairs(raidS2PairSections) do
            if b.raid == s.key then table.insert(s.bosses, b); break end
        end
    end

    local raidS2MainAnchor, raidS2MainOffsetY =
        MakeBossSectionGrid(raidSeasons["s2"], raidS2Anchor, raidS2MainSections, RollAwayDBChar.raids)

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

    -- Season 3 placeholder
    local raidS3Label = raidSeasons["s3"]:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    raidS3Label:SetPoint("TOPLEFT", raidSeasons["s3"], "TOPLEFT", 0, -8)
    raidS3Label:SetTextColor(0.5, 0.5, 0.5, 1)
    raidS3Label:SetText(RA_L["season_coming_soon"])

    ------------------------------------------------------------
    -- Tab: Prey
    ------------------------------------------------------------
    local preyPanel = tabPanels["prey"]
    local preyLabel = preyPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    preyLabel:SetPoint("TOPLEFT", preyPanel, "TOPLEFT", 0, -10)
    preyLabel:SetText(RA_L["prey_title"])
    local preyHint = MakeHintText(preyPanel, preyLabel, RA_L["prey_hint"])

    local preyCB = MakeCB(preyPanel, RA_L["prey_toggle_label"], RollAwayDBChar.prey, function(checked)
        RollAwayDBChar.prey = checked
    end)
    preyCB.frame:SetPoint("TOPLEFT", preyHint, "BOTTOMLEFT", 0, -14)

    ------------------------------------------------------------
    -- Tab: Legacy Raids
    ------------------------------------------------------------
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

    local rollDefs = {
        { dbKey = "legacyNeed",     labelKey = "legacy_roll_need"     },
        { dbKey = "legacyGreed",    labelKey = "legacy_roll_greed"    },
        { dbKey = "legacyTransmog", labelKey = "legacy_roll_transmog" },
    }
    local prevRollCB = nil
    for _, rd in ipairs(rollDefs) do
        local capturedKey = rd.dbKey
        local rollCB = MakeCB(legacyPanel, RA_L[rd.labelKey], RollAwayDB[rd.dbKey], function(checked)
            RollAwayDB[capturedKey] = checked
            DBG("[Legacy UI]", capturedKey, "=", tostring(RollAwayDB[capturedKey]))
        end)
        if not prevRollCB then
            rollCB.frame:SetPoint("TOPLEFT", legacyRollLabel, "BOTTOMLEFT", 0, -10)
        else
            rollCB.frame:SetPoint("LEFT", prevRollCB, "RIGHT", 16, 0)
        end
        prevRollCB = rollCB.frame
    end

    local legacyRaidLine = legacyPanel:CreateTexture(nil, "ARTWORK")
    legacyRaidLine:SetHeight(1)
    legacyRaidLine:SetWidth(560)
    legacyRaidLine:SetPoint("TOPLEFT", legacyRollLabel, "BOTTOMLEFT", 0, -44)
    legacyRaidLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    local dfRaids = {
        { key = "vault_of_incarnates", label = "legacy_raid_vault_of_incarnates" },
        { key = "aberrus",             label = "legacy_raid_aberrus"              },
        { key = "amirdrassil",         label = "legacy_raid_amirdrassil"          },
    }
    local twwRaids = {
        { key = "nerubar_palace",       label = "legacy_raid_nerubar_palace"       },
        { key = "liberation_undermine", label = "legacy_raid_liberation_undermine" },
        { key = "manaforge_omega",      label = "legacy_raid_manaforge_omega"      },
    }

    local dfHeader = legacyPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dfHeader:SetPoint("TOPLEFT", legacyRaidLine, "BOTTOMLEFT", 0, -14)
    dfHeader:SetText(RA_L["legacy_col_dragonflight"])

    local twwHeader = legacyPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    twwHeader:SetPoint("TOPLEFT", legacyRaidLine, "BOTTOMLEFT", ENTRY_W + COL_GAP, -14)
    twwHeader:SetText(RA_L["legacy_col_tww"])

    local prevDF = dfHeader
    for _, r in ipairs(dfRaids) do
        local k = r.key
        local legCB = MakeCB(legacyPanel, RA_L[r.label], RA.GetLegacyRaidsDB()[k], function(checked)
            RA.GetLegacyRaidsDB()[k] = checked
        end)
        legCB.frame:SetPoint("TOPLEFT", prevDF, "BOTTOMLEFT", 0, -6)
        table.insert(legacyRaidCBs, { cb = legCB, key = k })
        prevDF = legCB.frame
    end

    local prevTWW = twwHeader
    for _, r in ipairs(twwRaids) do
        local k = r.key
        local legCB = MakeCB(legacyPanel, RA_L[r.label], RA.GetLegacyRaidsDB()[k], function(checked)
            RA.GetLegacyRaidsDB()[k] = checked
        end)
        legCB.frame:SetPoint("TOPLEFT", prevTWW, "BOTTOMLEFT", 0, -6)
        table.insert(legacyRaidCBs, { cb = legCB, key = k })
        prevTWW = legCB.frame
    end

    -- Legacy tab button: only visible when Legacy is enabled
    local legacyTabBtn = tabButtons["legacy"]
    legacyTabBtn:SetShown(RollAwayDB.legacy == true)

    cbLegacy:SetCallback("OnValueChanged", function(widget, _, checked)
        RollAwayDB.legacy = checked
        legacyTabBtn:SetShown(RollAwayDB.legacy == true)
        if not RollAwayDB.legacy and tabPanels["legacy"]:IsShown() then
            ShowTab("general")
        end
    end)

    -- Expose OpenOptionsTab so Reminder.lua can open a specific tab
    function RA.OpenOptionsTab(key)
        RA.RunProtectedOrQueue(function()
            Settings.OpenToCategory(RA_CategoryID)
            ShowTab(key)
        end)
    end


    ------------------------------------------------------------
    -- Subcategory: QoL  (Filter / LFG / Logs / Reminder via left nav)
    -- Built in Options/OptionsQoL.lua.
    ------------------------------------------------------------
    RA.BuildQoLOptions(category, S, classColor, SetTabActive, SetTabInactive)
    RA.BuildProfileOptions(category, S, classColor, SetTabActive, SetTabInactive)

    ShowTab("general")
    Settings.RegisterAddOnCategory(category)
end
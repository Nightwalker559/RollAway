-- RollAway - Options/OptionsQoL.lua
-- Builds the "QoL" settings subcategory (Filter / LFG / Logs / Reminder via
-- left nav). Extracted from Options.lua (no behavior change) - called once
-- from RA.InitOptions() in Options.lua.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

local UI      = RA.OptionsUI
local AceGUI  = UI.AceGUI
local MakeCB  = UI.MakeCB

------------------------------------------------------------------------
-- Subcategory: QoL  (Filter / LFG / Reminder via left nav)
--
-- category:        the main RollAway Settings category (from InitOptions)
-- S:                ElvUI Skins module, or nil
-- classColor:       player class color, for ElvUI tab highlighting
-- SetTabActive/Inactive: shared tab-label color helpers from InitOptions
------------------------------------------------------------------------
function RA.BuildQoLOptions(category, S, classColor, SetTabActive, SetTabInactive)
    local qolPanel = CreateFrame("Frame")
    Settings.RegisterCanvasLayoutSubcategory(category, qolPanel, RA_L["qol_section_title"])

    -- Fixed header (not part of the scrolling content)
    local qolTitle = qolPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    qolTitle:SetPoint("TOPLEFT", qolPanel, "TOPLEFT", 0, -10)
    qolTitle:SetText(RA_L["qol_panel_title"])

    local qolPanelInfo = qolPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolPanelInfo:SetPoint("TOPLEFT", qolTitle, "BOTTOMLEFT", 0, -6)
    qolPanelInfo:SetWidth(560)
    qolPanelInfo:SetJustifyH("LEFT")
    qolPanelInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolPanelInfo:SetText(RA_L["qol_panel_info"])

    local qolHeaderLine = qolPanel:CreateTexture(nil, "ARTWORK")
    qolHeaderLine:SetHeight(1); qolHeaderLine:SetWidth(560)
    qolHeaderLine:SetPoint("TOPLEFT", qolPanelInfo, "BOTTOMLEFT", 0, -10)
    qolHeaderLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Left nav (alphabetical: Filter / LFG / Reminder)
    local QOL_NAV_W = 130

    local qolNavDefs = {
        { key = "filter",   label = RA_L["qol_filter_section"]   },
        { key = "lfg",       label = RA_L["qol_nav_lfg"]          },
        { key = "logs",       label = RA_L["qol_nav_logs"]        },
        { key = "misc",      label = RA_L["qol_nav_misc"]         },
        { key = "reminder", label = RA_L["qol_reminder_section"] },
    }

    local qolCatPanels  = {}
    local qolNavButtons = {}

    local function ShowQolCategory(key)
        for k, p in pairs(qolCatPanels) do p:SetShown(k == key) end
        for k, b in pairs(qolNavButtons) do
            if k == key then
                if b.RA_ApplyActive then b.RA_ApplyActive() else SetTabActive(b) end
            else
                if b.RA_ApplyInactive then b.RA_ApplyInactive() else SetTabInactive(b) end
            end
        end
    end

    local prevNavBtn
    for _, def in ipairs(qolNavDefs) do
        local btn = CreateFrame("Button", nil, qolPanel, "UIPanelButtonTemplate")
        btn:SetSize(QOL_NAV_W, 24)
        btn:SetText(def.label)
        if prevNavBtn then
            btn:SetPoint("TOP", prevNavBtn, "BOTTOM", 0, -4)
        else
            btn:SetPoint("TOPLEFT", qolHeaderLine, "BOTTOMLEFT", 0, -14)
        end
        prevNavBtn = btn
        local capturedKey = def.key
        btn:SetScript("OnClick", function() ShowQolCategory(capturedKey) end)
        if S and RA.ElvSkinTab then RA.ElvSkinTab(btn, qolCatPanels, capturedKey, classColor) end
        qolNavButtons[def.key] = btn
    end

    -- Own ScrollFrame per category; height is fixed (live measurement unreliable).
    -- forceHideBar: force scrollbar hidden until a category needs scrolling.
    local function CreateQolCategoryPanel(name, height, forceHideBar)
        local p = CreateFrame("Frame", nil, qolPanel)
        p:SetPoint("TOPLEFT",     qolHeaderLine, "BOTTOMLEFT", QOL_NAV_W + 16, -14)
        p:SetPoint("BOTTOMRIGHT", qolPanel,      "BOTTOMRIGHT", 0, 0)
        p:Hide()

        local scroll = CreateFrame("ScrollFrame", "RollAwayQol"..name.."Scroll", p, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",     p, "TOPLEFT",     0,   0)
        scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -26, 0)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(420, height)
        scroll:SetScrollChild(content)

        local bar = _G["RollAwayQol"..name.."ScrollScrollBar"]
        scroll:SetScript("OnScrollRangeChanged", function(self, xRange, yRange)
            local max = math.max(0, yRange or 0)
            if bar then
                bar:SetMinMaxValues(0, max)
                bar:SetValue(math.min(bar:GetValue(), max))
                bar:SetShown((not forceHideBar) and max > 1)
            end
        end)
        scroll:SetScript("OnVerticalScroll", function(self, offset)
            if bar then bar:SetValue(offset) end
        end)
        if bar then
            bar:SetScript("OnValueChanged", function(self, value) scroll:SetVerticalScroll(value) end)
            local upBtn   = _G["RollAwayQol"..name.."ScrollScrollBarScrollUpButton"]
            local downBtn = _G["RollAwayQol"..name.."ScrollScrollBarScrollDownButton"]
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
            if forceHideBar then bar:Hide() end
        end

        return p, content, scroll
    end

    -- Estimated heights – adjust here when a category gains/loses an option.
    -- LFG/Reminder: scrollbar force-hidden for now, flip to false once needed.
    local filterPanel,   filter   = CreateQolCategoryPanel("Filter",   430, false)
    local lfgPanel,      lfg      = CreateQolCategoryPanel("Lfg",      260, true)
    local logsPanel,     logs     = CreateQolCategoryPanel("Logs",     380, true)
    local miscPanel,     misc     = CreateQolCategoryPanel("Misc",     200, true)
    local reminderPanel, reminder = CreateQolCategoryPanel("Reminder", 660, true)

    qolCatPanels.filter   = filterPanel
    qolCatPanels.lfg      = lfgPanel
    qolCatPanels.logs     = logsPanel
    qolCatPanels.misc     = miscPanel
    qolCatPanels.reminder = reminderPanel

    -- ── Category: Misc ────────────────────────────────────────────────
    -- Catch-all for settings that don't fit Filter/LFG/Logs/Reminder.

    local qolAutoAcceptCB = MakeCB(misc, RA_L["qol_autoaccept_label"], RollAwayDB.autoAcceptInvite, function(checked)
        RollAwayDB.autoAcceptInvite = checked
    end)
    qolAutoAcceptCB.frame:SetPoint("TOPLEFT", misc, "TOPLEFT", 0, -8)
    if ElvUI then
        qolAutoAcceptCB:SetDisabled(true)
    end

    local qolAutoAcceptInfo = misc:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolAutoAcceptInfo:SetPoint("TOPLEFT", qolAutoAcceptCB.frame, "BOTTOMLEFT", 20, -6)
    qolAutoAcceptInfo:SetWidth(400); qolAutoAcceptInfo:SetJustifyH("LEFT")
    qolAutoAcceptInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolAutoAcceptInfo:SetText(RA_L["qol_autoaccept_info"])

    -- Auto Repair (dropdown: None / Player / Guild) - same Default-UI-only
    -- reasoning as Auto-Accept above.
    local qolAutoRepairLabel = misc:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qolAutoRepairLabel:SetPoint("TOPLEFT", qolAutoAcceptInfo, "BOTTOMLEFT", -20, -14)
    qolAutoRepairLabel:SetText(RA_L["qol_autorepair_label"])

    local AUTOREPAIR_LIST  = {
        ["none"]   = RA_L["qol_autorepair_none"],
        ["player"] = RA_L["qol_autorepair_player"],
        ["guild"]  = RA_L["qol_autorepair_guild"],
    }
    local AUTOREPAIR_ORDER = { "none", "player", "guild" }

    local autoRepairDD
    if AceGUI then
        autoRepairDD = AceGUI:Create("Dropdown")
        autoRepairDD:SetLabel("")
        autoRepairDD:SetList(AUTOREPAIR_LIST, AUTOREPAIR_ORDER)
        autoRepairDD:SetValue(RollAwayDB.autoRepairMode or "none")
        autoRepairDD:SetWidth(160)
        autoRepairDD:SetCallback("OnValueChanged", function(_, _, value)
            RollAwayDB.autoRepairMode = value
        end)
        autoRepairDD.frame:SetParent(misc)
        autoRepairDD.frame:ClearAllPoints()
        autoRepairDD.frame:SetPoint("TOPLEFT", qolAutoRepairLabel, "BOTTOMLEFT", 0, -4)
        autoRepairDD.frame:Show()
        if ElvUI then autoRepairDD:SetDisabled(true) end
    end

    local qolAutoRepairInfo = misc:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolAutoRepairInfo:SetPoint("TOPLEFT", autoRepairDD and autoRepairDD.frame or qolAutoRepairLabel, "BOTTOMLEFT", 20, -6)
    qolAutoRepairInfo:SetWidth(400); qolAutoRepairInfo:SetJustifyH("LEFT")
    qolAutoRepairInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolAutoRepairInfo:SetText(RA_L["qol_autorepair_info"])

    -- ── Category: Reminder (alphabetical by label) ──────────────────────

    -- Great Vault notification
    local qolVaultAlertCB = MakeCB(reminder, RA_L["greatvault_alert_label"], RollAwayDB.greatVaultAlert, function(checked)
        RollAwayDB.greatVaultAlert = checked
    end)
    qolVaultAlertCB.frame:SetPoint("TOPLEFT", reminder, "TOPLEFT", 0, -8)

    local qolVaultAlertInfo = reminder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolVaultAlertInfo:SetPoint("TOPLEFT", qolVaultAlertCB.frame, "BOTTOMLEFT", 20, -6)
    qolVaultAlertInfo:SetWidth(400); qolVaultAlertInfo:SetJustifyH("LEFT")
    qolVaultAlertInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolVaultAlertInfo:SetText(RA_L["greatvault_alert_info"])

    -- Paragon bag notification
    local qolParagonCB = MakeCB(reminder, RA_L["paragon_alert_label"], RollAwayDB.paragonAlert, function(checked)
        RollAwayDB.paragonAlert = checked
    end)
    qolParagonCB.frame:SetPoint("TOPLEFT", qolVaultAlertInfo, "BOTTOMLEFT", -20, -12)

    local qolParagonInfo = reminder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolParagonInfo:SetPoint("TOPLEFT", qolParagonCB.frame, "BOTTOMLEFT", 20, -6)
    qolParagonInfo:SetWidth(400); qolParagonInfo:SetJustifyH("LEFT")
    qolParagonInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolParagonInfo:SetText(RA_L["paragon_alert_info"])

    -- Reminder font size (moved up here since fontSlider.frame is referenced below)
    local fontSlider
    if AceGUI then
        fontSlider = AceGUI:Create("Slider")
        fontSlider:SetLabel(string.format("%s  %d", RA_L["qol_fontsize_label"], RollAwayDB.talentFontSize))
        fontSlider:SetSliderValues(10, 40, 1)
        fontSlider:SetValue(RollAwayDB.talentFontSize)
        fontSlider:SetWidth(220)
        fontSlider:SetCallback("OnValueChanged", function(widget, _, value)
            local v = math.floor(value)
            RollAwayDB.talentFontSize = v
            widget:SetLabel(string.format("%s  %d", RA_L["qol_fontsize_label"], v))
        end)
        fontSlider.frame:SetParent(reminder)
        fontSlider.frame:ClearAllPoints()
        fontSlider.frame:SetPoint("TOPLEFT", qolParagonInfo, "BOTTOMLEFT", -20, -12)
        fontSlider.frame:Show()
        -- AceGUI's layout pass calls Show() on the editbox; hook OnShow to keep it hidden.
        if fontSlider.editbox then
            fontSlider.editbox:SetScript("OnShow", function(self) self:Hide() end)
            C_Timer.After(0, function() if fontSlider.editbox then fontSlider.editbox:Hide() end end)
        end
    else
        -- Fallback ohne AceGUI
        local qolSizeLabel = reminder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        qolSizeLabel:SetPoint("TOPLEFT", qolParagonInfo, "BOTTOMLEFT", -20, -12)
        qolSizeLabel:SetText(RA_L["qol_fontsize_label"])
        local qolSizeVal = reminder:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        qolSizeVal:SetPoint("TOPLEFT", qolSizeLabel, "BOTTOMLEFT", 0, -4)
        qolSizeVal:SetJustifyH("LEFT")
        qolSizeVal:SetText(string.format(RA_L["qol_fontsize_value"], RollAwayDB.talentFontSize))
        local sliderTalent = CreateFrame("Slider", "RollAwayTalentSizeSlider", reminder, "OptionsSliderTemplate")
        sliderTalent:SetWidth(200)
        sliderTalent:SetPoint("TOPLEFT", qolSizeVal, "BOTTOMLEFT", 0, -8)
        sliderTalent:SetMinMaxValues(10, 40)
        sliderTalent:SetValueStep(1)
        sliderTalent:SetValue(RollAwayDB.talentFontSize)
        _G["RollAwayTalentSizeSliderText"]:Hide()
        _G["RollAwayTalentSizeSliderLow"]:SetText("")
        _G["RollAwayTalentSizeSliderHigh"]:SetText("")
        sliderTalent:SetScript("OnValueChanged", function(_, value)
            RollAwayDB.talentFontSize = math.floor(value)
            qolSizeVal:SetText(string.format(RA_L["qol_fontsize_value"], RollAwayDB.talentFontSize))
        end)
        if S and S.HandleSliderFrame then S:HandleSliderFrame(sliderTalent) end
        fontSlider = { frame = sliderTalent }
    end

    -- Durability warning
    local qolDuraCB = MakeCB(reminder, RA_L["qol_durability_label"], RollAwayDB.durabilityWarning, function(checked)
        RollAwayDB.durabilityWarning = checked
    end)
    qolDuraCB.frame:SetPoint("TOPLEFT", fontSlider.frame, "BOTTOMLEFT", 0, -14)

    local qolDuraInfo = reminder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolDuraInfo:SetPoint("TOPLEFT", qolDuraCB.frame, "BOTTOMLEFT", 20, -6)
    qolDuraInfo:SetWidth(400); qolDuraInfo:SetJustifyH("LEFT")
    qolDuraInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolDuraInfo:SetText(RA_L["qol_durability_info"])

    -- Instance join reminder
    local qolJoinCB = MakeCB(reminder, RA_L["qol_join_reminder_label"], RollAwayDB.instanceJoinReminder, function(checked)
        RollAwayDB.instanceJoinReminder = checked
    end)
    qolJoinCB.frame:SetPoint("TOPLEFT", qolDuraInfo, "BOTTOMLEFT", -20, -12)

    local qolJoinInfo = reminder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolJoinInfo:SetPoint("TOPLEFT", qolJoinCB.frame, "BOTTOMLEFT", 20, -6)
    qolJoinInfo:SetWidth(400); qolJoinInfo:SetJustifyH("LEFT")
    qolJoinInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolJoinInfo:SetText(RA_L["qol_join_reminder_info"])

    -- Sub-option: keystone companion addon (BigWigs / Details! / RollAway
    -- Teleport reminder — mutually exclusive)
    local qolKeyAddonLabel = reminder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qolKeyAddonLabel:SetPoint("TOPLEFT", qolJoinInfo, "BOTTOMLEFT", 0, -10)
    qolKeyAddonLabel:SetText(RA_L["qol_join_keyaddon_label"])

    local cbBigWigs = MakeCB(reminder, RA_L["qol_join_keyaddon_bigwigs"], nil, nil)
    cbBigWigs.frame:SetPoint("TOPLEFT", qolKeyAddonLabel, "BOTTOMLEFT", 0, -6)

    local cbDetails = MakeCB(reminder, RA_L["qol_join_keyaddon_details"], nil, nil)
    cbDetails.frame:SetPoint("LEFT", cbBigWigs.frame, "RIGHT", 10, 0)

    local cbTeleport = MakeCB(reminder, RA_L["qol_join_keyaddon_teleport"], nil, nil)
    cbTeleport.frame:SetPoint("LEFT", cbDetails.frame, "RIGHT", 10, 0)

    local qolKeyAddonInfo = reminder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolKeyAddonInfo:SetPoint("TOPLEFT", cbBigWigs.frame, "BOTTOMLEFT", 20, -6)
    qolKeyAddonInfo:SetWidth(400); qolKeyAddonInfo:SetJustifyH("LEFT")
    qolKeyAddonInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolKeyAddonInfo:SetText(RA_L["qol_join_keyaddon_info"])

    -- Re-syncs checkbox state from saved DB + live addon detection. Does NOT
    -- clear the saved choice when the addon isn't detected right now - BigWigs'
    -- Keystones sub-module (SlashCmdList["key"]) often isn't registered yet at
    -- options-open time (e.g. right after login), which used to wipe the saved
    -- setting back to "none" on every panel open even though the addon was
    -- actually installed. The checkbox just greys out until it's detected;
    -- the saved value (and GetActiveKeyAddon's own live check) stays intact.
    -- The teleport reminder is always available (no external addon needed).
    local function RefreshKeyAddonCheckboxes()
        local bwOK = RA.IsBigWigsKeyAvailable and RA.IsBigWigsKeyAvailable()
        local dtOK = RA.IsDetailsKeyAvailable and RA.IsDetailsKeyAvailable()

        cbBigWigs:SetValue(RollAwayDB.joinReminderKeyAddon == "bigwigs")
        cbDetails:SetValue(RollAwayDB.joinReminderKeyAddon == "details")
        cbTeleport:SetValue(RollAwayDB.joinReminderKeyAddon == "teleport")

        cbBigWigs:SetDisabled(not bwOK)
        cbDetails:SetDisabled(not dtOK)
    end

    cbBigWigs:SetCallback("OnValueChanged", function(widget, _, value)
        RollAwayDB.joinReminderKeyAddon = value and "bigwigs" or "none"
        RefreshKeyAddonCheckboxes()
    end)
    cbDetails:SetCallback("OnValueChanged", function(widget, _, value)
        RollAwayDB.joinReminderKeyAddon = value and "details" or "none"
        RefreshKeyAddonCheckboxes()
    end)
    cbTeleport:SetCallback("OnValueChanged", function(widget, _, value)
        RollAwayDB.joinReminderKeyAddon = value and "teleport" or "none"
        RefreshKeyAddonCheckboxes()
    end)

    RefreshKeyAddonCheckboxes()

    -- Re-check on every panel open, since addon load order isn't guaranteed.
    qolPanel:HookScript("OnShow", RefreshKeyAddonCheckboxes)

    -- Sub-option: separate companion addon choice for manually formed (premade)
    -- groups. No teleport option here - RollAway Teleport Reminder needs an
    -- LFG activity ID to know the exact dungeon, which premade groups don't have.
    -- Thin divider + extra gap so this reads as a clearly separate block from
    -- the Group Finder keyaddon choice above it, not a continuation of it.
    local qolPremadeDivider = reminder:CreateTexture(nil, "ARTWORK")
    qolPremadeDivider:SetHeight(1)
    qolPremadeDivider:SetWidth(400)
    qolPremadeDivider:SetPoint("TOPLEFT", qolKeyAddonInfo, "BOTTOMLEFT", -20, -14)
    qolPremadeDivider:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    local qolPremadeLabel = reminder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qolPremadeLabel:SetPoint("TOPLEFT", qolPremadeDivider, "BOTTOMLEFT", 0, -14)
    qolPremadeLabel:SetText(RA_L["qol_premade_keyaddon_label"])

    local cbPremadeBigWigs = MakeCB(reminder, RA_L["qol_join_keyaddon_bigwigs"], nil, nil)
    cbPremadeBigWigs.frame:SetPoint("TOPLEFT", qolPremadeLabel, "BOTTOMLEFT", 0, -6)

    local cbPremadeDetails = MakeCB(reminder, RA_L["qol_join_keyaddon_details"], nil, nil)
    cbPremadeDetails.frame:SetPoint("LEFT", cbPremadeBigWigs.frame, "RIGHT", 10, 0)

    local qolPremadeInfo = reminder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolPremadeInfo:SetPoint("TOPLEFT", cbPremadeBigWigs.frame, "BOTTOMLEFT", 20, -6)
    qolPremadeInfo:SetWidth(400); qolPremadeInfo:SetJustifyH("LEFT")
    qolPremadeInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolPremadeInfo:SetText(RA_L["qol_premade_keyaddon_info"])

    local function RefreshPremadeKeyAddonCheckboxes()
        local bwOK = RA.IsBigWigsKeyAvailable and RA.IsBigWigsKeyAvailable()
        local dtOK = RA.IsDetailsKeyAvailable and RA.IsDetailsKeyAvailable()

        cbPremadeBigWigs:SetValue(RollAwayDB.premadeKeyAddon == "bigwigs")
        cbPremadeDetails:SetValue(RollAwayDB.premadeKeyAddon == "details")

        cbPremadeBigWigs:SetDisabled(not bwOK)
        cbPremadeDetails:SetDisabled(not dtOK)
    end

    cbPremadeBigWigs:SetCallback("OnValueChanged", function(widget, _, value)
        RollAwayDB.premadeKeyAddon = value and "bigwigs" or "none"
        RefreshPremadeKeyAddonCheckboxes()
    end)
    cbPremadeDetails:SetCallback("OnValueChanged", function(widget, _, value)
        RollAwayDB.premadeKeyAddon = value and "details" or "none"
        RefreshPremadeKeyAddonCheckboxes()
    end)

    RefreshPremadeKeyAddonCheckboxes()
    qolPanel:HookScript("OnShow", RefreshPremadeKeyAddonCheckboxes)

    -- Ready Check talent reminder (last alphabetically: "Show talent reminder...")
    local qolCB = MakeCB(reminder, RA_L["qol_readycheck_label"], RollAwayDB.readyCheckReminder, function(checked)
        RollAwayDB.readyCheckReminder = checked
    end)
    qolCB.frame:SetPoint("TOPLEFT", qolPremadeInfo, "BOTTOMLEFT", -40, -12)

    local qolInfo = reminder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolInfo:SetPoint("TOPLEFT", qolCB.frame, "BOTTOMLEFT", 20, -6)
    qolInfo:SetWidth(400); qolInfo:SetJustifyH("LEFT")
    qolInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolInfo:SetText(RA_L["qol_readycheck_info"])

    -- ── Category: Filter (alphabetical by label) ─────────────────────────

    local qolAHCB = MakeCB(filter, RA_L["qol_expansion_filter_label"], RollAwayDB.expansionFilterAH, function(checked)
        RollAwayDB.expansionFilterAH = checked
    end)
    qolAHCB.frame:SetPoint("TOPLEFT", filter, "TOPLEFT", 0, -8)

    local qolAHInfo = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolAHInfo:SetPoint("TOPLEFT", qolAHCB.frame, "BOTTOMLEFT", 20, -6)
    qolAHInfo:SetWidth(400); qolAHInfo:SetJustifyH("LEFT")
    qolAHInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolAHInfo:SetText(RA_L["qol_expansion_filter_info"])

    -- Anchor advances past shown widgets so hidden ones leave no gap.
    local qolChainAnchor = qolAHInfo
    local isMaxLevel = RA.IsMaxLevel and RA.IsMaxLevel()

    -- Omniumfoliant: hide minimap icon, show button on Character Frame
    -- Longest checkbox label in the file - explicit width so it wraps
    -- instead of running off-panel on one line.
    local qolOmniCB = MakeCB(filter, RA_L["qol_omniumfoliant_label"], RollAwayDB.hideOmniumfoliantMinimap, function(checked)
        RollAwayDB.hideOmniumfoliantMinimap = checked
        if RA.ApplyOmniumfoliantFeature then RA.ApplyOmniumfoliantFeature() end
    end, 400)
    qolOmniCB.frame:SetPoint("TOPLEFT", qolChainAnchor, "BOTTOMLEFT", -20, -12)
    qolOmniCB.frame:SetHeight(40) -- room for the wrapped 2-line label

    local qolOmniInfo = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolOmniInfo:SetPoint("TOPLEFT", qolOmniCB.frame, "BOTTOMLEFT", 20, -6)
    qolOmniInfo:SetWidth(400); qolOmniInfo:SetJustifyH("LEFT")
    qolOmniInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolOmniInfo:SetText(RA_L["qol_omniumfoliant_info"])

    -- Hide these options pre-max-level, matching the QoL.lua feature gate.
    if not isMaxLevel then
        qolOmniCB.frame:Hide()
        qolOmniInfo:Hide()
    else
        qolChainAnchor = qolOmniInfo
    end

    -- World Map: hide tracked-faction activity button (experimental)
    local qolMapActCB = MakeCB(filter, RA_L["qol_map_activity_label"], RollAwayDB.hideMapActivityTracker, function(checked)
        RollAwayDB.hideMapActivityTracker = checked
        if RA.ApplyMapActivityTrackerFeature then RA.ApplyMapActivityTrackerFeature() end
    end)
    qolMapActCB.frame:SetPoint("TOPLEFT", qolChainAnchor, "BOTTOMLEFT", -20, -12)

    local qolMapActInfo = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolMapActInfo:SetPoint("TOPLEFT", qolMapActCB.frame, "BOTTOMLEFT", 20, -6)
    qolMapActInfo:SetWidth(400); qolMapActInfo:SetJustifyH("LEFT")
    qolMapActInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolMapActInfo:SetText(RA_L["qol_map_activity_info"])

    qolChainAnchor = qolMapActInfo

    -- Professions: hide "Crafting Output Log" popup
    local qolCraftLogCB = MakeCB(filter, RA_L["qol_crafting_output_log_label"], RollAwayDB.hideCraftingOutputLog, function(checked)
        RollAwayDB.hideCraftingOutputLog = checked
        if RA.ApplyCraftingOutputLogFeature then RA.ApplyCraftingOutputLogFeature() end
    end)
    qolCraftLogCB.frame:SetPoint("TOPLEFT", qolChainAnchor, "BOTTOMLEFT", -20, -12)

    local qolCraftLogInfo = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolCraftLogInfo:SetPoint("TOPLEFT", qolCraftLogCB.frame, "BOTTOMLEFT", 20, -6)
    qolCraftLogInfo:SetWidth(400); qolCraftLogInfo:SetJustifyH("LEFT")
    qolCraftLogInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolCraftLogInfo:SetText(RA_L["qol_crafting_output_log_info"])

    qolChainAnchor = qolCraftLogInfo

    -- Great Vault button on Character Frame
    local qolVaultBtnCB = MakeCB(filter, RA_L["qol_vault_button_label"], RollAwayDB.vaultButtonCharFrame, function(checked)
        RollAwayDB.vaultButtonCharFrame = checked
        if RA.ApplyVaultButtonFeature then RA.ApplyVaultButtonFeature() end
    end)
    qolVaultBtnCB.frame:SetPoint("TOPLEFT", qolChainAnchor, "BOTTOMLEFT", -20, -12)

    local qolVaultBtnInfo = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolVaultBtnInfo:SetPoint("TOPLEFT", qolVaultBtnCB.frame, "BOTTOMLEFT", 20, -6)
    qolVaultBtnInfo:SetWidth(400); qolVaultBtnInfo:SetJustifyH("LEFT")
    qolVaultBtnInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolVaultBtnInfo:SetText(RA_L["qol_vault_button_info"])

    if not isMaxLevel then
        qolVaultBtnCB.frame:Hide()
        qolVaultBtnInfo:Hide()
    else
        qolChainAnchor = qolVaultBtnInfo
    end

    -- Vault currency display
    local qolVaultCB = MakeCB(filter, RA_L["qol_vault_currency_label"], RollAwayDB.vaultCurrencyDisplay, function(checked)
        RollAwayDB.vaultCurrencyDisplay = checked
    end)
    qolVaultCB.frame:SetPoint("TOPLEFT", qolChainAnchor, "BOTTOMLEFT", -20, -12)

    local qolVaultInfo = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolVaultInfo:SetPoint("TOPLEFT", qolVaultCB.frame, "BOTTOMLEFT", 20, -6)
    qolVaultInfo:SetWidth(400); qolVaultInfo:SetJustifyH("LEFT")
    qolVaultInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolVaultInfo:SetText(RA_L["qol_vault_currency_info"])

    if not (RA.BONUS_ROLLS_ENABLED and isMaxLevel) then
        qolVaultCB.frame:Hide()
        qolVaultInfo:Hide()
    else
        qolChainAnchor = qolVaultInfo
    end

    -- Vendor Filter Light: dim already-known/maxed vendor items
    local qolVendorFilterCB = MakeCB(filter, RA_L["qol_vendor_filter_label"], RollAwayDB.vendorFilterEnabled, function(checked)
        RollAwayDB.vendorFilterEnabled = checked
        if checked then
            if RA.ApplyVendorFilterFeature then RA.ApplyVendorFilterFeature() end
        else
            if RA.ResetVendorFilterButtons then RA.ResetVendorFilterButtons() end
        end
    end)
    qolVendorFilterCB.frame:SetPoint("TOPLEFT", qolChainAnchor, "BOTTOMLEFT", -20, -12)

    local qolVendorFilterInfo = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolVendorFilterInfo:SetPoint("TOPLEFT", qolVendorFilterCB.frame, "BOTTOMLEFT", 20, -6)
    qolVendorFilterInfo:SetWidth(400); qolVendorFilterInfo:SetJustifyH("LEFT")
    qolVendorFilterInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolVendorFilterInfo:SetText(RA_L["qol_vendor_filter_info"])

    -- Alpha slider (only meaningful together with the toggle above)
    if AceGUI then
        local vendorAlphaSlider = AceGUI:Create("Slider")
        vendorAlphaSlider:SetLabel(string.format("%s  %d%%", RA_L["qol_vendor_filter_alpha_label"], math.floor(RollAwayDB.vendorFilterAlpha * 100 + 0.5)))
        vendorAlphaSlider:SetSliderValues(10, 100, 5)
        vendorAlphaSlider:SetValue(math.floor(RollAwayDB.vendorFilterAlpha * 100 + 0.5))
        vendorAlphaSlider:SetWidth(220)
        vendorAlphaSlider:SetCallback("OnValueChanged", function(widget, _, value)
            local v = math.floor(value)
            RollAwayDB.vendorFilterAlpha = v / 100
            widget:SetLabel(string.format("%s  %d%%", RA_L["qol_vendor_filter_alpha_label"], v))
            if RollAwayDB.vendorFilterEnabled and RA.ApplyVendorFilterFeature then
                RA.ApplyVendorFilterFeature()
            end
        end)
        vendorAlphaSlider.frame:SetParent(filter)
        vendorAlphaSlider.frame:ClearAllPoints()
        vendorAlphaSlider.frame:SetPoint("TOPLEFT", qolVendorFilterInfo, "BOTTOMLEFT", -20, -12)
        vendorAlphaSlider.frame:Show()
        if vendorAlphaSlider.editbox then
            vendorAlphaSlider.editbox:SetScript("OnShow", function(self) self:Hide() end)
            C_Timer.After(0, function() if vendorAlphaSlider.editbox then vendorAlphaSlider.editbox:Hide() end end)
        end
    else
        -- Fallback ohne AceGUI
        local vendorAlphaLabel = filter:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        vendorAlphaLabel:SetPoint("TOPLEFT", qolVendorFilterInfo, "BOTTOMLEFT", -20, -12)
        vendorAlphaLabel:SetText(RA_L["qol_vendor_filter_alpha_label"])
        local vendorAlphaVal = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        vendorAlphaVal:SetPoint("TOPLEFT", vendorAlphaLabel, "BOTTOMLEFT", 0, -4)
        vendorAlphaVal:SetJustifyH("LEFT")
        vendorAlphaVal:SetText(string.format("%d%%", math.floor(RollAwayDB.vendorFilterAlpha * 100 + 0.5)))
        local sliderVendorAlpha = CreateFrame("Slider", "RollAwayVendorAlphaSlider", filter, "OptionsSliderTemplate")
        sliderVendorAlpha:SetWidth(200)
        sliderVendorAlpha:SetPoint("TOPLEFT", vendorAlphaVal, "BOTTOMLEFT", 0, -8)
        sliderVendorAlpha:SetMinMaxValues(10, 100)
        sliderVendorAlpha:SetValueStep(5)
        sliderVendorAlpha:SetValue(math.floor(RollAwayDB.vendorFilterAlpha * 100 + 0.5))
        _G["RollAwayVendorAlphaSliderText"]:Hide()
        _G["RollAwayVendorAlphaSliderLow"]:SetText("")
        _G["RollAwayVendorAlphaSliderHigh"]:SetText("")
        sliderVendorAlpha:SetScript("OnValueChanged", function(_, value)
            local v = math.floor(value)
            RollAwayDB.vendorFilterAlpha = v / 100
            vendorAlphaVal:SetText(string.format("%d%%", v))
            if RollAwayDB.vendorFilterEnabled and RA.ApplyVendorFilterFeature then
                RA.ApplyVendorFilterFeature()
            end
        end)
        if S and S.HandleSliderFrame then S:HandleSliderFrame(sliderVendorAlpha) end
    end

    -- ── Category: Logs ─────────────────────────────────────────────────

    -- Master toggle
    local logSubCBs = {}
    local function UpdateLogSubCBsState()
        local enabled = RollAwayDB.autoLogEnabled
        for _, cb in ipairs(logSubCBs) do
            cb:SetDisabled(not enabled)
        end
    end

    local qolLogMasterCB = MakeCB(logs, RA_L["qol_log_enable_label"], RollAwayDB.autoLogEnabled, function(checked)
        RollAwayDB.autoLogEnabled = checked
        UpdateLogSubCBsState()
    end)
    qolLogMasterCB.frame:SetPoint("TOPLEFT", logs, "TOPLEFT", 0, -8)

    local qolLogMasterInfo = logs:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qolLogMasterInfo:SetPoint("TOPLEFT", qolLogMasterCB.frame, "BOTTOMLEFT", 20, -6)
    qolLogMasterInfo:SetWidth(380); qolLogMasterInfo:SetJustifyH("LEFT")
    qolLogMasterInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    qolLogMasterInfo:SetText(RA_L["qol_log_enable_info"])

    -- Compact zone checkbox list (no per-item info text, mirrors MRT's layout)
    local LOG_ZONE_DEFS = {
        { dbKey = "autoLogScenario",      labelKey = "qol_log_scenario_label"     },
        { dbKey = "autoLogMythicDungeon", labelKey = "qol_log_dungeon_label"      },
        { dbKey = "autoLogRaidMythic",    labelKey = "qol_log_raid_mythic_label"  },
        { dbKey = "autoLogRaidHeroic",    labelKey = "qol_log_raid_heroic_label"  },
        { dbKey = "autoLogRaidNormal",    labelKey = "qol_log_raid_normal_label"  },
        { dbKey = "autoLogRaidLFR",       labelKey = "qol_log_raid_lfr_label"     },
        { dbKey = "autoLogDelve",         labelKey = "qol_log_delve_label"        },
        { dbKey = "autoLogArena",         labelKey = "qol_log_arena_label"        },
    }

    local logZoneAnchor = qolLogMasterInfo
    local isFirstLogZone = true
    for _, def in ipairs(LOG_ZONE_DEFS) do
        local capturedKey = def.dbKey
        local cb = MakeCB(logs, RA_L[def.labelKey], RollAwayDB[def.dbKey], function(checked)
            RollAwayDB[capturedKey] = checked
        end)
        -- First item hangs off the (indented) info text, so it needs -20 to
        -- land back at x=0. Every item after that chains checkbox->checkbox
        -- directly, already at x=0, so no further horizontal offset.
        cb.frame:SetPoint("TOPLEFT", logZoneAnchor, "BOTTOMLEFT", isFirstLogZone and -20 or 0, -10)
        isFirstLogZone = false
        logZoneAnchor = cb.frame
        table.insert(logSubCBs, cb)
    end

    -- Chat notification toggle (own line, separated from the zone list)
    local qolLogChatCB = MakeCB(logs, RA_L["qol_log_chatnotify_label"], RollAwayDB.autoLogChatNotify, function(checked)
        RollAwayDB.autoLogChatNotify = checked
    end)
    qolLogChatCB.frame:SetPoint("TOPLEFT", logZoneAnchor, "BOTTOMLEFT", 0, -16)
    table.insert(logSubCBs, qolLogChatCB)

    -- Advanced Combat Logging reminder popup toggle - independent of the
    -- master toggle above, so it still works for players who log manually.
    local qolLogAdvReminderCB = MakeCB(logs, RA_L["qol_log_advlog_reminder_label"], RollAwayDB.advLogReminderEnabled, function(checked)
        RollAwayDB.advLogReminderEnabled = checked
    end)
    qolLogAdvReminderCB.frame:SetPoint("TOPLEFT", qolLogChatCB.frame, "BOTTOMLEFT", 0, -10)

    UpdateLogSubCBsState()

    -- ── Category: LFG (alphabetical by label) ─────────────────────────────

    -- Auto-apply playstyle checkbox
    local lfgqcAutoPSCB = MakeCB(lfg, RA_L["qol_lfgqc_autops_label"], RollAwayDB.lfgAutoPlaystyle, nil)
    lfgqcAutoPSCB.frame:SetPoint("TOPLEFT", lfg, "TOPLEFT", 0, -8)

    local lfgqcAutoPSInfo = lfg:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lfgqcAutoPSInfo:SetPoint("TOPLEFT", lfgqcAutoPSCB.frame, "BOTTOMLEFT", 20, -6)
    lfgqcAutoPSInfo:SetWidth(400); lfgqcAutoPSInfo:SetJustifyH("LEFT")
    lfgqcAutoPSInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    lfgqcAutoPSInfo:SetText(RA_L["qol_lfgqc_autops_info"])

    -- Default playstyle label (indented, sub-option of autops checkbox)
    local lfgqcPSLabel = lfg:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lfgqcPSLabel:SetPoint("TOPLEFT", lfgqcAutoPSInfo, "BOTTOMLEFT", 0, -12)
    lfgqcPSLabel:SetText(RA_L["qol_lfgqc_playstyle_label"])

    -- Standard-Spielstil Dropdown (AceGUI – ElvUI-nativer Skin)
    local PLAYSTYLE_LIST  = {
        [0] = RA_L["qol_lfgqc_ps_none"],
        [1] = RA_L["qol_lfgqc_ps_standard"],
        [2] = RA_L["qol_lfgqc_ps_relaxed"],
        [3] = RA_L["qol_lfgqc_ps_competitive"],
        [4] = RA_L["qol_lfgqc_ps_carry"],
    }
    local PLAYSTYLE_ORDER = { 0, 1, 2, 3, 4 }

    -- psDD only exists with AceGUI; guarded below so state still saves without it.
    local psDD
    if AceGUI then
        psDD = AceGUI:Create("Dropdown")
        psDD:SetLabel("")  -- label is above the widget
        psDD:SetList(PLAYSTYLE_LIST, PLAYSTYLE_ORDER)
        psDD:SetValue(RollAwayDB.lfgDefaultPlaystyle or 0)
        psDD:SetWidth(160)
        psDD:SetCallback("OnValueChanged", function(_, _, value)
            RollAwayDB.lfgDefaultPlaystyle = value
        end)
        psDD.frame:SetParent(lfg)
        psDD.frame:ClearAllPoints()
        psDD.frame:SetPoint("TOPLEFT", lfgqcPSLabel, "BOTTOMLEFT", 0, -4)
        psDD.frame:Show()
    end

    -- Enable/disable label and dropdown based on checkbox state
    local function UpdatePSState(enabled)
        if enabled then
            lfgqcPSLabel:SetTextColor(1, 1, 1, 1)
            if psDD then psDD:SetDisabled(false) end
        else
            lfgqcPSLabel:SetTextColor(0.5, 0.5, 0.5, 1)
            if psDD then psDD:SetDisabled(true) end
        end
    end

    UpdatePSState(RollAwayDB.lfgAutoPlaystyle)

    lfgqcAutoPSCB:SetCallback("OnValueChanged", function(widget, _, checked)
        RollAwayDB.lfgAutoPlaystyle = checked
        UpdatePSState(checked)
    end)

    -- Enable checkbox (last alphabetically: "Show dungeon quick-create...")
    local lfgqcCB = MakeCB(lfg, RA_L["qol_lfgqc_label"], RollAwayDB.lfgQuickCreate, function(checked)
        RollAwayDB.lfgQuickCreate = checked
    end)
    lfgqcCB.frame:SetPoint("TOPLEFT", psDD and psDD.frame or lfgqcPSLabel, "BOTTOMLEFT", -20, -14)

    local lfgqcInfo = lfg:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lfgqcInfo:SetPoint("TOPLEFT", lfgqcCB.frame, "BOTTOMLEFT", 20, -6)
    lfgqcInfo:SetWidth(400); lfgqcInfo:SetJustifyH("LEFT")
    lfgqcInfo:SetTextColor(0.6, 0.6, 0.6, 1)
    lfgqcInfo:SetText(RA_L["qol_lfgqc_info"])

    -- Default category on open (alphabetically first)
    ShowQolCategory("filter")

    return qolPanel
end

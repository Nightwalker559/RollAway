-- RollAway - Options/OptionsQoL.lua
-- Builds the "QoL" settings subcategory (Filter / LFG / Logs / Misc /
-- Quests / Reminder via left nav) - called once from RA.InitOptions() in Options/Options.lua.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

local UI      = RA.OptionsUI
local MakeCB  = UI.MakeCB
local MakeInfoText = UI.MakeInfoText
local MakeToggle = UI.MakeToggle
local MakeDropdown = UI.MakeDropdown
local MakeValueSlider = UI.MakeValueSlider
local MakeSkinnedButton = UI.MakeSkinnedButton

------------------------------------------------------------------------
-- Subcategory: QoL  (Character / Filter / Hide / LFG / Logs / Misc / Quests /
-- Reminder via left nav, sorted alphabetically by the shown label)
--
-- category:        the main RollAway Settings category (from InitOptions)
-- S:                ElvUI Skins module, or nil
-- classColor:       player class color, for ElvUI tab highlighting
------------------------------------------------------------------------
function RA.BuildQoLOptions(category, S, classColor)
    local qolPanel = CreateFrame("Frame")
    Settings.RegisterCanvasLayoutSubcategory(category, qolPanel, RA_L["qol_section_title"])

    -- Fixed header (not part of the scrolling content)
    local qolTitle = qolPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    qolTitle:SetPoint("TOPLEFT", qolPanel, "TOPLEFT", 0, -10)
    qolTitle:SetText(RA_L["qol_panel_title"])

    local qolPanelInfo = MakeInfoText(qolPanel, qolTitle, 0, -6, 560, RA_L["qol_panel_info"])

    local qolHeaderLine = qolPanel:CreateTexture(nil, "ARTWORK")
    qolHeaderLine:SetHeight(1); qolHeaderLine:SetWidth(560)
    qolHeaderLine:SetPoint("TOPLEFT", qolPanelInfo, "BOTTOMLEFT", 0, -10)
    qolHeaderLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Left nav, sorted alphabetically by the label shown (so the order follows
    -- the client language). The Character tab only holds max-level features,
    -- so it does not exist below max level.
    local QOL_NAV_W = 130
    local isMaxLevel = RA.IsMaxLevel()

    local qolNavDefs = {
        { key = "character", label = RA_L["qol_nav_character"], show = isMaxLevel },
        { key = "filter",    label = RA_L["qol_filter_section"]   },
        { key = "hide",      label = RA_L["qol_nav_hide"]         },
        { key = "lfg",       label = RA_L["qol_nav_lfg"]          },
        { key = "logs",      label = RA_L["qol_nav_logs"]         },
        { key = "misc",      label = RA_L["qol_nav_misc"]         },
        { key = "quests",    label = RA_L["qol_nav_quests"]       },
        { key = "reminder",  label = RA_L["qol_reminder_section"] },
    }
    for i = #qolNavDefs, 1, -1 do
        if qolNavDefs[i].show == false then table.remove(qolNavDefs, i) end
    end
    table.sort(qolNavDefs, function(a, b) return a.label:lower() < b.label:lower() end)

    local qolCatPanels  = {}
    local qolNavButtons = {}
    local ShowQolCategory = UI.MakeTabSelector(qolCatPanels, qolNavButtons)

    local prevNavBtn
    for _, def in ipairs(qolNavDefs) do
        local key = def.key
        local btn = CreateFrame("Button", nil, qolPanel, "UIPanelButtonTemplate")
        btn:SetSize(QOL_NAV_W, 24)
        btn:SetText(def.label)
        if prevNavBtn then
            btn:SetPoint("TOP", prevNavBtn, "BOTTOM", 0, -4)
        else
            btn:SetPoint("TOPLEFT", qolHeaderLine, "BOTTOMLEFT", 0, -14)
        end
        prevNavBtn = btn
        btn:SetScript("OnClick", function() ShowQolCategory(key) end)
        if S and RA.ElvSkinTab then RA.ElvSkinTab(btn, qolCatPanels, key, classColor) end
        qolNavButtons[key] = btn
    end

    -- Own ScrollFrame per category; height is fixed (live measurement unreliable).
    -- forceHideBar: force scrollbar hidden until a category needs scrolling.
    -- Estimated heights - adjust when a category gains/loses an option.
    local function CreateQolCategoryPanel(key, name, height, forceHideBar)
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

        UI.SetupScrollBar(scroll, _G["RollAwayQol"..name.."ScrollScrollBar"], S, forceHideBar)

        qolCatPanels[key] = p
        return content
    end

    -- LFG/Logs/Misc/Reminder: scrollbar force-hidden for now, flip to false once needed.
    local character = isMaxLevel and CreateQolCategoryPanel("character", "Character", 280, true) or nil
    local filter   = CreateQolCategoryPanel("filter",   "Filter",   260, true)
    local hide     = CreateQolCategoryPanel("hide",     "Hide",     460, false)
    local lfg      = CreateQolCategoryPanel("lfg",      "Lfg",      380, true)
    local logs     = CreateQolCategoryPanel("logs",     "Logs",     380, true)
    local misc      = CreateQolCategoryPanel("misc",     "Misc",     200, true)
    local quests   = CreateQolCategoryPanel("quests",   "Quests",   400, true)
    local reminder = CreateQolCategoryPanel("reminder", "Reminder", 660, true)

    -- ── Category: Misc ────────────────────────────────────────────────
    -- Catch-all for settings that don't fit Filter/LFG/Logs/Reminder.

    -- Auto-accept invites and Auto Repair are Default-UI-only: ElvUI ships
    -- its own versions of both.
    local qolAutoAcceptCB, qolAutoAcceptInfo = MakeToggle(misc, nil, 0, -8, {
        label = RA_L["qol_autoaccept_label"], info = RA_L["qol_autoaccept_info"], dbKey = "autoAcceptInvite",
    })
    if ElvUI then qolAutoAcceptCB:SetDisabled(true) end

    -- Auto Repair (dropdown: None / Player / Guild)
    local qolAutoRepairLabel = misc:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qolAutoRepairLabel:SetPoint("TOPLEFT", qolAutoAcceptInfo, "BOTTOMLEFT", -20, -14)
    qolAutoRepairLabel:SetText(RA_L["qol_autorepair_label"])

    local autoRepairDD = MakeDropdown(misc, qolAutoRepairLabel, 0, -4, 160)
    autoRepairDD:SetList({
        ["none"]   = RA_L["qol_autorepair_none"],
        ["player"] = RA_L["qol_autorepair_player"],
        ["guild"]  = RA_L["qol_autorepair_guild"],
    }, { "none", "player", "guild" })
    autoRepairDD:SetValue(RollAwayDB.autoRepairMode or "none")
    autoRepairDD:SetCallback("OnValueChanged", function(_, _, value)
        RollAwayDB.autoRepairMode = value
    end)
    if ElvUI then autoRepairDD:SetDisabled(true) end

    MakeInfoText(misc, autoRepairDD.frame, 20, -6, 400, RA_L["qol_autorepair_info"])

    -- ── Category: Quests ───────────────────────────────────────────────
    -- Every change re-registers only the events the settings still need.

    local qolQuestAcceptLabel = quests:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qolQuestAcceptLabel:SetPoint("TOPLEFT", quests, "TOPLEFT", 0, -8)
    qolQuestAcceptLabel:SetText(RA_L["qol_quests_accept_label"])

    local questAnchor = qolQuestAcceptLabel
    for _, def in ipairs({
        { dbKey = "questAcceptRegular", labelKey = "qol_quests_regular_label" },
        { dbKey = "questAcceptDaily",   labelKey = "qol_quests_daily_label"   },
        { dbKey = "questAcceptWeekly",  labelKey = "qol_quests_weekly_label"  },
    }) do
        local dbKey = def.dbKey
        local cb = MakeCB(quests, RA_L[def.labelKey], RollAwayDB[dbKey], function(checked)
            RollAwayDB[dbKey] = checked
            RA.ApplyQuestAutomation()
        end)
        cb.frame:SetPoint("TOPLEFT", questAnchor, "BOTTOMLEFT", 0, -6)
        questAnchor = cb.frame
    end

    local _, qolQuestTurnInInfo = MakeToggle(quests, questAnchor, 0, -16, {
        label = RA_L["qol_quests_turnin_label"], info = RA_L["qol_quests_turnin_info"],
        dbKey = "questAutoTurnIn", onChange = RA.ApplyQuestAutomation,
        width = 400, -- long label: explicit width, or it gets cut off
    })

    local _, qolQuestModInfo = MakeToggle(quests, qolQuestTurnInInfo, -20, -14, {
        label = RA_L["qol_quests_modifier_label"], info = RA_L["qol_quests_modifier_info"],
        dbKey = "questRequireModifier",
        width = 400,
    })

    local qolQuestKeyLabel = quests:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qolQuestKeyLabel:SetPoint("TOPLEFT", qolQuestModInfo, "BOTTOMLEFT", 0, -14)
    qolQuestKeyLabel:SetText(RA_L["qol_quests_modkey_label"])

    local questKeyDD = MakeDropdown(quests, qolQuestKeyLabel, 0, -4, 120)
    questKeyDD:SetList({
        ["SHIFT"] = SHIFT_KEY_TEXT or "Shift",
        ["ALT"]   = ALT_KEY_TEXT   or "Alt",
        ["CTRL"]  = CTRL_KEY_TEXT  or "Ctrl",
    }, { "SHIFT", "ALT", "CTRL" })
    questKeyDD:SetValue(RollAwayDB.questModifierKey or "SHIFT")
    questKeyDD:SetCallback("OnValueChanged", function(_, _, value)
        RollAwayDB.questModifierKey = value
    end)

    -- ── Category: Reminder (alphabetical by label) ──────────────────────

    -- Great Vault notification (hidden below max level, the next toggle then
    -- moves up into its place)
    local qolVaultAlertCB, qolVaultAlertInfo = MakeToggle(reminder, nil, 0, -8, {
        label = RA_L["greatvault_alert_label"], info = RA_L["greatvault_alert_info"], dbKey = "greatVaultAlert",
    })
    local paragonAnchor, paragonX, paragonY = qolVaultAlertInfo, -20, -12
    if not isMaxLevel then
        qolVaultAlertCB.frame:Hide()
        qolVaultAlertInfo:Hide()
        paragonAnchor, paragonX, paragonY = nil, 0, -8
    end

    -- Paragon bag notification
    local _, qolParagonInfo = MakeToggle(reminder, paragonAnchor, paragonX, paragonY, {
        label = RA_L["paragon_alert_label"], info = RA_L["paragon_alert_info"], dbKey = "paragonAlert",
    })

    -- Reminder font size
    local fontSlider = MakeValueSlider(reminder, qolParagonInfo, -20, -12, {
        min = 10, max = 40, step = 1, value = RollAwayDB.talentFontSize,
        formatLabel = function(v) return string.format("%s  %d", RA_L["qol_fontsize_label"], v) end,
        onChange = function(v) RollAwayDB.talentFontSize = v end,
    })

    -- Durability warning
    local _, qolDuraInfo = MakeToggle(reminder, fontSlider.frame, 0, -14, {
        label = RA_L["qol_durability_label"], info = RA_L["qol_durability_info"], dbKey = "durabilityWarning",
    })

    -- Instance join reminder
    local _, qolJoinInfo = MakeToggle(reminder, qolDuraInfo, -20, -12, {
        label = RA_L["qol_join_reminder_label"], info = RA_L["qol_join_reminder_info"], dbKey = "instanceJoinReminder",
    })

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

    local qolKeyAddonInfo = MakeInfoText(reminder, cbBigWigs.frame, 20, -6, 400, RA_L["qol_join_keyaddon_info"])

    -- Re-syncs checkbox state from saved DB + live addon detection. Does NOT
    -- clear the saved choice when the addon isn't detected right now - BigWigs'
    -- Keystones sub-module (SlashCmdList["key"]) often isn't registered yet at
    -- options-open time (e.g. right after login), which used to wipe the saved
    -- setting back to "none" on every panel open even though the addon was
    -- actually installed. The checkbox just greys out until it's detected;
    -- the saved value (and GetActiveKeyAddon's own live check) stays intact.
    -- The teleport reminder is always available (no external addon needed).
    local function RefreshKeyAddonCheckboxes()
        cbBigWigs:SetValue(RollAwayDB.joinReminderKeyAddon == "bigwigs")
        cbDetails:SetValue(RollAwayDB.joinReminderKeyAddon == "details")
        cbTeleport:SetValue(RollAwayDB.joinReminderKeyAddon == "teleport")

        cbBigWigs:SetDisabled(not RA.IsBigWigsKeyAvailable())
        cbDetails:SetDisabled(not RA.IsDetailsKeyAvailable())
    end

    -- Each checkbox sets its own choice, or "none" when unchecked.
    for choice, cb in pairs({ bigwigs = cbBigWigs, details = cbDetails, teleport = cbTeleport }) do
        cb:SetCallback("OnValueChanged", function(_, _, value)
            RollAwayDB.joinReminderKeyAddon = value and choice or "none"
            RefreshKeyAddonCheckboxes()
        end)
    end

    RefreshKeyAddonCheckboxes()

    -- Re-check on every panel open, since addon load order isn't guaranteed.
    qolPanel:HookScript("OnShow", RefreshKeyAddonCheckboxes)

    -- Ready Check talent reminder (last alphabetically: "Show talent reminder...")
    local qolShowSpecCB  -- forward-declared, referenced in the toggle's callback below
    local _, qolInfo = MakeToggle(reminder, qolKeyAddonInfo, -20, -20, {
        label = RA_L["qol_readycheck_label"], info = RA_L["qol_readycheck_info"], dbKey = "readyCheckReminder",
        onChange = function(checked)
            if qolShowSpecCB then qolShowSpecCB:SetDisabled(not checked) end
        end,
    })

    qolShowSpecCB = MakeCB(reminder, RA_L["qol_readycheck_showspec_label"], RollAwayDB.readyCheckShowSpec, function(checked)
        RollAwayDB.readyCheckShowSpec = checked
    end)
    qolShowSpecCB.frame:SetPoint("TOPLEFT", qolInfo, "BOTTOMLEFT", 20, -10)
    qolShowSpecCB:SetDisabled(not RollAwayDB.readyCheckReminder)

    -- Lock reminder position: applies to the Check Talents / Durability /
    -- Join reminder toasts.
    local qolLockCB = MakeCB(reminder, RA_L["qol_lock_position_label"], RollAwayDB.qolReminderLockPosition, function(checked)
        RollAwayDB.qolReminderLockPosition = checked
    end)
    qolLockCB.frame:SetPoint("TOPLEFT", qolShowSpecCB.frame, "BOTTOMLEFT", -20, -14)

    local qolResetPosBtn = MakeSkinnedButton(reminder, RA_L["qol_reset_position_button"], 160, S)
    qolResetPosBtn:SetPoint("TOPLEFT", qolLockCB.frame, "BOTTOMLEFT", 4, -8)
    qolResetPosBtn:SetScript("OnClick", RA.ResetToastPositions)

    -- ── Toggle chains (Character / Filter / Hide) ─────────────────────────
    -- A category stacks its toggles top to bottom: each new one hangs below
    -- the last *visible* one, so an option that is hidden (e.g. below max
    -- level) leaves no gap. chain.Add(opts, visible) returns the checkbox;
    -- chain.Anchor() is the last visible description, for a widget below.
    local function NewToggleChain(panel)
        local anchor, x, y = nil, 0, -8
        local chain = {}
        function chain.Add(opts, visible)
            local cb, info = MakeToggle(panel, anchor, x, y, opts)
            if visible == false then
                cb.frame:Hide()
                info:Hide()
            else
                anchor, x, y = info, -20, -12
            end
            return cb
        end
        function chain.Anchor() return anchor end
        return chain
    end

    -- ── Category: Character (max level only) ────────────────────────────
    if character then
        local charChain = NewToggleChain(character)

        -- Omniumfoliant: hide minimap icon, show button on Character Frame.
        -- Long label - explicit width so it wraps instead of running off-panel.
        local qolOmniCB = charChain.Add({
            label = RA_L["qol_omniumfoliant_label"], info = RA_L["qol_omniumfoliant_info"],
            dbKey = "hideOmniumfoliantMinimap", width = 400,
            onChange = function() RA.RefreshCharFrameButtons("option toggled") end,
        })
        qolOmniCB.frame:SetHeight(40) -- room for the wrapped 2-line label

        -- Great Vault button on Character Frame
        charChain.Add({
            label = RA_L["qol_vault_button_label"], info = RA_L["qol_vault_button_info"],
            dbKey = "vaultButtonCharFrame",
            onChange = function() RA.RefreshCharFrameButtons("option toggled") end,
        })

        -- Vault currency display
        charChain.Add({
            label = RA_L["qol_vault_currency_label"], info = RA_L["qol_vault_currency_info"],
            dbKey = "vaultCurrencyDisplay",
        }, RA.BONUS_ROLLS_ENABLED and true or false)
    end

    -- ── Category: Filter (narrows what lists show) ───────────────────────
    local filterChain = NewToggleChain(filter)

    filterChain.Add({
        label = RA_L["qol_expansion_filter_label"], info = RA_L["qol_expansion_filter_info"], dbKey = "expansionFilterAH",
    })

    -- Vendor Filter Light: dim already-known/maxed vendor items (applies the
    -- dim, or resets it when turned off)
    filterChain.Add({
        label = RA_L["qol_vendor_filter_label"], info = RA_L["qol_vendor_filter_info"],
        dbKey = "vendorFilterEnabled", onChange = RA.ApplyVendorFilterFeature,
    })

    -- Alpha slider (only meaningful together with the toggle above)
    MakeValueSlider(filter, filterChain.Anchor(), -20, -12, {
        min = 10, max = 100, step = 5, value = math.floor(RollAwayDB.vendorFilterAlpha * 100 + 0.5),
        formatLabel = function(v) return string.format("%s  %d%%", RA_L["qol_vendor_filter_alpha_label"], v) end,
        onChange = function(v)
            RollAwayDB.vendorFilterAlpha = v / 100
            if RollAwayDB.vendorFilterEnabled then RA.ApplyVendorFilterFeature() end
        end,
    })

    -- ── Category: Hide (switches off Blizzard UI elements) ───────────────
    local hideChain = NewToggleChain(hide)

    -- Red error text in the middle of the screen
    hideChain.Add({
        label = RA_L["qol_hide_errors_label"], info = RA_L["qol_hide_errors_info"],
        dbKey = "hideErrorMessages", onChange = RA.ApplyHideErrorsFeature,
    })

    -- Talking Head (voiced dialog box at the top of the screen)
    hideChain.Add({
        label = RA_L["qol_hide_talkinghead_label"], info = RA_L["qol_hide_talkinghead_info"],
        dbKey = "hideTalkingHead", onChange = RA.ApplyHideTalkingHeadFeature,
    })

    -- Boss banner after a boss kill
    hideChain.Add({
        label = RA_L["qol_hide_bossbanner_label"], info = RA_L["qol_hide_bossbanner_info"],
        dbKey = "hideBossBanner", onChange = RA.ApplyHideBossBannerFeature,
    })

    -- Event toasts at the top of the screen
    hideChain.Add({
        label = RA_L["qol_hide_eventtoasts_label"], info = RA_L["qol_hide_eventtoasts_info"],
        dbKey = "hideEventToasts", onChange = RA.ApplyHideEventToastsFeature,
    })

    -- World Map: hide tracked-faction activity button (experimental)
    hideChain.Add({
        label = RA_L["qol_map_activity_label"], info = RA_L["qol_map_activity_info"],
        dbKey = "hideMapActivityTracker", onChange = RA.ApplyMapActivityTrackerFeature,
    })

    -- Professions: hide "Crafting Output Log" popup
    hideChain.Add({
        label = RA_L["qol_crafting_output_log_label"], info = RA_L["qol_crafting_output_log_info"],
        dbKey = "hideCraftingOutputLog", onChange = RA.ApplyCraftingOutputLogFeature,
    })

    -- ── Category: Logs ─────────────────────────────────────────────────

    -- Master toggle
    local logSubCBs = {}
    local function UpdateLogSubCBsState()
        for _, cb in ipairs(logSubCBs) do
            cb:SetDisabled(not RollAwayDB.autoLogEnabled)
        end
    end

    local _, qolLogMasterInfo = MakeToggle(logs, nil, 0, -8, {
        label = RA_L["qol_log_enable_label"], info = RA_L["qol_log_enable_info"], dbKey = "autoLogEnabled",
        infoWidth = 380, width = 400, onChange = UpdateLogSubCBsState,
    })

    -- Compact zone checkbox list (no per-item info text, mirrors MRT's layout)
    local LOG_ZONE_DEFS = {
        { dbKey = "autoLogScenario",      labelKey = "qol_log_scenario_label"     },
        { dbKey = "autoLogMythicDungeon", labelKey = "qol_log_dungeon_label"      },
        { dbKey = "autoLogRaidMythic",    labelKey = "qol_log_raid_mythic_label"  },
        { dbKey = "autoLogRaidHeroic",    labelKey = "qol_log_raid_heroic_label"  },
        { dbKey = "autoLogRaidNormal",    labelKey = "qol_log_raid_normal_label"  },
        { dbKey = "autoLogRaidLFR",       labelKey = "qol_log_raid_lfr_label"     },
    }

    local logZoneAnchor = qolLogMasterInfo
    local logZoneOffsetX = -20  -- first item hangs off the (indented) info text, back to x=0
    for _, def in ipairs(LOG_ZONE_DEFS) do
        local dbKey = def.dbKey
        local cb = MakeCB(logs, RA_L[def.labelKey], RollAwayDB[dbKey], function(checked)
            RollAwayDB[dbKey] = checked
        end)
        -- Every item after the first chains checkbox->checkbox directly,
        -- already at x=0, so no further horizontal offset.
        cb.frame:SetPoint("TOPLEFT", logZoneAnchor, "BOTTOMLEFT", logZoneOffsetX, -10)
        logZoneOffsetX = 0
        logZoneAnchor = cb.frame
        table.insert(logSubCBs, cb)
    end

    -- Chat notification toggle (own line, separated from the zone list)
    local qolLogChatCB = MakeCB(logs, RA_L["qol_log_chatnotify_label"], RollAwayDB.autoLogChatNotify, function(checked)
        RollAwayDB.autoLogChatNotify = checked
    end, 400) -- explicit width: long label, or it gets cut off
    qolLogChatCB.frame:SetPoint("TOPLEFT", logZoneAnchor, "BOTTOMLEFT", 0, -16)
    table.insert(logSubCBs, qolLogChatCB)

    -- Advanced Combat Logging reminder popup toggle - independent of the
    -- master toggle above, so it still works for players who log manually.
    local qolLogAdvReminderCB = MakeCB(logs, RA_L["qol_log_advlog_reminder_label"], RollAwayDB.advLogReminderEnabled, function(checked)
        RollAwayDB.advLogReminderEnabled = checked
    end, 400)
    qolLogAdvReminderCB.frame:SetPoint("TOPLEFT", qolLogChatCB.frame, "BOTTOMLEFT", 0, -10)

    UpdateLogSubCBsState()

    -- ── Category: LFG (alphabetical by label) ─────────────────────────────

    -- Auto-apply playstyle checkbox
    local UpdatePSState  -- forward-declared: needs the dropdown created below
    local _, lfgqcAutoPSInfo = MakeToggle(lfg, nil, 0, -8, {
        label = RA_L["qol_lfgqc_autops_label"], info = RA_L["qol_lfgqc_autops_info"], dbKey = "lfgAutoPlaystyle",
        onChange = function(checked) UpdatePSState(checked) end,
    })

    -- Default playstyle label (indented, sub-option of autops checkbox)
    local lfgqcPSLabel = lfg:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lfgqcPSLabel:SetPoint("TOPLEFT", lfgqcAutoPSInfo, "BOTTOMLEFT", 0, -12)
    lfgqcPSLabel:SetText(RA_L["qol_lfgqc_playstyle_label"])

    -- Default playstyle dropdown (AceGUI, native ElvUI skin)
    local psDD = MakeDropdown(lfg, lfgqcPSLabel, 0, -4, 160)
    psDD:SetList({
        [0] = RA_L["qol_lfgqc_ps_none"],
        [1] = RA_L["qol_lfgqc_ps_standard"],
        [2] = RA_L["qol_lfgqc_ps_relaxed"],
        [3] = RA_L["qol_lfgqc_ps_competitive"],
        [4] = RA_L["qol_lfgqc_ps_carry"],
    }, { 0, 1, 2, 3, 4 })
    psDD:SetValue(RollAwayDB.lfgDefaultPlaystyle or 0)
    psDD:SetCallback("OnValueChanged", function(_, _, value)
        RollAwayDB.lfgDefaultPlaystyle = value
    end)

    -- Enable/disable label and dropdown based on checkbox state
    UpdatePSState = function(enabled)
        if enabled then
            lfgqcPSLabel:SetTextColor(1, 1, 1, 1)
        else
            lfgqcPSLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        end
        psDD:SetDisabled(not enabled)
    end
    UpdatePSState(RollAwayDB.lfgAutoPlaystyle)

    -- Preselect the Mythic+ difficulty in the Group Finder's create form
    local _, lfgqcMPlusInfo = MakeToggle(lfg, psDD.frame, -20, -14, {
        label = RA_L["qol_lfgqc_automplus_label"], info = RA_L["qol_lfgqc_automplus_info"], dbKey = "lfgAutoMythicPlus",
    })

    -- Enable checkbox (last alphabetically: "Show dungeon quick-create...")
    MakeToggle(lfg, lfgqcMPlusInfo, -20, -12, {
        label = RA_L["qol_lfgqc_label"], info = RA_L["qol_lfgqc_info"], dbKey = "lfgQuickCreate",
    })

    -- Default category on open (the first one in the nav)
    ShowQolCategory(qolNavDefs[1].key)

    return qolPanel
end

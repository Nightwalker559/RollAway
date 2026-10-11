-- RollAway - Options/OptionsQoL.lua
-- The "QoL" page of the options window, built once from RA.InitOptions(). Left nav (sorted by the
-- shown label): Character / Crafting & Vendors / Group / Hide / Logs / Quests / Reminder.
-- Keep RA.FEATURES (Modules/FeatureList.lua) in step when an option moves or is added.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

local UI      = RA.OptionsUI
local MakeCB  = UI.MakeCB
local MakeInfoText = UI.MakeInfoText
local MakeToggle = UI.MakeToggle
local MakeDropdown = UI.MakeDropdown
local MakeValueSlider = UI.MakeValueSlider
local MakeSkinnedButton = UI.MakeSkinnedButton
local QOL_CONTENT_W = UI.QOL_CONTENT_W
local QOL_INFO_W    = UI.QOL_INFO_W

-- Toggles stack top to bottom, each below the last visible one (no gap for a hidden
-- option). chain.Add(opts, visible) returns the checkbox and its description; AddSub adds
-- an indented sub-checkbox (disabled while the parent option is off); AddCB a plain
-- checkbox; Dropdown a labelled dropdown under the toggle just added; Set(frame, indent)
-- continues the chain below any other element (`indent`: how far in it sits).
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
        return cb, info
    end

    function chain.AddSub(opts, parentKey)
        local sub = MakeCB(panel, opts.label, RollAwayDB[opts.dbKey], function(checked)
            RollAwayDB[opts.dbKey] = checked
            if opts.onChange then opts.onChange(checked) end
        end, nil, QOL_INFO_W)
        sub.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 20, -10)
        sub:SetDisabled(not RollAwayDB[parentKey])
        anchor, x, y = sub.frame, -40, -12  -- back to the main toggles' left edge (sub = +40)
        return sub
    end

    function chain.AddCB(label, dbKey, onChange)
        local cb = MakeCB(panel, label, RollAwayDB[dbKey], function(checked)
            RollAwayDB[dbKey] = checked
            if onChange then onChange(checked) end
        end, nil, QOL_CONTENT_W)
        if anchor then
            cb.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
        else
            cb.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        end
        anchor, x, y = cb.frame, 0, -10
        return cb
    end

    -- Label + dropdown belonging to the toggle just added (indented like its description).
    -- Returns the label, the dropdown and a function(enabled) that greys both.
    function chain.Dropdown(labelText, width, list, order, dbKey, default)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
        label:SetText(labelText)
        local dd = MakeDropdown(panel, label, 0, -4, width)
        dd:SetList(list, order)
        dd:SetValue(RollAwayDB[dbKey] or default)
        dd:SetCallback("OnValueChanged", function(_, _, value) RollAwayDB[dbKey] = value end)
        anchor, x, y = dd.frame, -20, -14
        return label, dd, function(enabled)
            local shade = enabled and 1 or 0.5
            label:SetTextColor(shade, shade, shade, 1)
            dd:SetDisabled(not enabled)
        end
    end

    function chain.Set(frame, indent, gap)
        anchor, x, y = frame, -(indent or 0), gap or -14
    end

    function chain.Anchor() return anchor end
    return chain
end

-- parent: the options window's content frame; registerPage(key, label, page): adds the
-- page to the window's list; classColor: for the ElvUI tab highlight (nil without ElvUI).
function RA.BuildQoLOptions(parent, registerPage, classColor)
    local qolPanel = CreateFrame("Frame", nil, parent)
    qolPanel:SetPoint("TOPLEFT",     parent, "TOPLEFT",      16, 0)
    qolPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 0)
    registerPage("qol", RA_L["qol_section_title"], qolPanel)

    -- Fixed header
    local qolTitle = qolPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    qolTitle:SetPoint("TOPLEFT", qolPanel, "TOPLEFT", 0, -10)
    qolTitle:SetText(RA_L["qol_panel_title"])

    local qolPanelInfo = MakeInfoText(qolPanel, qolTitle, 0, -6, 510, RA_L["qol_panel_info"])

    local qolHeaderLine = qolPanel:CreateTexture(nil, "ARTWORK")
    qolHeaderLine:SetHeight(1); qolHeaderLine:SetWidth(560)
    qolHeaderLine:SetPoint("TOPLEFT", qolPanelInfo, "BOTTOMLEFT", 0, -10)
    qolHeaderLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    RA.AddHeaderLogo(qolPanel, qolHeaderLine)

    -- Left nav sorted by the shown label (follows the client language); no Character
    -- tab below max level.
    local QOL_NAV_W = 130
    local isMaxLevel = RA.IsMaxLevel()

    local qolNavDefs = {
        { key = "character", label = RA_L["qol_nav_character"], show = isMaxLevel },
        { key = "craft",     label = RA_L["qol_nav_craft"]        },
        { key = "group",     label = RA_L["qol_nav_group"]        },
        { key = "hide",      label = RA_L["qol_nav_hide"]         },
        { key = "logs",      label = RA_L["qol_nav_logs"]         },
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
        RA.Skin.OptionTab(btn, qolCatPanels, key, classColor)
        qolNavButtons[key] = btn
    end

    -- A ScrollFrame per category (UI.MakeCategoryPage).
    local function CreateQolCategoryPanel(key, name)
        return UI.MakeCategoryPage(qolPanel, qolHeaderLine, QOL_NAV_W, "RollAwayQol", name, qolCatPanels, key)
    end

    local character = isMaxLevel and CreateQolCategoryPanel("character", "Character") or nil
    local craft     = CreateQolCategoryPanel("craft",    "Craft")
    local group     = CreateQolCategoryPanel("group",    "Group")
    local hide      = CreateQolCategoryPanel("hide",     "Hide")
    local logs      = CreateQolCategoryPanel("logs",     "Logs")
    local quests    = CreateQolCategoryPanel("quests",   "Quests")
    local reminder  = CreateQolCategoryPanel("reminder", "Reminder")

    -- ── Category: Character (max level) ─────────────────────────────────
    if character then
        local charChain = NewToggleChain(character)

        -- Great Vault button on the Character panel
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

    -- ── Category: Crafting & Vendors ─────────────────────────────────────
    local craftChain = NewToggleChain(craft)

    -- Salvage slot (CraftingSalvage.lua)
    craftChain.Add({
        label = RA_L["qol_salvage_slot_label"], info = RA_L["qol_salvage_slot_info"],
        dbKey = "autoSalvageSlot", onChange = RA.ApplyCraftingSalvageFeature,
    })

    -- Crafting output log
    craftChain.Add({
        label = RA_L["qol_crafting_output_log_label"], info = RA_L["qol_crafting_output_log_info"],
        dbKey = "hideCraftingOutputLog", onChange = RA.ApplyCraftingOutputLogFeature,
    })

    craftChain.Add({
        label = RA_L["qol_expansion_filter_label"], info = RA_L["qol_expansion_filter_info"], dbKey = "expansionFilterAH",
    })

    -- Auto repair (dropdown: none / player / guild): the label is the option's title, the
    -- description follows the dropdown.
    local autoRepairLabel = craft:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoRepairLabel:SetPoint("TOPLEFT", craftChain.Anchor(), "BOTTOMLEFT", -20, -14)
    autoRepairLabel:SetText(RA_L["qol_autorepair_label"])

    local autoRepairDD = MakeDropdown(craft, autoRepairLabel, 0, -4, 160)
    autoRepairDD:SetList({
        ["none"]   = RA_L["qol_autorepair_none"],
        ["player"] = RA_L["qol_autorepair_player"],
        ["guild"]  = RA_L["qol_autorepair_guild"],
    }, { "none", "player", "guild" })
    autoRepairDD:SetValue(RollAwayDB.autoRepairMode or "none")
    autoRepairDD:SetCallback("OnValueChanged", function(_, _, value)
        RollAwayDB.autoRepairMode = value
    end)
    craftChain.Set(MakeInfoText(craft, autoRepairDD.frame, 20, -6, QOL_INFO_W, RA_L["qol_autorepair_info"]), 20, -14)

    -- Vendor filter: dims known items (reset when turned off)
    craftChain.Add({
        label = RA_L["qol_vendor_filter_label"], info = RA_L["qol_vendor_filter_info"],
        dbKey = "vendorFilterEnabled", onChange = RA.ApplyVendorFilterFeature,
    })

    -- Alpha slider (only with the toggle above)
    MakeValueSlider(craft, craftChain.Anchor(), -20, -12, {
        min = 10, max = 100, step = 5, value = math.floor(RollAwayDB.vendorFilterAlpha * 100 + 0.5),
        formatLabel = function(v) return string.format("%s  %d%%", RA_L["qol_vendor_filter_alpha_label"], v) end,
        onChange = function(v)
            RollAwayDB.vendorFilterAlpha = v / 100
            if RollAwayDB.vendorFilterEnabled then RA.ApplyVendorFilterFeature() end
        end,
    })

    -- ── Category: Group ──────────────────────────────────────────────────
    local groupChain = NewToggleChain(group)

    groupChain.Add({
        label = RA_L["qol_autoaccept_label"], info = RA_L["qol_autoaccept_info"], dbKey = "autoAcceptInvite",
    })

    -- Tank marker offer (TankMarker.lua); the icon choice matters only while it is on.
    local SetTankIconEnabled  -- needs the dropdown created below
    groupChain.Add({
        label = RA_L["qol_tankmark_label"], info = RA_L["qol_tankmark_info"],
        dbKey = "tankMarkEnabled",
        onChange = function(checked)
            RA.ApplyTankMarker()
            SetTankIconEnabled(checked)
        end,
    })

    local tankIconList, tankIconOrder = {}, {}
    for i = 1, 8 do
        tankIconList[i]  = RA.RaidIconText(i) .. " " .. _G["RAID_TARGET_" .. i]
        tankIconOrder[i] = i
    end
    local _
    _, _, SetTankIconEnabled = groupChain.Dropdown(RA_L["qol_tankmark_icon_label"], 160,
        tankIconList, tankIconOrder, "tankMarkIcon", 6)
    SetTankIconEnabled(RollAwayDB.tankMarkEnabled)

    -- Dungeon quick selection in the group finder
    groupChain.Add({
        label = RA_L["qol_lfgqc_label"], info = RA_L["qol_lfgqc_info"], dbKey = "lfgQuickCreate",
    })

    -- Mythic+ difficulty preselected in the create form
    groupChain.Add({
        label = RA_L["qol_lfgqc_automplus_label"], info = RA_L["qol_lfgqc_automplus_info"], dbKey = "lfgAutoMythicPlus",
    })

    -- Auto playstyle; the dropdown follows the checkbox
    local SetPlaystyleEnabled  -- needs the dropdown created below
    groupChain.Add({
        label = RA_L["qol_lfgqc_autops_label"], info = RA_L["qol_lfgqc_autops_info"], dbKey = "lfgAutoPlaystyle",
        onChange = function(checked) SetPlaystyleEnabled(checked) end,
    })
    _, _, SetPlaystyleEnabled = groupChain.Dropdown(RA_L["qol_lfgqc_playstyle_label"], 230, {  -- "Beförderung angeboten" needs room
        [0] = RA_L["qol_lfgqc_ps_none"],
        [1] = RA_L["qol_lfgqc_ps_standard"],
        [2] = RA_L["qol_lfgqc_ps_relaxed"],
        [3] = RA_L["qol_lfgqc_ps_competitive"],
        [4] = RA_L["qol_lfgqc_ps_carry"],
    }, { 0, 1, 2, 3, 4 }, "lfgDefaultPlaystyle", 0)
    SetPlaystyleEnabled(RollAwayDB.lfgAutoPlaystyle)

    -- ── Category: Hide (Blizzard UI elements) ───────────────────────────
    local hideChain = NewToggleChain(hide)

    -- Red error text
    local infoMsgCB  -- sub-option, switched with the toggle below
    hideChain.Add({
        label = RA_L["qol_hide_errors_label"], info = RA_L["qol_hide_errors_info"],
        dbKey = "hideErrorMessages",
        onChange = function(checked)
            RA.ApplyHideErrorsFeature()
            if infoMsgCB then infoMsgCB:SetDisabled(not checked) end
        end,
    })
    infoMsgCB = hideChain.AddSub({ label = RA_L["qol_hide_infomsg_label"], dbKey = "hideInfoMessages" },
        "hideErrorMessages")

    -- Talking Head
    hideChain.Add({
        label = RA_L["qol_hide_talkinghead_label"], info = RA_L["qol_hide_talkinghead_info"],
        dbKey = "hideTalkingHead", onChange = RA.ApplyHideTalkingHeadFeature,
    })

    -- Boss banner
    hideChain.Add({
        label = RA_L["qol_hide_bossbanner_label"], info = RA_L["qol_hide_bossbanner_info"],
        dbKey = "hideBossBanner", onChange = RA.ApplyHideBossBannerFeature,
    })

    -- Event toasts
    hideChain.Add({
        label = RA_L["qol_hide_eventtoasts_label"], info = RA_L["qol_hide_eventtoasts_info"],
        dbKey = "hideEventToasts", onChange = RA.ApplyHideEventToastsFeature,
    })

    -- Alert pop-ups
    hideChain.Add({
        label = RA_L["qol_hide_alerts_label"], info = RA_L["qol_hide_alerts_info"],
        dbKey = "hideAlerts", onChange = RA.ApplyHideAlertsFeature,
    })

    -- World Map: faction button, bounty board, eye
    hideChain.Add({
        label = RA_L["qol_map_activity_label"], info = RA_L["qol_map_activity_info"],
        dbKey = "hideMapActivityTracker", onChange = RA.ApplyMapActivityTrackerFeature,
    })

    -- RollAway's own minimap button
    hideChain.Add({
        label = RA_L["qol_hide_minimapbtn_label"], info = RA_L["qol_hide_minimapbtn_info"],
        dbKey = "minimapButtonHide", onChange = RA.ApplyMinimapButton,
    })

    -- Omniumfoliant: minimap icon hidden, button on the Character panel (max level)
    hideChain.Add({
        label = RA_L["qol_omniumfoliant_label"], info = RA_L["qol_omniumfoliant_info"],
        dbKey = "hideOmniumfoliantMinimap",
        onChange = function() RA.RefreshCharFrameButtons("option toggled") end,
    }, isMaxLevel)

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
        onChange = UpdateLogSubCBsState,
    })
    -- Compact zone checkbox list (MRT layout, no info texts)
    local LOG_ZONE_DEFS = {
        { dbKey = "autoLogScenario",      labelKey = "qol_log_scenario_label"     },
        { dbKey = "autoLogMythicDungeon", labelKey = "qol_log_dungeon_label"      },
        { dbKey = "autoLogRaidMythic",    labelKey = "qol_log_raid_mythic_label"  },
        { dbKey = "autoLogRaidHeroic",    labelKey = "qol_log_raid_heroic_label"  },
        { dbKey = "autoLogRaidNormal",    labelKey = "qol_log_raid_normal_label"  },
        { dbKey = "autoLogRaidLFR",       labelKey = "qol_log_raid_lfr_label"     },
        { dbKey = "autoLogRaidCurrentOnly", labelKey = "qol_log_raid_current_label"  },
    }

    local logZoneAnchor = qolLogMasterInfo
    local logZoneOffsetX = -20  -- first item hangs off the (indented) info text, back to x=0
    for _, def in ipairs(LOG_ZONE_DEFS) do
        local dbKey = def.dbKey
        local cb = MakeCB(logs, RA_L[def.labelKey], RollAwayDB[dbKey], function(checked)
            RollAwayDB[dbKey] = checked
        end)
        -- Each later item chains checkbox to checkbox (already at x=0).
        cb.frame:SetPoint("TOPLEFT", logZoneAnchor, "BOTTOMLEFT", logZoneOffsetX, -10)
        logZoneOffsetX = 0
        logZoneAnchor = cb.frame
        table.insert(logSubCBs, cb)
    end

    -- Chat notification (own line)
    local qolLogChatCB = MakeCB(logs, RA_L["qol_log_chatnotify_label"], RollAwayDB.autoLogChatNotify, function(checked)
        RollAwayDB.autoLogChatNotify = checked
    end, nil, QOL_CONTENT_W)
    qolLogChatCB.frame:SetPoint("TOPLEFT", logZoneAnchor, "BOTTOMLEFT", 0, -16)
    table.insert(logSubCBs, qolLogChatCB)

    -- Advanced Combat Logging reminder: independent of the master toggle (manual loggers).
    local qolLogAdvReminderCB = MakeCB(logs, RA_L["qol_log_advlog_reminder_label"], RollAwayDB.advLogReminderEnabled, function(checked)
        RollAwayDB.advLogReminderEnabled = checked
    end, nil, QOL_CONTENT_W)
    qolLogAdvReminderCB.frame:SetPoint("TOPLEFT", qolLogChatCB.frame, "BOTTOMLEFT", 0, -10)
    RA.ToggleControls["advLogReminderEnabled"] = qolLogAdvReminderCB

    UpdateLogSubCBsState()

    -- ── Category: Quests ───────────────────────────────────────────────
    -- Every change registers only the events still needed.

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
    })

    local _, qolQuestModInfo = MakeToggle(quests, qolQuestTurnInInfo, -20, -14, {
        label = RA_L["qol_quests_modifier_label"], info = RA_L["qol_quests_modifier_info"],
        dbKey = "questRequireModifier",
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

    -- ── Category: Reminder ───────────────────────────────────────────────
    -- Toasts first (they share the look settings at the bottom).
    local remChain = NewToggleChain(reminder)

    -- Durability warning
    remChain.Add({
        label = RA_L["qol_durability_label"], info = RA_L["qol_durability_info"], dbKey = "durabilityWarning",
    })

    -- Instance join reminder
    local _, qolJoinInfo = remChain.Add({
        label = RA_L["qol_join_reminder_label"], info = RA_L["qol_join_reminder_info"], dbKey = "instanceJoinReminder",
    })

    -- Sub-option: keystone companion addon (BigWigs / Details! / Teleport reminder, one of them)
    local qolKeyAddonLabel = reminder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qolKeyAddonLabel:SetPoint("TOPLEFT", qolJoinInfo, "BOTTOMLEFT", 0, -10)
    qolKeyAddonLabel:SetWidth(QOL_INFO_W)  -- wraps instead of running off the panel
    qolKeyAddonLabel:SetJustifyH("LEFT")
    qolKeyAddonLabel:SetText(RA_L["qol_join_keyaddon_label"])

    -- One per line (three side by side do not fit).
    local cbBigWigs = MakeCB(reminder, RA_L["qol_join_keyaddon_bigwigs"], nil, nil)
    cbBigWigs.frame:SetPoint("TOPLEFT", qolKeyAddonLabel, "BOTTOMLEFT", 0, -6)

    local cbDetails = MakeCB(reminder, RA_L["qol_join_keyaddon_details"], nil, nil)
    cbDetails.frame:SetPoint("TOPLEFT", cbBigWigs.frame, "BOTTOMLEFT", 0, -4)

    local cbTeleport = MakeCB(reminder, RA_L["qol_join_keyaddon_teleport"], nil, nil)
    cbTeleport.frame:SetPoint("TOPLEFT", cbDetails.frame, "BOTTOMLEFT", 0, -4)

    local qolKeyAddonInfo = MakeInfoText(reminder, cbTeleport.frame, 20, -6, QOL_INFO_W, RA_L["qol_join_keyaddon_info"])
    remChain.Set(qolKeyAddonInfo, 20, -20)

    -- Checkbox state from the saved choice + live addon detection. An addon not detected
    -- yet (BigWigs' "key" command is often not registered right after login) does not
    -- clear the saved choice: the box just greys out. The teleport reminder is always available.
    local function RefreshKeyAddonCheckboxes()
        cbBigWigs:SetValue(RollAwayDB.joinReminderKeyAddon == "bigwigs")
        cbDetails:SetValue(RollAwayDB.joinReminderKeyAddon == "details")
        cbTeleport:SetValue(RollAwayDB.joinReminderKeyAddon == "teleport")

        cbBigWigs:SetDisabled(not RA.IsBigWigsKeyAvailable())
        cbDetails:SetDisabled(not RA.IsDetailsKeyAvailable())
    end

    -- Each checkbox sets its choice, "none" when unchecked.
    for choice, cb in pairs({ bigwigs = cbBigWigs, details = cbDetails, teleport = cbTeleport }) do
        cb:SetCallback("OnValueChanged", function(_, _, value)
            RollAwayDB.joinReminderKeyAddon = value and choice or "none"
            RefreshKeyAddonCheckboxes()
        end)
    end

    RefreshKeyAddonCheckboxes()

    -- Re-check on every open (addon load order).
    qolPanel:HookScript("OnShow", RefreshKeyAddonCheckboxes)

    -- Ready check talent reminder (+ sub-option: show the active spec)
    local qolShowSpecCB  -- referenced in the toggle's callback below
    remChain.Add({
        label = RA_L["qol_readycheck_label"], info = RA_L["qol_readycheck_info"], dbKey = "readyCheckReminder",
        onChange = function(checked)
            if qolShowSpecCB then qolShowSpecCB:SetDisabled(not checked) end
        end,
    })
    qolShowSpecCB = remChain.AddSub({ label = RA_L["qol_readycheck_showspec_label"], dbKey = "readyCheckShowSpec" },
        "readyCheckReminder")

    -- Great Vault notification (hidden below max level; the next toggle moves up)
    remChain.Add({
        label = RA_L["greatvault_alert_label"], info = RA_L["greatvault_alert_info"], dbKey = "greatVaultAlert",
    }, isMaxLevel)

    -- Paragon notification
    remChain.Add({
        label = RA_L["paragon_alert_label"], info = RA_L["paragon_alert_info"], dbKey = "paragonAlert",
    })

    -- Look of the toasts: font size, position
    local fontSlider = MakeValueSlider(reminder, remChain.Anchor(), -20, -12, {
        min = 10, max = 40, step = 1, value = RollAwayDB.talentFontSize,
        formatLabel = function(v) return string.format("%s  %d", RA_L["qol_fontsize_label"], v) end,
        onChange = function(v) RollAwayDB.talentFontSize = v end,
    })
    remChain.Set(fontSlider, 0, -14)

    -- Lock position: Check Talents / Durability / Join reminder toasts.
    local qolLockCB = remChain.AddCB(RA_L["qol_lock_position_label"], "qolReminderLockPosition")

    local qolResetPosBtn = MakeSkinnedButton(reminder, RA_L["qol_reset_position_button"], 160)
    qolResetPosBtn:SetPoint("TOPLEFT", qolLockCB.frame, "BOTTOMLEFT", 4, -8)
    qolResetPosBtn:SetScript("OnClick", RA.ResetToastPositions)

    -- Default category on open (first in the nav)
    ShowQolCategory(qolNavDefs[1].key)

    -- Opens the QoL page `key` (feature overview); a page missing at this level shows the first.
    function RA.OpenQoLCategory(key)
        RA.OpenOptions("qol")
        ShowQolCategory(qolCatPanels[key] and key or qolNavDefs[1].key)
    end

    return qolPanel
end

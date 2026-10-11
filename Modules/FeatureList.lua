-- RollAway - FeatureList.lua
-- Overview window of all features with their description and state (/raw features,
-- /rawfeatures, button in the options). A click opens the feature's settings.
-- Keep RA.FEATURES in step with the options pages (Options.lua, OptionsQoL.lua).

local RA   = _G.RollAway
local RA_L = RA.RA_L

local WIDTH, HEIGHT, CONTENT_W = 400, 640, 340
-- Name / description of a row end here, left of the checkbox or the "On/Off" text.
local TEXT_W = CONTENT_W - 44

local function AnyTrue(t)
    if type(t) ~= "table" then return false end
    for _, v in pairs(t) do
        if v then return true end
    end
    return false
end

-- A saved boolean of the profile.
local function DB(key) return function() return RollAwayDB[key] end end

-- One entry: name / info (locale keys, info optional), on() -> state, open = where a click
-- goes ({ tab = key } main options tab, { qol = key } QoL page), show == false hides it.
-- toggle = key in RA.ToggleControls (the options' checkbox, so the overview runs the very
-- same code as a click there); invert: the checkbox means the opposite of "on".
-- Without toggle the row only shows its state (several settings, a dropdown ...).
-- Built lazily (RollAwayDB/RA flags are not known at load).
local function BuildSections()
    local maxLevel = RA.IsMaxLevel()
    local bonusRolls = RA.BONUS_ROLLS_ENABLED and maxLevel
    local char = RollAwayDBChar

    -- `on`: saved key (then a toggle) or a function.
    local function Qol(page, name, info, on, show)
        local entry = { name = name, info = info, on = on, open = { qol = page }, show = show }
        if type(on) == "string" then
            entry.toggle, entry.on = on, DB(on)
        end
        return entry
    end

    local sections = {
        { title = "feat_section_loot", items = {
            { name = "visibility_section_title", info = "visibility_info",
              on = function() return not RollAwayDB.lootFrameAutoCloseDisabled end, open = { tab = "general" },
              toggle = "lootFrameAutoCloseDisabled", invert = true },
            { name = "confirm_roll_title", info = "confirm_roll_hint",
              on = function() return AnyTrue(RollAwayDB.confirmRoll) end, open = { tab = "raids" } },
            { name = "legacy_section_title", info = "feat_legacy",
              on = DB("legacy"), open = { tab = "general" }, toggle = "legacy" },
        } },
        { title = "feat_section_bonusroll", show = bonusRolls, items = {
            { name = "feat_name_dungeons", info = "feat_dungeons", open = { tab = "dungeons" },
              on = function() return char.dungeonAutoPassAll or AnyTrue(char.dungeons) or AnyTrue(char.dungeons_s2) end },
            { name = "feat_name_raids", info = "feat_raids", open = { tab = "raids" },
              on = function() return AnyTrue(char.raidAutoPassDifficulty) or AnyTrue(char.raids) end },
            { name = "feat_name_delves", info = "feat_delves", open = { tab = "delves" },
              on = function() return char.delveAutoPassAll or AnyTrue(char.delves) or AnyTrue(char.delves_s2) end },
            { name = "feat_name_prey", info = "feat_prey", open = { tab = "prey" },
              on = function() return char.prey end, toggle = "char:prey" },
            { name = "feat_name_reminder", info = "reminder_info", open = { tab = "general" },
              on = DB("showReminder"), toggle = "showReminder" },
            { name = "feat_name_warning", info = "autopass_warning_info", open = { tab = "general" },
              on = DB("autoPassWarning"), toggle = "autoPassWarning" },
        } },
        { title = "qol_nav_group", items = {
            Qol("group", "qol_autoaccept_label",   "qol_autoaccept_info",   "autoAcceptInvite"),
            Qol("group", "qol_tankmark_label",     "qol_tankmark_info",     "tankMarkEnabled"),
            Qol("group", "qol_lfgqc_label",        "qol_lfgqc_info",        "lfgQuickCreate"),
            Qol("group", "qol_lfgqc_automplus_label", "qol_lfgqc_automplus_info", "lfgAutoMythicPlus"),
            Qol("group", "qol_lfgqc_autops_label", "qol_lfgqc_autops_info", "lfgAutoPlaystyle"),
        } },
        { title = "qol_nav_craft", items = {
            Qol("craft", "qol_salvage_slot_label", "qol_salvage_slot_info", "autoSalvageSlot"),
            Qol("craft", "qol_crafting_output_log_label", "qol_crafting_output_log_info", "hideCraftingOutputLog"),
            Qol("craft", "qol_expansion_filter_label", "qol_expansion_filter_info", "expansionFilterAH"),
            Qol("craft", "qol_autorepair_label",   "qol_autorepair_info",
                function() return (RollAwayDB.autoRepairMode or "none") ~= "none" end),
            Qol("craft", "qol_vendor_filter_label", "qol_vendor_filter_info", "vendorFilterEnabled"),
        } },
        { title = "qol_nav_quests", items = {
            Qol("quests", "feat_name_quests_accept", "feat_quests_accept", function()
                return RollAwayDB.questAcceptRegular or RollAwayDB.questAcceptDaily or RollAwayDB.questAcceptWeekly
            end),
            Qol("quests", "qol_quests_turnin_label", "qol_quests_turnin_info", "questAutoTurnIn"),
        } },
        { title = "qol_reminder_section", items = {
            Qol("reminder", "qol_durability_label",    "qol_durability_info",    "durabilityWarning"),
            Qol("reminder", "qol_join_reminder_label", "qol_join_reminder_info", "instanceJoinReminder"),
            Qol("reminder", "qol_readycheck_label",    "qol_readycheck_info",    "readyCheckReminder"),
            Qol("reminder", "greatvault_alert_label",  "greatvault_alert_info",  "greatVaultAlert", maxLevel),
            Qol("reminder", "paragon_alert_label",     "paragon_alert_info",     "paragonAlert"),
        } },
        { title = "qol_nav_hide", items = {
            Qol("hide", "qol_hide_errors_label",       "qol_hide_errors_info",       "hideErrorMessages"),
            Qol("hide", "qol_hide_talkinghead_label",  "qol_hide_talkinghead_info",  "hideTalkingHead"),
            Qol("hide", "qol_hide_bossbanner_label",   "qol_hide_bossbanner_info",   "hideBossBanner"),
            Qol("hide", "qol_hide_eventtoasts_label",  "qol_hide_eventtoasts_info",  "hideEventToasts"),
            Qol("hide", "qol_hide_alerts_label",       "qol_hide_alerts_info",       "hideAlerts"),
            Qol("hide", "qol_map_activity_label",      "qol_map_activity_info",      "hideMapActivityTracker"),
            Qol("hide", "qol_hide_minimapbtn_label",   "qol_hide_minimapbtn_info",   "minimapButtonHide"),
            Qol("hide", "qol_omniumfoliant_label",     "qol_omniumfoliant_info",     "hideOmniumfoliantMinimap", maxLevel),
        } },
        { title = "qol_nav_character", show = maxLevel, items = {
            Qol("character", "qol_vault_button_label",   "qol_vault_button_info",   "vaultButtonCharFrame"),
            Qol("character", "qol_vault_currency_label", "qol_vault_currency_info", "vaultCurrencyDisplay",
                RA.BONUS_ROLLS_ENABLED),
        } },
        { title = "qol_nav_logs", items = {
            Qol("logs", "qol_log_enable_label",        "qol_log_enable_info", "autoLogEnabled"),
            Qol("logs", "qol_log_advlog_reminder_label", nil,                 "advLogReminderEnabled"),
        } },
        { title = "feat_section_commands", commands = {
            { "/raw",         "cmd_raw_info"         },
            { "/rawfeatures", "cmd_rawfeatures_info" },
            { "/rat",         "cmd_rat_info"         },
            { "/rawvault",    "cmd_rawvault_info"    },
            { "/rawparagon",  "cmd_rawparagon_info"  },
            { "/rawtank",     "cmd_rawtank_info"     },
        } },
    }
    return sections
end

-- Opens the settings page of an entry (queued during combat).
local function OpenFeature(open)
    if open.tab and RA.OpenOptionsTab then
        RA.OpenOptionsTab(open.tab)
    elseif open.qol and RA.OpenQoLCategory then
        RA.OpenQoLCategory(open.qol)
    end
end

local frame
local refreshers = {}

-- The row's checkbox, if the overview can switch the feature.
local function Control(item)
    return item.toggle and RA.ToggleControls and RA.ToggleControls[item.toggle]
end

local function StateText(on)
    return on and ("|cff33ff33" .. RA_L["feat_on"] .. "|r") or ("|cff888888" .. RA_L["feat_off"] .. "|r")
end

local function CreateFrameOnce()
    local f = RA.CreatePanelWindow("RollAwayFeatureListFrame", UIParent, WIDTH, HEIGHT, RA_L["feat_title"])
    RA.AddTitleIcon(f)
    f:SetFrameStrata("HIGH")
    RA.MakeDraggable(f)
    tinsert(UISpecialFrames, "RollAwayFeatureListFrame")

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -34)
    hint:SetWidth(WIDTH - 36)
    hint:SetJustifyH("LEFT")
    hint:SetText(RA_L["feat_hint"])

    local scroll = RA.OptionsUI.MakeScrollFrame(f, "RollAwayFeatureListScroll")
    scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",      12, -64)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30,  12)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_W + 8, 1)
    scroll:SetScrollChild(content)

    local y = -4
    for _, section in ipairs(BuildSections()) do
        if section.show ~= false then
            local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
            header:SetText(RA_L[section.title])
            local line = content:CreateTexture(nil, "ARTWORK")
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
            line:SetPoint("RIGHT", content, "RIGHT", -4, 0)
            line:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            y = y - 28

            for _, item in ipairs(section.items or {}) do
                if item.show ~= false then
                    local row = CreateFrame("Button", nil, content)
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
                    row:SetWidth(CONTENT_W)

                    local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                    name:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -4)
                    name:SetWidth(TEXT_W)
                    name:SetJustifyH("LEFT")
                    name:SetText(RA_L[item.name])

                    local state, box
                    local control = Control(item)
                    if control then
                        box = RA.OptionsUI.MakeCheckBox(row)
                        box:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -2)
                        box:SetScript("OnClick", function(self)
                            local value = self:GetChecked() and true or false
                            if InCombatLockdown() then
                                self:SetChecked(not value)
                                RA.Print(RA_L["feat_combat"])
                                return
                            end
                            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                            if item.invert then value = not value end
                            control:Toggle(value)
                        end)
                    else
                        state = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                        state:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
                    end

                    local height = 4 + name:GetStringHeight() + 6
                    if item.info then
                        local info = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                        info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
                        info:SetWidth(TEXT_W)
                        info:SetJustifyH("LEFT")
                        info:SetTextColor(0.7, 0.7, 0.7)
                        info:SetText(RA_L[item.info])
                        height = height + info:GetStringHeight() + 3
                    end
                    row:SetHeight(height)

                    local hl = row:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(1, 1, 1, 0.06)
                    row:SetScript("OnClick", function() OpenFeature(item.open) end)

                    refreshers[#refreshers + 1] = function()
                        if box then
                            box:SetChecked(item.on() and true or false)
                        else
                            state:SetText(StateText(item.on()))
                        end
                    end
                    y = y - height - 2
                end
            end

            for _, cmd in ipairs(section.commands or {}) do
                local row = CreateFrame("Frame", nil, content)
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
                row:SetWidth(CONTENT_W)

                local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                name:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -4)
                name:SetText(cmd[1])

                local info = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                info:SetPoint("TOPLEFT", row, "TOPLEFT", 120, -5)
                info:SetWidth(CONTENT_W - 130)
                info:SetJustifyH("LEFT")
                info:SetTextColor(0.7, 0.7, 0.7)
                info:SetText(RA_L[cmd[2]])

                local height = 8 + math.max(name:GetStringHeight(), info:GetStringHeight())
                row:SetHeight(height)
                y = y - height - 2
            end
            y = y - 12
        end
    end
    content:SetHeight(-y + 4)

    f:SetScript("OnShow", function()
        for _, refresh in ipairs(refreshers) do refresh() end
    end)
    return f
end

-- Next to the options window when that is open (right of it, left if the screen has no
-- room), else in the screen center.
local function AnchorFrame()
    local opt = _G.RollAwayOptionsFrame
    frame:ClearAllPoints()
    if opt and opt:IsShown() then
        local right = opt:GetRight()
        if right and right + WIDTH + 4 > UIParent:GetRight() then
            frame:SetPoint("TOPRIGHT", opt, "TOPLEFT", -4, 0)
        else
            frame:SetPoint("TOPLEFT", opt, "TOPRIGHT", 4, 0)
        end
    else
        frame:SetPoint("CENTER")
    end
end

-- Toggles the window.
function RA.ToggleFeatureList()
    if not frame then frame = CreateFrameOnce() end
    local show = not frame:IsShown()
    if show then AnchorFrame() end
    frame:SetShown(show)
end

-- The options window just opened: an open overview moves next to it.
function RA.ReanchorFeatureList()
    if frame and frame:IsShown() then AnchorFrame() end
end

function RA.InitFeatureList()
    SLASH_ROLLAWAYFEATURES1 = "/rawfeatures"
    SlashCmdList["ROLLAWAYFEATURES"] = RA.ToggleFeatureList
end

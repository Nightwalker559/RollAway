-- RollAway - Options/OptionsDev.lua
-- Builds the "Developer" settings subcategory (Logging / Tests / Tools /
-- Commands via left nav) - only for developer characters (RA.DEV_CHARS).
-- Called once from RA.InitOptions() in Options/Options.lua. The buttons run
-- the same dev commands as the slash commands (RA.RunDevCommand, Core/Debug.lua).

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

local UI      = RA.OptionsUI
local MakeCB  = UI.MakeCB
local MakeInfoText = UI.MakeInfoText
local MakeToggle = UI.MakeToggle
local MakeSkinnedButton = UI.MakeSkinnedButton
local QOL_INFO_W    = UI.QOL_INFO_W

local NAV_W = 130

-- Everyone's commands and the developer commands, for the Commands page:
-- { command text, locale key of the description }.
local PUBLIC_COMMANDS = {
    { "/raw  /rollaway", "cmd_raw_info"       },
    { "/rat",            "cmd_rat_info"       },
    { "/rawvault",       "cmd_rawvault_info"  },
    { "/rawparagon",     "cmd_rawparagon_info" },
    { "/rawtank",        "cmd_rawtank_info"   },
}
local DEV_COMMANDS = {
    { "/rawraids",         "cmd_rawraids_info"       },
    { "/rawdungeons",      "cmd_rawdungeons_info"    },
    { "/rawbosses",        "cmd_rawbosses_info"      },
    { "/rawtest",          "cmd_rawtest_info"        },
    { "/rawreminder",      "cmd_rawreminder_info"    },
    { "/rawreset",         "cmd_rawreset_info"       },
    { "/rawqol",           "cmd_rawqol_info"         },
    { "/rawwhats",         "cmd_rawwhats_info"       },
    { "/rawlog",           "cmd_rawlog_info"         },
    { "/rawdump",          "cmd_rawdump_info"        },
    { "/rawcharbtn",       "cmd_rawcharbtn_info"     },
    { "/rawchonkyoffset",  "cmd_rawchonkyoffset_info" },
    { "/rawtank test",     "cmd_rawtanktest_info"    },
}

-- Text block "command  description" per line, commands in white.
local function CommandLines(list)
    local lines = {}
    for i, entry in ipairs(list) do
        lines[i] = "|cffFFFFFF" .. entry[1] .. "|r  " .. RA_L[entry[2]]
    end
    return table.concat(lines, "\n")
end

function RA.BuildDevOptions(category, S, classColor)
    local panel = CreateFrame("Frame")
    Settings.RegisterCanvasLayoutSubcategory(category, panel, RA_L["dev_section_title"])

    -- Fixed header
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -10)
    title:SetText(RA_L["dev_panel_title"])

    local panelInfo = MakeInfoText(panel, title, 0, -6, 560, RA_L["dev_panel_info"])

    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1); headerLine:SetWidth(560)
    headerLine:SetPoint("TOPLEFT", panelInfo, "BOTTOMLEFT", 0, -10)
    headerLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Left nav in working order (not alphabetical).
    local navDefs = {
        { key = "log",      label = RA_L["dev_nav_log"]      },
        { key = "tests",    label = RA_L["dev_nav_tests"]    },
        { key = "tools",    label = RA_L["dev_nav_tools"]    },
        { key = "commands", label = RA_L["dev_nav_commands"] },
    }

    local catPanels  = {}
    local navButtons = {}
    local ShowCategory = UI.MakeTabSelector(catPanels, navButtons)

    local prevNavBtn
    for _, def in ipairs(navDefs) do
        local key = def.key
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(NAV_W, 24)
        btn:SetText(def.label)
        if prevNavBtn then
            btn:SetPoint("TOP", prevNavBtn, "BOTTOM", 0, -4)
        else
            btn:SetPoint("TOPLEFT", headerLine, "BOTTOMLEFT", 0, -14)
        end
        prevNavBtn = btn
        btn:SetScript("OnClick", function() ShowCategory(key) end)
        if S and RA.ElvSkinTab then RA.ElvSkinTab(btn, catPanels, key, classColor) end
        navButtons[key] = btn
    end

    -- Own scroll frame per category (see UI.MakeCategoryPage).
    local function CreateCategoryPanel(key, name)
        return UI.MakeCategoryPage(panel, headerLine, NAV_W, "RollAwayDev", name, catPanels, key, S)
    end

    local logPage      = CreateCategoryPanel("log",      "Log")
    local testsPage    = CreateCategoryPanel("tests",    "Tests")
    local toolsPage    = CreateCategoryPanel("tools",    "Tools")
    local commandsPage = CreateCategoryPanel("commands", "Commands")

    -- Buttons that run a dev command: greyed out while the command is not
    -- usable (most need debug mode on). Refreshed when the panel opens and
    -- when debug mode is switched.
    local actionButtons = {}
    local function RefreshActionButtons()
        for _, entry in ipairs(actionButtons) do
            entry.btn:SetEnabled(RA.DevCommandAvailable(entry.command))
        end
    end

    -- A button for a dev command with its description (and slash command)
    -- below. anchor = what it hangs below (nil: top of the page).
    -- Returns the description text, as the anchor for the next entry.
    local function AddAction(page, anchor, x, y, command, labelKey, slash)
        local btn = MakeSkinnedButton(page, RA_L[labelKey], 200, S)
        if anchor then
            btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
        else
            btn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -8)
        end
        btn:SetScript("OnClick", function() RA.RunDevCommand(command) end)
        actionButtons[#actionButtons + 1] = { btn = btn, command = command }

        local infoKey = "cmd_" .. command:lower() .. "_info"
        return MakeInfoText(page, btn, 0, -4, QOL_INFO_W,
            "|cffFFFFFF" .. slash .. "|r  " .. RA_L[infoKey])
    end

    ------------------------------------------------------------------
    -- Logging: debug mode, errors only, log window
    ------------------------------------------------------------------
    local _, debugInfo = MakeToggle(logPage, nil, 0, -8, {
        label = RA_L["debug_label"], info = RA_L["dev_debug_info"], dbKey = "debug",
        onChange = function(checked)
            RA.OnDebugModeChanged(checked)
            RefreshActionButtons()
        end,
    })

    local _, errorsInfo = MakeToggle(logPage, debugInfo, -20, -14, {
        label = RA_L["debug_errors_only_label"], info = RA_L["dev_errors_only_info"], dbKey = "debugErrorsOnly",
    })

    local logHeader = logPage:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    logHeader:SetPoint("TOPLEFT", errorsInfo, "BOTTOMLEFT", -20, -18)
    logHeader:SetText(RA_L["dev_log_window_label"])

    local openBtn = MakeSkinnedButton(logPage, RA_L["dev_log_open"], 150, S)
    openBtn:SetPoint("TOPLEFT", logHeader, "BOTTOMLEFT", 0, -8)
    openBtn:SetScript("OnClick", RA.ToggleDebugLogWindow)

    local clearBtn = MakeSkinnedButton(logPage, RA_L["dev_log_clear"], 110, S)
    clearBtn:SetPoint("LEFT", openBtn, "RIGHT", 8, 0)
    clearBtn:SetScript("OnClick", RA.ClearDebugLog)

    local resetBtn = MakeSkinnedButton(logPage, RA_L["dev_log_reset"], 190, S)
    resetBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
    resetBtn:SetScript("OnClick", RA.ResetDebugLogWindow)

    local logHint = MakeInfoText(logPage, openBtn, 0, -6, QOL_INFO_W, RA_L["dev_log_hint"])

    -- Log filter: which kinds of lines the debug log shows (RA.DEBUG_CATEGORIES,
    -- Core/Debug.lua). Two columns of checkboxes plus All / None.
    local filterHeader = logPage:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    filterHeader:SetPoint("TOPLEFT", logHint, "BOTTOMLEFT", 0, -18)
    filterHeader:SetText(RA_L["dev_filter_title"])
    local filterInfo = MakeInfoText(logPage, filterHeader, 0, -6, QOL_INFO_W, RA_L["dev_filter_info"])

    local allBtn = MakeSkinnedButton(logPage, RA_L["dev_filter_all"], 80, S)
    allBtn:SetPoint("TOPLEFT", filterInfo, "BOTTOMLEFT", 0, -8)
    local noneBtn = MakeSkinnedButton(logPage, RA_L["dev_filter_none"], 80, S)
    noneBtn:SetPoint("LEFT", allBtn, "RIGHT", 8, 0)

    local filterCBs = {}
    for i, category in ipairs(RA.DEBUG_CATEGORIES) do
        local key = category.key
        local cb = MakeCB(logPage, RA_L["dev_filter_" .. key], RA.IsDebugCategoryOn(key), function(checked)
            RA.SetDebugCategory(key, checked)
        end, 220)
        local column, row = (i - 1) % 2, math.floor((i - 1) / 2)
        cb.frame:SetPoint("TOPLEFT", allBtn, "BOTTOMLEFT", column * 240, -10 - row * 28)
        filterCBs[#filterCBs + 1] = { cb = cb, key = key }
    end

    local function SetAllFilters(on)
        RA.SetAllDebugCategories(on)
        for _, entry in ipairs(filterCBs) do entry.cb:SetValue(on) end
    end
    allBtn:SetScript("OnClick", function() SetAllFilters(true) end)
    noneBtn:SetScript("OnClick", function() SetAllFilters(false) end)

    ------------------------------------------------------------------
    -- Tests: popups and automation, tank marker test mode
    ------------------------------------------------------------------
    local testsAnchor
    local testActions = {
        { "RAWTEST",     "dev_test_autopass", "/rawtest"     },
        { "RAWREMINDER", "dev_test_reminder", "/rawreminder" },
        { "RAWQOL",      "dev_test_qol",      "/rawqol"      },
        { "RAWWHATS",    "dev_test_whatsnew", "/rawwhats"    },
        { "RAWRESET",    "dev_test_reset",    "/rawreset"    },
    }
    for _, def in ipairs(testActions) do
        testsAnchor = AddAction(testsPage, testsAnchor, testsAnchor and 0 or nil, -14, def[1], def[2], def[3])
    end

    local tankTestCB = MakeCB(testsPage, RA_L["dev_tank_test_label"], RA.IsTankMarkerTest(), function(checked)
        RA.SetTankMarkerTest(checked)
    end)
    tankTestCB.frame:SetPoint("TOPLEFT", testsAnchor, "BOTTOMLEFT", 0, -22)
    local tankTestInfo = MakeInfoText(testsPage, tankTestCB.frame, 20, -6, QOL_INFO_W - 20, RA_L["dev_tank_test_info"])

    -- Session-only switch (RA.devTest): try the bonus roll auto-pass in old content,
    -- e.g. MoP raids.
    local oldRaidCB = MakeCB(testsPage, RA_L["dev_oldraid_test_label"], RA.devTest.oldRaidAutoPass, function(checked)
        RA.devTest.oldRaidAutoPass = checked
    end)
    oldRaidCB.frame:SetPoint("TOPLEFT", tankTestInfo, "BOTTOMLEFT", -20, -22)
    MakeInfoText(testsPage, oldRaidCB.frame, 20, -6, QOL_INFO_W - 20, RA_L["dev_oldraid_test_info"])

    ------------------------------------------------------------------
    -- Tools: diagnostics into the log
    ------------------------------------------------------------------
    local toolsAnchor
    local toolActions = {
        { "RAWDUMP",    "dev_tool_dump",    "/rawdump"    },
        { "RAWCHARBTN", "dev_tool_charbtn", "/rawcharbtn" },
    }
    for _, def in ipairs(toolActions) do
        toolsAnchor = AddAction(toolsPage, toolsAnchor, toolsAnchor and 0 or nil, -14, def[1], def[2], def[3])
    end
    MakeInfoText(toolsPage, toolsAnchor, 0, -18, QOL_INFO_W, RA_L["dev_tool_chonky_hint"])

    ------------------------------------------------------------------
    -- Commands: reference list, grouped
    ------------------------------------------------------------------
    local publicHeader = commandsPage:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    publicHeader:SetPoint("TOPLEFT", commandsPage, "TOPLEFT", 0, -8)
    publicHeader:SetText(RA_L["dev_commands_public"])
    local publicList = MakeInfoText(commandsPage, publicHeader, 0, -6, QOL_INFO_W, CommandLines(PUBLIC_COMMANDS))

    local devHeader = commandsPage:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    devHeader:SetPoint("TOPLEFT", publicList, "BOTTOMLEFT", 0, -18)
    devHeader:SetText(RA_L["dev_commands_dev"])
    local devList = MakeInfoText(commandsPage, devHeader, 0, -6, QOL_INFO_W, CommandLines(DEV_COMMANDS))
    MakeInfoText(commandsPage, devList, 0, -10, QOL_INFO_W, RA_L["dev_commands_note"])

    -- The commands are registered after the options are built, and the tank
    -- test mode can change by slash command: sync both on every open.
    panel:HookScript("OnShow", function()
        RefreshActionButtons()
        tankTestCB:SetValue(RA.IsTankMarkerTest())
    end)

    ShowCategory(navDefs[1].key)
end

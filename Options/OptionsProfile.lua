-- RollAway - Options/OptionsProfile.lua
-- Builds the "Profile" settings subcategory: switch, create, copy-from,
-- delete and reset AceDB-3.0 profiles (RA.db). Called once from
-- RA.InitOptions() in Options.lua.
--
-- Note: the rest of the Options UI (General/Dungeons/Raids/... tabs, QoL
-- subcategory) is built once at ADDON_LOADED with each widget's initial
-- value baked in from RollAwayDB at that moment. Switching/copying/
-- resetting a profile here changes the underlying data immediately, but
-- those other widgets won't visually refresh until a UI reload - hence
-- the reload prompt after any profile change below.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

local UI                = RA.OptionsUI
local MakeSectionHeader = UI.MakeSectionHeader
local MakeDropdown      = UI.MakeDropdown
local MakeSkinnedButton = UI.MakeSkinnedButton
local MakeHintText      = UI.MakeHintText

------------------------------------------------------------------------
-- Profile import/export (AceDB profile settings only - Dungeons/Raids/
-- Delves/Prey live in RollAwayDBChar and change too often per-character
-- to be worth sharing this way).
--
-- Format: "RollAway1:" + Base64(CBOR(RA.db.profile)) via the native
-- C_EncodingUtil (available since 11.1.5, well below our min interface).
------------------------------------------------------------------------
local PROFILE_EXPORT_PREFIX = "RollAway1:"

local function EncodeProfile(profile)
    local ok, serialized = pcall(C_EncodingUtil.SerializeCBOR, profile)
    if not ok or type(serialized) ~= "string" then return nil end
    local ok2, encoded = pcall(C_EncodingUtil.EncodeBase64, serialized)
    if not ok2 or type(encoded) ~= "string" then return nil end
    return PROFILE_EXPORT_PREFIX .. encoded
end

local function DecodeProfile(text)
    if type(text) ~= "string" then return nil end
    text = text:match("^%s*(.-)%s*$")
    if text:sub(1, #PROFILE_EXPORT_PREFIX) ~= PROFILE_EXPORT_PREFIX then return nil end
    local encoded = text:sub(#PROFILE_EXPORT_PREFIX + 1)
    local ok1, serialized = pcall(C_EncodingUtil.DecodeBase64, encoded)
    if not ok1 or type(serialized) ~= "string" then return nil end
    local ok2, data = pcall(C_EncodingUtil.DeserializeCBOR, serialized)
    if not ok2 or type(data) ~= "table" then return nil end
    return data
end

-- Recursively copies only keys that exist in RA.defaults.profile, and only
-- when the imported value's type matches the default's - so a garbage or
-- hand-edited string can't smuggle in a bad type and break something else
-- that reads this profile later. Unknown keys are dropped, missing ones
-- fall back to the default.
local function ApplyImportedProfile(target, defaults, imported)
    for k, defaultVal in pairs(defaults) do
        if type(defaultVal) == "table" then
            target[k] = target[k] or {}
            local sub = (type(imported[k]) == "table") and imported[k] or {}
            ApplyImportedProfile(target[k], defaultVal, sub)
        else
            local v = imported[k]
            target[k] = (type(v) == type(defaultVal)) and v or defaultVal
        end
    end
end

------------------------------------------------------------------------
-- StaticPopups (registered once at file load)
--
-- WoW 12.x (Midnight) rewrote StaticPopup on top of the new GameDialog
-- widget: self.editBox / self.button1 / self.data no longer exist on the
-- callback's "self". Use dialog:GetEditBox() / :GetButton1() / :GetButton2(),
-- and the popup's data argument comes in directly as the callback's 2nd
-- parameter instead of self.data.
------------------------------------------------------------------------

-- Edit box helpers shared by the popups below.
local function ClearAndFocusEditBox(dialog)
    local editBox = dialog:GetEditBox()
    editBox:SetText("")
    editBox:SetFocus()
end

-- Enter presses the popup's first button (if enabled).
local function AcceptOnEnter(editBox)
    local dialog = editBox:GetParent()
    if dialog:GetButton1():IsEnabled() then
        StaticPopup_OnClick(dialog, 1)
    end
end

local function CloseDialog(editBox)
    editBox:GetParent():Hide()
end

local function IsValidProfileName(name)
    return name and name ~= "" and not name:find("^%s+$")
end

RA.RegisterPopup("ROLLAWAY_PROFILE_NEW", {
    text         = RA_L["profile_new_prompt"],
    button1      = ACCEPT,
    button2      = CANCEL,
    hasEditBox   = true,
    maxLetters   = 50,
    OnShow       = ClearAndFocusEditBox,
    OnAccept = function(dialog)
        local name = dialog:GetEditBox():GetText()
        if IsValidProfileName(name) then
            RA.db:SetProfile(name)
            RA.PromptProfileReload()
        end
    end,
    EditBoxOnEnterPressed  = AcceptOnEnter,
    EditBoxOnEscapePressed = CloseDialog,
})

RA.RegisterPopup("ROLLAWAY_PROFILE_DELETE", {
    text = RA_L["profile_delete_confirm"],
    button1      = ACCEPT,
    button2      = CANCEL,
    OnAccept = function(_, data)
        RA.db:DeleteProfile(data, true)
        RA.RefreshProfileOptions()
    end,
})

RA.RegisterPopup("ROLLAWAY_PROFILE_RESET", {
    text         = RA_L["profile_reset_confirm"],
    button1      = ACCEPT,
    button2      = CANCEL,
    OnAccept = function()
        RA.db:ResetProfile()
        -- Dungeons/Raids/Delves/Prey selections live in RollAwayDBChar
        -- (SavedVariablesPerCharacter), outside AceDB, so ResetProfile()
        -- above never touches them. Reset it too (back to defaults right
        -- away, so nothing reads it half-empty until the reload).
        wipe(RollAwayDBChar)
        RA.InitCharDB()
        RA.PromptProfileReload()
    end,
})

RA.RegisterPopup("ROLLAWAY_PROFILE_EXPORT", {
    text         = RA_L["profile_export_prompt"],
    button1      = OKAY,
    hasEditBox   = true,
    editBoxWidth = 350,
    maxLetters   = 0,
    OnShow = function(dialog, data)
        local editBox = dialog:GetEditBox()
        editBox:SetText(data or "")
        editBox:HighlightText()
        editBox:SetFocus()
        if not editBox.raCopyCloseHooked then
            editBox.raCopyCloseHooked = true
            editBox:HookScript("OnKeyDown", function(_, key)
                if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
                    -- Deferred: closing immediately on keydown pre-empted the
                    -- native clipboard copy, so the string never got copied.
                    C_Timer.After(0, function() dialog:Hide() end)
                end
            end)
        end
    end,
    EditBoxOnEnterPressed  = CloseDialog,
    EditBoxOnEscapePressed = CloseDialog,
})

RA.RegisterPopup("ROLLAWAY_PROFILE_IMPORT", {
    text         = RA_L["profile_import_prompt"],
    button1      = ACCEPT,
    button2      = CANCEL,
    hasEditBox   = true,
    editBoxWidth = 350,
    maxLetters   = 0,
    OnShow       = ClearAndFocusEditBox,
    OnAccept = function(dialog)
        local imported = DecodeProfile(dialog:GetEditBox():GetText())
        if not imported then
            UIErrorsFrame:AddMessage(RA_L["profile_import_invalid"], 1, 0.2, 0.2, 1)
            return
        end
        RA.pendingProfileImport = imported
        StaticPopup_Show("ROLLAWAY_PROFILE_IMPORT_NAME")
    end,
    EditBoxOnEnterPressed  = AcceptOnEnter,
    EditBoxOnEscapePressed = CloseDialog,
})

RA.RegisterPopup("ROLLAWAY_PROFILE_IMPORT_NAME", {
    text         = RA_L["profile_import_name_prompt"],
    button1      = ACCEPT,
    button2      = CANCEL,
    hasEditBox   = true,
    maxLetters   = 50,
    OnShow       = ClearAndFocusEditBox,
    OnAccept = function(dialog)
        local name = dialog:GetEditBox():GetText()
        local imported = RA.pendingProfileImport
        RA.pendingProfileImport = nil
        if imported and IsValidProfileName(name) then
            RA.db:SetProfile(name)
            ApplyImportedProfile(RA.db.profile, RA.defaults.profile, imported)
            RA.PromptProfileReload()
        end
    end,
    OnCancel = function() RA.pendingProfileImport = nil end,
    EditBoxOnEnterPressed  = AcceptOnEnter,
    EditBoxOnEscapePressed = CloseDialog,
})

RA.RegisterPopup("ROLLAWAY_PROFILE_RELOAD", {
    text         = RA_L["profile_reload_prompt"],
    button1      = RA_L["profile_reload_now"],
    button2      = CANCEL,
    OnAccept = function() ReloadUI() end,
})

-- Flags the settings UI as out of date (needs a /reload) and offers one.
function RA.PromptProfileReload()
    RA.profileReloadPending = true
    RA.RefreshProfileOptions()
    StaticPopup_Show("ROLLAWAY_PROFILE_RELOAD")
end

------------------------------------------------------------------------
-- Subcategory: Profile
------------------------------------------------------------------------
function RA.BuildProfileOptions(category, S)
    local panel = CreateFrame("Frame")
    Settings.RegisterCanvasLayoutSubcategory(category, panel, RA_L["profile_section_title"])

    local _, headerLine = MakeSectionHeader(panel, panel, -10, RA_L["profile_panel_title"])
    local hint = MakeHintText(panel, headerLine, RA_L["profile_panel_info"])

    -- ── Active profile ───────────────────────────────────────────────
    local activeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    activeLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -18)
    activeLabel:SetText(RA_L["profile_active_label"])

    local activeDD = MakeDropdown(panel, activeLabel, 0, -4, 220)

    -- ── New / Reset (act on the active profile) ─────────────────────
    local function MakeButton(label, width)
        return MakeSkinnedButton(panel, label, width, S)
    end

    local newBtn = MakeButton(RA_L["profile_new_button"], 90)
    newBtn:SetPoint("LEFT", activeDD.frame, "RIGHT", 16, 0)

    local resetBtn = MakeButton(RA_L["profile_reset_button"], 130)
    resetBtn:SetPoint("LEFT", newBtn, "RIGHT", 8, 0)

    -- ── Other profile: copy from / delete ────────────────────────────
    local otherLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    otherLabel:SetPoint("TOPLEFT", activeDD.frame, "BOTTOMLEFT", 0, -24)
    otherLabel:SetText(RA_L["profile_other_label"])

    local otherDD = MakeDropdown(panel, otherLabel, 0, -4, 220)

    local copyBtn = MakeButton(RA_L["profile_copy_button"], 90)
    copyBtn:SetPoint("LEFT", otherDD.frame, "RIGHT", 16, 0)

    local deleteBtn = MakeButton(RA_L["profile_delete_button"], 90)
    deleteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)

    -- ── Import / Export (act on the active profile) ──────────────────
    local exportInfoText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    exportInfoText:SetPoint("TOPLEFT", otherDD.frame, "BOTTOMLEFT", 0, -12)
    exportInfoText:SetJustifyH("LEFT")
    exportInfoText:SetText(RA_L["profile_export_info"])

    local exportInfoName = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    exportInfoName:SetPoint("LEFT", exportInfoText, "RIGHT", 4, 0)
    exportInfoName:SetJustifyH("LEFT")

    local importBtn = MakeButton(RA_L["profile_import_button"], 90)
    importBtn:SetPoint("TOPLEFT", exportInfoText, "BOTTOMLEFT", 0, -6)

    local exportBtn = MakeButton(RA_L["profile_export_button"], 90)
    exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)

    -- ── Data wiring ───────────────────────────────────────────────────

    -- Rebuilds both dropdown lists/values from RA.db's current state.
    -- Exposed so the popups above can trigger a refresh after a change.
    local selectedOther
    local function Refresh()
        local current = RA.db:GetCurrentProfile()

        local allProfiles = RA.db:GetProfiles()
        table.sort(allProfiles)

        local activeList = {}
        for _, name in ipairs(allProfiles) do activeList[name] = name end
        activeDD:SetList(activeList, allProfiles)
        activeDD:SetValue(current)

        exportInfoName:SetText(current)
        if RA.profileReloadPending then
            exportInfoName:SetTextColor(1, 0.25, 0.25)
        else
            exportInfoName:SetTextColor(0.25, 1, 0.25)
        end

        local otherOrder, otherList = {}, {}
        for _, name in ipairs(allProfiles) do
            if name ~= current then
                otherList[name] = name
                table.insert(otherOrder, name)
            end
        end

        local hasOther = otherOrder[1] ~= nil
        if hasOther then
            otherDD:SetList(otherList, otherOrder)
            if selectedOther and not otherList[selectedOther] then selectedOther = nil end
            if not selectedOther then selectedOther = otherOrder[1] end
            otherDD:SetValue(selectedOther)
        else
            -- A genuinely empty list leaves the dropdown's pullout menu
            -- permanently expanded (library/Blizzard menu-template quirk)
            -- instead of rendering a normal closed box. Feed it one inert
            -- placeholder entry instead, and disable the widget.
            selectedOther = nil
            otherDD:SetList({ [""] = RA_L["profile_none_available"] }, { "" })
            otherDD:SetValue("")
        end
        otherDD:SetDisabled(not hasOther)
        if hasOther then
            copyBtn:Enable()
            deleteBtn:Enable()
        else
            copyBtn:Disable()
            deleteBtn:Disable()
        end
    end
    RA.RefreshProfileOptions = Refresh

    activeDD:SetCallback("OnValueChanged", function(_, _, value)
        if value and value ~= RA.db:GetCurrentProfile() then
            RA.db:SetProfile(value)
            RA.PromptProfileReload()
        end
    end)

    otherDD:SetCallback("OnValueChanged", function(_, _, value)
        -- "" is the inert placeholder shown when no other profile exists
        -- (widget stays disabled then), never a real profile name.
        selectedOther = (value ~= "" and value) or nil
    end)

    newBtn:SetScript("OnClick", function()
        StaticPopup_Show("ROLLAWAY_PROFILE_NEW")
    end)

    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("ROLLAWAY_PROFILE_RESET")
    end)

    copyBtn:SetScript("OnClick", function()
        if selectedOther then
            RA.db:CopyProfile(selectedOther)
            RA.PromptProfileReload()
        end
    end)

    deleteBtn:SetScript("OnClick", function()
        if selectedOther then
            StaticPopup_Show("ROLLAWAY_PROFILE_DELETE", selectedOther, nil, selectedOther)
        end
    end)

    exportBtn:SetScript("OnClick", function()
        local encoded = EncodeProfile(RA.db.profile)
        if encoded then
            StaticPopup_Show("ROLLAWAY_PROFILE_EXPORT", nil, nil, encoded)
        else
            UIErrorsFrame:AddMessage(RA_L["profile_export_failed"], 1, 0.2, 0.2, 1)
        end
    end)

    importBtn:SetScript("OnClick", function()
        StaticPopup_Show("ROLLAWAY_PROFILE_IMPORT")
    end)

    Refresh()

    return panel
end

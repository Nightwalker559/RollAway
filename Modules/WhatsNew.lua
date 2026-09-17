local RA   = _G.RollAway
local RA_L = RA.RA_L

-- Bump this whenever a new feature entry is added below.
local WHATS_NEW_VERSION = "3.0.5"

-- Each entry: { title, description, location } - all three pulled from
-- RA_L so this shows correctly in both enUS and deDE.
-- Only entries for the CURRENT version (WHATS_NEW_VERSION above) belong
-- here - clear this list out and replace it whenever that version bumps.
local FEATURES = {
    {
        title       = RA_L["whatsnew_autoaccept_title"],
        description = RA_L["whatsnew_autoaccept_desc"],
        location    = RA_L["whatsnew_autoaccept_location"],
    },
    {
        title       = RA_L["whatsnew_autorepair_title"],
        description = RA_L["whatsnew_autorepair_desc"],
        location    = RA_L["whatsnew_autorepair_location"],
    },
}

-- ============================================================
-- Frame
-- ============================================================

local frame

local function CreateWhatsNewFrame()
    local f = CreateFrame("Frame", "RollAwayWhatsNewFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(440, 340)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    RA.MakeDraggable(f)

    f.TitleText:SetText("RollAway - What's New  |cFFAA8830v" .. WHATS_NEW_VERSION .. "|r")

    -- Plain ScrollFrame without template — no scrollbar widget, mousewheel only
    local sf = CreateFrame("ScrollFrame", "RollAwayWhatsNewScroll", f)
    sf:SetPoint("TOPLEFT",     f, "TOPLEFT",      12, -32)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  -12,  44)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local max     = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, current - delta * 30)))
    end)

    -- Content frame: fixed width, height grows with cards
    -- Frame 440 - inset(~8 each side) - scrollbar(~20) - card margins = 380
    local CARD_W = 380

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(CARD_W + 8)
    content:SetHeight(1)
    sf:SetScrollChild(content)

    local yOffset = -8

    for _, feat in ipairs(FEATURES) do
        local card = CreateFrame("Frame", nil, content, "BackdropTemplate")
        card:SetWidth(CARD_W)
        card:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOffset)
        card:SetBackdrop(nil)

        -- Title
        local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleText:SetWidth(CARD_W - 26)
        titleText:SetPoint("TOPLEFT", card, "TOPLEFT", 22, -9)
        titleText:SetJustifyH("LEFT")
        titleText:SetTextColor(0.94, 0.75, 0.25)
        titleText:SetText(feat.title)

        -- Gold bullet — centered vertically with title
        local bullet = card:CreateTexture(nil, "ARTWORK")
        bullet:SetSize(6, 6)
        bullet:SetPoint("RIGHT", titleText, "LEFT", -4, 0)
        bullet:SetColorTexture(0.91, 0.72, 0.25, 1)

        -- Description
        local descText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        descText:SetWidth(CARD_W - 20)
        descText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -30)
        descText:SetJustifyH("LEFT")
        descText:SetSpacing(2)
        descText:SetTextColor(0.78, 0.66, 0.40)
        descText:SetText(feat.description)

        -- Location line
        local locLabel = card:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        locLabel:SetWidth(CARD_W - 20)
        locLabel:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -6)
        locLabel:SetJustifyH("LEFT")
        locLabel:SetText("|cFF6A5020Options:|r |cFFA08840" .. feat.location .. "|r")

        local cardH = 32 + descText:GetStringHeight() + locLabel:GetStringHeight() + 14
        card:SetHeight(cardH)
        yOffset = yOffset - cardH - 8
    end

    content:SetHeight(math.abs(yOffset) + 8)

    -- OK button
    local okBtn = CreateFrame("Button", "RollAwayWhatsNewOkay", f, "UIPanelButtonTemplate")
    okBtn:SetSize(90, 24)
    okBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    okBtn:SetText(RA.RA_L["reminder_okay"])
    okBtn:SetScript("OnClick", function()
        RollAwayDB.whatsNewSeen = WHATS_NEW_VERSION
        f:Hide()
    end)

    return f
end

-- ============================================================
-- Public API
-- ============================================================

function RA.ShowWhatsNew()
    if not frame then
        frame = CreateWhatsNewFrame()
    end
    frame:Show()
end

-- ============================================================
-- Init
-- ============================================================

function RA.InitWhatsNew()
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function(self)
        if RollAwayDB.whatsNewSeen ~= WHATS_NEW_VERSION then
            RA.ShowWhatsNew()
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    end)
end
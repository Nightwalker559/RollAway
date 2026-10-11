-- RollAway - MinimapButton.lua
-- Minimap button (no library): left click toggles the feature overview, right click the
-- options, drag moves it (angle saved in the profile). Hidden with minimapButtonHide (QoL > Hide).
-- Named like a LibDBIcon button ("LibDBIcon10_<name>", .icon / .border / .background) so
-- button collectors (LuckyoneUI, MinimapButtonButton ...) pick it up.

local RA   = _G.RollAway
local RA_L = RA.RA_L

local button

-- Places the button on the minimap edge at `angle` degrees (0 = right, counterclockwise);
-- square minimaps (ElvUI) get the button on the square edge.
local function Place(angle)
    -- A collector moved the button into its own bar: leave the layout to it.
    if button:GetParent() ~= Minimap then return end
    local rad = math.rad(angle)
    local dx, dy = math.cos(rad), math.sin(rad)
    local half = Minimap:GetWidth() / 2 + 5
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape ~= "ROUND" then
        local m = math.max(math.abs(dx), math.abs(dy))
        dx, dy = dx / m, dy / m
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", dx * half, dy * half)
end

local function UpdateAngleFromCursor()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    RollAwayDB.minimapAngle = angle
    Place(angle)
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(RA_L["addon_title"])
    GameTooltip:AddLine(RA_L["feat_mm_left"], 1, 1, 1)
    GameTooltip:AddLine(RA_L["feat_mm_right"], 1, 1, 1)
    GameTooltip:AddLine(RA_L["feat_mm_drag"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function CreateButton()
    local b = CreateFrame("Button", "LibDBIcon10_RollAway", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\AddOns\\RollAway\\Media\\Icon")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.icon, b.border, b.background = icon, border, bg

    b:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            RA.ToggleOptions()
        else
            RA.ToggleFeatureList()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", UpdateAngleFromCursor)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Shows or hides the button according to the setting (creates it on first need).
local function Apply()
    if RollAwayDB.minimapButtonHide then
        if button then button:Hide() end
        return
    end
    if not button then button = CreateButton() end
    Place(RollAwayDB.minimapAngle or 225)
    button:Show()
end

-- Button bars (LuckyoneUI) re-collect on ElvUI's minimap update; LibDBIcon buttons trigger
-- that through the library's Show/Hide, a button without it has to ask. Without this the
-- gap of a hidden button stays until the next reload.
local function NotifyButtonBars()
    local E = ElvUI and ElvUI[1]
    local minimap = E and E.GetModule and E:GetModule("Minimap", true)
    if minimap and minimap.UpdateSettings then pcall(minimap.UpdateSettings, minimap) end
end

-- After a setting change (options, overview, profile switch).
function RA.ApplyMinimapButton()
    Apply()
    NotifyButtonBars()
end

function RA.InitMinimapButton()
    Apply()
    -- A profile switch brings another saved position / visibility.
    RA.db.onProfileChange = (function(previous)
        return function(...)
            if previous then previous(...) end
            RA.ApplyMinimapButton()
        end
    end)(RA.db.onProfileChange)
end

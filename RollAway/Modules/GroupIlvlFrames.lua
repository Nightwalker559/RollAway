-- RollAway - Modules/GroupIlvlFrames.lua
-- Item level of the party members in Blizzard's default party frames, both styles: the classic
-- PartyFrame (PartyMemberFrame) and the raid-style CompactPartyFrame. The levels come from
-- Modules/GroupIlvl.lua (RA.FormatGroupIlvl); ElvUI's frames get them through the [raw:ilvl]
-- tags (Core/ElvUI_Tags.lua). Party only: raid frames stay as they are.
--
-- Each member frame gets one FontString of ours next to it. The name text is left alone (it can be
-- a secret value inside instances, to which nothing can be appended), and the FontStrings are kept
-- in a weak table so no field is written into Blizzard's frames. The hooks are post-hooks and only
-- ask for a redraw on the next frame; nothing of Blizzard's code is called from ours.
--
-- Active while RollAwayDB.groupIlvl is on (RA.SetGroupIlvlFrames, called by RA.ApplyGroupIlvl).
-- With ElvUI's unit frames the default frames are hidden, and so is our text with them.

local RA = _G["RollAway"]

local FONT_SIZE_DEFAULT = 10
local BULLET   = "\226\128\162 "   -- "• " between the name and the level
local NAME_GAP = 4

-- The positions around the frame: our text anchor point, the point of the member frame it hangs
-- on, and the offset. Any other value means the name row (see Place).
local ANCHORS = {
    right  = { "LEFT",   "RIGHT",  4,  0 },
    left   = { "RIGHT",  "LEFT",  -4,  0 },
    top    = { "BOTTOM", "TOP",    0,  2 },
    bottom = { "TOP",    "BOTTOM", 0, -2 },
}

local texts = setmetatable({}, { __mode = "k" })   -- member frame -> our FontString
local active = false
local hooked = false
local scheduled = false
local eventFrame

local function IsPartyUnit(unit)
    return type(unit) == "string" and (unit == "player" or unit:find("^party%d$") ~= nil)
end

-- A number from a region, nil when it cannot be read (the name's text width is a secret value
-- when the name itself is one).
local function Measure(region, method)
    local ok, value = pcall(region[method], region)
    if ok and type(value) == "number" and RA.IsAccessible(value) then return value end
end

-- Sets the text and puts it in place. `nameText`: the frame's name FontString. The default position
-- is the name row: "Name • 335", the level right behind the name's text, however long the name
-- is. When the width of the name cannot be read the level goes
-- to the end of the name's box instead (raid-style frames: the box spans the frame, the name is
-- left aligned; classic frames: the box has a fixed width).
local function Place(fs, frame, nameText, compact, text)
    local pos = RollAwayDB.groupIlvlPos
    local font = fs:GetFont()
    local nameFont, nameSize, nameFlags
    if nameText and not ANCHORS[pos] then
        local ok, f, s, fl = pcall(nameText.GetFont, nameText)
        if ok and f then nameFont, nameSize, nameFlags = f, s, fl end
    end
    if nameFont then
        -- In the name row we look like the name: its font, size and (no) outline.
        fs:SetFont(nameFont, nameSize, nameFlags)
    else
        -- Outside the frame the outline keeps the text readable on any background.
        fs:SetFont(font, RollAwayDB.groupIlvlSize or FONT_SIZE_DEFAULT, "OUTLINE")
    end
    fs:ClearAllPoints()
    if ANCHORS[pos] then
        local a = ANCHORS[pos]
        fs:SetText(text)
        fs:SetPoint(a[1], frame, a[2], a[3], a[4])
    elseif nameText then
        fs:SetText(BULLET .. text)
        local nameWidth = Measure(nameText, "GetStringWidth")
        if nameWidth then
            local box = Measure(nameText, "GetWidth")
            if box and box <= 0 then box = nil end
            local x
            if compact then
                -- The box ends at the frame's edge: the level stays inside it.
                x = nameWidth + NAME_GAP
                if box then x = math.min(x, math.max(box - fs:GetStringWidth(), 0)) end
            else
                -- The box is narrower than the frame and cuts a long name off; the level goes
                -- behind the box then, a little past the frame's edge if it has to.
                x = math.min(nameWidth, box or nameWidth) + NAME_GAP
            end
            fs:SetPoint("LEFT", nameText, "LEFT", x, 0)
        elseif compact then
            fs:SetPoint("RIGHT", nameText, "RIGHT", 0, 0)
        else
            fs:SetPoint("LEFT", nameText, "RIGHT", 3, 0)
        end
    else
        fs:SetText(text)
        fs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    end
end

-- Shows the level of `unit` on `frame`; hides the text when there is nothing to show.
local function Show(frame, unit, nameText, compact)
    local text = unit and RA.FormatGroupIlvl(unit)
    local fs = texts[frame]
    if not text then
        if fs then fs:Hide() end
        return
    end
    if not fs then
        fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        texts[frame] = fs
    end
    Place(fs, frame, nameText, compact, text)
    fs:Show()
end

local function Refresh()
    scheduled = false
    if not active then
        for _, fs in pairs(texts) do fs:Hide() end
        return
    end

    local inRaid = IsInRaid()
    local preview = EditModeManagerFrame and EditModeManagerFrame:ArePartyFramesForcedShown()

    -- Classic style: party1..party4 (the player has his own frame, which we leave alone).
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if pool then
        for frame in pool:EnumerateActive() do
            local unit = frame.unitToken
            -- Edit Mode preview: Blizzard fills the frames of missing members with the player.
            if preview and IsPartyUnit(unit) and not UnitExists(unit) then unit = "player" end
            Show(frame, not inRaid and IsPartyUnit(unit) and unit or nil, frame.Name, false)
        end
    end

    -- Raid style: the player and the party members in one frame set. Created on demand by
    -- Blizzard, so it may not exist yet.
    local members = CompactPartyFrame and CompactPartyFrame.memberUnitFrames
    if members then
        for i = 1, #members do
            local frame = members[i]
            local unit = frame.unit
            Show(frame, not inRaid and IsPartyUnit(unit) and unit or nil, frame.name, true)
        end
    end
end

-- Bursts (roster changes, Blizzard redoing all frames) become one pass on the next frame.
local function Schedule()
    if scheduled then return end
    scheduled = true
    RunNextFrame(Refresh)
end

local function InstallHooks()
    if hooked then return end
    hooked = true
    -- groupType is set on the party/raid member frames only, not on nameplates.
    local function OnCompactFrame(frame)
        if active and frame.groupType and not IsInRaid() then Schedule() end
    end
    hooksecurefunc("CompactUnitFrame_SetUnit", OnCompactFrame)
    hooksecurefunc("CompactUnitFrame_UpdateName", OnCompactFrame)   -- the name's width decides where we sit
    if PartyFrame and PartyFrame.UpdatePartyFrames then
        hooksecurefunc(PartyFrame, "UpdatePartyFrames", Schedule)
    end
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", Schedule)
end

-- Called with the setting by RA.ApplyGroupIlvl (login and every toggle).
function RA.SetGroupIlvlFrames(enabled)
    active = enabled and true or false
    if active then
        InstallHooks()
        eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif eventFrame then
        eventFrame:UnregisterAllEvents()
    end
    Schedule()
end

-- After the position or the size changed; level changes arrive through RA.OnGroupIlvlChanged.
function RA.RefreshGroupIlvlFrames()
    Schedule()
end

RA.OnGroupIlvlChanged(function() if active then Schedule() end end)

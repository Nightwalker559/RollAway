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

local FONT_SIZE_DEFAULT = 12

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

-- `nameText`: the frame's name FontString. The default position is the name row: at the right end
-- of the name's box in the raid-style frames (it spans the frame's width, the name is left
-- aligned), right behind the fixed-width name box in the classic frames.
local function Place(fs, frame, nameText, compact)
    local pos = RollAwayDB.groupIlvlPos
    fs:ClearAllPoints()
    if ANCHORS[pos] then
        local a = ANCHORS[pos]
        fs:SetPoint(a[1], frame, a[2], a[3], a[4])
    elseif nameText and compact then
        fs:SetPoint("RIGHT", nameText, "RIGHT", 0, 0)
    elseif nameText then
        fs:SetPoint("LEFT", nameText, "RIGHT", 3, 0)
    else
        fs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    end
    local font = fs:GetFont()
    fs:SetFont(font, RollAwayDB.groupIlvlSize or FONT_SIZE_DEFAULT, "OUTLINE")
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
    Place(fs, frame, nameText, compact)
    fs:SetText(text)
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
    hooksecurefunc("CompactUnitFrame_SetUnit", function(frame)
        if active and frame.groupType then Schedule() end
    end)
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

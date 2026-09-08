-- RollAway - Paragon.lua
-- Midnight paragon bag notification.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local C_Timer_After    = RA.C_Timer_After

local TIMER_DURATION = 60

------------------------------------------------------------------------
-- Midnight paragon quest table: questID -> locale key
------------------------------------------------------------------------
local PARAGON_QUESTS = {
    [94492] = "paragon_faction_slayers_duellum",
    [89032] = "paragon_faction_singularity",
    [93811] = "paragon_faction_silvermoon_court",
    [95391] = "paragon_faction_ritual_sites",
    [89035] = "paragon_faction_harati",
    [93566] = "paragon_faction_amani_tribe",
    [93798] = "paragon_faction_zuljarras_forces",
}

------------------------------------------------------------------------
-- Quests with a known turn-in NPC + zone (verified via Wowhead 12.0.7).
-- Text lives in locale files as paragon_npc_<questID> / paragon_zone_<questID>.
-- Static table since the live waypoint API only covers the tracked quest.
------------------------------------------------------------------------
local PARAGON_LOCATION_QUESTS = {
    [94492] = true,
    [89032] = true, -- Quest text says "Murik in Iskaara" (recycled DF text,
                     -- Blizzard bug since 11.0.5); actual turn-in is Void
                     -- Researcher Anomander at Howling Ridge in Voidstorm.
    [93811] = true,
    [95391] = true,
    [89035] = true,
    [93566] = true,
    -- [93798] Zul'jarra's Forces: turn-in NPC/zone not yet verified, omitted for now.
}

local function GetQuestLocation(questID)
    if not PARAGON_LOCATION_QUESTS[questID] then return nil end
    return {
        npc  = RA_L["paragon_npc_"  .. questID],
        zone = RA_L["paragon_zone_" .. questID],
    }
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------

local paragonFrame
local paragonTimer  -- RA.CreateTimerBar handle (Start/Stop), set in CreateParagonFrame

local function CreateParagonFrame()
    if paragonFrame then return end

    paragonFrame = RA.CreatePopupFrame({
        name     = "RollAwayParagonFrame",
        okayName = "RollAwayParagonOkay",
        width    = 300,
        height   = 130,
        yOffset  = -220,
    })
    paragonTimer = paragonFrame.timer

    -- Header (count line)
    paragonFrame.header = paragonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    paragonFrame.header:SetPoint("TOPLEFT",  paragonFrame, "TOPLEFT",  10, -40)
    paragonFrame.header:SetPoint("TOPRIGHT", paragonFrame, "TOPRIGHT", -10, -40)
    paragonFrame.header:SetJustifyH("LEFT")

    -- Row pool: bullet + content FontString, content anchored right after
    -- the bullet so wrapped lines stay aligned under the entry text.
    paragonFrame.rows = {}

    paragonFrame:SetScript("OnShow", function(self)
        if RA.C_Timer_After then
            RA.C_Timer_After(0, function()
                if not self:IsShown() then return end
                local lastRow = self.rows[self.numActiveRows]
                local bottomY = lastRow and lastRow.content:GetBottom() or self.header:GetBottom()
                local topY = self:GetTop()
                local contentHeight = (topY and bottomY) and (topY - bottomY) or 80
                -- contentHeight (top edge -> last row bottom) + gap + btn(22) + bar(8) + pad(18)
                self:SetHeight(math.max(130, contentHeight + 10 + 22 + 8 + 18))
            end)
        end
        paragonTimer.Start(TIMER_DURATION)
    end)

    paragonFrame:SetScript("OnHide", paragonTimer.Stop)
end

-- Returns the row for index, creating and anchoring it below the previous row on first use.
local function EnsureRow(index)
    local row = paragonFrame.rows[index]
    if row then return row end

    local bullet = paragonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bullet:SetWidth(14)
    bullet:SetJustifyH("LEFT")
    bullet:SetText("|cffFFD100-|r")

    local content = paragonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    content:SetPoint("TOPLEFT", bullet, "TOPRIGHT", 2, 0)
    content:SetPoint("RIGHT", paragonFrame, "RIGHT", -10, 0)
    content:SetJustifyH("LEFT")
    content:SetNonSpaceWrap(true)

    if index == 1 then
        bullet:SetPoint("TOPLEFT", paragonFrame.header, "BOTTOMLEFT", 0, -6)
    else
        local prev = paragonFrame.rows[index - 1]
        -- X must match the previous bullet (not its content, which starts
        -- further right) — otherwise each row drifts further to the right.
        bullet:SetPoint("LEFT", prev.bullet, "LEFT", 0, 0)
        bullet:SetPoint("TOP",  prev.content, "BOTTOM", 0, -4)
    end

    row = { bullet = bullet, content = content }
    paragonFrame.rows[index] = row
    return row
end

------------------------------------------------------------------------
-- Logic
------------------------------------------------------------------------

local function GetAvailableParagonQuests()
    local found = {}
    for questID, locKey in pairs(PARAGON_QUESTS) do
        if C_QuestLog.IsOnQuest(questID) then
            found[#found + 1] = { name = RA_L[locKey], questID = questID }
        end
    end
    table.sort(found, function(a, b) return a.name < b.name end)
    return found
end

function RA.ShowParagonFrame(quests)
    CreateParagonFrame()

    -- Stack below the Reminder frame if it's currently shown, to avoid
    -- both notifications overlapping at the same default position.
    paragonFrame:ClearAllPoints()
    local reminderFrame = _G["RollAwayReminderFrame"]
    if reminderFrame and reminderFrame:IsShown() then
        paragonFrame:SetPoint("TOP", reminderFrame, "BOTTOM", 0, -10)
    else
        paragonFrame:SetPoint("TOP", UIParent, "TOP", 0, -220)
    end

    local countKey = (#quests == 1) and "paragon_count_one" or "paragon_count_many"
    paragonFrame.header:SetText(string.format(RA_L[countKey], #quests))

    for i, q in ipairs(quests) do
        local row = EnsureRow(i)
        local text = q.name
        local loc = GetQuestLocation(q.questID)
        if loc then
            text = text .. string.format(RA_L["paragon_location"], loc.npc, loc.zone)
        end
        row.content:SetText(text)
        row.bullet:Show()
        row.content:Show()
    end

    -- Hide any leftover rows from a previous, longer list.
    for i = #quests + 1, #paragonFrame.rows do
        paragonFrame.rows[i].bullet:Hide()
        paragonFrame.rows[i].content:Hide()
    end
    paragonFrame.numActiveRows = #quests

    paragonFrame:Show()
    DBG("[Paragon] Showing frame, count:", #quests)
end

local function CheckAndShow()
    if not RollAwayDB or not RollAwayDB.paragonAlert then return end
    local quests = GetAvailableParagonQuests()
    if #quests == 0 then return end
    RA.ShowParagonFrame(quests)
end

-- Manual check: always runs regardless of the paragonAlert setting.
local function ManualCheck()
    local quests = GetAvailableParagonQuests()
    if #quests == 0 then
        print("|cff33ff99RollAway:|r " .. RA_L["paragon_none"])
        return
    end
    RA.ShowParagonFrame(quests)
end

-- Dev-only test (/rawreminder): shows the frame with fake names but real
-- questIDs, ignoring the paragonAlert setting.
local function TestShow()
    RA.ShowParagonFrame({
        { name = RA_L["paragon_faction_silvermoon_court"], questID = 93811 },
        { name = RA_L["paragon_faction_amani_tribe"],      questID = 93566 },
    })
end
RA.ParagonTestShow = TestShow

------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------

function RA.InitParagon()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("QUEST_ACCEPTED")

    f:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_ENTERING_WORLD" then
            -- arg1 = isInitialLogin, arg2 = isReloadingUi.
            -- Only fire on actual login, never on /reload or zoning.
            if not arg1 then return end

            -- Delay so the quest log is fully populated before scanning.
            if C_Timer_After then
                C_Timer_After(3, CheckAndShow)
            else
                CheckAndShow()
            end

        elseif event == "QUEST_ACCEPTED" then
            -- arg1 is the questID in modern WoW (Shadowlands+).
            if not PARAGON_QUESTS[arg1] then return end
            DBG("[Paragon] Paragon quest accepted:", arg1)
            if not (RollAwayDB and RollAwayDB.paragonAlert) then return end
            -- Short delay so IsOnQuest() returns true reliably.
            if C_Timer_After then
                C_Timer_After(0.5, function()
                    local quests = GetAvailableParagonQuests()
                    if #quests > 0 then RA.ShowParagonFrame(quests) end
                end)
            end
        end
    end)

    -- /rawparagon – manual check, available to all users
    SLASH_RAWPARAGON1 = "/rawparagon"
    SlashCmdList["RAWPARAGON"] = ManualCheck

    DBG("[Paragon] Initialized")
end
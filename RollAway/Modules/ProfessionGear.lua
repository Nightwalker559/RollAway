-- RollAway - ProfessionGear.lua
-- Professions: removes the Dragonflight profession appearance auras (the outfit and tool
-- that gathering and crafting put on your character). Cancelling an aura is blocked in
-- combat, so this only runs out of combat; leftovers go when combat ends.
--
-- Settings: RollAwayDB.hideProfessionGear / hideProfessionGearInstant.
-- Instant off: the auras go when the activity ends (cast / channel stop), so the gear
-- shows while you work. Instant on: they go the moment they appear.
-- The fishing aura is never cancelled instantly (that ends the fishing channel); it
-- goes when the channel stops.

local RA  = _G["RollAway"]
local DBG = RA.DBG

local GEAR_AURAS = {
    [394003] = true,  -- Spark of Madness (Alchemy)
    [388658] = true,  -- Suited For Smithing (Blacksmithing)
    [394015] = true,  -- An Eye For Shine (Jewelcrafting)
    [394008] = true,  -- A Looker's Charm (Enchanting)
    [394007] = true,  -- A Production-Grade Display (Engineering)
    [394016] = true,  -- Artist's Duds (Inscription)
    [394001] = true,  -- Sculpting Leather Finery (Leatherworking)
    [391312] = true,  -- Wrapped Up In Weaving (Tailoring)
    [391775] = true,  -- What's Cookin', Good Lookin'? (Cooking)
    [394005] = true,  -- A Cultivator's Colors (Herbalism)
    [394006] = true,  -- Rockin' Mining Gear (Mining)
    [394011] = true,  -- Dressed To Kill (Skinning)
}
local FISHING_AURA = 394009  -- Fishing for Attention

local UNIT_EVENTS  = { "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP" }
local WORLD_EVENTS = { "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

local eventFrame
local loginSweep  -- entered the world, the full aura update that follows is not seen yet

-- Aura data is a secret value in some situations (restricted encounters, PvP): skipped then.
local function CancelBySpell(spellID)
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok or not aura or not RA.IsAccessible(aura) then return end
    local instanceID = aura.auraInstanceID
    if instanceID and RA.IsAccessible(instanceID) then
        pcall(C_UnitAuras.CancelAuraByInstanceID, "player", instanceID)
    end
end

local function RemoveGear(includeFishing)
    if InCombatLockdown() then return end
    for spellID in pairs(GEAR_AURAS) do CancelBySpell(spellID) end
    if includeFishing then CancelBySpell(FISHING_AURA) end
end

-- UNIT_AURA only while it is needed: instant mode, or until the first full update after
-- entering the world (the signal that the aura list is there).
local function UpdateAuraEvent()
    local db = RollAwayDB
    if db and db.hideProfessionGear and (db.hideProfessionGearInstant or loginSweep) then
        eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    else
        eventFrame:UnregisterEvent("UNIT_AURA")
    end
end

local function HandleAuraUpdate(info)
    if info.isFullUpdate then
        if loginSweep then
            loginSweep = false
            RemoveGear(true)
            UpdateAuraEvent()
        elseif RollAwayDB.hideProfessionGearInstant then
            RemoveGear()
        end
        return
    end

    if not RollAwayDB.hideProfessionGearInstant then return end
    local added = info.addedAuras
    if not added or not RA.IsAccessible(added) then return end
    for _, aura in ipairs(added) do
        if RA.IsAccessible(aura) then
            local spellID, instanceID = aura.spellId, aura.auraInstanceID
            if RA.IsAccessible(spellID) and GEAR_AURAS[spellID] and RA.IsAccessible(instanceID) then
                pcall(C_UnitAuras.CancelAuraByInstanceID, "player", instanceID)
            end
        end
    end
end

local function OnEvent(_, event, _, info)
    if event == "UNIT_AURA" then
        -- Cannot cancel in combat, and the payload can be secret outside it too.
        if InCombatLockdown() or not info or not RA.IsAccessible(info) then return end
        pcall(HandleAuraUpdate, info)
    elseif event == "PLAYER_ENTERING_WORLD" then
        loginSweep = true
        UpdateAuraEvent()
        RunNextFrame(function() RemoveGear(true) end)
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "PLAYER_REGEN_ENABLED" then
        RemoveGear(true)   -- no channel running any more, the fishing aura can go too
    else
        RemoveGear()
    end
end

-- At load and on option change.
function RA.ApplyProfessionGearFeature()
    if not eventFrame then return end
    local on = RollAwayDB and RollAwayDB.hideProfessionGear
    for _, event in ipairs(UNIT_EVENTS) do
        if on then eventFrame:RegisterUnitEvent(event, "player") else eventFrame:UnregisterEvent(event) end
    end
    for _, event in ipairs(WORLD_EVENTS) do
        if on then eventFrame:RegisterEvent(event) else eventFrame:UnregisterEvent(event) end
    end
    if not on then loginSweep = false end
    UpdateAuraEvent()
    if on then
        RemoveGear()  -- what is on you already
        DBG("[ProfessionGear] on, instant=" .. tostring(RollAwayDB.hideProfessionGearInstant))
    end
end

function RA.InitProfessionGear()
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", OnEvent)
    RA.ApplyProfessionGearFeature()
end

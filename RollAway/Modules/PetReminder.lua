-- RollAway - PetReminder.lua
-- Hunter: text-only toast "Re-summon your pet." when entering a current dungeon or raid.
-- A pet that died has to be revived, dismissed and summoned again, or it is bugged; the bug
-- cannot be detected, so the toast shows on every entry (the pet's state is not checked).
--
-- Setting: RollAwayDB.hunterPetReminder (QoL page "Class", hunters only).
-- Once per instance visit (RollAwayDBChar.lastPetReminderInstID, cleared like the other
-- instance reminders). Called from the zone-change handler in Core/Core.lua.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local petFrame, petTimer  -- QoL toast, created on first show

function RA.ShowPetReminder()
    local db, char = RollAwayDB, RollAwayDBChar
    if not db or not char or not db.hunterPetReminder or not RA.IsHunter() then return end

    local itype, instanceID = RA.cachedInstanceType, RA.cachedInstanceID
    local current = (itype == "party" and RA.DUNGEON_MAP[instanceID])
        or (itype == "raid" and RA.REMINDER_RAID_MAP_IDS[instanceID])
    if not current then
        -- Left the instance: the next visit shows it again.
        if itype == "none" then char.lastPetReminderInstID = nil end
        return
    end
    if char.lastPetReminderInstID == instanceID then return end
    char.lastPetReminderInstID = instanceID
    DBG("[PetReminder] instanceID:", instanceID)

    if not petFrame then
        petFrame, petTimer = RA.CreateToastFrame("RollAwayPetReminderFrame", 280, 36, 220)
        RA.SetupInstanceReminderLifecycle(petFrame, "lastPetReminderInstID")
    end
    local fontPath, fontSize = RA.GetQoLFont()
    petFrame.text:SetFont(fontPath, fontSize, "OUTLINE")
    petFrame.text:SetText("|cffFFFFFF" .. RA_L["qol_pet_reminder_text"] .. "|r")
    petFrame:Show()
    petTimer.Start()
end

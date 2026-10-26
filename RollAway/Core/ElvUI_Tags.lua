-- RollAway - Core/ElvUI_Tags.lua
-- The [gilvl] tags for ElvUI's unit frames (item level of group members, Modules/GroupIlvl.lua):
--   [gilvl]          284     colored by the thresholds (switch in the QoL page "Group")
--   [gilvl:plain]    284     never colored
--   [gilvl:brackets] [284]   colored like [gilvl]
-- Use them in any ElvUI text field, e.g. Unit Frames > Party > Name: [name] [gilvl].
-- Silent no-op without ElvUI. The tags are always registered (ElvUI keeps text typed
-- into its fields), they just show nothing while the feature is off.

if not ElvUI then return end
local E = unpack(ElvUI)
if not E or not E.AddTag then return end

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local oUF  = E.oUF

-- The group in ElvUI's "Available Tags" list; the same in every language, all our tags go here.
-- ElvUI sorts the groups by name. The color code ("|") sorts after every letter, so the group
-- lands at the end of the list, next to other addons' groups, in our chat color.
local TAG_CATEGORY = "|cff66ccffRollAway|r"

-- Tag bodies run in oUF's environment, so they reach everything through upvalues.
-- GROUP_ROSTER_UPDATE is one of oUF's unitless events: it re-evaluates the tag when
-- the unit behind a frame changes. UNIT_NAME_UPDATE covers units that appear later.
local EVENTS = "UNIT_NAME_UPDATE GROUP_ROSTER_UPDATE"

local TAGS = {
    { "gilvl",          nil,        "gilvl_tag_default" },
    { "gilvl:plain",    "plain",    "gilvl_tag_plain" },
    { "gilvl:brackets", "brackets", "gilvl_tag_brackets" },
}

for _, tag in ipairs(TAGS) do
    local name, mode, descriptionKey = tag[1], tag[2], tag[3]
    E:AddTag(name, EVENTS, function(unit)
        return RA.FormatGroupIlvl(unit, mode)
    end)
    E:AddTagInfo(name, TAG_CATEGORY, RA_L[descriptionKey])
end

-- New levels arrive one at a time during an inspect sweep. Bursts are merged into a
-- single pass over ElvUI's frames on the next frame; only frames showing a changed
-- unit are re-evaluated, which is far cheaper than oUF.Tags:RefreshMethods.
local changed = {}
local scheduled = false

local function Flush()
    scheduled = false
    for _, frame in next, oUF.objects do
        local unit = frame.unit
        if unit and frame.UpdateTags and frame:IsVisible() then
            local guid = RA.SafeUnitGUID(unit)
            if guid and changed[guid] then frame:UpdateTags() end
        end
    end
    wipe(changed)
end

RA.OnGroupIlvlChanged(function(guid)
    changed[guid] = true
    if not scheduled then
        scheduled = true
        RunNextFrame(Flush)
    end
end)

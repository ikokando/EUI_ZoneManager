-------------------------------------------------------------------------------
--  Core/Context.lua -- zone-type detection, shared by every module.
-------------------------------------------------------------------------------
local _, ZM = ...

-- Mythic dungeons count as Mythic+ from the entrance on: an addon reload has to happen
-- before the key, and a graphics switch is best hidden in the loading screen too.
ZM.CONTEXTS = {
    { key = "world",        label = "Open World",
      desc = "Everywhere outside an instance, including cities and player housing." },
    { key = "dungeon",      label = "Dungeons",
      desc = "5-player dungeons on Normal, Heroic, Timewalking and Follower." },
    { key = "mythicplus",   label = "Mythic / Mythic+",
      desc = "Mythic dungeons, with or without a keystone. Switches when you enter the dungeon, so nothing happens once the timer runs." },
    { key = "raid",         label = "Raids",
      desc = "All raid difficulties, including LFR." },
    { key = "delve",        label = "Delves",
      desc = "Delves of every tier." },
    { key = "scenario",     label = "Scenarios",
      desc = "Scenarios and other small instanced content that is not a delve." },
    { key = "battleground", label = "Battlegrounds",
      desc = "Battlegrounds, rated and unrated, including epic battlegrounds." },
    { key = "arena",        label = "Arenas",
      desc = "Arenas and Solo Shuffle." },
}
ZM.CONTEXT_LABEL = {}
for _, c in ipairs(ZM.CONTEXTS) do ZM.CONTEXT_LABEL[c.key] = c.label end

local DIFFICULTY_KEYSTONE = 8
local DIFFICULTY_MYTHIC   = 23
local DIFFICULTY_DELVE    = 208

function ZM.RealContext()
    local inInstance = IsInInstance()
    if not inInstance then return "world" end
    local _, instanceType, difficultyID = GetInstanceInfo()
    if instanceType == "party" then
        if difficultyID == DIFFICULTY_MYTHIC or difficultyID == DIFFICULTY_KEYSTONE then return "mythicplus" end
        return "dungeon"
    elseif instanceType == "raid" then
        return "raid"
    elseif instanceType == "pvp" then
        return "battleground"
    elseif instanceType == "arena" then
        return "arena"
    elseif instanceType == "scenario" then
        if difficultyID == DIFFICULTY_DELVE then return "delve" end
        return "scenario"
    end
    return "world"   -- housing and anything new fall back to the open world
end

-- Simulation: pretend to be in another zone type (see Core/Events.lua).
ZM.simContext = nil

function ZM.GetContext()
    return ZM.simContext or ZM.RealContext()
end

-------------------------------------------------------------------------------
--  Group mode: the zone type a Group Finder activity stands for
-------------------------------------------------------------------------------
local issecretvalue = issecretvalue or function() return false end
local CATEGORY_DUNGEONS = GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2

function ZM.ActivityContext(activityID)
    if type(activityID) ~= "number" or issecretvalue(activityID) then return nil end
    local ai = C_LFGList.GetActivityInfoTable(activityID)
    if not ai then return nil end
    if ai.isPvpActivity or ai.isRatedPvpActivity then
        local n = ai.maxNumPlayers
        return (type(n) == "number" and n > 0 and n <= 5) and "arena" or "battleground"
    end
    if ai.categoryID == CATEGORY_DUNGEONS then
        if ai.isMythicPlusActivity or ai.isMythicActivity then return "mythicplus" end
        return "dungeon"
    end
    local cat = ai.categoryID and C_LFGList.GetLfgCategoryInfo and C_LFGList.GetLfgCategoryInfo(ai.categoryID)
    local cname = cat and type(cat.name) == "string" and not issecretvalue(cat.name) and cat.name or ""
    if _G.DELVES_LABEL and cname == _G.DELVES_LABEL then return "delve" end
    if ai.isCurrentRaidActivity or (_G.RAIDS and cname == _G.RAIDS)
       or (type(ai.maxNumPlayers) == "number" and ai.maxNumPlayers > 5) then
        return "raid"
    end
    return nil   -- questing, custom, ...: the zone decides
end

-- The zone type the addon set follows while group mode is on and you are in a group
-- whose content is known; nil otherwise (then the zone decides).
function ZM.GroupContext()
    local d = ZM.db
    if not (d and d.groupMode and d.groupCtx) or ZM.simContext then return nil end
    -- Right after a reload the roster may still be empty: keep the saved group type.
    if not IsInGroup() and not (ZM.Group and ZM.Group.settling) then return nil end
    return d.groupCtx
end

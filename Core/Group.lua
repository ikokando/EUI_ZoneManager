-------------------------------------------------------------------------------
--  Core/Group.lua -- group mode: the addon set follows the group's content.
--
--  Joining a Group Finder group (or listing one) tells us what it is for, e.g. a
--  Mythic+ key. The addon set of that zone type is asked for right away, while you
--  are still in town, and zone changes do not ask again while you stay in the
--  group. Leaving the group hands the choice back to the zone.
--
--  Sources: the group's own listing (C_LFGList.GetActiveEntryInfo, also visible to
--  members) and the listing you applied to when its invite is accepted (leaders
--  often delist a full group, so the listing alone is not enough).
--  Graphics profiles are not affected: they switch per zone, without a reload.
--
--  CPU: only group events, each costs a boolean check; nothing runs per frame.
--  All events are unregistered while group mode is off.
-------------------------------------------------------------------------------
local _, ZM = ...
local AD = ZM.Addons
local C = ZM.C
local issecretvalue = issecretvalue or function() return false end

local GR = {}
ZM.Group = GR

local frame = CreateFrame("Frame")
local wasInGroup = false
local pendingCtx          -- from an accepted invite, until the roster shows the group
-- After a login/reload the roster lags behind: the saved group type counts until the
-- delayed check has really looked (else the zone's set is asked for, then the group's
-- again after that reload, and so on).
GR.settling = false

local function FirstActivity(info)
    if type(info) ~= "table" then return nil end
    local ids = info.activityIDs
    if type(ids) == "table" and not issecretvalue(ids) then return ids[1] end
    return info.activityID
end

-- The group's own listing, if it still has one.
local function ListingContext()
    local entry = C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
    return entry and ZM.ActivityContext(FirstActivity(entry))
end

local function Announce(msg)
    if ZM.db.announce then ZM.Print(msg) end
end

-- Store the group's zone type and let the Addons module re-evaluate (it asks for a
-- reload only when the set really changes something).
local function SetGroupContext(ctx)
    if ctx == ZM.db.groupCtx then return end
    ZM.db.groupCtx = ctx
    if ctx then
        Announce("group mode: " .. C.WHITE .. (ZM.CONTEXT_LABEL[ctx] or ctx) .. "|r group, zone changes won't ask for a reload while you stay in it.")
    end
    if AD.IsEnabled() then ZM.Dispatch(true, ctx and "group" or "groupleft", AD) end
end

local function Check()
    local inGroup = IsInGroup()
    -- Not in the group yet right after a reload: wait for the delayed check.
    if GR.settling and not inGroup then return end
    if inGroup ~= wasInGroup then
        wasInGroup = inGroup
        if inGroup then
            local ctx = pendingCtx or ListingContext()
            pendingCtx = nil
            if ctx then SetGroupContext(ctx) end
        else
            pendingCtx = nil
            if ZM.db.groupCtx then
                Announce("group left: the zone decides the addon set again.")
                SetGroupContext(nil)
            end
        end
    elseif inGroup and not ZM.db.groupCtx then
        local ctx = ListingContext()   -- the listing can show up after the roster
        if ctx then SetGroupContext(ctx) end
    end
end

frame:SetScript("OnEvent", function(_, event, resultID, newStatus)
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        if newStatus == "inviteaccepted" and type(resultID) == "number" then
            local info = C_LFGList.GetSearchResultInfo(resultID)
            local ctx = ZM.ActivityContext(FirstActivity(info))
            if ctx then
                if IsInGroup() then SetGroupContext(ctx) else pendingCtx = ctx end
            end
        end
        return
    end
    Check()
end)

-- Register only while group mode is on; called at boot and from the toggle.
function GR.Update()
    local on = ZM.db and ZM.db.groupMode
    if on then
        frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        frame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
        -- A saved group type survives the reload it asked for. The roster can lag a
        -- moment behind login, so a stale one (group left while offline) is only
        -- dropped once a later check really finds no group.
        wasInGroup = IsInGroup() or ZM.db.groupCtx ~= nil
        if ZM.db.groupCtx then
            GR.settling = true
            C_Timer.After(5, function()
                GR.settling = false
                Check()
            end)
        end
    else
        frame:UnregisterAllEvents()
        pendingCtx = nil
        GR.settling = false
    end
end

function GR.SetEnabled(on)
    ZM.db.groupMode = on and true or false
    if on then
        GR.Update()
        local ctx = IsInGroup() and ListingContext()
        if ctx then SetGroupContext(ctx) end
    else
        GR.Update()
        if ZM.db.groupCtx then
            ZM.db.groupCtx = nil
            if AD.IsEnabled() then ZM.Dispatch(true, "groupleft", AD) end
        end
    end
    ZM.Refresh()
end

-- Status line for the Overview.
function GR.StatusText()
    if not ZM.db.groupMode then return C.DIM .. "off|r" end
    local ctx = ZM.GroupContext()
    if ctx then return C.ACCENT .. (ZM.CONTEXT_LABEL[ctx] or ctx) .. "|r group" end
    if IsInGroup() then return C.DIM .. "in a group without a known activity: the zone decides|r" end
    return C.DIM .. "not in a group: the zone decides|r"
end

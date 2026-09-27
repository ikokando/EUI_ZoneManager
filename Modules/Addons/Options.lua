-------------------------------------------------------------------------------
--  Modules/Addons/Options.lua -- the "Addon Sets" tab, plus a button in Blizzard's
--  addon list that opens it.
-------------------------------------------------------------------------------
local _, ZM = ...
local AD = ZM.Addons
local C = ZM.C

local function Edited() AD.OnSetEdited() end

-- Tooltip: the addon's own notes, then what the row covers.
local function GroupTip(g)
    local parts = {}
    if g.notes and g.notes ~= "" then parts[#parts + 1] = g.notes end
    if #g.members > 1 then
        parts[#parts + 1] = "Switches these " .. #g.members .. " addons together:\n" .. C.DIM .. table.concat(g.members, "\n") .. "|r"
            .. "\n\nModules that were off before stay off when you switch the row back on."
    else
        parts[#parts + 1] = C.DIM .. g.key .. "|r"
    end
    if C_AddOns.IsAddOnLoadOnDemand(g.parent or g.members[1]) then
        parts[#parts + 1] = C.DIM .. "Load on demand: the addon loads it itself when needed.|r"
    end
    return table.concat(parts, "\n\n")
end

local function BuildPage(parent, yOffset)
    local E = ZM.EUI()
    local W = E.Widgets
    local d = AD.DB()
    local y = yOffset
    local _, h
    if E.ClearContentHeader then E:ClearContentHeader() end

    _, h = W:SectionHeader(parent, "ADDON SET", y); y = y - h
    local sv, so = ZM.NameValues(AD.Names(), false)
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Edit Set", values = sv, order = so,
          tooltip = "The addon set the list below belongs to.",
          getValue = function() return d.editing end,
          setValue = function(v) d.editing = v; E:RefreshPage() end })
    y = y - h

    y = y - ZM.FeedbackRow(parent, y, function(left, right)
        local used = {}
        for _, c in ipairs(ZM.CONTEXTS) do
            if d.assign[c.key] == d.editing then used[#used + 1] = c.label end
        end
        left:SetText("Used in:  " .. (#used > 0 and table.concat(used, ", ")
            or (C.ORANGE .. "no zone type yet: assign it on the Overview tab|r")))
        if not d.enabled then
            right:SetText(C.DIM .. "Addons module off|r")
        elseif AD.current == d.editing and not ZM.simContext then
            local hold, n = AD.Hold(), AD.PendingCount()
            if hold then
                right:SetText(C.ORANGE .. "In use here, your own changes kept|r")
            elseif n > 0 then
                right:SetText(C.ORANGE .. "In use here: reload needed (" .. n .. ")|r")
            else
                right:SetText(C.GREEN .. "In use here, all loaded|r")
            end
        else
            right:SetText(C.DIM .. "Not in use right now|r")
        end
    end)

    -- Editing another set than the one in use changes nothing on screen until you
    -- enter one of its zone types: say so, and offer the way back.
    y = y - ZM.InfoRow(parent, y, function(left, right)
        local inUse = AD.current
        if not d.enabled or ZM.simContext or not inUse or inUse == d.editing then
            left:SetText(C.DIM .. "Changes to the set in use apply right away (after a reload).|r")
        else
            left:SetText(C.ORANGE .. "Not the set of this zone.|r This zone uses " .. C.WHITE .. inUse
                .. "|r: changes here apply when you enter a zone type that uses " .. C.WHITE .. tostring(d.editing) .. "|r.")
        end
        right:SetText("")
    end)

    _, h = W:WideDualButton(parent, "Edit Set In Use", "Reload Now", y, function()
        if AD.current and d.sets[AD.current] then
            d.editing = AD.current
            ZM.Rebuild()
        else
            ZM.SetFeedback(C.DIM .. "No addon set in use in this zone.|r")
            ZM.Refresh()
        end
    end, function()
        if AD.PendingCount() > 0 then
            AD.ReloadNow()
        else
            ZM.SetFeedback("Nothing to reload: all addons of the set in use are loaded.")
            ZM.Refresh()
        end
    end)
    y = y - h

    _, h = W:WideDualButton(parent, "New Set", "Duplicate", y, function()
        ZM.AskName("New Addon Set", "Starts with the addons that are enabled right now.", "Set name",
            function(text) return AD.Create(text) end)
    end, function()
        ZM.AskName("Duplicate Addon Set", "Copy of \"" .. tostring(d.editing) .. "\".", "Set name",
            function(text) return AD.Create(text, d.editing) end)
    end)
    y = y - h

    _, h = W:WideDualButton(parent, "Rename", "Delete", y, function()
        ZM.AskName("Rename Addon Set", "New name for \"" .. tostring(d.editing) .. "\".", "Set name",
            function(text) return AD.Rename(d.editing, text) end)
    end, function()
        local name = d.editing
        ZM.Confirm("Delete Addon Set", "Delete \"" .. tostring(name) .. "\"?\nZone types using it will be set to \"Don't change\".",
            "Delete", function()
                local ok, err = AD.Delete(name)
                if ok then ZM.SetFeedback("Deleted \"" .. tostring(name) .. "\".") else ZM.Popup("Delete Addon Set", err) end
                ZM.Rebuild()
            end)
    end)
    y = y - h

    _, h = W:SectionHeader(parent, "ADDONS IN THIS SET", y); y = y - h
    _, h = W:WideTripleButton(parent, "Enable All", "Disable All", "Copy Current State", y,
        function()
            local s = AD.Editing(); if not s then return end
            AD.SetAll(s, true); Edited(); ZM.SetFeedback("All addons on."); E:RefreshPage()
        end,
        function()
            local s = AD.Editing(); if not s then return end
            AD.SetAll(s, false); Edited(); ZM.SetFeedback("All addons off."); E:RefreshPage()
        end,
        function()
            local s = AD.Editing(); if not s then return end
            AD.CopyCurrent(s); Edited(); ZM.SetFeedback("Copied the currently enabled addons."); E:RefreshPage()
        end)
    y = y - h

    local cfgs = {}
    for _, g in ipairs(AD.Groups()) do
        local count = #g.members > 1 and (C.DIM .. "  (" .. #g.members .. ")|r") or ""
        cfgs[#cfgs + 1] = {
            type = "toggle", text = g.title .. count,
            tooltip = GroupTip(g), tooltipOpts = ZM.TIP_OPTS,
            getValue = function()
                local s = AD.Editing()
                return s and AD.GroupOn(s, g) or false
            end,
            setValue = function(v)
                local s = AD.Editing(); if not s then return end
                AD.SetGroup(s, g, v)
                Edited()
                E:RefreshPage()
            end,
        }
    end
    y = ZM.DualRows(W, parent, y, cfgs)

    y = y - ZM.InfoRow(parent, y, function(left, right)
        left:SetText(C.DIM .. AD.LOCKED_NOTE .. "|r")
        right:SetText("")
    end)

    return math.abs(y)
end

ZM.AddPage("Addon Sets", BuildPage)

-------------------------------------------------------------------------------
--  Button in Blizzard's addon list
-------------------------------------------------------------------------------
-- Sits in the free space between "Disable All" and "Okay". The list stays open underneath
-- (EllesmereUI draws above it), so unsaved ticks in it are not thrown away.
local function AttachAddonListButton()
    local list = _G.AddonList
    if not list or list.EUIZoneManagerButton then return end
    local btn = CreateFrame("Button", nil, list, "SharedButtonSmallTemplate")
    btn:SetSize(140, 22)
    if list.DisableAllButton then
        btn:SetPoint("TOPLEFT", list.DisableAllButton, "TOPRIGHT", 12, 0)
    else
        btn:SetPoint("BOTTOM", list, "BOTTOM", 0, 4)
    end
    btn:SetText(ZM.TITLE)
    btn:SetScript("OnClick", function()
        local d = AD.DB()
        if d and AD.current and d.sets[AD.current] then d.editing = AD.current end
        if not ZM.OpenOptions("Addon Sets") then ZM.Print("EllesmereUI options are not available.") end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ZM.TITLE, 1, 1, 1)
        if AD.IsEnabled() and AD.current then
            GameTooltip:AddLine("This zone uses addon set " .. C.WHITE .. AD.current .. "|r.", nil, nil, nil, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Changes you make in this list are noticed after the reload: you can keep them until the zone type changes, save them into the set, or undo them.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Addon sets per zone type, in the EllesmereUI options.", nil, nil, nil, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: edit the set in use", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    list.EUIZoneManagerButton = btn
end

-- Blizzard_AddOnList loads before us in practice; the event covers a client that loads it later.
function AD.HookAddonList()
    if _G.AddonList then
        AttachAddonListButton()
        return
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name == "Blizzard_AddOnList" then
            self:UnregisterEvent("ADDON_LOADED")
            AttachAddonListButton()
        end
    end)
end

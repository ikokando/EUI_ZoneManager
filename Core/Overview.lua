-------------------------------------------------------------------------------
--  Core/Overview.lua -- the "Overview" tab: modules on/off, status, simulation,
--  one assignment table for both modules, recent switches.
-------------------------------------------------------------------------------
local _, ZM = ...
local GX, AD = ZM.Graphics, ZM.Addons
local C = ZM.C
local NONE = ZM.NONE
local SIM_OFF = "__real"
local HISTORY_ROWS = 6

-- "Unload: A, B   Load: C" for a set, or nil when a reload would change nothing.
local function DiffText(set, max)
    local off, on = AD.Diff(set)
    if #off + #on == 0 then return nil, 0 end
    local parts = {}
    if #off > 0 then parts[#parts + 1] = C.RED .. "Unload:|r " .. AD.GroupTitles(off, max) end
    if #on > 0 then parts[#parts + 1] = C.GREEN .. "Load:|r " .. AD.GroupTitles(on, max) end
    return table.concat(parts, "   "), #off + #on
end

local function NameOrNone(name)
    return name and (C.ACCENT .. name .. "|r") or (C.DIM .. "Don't change|r")
end

-- Fixed-height list of the last switches.
local function HistoryBlock(parent, y)
    local E = ZM.EUI()
    local LINE, PADV = 26, 12
    local H = HISTORY_ROWS * LINE + PADV * 2
    if E._prebuilding or not (E.MakeFont and E.RowBg) then return H end
    local pad = E.CONTENT_PAD or 45
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(parent:GetWidth() - pad * 2, H)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
    E.RowBg(f, parent)

    local lefts, rights = {}, {}
    for i = 1, HISTORY_ROWS do
        local ly = -PADV - (i - 1) * LINE - LINE / 2
        local r = E.MakeFont(f, 13, nil, 1, 1, 1, 1)
        r:SetPoint("RIGHT", f, "TOPRIGHT", -20, ly)
        r:SetJustifyH("RIGHT")
        local l = E.MakeFont(f, 13, nil, 1, 1, 1, 1)
        l:SetPoint("LEFT", f, "TOPLEFT", 20, ly)
        l:SetJustifyH("LEFT")
        lefts[i], rights[i] = l, r
    end

    local function U()
        for i = 1, HISTORY_ROWS do
            local e = ZM.history[i]
            if e then
                local sim = e.sim and (C.ORANGE .. " [sim]|r") or ""
                local parts = {}
                if e.graphics ~= nil then parts[#parts + 1] = "Graphics " .. NameOrNone(e.graphics or nil) end
                if e.addons ~= nil then parts[#parts + 1] = "Addons " .. NameOrNone(e.addons or nil) end
                lefts[i]:SetText(C.DIM .. e.t .. "|r   " .. (ZM.CONTEXT_LABEL[e.ctx] or e.ctx) .. sim
                    .. (#parts > 0 and ("   " .. table.concat(parts, "   ")) or ""))
                local res = {}
                if e.graphicsChanged and e.graphicsChanged > 0 then res[#res + 1] = e.graphicsChanged .. " gfx" end
                if e.addonsPending and e.addonsPending > 0 then res[#res + 1] = C.ORANGE .. "reload: " .. e.addonsPending .. "|r" end
                rights[i]:SetText((#res > 0 and (table.concat(res, "  ") .. "  ") or "") .. C.DIM .. e.why .. "|r")
            elseif i == 1 then
                lefts[i]:SetText(C.DIM .. "No switches yet this session.|r")
                rights[i]:SetText("")
            else
                lefts[i]:SetText("")
                rights[i]:SetText("")
            end
        end
    end
    U()
    if E.RegisterWidgetRefresh then E.RegisterWidgetRefresh(U) end
    return H
end

local function BuildPage(parent, yOffset)
    local E = ZM.EUI()
    local W = E.Widgets
    local gdb, adb = GX.DB(), AD.DB()
    local y = yOffset
    local _, h
    if E.ClearContentHeader then E:ClearContentHeader() end

    -- Modules
    _, h = W:SectionHeader(parent, "MODULES", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Graphics",
          tooltip = "Loads the assigned graphics profile whenever you enter a different zone type.\n\nWhile on, Blizzard's separate \"Raid and Battleground\" graphics tab is switched off: the profiles replace it. Switching the module off restores your previous choice.",
          getValue = function() return GX.IsEnabled() end,
          setValue = function(v) ZM.SetModuleEnabled(GX, v) end },
        { type = "toggle", text = "Addons",
          tooltip = "Switches to the assigned addon set whenever you enter a different zone type.\n\nWoW can only load or unload addons with a UI reload, and only you can start one: you get a \"Reload now?\" prompt whenever the set really changes something. Never during combat.\n\nSwitching the module off leaves every addon as it is.",
          getValue = function() return AD.IsEnabled() end,
          setValue = function(v) ZM.SetModuleEnabled(AD, v) end })
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Chat Message on Switch",
          tooltip = "One chat line when a zone change loads a graphics profile or needs a reload for the addon set.",
          getValue = function() return ZM.db.announce end,
          setValue = function(v) ZM.db.announce = v and true or false end },
        { type = "toggle", text = "Addon Set by Group Content",
          tooltip = "Group mode. When you join a Group Finder group (or list one), Zone Manager reads what the group is for, e.g. a Mythic+ key, a raid or an arena, and uses the addon set of that zone type right away: you get the reload prompt while you are still in town, not at the instance entrance.\n\n"
              .. "While you stay in that group, zone changes do not ask for a reload again, e.g. between two keys or when you port back to town.\n\n"
              .. "Leaving the group hands the choice back to the zone.\n\n"
              .. C.DIM .. "Only groups with a Group Finder activity are recognized; in other groups the zone decides as usual. Graphics profiles still follow the zone, they need no reload. A simulation overrides group mode.|r",
          tooltipOpts = ZM.TIP_OPTS,
          disabled = function() return not AD.IsEnabled() end,
          disabledTooltip = "The Addons module is off.",
          getValue = function() return ZM.db.groupMode end,
          setValue = function(v) ZM.Group.SetEnabled(v) end })
    y = y - h

    -- Status
    _, h = W:SectionHeader(parent, "STATUS", y); y = y - h
    y = y - ZM.InfoRow(parent, y, function(left, right)
        local ctx = ZM.GetContext()
        left:SetText("Zone type:  " .. C.ACCENT .. (ZM.CONTEXT_LABEL[ctx] or ctx) .. "|r"
            .. (ZM.simContext and (C.ORANGE .. "  [simulated]|r") or ""))
        right:SetText(ZM.simContext and (C.DIM .. "ends with the next loading screen|r") or "")
    end)
    y = y - ZM.InfoRow(parent, y, function(left, right)
        if not GX.IsEnabled() then
            left:SetText("Graphics:  " .. C.DIM .. "module off|r")
            right:SetText("")
            return
        end
        local name = GX.ProfileFor(ZM.GetContext())
        left:SetText("Graphics:  " .. NameOrNone(name) .. (GX.previewProfile and (C.ORANGE .. "  [preview]|r") or ""))
        right:SetText(name and (C.GREEN .. "on screen|r") or "")
    end)
    y = y - ZM.InfoRow(parent, y, function(left, right)
        if not AD.IsEnabled() then
            left:SetText("Addons:  " .. C.DIM .. "module off|r")
            right:SetText("")
            return
        end
        local actx = AD.ContextFor(ZM.GetContext())
        local name = AD.SetFor(actx)
        local via = ZM.GroupContext() and (C.DIM .. "  (group: " .. (ZM.CONTEXT_LABEL[actx] or actx) .. ")|r") or ""
        local hold = AD.Hold()
        if name and hold and hold.set == name and hold.ctx == actx then
            left:SetText("Addons:  " .. NameOrNone(name) .. via)
            right:SetText(C.ORANGE .. "your own changes kept until the zone type changes|r")
            return
        end
        local diff, n = DiffText(name and adb.sets[name], 3)
        left:SetText("Addons:  " .. NameOrNone(name) .. via .. (diff and ("     " .. diff) or ""))
        if not name then
            right:SetText("")
        elseif n > 0 then
            right:SetText(C.ORANGE .. (ZM.simContext and "would change " or "reload needed: ") .. n .. "|r")
        else
            right:SetText(C.GREEN .. "all match|r")
        end
    end)
    y = y - ZM.InfoRow(parent, y, function(left, right)
        left:SetText("Group mode:  " .. ZM.Group.StatusText())
        right:SetText("")
    end)

    -- Simulation + the one Apply button, right under what they affect.
    local simValues, simOrder = { _noLoc = true, [SIM_OFF] = "Off (real zone)" }, { SIM_OFF }
    for _, c in ipairs(ZM.CONTEXTS) do
        simValues[c.key] = c.label
        simOrder[#simOrder + 1] = c.key
    end
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Simulate Zone Type", values = simValues, order = simOrder,
          tooltip = "Pretend to be in another zone type without going there.\n\nGraphics: its profile goes on screen right away.\nAddons: the line above shows what its set would load or unload; nothing changes until you click Apply Now, which then asks for the reload.\n\nThe simulation survives that reload and ends with the next loading screen, or pick \"Off\".",
          getValue = function() return ZM.simContext or SIM_OFF end,
          setValue = function(v) ZM.SetSim(v ~= SIM_OFF and v or nil) end })
    y = y - h

    y = y - ZM.FeedbackRow(parent, y, function(left, right)
        if ZM.simContext then
            left:SetText(C.ORANGE .. "Simulation:|r graphics are live, addons are a preview until you click Apply Now.")
        else
            local e = ZM.history[1]
            left:SetText(e and (C.DIM .. "Last switch " .. e.t .. " (" .. e.why .. ")|r")
                or (C.DIM .. "Nothing applied yet this session.|r"))
        end
        right:SetText("")
    end)
    _, h = W:WideButton(parent, "Apply Now", y, function() ZM.ApplyNow("manual") end, 300)
    y = y - h

    -- One assignment table for both modules
    _, h = W:SectionHeader(parent, "ZONE TYPES", y); y = y - h
    y = y - ZM.InfoRow(parent, y, function(left, right)
        left:SetText(C.DIM .. "Graphics profile|r")
        right:SetText(C.DIM .. "Addon set|r")
    end)
    local gv, go = ZM.NameValues(GX.Names(), true)
    local av, ao = ZM.NameValues(AD.Names(), true)
    for _, c in ipairs(ZM.CONTEXTS) do
        local key = c.key
        local function Changed()
            if ZM.GetContext() == key then ZM.ApplyNow("manual") else E:RefreshPage() end
        end
        _, h = W:DualRow(parent, y,
            { type = "dropdown", text = c.label, values = gv, order = go, tooltip = c.desc,
              disabled = function() return not GX.IsEnabled() end,
              disabledTooltip = "The Graphics module is off.",
              getValue = function() return gdb.assign[key] or NONE end,
              setValue = function(v) gdb.assign[key] = v; Changed() end },
            { type = "dropdown", text = c.label, values = av, order = ao, tooltip = c.desc,
              disabled = function() return not AD.IsEnabled() end,
              disabledTooltip = "The Addons module is off.",
              getValue = function() return adb.assign[key] or NONE end,
              setValue = function(v) adb.assign[key] = v; Changed() end })
        y = y - h
    end

    _, h = W:SectionHeader(parent, "RECENT SWITCHES", y); y = y - h
    y = y - HistoryBlock(parent, y)

    return math.abs(y)
end

ZM.AddPage("Overview", BuildPage, 1)

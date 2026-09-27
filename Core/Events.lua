-------------------------------------------------------------------------------
--  Core/Events.lua -- the one event frame, the dispatcher to the modules,
--  simulation, Apply Now, slash command and boot.
--
--  CPU: nothing runs per frame and there is no ticker. A loading screen or a zone
--  change costs one instance lookup; the modules only work when the zone TYPE changes.
-------------------------------------------------------------------------------
local _, ZM = ...
local GX, AD = ZM.Graphics, ZM.Addons
local C = ZM.C

ZM.current = { context = nil }
ZM.history = {}
local HISTORY_MAX = 6

local REASON_LABEL = {
    PLAYER_ENTERING_WORLD = "loading screen", ZONE_CHANGED_NEW_AREA = "zone change",
    PLAYER_REGEN_ENABLED = "after combat", manual = "apply", sim = "simulation",
    simoff = "simulation off", preview = "preview", enable = "module on", slash = "/zm apply",
    group = "group joined", groupleft = "group left",
}
local AUTOMATIC = { PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true, PLAYER_REGEN_ENABLED = true,
                    group = true, groupleft = true }

-- Automatic switches get the chat line; the user's own actions answer in the options.
function ZM.IsAutomatic(reason) return AUTOMATIC[reason] == true end

local frame = CreateFrame("Frame")
local pendingCombat = false

-- Tell the enabled modules (or just `only`) about the current zone type. Returns the
-- history entry, or nil when nothing ran (no module on / same zone type / combat).
function ZM.Dispatch(force, reason, only)
    if not ZM.db or not (GX.IsEnabled() or AD.IsEnabled()) then return end
    local ctx = ZM.GetContext()
    if not force and ctx == ZM.current.context then return end

    -- Neither a render-settings reload nor a reload prompt belongs in a fight.
    if InCombatLockdown() then
        if not pendingCombat then
            pendingCombat = true
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end

    ZM.current.context = ctx
    local entry = { t = date("%H:%M:%S"), ctx = ctx, why = REASON_LABEL[reason] or tostring(reason),
                    sim = ZM.simContext ~= nil }
    ZM.ForEachModule(function(mod)
        if mod.IsEnabled() and (not only or only == mod) then
            -- One module failing must not stop the other; BugSack still gets the error.
            local ok, err = pcall(mod.OnContext, ctx, reason, force, entry)
            if not ok then geterrorhandler()(err) end
        end
    end)

    table.insert(ZM.history, 1, entry)
    if #ZM.history > HISTORY_MAX then ZM.history[#ZM.history] = nil end

    if ZM.DebugOn() then
        local iName, iType, diff, diffName = GetInstanceInfo()
        ZM.DebugLog({ event = reason, ctx = ctx, sim = ZM.simContext,
            instance = ("%s | type=%s | difficulty=%s (%s)"):format(tostring(iName), tostring(iType), tostring(diff), tostring(diffName)),
            graphics = entry.graphics, graphicsChanged = entry.graphicsChanged,
            addons = entry.addons, addonsPending = entry.addonsPending })
        ZM.Print(("[debug] %s -> graphics %s (%s), addons %s (%s) [%s]"):format(ctx,
            tostring(entry.graphics), tostring(entry.graphicsChanged), tostring(entry.addons),
            tostring(entry.addonsPending), tostring(reason)))
    end

    ZM.Refresh()
    return entry
end

-- Buttons and settings: always answer in the feedback line.
function ZM.ApplyNow(reason, only)
    if not (GX.IsEnabled() or AD.IsEnabled()) then
        ZM.SetFeedback(C.RED .. "Both modules are off.|r")
        ZM.Refresh()
        return
    end
    if InCombatLockdown() then
        ZM.SetFeedback(C.ORANGE .. "In combat: applies when combat ends.|r")
    end
    local e = ZM.Dispatch(true, reason or "manual", only)
    if e then
        local parts = {}
        if e.graphics ~= nil then
            parts[#parts + 1] = e.graphics
                and ("Graphics " .. C.WHITE .. e.graphics .. "|r: " .. GX.ChangedText(e.graphicsChanged or 0))
                or "Graphics: don't change"
        end
        if e.addons ~= nil then
            local n = e.addonsPending or 0
            if not e.addons then
                parts[#parts + 1] = "Addons: don't change"
            elseif n == 0 then
                parts[#parts + 1] = "Addons " .. C.WHITE .. e.addons .. "|r: all match"
            elseif ZM.simContext and reason ~= "manual" then
                parts[#parts + 1] = "Addons " .. C.WHITE .. e.addons .. "|r: preview, " .. n .. " would change"
            else
                parts[#parts + 1] = "Addons " .. C.WHITE .. e.addons .. "|r: reload needed"
            end
        end
        ZM.SetFeedback(table.concat(parts, "     "))
    end
    ZM.Refresh()
end

-- Simulation: saved, so it survives the /reload an addon set asks for; a real loading
-- screen ends it. Off returns to the real zone type.
function ZM.SetSim(ctx)
    ZM.simContext = ctx
    ZM.db.sim = ctx
    ZM.ApplyNow(ctx and "sim" or "simoff")
end

function ZM.SetModuleEnabled(mod, on)
    mod.SetEnabled(on)
    ZM.current.context = nil
    if on then
        ZM.ApplyNow("enable", mod)
    else
        ZM.SetFeedback(mod.label .. " module off. " .. (mod == GX and "Graphics" or "Addons") .. " stay as they are.")
        ZM.Refresh()
    end
end

-- EllesmereUI's "Reset ALL EUI Addon Settings".
function ZM.ResetAll()
    ZM.simContext, ZM.db.sim = nil, nil
    ZM.ForEachModule(function(mod) mod.Reset() end)
    ZM.current.context = nil
    ZM.Dispatch(true, "manual")
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local function Boot()
    local db = ZM.InitDB()
    ZM.ForEachModule(function(mod) mod.Init(db[mod.dbKey]) end)
    -- A simulation carries over a /reload; PLAYER_ENTERING_WORLD decides whether it ends.
    if db.sim and ZM.CONTEXT_LABEL[db.sim] then ZM.simContext = db.sim else db.sim = nil end
    ZM.RegisterWithEUI()
    AD.HookAddonList()
    ZM.Group.Update()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        Boot()
        return   -- PLAYER_ENTERING_WORLD follows and does the first switch
    end

    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        pendingCombat = false
        ZM.Dispatch(true, event)
        return
    end

    local force = false
    if event == "PLAYER_ENTERING_WORLD" and (isInitialLogin or not isReloadingUi) then
        -- A real loading screen (not a /reload) ends every test state.
        if ZM.simContext then
            ZM.simContext, ZM.db.sim = nil, nil
            ZM.Print("simulation ended (loading screen).")
            force = true
        end
        ZM.ForEachModule(function(mod)
            if mod.OnLoadingScreen then mod.OnLoadingScreen() end
        end)
    end
    ZM.Dispatch(force, event)
end)

-------------------------------------------------------------------------------
--  Slash command
-------------------------------------------------------------------------------
SLASH_EUIZONEMANAGER1 = "/zm"
SLASH_EUIZONEMANAGER2 = "/zonemanager"
SlashCmdList.EUIZONEMANAGER = function(msg)
    if not ZM.db then return end
    msg = strtrim((msg or ""):lower())
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    if cmd == "apply" then
        ZM.ApplyNow("slash")
        ZM.Print(ZM.RecentFeedback() or "done.")
    elseif cmd == "status" then
        local ctx = ZM.GetContext()
        ZM.Print(("zone type: %s%s | graphics: %s | addons: %s | group mode: %s"):format(
            ZM.CONTEXT_LABEL[ctx] or ctx, ZM.simContext and " (simulated)" or "",
            GX.IsEnabled() and tostring(GX.ProfileFor(ctx) or "don't change") or "off",
            AD.IsEnabled() and tostring(AD.SetFor(AD.ContextFor(ctx)) or "don't change") or "off",
            ZM.Group.StatusText()))
    elseif cmd == "sim" then
        if arg == "" or arg == "off" then
            ZM.SetSim(nil)
            ZM.Print("simulation off.")
        elseif ZM.CONTEXT_LABEL[arg] then
            ZM.SetSim(arg)
            ZM.Print("simulating " .. ZM.CONTEXT_LABEL[arg] .. " (/zm sim off to stop).")
        else
            local keys = {}
            for _, c in ipairs(ZM.CONTEXTS) do keys[#keys + 1] = c.key end
            ZM.Print("zone types: " .. table.concat(keys, ", "))
        end
    elseif cmd == "debug" then
        ZM.SetDebug(not ZM.DebugOn())
        ZM.Print("debug log " .. (ZM.DebugOn() and (C.GREEN .. "on|r (saved on /reload or logout)") or (C.RED .. "off|r (log cleared)")))
    else
        if ZM.OpenOptions() then return end
        ZM.Print("/zm status, /zm apply, /zm sim <type|off>, /zm debug")
    end
end

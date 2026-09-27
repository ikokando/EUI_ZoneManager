-------------------------------------------------------------------------------
--  Modules/Addons/Addons.lua -- addon sets: storage, enable flags, reload prompt.
--
--  WoW only loads or unloads addons with a UI reload, and only a click may start
--  one. So a switch writes the enable flags (per character) straight away and asks.
-------------------------------------------------------------------------------
local _, ZM = ...
local NONE = ZM.NONE
local C = ZM.C

local AD = { key = "addons", label = "Addons", dbKey = "addons" }
ZM.Addons = AD

--  db (EUIZoneManagerDB.addons) = {
--      enabled,
--      sets    = { [name] = { state = { [addon] = bool }, memo = { [group] = { [addon] = bool } } } },
--      assign  = { [contextKey] = setName | NONE },
--      editing = setName,
--      written = { [charGUID] = { [addon] = bool } },   -- flags as Zone Manager last left them
--      hold    = { [charGUID] = { ctx =, set = } },     -- "keep for now": no writes while ctx/set stay
--  }
local db

AD.current = nil   -- set of the current zone type

-- Never managed: the menu lives in these, and Zone Manager itself must stay loaded.
local LOCKED_ADDONS = { EllesmereUI = true, EllesmereUIOptions = true, EllesmereUILocales = true }
LOCKED_ADDONS[ZM.NAME] = true
local LOCKED_GROUPS = { EllesmereUI = true }
AD.LOCKED_NOTE = "EllesmereUI and Zone Manager are always loaded and not listed."

-------------------------------------------------------------------------------
--  Installed addons, grouped the way Blizzard's addon list groups them
-------------------------------------------------------------------------------
local function StripColor(s)
    return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
AD.StripColor = StripColor

-- The installed set cannot change during a session: built once, on demand.
local _groups, _groupOf, _manageable, _byKey
function AD.Groups()
    if _groups then return _groups end
    local order = {}
    _groupOf, _manageable, _byKey = {}, {}, {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, title, notes = C_AddOns.GetAddOnInfo(i)
        local group = C_AddOns.GetAddOnMetadata(i, "Group")
        if not group or group == "" then group = name end
        if name and not name:find("^Blizzard_") and not LOCKED_ADDONS[name] and not LOCKED_GROUPS[group] then
            local g = _byKey[group]
            if not g then
                g = { key = group, members = {} }
                _byKey[group] = g
                order[#order + 1] = g
            end
            g.members[#g.members + 1] = name
            if name == group then g.parent, g.title, g.notes = name, title, notes end
            _groupOf[name] = group
            _manageable[name] = true
        end
    end
    for _, g in ipairs(order) do
        if not g.title then   -- children whose parent is not installed
            local _, t, n = C_AddOns.GetAddOnInfo(g.members[1])
            g.title, g.notes = t or g.key, n
        end
        g.sortTitle = StripColor(g.title):lower()
        table.sort(g.members, function(a, b)
            if a == g.parent then return true elseif b == g.parent then return false end
            return a:lower() < b:lower()
        end)
    end
    table.sort(order, function(a, b) return a.sortTitle < b.sortTitle end)
    _groups = order
    return order
end

local function IsManageable(name)
    AD.Groups()
    return _manageable[name] == true
end

function AD.GroupTitles(keys, max)
    AD.Groups()
    local out = {}
    for i, k in ipairs(keys) do
        if max and i > max then
            out[#out + 1] = ("+%d more"):format(#keys - max)
            break
        end
        out[#out + 1] = StripColor(_byKey[k] and _byKey[k].title or k)
    end
    return table.concat(out, ", ")
end

-------------------------------------------------------------------------------
--  Enable flags and loaded state
-------------------------------------------------------------------------------
-- Per character: a set only changes the character that is playing.
local function CharKey() return UnitGUID("player") end

function AD.IsEnabledFlag(name)
    return (C_AddOns.GetAddOnEnableState(name, CharKey()) or 0) > 0
end

-- Would the loaded state change on the next reload for this wish?
local function WouldChange(name, want)
    local loaded = C_AddOns.IsAddOnLoaded(name)
    if not want then return loaded end
    if loaded or C_AddOns.IsAddOnLoadOnDemand(name) then return false end
    local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo(name)
    -- Missing dependency, out of date, ...: a reload would not load it either.
    if not loadable and reason ~= "DISABLED" then return false end
    return true
end

-- What a reload would do for this set: group keys to unload / load.
function AD.Diff(set)
    local off, on, seenOff, seenOn = {}, {}, {}, {}
    if type(set) ~= "table" then return off, on end
    AD.Groups()
    for name, want in pairs(set.state) do
        if _manageable[name] and WouldChange(name, want) then
            local g = _groupOf[name]
            if want then
                if not seenOn[g] then seenOn[g] = true; on[#on + 1] = g end
            elseif not seenOff[g] then
                seenOff[g] = true; off[#off + 1] = g
            end
        end
    end
    return off, on
end

-- Are the set's addons already loaded as the set wants them? Then a reload changes
-- nothing and there is nothing to ask.
function AD.IsSetLoaded(set)
    local off, on = AD.Diff(set)
    return #off + #on == 0
end

-- Character first (what Blizzard's own list does in game), then by name, then for all
-- characters as a last resort. Every write is read back.
local function SetFlag(name, want)
    local fn = want and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn
    fn(name, CharKey())
    if AD.IsEnabledFlag(name) == want then return "guid" end
    fn(name, UnitName("player"))
    if AD.IsEnabledFlag(name) == want then return "name" end
    fn(name)
    if AD.IsEnabledFlag(name) == want then return "all" end
    return "FAILED"
end

local function WriteFlags(set)
    local n, writes = 0, ZM.DebugOn() and {} or nil
    for name, want in pairs(set.state) do
        if IsManageable(name) and AD.IsEnabledFlag(name) ~= want then
            local how = SetFlag(name, want)
            if how == "FAILED" then ZM.Print(C.RED .. "could not change|r " .. name) end
            if writes then writes[#writes + 1] = ("%s %s (%s)"):format(name, want and "on" or "off", how) end
            n = n + 1
        end
    end
    if n > 0 then C_AddOns.SaveAddOns() end
    if writes and #writes > 0 then ZM.DebugLog({ module = "addons", writes = writes }) end
    return n
end

-------------------------------------------------------------------------------
--  Manual changes (Blizzard's addon list, other addon managers)
--
--  Zone Manager remembers, per character, the flags it last left. A difference
--  at the next switch means someone else changed them; that is asked about
--  instead of silently overwritten.
-------------------------------------------------------------------------------
local function WrittenDB()
    if type(db.written) ~= "table" then db.written = {} end
    return db.written
end

local function RememberFlags()
    WrittenDB()[CharKey()] = AD.SnapshotState()
end

function AD.ForgetFlags()
    WrittenDB()[CharKey()] = nil
end

-- { [addon] = nowEnabled } for every flag that differs from the remembered one, or nil.
local function Drift()
    local last = WrittenDB()[CharKey()]
    if type(last) ~= "table" then return nil end
    local out, n = {}, 0
    for name, was in pairs(last) do
        if IsManageable(name) then
            local now = AD.IsEnabledFlag(name)
            if now ~= was then out[name] = now; n = n + 1 end
        end
    end
    return n > 0 and out or nil
end

function AD.Hold()
    local h = type(db.hold) == "table" and db.hold[CharKey()]
    return type(h) == "table" and h or nil
end

local function SetHold(ctx, setName)
    if type(db.hold) ~= "table" then db.hold = {} end
    db.hold[CharKey()] = ctx and { ctx = ctx, set = setName } or nil
end

-- Group keys switched off / on by a drift table.
local function DriftGroups(drift)
    AD.Groups()
    local off, on, seen = {}, {}, {}
    for name, now in pairs(drift) do
        local g = _groupOf[name]
        if g and not seen[g] then
            seen[g] = true
            if now then on[#on + 1] = g else off[#off + 1] = g end
        end
    end
    return off, on
end

-------------------------------------------------------------------------------
--  Sets
-------------------------------------------------------------------------------
function AD.SnapshotState()
    local state = {}
    for _, g in ipairs(AD.Groups()) do
        for _, name in ipairs(g.members) do state[name] = AD.IsEnabledFlag(name) end
    end
    return state
end

local function NewSet() return { state = AD.SnapshotState(), memo = {} } end

local function Seed()
    db.sets, db.assign = { ["Default"] = NewSet() }, {}
    for _, c in ipairs(ZM.CONTEXTS) do db.assign[c.key] = "Default" end
    db.editing = "Default"
end

function AD.Names() return ZM.SortedKeys(db and db.sets) end
function AD.DB() return db end
function AD.Editing() return db and db.editing and db.sets[db.editing] end

-- Addons installed after a set was made start out as they are right now.
function AD.WantFor(set, name)
    local v = set.state[name]
    if v == nil then return AD.IsEnabledFlag(name) end
    return v
end

-- A group row is "on" when its parent (or, without one, any member) loads in the set.
function AD.GroupOn(set, g)
    if g.parent then return AD.WantFor(set, g.parent) end
    for _, name in ipairs(g.members) do
        if AD.WantFor(set, name) then return true end
    end
    return false
end

-- Off remembers the members' own states and on restores them, so a partly enabled group
-- (e.g. only some RaiderIO databases) survives an off/on round trip.
function AD.SetGroup(set, g, on)
    if on then
        local memo = set.memo[g.key]
        for _, name in ipairs(g.members) do
            local v = true
            if memo and memo[name] ~= nil then v = memo[name] end
            set.state[name] = v
        end
        if g.parent then set.state[g.parent] = true end
        set.memo[g.key] = nil
    else
        local memo = {}
        for _, name in ipairs(g.members) do
            memo[name] = AD.WantFor(set, name)
            set.state[name] = false
        end
        set.memo[g.key] = memo
    end
end

function AD.SetAll(set, on)
    for _, g in ipairs(AD.Groups()) do AD.SetGroup(set, g, on) end
end

function AD.CopyCurrent(set)
    set.state, set.memo = AD.SnapshotState(), {}
end

function AD.Create(name, copyFrom)
    local n, err = ZM.CheckName(name, db.sets, "set")
    if not n then return false, err end
    local src = copyFrom and db.sets[copyFrom]
    db.sets[n] = src and ZM.DeepCopy(src) or NewSet()
    db.editing = n
    return true
end

function AD.Rename(old, new)
    if not db.sets[old] then return false, "Set not found." end
    if new and strtrim(new) == old then return true end
    local n, err = ZM.CheckName(new, db.sets, "set")
    if not n then return false, err end
    db.sets[n], db.sets[old] = db.sets[old], nil
    for k, v in pairs(db.assign) do
        if v == old then db.assign[k] = n end
    end
    if db.editing == old then db.editing = n end
    if AD.current == old then AD.current = n end
    return true
end

function AD.Delete(name)
    if not db.sets[name] then return false, "Set not found." end
    if #AD.Names() <= 1 then return false, "The last set cannot be deleted." end
    db.sets[name] = nil
    for k, v in pairs(db.assign) do
        if v == name then db.assign[k] = NONE end
    end
    if db.editing == name then db.editing = AD.Names()[1] end
    if AD.current == name then AD.current = nil end
    return true
end

-------------------------------------------------------------------------------
--  Switching
-------------------------------------------------------------------------------
function AD.SetFor(ctx)
    local name = db.assign[ctx]
    if name == NONE or not db.sets[name] then return nil end
    return name
end

function AD.ReloadNow()
    if InCombatLockdown() then
        ZM.SetFeedback(C.ORANGE .. "Not in combat.|r")
        return
    end
    ReloadUI()
end

-- The zone type the addon set follows: the group's content in group mode, else the zone.
function AD.ContextFor(zoneCtx)
    return ZM.GroupContext() or zoneCtx
end

-- "Mythic / Mythic+ (group)" etc. for prompts and status lines.
function AD.ContextText(ctx)
    local label = ZM.CONTEXT_LABEL[ctx] or "This zone"
    if ZM.simContext then return label .. " (simulated)" end
    if ZM.GroupContext() == ctx then return label .. " (group)" end
    return label
end

local declinedKey   -- "context:set" answered with "Not now"; a new zone type clears it
local promptKey     -- "context:set" of the reload prompt already scheduled or shown

local function ShowReloadPrompt(ctx, setName, off, on)
    local lines = {}
    if #off > 0 then lines[#lines + 1] = C.RED .. "Unload:|r " .. AD.GroupTitles(off, 6) end
    if #on > 0 then lines[#lines + 1] = C.GREEN .. "Load:|r " .. AD.GroupTitles(on, 6) end
    local msg = ("%s uses addon set |cffffffff%s|r.\n\n%s\n\nReload now?"):format(
        AD.ContextText(ctx), setName, table.concat(lines, "\n"))
    local E = ZM.EUI()
    if E and E.ShowConfirmPopup then
        E:ShowConfirmPopup({
            title = ZM.TITLE, message = msg, confirmText = "Reload", cancelText = "Not now",
            onConfirm = AD.ReloadNow,
            onCancel = function() declinedKey = ctx .. ":" .. setName; promptKey = nil end,
            onDismiss = function() promptKey = nil end,
        })
    else
        ZM.Print(msg:gsub("\n\n", " ") .. " Type /reload.")
    end
end

-- Back to the set: rewrite its flags and reload right away (the user's "Undo" click;
-- called synchronously from it). No reload when the undone change was never loaded.
local function RestoreSet(setName)
    local set = db.sets[setName]
    if not set then return end
    SetHold(nil)
    WriteFlags(set)
    RememberFlags()
    local off, on = AD.Diff(set)
    if #off + #on > 0 then
        AD.ReloadNow()
    else
        ZM.SetFeedback("Back to \"" .. setName .. "\".")
    end
    ZM.Refresh()
end

-- Flags were changed outside Zone Manager: keep (for now, or saved into the set) or undo.
local function ShowDriftPrompt(ctx, setName, drift)
    local off, on = DriftGroups(drift)
    local lines = {}
    if #off > 0 then lines[#lines + 1] = C.RED .. "Off:|r " .. AD.GroupTitles(off, 6) end
    if #on > 0 then lines[#lines + 1] = C.GREEN .. "On:|r " .. AD.GroupTitles(on, 6) end
    local msg = ("Addons were changed outside Zone Manager (e.g. in Blizzard's addon list):\n\n%s\n\n%s uses addon set |cffffffff%s|r. Keep your changes?\n\n"
        .. C.DIM .. "Keep: stays like this until the zone type changes.\nUndo: back to the set, reloads the UI right away.|r"):format(
        table.concat(lines, "\n"), AD.ContextText(ctx), setName)

    local function Keep(save)
        local set = db.sets[setName]
        if save and set then
            for name, now in pairs(drift) do
                set.state[name] = now
                set.memo[_groupOf[name]] = nil
            end
            SetHold(nil)
            ZM.SetFeedback("Saved your changes to \"" .. setName .. "\".")
        else
            SetHold(ctx, setName)
            ZM.SetFeedback("Keeping your changes until the zone type changes.")
        end
        RememberFlags()
        ZM.Refresh()
    end

    local E = ZM.EUI()
    if E and E.ShowConfirmPopup then
        E:ShowConfirmPopup({
            title = ZM.TITLE, message = msg, confirmText = "Keep", cancelText = "Undo",
            checkbox = "Also save them to set \"" .. setName .. "\"",
            onConfirm = function(save) Keep(save) end,
            onCancel = function() RestoreSet(setName) end,
            onDismiss = function() Keep(false) end,
        })
    else
        Keep(false)
        ZM.Print("addons changed outside Zone Manager: kept until the zone type changes.")
    end
end

-- Called by the dispatcher for every zone-type switch. During a simulation this is a
-- preview only, until the user clicks Apply Now (reason "manual").
function AD.OnContext(ctx, reason, force, entry)
    ctx = AD.ContextFor(ctx)
    local name = AD.SetFor(ctx)
    if ctx ~= AD.lastContext then declinedKey, promptKey = nil, nil end
    local changedSet = name ~= AD.current
    AD.lastContext = ctx
    AD.current = name
    entry.addons = name or false
    entry.addonsCtx = ctx
    if not name then return end
    -- The editor follows the set in use whenever that changes.
    if changedSet and not ZM.simContext then db.editing = name end

    local set = db.sets[name]
    if ZM.simContext and reason ~= "manual" then
        local off, on = AD.Diff(set)
        entry.addonsPending = #off + #on
        return
    end

    -- "Keep" from the drift prompt: leave the flags alone while zone type and set stay.
    local hold = AD.Hold()
    if hold and (hold.ctx ~= ctx or hold.set ~= name) then SetHold(nil); hold = nil end
    if hold then
        RememberFlags()
        entry.addonsPending, entry.addonsHeld = 0, true
        return
    end

    local drift = Drift()
    if drift then
        entry.addonsPending, entry.addonsDrift = 0, true
        C_Timer.After(0.5, function()
            if AD.lastContext == ctx and AD.current == name and not InCombatLockdown() then
                ShowDriftPrompt(ctx, name, drift)
            end
        end)
        return
    end

    WriteFlags(set)
    RememberFlags()
    local off, on = AD.Diff(set)
    local n = #off + #on
    entry.addonsPending = n
    -- The set's addons are already loaded: no reload, no prompt.
    if n == 0 then promptKey = nil; return end

    if ZM.db.announce and ZM.IsAutomatic(reason) then
        ZM.Print(("%s: addon set |cffffffff%s|r, reload needed (%d addon(s))."):format(AD.ContextText(ctx), name, n))
    end
    local key = ctx .. ":" .. name
    -- Only the user's own actions ask again after "Not now"; group events, combat end
    -- etc. respect it. And one prompt per context:set, not one per event.
    local userAsked = force and not ZM.IsAutomatic(reason)
    if userAsked or (declinedKey ~= key and promptKey ~= key) then
        promptKey = key
        -- A beat after the loading screen, so the popup is not lost behind it.
        C_Timer.After(0.5, function()
            if promptKey ~= key then return end
            if AD.lastContext == ctx and AD.current == name and not InCombatLockdown()
               and not AD.IsSetLoaded(set) then
                local o2, n2 = AD.Diff(set)
                ShowReloadPrompt(ctx, name, o2, n2)
            else
                promptKey = nil
            end
        end)
    end
end

-- Editing the set in use writes its flags straight away (the reload stays the user's call).
-- It also ends a "keep for now": the set is the user's choice again.
function AD.OnSetEdited()
    if not db.enabled or ZM.simContext or db.editing ~= AD.current then return end
    SetHold(nil)
    WriteFlags(db.sets[AD.current])
    RememberFlags()
end

-- Reload changes pending for the set in use (0 when none or not in use).
function AD.PendingCount()
    if not (db and db.enabled and AD.current and db.sets[AD.current]) or ZM.simContext then return 0 end
    if AD.Hold() then return 0 end
    local off, on = AD.Diff(db.sets[AD.current])
    return #off + #on
end

-------------------------------------------------------------------------------
--  Module interface
-------------------------------------------------------------------------------
function AD.Init(moduleDB)
    db = moduleDB
    if db.enabled == nil then db.enabled = true end
    if type(db.sets) ~= "table" or next(db.sets) == nil then Seed() end
    if type(db.assign) ~= "table" then db.assign = {} end
    for name, s in pairs(db.sets) do
        if type(s) ~= "table" then db.sets[name] = nil
        else
            s.state = type(s.state) == "table" and s.state or {}
            s.memo = type(s.memo) == "table" and s.memo or {}
        end
    end
    local first = AD.Names()[1]
    for _, c in ipairs(ZM.CONTEXTS) do
        local a = db.assign[c.key]
        if a ~= NONE and not db.sets[a] then db.assign[c.key] = first or NONE end
    end
    if not db.sets[db.editing] then db.editing = first end
end

function AD.IsEnabled() return db and db.enabled == true end

-- Disabling leaves every addon as it is. Enabling starts from the set: changes made
-- while the module was off are not "manual changes".
function AD.SetEnabled(on)
    db.enabled = on and true or false
    AD.current, AD.lastContext = nil, nil
    AD.ForgetFlags()
    SetHold(nil)
end

function AD.Reset()
    Seed()
    db.enabled = true
    db.written, db.hold = nil, nil
    AD.current, AD.lastContext = nil, nil
end

ZM.AddModule(AD)

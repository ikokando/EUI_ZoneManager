-------------------------------------------------------------------------------
--  Core/Init.lua -- namespace, SavedVariables, module registry, shared helpers.
--  Zone Manager is an unofficial EllesmereUI companion; it never edits EllesmereUI.
-------------------------------------------------------------------------------
local ADDON_NAME, ZM = ...
_G.EUIZoneManager = ZM

ZM.NAME       = ADDON_NAME
ZM.MODULE_KEY = ADDON_NAME   -- EllesmereUI module key; matches the folder
ZM.TITLE      = "Zone Manager"
ZM.NONE       = "__none"     -- zone-type assignment: leave this module's part alone

ZM.C = {
    ACCENT = "|cff0cd29f",
    GREEN  = "|cff4ade80",
    ORANGE = "|cffffb000",
    RED    = "|cffff6060",
    DIM    = "|cff8a8a8a",
    WHITE  = "|cffffffff",
}
ZM.CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t  "

function ZM.Print(msg)
    print("|cff0cd29fZone Manager|r " .. tostring(msg))
end

-- Client global string (already localized), with a fallback for clients that lack it.
function ZM.G(name, fallback)
    local v = name and _G[name]
    if type(v) == "string" and v ~= "" then return v end
    return fallback
end

function ZM.DeepCopy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and ZM.DeepCopy(v) or v end
    return out
end

function ZM.SortedKeys(t)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = k end
    table.sort(out, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return out
end

-- Shared rules for profile / set names. Returns the trimmed name or nil + message.
function ZM.CheckName(name, existing, kind)
    name = name and strtrim(name) or ""
    if name == "" then return nil, "Please enter a name." end
    if name == ZM.NONE then return nil, "That name is reserved." end
    if existing[name] then return nil, ("A %s with that name already exists."):format(kind) end
    return name
end

-------------------------------------------------------------------------------
--  SavedVariables
-------------------------------------------------------------------------------
--  EUIZoneManagerDB = {
--      announce,              -- chat line on automatic switches
--      groupMode, groupCtx,   -- addon set follows the group's content (Core/Group.lua)
--      sim,                   -- simulated zone type; survives /reload, not a loading screen
--      debug, log,            -- /zm debug
--      graphics = { ... },    -- owned by Modules/Graphics
--      addons   = { ... },    -- owned by Modules/Addons
--  }
-- Account wide: graphics belong to the machine, addon sets are chosen per zone, not per character.
function ZM.InitDB()
    if type(_G.EUIZoneManagerDB) ~= "table" then _G.EUIZoneManagerDB = {} end
    local d = _G.EUIZoneManagerDB
    if d.announce == nil then d.announce = true end
    if d.groupMode == nil then d.groupMode = false end
    if type(d.graphics) ~= "table" then d.graphics = {} end
    if type(d.addons) ~= "table" then d.addons = {} end
    ZM.db = d
    return d
end

-------------------------------------------------------------------------------
--  Modules
-------------------------------------------------------------------------------
--  A module table may provide:
--    key, label, dbKey
--    Init(db)                       once at login, with its own SavedVariables table
--    IsEnabled() / SetEnabled(on)
--    OnContext(ctx, reason, force, entry)   a zone type (real or simulated) became current
--    OnLoadingScreen(isReload)      before OnContext on every PLAYER_ENTERING_WORLD
--    Reset()                        EllesmereUI's "Reset ALL"
ZM.modules, ZM.moduleOrder = {}, {}

function ZM.AddModule(mod)
    if not ZM.modules[mod.key] then ZM.moduleOrder[#ZM.moduleOrder + 1] = mod.key end
    ZM.modules[mod.key] = mod
    return mod
end

function ZM.ForEachModule(fn)
    for _, key in ipairs(ZM.moduleOrder) do fn(ZM.modules[key]) end
end

-------------------------------------------------------------------------------
--  Feedback line (green tick in the options for a few seconds after an action)
-------------------------------------------------------------------------------
ZM.FEEDBACK_SECS = 5

function ZM.SetFeedback(text)
    ZM.lastAction = { time = GetTime(), text = text }
    -- One refresh when the highlight expires; only ever after a user action.
    C_Timer.After(ZM.FEEDBACK_SECS + 0.05, function() ZM.Refresh() end)
end

function ZM.RecentFeedback()
    local a = ZM.lastAction
    if a and GetTime() - a.time < ZM.FEEDBACK_SECS then return a.text end
end

-- Re-read the visible options page, only while the panel is open.
function ZM.Refresh()
    local E = _G.EllesmereUI
    local f = E and E._mainFrame
    if f and f:IsShown() and E.RefreshPage then E:RefreshPage() end
end

-------------------------------------------------------------------------------
--  Debug log (/zm debug): ring buffer in the SavedVariables, readable after /reload
-------------------------------------------------------------------------------
local LOG_MAX = 60

function ZM.DebugOn()
    return ZM.db and ZM.db.debug == true
end

function ZM.DebugLog(entry)
    if not ZM.DebugOn() then return end
    entry.t = entry.t or date("%H:%M:%S")
    local log = ZM.db.log
    if type(log) ~= "table" then log = {}; ZM.db.log = log end
    log[#log + 1] = entry
    while #log > LOG_MAX do table.remove(log, 1) end
end

function ZM.SetDebug(on)
    ZM.db.debug = on and true or false
    if not ZM.db.debug then ZM.db.log = nil end
end

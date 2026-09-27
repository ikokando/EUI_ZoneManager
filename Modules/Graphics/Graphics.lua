-------------------------------------------------------------------------------
--  Modules/Graphics/Graphics.lua -- graphics profiles: storage, applying, preview.
--  Only CVars whose value actually differs are written.
-------------------------------------------------------------------------------
local _, ZM = ...
local GX = ZM.Graphics
local NONE = ZM.NONE

--  db (EUIZoneManagerDB.graphics) = {
--      enabled,
--      profiles = { [name] = { q = { [cvar] = n }, x = { [cvar] = n } } },
--      assign   = { [contextKey] = profileName | NONE },
--      editing  = profileName,
--      raidSplitOrig = "0" | "1" | nil,  -- RAIDsettingsEnabled before we took it over
--  }
local db

GX.current = nil          -- profile on screen (set by the last apply)
GX.previewProfile = nil   -- Live Preview from the editor; runtime only

local function RaidName(cvar) return "raid" .. cvar:sub(1, 1):upper() .. cvar:sub(2) end
local function ReadNum(cvar) return tonumber(C_CVar.GetCVar(cvar)) end

-------------------------------------------------------------------------------
--  Profiles
-------------------------------------------------------------------------------
-- raid=true reads Blizzard's "Raid and Battleground" tab instead of "Base".
local function CaptureQuality(p, raid)
    local src = raid and RaidName(GX.PRESET_CVAR) or GX.PRESET_CVAR
    p.q[GX.PRESET_CVAR] = ReadNum(src) or p.q[GX.PRESET_CVAR]
    for _, def in ipairs(GX.QualityList()) do
        local v = ReadNum(raid and RaidName(def.cvar) or def.cvar)
        if v then p.q[def.cvar] = v end
    end
end

function GX.NewProfileFromGame(raid)
    local p = { q = {}, x = {} }
    CaptureQuality(p, raid)
    return p
end

local function Seed()
    db.profiles, db.assign = { ["Default"] = GX.NewProfileFromGame(false) }, {}
    local raidProfile = "Default"
    -- Keep today's split: if Blizzard's raid tab is in use, it becomes its own profile.
    if C_CVar.GetCVar(GX.RAID_SPLIT_CVAR) == "1" then
        raidProfile = "Raid & Battleground"
        db.profiles[raidProfile] = GX.NewProfileFromGame(true)
    end
    for _, c in ipairs(ZM.CONTEXTS) do
        db.assign[c.key] = (c.key == "raid" or c.key == "battleground") and raidProfile or "Default"
    end
    db.editing = "Default"
end

function GX.Names() return ZM.SortedKeys(db and db.profiles) end
function GX.DB() return db end
function GX.Editing() return db and db.editing and db.profiles[db.editing] end

function GX.CaptureInto(p)
    CaptureQuality(p, false)
    for key in pairs(p.x) do p.x[key] = ReadNum(key) or p.x[key] end
end

-- Same as Blizzard's "Base Graphics Quality" slider: every setting jumps to that level.
function GX.ApplyPresetToProfile(p, level)
    p.q[GX.PRESET_CVAR] = level
    if not GetGraphicsCVarValueForQualityLevel then return end
    for _, def in ipairs(GX.QualityList()) do
        local ok, v = pcall(GetGraphicsCVarValueForQualityLevel, def.cvar, level, false)
        if ok and type(v) == "number" then
            if def.minPreset and v < def.minPreset then v = def.minPreset end
            p.q[def.cvar] = v
        end
    end
end

function GX.Create(name, copyFrom)
    local n, err = ZM.CheckName(name, db.profiles, "profile")
    if not n then return false, err end
    local src = copyFrom and db.profiles[copyFrom]
    db.profiles[n] = src and ZM.DeepCopy(src) or GX.NewProfileFromGame(false)
    db.editing = n
    return true
end

function GX.Rename(old, new)
    if not db.profiles[old] then return false, "Profile not found." end
    if new and strtrim(new) == old then return true end
    local n, err = ZM.CheckName(new, db.profiles, "profile")
    if not n then return false, err end
    db.profiles[n], db.profiles[old] = db.profiles[old], nil
    for k, v in pairs(db.assign) do
        if v == old then db.assign[k] = n end
    end
    if db.editing == old then db.editing = n end
    if GX.current == old then GX.current = n end
    if GX.previewProfile == old then GX.previewProfile = n end
    return true
end

function GX.Delete(name)
    if not db.profiles[name] then return false, "Profile not found." end
    if #GX.Names() <= 1 then return false, "The last profile cannot be deleted." end
    db.profiles[name] = nil
    for k, v in pairs(db.assign) do
        if v == name then db.assign[k] = NONE end
    end
    if db.editing == name then db.editing = GX.Names()[1] end
    if GX.current == name then GX.current = nil end
    if GX.previewProfile == name then GX.previewProfile = nil end
    return true
end

-------------------------------------------------------------------------------
--  Applying
-------------------------------------------------------------------------------
local changeLog   -- filled only while /zm debug is on

local function SetIfDifferent(cvar, value)
    if value == nil then return 0 end
    local cur = C_CVar.GetCVar(cvar)
    if cur == nil then return 0 end
    local want = tostring(value)
    if cur == want then return 0 end
    local cn, wn = tonumber(cur), tonumber(want)
    if cn and wn and math.abs(cn - wn) < 0.0001 then return 0 end
    C_CVar.SetCVar(cvar, want)
    if changeLog then changeLog[#changeLog + 1] = ("%s %s>%s"):format(cvar, cur, want) end
    return 1
end

-- Blizzard only reads the base settings while the raid split is off, so we own the switch
-- while enabled and hand the user's choice back when disabled.
local function TakeRaidSplit()
    local cur = C_CVar.GetCVar(GX.RAID_SPLIT_CVAR)
    if cur == nil or cur == "0" then return end
    if db.raidSplitOrig == nil then db.raidSplitOrig = cur end
    C_CVar.SetCVar(GX.RAID_SPLIT_CVAR, "0")
end

local function ReleaseRaidSplit()
    if db and db.raidSplitOrig ~= nil then
        C_CVar.SetCVar(GX.RAID_SPLIT_CVAR, db.raidSplitOrig)
        db.raidSplitOrig = nil
    end
end

-- Returns how many CVars changed.
function GX.ApplyProfile(p)
    if type(p) ~= "table" then return 0 end
    if db.enabled then TakeRaidSplit() end
    changeLog = ZM.DebugOn() and {} or nil
    local n = 0
    -- Preset first: the per-setting values below then win over whatever it implies.
    n = n + SetIfDifferent(GX.PRESET_CVAR, p.q[GX.PRESET_CVAR])
    for _, def in ipairs(GX.QualityList()) do n = n + SetIfDifferent(def.cvar, p.q[def.cvar]) end
    for _, def in ipairs(GX.ExtrasList()) do n = n + SetIfDifferent(def.cvar, p.x[def.cvar]) end
    if p.x.RenderScale then n = n + SetIfDifferent("RenderScale", p.x.RenderScale) end
    if p.x.maxFPS then
        n = n + SetIfDifferent("useMaxFPS", 1)
        n = n + SetIfDifferent("maxFPS", p.x.maxFPS)
    end
    if changeLog and #changeLog > 0 then ZM.DebugLog({ module = "graphics", writes = changeLog }) end
    changeLog = nil
    return n
end

-- The profile a zone type shows right now (Live Preview wins), or nil for "don't change".
function GX.ProfileFor(ctx)
    if GX.previewProfile and db.profiles[GX.previewProfile] then return GX.previewProfile end
    local name = db.assign[ctx]
    if name == NONE or not db.profiles[name] then return nil end
    return name
end

function GX.ChangedText(n)
    if n == 0 then return "already up to date" end
    return n == 1 and "1 setting changed" or (n .. " settings changed")
end

-- Called by the dispatcher (Core/Events.lua) for every zone-type switch.
function GX.OnContext(ctx, reason, force, entry)
    local name = GX.ProfileFor(ctx)
    GX.current = name
    entry.graphics = name or false
    if not name then return end
    local n = GX.ApplyProfile(db.profiles[name])
    entry.graphicsChanged = n
    if n > 0 and ZM.db.announce and ZM.IsAutomatic(reason) then
        ZM.Print(("%s: graphics profile |cffffffff%s|r loaded."):format(ZM.CONTEXT_LABEL[ctx] or ctx, name))
    end
end

-- A real loading screen ends the Live Preview.
function GX.OnLoadingScreen()
    GX.previewProfile = nil
end

-- Editing the profile on screen applies it live. Debounced: a slider drag is one reload
-- of the render settings, not one per step.
local _liveQueued = false
function GX.OnProfileEdited()
    if not (db.enabled and db.editing == GX.current) or _liveQueued then return end
    _liveQueued = true
    C_Timer.After(0.3, function()
        _liveQueued = false
        if db.enabled and GX.current and db.profiles[GX.current] and not InCombatLockdown() then
            local n = GX.ApplyProfile(db.profiles[GX.current])
            if n > 0 then
                ZM.SetFeedback("Live: " .. GX.ChangedText(n))
                ZM.Refresh()
            end
        end
    end)
end

-- Put one profile on screen wherever you are (nil = back to the assignments).
function GX.SetPreview(name)
    GX.previewProfile = (name and db.profiles[name]) and name or nil
    ZM.ApplyNow("preview", GX)   -- graphics only: a preview must not raise an addon reload prompt
end

-------------------------------------------------------------------------------
--  Module interface
-------------------------------------------------------------------------------
function GX.Init(moduleDB)
    db = moduleDB
    if db.enabled == nil then db.enabled = true end
    if type(db.profiles) ~= "table" or next(db.profiles) == nil then Seed() end
    if type(db.assign) ~= "table" then db.assign = {} end
    for name, p in pairs(db.profiles) do
        if type(p) ~= "table" then db.profiles[name] = nil
        else
            p.q = type(p.q) == "table" and p.q or {}
            p.x = type(p.x) == "table" and p.x or {}
        end
    end
    local first = GX.Names()[1]
    for _, c in ipairs(ZM.CONTEXTS) do
        local a = db.assign[c.key]
        if a ~= NONE and not db.profiles[a] then db.assign[c.key] = first or NONE end
    end
    if not db.profiles[db.editing] then db.editing = first end
    if not db.enabled then ReleaseRaidSplit() end
end

function GX.IsEnabled() return db and db.enabled == true end

function GX.SetEnabled(on)
    db.enabled = on and true or false
    GX.current, GX.previewProfile = nil, nil
    if not db.enabled then ReleaseRaidSplit() end
end

-- EllesmereUI's "Reset ALL": start over from the game's current values.
function GX.Reset()
    ReleaseRaidSplit()
    Seed()
    db.enabled = true
    GX.current, GX.previewProfile = nil, nil
end

ZM.AddModule(GX)

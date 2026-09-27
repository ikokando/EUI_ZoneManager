-------------------------------------------------------------------------------
--  Core/Bridge.lua -- everything that touches EllesmereUI: module registration,
--  the sidebar row, opening the panel, and small row builders shared by the pages.
--  Pages are built with EllesmereUI's own widget factory (EllesmereUI.Widgets), which
--  exists once its load-on-demand options addon has loaded, i.e. when a page opens.
-------------------------------------------------------------------------------
local _, ZM = ...
local C = ZM.C

ZM.TIP_OPTS = { width = 340, justify = "LEFT" }

local function EUI() return _G.EllesmereUI end
ZM.EUI = EUI

-------------------------------------------------------------------------------
--  Pages (tabs of our one sidebar row)
-------------------------------------------------------------------------------
ZM.pages, ZM.pageOrder = {}, {}

function ZM.AddPage(name, builder, position)
    ZM.pages[name] = builder
    table.insert(ZM.pageOrder, math.min(position or (#ZM.pageOrder + 1), #ZM.pageOrder + 1), name)
end

-- Rebuild our pages in place: needed when a dropdown's option list changes, since built
-- menus are cached.
function ZM.Rebuild()
    local E = EUI()
    if not E then return end
    if E.InvalidateModulePageCache then E:InvalidateModulePageCache(ZM.MODULE_KEY) end
    if E.RefreshPage then E:RefreshPage(true) end
end

-------------------------------------------------------------------------------
--  Popups
-------------------------------------------------------------------------------
function ZM.Popup(title, message)
    local E = EUI()
    if E and E.ShowConfirmPopup then
        E:ShowConfirmPopup({ title = title, message = message, confirmText = "OK", hideCancel = true })
    else
        ZM.Print(message)
    end
end

-- onName(text) returns ok, err. Success gets a green tick, failure a popup.
function ZM.AskName(title, message, placeholder, onName)
    local E = EUI()
    if not (E and E.ShowInputPopup) then return end
    E:ShowInputPopup({
        title = title, message = message, placeholder = placeholder or "Name",
        confirmText = "OK", cancelText = "Cancel",
        onConfirm = function(text)
            local ok, err = onName(text)
            if ok then ZM.SetFeedback("Saved.") else ZM.Popup(title, err) end
            ZM.Rebuild()
        end,
    })
end

function ZM.Confirm(title, message, confirmText, onConfirm)
    local E = EUI()
    if not (E and E.ShowConfirmPopup) then return end
    E:ShowConfirmPopup({ title = title, message = message, confirmText = confirmText, cancelText = "Cancel",
        onConfirm = onConfirm })
end

-------------------------------------------------------------------------------
--  Row helpers
-------------------------------------------------------------------------------
-- Dropdown values for a list of names, optionally led by "Don't change".
function ZM.NameValues(names, withNone)
    local values, order = { _noLoc = true }, {}
    if withNone then
        values[ZM.NONE] = C.DIM .. "Don't change|r"
        order[1] = ZM.NONE
    end
    for _, name in ipairs(names) do
        values[name] = name
        order[#order + 1] = name
    end
    return values, order
end

-- Lays DualRow configs out two per row.
function ZM.DualRows(W, parent, y, cfgs)
    local _, h
    for i = 1, #cfgs, 2 do
        _, h = W:DualRow(parent, y, cfgs[i], cfgs[i + 1]); y = y - h
    end
    return y
end

-- Plain text row: update(left, right) fills two font strings and re-runs on every page
-- refresh. The widget factory has no read-only text row, so this is ours.
function ZM.InfoRow(parent, y, update)
    local E = EUI()
    local H = 50
    if E._prebuilding or not (E.MakeFont and E.RowBg) then return H end
    local pad = E.CONTENT_PAD or 45
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(parent:GetWidth() - pad * 2, H)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
    E.RowBg(f, parent)
    local right = E.MakeFont(f, 14, nil, 1, 1, 1, 1)
    right:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    right:SetJustifyH("RIGHT")
    local left = E.MakeFont(f, 14, nil, 1, 1, 1, 1)
    left:SetPoint("LEFT", f, "LEFT", 20, 0)
    left:SetPoint("RIGHT", right, "LEFT", -20, 0)
    left:SetJustifyH("LEFT")
    left:SetWordWrap(false)
    local function U() update(left, right) end
    U()
    if E.RegisterWidgetRefresh then E.RegisterWidgetRefresh(U) end
    return H
end

-- Feedback row: the green tick after an action, otherwise fallback(left, right).
function ZM.FeedbackRow(parent, y, fallback)
    return ZM.InfoRow(parent, y, function(left, right)
        local fb = ZM.RecentFeedback()
        if fb then
            left:SetText(ZM.CHECK .. fb)
            right:SetText("")
        else
            fallback(left, right)
        end
    end)
end

-------------------------------------------------------------------------------
--  Registration
-------------------------------------------------------------------------------
-- RegisterModule whitelists callers by their "AddOns/<folder>/" path via debugstack.
-- From a loadstring chunk the caller is `[string ...]`, so the guard falls through.
local function RegisterModule(config)
    local E = EUI()
    _G.__EUIZoneManager_pendingReg = { key = ZM.MODULE_KEY, config = config }
    local trampoline = loadstring([[
        local r = _G.__EUIZoneManager_pendingReg
        if r and EllesmereUI and EllesmereUI.RegisterModule then
            EllesmereUI:RegisterModule(r.key, r.config)
        end
    ]], "EUIZoneManager-register")
    local ok = trampoline and pcall(trampoline)
    _G.__EUIZoneManager_pendingReg = nil
    if not ok then pcall(function() E:RegisterModule(ZM.MODULE_KEY, config) end) end
end

-- Our own sidebar category, right under NaowhUI's when that is installed. The sidebar is
-- built lazily on first panel open, so this is early enough.
local function InjectSidebar()
    local E = EUI()
    local key = ZM.MODULE_KEY
    E._addonInfoByFolder = E._addonInfoByFolder or {}
    E._addonInfoByFolder[key] = E._addonInfoByFolder[key] or {
        folder       = key,
        display      = ZM.TITLE,
        search_name  = "Zone Manager Graphics Addons Profiles Sets",
        alwaysLoaded = true,   -- no power toggle, row always clickable
    }
    E._syncExempt = E._syncExempt or {}
    E._syncExempt[key] = true  -- account-wide data, nothing to sync between EUI profiles

    E.ADDON_GROUPS = E.ADDON_GROUPS or {}
    local insertAt = 1
    for i, g in ipairs(E.ADDON_GROUPS) do
        if g.key == "zonemanager" then return end
        if g.key == "naowhui" then insertAt = i + 1 end
    end
    table.insert(E.ADDON_GROUPS, insertAt, { key = "zonemanager", label = ZM.TITLE, members = { key } })
end

function ZM.RegisterWithEUI()
    local E = EUI()
    if not (E and E.RegisterModule) then
        ZM.Print(C.RED .. "EllesmereUI not found.|r The options need EllesmereUI; zone switching still works.")
        return
    end
    RegisterModule({
        title       = ZM.TITLE,
        description = "Graphics profiles and addon sets per zone type.",
        pages       = ZM.pageOrder,
        buildPage   = function(pageName, parent, yOffset)
            local build = ZM.pages[pageName]
            return (build and build(parent, yOffset)) or math.abs(yOffset)
        end,
        onReset     = function() ZM.ResetAll() end,
    })
    -- Next frame: NaowhUI injects its category at PLAYER_LOGIN too, and we sit below it.
    C_Timer.After(0, InjectSidebar)
end

-- Open the panel on our row, optionally on one tab.
function ZM.OpenOptions(page)
    local E = EUI()
    if not (E and E.Show and E.SelectModule) then return false end
    E:Show()
    local tries = 0
    local function Select()
        tries = tries + 1
        local f = E._mainFrame
        if f and f:IsShown() then
            E:SelectModule(ZM.MODULE_KEY)
            if page and E.SelectPage then E:SelectPage(page) end
        elseif tries < 20 then
            C_Timer.After(0.1, Select)
        end
    end
    C_Timer.After(0, Select)
    return true
end

-------------------------------------------------------------------------------
--  Modules/Graphics/Options.lua -- the "Graphics" tab: profile editor laid out
--  like Blizzard's Graphics Quality block, with Blizzard's own tooltips.
-------------------------------------------------------------------------------
local _, ZM = ...
local GX = ZM.Graphics
local C = ZM.C
local KEEP = "__keep"   -- extras: this profile does not touch the setting

local function Edited() GX.OnProfileEdited() end

-------------------------------------------------------------------------------
--  Blizzard's tooltips
-------------------------------------------------------------------------------
local function OptionTip(o)
    local tip = o[3] and ZM.G(o[3])
    local warn = o[4] and ZM.G(o[4])
    if warn then tip = (tip and (tip .. "\n\n") or "") .. "|cffff8040" .. warn .. "|r" end
    return tip
end

-- Laid out like Blizzard's: description, then every option with its own text.
local function SettingTip(def, extraNote)
    local parts = {}
    local desc = def.tip and ZM.G(def.tip)
    if desc then parts[#parts + 1] = desc end
    if def.opts then
        local rec = GX.RecommendedValue(def)
        local lines = {}
        for _, o in ipairs(def.opts) do
            local t = OptionTip(o)
            local recTag = (o[1] == rec) and (C.GREEN .. "  (" .. GX.RECOMMENDED .. ")|r") or ""
            if t then
                lines[#lines + 1] = C.WHITE .. o[2] .. "|r" .. recTag .. "\n" .. t
            elseif recTag ~= "" then
                lines[#lines + 1] = C.WHITE .. o[2] .. "|r" .. recTag
            end
        end
        if #lines > 0 then parts[#parts + 1] = table.concat(lines, "\n\n") end
    end
    if extraNote then parts[#parts + 1] = C.DIM .. extraNote .. "|r" end
    if #parts == 0 then return nil end
    return table.concat(parts, "\n\n")
end

-- Dropdown values with Blizzard's "Recommended" note and a hover tooltip per option.
local function OptionValues(def, withKeep)
    local values, order, tips = { _noLoc = true }, {}, {}
    if withKeep then
        values[KEEP] = "Don't change"
        order[1] = KEEP
        tips[KEEP] = "This profile leaves the setting as it is."
    end
    local rec = GX.RecommendedValue(def)
    for _, o in ipairs(def.opts) do
        values[o[1]] = (o[1] == rec) and { text = o[2], note = GX.RECOMMENDED } or o[2]
        order[#order + 1] = o[1]
        tips[o[1]] = OptionTip(o)
    end
    values._menuOpts = {
        onItemHover = function(key, item)
            local E = ZM.EUI()
            if tips[key] and item and E and E.ShowWidgetTooltip then E.ShowWidgetTooltip(item, tips[key], ZM.TIP_OPTS) end
        end,
        onItemLeave = function()
            local E = ZM.EUI()
            if E and E.HideWidgetTooltip then E.HideWidgetTooltip() end
        end,
    }
    return values, order
end

local UNSUPPORTED_TIP = function() return "Not supported by your hardware or graphics API." end

-------------------------------------------------------------------------------
--  Row configs
-------------------------------------------------------------------------------
local function QualityDropdownCfg(def)
    local values, order = OptionValues(def)
    return {
        type = "dropdown", text = def.label, values = values, order = order,
        tooltip = SettingTip(def), tooltipOpts = ZM.TIP_OPTS,
        getValue = function() local p = GX.Editing(); return p and p.q[def.cvar] end,
        setValue = function(v)
            local p = GX.Editing(); if not p then return end
            p.q[def.cvar] = v
            Edited()
        end,
        itemDisabled = function(v) return not GX.IsQualityValueSupported(def.cvar, v) end,
        itemDisabledTooltip = UNSUPPORTED_TIP,
    }
end

-- 0-9 in the CVar, 1-10 on screen (Blizzard's own convention).
local function QualitySliderCfg(def)
    return {
        type = "slider", text = def.label, min = 1, max = 10, step = 1,
        tooltip = SettingTip(def), tooltipOpts = ZM.TIP_OPTS,
        getValue = function() local p = GX.Editing(); return ((p and p.q[def.cvar]) or 0) + 1 end,
        setValue = function(v)
            local p = GX.Editing(); if not p then return end
            p.q[def.cvar] = math.floor(v + 0.5) - 1
            Edited()
        end,
    }
end

local function ExtraDropdownCfg(def)
    local values, order = OptionValues(def, true)
    return {
        type = "dropdown", text = def.label, values = values, order = order,
        tooltip = SettingTip(def, "\"Don't change\": this profile leaves the setting as it is."), tooltipOpts = ZM.TIP_OPTS,
        getValue = function()
            local p = GX.Editing()
            local v = p and p.x[def.cvar]
            if v == nil then return KEEP end
            return v
        end,
        setValue = function(v)
            local p = GX.Editing(); if not p then return end
            if v == KEEP then p.x[def.cvar] = nil else p.x[def.cvar] = v end
            Edited()
        end,
        itemDisabled = function(v)
            if v == KEEP or def.noValidate then return false end
            return not GX.IsCVarValueSupported(def.cvar, v)
        end,
        itemDisabledTooltip = UNSUPPORTED_TIP,
    }
end

-- Toggle + slider pair for a numeric extra that is only written while switched on.
local function ManagedSliderRow(W, parent, y, E, o)
    local _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Set " .. o.label,
          tooltip = SettingTip({ tip = o.tip }, "Off: this profile leaves it alone."), tooltipOpts = ZM.TIP_OPTS,
          getValue = function() local p = GX.Editing(); return p and p.x[o.key] ~= nil end,
          setValue = function(v)
              local p = GX.Editing(); if not p then return end
              p.x[o.key] = v and o.current() or nil
              Edited(); E:RefreshPage()
          end },
        { type = "slider", text = o.sliderLabel or o.label, min = o.min, max = o.max, step = 1,
          disabled = function() local p = GX.Editing(); return not (p and p.x[o.key]) end,
          getValue = function() local p = GX.Editing(); return o.toSlider((p and p.x[o.key]) or o.current()) end,
          setValue = function(v)
              local p = GX.Editing(); if not (p and p.x[o.key]) then return end
              p.x[o.key] = o.fromSlider(v)
              Edited()
          end })
    return y - h
end

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
local function BuildPage(parent, yOffset)
    local E = ZM.EUI()
    local W = E.Widgets
    local d = GX.DB()
    local y = yOffset
    local _, h
    if E.ClearContentHeader then E:ClearContentHeader() end

    -- Picker + Live Preview
    _, h = W:SectionHeader(parent, "GRAPHICS PROFILE", y); y = y - h
    local pv, po = ZM.NameValues(GX.Names(), false)
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Edit Profile", values = pv, order = po,
          tooltip = "The profile the settings below belong to.",
          getValue = function() return d.editing end,
          setValue = function(v)
              d.editing = v
              -- Live Preview follows the picker, so flipping profiles compares them on screen.
              if GX.previewProfile then GX.SetPreview(v) else E:RefreshPage() end
          end },
        { type = "toggle", text = "Live Preview",
          tooltip = "Puts this profile on screen right now, wherever you are, so every change below is visible immediately.\n\nSwitching profiles above while it is on compares them directly.\n\nEnds with the next loading screen or when switched off; your zone assignments stay as they are.",
          disabled = function() return not d.enabled end,
          disabledTooltip = "Enable the Graphics module on the Overview tab first.",
          getValue = function() return GX.previewProfile ~= nil and GX.previewProfile == d.editing end,
          setValue = function(v) GX.SetPreview(v and d.editing or nil) end })
    y = y - h

    y = y - ZM.FeedbackRow(parent, y, function(left, right)
        local used = {}
        for _, c in ipairs(ZM.CONTEXTS) do
            if d.assign[c.key] == d.editing then used[#used + 1] = c.label end
        end
        left:SetText("Used in:  " .. (#used > 0 and table.concat(used, ", ")
            or (C.ORANGE .. "no zone type yet: assign it on the Overview tab|r")))
        if GX.current == d.editing and d.enabled then
            right:SetText(C.GREEN .. "On screen now|r" .. (GX.previewProfile and (C.ORANGE .. " [preview]|r") or ""))
        else
            right:SetText(C.DIM .. "Not on screen|r")
        end
    end)

    _, h = W:WideDualButton(parent, "New Profile", "Duplicate", y, function()
        ZM.AskName("New Profile", "Starts from your current in-game graphics settings.", "Profile name",
            function(text) return GX.Create(text) end)
    end, function()
        ZM.AskName("Duplicate Profile", "Copy of \"" .. tostring(d.editing) .. "\".", "Profile name",
            function(text) return GX.Create(text, d.editing) end)
    end)
    y = y - h

    _, h = W:WideDualButton(parent, "Rename", "Delete", y, function()
        ZM.AskName("Rename Profile", "New name for \"" .. tostring(d.editing) .. "\".", "Profile name",
            function(text) return GX.Rename(d.editing, text) end)
    end, function()
        local name = d.editing
        ZM.Confirm("Delete Profile", "Delete \"" .. tostring(name) .. "\"?\nZone types using it will be set to \"Don't change\".",
            "Delete", function()
                local ok, err = GX.Delete(name)
                if ok then ZM.SetFeedback("Deleted \"" .. tostring(name) .. "\".") else ZM.Popup("Delete Profile", err) end
                ZM.Rebuild()
            end)
    end)
    y = y - h

    -- Blizzard's Graphics Quality block
    _, h = W:SectionHeader(parent, "GRAPHICS QUALITY", y); y = y - h
    local presetTip = ZM.G(GX.PRESET_TIP)
    _, h = W:Slider(parent, GX.PRESET_LABEL, y, 1, 10, 1,
        function() local p = GX.Editing(); return ((p and p.q[GX.PRESET_CVAR]) or 0) + 1 end,
        function(v)
            local p = GX.Editing(); if not p then return end
            GX.ApplyPresetToProfile(p, math.floor(v + 0.5) - 1)
            Edited()
            E:RefreshPage()   -- every setting below just moved
        end,
        (presetTip and (presetTip .. "\n\n") or "")
            .. "Like Blizzard's slider: moving it sets every setting below to that quality level. Fine-tune afterwards.")
    y = y - h

    local dropdowns, sliders = {}, {}
    for _, def in ipairs(GX.QualityList()) do
        if def.slider then sliders[#sliders + 1] = QualitySliderCfg(def)
        else dropdowns[#dropdowns + 1] = QualityDropdownCfg(def) end
    end
    y = ZM.DualRows(W, parent, y, dropdowns)
    y = ZM.DualRows(W, parent, y, sliders)

    -- Optional extras
    _, h = W:SectionHeader(parent, "ADVANCED (OPTIONAL)", y); y = y - h
    local extras = {}
    for _, def in ipairs(GX.ExtrasList()) do extras[#extras + 1] = ExtraDropdownCfg(def) end
    y = ZM.DualRows(W, parent, y, extras)

    y = ManagedSliderRow(W, parent, y, E, {
        key = "RenderScale", label = GX.RENDER_SCALE_LABEL, sliderLabel = GX.RENDER_SCALE_LABEL .. " %", tip = GX.RENDER_SCALE_TIP,
        min = math.floor(((GetMinRenderScale and GetMinRenderScale()) or 0.5) * 100 + 0.5),
        max = math.floor(((GetMaxRenderScale and GetMaxRenderScale()) or 2) * 100 + 0.5),
        current = function() return tonumber(C_CVar.GetCVar("RenderScale")) or 1 end,
        toSlider = function(v) return math.floor(v * 100 + 0.5) end,
        fromSlider = function(v) return v / 100 end,
    })
    y = ManagedSliderRow(W, parent, y, E, {
        key = "maxFPS", label = GX.MAXFPS_LABEL, tip = GX.MAXFPS_TIP, min = 8, max = 200,
        current = function() return tonumber(C_CVar.GetCVar("maxFPS")) or 144 end,
        toSlider = function(v) return v end,
        fromSlider = function(v) return math.floor(v + 0.5) end,
    })

    -- Actions
    _, h = W:SectionHeader(parent, "ACTIONS", y); y = y - h
    _, h = W:WideButton(parent, "Copy Current Game Settings Into This Profile", y, function()
        local p = GX.Editing(); if not p then return end
        GX.CaptureInto(p)
        ZM.SetFeedback("Copied from the game settings.")
        Edited()
        E:RefreshPage()
    end, 450)
    y = y - h

    return math.abs(y)
end

ZM.AddPage("Graphics", BuildPage)

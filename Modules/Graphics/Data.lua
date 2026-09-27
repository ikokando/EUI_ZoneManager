-------------------------------------------------------------------------------
--  Modules/Graphics/Data.lua -- the settings of Blizzard's Graphics page this
--  module manages, mirrored from Blizzard_SettingsDefinitions_Shared/Graphics.lua.
--  Labels and tooltips are the client's own global strings, so they come in the
--  client language; the English fallbacks only cover a client that lacks one.
-------------------------------------------------------------------------------
local _, ZM = ...
local G = ZM.G

local GX = { key = "graphics", label = "Graphics", dbKey = "graphics" }
ZM.Graphics = GX

local LOW    = G("VIDEO_OPTIONS_LOW", "Low")
local FAIR   = G("VIDEO_OPTIONS_FAIR", "Fair")
local MEDIUM = G("VIDEO_OPTIONS_MEDIUM", "Good")
local HIGH   = G("VIDEO_OPTIONS_HIGH", "High")
local ULTRA  = G("VIDEO_OPTIONS_ULTRA", "Ultra")
local UHIGH  = G("VIDEO_OPTIONS_ULTRA_HIGH", "Ultra High")
local OFF    = G("VIDEO_OPTIONS_DISABLED", "Disabled")
local ON     = G("VIDEO_OPTIONS_ENABLED", "Enabled")
local COMBAT_CUES_WARN = "VIDEO_OPTIONS_COMBAT_CUES_DISABLED_WARNING"

GX.PRESET_CVAR     = "graphicsQuality"
GX.PRESET_LABEL    = G("BASE_GRAPHICS_QUALITY", "Base Graphics Quality")
GX.PRESET_TIP      = "OPTION_TOOLTIP_GRAPHICS_QUALITY"
GX.RAID_SPLIT_CVAR = "RAIDsettingsEnabled"
GX.RECOMMENDED     = G("VIDEO_OPTIONS_RECOMMENDED", "Recommended")

-- "Graphics Quality" block. Sliders are 0-9 in the CVar and shown 1-10, as Blizzard does.
-- tip = global string of the setting's tooltip; option = { value, label, tipGlobal, warnGlobal }.
-- minPreset: Blizzard never lets the preset slider push this one below that value.
GX.QUALITY = {
    { cvar = "graphicsShadowQuality", label = G("SHADOW_QUALITY", "Shadow Quality"), tip = "OPTION_TOOLTIP_SHADOW_QUALITY",
      opts = { {0, LOW, "VIDEO_OPTIONS_SHADOW_QUALITY_LOW"}, {1, FAIR, "VIDEO_OPTIONS_SHADOW_QUALITY_FAIR"},
               {2, MEDIUM, "VIDEO_OPTIONS_SHADOW_QUALITY_MEDIUM"}, {3, HIGH, "VIDEO_OPTIONS_SHADOW_QUALITY_HIGH"},
               {4, ULTRA, "VIDEO_OPTIONS_SHADOW_QUALITY_ULTRA"}, {5, UHIGH, "VIDEO_OPTIONS_SHADOW_QUALITY_ULTRA_HIGH"} } },
    { cvar = "graphicsLiquidDetail", label = G("LIQUID_DETAIL", "Liquid Detail"), tip = "OPTION_TOOLTIP_LIQUID_DETAIL",
      opts = { {0, LOW, "VIDEO_OPTIONS_LIQUID_DETAIL_LOW"}, {1, FAIR, "VIDEO_OPTIONS_LIQUID_DETAIL_FAIR"},
               {2, MEDIUM, "VIDEO_OPTIONS_LIQUID_DETAIL_MEDIUM"}, {3, HIGH, "VIDEO_OPTIONS_LIQUID_DETAIL_ULTRA"} } },
    { cvar = "graphicsParticleDensity", label = G("PARTICLE_DENSITY", "Particle Density"), tip = "OPTION_TOOLTIP_PARTICLE_DENSITY",
      minPreset = 1,
      opts = { {0, OFF, nil, COMBAT_CUES_WARN}, {1, LOW}, {2, FAIR}, {3, MEDIUM}, {4, HIGH}, {5, ULTRA} } },
    { cvar = "graphicsSSAO", label = G("SSAO_LABEL", "SSAO"), tip = "OPTION_TOOLTIP_SSAO",
      opts = { {0, OFF}, {1, LOW}, {2, MEDIUM}, {3, HIGH}, {4, ULTRA} } },
    { cvar = "graphicsDepthEffects", label = G("DEPTH_EFFECTS", "Depth Effects"), tip = "OPTION_TOOLTIP_DEPTH_EFFECTS",
      opts = { {0, OFF, "VIDEO_OPTIONS_DEPTH_EFFECTS_DISABLED"}, {1, LOW, "VIDEO_OPTIONS_DEPTH_EFFECTS_LOW"},
               {2, MEDIUM, "VIDEO_OPTIONS_DEPTH_EFFECTS_MEDIUM"}, {3, HIGH, "VIDEO_OPTIONS_DEPTH_EFFECTS_HIGH"} } },
    { cvar = "graphicsComputeEffects", label = G("COMPUTE_EFFECTS", "Compute Effects"), tip = "OPTION_TOOLTIP_COMPUTE_EFFECTS",
      opts = { {0, OFF, "VIDEO_OPTIONS_COMPUTE_EFFECTS_DISABLED"}, {1, LOW, "VIDEO_OPTIONS_COMPUTE_EFFECTS_LOW"},
               {2, MEDIUM, "VIDEO_OPTIONS_COMPUTE_EFFECTS_MEDIUM"}, {3, HIGH, "VIDEO_OPTIONS_COMPUTE_EFFECTS_HIGH"},
               {4, ULTRA, "VIDEO_OPTIONS_COMPUTE_EFFECTS_ULTRA"} } },
    { cvar = "graphicsOutlineMode", label = G("OUTLINE_MODE", "Outline Mode"), tip = "OPTION_TOOLTIP_OUTLINE_MODE",
      opts = { {0, OFF}, {1, MEDIUM}, {2, HIGH} } },
    { cvar = "graphicsTextureResolution", label = G("TEXTURE_DETAIL", "Texture Resolution"), tip = "OPTION_TOOLTIP_TEXTURE_DETAIL",
      opts = { {0, LOW, "VIDEO_OPTIONS_TEXTURE_DETAIL_LOW"}, {1, FAIR, "VIDEO_OPTIONS_TEXTURE_DETAIL_FAIR"},
               {2, HIGH, "VIDEO_OPTIONS_TEXTURE_DETAIL_HIGH"} } },
    { cvar = "graphicsSpellDensity", label = G("SPELL_DENSITY", "Spell Density"), tip = "OPTION_TOOLTIP_SPELL_DENSITY",
      needsSpellDensity = true,
      opts = { {0, G("VIDEO_OPTIONS_SFX_DENSITY_MIN", "Essential"), "VIDEO_OPTIONS_SFX_DENSITY_MIN_TOOLTIP"},
               {1, G("VIDEO_OPTIONS_SFX_DENSITY_REDUCED", "Reduced"), "VIDEO_OPTIONS_SFX_DENSITY_REDUCED_TOOLTIP"},
               {2, G("VIDEO_OPTIONS_SFX_DENSITY_FULL", "Everything"), "VIDEO_OPTIONS_SFX_DENSITY_FULL_TOOLTIP"} } },
    { cvar = "graphicsProjectedTextures", label = G("PROJECTED_TEXTURES", "Projected Textures"), tip = "OPTION_TOOLTIP_PROJECTED_TEXTURES",
      opts = { {0, OFF, nil, COMBAT_CUES_WARN}, {1, ON} } },
    { cvar = "graphicsViewDistance", label = G("FARCLIP", "View Distance"), tip = "OPTION_TOOLTIP_FARCLIP", slider = true },
    { cvar = "graphicsEnvironmentDetail", label = G("ENVIRONMENT_DETAIL", "Environment Detail"), tip = "OPTION_TOOLTIP_ENVIRONMENT_DETAIL", slider = true },
    { cvar = "graphicsGroundClutter", label = G("GROUND_CLUTTER", "Ground Clutter"), tip = "OPTION_TOOLTIP_GROUND_CLUTTER", slider = true },
}
-- Blizzard marks the hardware-detected default as "Recommended" in this block only.
for _, def in ipairs(GX.QUALITY) do def.recommend = true end

-- Optional extras from the rest of the Graphics page. Absent from a profile = not touched.
GX.EXTRAS = {
    { cvar = "shadowrt", label = G("RT_SHADOW_QUALITY", "Ray Traced Shadows"), tip = "OPTION_TOOLTIP_RT_SHADOW_QUALITY",
      opts = { {0, OFF}, {1, FAIR, "VIDEO_OPTIONS_RT_SHADOW_QUALITY_FAIR"}, {2, MEDIUM, "VIDEO_OPTIONS_RT_SHADOW_QUALITY_MEDIUM"},
               {3, HIGH, "VIDEO_OPTIONS_RT_SHADOW_QUALITY_HIGH"} } },
    { cvar = "textureFilteringMode", label = G("ANISOTROPIC", "Texture Filtering"), tip = "OPTION_TOOLTIP_ANISOTROPIC",
      opts = { {0, G("VIDEO_OPTIONS_BILINEAR", "Bilinear")}, {1, G("VIDEO_OPTIONS_TRILINEAR", "Trilinear")},
               {2, G("VIDEO_OPTIONS_2XANISOTROPIC", "2x Anisotropic")}, {3, G("VIDEO_OPTIONS_4XANISOTROPIC", "4x Anisotropic")},
               {4, G("VIDEO_OPTIONS_8XANISOTROPIC", "8x Anisotropic")}, {5, G("VIDEO_OPTIONS_16XANISOTROPIC", "16x Anisotropic")} } },
    { cvar = "ResampleQuality", label = G("RESAMPLE_QUALITY", "Resample Quality"), tip = "OPTION_TOOLTIP_RESAMPLE_QUALITY", noValidate = true,
      opts = { {0, G("RESAMPLE_QUALITY_POINT", "Point"), "VIDEO_OPTIONS_RESAMPLE_QUALITY_POINT"},
               {1, G("RESAMPLE_QUALITY_BILINEAR", "Bilinear"), "VIDEO_OPTIONS_RESAMPLE_QUALITY_BILINEAR"},
               {2, G("RESAMPLE_QUALITY_BICUBIC", "Bicubic"), "VIDEO_OPTIONS_RESAMPLE_QUALITY_BICUBIC"},
               {3, G("RESAMPLE_QUALITY_FSR", "AMD FSR 1.0"), "VIDEO_OPTIONS_RESAMPLE_QUALITY_FSR"} } },
    { cvar = "vrsValar", label = G("VRS_MODE", "Variable Rate Shading"), tip = "OPTION_TOOLTIP_VRS_MODE",
      opts = { {0, OFF}, {1, G("VIDEO_OPTIONS_STANDARD", "Standard"), "OPTION_TOOLTIP_VRS_STANDARD"},
               {2, G("VIDEO_OPTIONS_AGGRESSIVE", "Aggressive"), "OPTION_TOOLTIP_VRS_AGGRESSIVE"} } },
}
GX.RENDER_SCALE_LABEL = G("RENDER_SCALE", "Render Scale")
GX.RENDER_SCALE_TIP   = "OPTION_TOOLTIP_RENDER_SCALE"
GX.MAXFPS_LABEL       = G("MAXFPS", "Max Foreground FPS")
GX.MAXFPS_TIP         = "OPTION_MAXFPS_CHECK"

-------------------------------------------------------------------------------
--  Support checks
-------------------------------------------------------------------------------
local function CVarExists(cvar) return C_CVar.GetCVar(cvar) ~= nil end

-- Blizzard indexes an error-message list with the result: anything but a positive
-- number means "supported".
local function IsErr(err) return type(err) == "number" and err > 0 end

function GX.IsQualityValueSupported(cvar, value)
    if not IsGraphicsSettingValueSupported then return true end
    local ok, err = pcall(IsGraphicsSettingValueSupported, cvar, value, false)
    return not (ok and IsErr(err))
end

function GX.IsCVarValueSupported(cvar, value)
    if not IsGraphicsCVarValueSupported then return true end
    local ok, err = pcall(IsGraphicsCVarValueSupported, cvar, value)
    return not (ok and IsErr(err))
end

function GX.RecommendedValue(def)
    if not (def.recommend and GetCVarDefault) then return nil end
    return tonumber(GetCVarDefault(def.cvar))
end

-- The quality rows this client has (spell density is hardware gated).
local _qualityList
function GX.QualityList()
    if _qualityList then return _qualityList end
    local spellDensity = C_VideoOptions and C_VideoOptions.IsSpellVisualDensitySystemSupported
        and C_VideoOptions.IsSpellVisualDensitySystemSupported()
    local list = {}
    for _, def in ipairs(GX.QUALITY) do
        if CVarExists(def.cvar) and (not def.needsSpellDensity or spellDensity) then list[#list + 1] = def end
    end
    _qualityList = list
    return list
end

local _extrasList
function GX.ExtrasList()
    if _extrasList then return _extrasList end
    local list = {}
    for _, def in ipairs(GX.EXTRAS) do
        if CVarExists(def.cvar) then list[#list + 1] = def end
    end
    _extrasList = list
    return list
end

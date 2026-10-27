local FNP = FostercareNameplates
if not FNP then return end
local _, ns = ...
local UI = ns.UI
local CD, NP = FNP.NameplateCooldowns, FNP.Nameplates

-- ForgeUI layout (VanillaForge templates/ForgeUI): columns at 28 and 264, and a
-- live plate preview at the top of the right column on every tab.
local LEFT, RIGHT, SIDE = 28, 264, 208
local panel = UI.Window("FostercareNameplatesSettingsGUI", "FostercareNameplates", 500, 440,
    GetAddOnMetadata("FostercareNameplates", "Version"))

-- Each control adds a sync that shows its saved value and dims it while it
-- cannot take effect. options maps every reset-able key to its default.
local syncs, options = {}, {}
local RefreshPreview

local function Refresh()
    for _, sync in ipairs(syncs) do sync() end
    RefreshPreview()
end

-- Layout-only changes skip re-querying every plate's health, auras and target.
local function Apply(layoutOnly)
    NP:ApplyConfiguration(layoutOnly)
    FNP.RefreshNameplateScale()
    NP:RefreshMarks()
    CD:Refresh()
end

local function Live() return FNP.OwnsNameplates() end
local function Module(title) return function() return Live() and FNP.IsEnabled(title) end end
local Details, Scale, Castbars = Module("Nameplate Details"), Module("Nameplate Scale"), Module("Nameplate Castbar")
local function Cooldowns() return Live() and FNP.IsEnabled("Enemy Nameplate Cooldowns") and CD:IsAvailable() end
local function On(key, fallback) return FNP.GetOverride(key, fallback) == 1 end
local function Both(a, b) return function() return a() and b() end end
local function Set(key, fallback) return function() return On(key, fallback) end end

local function Times(value) return string.format("%.2fx", value) end
local function Percent(value) return math.floor(value * 100 + 0.5) .. "%" end
local function Pixels(value) return value .. " px" end
local function Seconds(value) return value .. " s" end

-- A switch for one feature module (its own saved key, not an override).
local function Feature(page, title, text, tip, y)
    local widget = UI.Switch("FNPOpt_" .. string.gsub(title, " ", ""), page, text, tip, LEFT, y, function(value)
        FostercareNameplates_Config[title] = value and 1 or 0
        local mod = FNP.mods[title]
        if FNP.nameplatesEnabled and mod and mod.enable then mod:enable() end
        Apply(); Refresh()
    end)
    table.insert(syncs, function() UI.Sync(widget, FNP.IsEnabled(title), Live()) end)
end

local function Option(page, key, fallback, text, tip, x, y, needs)
    options[key] = fallback
    local widget = UI.Switch("FNPOpt_" .. key, page, text, tip, x, y, function(value)
        FNP.SetOverride(key, value and 1 or 0); Apply(); Refresh()
    end, x == RIGHT and 172 or nil)
    table.insert(syncs, function() UI.Sync(widget, On(key, fallback), needs()) end)
end

-- Aura icon size and count change which icons exist, so they re-query auras.
local auraKeys = { nameplate_aura_size = true, nameplate_aura_count = true }

local function Slider(page, key, fallback, minimum, maximum, step, text, x, y, needs, format)
    options[key] = fallback
    local slider = UI.Slider("FNPOpt_" .. key, page, text, x, y, SIDE, minimum, maximum, step, function(value)
        FNP.SetOverride(key, value); Apply(not auraKeys[key]); RefreshPreview()
    end, format)
    table.insert(syncs, function()
        UI.SetSlider(slider, FNP.GetNumber(key, fallback, minimum, maximum))
        local on = needs() and true or false
        local alpha = on and 1 or 0.4
        slider:EnableMouse(on); slider:SetAlpha(alpha)
        slider.label:SetAlpha(alpha); slider.valueText:SetAlpha(alpha)
    end)
end

local function Choice(page, key, fallback, values, labels, x, y, needs)
    options[key] = fallback
    local buttons, Select, track = UI.Segmented("FNPOpt_" .. key, page, labels, x, y, SIDE, function(index)
        FNP.SetOverride(key, values[index]); Apply(); Refresh()
    end, { height = 24 })
    table.insert(syncs, function()
        local value, chosen = FNP.GetOverride(key, fallback), 1
        for i, candidate in ipairs(values) do if candidate == value then chosen = i end end
        Select(chosen)
        local on = needs() and true or false
        track:SetAlpha(on and 1 or 0.4)
        for _, button in ipairs(buttons) do if on then button:Enable() else button:Disable() end end
    end)
end

local function Hint(page, text, x, y, width)
    local label = UI.Label(page, text, x, y, "GameFontDisableSmall")
    label:SetWidth(width or SIDE)
    return label
end

local tab = 1
local pages, ShowTab = UI.Tabs(panel, "FNPOpt", {
    { label = "General", height = 440 },
    { label = "Text & auras", height = 470 },
    { label = "Target", height = 466 },
    { label = "Casts", height = 420 },
}, function(index) tab = index; Refresh() end)
panel:SetScript("OnShow", function() ShowTab(tab) end)

-- General -------------------------------------------------------------------
local general = pages[1]
UI.Heading(general, "Nameplates", LEFT, -98)
local master = UI.Switch("FNPOpt_Master", general, "Use FostercareNameplates",
    "Off keeps Blizzard plates and your target-frame castbar. Takes effect after /reload.", LEFT, -118,
    function(value)
        FostercareNameplates_Config.nameplatesEnabled = value and 1 or 0
        Refresh()
    end)
UI.Heading(general, "Features", LEFT, -160)
Feature(general, "Nameplate Scale", "Resize plates", "Plate and castbar size.", -180)
Feature(general, "Nameplate Details", "Target, text, auras and marks",
    "Target emphasis, health and level text, auras, combo points, raid marks and fading.", -206)
Feature(general, "Nameplate Class Colors", "Class colors for players", "Color enemy and friendly player bars by class.", -232)
Feature(general, "Nameplate Castbar", "Enemy castbars", "A castbar under each casting enemy.", -258)
Feature(general, "Enemy Nameplate Cooldowns", "Enemy cooldowns",
    "Icons for cooldowns seen used by enemy players. Needs NamPower 4.6.2+.", -284)
UI.Heading(general, "Size", RIGHT, -258)
Slider(general, "nameplate_scale", 1, 0.1, 4, 0.05, "Plate size", RIGHT, -278, Scale, Times)
Option(general, "nameplate_follow_ui", 0, "Follow UI scale", "Multiply plate size by the game's UI scale.",
    RIGHT, -322, Scale)
local status = Hint(general, "", LEFT, -362, 444)
local reset = UI.Button("FNPOpt_Reset", general, "Reset settings", 0, 0, 172, function()
    for key, fallback in pairs(options) do FNP.SetOverride(key, fallback) end
    Apply(); Refresh()
end)
reset:ClearAllPoints(); reset:SetPoint("BOTTOMLEFT", general, "BOTTOMLEFT", LEFT, 18)
UI.Tooltip(reset, "Restore every option to its default. Feature switches stay as they are.")
table.insert(syncs, function()
    local enabled = FostercareNameplates_Config.nameplatesEnabled ~= 0
    UI.Sync(master, enabled)
    local text = ""
    if enabled ~= FNP.nameplatesEnabled then text = "Type /reload to apply."
    elseif not enabled then text = "Off: Blizzard plates are in use."
    elseif not Live() then text = "BlizzNameplatesPlus or ShaguPlates owns the plates."
    elseif not CD:IsAvailable() then text = "Enemy cooldowns need NamPower 4.6.2+." end
    status:SetText(text)
end)

-- Text & auras ----------------------------------------------------------------
local words = pages[2]
UI.Heading(words, "Health text", LEFT, -98)
Choice(words, "nameplate_health", 1, { 0, 1, 2, 3 }, { "Off", "%", "Value", "Both" }, LEFT, -118, Details)
Option(words, "nameplate_health_target", 1, "Only on your target", nil, LEFT, -152,
    function() return Details() and FNP.GetNumber("nameplate_health", 1, 0, 3) > 0 end)
UI.Heading(words, "On the plate", LEFT, -192)
Option(words, "nameplate_level", 1, "Level in the level slot",
    "Sized with the plate and colored by difficulty. Off shows the game's own level.", LEFT, -212, Details)
Option(words, "nameplate_combo", 1, "Combo points on your target", nil, LEFT, -238, Details)
Option(words, "nameplate_targeting", 0, "Label NPCs targeting you", "Hostile NPCs whose target is you. Targeting, not threat.", LEFT, -264, Details)
UI.Heading(words, "Raid marks", LEFT, -304)
Option(words, "nameplate_marks", 1, "Move raid marks", "Off leaves marks where the game puts them.", LEFT, -324, Details)
local marks = Both(Details, Set("nameplate_marks", 1))
Slider(words, "nameplate_raidmark_size", 20, 12, 40, 1, "Mark size", LEFT, -356, marks, Pixels)
Choice(words, "nameplate_raidmark_position", "left", { "left", "above", "right" }, { "Left", "Above", "Right" },
    LEFT, -400, marks)
UI.Heading(words, "Auras", RIGHT, -258)
Option(words, "nameplate_own_auras", 1, "Your debuffs", "Including your pet's.", RIGHT, -278, Details)
Option(words, "nameplate_cc", 1, "Crowd control", "One crowd-control effect from any caster.", RIGHT, -304, Details)
Option(words, "nameplate_enemy_buffs", 0, "Enemy buffs", "Up to two buffs on enemies.", RIGHT, -330, Details)
Slider(words, "nameplate_aura_count", 3, 1, 6, 1, "Most debuffs", RIGHT, -360,
    Both(Details, Set("nameplate_own_auras", 1)))
Slider(words, "nameplate_aura_size", 20, 14, 32, 1, "Icon size", RIGHT, -402, function()
    return Details() and (On("nameplate_own_auras", 1) or On("nameplate_cc", 1) or On("nameplate_enemy_buffs", 0))
end, Pixels)

-- Target ----------------------------------------------------------------------
local target = pages[3]
UI.Heading(target, "Your target", LEFT, -98)
Option(target, "nameplate_target_glow", 0, "Warm glow", nil, LEFT, -118, Details)
Slider(target, "nameplate_target_scale", 1.1, 1, 1.5, 0.05, "Target size", LEFT, -150, Both(Details, Scale), Times)
Slider(target, "nameplate_other_alpha", 0.8, 0.2, 1, 0.05, "Other plates", LEFT, -192, Details, Percent)
UI.Heading(target, "Fade", LEFT, -244)
Option(target, "nameplate_fade_critters", 0, "Critters", nil, LEFT, -264, Details)
Option(target, "nameplate_fade_totems", 0, "Totems", nil, LEFT, -290, Details)
Option(target, "nameplate_fade_pets", 0, "Pets and guardians", "Other players' pets, guardians and totems.", LEFT, -316, Details)
Option(target, "nameplate_fade_trivial", 0, "Grey-level enemies", nil, LEFT, -342, Details)
Option(target, "nameplate_fade_neutral", 0, "Idle neutral units", "Neutral units not in combat.", LEFT, -368, Details)
Slider(target, "nameplate_fade_alpha", 0.3, 0.1, 0.8, 0.05, "Faded plates", LEFT, -400, function()
    return Details() and (On("nameplate_fade_critters", 0) or On("nameplate_fade_totems", 0) or On("nameplate_fade_pets", 0)
        or On("nameplate_fade_trivial", 0) or On("nameplate_fade_neutral", 0))
end, Percent)
Hint(target, "Your target and marked units never fade. Faded plates stay clickable.", RIGHT, -258)

-- Casts -----------------------------------------------------------------------
local casts = pages[4]
UI.Heading(casts, "Castbars", LEFT, -98)
Option(casts, "nameplate_uninterruptible", 1, "Grey when uninterruptible", nil, LEFT, -118, Castbars)
Slider(casts, "nameplate_cast_height", 10, 6, 18, 1, "Height", LEFT, -150, Castbars, Pixels)
Slider(casts, "nameplate_cast_gap", 3, 0, 16, 1, "Gap below bar", LEFT, -192, Castbars, Pixels)
UI.Heading(casts, "Enemy cooldowns", LEFT, -244)
Option(casts, "nameplate_cd_target", 0, "Only on your target", nil, LEFT, -264, Cooldowns)
Slider(casts, "nameplate_cd_size", 22, 14, 40, 1, "Icon size", LEFT, -296, Cooldowns, Pixels)
Slider(casts, "nameplate_cd_count", 5, 1, 8, 1, "Most icons", LEFT, -338, Cooldowns)
Slider(casts, "nameplate_cd_minimum", 5, 5, 120, 1, "Shortest cooldown", RIGHT, -258, Cooldowns, Seconds)
Slider(casts, "nameplate_cd_offset", 8, 0, 60, 1, "Space above auras", RIGHT, -300, Cooldowns, Pixels)
Hint(casts, "Seen enemy players only. ~ marks an estimate: talents and resets can change it.", RIGHT, -342)

-- Preview -----------------------------------------------------------------------
-- A sample enemy on every tab; sizes follow the settings, capped to fit.
UI.Heading(panel, "Preview", RIGHT, -98)
local box = CreateFrame("Frame", nil, panel); box:EnableMouse(false)
box:SetWidth(SIDE); box:SetHeight(130); box:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT, -116)
UI.Rounded(box, "BACKGROUND", 10, UI.track)
local preview = CreateFrame("Frame", nil, box); preview:EnableMouse(false)
preview:SetWidth(110); preview:SetHeight(14); preview:SetPoint("CENTER", box, "CENTER", -8, -16)
local bar = CreateFrame("StatusBar", nil, preview); bar:EnableMouse(false); bar:SetAllPoints(preview)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetMinMaxValues(0, 100); bar:SetValue(72)
local border = bar:CreateTexture(nil, "ARTWORK"); border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
border:SetPoint("CENTER", bar, "CENTER", 0, 0); border:SetWidth(128); border:SetHeight(16)
local glow = bar:CreateTexture(nil, "BORDER")
glow:SetTexture("Interface\\Tooltips\\Nameplate-Glow"); glow:SetAllPoints(border)
glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.8, 0.3, 0.7)
local top = CreateFrame("Frame", nil, bar); top:SetAllPoints(bar)
local name = top:CreateFontString(nil, "OVERLAY"); name:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
name:SetPoint("BOTTOM", bar, "TOP", 0, 3); name:SetText("Enemy player")
local health = top:CreateFontString(nil, "OVERLAY"); health:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
health:SetPoint("CENTER", bar, "CENTER", 0, 0)
local level = top:CreateFontString(nil, "OVERLAY"); level:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
level:SetPoint("CENTER", bar, "RIGHT", 11, 0); level:SetText("60"); level:SetTextColor(1, 0.82, 0)
local mark = top:CreateTexture(nil, "OVERLAY"); mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
SetRaidTargetIconTexture(mark, 8)
local aura = top:CreateTexture(nil, "ARTWORK"); aura:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowWordPain")
local combo = CreateFrame("Frame", nil, top); combo:SetWidth(24); combo:SetHeight(6)
for i = 1, 3 do
    local pip = combo:CreateTexture(nil, "OVERLAY"); pip:SetTexture(1, 0.75, 0.15, 1)
    pip:SetWidth(6); pip:SetHeight(6); pip:SetPoint("LEFT", combo, "LEFT", (i - 1) * 9, 0)
end
local cast = CreateFrame("StatusBar", nil, preview); cast:EnableMouse(false)
cast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); cast:SetStatusBarColor(1, 0.8, 0)
cast:SetMinMaxValues(0, 1); cast:SetValue(0.6)
local castText = cast:CreateFontString(nil, "OVERLAY"); castText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
castText:SetPoint("CENTER", cast, "CENTER", 0, 0); castText:SetText("Fireball")

local function Shown(region, shown) if shown then region:Show() else region:Hide() end end

RefreshPreview = function()
    local detail, scaled = FNP.IsEnabled("Nameplate Details"), FNP.IsEnabled("Nameplate Scale")
    local size = scaled and FNP.GetNumber("nameplate_scale", 1, 0.1, 4) or 1
    if scaled and FNP.GetOverride("nameplate_follow_ui", 0) == 1 then size = size * UIParent:GetScale() end
    if scaled and detail then size = size * FNP.GetNumber("nameplate_target_scale", 1.1, 1, 1.5) end
    size = math.min(1.5, size)
    preview:SetScale(size)
    -- Names keep their stock size on real plates.
    FNP.SetNameplateFontSize(name, 10 / size)
    local color = FNP.IsEnabled("Nameplate Class Colors") and RAID_CLASS_COLORS.MAGE or { r = 1, g = 0, b = 0 }
    bar:SetStatusBarColor(color.r, color.g, color.b)
    local mode = detail and FNP.GetNumber("nameplate_health", 1, 0, 3) or 0
    health:SetText(mode == 0 and "" or (mode == 1 and "72%" or (mode == 2 and "3.6k" or "3.6k  72%")))
    Shown(level, detail and FNP.GetOverride("nameplate_level", 1) == 1)
    local marks = detail and FNP.GetOverride("nameplate_marks", 1) == 1
    local markSize = marks and FNP.GetNumber("nameplate_raidmark_size", 20, 12, 40) / size or 20
    mark:SetWidth(markSize); mark:SetHeight(markSize); mark:ClearAllPoints()
    local position = marks and FNP.GetOverride("nameplate_raidmark_position", "left") or "above"
    if position == "above" then mark:SetPoint("BOTTOM", name, "TOP", 0, 4)
    elseif position == "right" then mark:SetPoint("LEFT", bar, "RIGHT", 18, 0)
    else mark:SetPoint("RIGHT", bar, "LEFT", -4, 0) end
    local y = position == "above" and markSize + 10 or 6
    combo:ClearAllPoints(); combo:SetPoint("BOTTOM", name, "TOP", 0, y)
    if detail and FNP.GetOverride("nameplate_combo", 1) == 1 then combo:Show(); y = y + 10 else combo:Hide() end
    local auraSize = FNP.GetNumber("nameplate_aura_size", 20, 14, 32) / size
    aura:SetWidth(auraSize); aura:SetHeight(auraSize); aura:ClearAllPoints()
    aura:SetPoint("BOTTOM", name, "TOP", 0, y)
    Shown(aura, detail and (FNP.GetOverride("nameplate_own_auras", 1) == 1 or FNP.GetOverride("nameplate_cc", 1) == 1
        or FNP.GetOverride("nameplate_enemy_buffs", 0) == 1))
    cast:SetWidth(88); cast:SetHeight(FNP.GetNumber("nameplate_cast_height", 10, 6, 18))
    cast:ClearAllPoints(); cast:SetPoint("TOP", bar, "BOTTOM", 8, -FNP.GetNumber("nameplate_cast_gap", 3, 0, 16))
    Shown(cast, FNP.IsEnabled("Nameplate Castbar"))
    Shown(glow, detail and FNP.GetOverride("nameplate_target_glow", 0) == 1)
end

-- Game Menu > AddOn Options > FostercareNameplates (ClassicAPI).
local entry = CreateFrame("Frame", "FostercareNameplatesOptionsEntry")
entry.name = "FostercareNameplates"
local entryTitle = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
entryTitle:SetPoint("TOPLEFT", entry, "TOPLEFT", 16, -16)
entryTitle:SetText("FostercareNameplates")
local entryText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
entryText:SetPoint("TOPLEFT", entryTitle, "BOTTOMLEFT", 0, -8)
entryText:SetText("Settings open in their own window. Type /fnp to open them at any time.")
UI.Select(UI.Button("FostercareNameplatesOptionsOpen", entry, "Open settings", 16, -70, 172, function()
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
    if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
    panel:Show()
end), true)
InterfaceOptions_AddCategory(entry)

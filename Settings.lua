local FNP = FostercareNameplates
if not FNP then return end
local settings = CreateFrame("Frame", "FostercareNameplatesSettingsGUI", UIParent)
settings:Hide()
table.insert(UISpecialFrames, "FostercareNameplatesSettingsGUI")
settings:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
settings:SetWidth(540)
settings:SetFrameStrata("DIALOG")
settings:SetMovable(true)
settings:SetClampedToScreen(true)
settings:EnableMouse(true)
settings:RegisterForDrag("LeftButton")
settings:SetScript("OnDragStart", function() this:StartMoving() end)
settings:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
FNP.SettingsTheme.Panel(settings, "background")
local title = FNP.SettingsTheme.Font(settings, "OVERLAY", "GameFontNormalLarge", "accent")
title:SetPoint("TOP", settings, "TOP", 0, -12)
title:SetText("FostercareNameplates")
local close = CreateFrame("Button", "FNPSettingsClose", settings, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", settings, "TOPRIGHT", -6, -6)
close:SetScript("OnClick", function() settings:Hide() end)
local done = CreateFrame("Button", "FNPSettingsDone", settings, "UIPanelButtonTemplate")
done:SetPoint("BOTTOMRIGHT", settings, "BOTTOMRIGHT", -16, 14)
done:SetWidth(96); done:SetHeight(24); done:SetText(CLOSE)
FNP.SettingsTheme.Button(done)
done:SetScript("OnClick", function() settings:Hide() end)
local function Resize()
    settings:SetHeight(math.min(600, math.max(240, UIParent:GetHeight() - 40)))
end
settings:RegisterEvent("UI_SCALE_CHANGED")
FNP.SetEventHandler(settings, Resize)
Resize()

local Theme, CD, NP = FNP.SettingsTheme, FNP.NameplateCooldowns, FNP.Nameplates
local page = CreateFrame("ScrollFrame", "FNPNameplateSettingsPage", settings, "UIPanelScrollFrameTemplate")
page:SetPoint("TOPLEFT", settings, "TOPLEFT", 14, -42)
page:SetPoint("BOTTOMRIGHT", settings, "BOTTOMRIGHT", -34, 48)
settings.nameplatePage = page
local content = CreateFrame("Frame", "FNPNameplateSettingsContent", page)
content:SetWidth(492); page:SetScrollChild(content); Theme.Panel(content)
local controls, refreshing, y = {}, nil, -14
page.controls = controls
local function Text(text, role, height)
    local label = Theme.Font(content, "OVERLAY", "GameFontNormalSmall", role)
    label:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    label:SetWidth(448); label:SetHeight(height or 22); label:SetJustifyH("LEFT"); label:SetText(text)
    y = y - (height or 22) - 8
    return label
end
-- Layout-only changes skip re-querying every plate's health, auras and target.
local function Apply(layoutOnly)
    NP:ApplyConfiguration(layoutOnly)
    FNP.RefreshNameplateScale()
    NP:RefreshMarks()
    CD:Refresh()
end
local function Check(key, title, fallback, moduleTitle)
    local button = CreateFrame("CheckButton", "FNPPlateCheck" .. string.gsub(key, "%W", "_"), content, "OptionsCheckButtonTemplate")
    button:SetWidth(24); button:SetHeight(24); button:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
    Theme.CheckButton(button)
    local label = _G[button:GetName() .. "Text"]
    label:SetText(title); label:SetFontObject("GameFontNormalSmall"); Theme.Text(label)
    button.fallback, button.moduleTitle, button.checkKey = fallback, moduleTitle, key
    button:SetScript("OnClick", function()
        if refreshing then return end
        local value = button:GetChecked() and 1 or 0
        if moduleTitle then
            FostercareNameplates_Config[moduleTitle] = value
            local mod = FNP.mods[moduleTitle]
            if FNP.nameplatesEnabled and mod and mod.enable then mod:enable() end
        else FNP.SetOverride(key, value) end
        Apply(); page:RefreshValues()
    end)
    controls[key] = button; y = y - 28
end
-- Aura icon size and count change which icons exist, so they re-query auras.
local auraKeys = { nameplate_aura_size = true, nameplate_aura_count = true }
local function Slider(key, title, minimum, maximum, step, fallback, suffix)
    y = y - 20
    local slider = CreateFrame("Slider", "FNPPlateSlider" .. key, content, "OptionsSliderTemplate")
    slider:SetWidth(432); slider:SetHeight(16); slider:SetPoint("TOPLEFT", content, "TOPLEFT", 26, y)
    slider:SetMinMaxValues(minimum, maximum); slider:SetValueStep(step); Theme.Slider(slider)
    local name, label = slider:GetName(), _G[slider:GetName() .. "Text"]
    Theme.Text(label); Theme.Text(_G[name .. "Low"], "muted"); Theme.Text(_G[name .. "High"], "muted")
    _G[name .. "Low"]:SetText(minimum .. suffix); _G[name .. "High"]:SetText(maximum .. suffix)
    slider:SetScript("OnValueChanged", function()
        local value = math.floor(slider:GetValue() / step + 0.5) * step
        label:SetText(title .. ": " .. (step < 1 and string.format("%.2f", value) or tostring(value)) .. suffix)
        if not refreshing then FNP.SetOverride(key, value); Apply(not auraKeys[key]); page:RefreshPreview() end
    end)
    controls[key] = slider
    slider.key, slider.fallback, slider.minimum, slider.maximum = key, fallback, minimum, maximum
    y = y - 36
end
local function Choice(key, title, values, labels, fallback)
    local button = CreateFrame("Button", "FNPPlateChoice" .. key, content, "UIPanelButtonTemplate")
    button:SetWidth(286); button:SetHeight(24); button:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
    Theme.Button(button)
    button.choiceKey, button.fallback, button.values, button.labels, button.title = key, fallback, values, labels, title
    button:SetScript("OnClick", function()
        local value, index = FNP.GetOverride(key, fallback), 0
        for i, candidate in ipairs(values) do if candidate == value then index = i end end
        FNP.SetOverride(key, values[index % #values + 1]); Apply(); page:RefreshValues()
    end)
    controls[key] = button; y = y - 34
end

Text("Nameplates", "heading")
local master = CreateFrame("CheckButton", "FNPNameplatesEnabled", content, "OptionsCheckButtonTemplate")
master:SetWidth(24); master:SetHeight(24); master:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
Theme.CheckButton(master)
local masterLabel = _G[master:GetName() .. "Text"]
masterLabel:SetText("Use FostercareNameplates nameplate features")
masterLabel:SetFontObject("GameFontNormalSmall"); Theme.Text(masterLabel)
master:SetScript("OnClick", function()
    FostercareNameplates_Config.nameplatesEnabled = master:GetChecked() and 1 or 0
    page:RefreshValues()
end)
page.master = master; y = y - 28
Text("Type /reload after changing this switch. Off keeps Blizzard plates and your target-frame castbar. Individual feature choices are kept.", "hint", 46)
local ownerNote = Text("", "hint", 32)
Text("The feature settings below apply immediately while enabled.", "hint", 30)
Text("Target preview (size preview capped at 2.5x)", "muted")
local preview = CreateFrame("Frame", nil, content); preview:EnableMouse(false)
preview:SetWidth(110); preview:SetHeight(14); preview:SetPoint("TOP", content, "TOP", 0, y - 110)
local bar = CreateFrame("StatusBar", nil, preview); bar:EnableMouse(false); bar:SetAllPoints(preview)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetMinMaxValues(0, 100); bar:SetValue(72)
local border = bar:CreateTexture(nil, "OVERLAY"); border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
border:SetPoint("CENTER", bar, "CENTER", 0, 0); border:SetWidth(128); border:SetHeight(16)
local name = bar:CreateFontString(nil, "OVERLAY"); name:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
name:SetPoint("BOTTOM", bar, "TOP", 0, 3); name:SetText("Enemy player")
local health = bar:CreateFontString(nil, "OVERLAY"); health:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
health:SetPoint("CENTER", bar, "CENTER", 0, 0)
local mark = bar:CreateTexture(nil, "OVERLAY"); mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
SetRaidTargetIconTexture(mark, 8)
local cast = CreateFrame("StatusBar", nil, preview); cast:EnableMouse(false)
cast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); cast:SetStatusBarColor(1, 0.8, 0)
cast:SetMinMaxValues(0, 1); cast:SetValue(0.6)
local castText = cast:CreateFontString(nil, "OVERLAY"); castText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
castText:SetPoint("CENTER", cast, "CENTER", 0, 0); castText:SetText("Fireball")
local aura = bar:CreateTexture(nil, "ARTWORK"); aura:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowWordPain")
local combo = bar:CreateFontString(nil, "OVERLAY"); combo:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
combo:SetTextColor(1, 0.75, 0.15); combo:SetText("* * *")
local previewGlow = bar:CreateTexture(nil, "BORDER")
previewGlow:SetTexture("Interface\\Tooltips\\Nameplate-Glow"); previewGlow:SetAllPoints(border)
previewGlow:SetBlendMode("ADD")
previewGlow:SetVertexColor(1, 0.8, 0.3, 0.7)
y = y - 220
Text("Size and target emphasis", "heading")
Check("Nameplate Scale", "Adjust plate size", 1, "Nameplate Scale")
Check("Nameplate Details", "Target emphasis, marks and details", 1, "Nameplate Details")
Check("Nameplate Class Colors", "Class colors for players", 1, "Nameplate Class Colors")
Slider("nameplate_scale", "Plate size", 0.1, 4, 0.05, 1, "x")
Check("nameplate_follow_ui", "Multiply plate size by global UI scale", 0)
Text("Names and levels keep their original font size and native ownership.", "hint", 30)
Slider("nameplate_target_scale", "Extra target size", 1, 1.5, 0.05, 1.1, "x")
Slider("nameplate_other_alpha", "Other plates' opacity with a target", 0.2, 1, 0.05, 0.8, "")
Check("nameplate_target_glow", "Warm highlight on your target", 0)
Text("Marked units retain at least 90% opacity. Native clicks and mouseover remain intact.", "hint", 34)
Text("Raid target marks", "heading")
Check("nameplate_marks", "Adjust native raid marks", 1)
Slider("nameplate_raidmark_size", "Mark size", 12, 40, 1, 20, " px")
Choice("nameplate_raidmark_position", "Mark position", {"left", "above", "right"}, {"Left", "Above name", "Right"}, "left")
Text("Turning this off restores the native position; the game still shows raid marks.", "hint", 30)
Text("Health, auras and attention", "heading")
Choice("nameplate_health", "Health text", {0, 1, 2, 3}, {"Off", "Percent", "Health", "Health + percent"}, 1)
Check("nameplate_health_target", "Health text on target only", 1)
Check("nameplate_own_auras", "Your debuffs (including your pet)", 1)
Check("nameplate_cc", "One crowd-control effect, any caster", 1)
Check("nameplate_enemy_buffs", "Also show up to two enemy buffs", 0)
Slider("nameplate_aura_count", "Maximum own debuffs", 1, 6, 1, 3, "")
Slider("nameplate_aura_size", "Aura icon size", 14, 32, 1, 20, " px")
Check("nameplate_combo", "Combo points on your target", 1)
Check("nameplate_targeting", "Label enemies targeting you", 0)
Text("Aura durations come from the client. Effects without known timing have no countdown.", "hint", 34)
Text("Castbars", "heading")
Check("Nameplate Castbar", "Nameplate castbars", 1, "Nameplate Castbar")
Check("nameplate_uninterruptible", "Grey bars for uninterruptible casts", 1)
Slider("nameplate_cast_height", "Castbar height", 6, 18, 1, 10, " px")
Slider("nameplate_cast_gap", "Space below health bar", 0, 16, 1, 3, " px")
Text("Enemy cooldowns", "heading")
Check("cooldowns", "Show estimated enemy cooldowns", 1, "Enemy Nameplate Cooldowns")
Check("nameplate_cd_target", "Cooldowns on target only", 0)
Text("Observed enemy players only. ~ means estimated: talents, resets and server rules can change timers. Items and unobserved abilities are not revealed.", "hint", 48)
Slider("nameplate_cd_size", "Cooldown icon size", 14, 40, 1, 22, " px")
Slider("nameplate_cd_count", "Maximum cooldown icons", 1, 8, 1, 5, "")
Slider("nameplate_cd_minimum", "Minimum base cooldown", 5, 120, 1, 5, " s")
Slider("nameplate_cd_offset", "Extra space above aura row", 0, 60, 1, 8, " px")
local reset = CreateFrame("Button", "FNPNameplatesReset", content, "UIPanelButtonTemplate")
reset:SetWidth(180); reset:SetHeight(24); reset:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
reset:SetText("Reset nameplate settings"); Theme.Button(reset)
reset:SetScript("OnClick", function()
    for _, control in pairs(controls) do
        local key = control.key or control.choiceKey or (not control.moduleTitle and control.checkKey)
        if key then FNP.SetOverride(key, control.fallback) end
    end
    Apply(); page:RefreshValues()
end)
controls.reset = reset; y = y - 36
Text("Module enable choices are kept. Enemy cooldowns require NamPower 4.6.2+.", "hint", 34)
content:SetHeight(-y + 18)

function page:RefreshPreview()
    local detail = FNP.IsEnabled("Nameplate Details")
    local size = FNP.IsEnabled("Nameplate Scale") and FNP.GetNumber("nameplate_scale", 1, 0.1, 4) or 1
    if FNP.IsEnabled("Nameplate Scale") then
        if FNP.GetOverride("nameplate_follow_ui", 0) == 1 then size = size * UIParent:GetScale() end
        if detail then size = size * FNP.GetNumber("nameplate_target_scale", 1.1, 1, 1.5) end
    end
    preview:SetScale(math.min(2.5, size))
    FNP.SetNameplateFontSize(name, 10 / math.min(2.5, size))
    local color = FNP.IsEnabled("Nameplate Class Colors") and RAID_CLASS_COLORS.MAGE or {r=1,g=0,b=0}
    bar:SetStatusBarColor(color.r, color.g, color.b)
    local mode = detail and FNP.GetNumber("nameplate_health", 1, 0, 3) or 0
    health:SetText(mode == 0 and "" or (mode == 1 and "72%" or (mode == 2 and "3.6k" or "3.6k  72%")))
    local marks = detail and FNP.GetOverride("nameplate_marks", 1) == 1
    local markSize = marks and FNP.GetNumber("nameplate_raidmark_size", 20, 12, 40) / size or 20
    mark:SetWidth(markSize); mark:SetHeight(markSize); mark:ClearAllPoints()
    local pos = marks and FNP.GetOverride("nameplate_raidmark_position", "left") or "above"
    if pos == "above" then mark:SetPoint("BOTTOM", name, "TOP", 0, 4)
    elseif pos == "right" then mark:SetPoint("LEFT", bar, "RIGHT", 18, 0)
    else mark:SetPoint("RIGHT", bar, "LEFT", -4, 0) end
    local top = pos == "above" and markSize + 10 or 6
    combo:ClearAllPoints(); combo:SetPoint("BOTTOM", name, "TOP", 0, top)
    if detail and FNP.GetOverride("nameplate_combo", 1) == 1 then combo:Show(); top = top + 10 else combo:Hide() end
    local auraSize = FNP.GetNumber("nameplate_aura_size", 20, 14, 32) / size
    aura:SetWidth(auraSize); aura:SetHeight(auraSize); aura:ClearAllPoints()
    aura:SetPoint("BOTTOM", name, "TOP", 0, top)
    if detail and (FNP.GetOverride("nameplate_own_auras", 1) == 1 or FNP.GetOverride("nameplate_cc", 1) == 1
        or FNP.GetOverride("nameplate_enemy_buffs", 0) == 1) then aura:Show() else aura:Hide() end
    cast:SetWidth(88); cast:SetHeight(FNP.GetNumber("nameplate_cast_height", 10, 6, 18))
    cast:ClearAllPoints(); cast:SetPoint("TOP", bar, "BOTTOM", 8, -FNP.GetNumber("nameplate_cast_gap", 3, 0, 16))
    if FNP.IsEnabled("Nameplate Castbar") then cast:Show() else cast:Hide() end
    if detail and FNP.GetOverride("nameplate_target_glow", 0) == 1 then previewGlow:Show() else previewGlow:Hide() end
end
function page:RefreshValues()
    refreshing = true
    local enabled = FostercareNameplates_Config.nameplatesEnabled ~= 0
    master:SetChecked(enabled)
    for _, control in pairs(controls) do
        if control.key then control:SetValue(FNP.GetNumber(control.key, control.fallback, control.minimum, control.maximum))
        elseif control.checkKey then
            control:SetChecked(control.moduleTitle and FNP.IsEnabled(control.moduleTitle)
                or (not control.moduleTitle and FNP.GetOverride(control.checkKey, control.fallback) == 1))
        elseif control.choiceKey then
            local value, label = FNP.GetOverride(control.choiceKey, control.fallback), control.labels[1]
            for i, candidate in ipairs(control.values) do if candidate == value then label = control.labels[i] end end
            control:SetText(control.title .. ": " .. label)
        end
    end
    if enabled ~= FNP.nameplatesEnabled then ownerNote:SetText("Type /reload to apply your nameplate feature choice.")
    elseif not enabled then ownerNote:SetText("Blizzard plates are active. FostercareNameplates nameplate features are inactive.")
    elseif FNP.legacyOwner then ownerNote:SetText("Update FostercareTweaks to 1.3.0+ and restart. Its older nameplate system is still active.")
    elseif not FNP.OwnsNameplates() then ownerNote:SetText("BlizzNameplatesPlus or ShaguPlates owns the plates. These settings stay inactive.")
    elseif not CD:IsAvailable() then ownerNote:SetText("Enemy cooldowns need NamPower 4.6.2+. Other features are available.")
    else ownerNote:SetText("Select a target for health and combo points. The preview shows sample values.") end
    refreshing = nil; self:RefreshPreview()
end

settings:SetScript("OnShow", function() Resize(); page:RefreshValues() end)

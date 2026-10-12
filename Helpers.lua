local FNP = FostercareNameplates
if not FNP then return end

-- Traverse frame returns without constructing a temporary region array.
local function RegionWalk(idx, callback, arg1, arg2, arg3, r, ...)
    if not r then return end
    callback(r, idx, arg1, arg2, arg3)
    return RegionWalk(idx + 1, callback, arg1, arg2, arg3, ...)
end

FNP.ForEachRegion = function(frame, callback, arg1, arg2, arg3)
    if frame and frame.GetRegions and callback then
        RegionWalk(1, callback, arg1, arg2, arg3, frame:GetRegions())
    end
end

-- ClassicAPI HookScript invokes the previous script without positional args.
-- Preserve modern owners too: forward the original call to them, and normalize
-- only our posthook. Native FrameXML still receives its original globals.
FNP.HookScript = function(frame, script, func)
    if not frame or not func then return end
    local previous = frame:GetScript(script)
    frame:SetScript(script, function(...)
        if previous then previous(...) end
        if script == "OnEvent" then
            return func(frame, FNP.EventArgs(...))
        elseif select(1, ...) == frame then
            return func(...)
        end
        return func(frame, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    end)
end

-- ClassicAPI may dispatch positional arguments or native globals. Decode once
-- at the event boundary; module logic always receives (frame, event, payload).
function FNP.EventArgs(first, second, ...)
    if type(first) == "table" then return second, ... end
    if type(first) == "string" then return first, second, ... end
    return event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
end

function FNP.SetEventHandler(frame, handler)
    frame:SetScript("OnEvent", function(...)
        return handler(frame, FNP.EventArgs(...))
    end)
end

function FNP.IsEnabled(key, default)
    local value = FostercareNameplates_Config[key]
    if value == nil then
        local module = FNP.mods[key]
        if module then return module.enabled == true end
        return default == true
    end
    return value == 1
end

function FNP.GetOverride(key, default)
    local value = FostercareNameplates_Config.overwrites[key]
    if value == nil then value = FNP.overwrites and FNP.overwrites[key] end
    if value == nil then return default end
    return value
end

function FNP.ClampNumber(input, default, minimum, maximum)
    local value = tonumber(input)
    if not value or value ~= value or value == math.huge or value == -math.huge then value = default end
    return math.max(minimum, math.min(maximum, value))
end

function FNP.GetNumber(key, default, minimum, maximum)
    return FNP.ClampNumber(FNP.GetOverride(key), default, minimum, maximum)
end

-- Native 1.12 FontStrings have no Frame GetScale/SetScale methods.
-- Use this only for addon-owned labels. Engine-owned name/level text scales
-- independently in the native renderer; preserve both font and parent ownership.
function FNP.SetNameplateFontSize(text, size)
    if not text then return end
    local font, current, flags = text:GetFont()
    size = math.max(1, math.floor(size + 0.5))
    if font and current ~= size then text:SetFont(font, size, flags) end
end

function FNP.SetOverride(key, value)
    FostercareNameplates_Config.overwrites[key] = value
    FNP.overwrites = FNP.overwrites or {}
    FNP.overwrites[key] = value
end

-- One palette for all settings pages. These styles touch addon-owned UI
-- only; native font objects and gameplay frames keep their original colors.
local Theme = {
    background = { 0.055, 0.045, 0.075 },
    panel = { 0.10, 0.075, 0.14 },
    control = { 0.14, 0.10, 0.20 },
    selected = { 0.25, 0.18, 0.35 },
    text = { 0.92, 0.90, 1 },
    heading = { 1, 1, 1 },
    muted = { 0.78, 0.75, 0.86 },
    hint = { 0.78, 0.75, 0.86 },
    border = { 0.55, 0.43, 0.72 },
    accent = { 0.78, 0.65, 1 },
}
FNP.SettingsTheme = Theme
local settingsBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}
function Theme.Text(font, role)
    if not font then return end
    local color = Theme[role or "text"]
    font:SetTextColor(color[1], color[2], color[3])
end
function Theme.Font(parent, layer, font, role)
    local text = parent:CreateFontString(nil, layer, font)
    Theme.Text(text, role)
    return text
end
function Theme.Panel(frame, surface)
    frame:SetBackdrop(settingsBackdrop)
    local bg, border = Theme[surface or "panel"], Theme.border
    frame:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
end
function Theme.SelectButton(button, selected)
    local color = selected and Theme.accent or Theme.border
    local bg = selected and Theme.selected or Theme.control
    button:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    button:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    Theme.Text(button:GetFontString(), selected and "heading" or "text")
    -- A visible underline identifies selection without relying on its color.
    if selected and not button.fnpSelectionMark then
        local mark = button:CreateTexture(nil, "OVERLAY")
        mark:SetTexture("Interface\\Buttons\\WHITE8X8")
        mark:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        mark:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4, 3)
        mark:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 3)
        mark:SetHeight(2)
        button.fnpSelectionMark = mark
    end
    if button.fnpSelectionMark then
        if selected then button.fnpSelectionMark:Show() else button.fnpSelectionMark:Hide() end
    end
end
function Theme.Button(button)
    Theme.Panel(button, "control")
    -- Keep the native button's text, state transitions and hit rectangle.
    button:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    button:GetNormalTexture():SetVertexColor(Theme.text[1], Theme.text[2], Theme.text[3], 0.08)
    button:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
    button:GetPushedTexture():SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.18)
    button:SetDisabledTexture("Interface\\Buttons\\WHITE8X8")
    button:GetDisabledTexture():SetVertexColor(Theme.border[1], Theme.border[2], Theme.border[3], 0.04)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(Theme.text[1], Theme.text[2], Theme.text[3], 0.14)
    Theme.SelectButton(button, false)
end
function Theme.CheckButton(button)
    Theme.Button(button)
    -- Keep native checked/disabled state and its checkmark shape.
    button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button:GetCheckedTexture():SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
end
function Theme.Slider(slider)
    local bg, border = Theme.control, Theme.border
    slider:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    slider:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    -- OptionsSliderTemplate names this native thumb; do not replace its input
    -- owner, value, range or 32-pixel artwork with a later-client widget API.
    local name = slider:GetName()
    local thumb = name and _G[name .. "Thumb"]
    if thumb then thumb:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1) end
end

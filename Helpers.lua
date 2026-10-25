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
-- The size we set is cached: GetFont can report a scaled, non-integer height,
-- and re-setting the font on every health update made the text flicker.
function FNP.SetNameplateFontSize(text, size)
    if not text then return end
    size = math.max(1, math.floor(size + 0.5))
    if text.fnpFontSize == size then return end
    local font, _, flags = text:GetFont()
    if font then text:SetFont(font, size, flags); text.fnpFontSize = size end
end

function FNP.SetOverride(key, value)
    FostercareNameplates_Config.overwrites[key] = value
    FNP.overwrites = FNP.overwrites or {}
    FNP.overwrites[key] = value
end

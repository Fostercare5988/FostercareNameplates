local FNP = FostercareNameplates
if not FNP then return end

-- Handlers take fixed parameters, never `...`: in the client's Lua 5.0 a call
-- to a vararg function builds an `arg` table, and plate OnUpdate runs for every
-- plate every frame (about 320 KB/s at 40 plates, audit 2026-10-26).

-- ClassicAPI HookScript invokes the previous script without positional args.
-- Preserve modern owners too: forward the original call to them, and normalize
-- only our posthook. Native FrameXML still receives its original globals.
FNP.HookScript = function(frame, script, func)
    if not frame or not func then return end
    local previous = frame:GetScript(script)
    frame:SetScript(script, function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        if previous then previous(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10) end
        if script == "OnEvent" then
            return func(frame, FNP.EventArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10))
        elseif a1 == frame then
            return func(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        end
        return func(frame, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    end)
end

-- ClassicAPI may dispatch positional arguments or native globals. Decode once
-- at the event boundary; module logic always receives (frame, event, payload).
function FNP.EventArgs(first, second, a3, a4, a5, a6, a7, a8, a9, a10)
    if type(first) == "table" then return second, a3, a4, a5, a6, a7, a8, a9, a10 end
    if type(first) == "string" then return first, second, a3, a4, a5, a6, a7, a8, a9, a10 end
    return event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
end

function FNP.SetEventHandler(frame, handler)
    frame:SetScript("OnEvent", function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        return handler(frame, FNP.EventArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10))
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

local FNP = FostercareNameplates
if not FNP then return end

-- Enemy cast bars. ClassicAPI's cast events, fired for the nameplateN token,
-- say when to ask C_Spell; the bar then fills itself from a duration object
-- (SetTimerDuration), so nothing runs per frame or polls while a unit casts.
local module = FNP:register({
    title = "Nameplate Castbar",
    description = "Adds a castbar to the nameplate based on unit casting information.",
    category = "Nameplates",
    enabled = true,
})
-- "Grey when uninterruptible" was on for every character: always grey now.
FostercareNameplates_Config.overwrites.nameplate_uninterruptible = nil

-- The cast events that fire for other units (ClassicAPI docs, UNIT_SPELLCAST_*).
-- DELAYED and CHANNEL_UPDATE fire only for the player: another unit's pushback
-- is never sent to the client, so its bar cannot move during a cast.
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }
local active, events, ticker
-- Bars showing a cast. Remote cast events are best-effort; a bar whose STOP
-- never came hides at its end time.
local shown = {}

local backdrop = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local function CreateBar(plate)
    local cb = CreateFrame("StatusBar", nil, plate)
    plate.fnpCastbar = cb
    cb:EnableMouse(false)
    cb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    cb:SetStatusBarColor(1, 0.8, 0, 1)
    FNP.HookScript(plate, "OnSizeChanged", function() FNP.LayoutNameplateCastbar(plate) end)

    cb.texture = CreateFrame("Frame", nil, cb)
    cb.texture:EnableMouse(false)
    cb.texture:SetPoint("RIGHT", cb, "LEFT", 0, 0)
    cb.texture.icon = cb.texture:CreateTexture(nil, "BACKGROUND")
    cb.texture.icon:SetPoint("CENTER", 0, 0)
    cb.texture:SetBackdrop(backdrop)
    cb.texture:SetBackdropBorderColor(1, 0.8, 0)

    cb.bg = cb:CreateTexture(nil, "BACKGROUND")
    cb.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    cb.bg:SetVertexColor(0.1, 0.1, 0, 0.8)
    cb.bg:SetAllPoints(true)

    cb.spark = cb:CreateTexture(nil, "OVERLAY")
    cb.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    cb.spark:SetBlendMode("ADD")
    cb.spark:SetPoint("CENTER", cb:GetStatusBarTexture(), "RIGHT", 0, 0)
    cb.timer = C_DurationUtil.CreateDuration()

    cb.backdrop = CreateFrame("Frame", nil, cb)
    cb.backdrop:EnableMouse(false)
    cb.backdrop:SetFrameLevel(cb:GetFrameLevel())
    cb.backdrop:SetPoint("TOPLEFT", cb, "TOPLEFT", -3, 3)
    cb.backdrop:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", 3, -3)
    cb.backdrop:SetBackdrop(backdrop)
    cb.backdrop:SetBackdropBorderColor(1, 0.8, 0)

    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    cb.text:SetPoint("CENTER", cb, "CENTER", 0, 0)

    cb:Hide()
    -- Size, place and font follow the plate's scale (Scaling.lua).
    FNP.LayoutNameplateCastbar(plate)
    FNP.Nameplates:LayoutExtras(plate)
    return cb
end

local function HideBar(cb)
    shown[cb] = nil
    if cb:IsShown() then cb:Hide() end
    cb.lastSpell, cb.lastTexture, cb.lastLocked, cb.lastChannel, cb.endSec = nil, nil, nil, nil, nil
end

local function Backstop()
    local now = GetTime()
    for cb in pairs(shown) do
        if now >= cb.endSec then HideBar(cb) end
    end
    if not next(shown) then ticker:Cancel(); ticker = nil end
end

local function Show(cb, cast, texture, startTime, endTime, notInterruptible, isChannel)
    cb.endSec = endTime / 1000
    cb.timer:SetTimeSpan(startTime / 1000, cb.endSec)
    if cb.lastChannel ~= isChannel then
        cb.lastChannel = isChannel
        cb:SetTimerDuration(cb.timer, Enum.StatusBarInterpolation.Immediate,
            isChannel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
    end
    if not cb:IsShown() then cb:Show() end
    shown[cb] = true
    if not ticker then ticker = C_Timer.NewTicker(0.5, Backstop) end

    -- Grey for a cast you cannot interrupt.
    local locked = notInterruptible and true or false
    if cb.lastLocked ~= locked then
        cb.lastLocked = locked
        local r, g, b = 1, 0.8, 0
        if locked then r, g, b = 0.7, 0.7, 0.7; cb:SetStatusBarColor(0.65, 0.65, 0.65, 1)
        else cb:SetStatusBarColor(1, 0.8, 0, 1) end
        cb.backdrop:SetBackdropBorderColor(r, g, b, 1)
        cb.texture:SetBackdropBorderColor(r, g, b, 1)
    end

    if cb.lastSpell ~= cast then
        cb.lastSpell = cast
        cb.text:SetText(cast)
    end

    if cb.lastTexture ~= texture then
        cb.lastTexture = texture
        if texture then
            cb.texture.icon:SetTexture(texture)
            cb.texture.icon:Show()
        else
            cb.texture.icon:Hide()
        end
    end
end

-- Ask the client what the plate's unit casts. A remote cast has timing only
-- when its start was seen (ClassicAPI docs, C_Spell.UnitCastingInfo).
local function Query(plate)
    local unit, cb = plate.fnpUnitGUID, plate.fnpCastbar
    local cast, texture, startTime, endTime, notInterruptible, _
    local isChannel = false
    if active and unit then
        cast, _, texture, startTime, endTime, _, _, notInterruptible = C_Spell.UnitCastingInfo(unit)
        if not cast then
            cast, _, texture, startTime, endTime, _, notInterruptible = C_Spell.UnitChannelInfo(unit)
            isChannel = cast ~= nil
        end
    end
    if cast and startTime and endTime and endTime > startTime and endTime > GetTime() * 1000 then
        Show(cb or CreateBar(plate), cast, texture, startTime, endTime, notInterruptible, isChannel)
    elseif cb then
        HideBar(cb)
    end
end

local function OnCast(_, _, unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if plate and FNP.libnameplate.plates[plate] then Query(plate) end
end

module.enable = function()
    active = FNP.IsEnabled(module.title) and FNP.OwnsNameplates()
    local lib = FNP.libnameplate
    if not events then
        events = CreateFrame("Frame", "FNPNameplateCastEvents")
        FNP.SetEventHandler(events, OnCast)
        -- A new unit may already be casting; a leaving one stops.
        table.insert(lib.OnAdded, Query)
        table.insert(lib.OnRemoved, function(plate) if plate.fnpCastbar then HideBar(plate.fnpCastbar) end end)
    end
    events:UnregisterAllEvents()
    if active then
        for _, ev in ipairs(CAST_EVENTS) do FNP.RegisterPlateEvent(events, ev) end
    end
    for plate in pairs(lib.plates) do Query(plate) end
end

module.shutdown = function()
    active = false
    if events then events:UnregisterAllEvents() end
    if ticker then ticker:Cancel(); ticker = nil end
end

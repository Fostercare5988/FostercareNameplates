local FNP = FostercareNameplates
if not FNP then return end

-- FostercareNameplates: mods/nameplate-castbar.lua
-- Adds a castbar to nameplates using ClassicAPI C_Spell cast/channel queries


local module = FNP:register({
    title = "Nameplate Castbar",
    description = "Adds a castbar to the nameplate based on unit casting information.",
    category = "Nameplates",
    enabled = true,
    config = { nameplate_uninterruptible = 1 },
})

local initialized, active
-- The ClassicAPI cast events that fire for other units. FAILED, DELAYED and
-- CHANNEL_UPDATE fire only for the player; SuperWoW's UNIT_CASTEVENT also
-- fires on every melee swing.
local CAST_EVENTS = {"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP"}
local function SyncEvents()
    if not module.events then return end
    if module.listening == active then return end
    module.listening = active
    module.events:UnregisterAllEvents()
    if active then
        for _, ev in ipairs(CAST_EVENTS) do module.events:RegisterEvent(ev) end
    end
end
module.enable = function(self)
    active = FNP.IsEnabled(module.title) and FNP.OwnsNameplates()
    module.rendering = active
    FNP.RefreshRendering()
    for plate in pairs(FNP.libnameplate.plates) do
        if plate.fnpCastbar then
            plate.fnpCastbar.nextQuery = nil
            if not active then plate.fnpCastbar:Hide() end
        end
    end
    SyncEvents()
    if initialized then return end
    initialized = true

    local backdrop = {
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    }

    local function create_castbar(plate)
        plate.fnpCastbar = CreateFrame("StatusBar", nil, plate)
        plate.fnpCastbar:EnableMouse(false)
        plate.fnpCastbar:SetPoint("BOTTOM", plate, "BOTTOM", 8, -11)
        plate.fnpCastbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        plate.fnpCastbar:SetStatusBarColor(1, 0.8, 0, 1)
        plate.fnpCastbar:SetWidth(math.max(12, plate:GetWidth() - 22))
        plate.fnpCastbar:SetHeight(10)
        FNP.HookScript(plate, "OnSizeChanged", function()
            if FNP.LayoutNameplateCastbar then FNP.LayoutNameplateCastbar(plate) end
        end)

        plate.fnpCastbar.texture = CreateFrame("Frame", nil, plate.fnpCastbar)
        plate.fnpCastbar.texture:EnableMouse(false)
        plate.fnpCastbar.texture:SetPoint("RIGHT", plate.fnpCastbar, "LEFT", 0, 0)
        plate.fnpCastbar.texture:SetHeight(18)
        plate.fnpCastbar.texture:SetWidth(18)
        plate.fnpCastbar.texture.icon = plate.fnpCastbar.texture:CreateTexture(nil, "BACKGROUND")
        plate.fnpCastbar.texture.icon:SetPoint("CENTER", 0, 0)
        plate.fnpCastbar.texture.icon:SetWidth(12)
        plate.fnpCastbar.texture.icon:SetHeight(12)
        plate.fnpCastbar.texture:SetBackdrop(backdrop)
        plate.fnpCastbar.texture:SetBackdropBorderColor(1, 0.8, 0)

        plate.fnpCastbar.bg = plate.fnpCastbar:CreateTexture(nil, "BACKGROUND")
        plate.fnpCastbar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        plate.fnpCastbar.bg:SetVertexColor(0.1, 0.1, 0, 0.8)
        plate.fnpCastbar.bg:SetAllPoints(true)

        plate.fnpCastbar.spark = plate.fnpCastbar:CreateTexture(nil, "OVERLAY")
        plate.fnpCastbar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        plate.fnpCastbar.spark:SetWidth(20)
        plate.fnpCastbar.spark:SetHeight(20)
        plate.fnpCastbar.spark:SetBlendMode("ADD")
        plate.fnpCastbar.spark:SetPoint("CENTER", plate.fnpCastbar:GetStatusBarTexture(), "RIGHT", 0, 0)
        plate.fnpCastbar.timer = C_DurationUtil.CreateDuration()

        plate.fnpCastbar.backdrop = CreateFrame("Frame", nil, plate.fnpCastbar)
        plate.fnpCastbar.backdrop:EnableMouse(false)
        plate.fnpCastbar.backdrop:SetFrameLevel(plate.fnpCastbar:GetFrameLevel())
        plate.fnpCastbar.backdrop:SetPoint("TOPLEFT", plate.fnpCastbar, "TOPLEFT", -3, 3)
        plate.fnpCastbar.backdrop:SetPoint("BOTTOMRIGHT", plate.fnpCastbar, "BOTTOMRIGHT", 3, -3)
        plate.fnpCastbar.backdrop:SetBackdrop(backdrop)
        plate.fnpCastbar.backdrop:SetBackdropBorderColor(1, 0.8, 0)

        plate.fnpCastbar.text = plate.fnpCastbar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        plate.fnpCastbar.text:SetPoint("CENTER", plate.fnpCastbar, "CENTER", 0, 0)
        local font, size = plate.fnpCastbar.text:GetFont()
        plate.fnpCastbar.text:SetFont(font, size - 3, "THINOUTLINE")

        plate.fnpCastbar:Hide()
        if FNP.LayoutNameplateCastbar then FNP.LayoutNameplateCastbar(plate) end
        if FNP.Nameplates then FNP.Nameplates:LayoutExtras(plate) end
    end

    local libnameplate = FNP.libnameplate

    -- Lifecycle cleanup touches only our castbar, even if another addon
    -- subsequently uses the shared native plate.fnpCastbar field.
    local function Reset(plate)
        local cb = plate.fnpCastbar
        if cb then
            cb:Hide()
            cb.lastSpell, cb.lastTexture, cb.lastChannel, cb.endSec = nil, nil, nil, nil
            cb.lastInterruptible, cb.castUnit, cb.nextQuery = nil, nil, nil
        end
    end
    table.insert(libnameplate.OnShow, function(plate)
        if plate.fnpCastbar and plate.fnpCastbar.castUnit ~= plate.fnpUnitGUID then Reset(plate) end
    end)
    table.insert(libnameplate.OnAdded, Reset)
    table.insert(libnameplate.OnRemoved, Reset)

    local function HideBar(cb)
        if cb:IsShown() then cb:Hide() end
        cb.lastSpell, cb.lastTexture, cb.lastInterruptible, cb.lastChannel = nil, nil, nil, nil
        cb.endSec = nil
    end

    -- The bar fills itself from cb.timer (SetTimerDuration, ClassicAPI): the
    -- spark rides the bar's texture, so nothing runs per frame while it casts.
    -- Only a query (below) or the cast ending touches the bar.
    local function Show(cb, cast, texture, startTime, endTime, notInterruptible, isChannel)
        cb.endSec = endTime / 1000
        cb.timer:SetTimeSpan(startTime / 1000, cb.endSec)
        if cb.lastChannel ~= isChannel then
            cb.lastChannel = isChannel
            cb:SetTimerDuration(cb.timer, Enum.StatusBarInterpolation.Immediate,
                isChannel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
        end
        if not cb:IsShown() then cb:Show() end

        -- Visual styling for interruptible vs uninterruptible casts
        local isUninterruptible = FNP.GetOverride("nameplate_uninterruptible", 1) == 1 and notInterruptible
        if cb.lastInterruptible ~= isUninterruptible then
            cb.lastInterruptible = isUninterruptible
            if isUninterruptible then
                cb:SetStatusBarColor(0.65, 0.65, 0.65, 1)
                cb.backdrop:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
                cb.texture:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
            else
                cb:SetStatusBarColor(1, 0.8, 0, 1)
                cb.backdrop:SetBackdropBorderColor(1, 0.8, 0, 1)
                cb.texture:SetBackdropBorderColor(1, 0.8, 0, 1)
            end
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

    table.insert(libnameplate.OnUpdate, function(plate, unit, now)
        if not active then return end
        if not plate.fnpCastbar then create_castbar(plate) end
        local cb = plate.fnpCastbar

        if not plate:IsShown() then
            HideBar(cb)
            return
        end

        -- Events invalidate immediately; bounded reconciliation covers remote
        -- casts whose event telemetry may be incomplete, and pushback, which
        -- ClassicAPI fires no event for on other units.
        if unit ~= cb.castUnit or not cb.nextQuery or now >= cb.nextQuery then
            local cast, displayName, texture, startTime, endTime, notInterruptible
            local isChannel = false
            if unit then
                local isTradeskill, castID
                cast, displayName, texture, startTime, endTime, isTradeskill, castID, notInterruptible = C_Spell.UnitCastingInfo(unit)
                if not cast then
                    cast, displayName, texture, startTime, endTime, isTradeskill, notInterruptible = C_Spell.UnitChannelInfo(unit)
                    isChannel = cast ~= nil
                end
            end
            -- Cast events for nameplate tokens invalidate at once; idle checks are a backstop.
            cb.castUnit, cb.nextQuery = unit, now + (cast and 0.1 or 1)
            if unit and cast and startTime and endTime and endTime > startTime and endTime > now * 1000 then
                Show(cb, cast, texture, startTime, endTime, notInterruptible, isChannel)
            else
                HideBar(cb)
            end
        elseif cb.endSec and now >= cb.endSec then
            HideBar(cb)
        end
    end)

    local events = CreateFrame("Frame", "FNPNameplateCastEvents", UIParent)
    module.events = events
    SyncEvents()
    FNP.SetEventHandler(events, function(_, ev, unit)
        -- ClassicAPI fires one event per token naming the caster; the
        -- nameplateN one is enough.
        if not active or not unit or not string.find(unit, "^nameplate") or not FNP.OwnsNameplates() then return end
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.fnpCastbar then plate.fnpCastbar.nextQuery = nil end
    end)
end

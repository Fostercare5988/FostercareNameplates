local FNP = FostercareNameplates
if not FNP then return end

-- Nameplate lifecycle and GUID bindings (ClassicAPI C_NamePlate).

-- Snapshot the master choice before plate discovery. Changing it requires a
-- restart so disabling never leaves a partly initialized plate subsystem.
FNP.nameplatesEnabled = FostercareNameplates_Config.nameplatesEnabled ~= 0

local libnameplate = CreateFrame("Frame", "FNPLibNameplate", UIParent)
libnameplate.OnInit = {}
libnameplate.OnShow = {}
libnameplate.OnUpdate = {}
libnameplate.OnAdded = {}
libnameplate.OnRemoved = {}
local plateRegistry = {}
libnameplate.plates = plateRegistry
local onUpdate = libnameplate.OnUpdate

-- Per-frame plate work runs only while a module needs it: it puts back what
-- the engine redraws on its own (the plate's alpha, the bar's color).
function FNP.RefreshRendering()
    local rendering = false
    for _, title in ipairs(FNP.moduleOrder) do
        if FNP.mods[title].rendering then rendering = true end
    end
    libnameplate.rendering = rendering and not libnameplate.stopping
end

function FNP.OwnsNameplates()
    return FNP.nameplatesEnabled and not libnameplate.stopping
end

-- Unit events for plates: ClassicAPI fires one per token naming the unit
-- (target, raidN, nameplateN...). RegisterUnitEvent drops every token but the
-- nameplate ones before Lua runs. The list grows when a plate takes a slot
-- past its end, and re-registers what is registered at that moment.
local plateTokens, plateEvents = {}, {}
for i = 1, 40 do plateTokens[i] = "nameplate" .. i end

function FNP.RegisterPlateEvent(frame, ev)
    plateEvents[frame] = plateEvents[frame] or {}
    plateEvents[frame][ev] = true
    frame:RegisterUnitEvent(ev, unpack(plateTokens))
end

local function CoverSlot(unit)
    local slot = tonumber(string.sub(unit, 10))
    if not slot or slot <= #plateTokens then return end
    for i = #plateTokens + 1, slot + 20 do plateTokens[i] = "nameplate" .. i end
    for frame, events in pairs(plateEvents) do
        for ev in pairs(events) do
            if frame:IsEventRegistered(ev) then frame:RegisterUnitEvent(ev, unpack(plateTokens)) end
        end
    end
end

-- C_NamePlate hands out the engine's plates only. Native region order:
-- border, glow, name, level, level icon, raid icon, dragon.
local function InitPlate(plate)
    if plateRegistry[plate] then return end
    plate.healthbar = plate:GetChildren()
    local r1, r2, r3, r4, r5, r6, r7 = plate:GetRegions()
    plate.border, plate.glow, plate.name, plate.level = r1, r2, r3, r4
    plate.levelicon, plate.raidicon, plate.dragon = r5, r6, r7

    for _, func in ipairs(libnameplate.OnInit) do
        func(plate)
    end

    -- ClassicAPI's HookScript runs ours after any handler the plate has. The
    -- closures name their plate, so they need no script arguments.
    plate:HookScript("OnUpdate", function()
        if not libnameplate.rendering then return end
        for i = 1, #onUpdate do onUpdate[i](plate) end
    end)
    plate:HookScript("OnShow", function()
        if libnameplate.stopping then return end
        for _, callback in ipairs(libnameplate.OnShow) do callback(plate) end
    end)

    plateRegistry[plate] = plate
end

-- ADDED/REMOVED own the binding: a unit that moves to another plate fires
-- REMOVED for the old frame and ADDED for the new (ClassicAPI 1.19).
local function Added(plate, guid)
    InitPlate(plate)
    plate.fnpUnitGUID = guid
    for _, callback in ipairs(libnameplate.OnAdded) do callback(plate, guid) end
end

-- Validate pooled-frame ownership before consuming any unit data.
FNP.GetNameplateUnit = function(plate)
    local guid = plate.fnpUnitGUID
    if guid and C_NamePlate.GetNamePlateForGUID(guid) == plate then
        return guid
    end
    plate.fnpUnitGUID = nil
end

if FNP.OwnsNameplates() then
    libnameplate:RegisterEvent("NAME_PLATE_CREATED")
    libnameplate:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    libnameplate:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    libnameplate:RegisterEvent("PLAYER_ENTERING_WORLD")
    libnameplate:RegisterEvent("PLAYER_LOGOUT")
end

-- Stop our own events and timers only, in every module. At logout the client
-- is already freeing the plates; reparenting, resizing or re-anchoring them
-- then was followed by ERROR #124 (SGroupPtr invalid block, 2026-10-22).
local function ShutdownNameplates()
    libnameplate.stopping, libnameplate.rendering = true, false
    libnameplate:UnregisterAllEvents()
    for _, title in ipairs(FNP.moduleOrder) do
        local module = FNP.mods[title]
        if module.shutdown then module:shutdown() end
    end
end

FNP.SetEventHandler(libnameplate, function(_, ev, a1)
    if ev == "PLAYER_LOGOUT" then ShutdownNameplates(); return end
    if libnameplate.stopping then return end
    if ev == "NAME_PLATE_CREATED" then
        InitPlate(a1)
    elseif ev == "NAME_PLATE_UNIT_ADDED" then
        CoverSlot(a1)
        local plate = C_NamePlate.GetNamePlateForUnit(a1)
        if plate then Added(plate, UnitGUID(a1)) end
    elseif ev == "NAME_PLATE_UNIT_REMOVED" then
        -- REMOVED comes before ADDED, and the token still names the leaving
        -- unit and plate during it.
        local plate = C_NamePlate.GetNamePlateForUnit(a1)
        if plate and plateRegistry[plate] then
            plate.fnpUnitGUID = nil
            for _, callback in ipairs(libnameplate.OnRemoved) do callback(plate) end
        end
    elseif ev == "PLAYER_ENTERING_WORLD" then
        -- Plates that are up when the UI loads, or that changed unit during a
        -- loading screen, are announced like an ADDED.
        for _, guid in ipairs(C_NamePlate.GetNamePlateGUIDs()) do
            local plate = C_NamePlate.GetNamePlateForGUID(guid)
            if plate and plate.fnpUnitGUID ~= guid then Added(plate, guid) end
        end
    end
end)

FNP.libnameplate = libnameplate

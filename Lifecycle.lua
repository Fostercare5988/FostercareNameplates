local FNP = FostercareNameplates
if not FNP then return end

-- Nameplate lifecycle and verified GUID bindings.
local NAMEPLATE_OBJECTORDER = { "border", "glow", "name", "level", "levelicon", "raidicon", "dragon" }

-- Snapshot the master choice before plate discovery. Changing it requires a
-- restart so disabling never leaves a partly initialized plate subsystem.
FNP.nameplatesEnabled = FostercareNameplates_Config.nameplatesEnabled ~= 0

local function IsNamePlate(frame)
    if not frame or frame:GetObjectType() ~= "Button" then return false end
    local regions = frame:GetRegions()
    if not regions or not regions.GetObjectType or not regions.GetTexture then return false end
    if regions:GetObjectType() ~= "Texture" then return false end
    return regions:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

local libnameplate = CreateFrame("Frame", "FNPLibNameplate", UIParent)
libnameplate.OnInit = {}
libnameplate.OnShow = {}
libnameplate.OnUpdate = {}
libnameplate.OnAdded = {}
libnameplate.OnRemoved = {}
local plateRegistry = {}
libnameplate.plates = plateRegistry

function FNP.OwnsNameplates()
    return FNP.nameplatesEnabled and not libnameplate.stopping and not FNP.legacyOwner and not ShaguPlates and not BNP
end

local function InitPlate(plate, unit)
    if not FNP.OwnsNameplates() then return end
    if not plate or plateRegistry[plate] then
        if plate and unit then plate.fnpUnitGUID = UnitGUID(unit) end
        return
    end
    if not IsNamePlate(plate) then return end

    if unit then plate.fnpUnitGUID = UnitGUID(unit) end
    plate.healthbar = plate:GetChildren()
    FNP.ForEachRegion(plate, function(region, index)
        local key = NAMEPLATE_OBJECTORDER[index]
        if key then plate[key] = region end
    end)

    for _, func in ipairs(libnameplate.OnInit) do
        func(plate)
    end

    FNP.HookScript(plate, "OnUpdate", function(self)
        if not FNP.OwnsNameplates() or #libnameplate.OnUpdate == 0 then return end
        -- Validate a pooled frame once for all render consumers, not once per feature.
        local unit, now = FNP.GetNameplateUnit(self), GetTime()
        for _, callback in ipairs(libnameplate.OnUpdate) do callback(self, unit, now) end
    end)
    FNP.HookScript(plate, "OnShow", function(self)
        if libnameplate.stopping then return end
        for _, callback in ipairs(libnameplate.OnShow) do callback(self) end
    end)

    plateRegistry[plate] = plate
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

local function ShutdownNameplates()
    libnameplate.stopping = true
    libnameplate:UnregisterAllEvents()
    if FNP.Nameplates then FNP.Nameplates:Shutdown() end
    if FNP.NameplateCooldowns then FNP.NameplateCooldowns:ApplyConfiguration() end
    for plate in pairs(plateRegistry) do
        if FNP.RestoreNameplateScale then FNP.RestoreNameplateScale(plate) end
        -- Engine-created plates can outlive the Lua UI. Unlink only our
        -- regions/frames before reload frees their font/layout resources.
        for _, key in ipairs({ "fnpHealth",
            "fnpAuras", "fnpCombo", "fnpTargetGlow", "fnpTargeting",
            "fnpCastbar", "fnpEnemyCooldowns" }) do
            local object = plate[key]
            if object then
                object:Hide(); object:ClearAllPoints(); object:SetParent(UIParent)
            end
        end
    end
end

FNP.SetEventHandler(libnameplate, function(_, ev, a1)
    if ev == "PLAYER_LOGOUT" then ShutdownNameplates(); return end
    if libnameplate.stopping or not FNP.nameplatesEnabled then return end
    if ev == "NAME_PLATE_CREATED" and a1 then
        InitPlate(a1)
    elseif ev == "NAME_PLATE_UNIT_ADDED" and a1 then
        local unit = a1
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then
            InitPlate(plate, unit)
            if plateRegistry[plate] then
                for _, callback in ipairs(libnameplate.OnAdded) do callback(plate, plate.fnpUnitGUID) end
            end
        end
    elseif ev == "NAME_PLATE_UNIT_REMOVED" and a1 then
        local unit = a1
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.fnpUnitGUID == UnitGUID(unit) then
            plate.fnpUnitGUID = nil
            for _, callback in ipairs(libnameplate.OnRemoved) do callback(plate) end
        end
    elseif ev == "PLAYER_ENTERING_WORLD" then
        for _, guid in ipairs(C_NamePlate.GetNamePlateGUIDs()) do
            InitPlate(C_NamePlate.GetNamePlateForGUID(guid), guid)
        end
    end
end)

FNP.libnameplate = libnameplate

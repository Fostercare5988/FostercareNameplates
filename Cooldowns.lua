local FNP = FostercareNameplates
if not FNP then return end

-- Observed enemy casts, not an inspection of another player's cooldown state.
-- SuperWoW owns cast identity; NamPower reads the current client's spell data.
local module = FNP:register({
    title = "Enemy Nameplate Cooldowns", category = "Nameplates", enabled = true,
    description = "Estimated cooldowns after enemy players use abilities. Requires NamPower 4.6.2+.",
    config = { nameplate_cd_size = 22, nameplate_cd_count = 5,
        nameplate_cd_minimum = 5, nameplate_cd_offset = 8, nameplate_cd_target = 0 },
})
local CD = { states = {}, count = 0 }
FNP.NameplateCooldowns = CD
local cache, cacheOrder, cacheCursor = {}, {}, 1
local visible, ticker, driver, initialized
local MAX_UNITS, MAX_SPELLS, MAX_CACHE = 128, 16, 256

-- Read on apply and refresh; the 0.2 s tick only reads these.
local opt = {}
local function ReadSettings()
    opt.targetOnly = FNP.GetOverride("nameplate_cd_target", 0) == 1
    opt.minimum = FNP.GetNumber("nameplate_cd_minimum", 5, 5, 120)
    opt.maximum = math.floor(FNP.GetNumber("nameplate_cd_count", 5, 1, 8))
    opt.size = math.floor(FNP.GetNumber("nameplate_cd_size", 22, 14, 40))
    opt.offset = FNP.GetNumber("nameplate_cd_offset", 8, 0, 60)
end

function CD:IsAvailable()
    if type(GetNampowerVersion) ~= "function" or type(GetSpellRecField) ~= "function"
        or type(GetSpellIconTexture) ~= "function" then return false end
    local major, minor, patch = GetNampowerVersion()
    return type(major) == "number" and type(minor) == "number" and type(patch) == "number"
        and (major > 4 or (major == 4 and (minor > 6 or (minor == 6 and patch >= 2))))
end

local function Metadata(id)
    if cache[id] ~= nil then return cache[id] or nil end
    -- Scalar reads avoid retaining NamPower's reused tables and arrays.
    local recovery = tonumber(GetSpellRecField(id, "recoveryTime")) or 0
    local category = tonumber(GetSpellRecField(id, "categoryRecoveryTime")) or 0
    local duration = math.max(recovery, category) / 1000
    local data = false
    if duration >= 5 and duration <= 1800 then
        local name = GetSpellRecField(id, "name")
        local iconID = GetSpellRecField(id, "spellIconID")
        local texture = iconID and GetSpellIconTexture(iconID)
        if type(name) == "string" and name ~= "" and texture then
            data = { name = name, texture = texture, duration = duration }
        end
    end
    local old = cacheOrder[cacheCursor]
    if old then cache[old] = nil end
    cacheOrder[cacheCursor], cache[id] = id, data
    cacheCursor = cacheCursor % MAX_CACHE + 1
    return data or nil
end

local function HideRow(plate)
    local row = plate.fnpEnemyCooldowns
    if not row then return end
    for _, icon in ipairs(row.icons) do
        if icon.start then icon.sweep:Clear() end
        icon.start, icon.lastRemaining = nil, nil
        icon:Hide()
    end
    row:Hide()
end

local function Icon(row, index)
    local icon = row.icons[index]
    if icon then return icon end
    icon = CreateFrame("Frame", nil, row)
    icon:EnableMouse(false)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints(icon)
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon.sweep = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.sweep:SetAllPoints(icon)
    icon.sweep.noCooldownCount = true
    -- The "~" estimate below is ours; native numbers would print over it.
    icon.sweep:SetHideCountdownNumbers(true)
    icon.textFrame = CreateFrame("Frame", nil, icon)
    icon.textFrame:SetAllPoints(icon)
    icon.textFrame:SetFrameLevel(icon.sweep:GetFrameLevel() + 2)
    icon.text = icon.textFrame:CreateFontString(nil, "OVERLAY")
    icon.text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    icon.text:SetPoint("CENTER", icon.textFrame, "CENTER", 0, 0)
    icon.text:SetTextColor(1, 0.85, 0.35)
    row.icons[index] = icon
    return icon
end

-- validated: the tick already matched plate and GUID, and the unit passed the
-- player and attackable checks when its row was first drawn.
local function Draw(plate, guid, now, validated)
    local state = CD.states[guid]
    local row = plate.fnpEnemyCooldowns
    if not state or not plate:IsShown() or (opt.targetOnly and guid ~= UnitGUID("target"))
        or (not validated and (C_NamePlate.GetNamePlateForGUID(guid) ~= plate
            or not UnitIsPlayer(guid) or not UnitCanAttack("player", guid))) then
        HideRow(plate); return
    end
    local minimum, maximum, size = opt.minimum, opt.maximum, opt.size
    local count = 0
    for _, entry in ipairs(state.spells) do
        if entry.ends > now and entry.data.duration >= minimum and count < maximum then
            count = count + 1
            if not row then
                row = CreateFrame("Frame", nil, plate)
                row:EnableMouse(false)
                row.icons = {}
                plate.fnpEnemyCooldowns = row
            end
            local icon = Icon(row, count)
            if icon.size ~= size then
                icon.size = size; icon:SetWidth(size); icon:SetHeight(size)
                icon:ClearAllPoints(); icon:SetPoint("LEFT", row, "LEFT", (count - 1) * (size + 3), 0)
            end
            if icon.start ~= entry.start or icon.spellID ~= entry.id then
                icon.start, icon.spellID = entry.start, entry.id
                icon.texture:SetTexture(entry.data.texture)
                icon.sweep:SetCooldown(entry.start, entry.data.duration)
            end
            local remaining = math.ceil(entry.ends - now)
            if icon.lastRemaining ~= remaining then
                icon.lastRemaining = remaining
                icon.text:SetText("~" .. (remaining >= 60 and (math.ceil(remaining / 60) .. "m") or tostring(remaining)))
            end
            if not icon:IsShown() then icon:Show() end
        end
    end
    if count == 0 then HideRow(plate); return end
    row.guid = guid
    for i = count + 1, #row.icons do
        local icon = row.icons[i]
        if icon.start then icon.sweep:Clear() end
        icon.start, icon.lastRemaining = nil, nil; icon:Hide()
    end
    -- Aura and target changes lay the row out themselves; here only a new,
    -- re-shown or resized row needs it.
    local width, offset = count * (size + 3) - 3, opt.offset
    local layout = not row:IsShown()
    if row.width ~= width or row.size ~= size or row.offset ~= offset then
        row.width, row.size, row.offset = width, size, offset
        row:SetWidth(width); row:SetHeight(size)
        if not FNP.Nameplates then
            row:ClearAllPoints(); row:SetPoint("BOTTOM", plate.name or plate, "TOP", 0, offset + 6)
        end
        layout = true
    end
    if layout and FNP.Nameplates then FNP.Nameplates:LayoutExtras(plate) end
    if not row:IsShown() then row:Show() end
end

local function Tick()
    local now = GetTime()
    for guid, state in pairs(CD.states) do
        for i = #state.spells, 1, -1 do
            if state.spells[i].ends <= now then table.remove(state.spells, i) end
        end
        if #state.spells == 0 then CD.states[guid] = nil; CD.count = CD.count - 1 end
    end
    for guid, plate in pairs(visible) do
        if C_NamePlate.GetNamePlateForGUID(guid) ~= plate then
            visible[guid] = nil
            -- A recycled plate may already display its new unit's icons.
            if plate.fnpEnemyCooldowns and plate.fnpEnemyCooldowns.guid == guid then HideRow(plate) end
        else Draw(plate, guid, now, true) end
    end
    if CD.count == 0 and ticker then ticker:Cancel(); ticker = nil end
end

function CD:Refresh()
    if self.enabled then ReadSettings(); Tick() end
end

function CD:Observe(unit, id)
    if not self.enabled or type(id) ~= "number" or id <= 0 then return end
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then return end
    local guid = UnitGUID(unit)
    if not guid or guid == UnitGUID("player") then return end
    local data = Metadata(id)
    if not data then return end
    local now, state = GetTime(), self.states[guid]
    if not state then
        if self.count >= MAX_UNITS then
            local oldestGUID, oldestTime
            for key, candidate in pairs(self.states) do
                if not oldestTime or candidate.last < oldestTime then oldestGUID, oldestTime = key, candidate.last end
            end
            self.states[oldestGUID] = nil; self.count = self.count - 1
            if visible[oldestGUID] then HideRow(visible[oldestGUID]) end
        end
        state = { spells = {} }; self.states[guid] = state; self.count = self.count + 1
    end
    -- Ranks share an ability name. A newly observed use supersedes an estimate,
    -- including uses after an unseen talent reset. No name-based unit matching.
    for i, entry in ipairs(state.spells) do
        if entry.data.name == data.name then
            if now - entry.start < 0.5 then return end
            table.remove(state.spells, i); break
        end
    end
    if #state.spells >= MAX_SPELLS then table.remove(state.spells) end
    table.insert(state.spells, 1, { id = id, data = data, start = now, ends = now + data.duration })
    state.last = now
    local plate = C_NamePlate.GetNamePlateForGUID(guid)
    if plate then visible[guid] = plate; Draw(plate, guid, now) end
    if not ticker then ticker = C_Timer.NewTicker(0.2, Tick) end
end

function CD:ApplyConfiguration()
    self.enabled = FNP.IsEnabled(module.title, true) and self:IsAvailable() and FNP.OwnsNameplates()
    if not driver then driver = CreateFrame("Frame", "FNPEnemyCooldownEvents", UIParent) end
    driver:UnregisterAllEvents()
    if not self.enabled then
        if ticker then ticker:Cancel(); ticker = nil end
        if visible then for _, plate in pairs(visible) do HideRow(plate) end end
        self.states, self.count, visible = {}, 0, {}
        return
    end
    visible = visible or {}
    ReadSettings()
    -- NamPower's cast events for other casters; SuperWoW's UNIT_CASTEVENT would also
    -- call us on every melee swing nearby.
    for _, ev in ipairs({ "SPELL_GO_OTHER", "SPELL_START_OTHER", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_ENTERING_WORLD",
        "PLAYER_TARGET_CHANGED", "ADDON_LOADED" }) do
        driver:RegisterEvent(ev)
    end
    FNP.SetEventHandler(driver, function(_, ev, unit, id, caster, _, _, _, _, spellType)
        if ev == "ADDON_LOADED" then
            if not FNP.OwnsNameplates() then CD:ApplyConfiguration() end
        elseif ev == "PLAYER_TARGET_CHANGED" then CD:Refresh()
        elseif ev == "SPELL_GO_OTHER" then
            -- itemId, spellId, casterGuid
            CD:Observe(caster, id)
        elseif ev == "SPELL_START_OTHER" then
            -- itemId, spellId, casterGuid, ..., spellType (1 = channel)
            if spellType == 1 then CD:Observe(caster, id) end
        elseif ev == "NAME_PLATE_UNIT_ADDED" then
            local guid = unit and UnitGUID(unit)
            local plate = guid and C_NamePlate.GetNamePlateForUnit(unit)
            if plate then visible[guid] = plate; Draw(plate, guid, GetTime()) end
        elseif ev == "NAME_PLATE_UNIT_REMOVED" then
            local guid = unit and UnitGUID(unit)
            local plate = guid and visible[guid]
            if plate then
                visible[guid] = nil
                if plate.fnpEnemyCooldowns and plate.fnpEnemyCooldowns.guid == guid then HideRow(plate) end
            end
        else
            -- World transitions discard observations rather than guessing which
            -- cooldown reset rules apply to a battleground or server script.
            CD.states, CD.count = {}, 0
            if ticker then ticker:Cancel(); ticker = nil end
            for _, plate in pairs(visible) do HideRow(plate) end
            visible = {}
        end
    end)
    if not initialized then
        initialized = true
        table.insert(FNP.libnameplate.OnShow, function(plate)
            if plate.fnpEnemyCooldowns and plate.fnpEnemyCooldowns.guid ~= plate.fnpUnitGUID then HideRow(plate) end
        end)
    end
    for _, guid in ipairs(C_NamePlate.GetNamePlateGUIDs()) do
        local plate = C_NamePlate.GetNamePlateForGUID(guid)
        if plate then visible[guid] = plate end
    end
    Tick()
end

module.enable = function() CD:ApplyConfiguration() end
module.apply = module.enable

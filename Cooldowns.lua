local FNP = FostercareNameplates
if not FNP then return end

-- Observed enemy casts, not an inspection of another player's cooldown state.
-- NamPower's cast events say what was used, its spell records the base cooldown.
local module = FNP:register({
    title = "Enemy Nameplate Cooldowns", category = "Nameplates", enabled = true,
    description = "Estimated cooldowns after enemy players use abilities.",
    config = { nameplate_cd_size = 22, nameplate_cd_count = 5,
        nameplate_cd_minimum = 5, nameplate_cd_offset = 8, nameplate_cd_target = 0 },
})
local CD = { states = {}, count = 0, offset = 8 }
FNP.NameplateCooldowns = CD
local cache, cacheOrder, cacheCursor = {}, {}, 1
local driver
local MAX_UNITS, MAX_SPELLS, MAX_CACHE = 128, 16, 256
local EVENTS = { "SPELL_GO_OTHER", "SPELL_START_OTHER", "PLAYER_ENTERING_WORLD" }

-- The client counts the time down (countdownForCooldowns CVar 1); "~" says the
-- timer is an estimate: whole seconds, then minutes from 60 s, rounded up.
local Up = Enum.NumericRuleFormatRounding.Up
local ESTIMATE = C_StringUtil.CreateNumericRuleFormatter()
ESTIMATE:SetBreakpoints({
    { threshold = 0, step = 1, rounding = Up, format = "~%d" },
    { threshold = 60, format = "~%dm", components = { { div = 60, step = 1, rounding = Up } } },
})

-- Read on apply and refresh.
local opt = {}
local function ReadSettings()
    opt.targetOnly = FNP.GetOverride("nameplate_cd_target", 0) == 1
    opt.minimum = FNP.GetNumber("nameplate_cd_minimum", 5, 5, 120)
    opt.maximum = math.floor(FNP.GetNumber("nameplate_cd_count", 5, 1, 8))
    opt.size = math.floor(FNP.GetNumber("nameplate_cd_size", 22, 14, 40))
    CD.offset = FNP.GetNumber("nameplate_cd_offset", 8, 0, 60)
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
        icon.start = nil
        icon:Hide()
    end
    row.guid = nil
    row:Hide()
end

local Draw

-- An estimate ran out: draw the row again without it.
local function Done()
    local icon = this.owner
    local row = icon.row
    icon.start = nil
    if row.guid then Draw(row.plate, row.guid, math.max(GetTime(), icon.ends)) end
end

local function Icon(row, index)
    local icon = row.icons[index]
    if icon then return icon end
    icon = CreateFrame("Frame", nil, row)
    icon:EnableMouse(false)
    icon.row = row
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints(icon)
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local sweep = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    sweep:SetAllPoints(icon)
    sweep:SetCountdownFormatter(ESTIMATE)
    local number = sweep:GetCountdownFontString()
    number:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    number:SetTextColor(1, 0.85, 0.35)
    sweep:SetScript("OnCooldownDone", Done)
    sweep.owner, icon.sweep = icon, sweep
    row.icons[index] = icon
    return icon
end

-- Prunes the unit's ended estimates, then shows the rest, newest first.
Draw = function(plate, guid, now)
    local state = CD.states[guid]
    if state then
        local spells = state.spells
        for i = #spells, 1, -1 do
            if spells[i].ends <= now then table.remove(spells, i) end
        end
        if #spells == 0 then CD.states[guid] = nil; CD.count = CD.count - 1; state = nil end
    end
    if not state or (opt.targetOnly and guid ~= UnitGUID("target"))
        or not UnitIsPlayer(guid) or not UnitCanAttack("player", guid) then
        HideRow(plate); return
    end
    local row = plate.fnpEnemyCooldowns
    local minimum, maximum, size = opt.minimum, opt.maximum, opt.size
    local count = 0
    for _, entry in ipairs(state.spells) do
        if entry.data.duration >= minimum and count < maximum then
            count = count + 1
            if not row then
                row = CreateFrame("Frame", nil, plate)
                row:EnableMouse(false)
                row.icons, row.plate = {}, plate
                plate.fnpEnemyCooldowns = row
            end
            local icon = Icon(row, count)
            if icon.size ~= size then
                icon.size = size; icon:SetWidth(size); icon:SetHeight(size)
                icon:ClearAllPoints(); icon:SetPoint("LEFT", row, "LEFT", (count - 1) * (size + 3), 0)
            end
            if icon.start ~= entry.start or icon.spellID ~= entry.id then
                icon.start, icon.ends, icon.spellID = entry.start, entry.ends, entry.id
                icon.texture:SetTexture(entry.data.texture)
                icon.sweep:SetCooldown(entry.start, entry.data.duration)
            end
            if not icon:IsShown() then icon:Show() end
        end
    end
    if count == 0 then HideRow(plate); return end
    row.guid = guid
    for i = count + 1, #row.icons do
        local icon = row.icons[i]
        if icon.start then icon.sweep:Clear() end
        icon.start = nil; icon:Hide()
    end
    -- Aura and target changes lay the row out themselves; here only a new,
    -- re-shown or resized row needs it.
    local width = count * (size + 3) - 3
    local layout = not row:IsShown()
    if row.width ~= width or row.size ~= size or row.offset ~= CD.offset then
        row.width, row.size, row.offset = width, size, CD.offset
        row:SetWidth(width); row:SetHeight(size)
        layout = true
    end
    if layout then FNP.Nameplates:LayoutExtras(plate) end
    if not row:IsShown() then row:Show() end
end

-- Every bound plate, after a target or settings change.
local function DrawAll()
    local now = GetTime()
    for plate in pairs(FNP.libnameplate.plates) do
        local guid = plate.fnpUnitGUID
        if guid then Draw(plate, guid, now) else HideRow(plate) end
    end
end

function CD:Refresh()
    if not self.enabled then return end
    ReadSettings()
    if opt.targetOnly then driver:RegisterEvent("PLAYER_TARGET_CHANGED")
    else driver:UnregisterEvent("PLAYER_TARGET_CHANGED") end
    DrawAll()
end

-- Most casts nearby have no cooldown worth showing: the cached spell record
-- answers that before any unit is asked about.
function CD:Observe(guid, id)
    if not self.enabled then return end
    local data = Metadata(id)
    if not data or not UnitIsPlayer(guid) or not UnitCanAttack("player", guid) then return end
    local now, state = GetTime(), self.states[guid]
    if not state then
        if self.count >= MAX_UNITS then
            local oldestGUID, oldestTime
            for key, candidate in pairs(self.states) do
                if not oldestTime or candidate.last < oldestTime then oldestGUID, oldestTime = key, candidate.last end
            end
            self.states[oldestGUID] = nil; self.count = self.count - 1
            local plate = C_NamePlate.GetNamePlateForGUID(oldestGUID)
            if plate then HideRow(plate) end
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
    if plate then Draw(plate, guid, now) end
end

local function OnEvent(_, ev, _, id, caster, _, _, _, _, spellType)
    if ev == "SPELL_GO_OTHER" then
        -- itemId, spellId, casterGuid
        CD:Observe(caster, id)
    elseif ev == "SPELL_START_OTHER" then
        -- itemId, spellId, casterGuid, ..., spellType (1 = channel)
        if spellType == 1 then CD:Observe(caster, id) end
    elseif ev == "PLAYER_TARGET_CHANGED" then
        DrawAll()
    else
        -- World transitions discard observations rather than guessing which
        -- cooldown reset rules apply to a battleground or server script.
        table.wipe(CD.states); CD.count = 0
        for plate in pairs(FNP.libnameplate.plates) do HideRow(plate) end
    end
end

function CD:ApplyConfiguration()
    self.enabled = FNP.IsEnabled(module.title, true) and FNP.OwnsNameplates()
    local lib = FNP.libnameplate
    if not driver then
        driver = CreateFrame("Frame", "FNPEnemyCooldownEvents")
        FNP.SetEventHandler(driver, OnEvent)
        table.insert(lib.OnAdded, function(plate, guid)
            if CD.enabled and guid then Draw(plate, guid, GetTime()) else HideRow(plate) end
        end)
        table.insert(lib.OnRemoved, HideRow)
    end
    driver:UnregisterAllEvents()
    if not self.enabled then
        table.wipe(self.states); self.count = 0
        for plate in pairs(lib.plates) do HideRow(plate) end
        return
    end
    -- NamPower's cast events for other casters; SuperWoW's UNIT_CASTEVENT would
    -- also call us on every melee swing nearby.
    for _, ev in ipairs(EVENTS) do driver:RegisterEvent(ev) end
    self:Refresh()
end

module.enable = function() CD:ApplyConfiguration() end
module.shutdown = function()
    CD.enabled = false
    if driver then driver:UnregisterAllEvents() end
end

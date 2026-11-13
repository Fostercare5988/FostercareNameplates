local FNP = FostercareNameplates
if not FNP then return end

-- Native plate/input ownership stays intact. Everything is drawn on events
-- (health and auras coalesced to one pass per frame); the one per-frame
-- callback, Render, puts back the plate's alpha when the engine changed it.
local defaults = { nameplate_marks = 1, nameplate_raidmark_size = 20,
    nameplate_raidmark_position = "left", nameplate_target_glow = 0,
    nameplate_target_scale = 1.1, nameplate_other_alpha = 0.8,
    nameplate_health = 1, nameplate_health_target = 1, nameplate_level = 1, nameplate_own_auras = 1,
    nameplate_cc = 1, nameplate_enemy_buffs = 0, nameplate_aura_size = 20,
    nameplate_aura_count = 3, nameplate_combo = 1, nameplate_targeting = 0,
    nameplate_fade_critters = 0, nameplate_fade_totems = 0, nameplate_fade_pets = 0,
    nameplate_fade_trivial = 0, nameplate_fade_neutral = 0, nameplate_fade_alpha = 0.3 }
local module = FNP:register({ title = "Nameplate Details", category = "Nameplates", enabled = true,
    description = "Native raid marks, target emphasis, health, auras and combo points.", config = defaults })
local NP = { pending = {}, settings = {} }
FNP.Nameplates = NP
local lib = FNP.libnameplate
local queued, driver
local auraSlots = {}
local DETAIL_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_COMBO_POINTS", "RAID_TARGET_UPDATE", "PLAYER_ENTERING_WORLD" }
-- Unit events, heard for nameplateN tokens only (FNP.RegisterPlateEvent).
local PLATE_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA_DELTA", "UNIT_FACTION", "UNIT_LEVEL" }

local function Visible(object, shown)
    shown = shown and true or false
    if (object:IsShown() and true or false) ~= shown then if shown then object:Show() else object:Hide() end end
end

local function Text(object, value)
    if object.fnpText ~= value then object.fnpText = value; object:SetText(value) end
end

-- Whether the plate's unit wears a raid mark: the mark itself, not the
-- engine's icon, which it shows in its own time.
local function Marked(plate)
    return plate.fnpDetailGUID and GetRaidTargetIndex(plate.fnpDetailGUID)
end

local function HideAuras(plate)
    local row = plate.fnpAuras
    if not row then return end
    for _, icon in ipairs(row.icons) do
        icon.cdStart = nil; icon.sweep:Clear(); Visible(icon, false)
    end
    Visible(row, false); plate.fnpAuraHeight = 0
end

local function Clear(plate)
    plate.fnpNeedsDetails = true
    NP.pending[plate] = nil
    HideAuras(plate)
    if plate.fnpHealth then Visible(plate.fnpHealth, false) end
    if plate.fnpLevel then Visible(plate.fnpLevel, false) end
    if plate.fnpCombo then Visible(plate.fnpCombo, false) end
    if plate.fnpTargetGlow then Visible(plate.fnpTargetGlow, false) end
    if plate.fnpTargeting then Visible(plate.fnpTargeting, false) end
end

function NP:LayoutMark(plate, restore)
    local icon = plate.raidicon
    if not icon then return end
    if not plate.fnpNativeMark then
        local state = { width = icon:GetWidth(), height = icon:GetHeight(), points = {} }
        for i = 1, icon:GetNumPoints() do state.points[i] = { icon:GetPoint(i) } end
        plate.fnpNativeMark = state
    end
    if restore or not self.settings.marks then
        if plate.fnpMarkOwned then
            local state = plate.fnpNativeMark
            icon:SetWidth(state.width); icon:SetHeight(state.height); icon:ClearAllPoints()
            for _, point in ipairs(state.points) do icon:SetPoint(unpack(point)) end
            plate.fnpMarkOwned = nil
        end
        return
    end
    local size, position = self.settings.markSize, self.settings.markPosition
    local anchor, point, relative, x, y = plate.healthbar or plate, "RIGHT", "LEFT", -4, 0
    if position == "above" then
        anchor, point, relative, x, y = plate.name or plate, "BOTTOM", "TOP", 0, 4
    elseif position == "right" then point, relative, x = "LEFT", "RIGHT", 18 * (plate.fnpVisualScale or 1) end
    local p, a, r, ox, oy = icon:GetPoint(1)
    if p ~= point or a ~= anchor or r ~= relative or ox ~= x or oy ~= y then
        icon:ClearAllPoints(); icon:SetPoint(point, anchor, relative, x, y)
    end
    if icon:GetWidth() ~= size then icon:SetWidth(size) end
    if icon:GetHeight() ~= size then icon:SetHeight(size) end
    -- Never touch native visibility or atlas coordinates.
    plate.fnpMarkOwned = true
end

function NP:RefreshMarks()
    if not FNP.OwnsNameplates() then return end
    self.settings.markSize = FNP.GetNumber("nameplate_raidmark_size", 20, 12, 40)
    self.settings.markPosition = FNP.GetOverride("nameplate_raidmark_position", "left")
    self.settings.marks = self.active and FNP.GetOverride("nameplate_marks", 1) == 1
    for plate in pairs(lib.plates) do
        if plate:IsShown() then self:LayoutMark(plate); self:Combo(plate); self:LayoutExtras(plate) end
        if self.active and plate.fnpDetailGUID then self:Alpha(plate, plate.fnpDetailGUID) end
    end
end

-- The level oval's center lies past the bar's right end by a tenth of the bar
-- width (measured in play, 2026-10-22), so it follows the plate size. At 9 px
-- and below the digits were unreadable on the gold oval.
local function PlaceLevel(plate)
    local label = plate.fnpLevel
    local x = math.floor(plate.healthbar:GetWidth() * 0.1 + 0.5)
    if label.fnpX ~= x then
        label.fnpX = x; label:ClearAllPoints(); label:SetPoint("CENTER", plate.healthbar, "RIGHT", x, 0)
    end
    FNP.SetNameplateFontSize(label, math.max(8, 10 * (plate.fnpVisualScale or 1)))
end

function NP:TopSpace(plate)
    local space = 6
    if self.settings.marks and self.settings.markPosition == "above" then space = space + self.settings.markSize + 4 end
    if not self.settings.marks and plate.raidicon and Marked(plate) then space = space + plate.raidicon:GetHeight() + 4 end
    if self.settings.combo and plate.fnpIsTarget then space = space + 10 end
    return space
end

function NP:LayoutExtras(plate)
    FNP.SetNameplateFontSize(plate.fnpHealth, math.max(7, 9 * (plate.fnpVisualScale or 1)))
    if plate.fnpLevel then PlaceLevel(plate) end
    if plate.fnpTargeting then
        local anchor = plate.fnpCastbar or plate.healthbar
        if plate.fnpTargeting.fnpAnchor ~= anchor then
            plate.fnpTargeting.fnpAnchor = anchor
            plate.fnpTargeting:ClearAllPoints()
            plate.fnpTargeting:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
        end
    end
    local row = plate.fnpAuras
    if row then
        local y = self:TopSpace(plate)
        if row.fnpLayoutY ~= y then
            row.fnpLayoutY = y; row:ClearAllPoints(); row:SetPoint("BOTTOM", plate.name or plate, "TOP", 0, y)
        end
    end
    local cds = plate.fnpEnemyCooldowns
    if cds then
        local y = self:TopSpace(plate) + (plate.fnpAuraHeight or 0)
            + FNP.NameplateCooldowns.offset
        if cds.fnpLayoutY ~= y then
            cds.fnpLayoutY = y; cds:ClearAllPoints(); cds:SetPoint("BOTTOM", plate.name or plate, "TOP", 0, y)
        end
    end
end

function NP:Health(plate, unit)
    local show = self.settings.health > 0 and unit and (not self.settings.healthTarget or plate.fnpIsTarget)
    local label = plate.fnpHealth
    if not show then if label then Visible(label, false) end; return end
    local hp, maximum = UnitHealth(unit) or 0, UnitHealthMax(unit)
    if not maximum or maximum <= 0 then if label then Visible(label, false) end; return end
    if not label then
        label = plate.healthbar:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
        label:SetPoint("CENTER", plate.healthbar, "CENTER", 0, 0)
        label:SetTextColor(1, 1, 1); plate.fnpHealth = label
    end
    -- Health events repeat values (one per token, and on target changes); build
    -- only the text that shows, and only when it changes.
    local mode = self.settings.health
    if label.fnpHP ~= hp or label.fnpMax ~= maximum or label.fnpMode ~= mode then
        label.fnpHP, label.fnpMax, label.fnpMode = hp, maximum, mode
        local text
        if mode == 2 then text = AbbreviateNumbers(hp)
        else
            text = math.floor(math.max(0, math.min(1, hp / maximum)) * 100 + 0.5) .. "%"
            if mode == 3 then text = AbbreviateNumbers(hp) .. "  " .. text end
        end
        Text(label, text)
    end
    FNP.SetNameplateFontSize(label, math.max(7, 9 * (plate.fnpVisualScale or 1)))
    Visible(label, true)
end

-- The engine's level text and skull keep their stock size and place, so they
-- spill off a scaled plate. Moving or re-fonting them crashed the client
-- (2026-10-22); hide them by alpha only and draw our own level in the
-- border's oval instead.
local function NativeLevel(plate, shown)
    local alpha = shown and 1 or 0
    if plate.level and plate.level:GetAlpha() ~= alpha then plate.level:SetAlpha(alpha) end
    if plate.levelicon and plate.levelicon:GetAlpha() ~= alpha then plate.levelicon:SetAlpha(alpha) end
end

function NP:Level(plate, unit)
    local label = plate.fnpLevel
    if not self.settings.level or not unit then
        if label then Visible(label, false) end
        NativeLevel(plate, true); return
    end
    NativeLevel(plate, false)
    if not label then
        -- On the plate, like the native level: a health bar child draws under
        -- the plate's border, which tinted the digits into the oval's gold.
        label = plate:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE"); plate.fnpLevel = label
    end
    PlaceLevel(plate)
    -- Same rules as the stock target frame: difficulty color for enemies,
    -- gold otherwise, "??" where the game shows a skull.
    local level, r, g, b = UnitLevel(unit) or 0, 1, 0.82, 0
    if level <= 0 then r, g, b = 1, 0.1, 0.1
    elseif UnitCanAttack("player", unit) then
        local color = GetDifficultyColor(level); r, g, b = color.r, color.g, color.b
    end
    Text(label, level > 0 and level or "??")
    if label.fnpR ~= r or label.fnpG ~= g or label.fnpB ~= b then
        label.fnpR, label.fnpG, label.fnpB = r, g, b; label:SetTextColor(r, g, b)
    end
    Visible(label, true)
end

local function AuraIcon(row, index)
    local icon = row.icons[index]
    if icon then return icon end
    icon = CreateFrame("Frame", nil, row); icon:EnableMouse(false)
    icon.texture = icon:CreateTexture(nil, "ARTWORK"); icon.texture:SetAllPoints(icon)
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- The client counts the time down (countdownForCooldowns CVar 1): whole
    -- seconds, then minutes from 60 s. No sweep, no flash; only the number.
    local sweep = CreateFrame("Cooldown", nil, icon)
    sweep:SetAllPoints(icon); sweep:EnableMouse(false)
    sweep:SetDrawSwipe(false); sweep:SetDrawBling(false); sweep:SetCountdownAbbrevThreshold(60)
    local number = sweep:GetCountdownFontString()
    number:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    number:ClearAllPoints(); number:SetPoint("BOTTOM", icon, "BOTTOM", 0, -1)
    -- An aura that ran out: draw the row again without it.
    sweep:SetScript("OnCooldownDone", function()
        local owner = this.owner
        owner.cdStart = nil; Visible(owner, false); NP:Queue(owner.plate, "auras")
    end)
    sweep.owner, icon.sweep = icon, sweep
    icon.count = icon:CreateFontString(nil, "OVERLAY"); icon.count:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    icon.count:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, 1)
    row.icons[index] = icon
    return icon
end

-- The row being filled. File-level state instead of a closure per update.
local auraPlate, auraRow, auraCount, auraNow

local function AddAura(name, texture, stacks, dispel, duration, expires, source, stealable, personal, id)
    if not name or not texture or (expires and expires > 0 and expires <= auraNow) then return end
    local size, row = NP.settings.auraSize, auraRow
    if not row then
        row = CreateFrame("Frame", nil, auraPlate); row:EnableMouse(false); row.icons = {}
        auraPlate.fnpAuras, auraRow = row, row
    end
    auraCount = auraCount + 1
    local icon = AuraIcon(row, auraCount)
    if icon.size ~= size then
        icon.size = size; icon:SetWidth(size); icon:SetHeight(size)
        icon:ClearAllPoints(); icon:SetPoint("LEFT", row, "LEFT", (auraCount - 1) * (size + 3), 0)
    end
    if icon.textureID ~= texture then icon.textureID = texture; icon.texture:SetTexture(texture) end
    icon.spellID = id
    Text(icon.count, stacks and stacks > 1 and tostring(stacks) or "")
    icon.plate = auraPlate
    if duration and duration > 0 and expires and expires > auraNow then
        local start = expires - duration
        if icon.cdStart ~= start or icon.cdDuration ~= duration then
            icon.cdStart, icon.cdDuration = start, duration
            icon.sweep:SetCooldown(start, duration)
        end
    elseif icon.cdStart then icon.cdStart = nil; icon.sweep:Clear() end
    Visible(icon, true)
    return id
end

function NP:Auras(plate, unit)
    local s = self.settings
    if not unit or not UnitCanAttack("player", unit) or (not s.own and not s.cc and not s.buffs) then
        HideAuras(plate); self:LayoutExtras(plate); return
    end
    local ccID
    auraPlate, auraRow, auraCount, auraNow = plate, plate.fnpAuras, 0, GetTime()
    -- Engine filters classify CC and caster identity; no spell lists, combat-log
    -- inference or tooltip parsing. Query only enough results for the capped row.
    if s.cc then ccID = AddAura(C_UnitAuras.UnitAura(unit, 1, "HARMFUL|CROWD_CONTROL")) end
    plate.fnpCCID, plate.fnpOwnTotal = ccID, nil
    if s.own then
        -- One aura-array walk; by-index getters re-walk from the start per call.
        local _, total = C_UnitAuras.GetAuraSlots(unit, "HARMFUL|PLAYER", nil, nil, auraSlots)
        plate.fnpOwnTotal = total
        local own = 0
        for i = 1, total or 0 do
            if own >= s.auraCount then break end
            local name, texture, stacks, dispel, duration, expires, source, stealable, personal, id = C_UnitAuras.UnitAuraBySlot(unit, auraSlots[i])
            if name and (not ccID or id ~= ccID) then
                local before = auraCount
                AddAura(name, texture, stacks, dispel, duration, expires, source, stealable, personal, id)
                if auraCount > before then own = own + 1 end
            end
        end
    end
    plate.fnpBuff1, plate.fnpBuff2 = nil, nil
    if s.buffs then
        plate.fnpBuff1 = AddAura(C_UnitAuras.UnitAura(unit, 1, "HELPFUL"))
        plate.fnpBuff2 = AddAura(C_UnitAuras.UnitAura(unit, 2, "HELPFUL"))
    end
    local row, count = auraRow, auraCount
    auraPlate, auraRow = nil, nil
    if row then
        for i = count + 1, #row.icons do
            local icon = row.icons[i]; icon.cdStart = nil; icon.sweep:Clear(); Visible(icon, false)
        end
        row:SetWidth(math.max(1, count * (s.auraSize + 3) - 3)); row:SetHeight(s.auraSize)
        Visible(row, count > 0)
    end
    plate.fnpAuraHeight = count > 0 and s.auraSize + 5 or 0
    self:LayoutExtras(plate)
end

-- ClassicAPI 1.17.10 UNIT_AURA_DELTA lists the aura instances that changed. A
-- refresh redraws the row only when the row shows that spell; a new or lost
-- aura only when the row's inputs moved: your debuff count, the first crowd
-- control, the first two buffs. Another player's debuff on an enemy in a
-- battleground costs a few engine reads, not a row rebuild.
local deltaAura = {}
function NP:AuraDeltaShows(plate, unit, info)
    if info.isFullUpdate then return true end
    local updated, row = info.updatedAuraInstanceIDs, plate.fnpAuras
    if updated and row then
        for i = 1, #updated do
            local d = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, updated[i], deltaAura)
            if d then
                for _, icon in ipairs(row.icons) do
                    if icon.spellID == d.spellId and icon:IsShown() then return true end
                end
            end
        end
    end
    if not info.addedAuraInstanceIDs and not info.removedAuraInstanceIDs then return false end
    local s = self.settings
    if s.own and plate.fnpOwnTotal ~= select(2, C_UnitAuras.GetAuraSlots(unit, "HARMFUL|PLAYER", nil, nil, auraSlots)) then return true end
    if s.cc and plate.fnpCCID ~= select(10, C_UnitAuras.UnitAura(unit, 1, "HARMFUL|CROWD_CONTROL")) then return true end
    return s.buffs and (plate.fnpBuff1 ~= select(10, C_UnitAuras.UnitAura(unit, 1, "HELPFUL"))
        or plate.fnpBuff2 ~= select(10, C_UnitAuras.UnitAura(unit, 2, "HELPFUL"))) or false
end

function NP:Combo(plate)
    local count = self.active and self.settings.combo and plate.fnpIsTarget and GetComboPoints() or 0
    if count <= 0 then if plate.fnpCombo then Visible(plate.fnpCombo, false) end; return end
    if not plate.fnpCombo then
        local row = CreateFrame("Frame", nil, plate); row:EnableMouse(false); row:SetWidth(45); row:SetHeight(7)
        row.pips = {}
        for i = 1, 5 do
            local pip = row:CreateTexture(nil, "OVERLAY"); pip:SetTexture(1, 0.75, 0.15, 1)
            pip:SetWidth(6); pip:SetHeight(6); pip:SetPoint("LEFT", row, "LEFT", (i - 1) * 9, 0)
            row.pips[i] = pip
        end
        plate.fnpCombo = row
    end
    local row = plate.fnpCombo
    local y = self.settings.marks and self.settings.markPosition == "above" and self.settings.markSize + 8 or 4
    if not self.settings.marks and plate.raidicon and Marked(plate) then y = plate.raidicon:GetHeight() + 8 end
    if row.fnpY ~= y then row.fnpY = y; row:ClearAllPoints(); row:SetPoint("BOTTOM", plate.name or plate, "TOP", 0, y) end
    for i = 1, 5 do Visible(row.pips[i], i <= count) end
    Visible(row, true)
end

-- recheck: the unit is new or its faction changed. Kind and faction hold while
-- the plate keeps its unit, and the "<guid>target" token is built once.
function NP:Targeting(plate, unit, recheck)
    if recheck and unit then
        if plate.fnpTargetUnit ~= unit then plate.fnpTargetUnit, plate.fnpTargetToken = unit, unit .. "target" end
        plate.fnpTargetCandidate = not UnitIsPlayer(unit) and UnitCanAttack("player", unit) and true or false
    end
    local show = self.settings.targeting and unit and plate.fnpTargetUnit == unit and plate.fnpTargetCandidate
        and UnitIsUnit(plate.fnpTargetToken, "player") and true or false
    local label = plate.fnpTargeting
    if show and not label then
        label = plate:CreateFontString(nil, "OVERLAY"); label:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
        label:SetPoint("TOP", plate.fnpCastbar or plate.healthbar, "BOTTOM", 0, -4)
        label:SetTextColor(1, 0.4, 0.25); label:SetText("Targeting you"); plate.fnpTargeting = label
    end
    if label then Visible(label, show) end
end

-- Queued work per plate is a sum of these bits, and two pending tables take
-- turns, so health and aura bursts build no tables.
local KIND_BIT = { health = 1, level = 2, auras = 4, targeting = 8 }
local spare = {}

local function Flush()
    queued = nil
    local pending = NP.pending
    NP.pending, spare = spare, pending
    for plate, flags in pairs(pending) do
        pending[plate] = nil
        local unit = NP.active and plate:IsShown() and FNP.GetNameplateUnit(plate)
        if unit then
            plate.fnpNeedsDetails = nil
            if flags % 2 == 1 then NP:Health(plate, unit) end
            if flags % 4 >= 2 then NP:Level(plate, unit) end
            if flags % 8 >= 4 then NP:Auras(plate, unit) end
            if flags >= 8 then NP:Targeting(plate, unit, true) end
        elseif NP.active then Clear(plate) end
    end
end

function NP:Queue(plate, kind)
    if not self.active or not plate then return end
    if not plate:IsShown() then plate.fnpNeedsDetails = true; return end
    local flags, bit = self.pending[plate] or 0, KIND_BIT[kind]
    if flags % (bit * 2) < bit then self.pending[plate] = flags + bit end
    if not queued then queued = true; C_Timer.After(0, Flush) end
end

function NP:Select(plate, selected)
    if selected then self.targetPlate = plate
    elseif self.targetPlate == plate then self.targetPlate = nil end
    if plate.fnpIsTarget ~= selected then
        plate.fnpIsTarget = selected
        FNP.ApplyNameplateScale(plate)
    end
    self:Combo(plate); self:LayoutExtras(plate); self:LayoutMark(plate); self:Glow(plate)
    self:Queue(plate, "health")
end

function NP:TargetChanged()
    self.targetGUID = UnitGUID("target")
    local previous, current = self.targetPlate, C_NamePlate.GetNamePlateForUnit("target")
    self.targetPlate = current and lib.plates[current] and current or nil
    if previous and previous ~= self.targetPlate then self:Select(previous, false) end
    if self.targetPlate then self:Select(self.targetPlate, true) end
    for plate in pairs(lib.plates) do
        if plate.fnpDetailGUID then self:Alpha(plate, plate.fnpDetailGUID) end
    end
end

-- CreatureType.dbc rows in this client: 8 Critter, 11 Totem.
local CRITTER, TOTEM = 8, 11

-- Type, owner and level do not change while a plate keeps its unit.
local function FixedFade(unit)
    local s, kind = NP.settings, UnitCreatureTypeID(unit)
    if s.fadeCritters and kind == CRITTER then return true end
    if s.fadeTotems and kind == TOTEM then return true end
    if s.fadePets and UnitIsOtherPlayersPet(unit) then return true end
    -- Grey by the stock rule (GetDifficultyColor, QuestLogFrame.lua): more
    -- levels below you than the green range. Skull levels never fade.
    if s.fadeTrivial then
        local level = UnitLevel(unit) or 0
        if level > 0 and UnitLevel("player") - level > GetQuestGreenRange() then return true end
    end
    return false
end

-- Combat changes a neutral unit's flags: UNIT_FLAGS asks again.
local function Faded(plate, unit)
    if plate.fnpFixedFade == nil then plate.fnpFixedFade = FixedFade(unit) end
    if plate.fnpFixedFade then return true end
    return NP.settings.fadeNeutral and UnitReaction(unit, "player") == 4 and not UnitAffectingCombat(unit)
end

-- The alpha a plate should have, worked out when one of its inputs changes:
-- your target, the unit, its raid mark, its flags, the settings. Other plates
-- dim while you have a target, faded kinds go further, a marked unit stays at
-- 0.9 or more.
function NP:Alpha(plate, unit)
    local s, wanted = self.settings, 1
    if unit ~= self.targetGUID then
        if self.targetGUID then wanted = s.otherAlpha end
        if s.fade and Faded(plate, unit) then wanted = math.min(wanted, s.fadeAlpha) end
    end
    if GetRaidTargetIndex(unit) then wanted = math.max(wanted, 0.9) end
    if wanted ~= plate.fnpAlpha then
        plate.fnpAlpha = wanted; plate:SetAlpha(wanted); plate.fnpDrawnAlpha = plate:GetAlpha()
    end
end

function NP:Glow(plate)
    local show = self.settings.glow and plate.fnpIsTarget
    local glow = plate.fnpTargetGlow
    if show and not glow then
        glow = plate:CreateTexture(nil, "BORDER")
        glow:SetTexture("Interface\\Tooltips\\Nameplate-Glow")
        -- This stock glow uses a black background; additive blending keeps
        -- that background transparent instead of covering the name/bar.
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 0.8, 0.3, 0.7); glow:SetAllPoints(plate.border or plate.healthbar)
        plate.fnpTargetGlow = glow
    end
    if glow then Visible(glow, show) end
end

-- A plate that gets a unit is drawn at once. Hiding it first and drawing on
-- the next frame made the health text flicker whenever a plate came back.
local function Bind(plate, unit)
    plate.fnpFixedFade = nil
    NP.pending[plate], plate.fnpNeedsDetails, plate.fnpDetailGUID = nil, nil, unit
    NP:Select(plate, unit == NP.targetGUID)
    NP:Alpha(plate, unit)
    NP:Health(plate, unit); NP:Level(plate, unit); NP:Auras(plate, unit); NP:Targeting(plate, unit, true)
end

-- The engine sets a plate's alpha itself (its target dimming, ClassicAPI's
-- nameplate*Alpha CVars) and no event says when; each frame puts ours back
-- when the plate shows something else. A plate reports its alpha as a byte
-- (n/255) and the CVars replace writes of 1 and 0.5 (ClassicAPI 1.17.8), so
-- compare with what the plate showed after our last write.
local function Render(plate)
    local alpha = plate.fnpAlpha
    if alpha and plate:GetAlpha() ~= plate.fnpDrawnAlpha then
        plate:SetAlpha(alpha); plate.fnpDrawnAlpha = plate:GetAlpha()
    end
end

function NP:Shutdown()
    self.active = false
    if driver then driver:UnregisterAllEvents() end
    table.wipe(self.pending)
    self.targetPlate, self.targetGUID = nil, nil
end
module.shutdown = function() NP:Shutdown() end

-- Turning details off restores the plates once; while off, settings changes
-- leave them to the game.
function NP:ApplyConfiguration(layoutOnly)
    local wasActive = self.active
    self.active = FNP.IsEnabled(module.title, true) and FNP.OwnsNameplates()
    module.rendering = self.active
    FNP.RefreshRendering()
    if driver and module.listening ~= self.active then
        module.listening = self.active
        driver:UnregisterAllEvents()
        if self.active then
            for _, ev in ipairs(DETAIL_EVENTS) do driver:RegisterEvent(ev) end
            for _, ev in ipairs(PLATE_EVENTS) do FNP.RegisterPlateEvent(driver, ev) end
        end
    end
    local s = self.settings
    s.marks = self.active and FNP.GetOverride("nameplate_marks", 1) == 1
    s.markSize = FNP.GetNumber("nameplate_raidmark_size", 20, 12, 40)
    s.markPosition = FNP.GetOverride("nameplate_raidmark_position", "left")
    s.glow = FNP.GetOverride("nameplate_target_glow", 0) == 1
    s.otherAlpha = FNP.GetNumber("nameplate_other_alpha", 0.8, 0.2, 1)
    s.health = math.floor(FNP.GetNumber("nameplate_health", 1, 0, 3))
    s.healthTarget = FNP.GetOverride("nameplate_health_target", 1) == 1
    s.level = FNP.GetOverride("nameplate_level", 1) == 1
    s.own = FNP.GetOverride("nameplate_own_auras", 1) == 1
    s.cc = FNP.GetOverride("nameplate_cc", 1) == 1
    s.buffs = FNP.GetOverride("nameplate_enemy_buffs", 0) == 1
    s.auraSize = FNP.GetNumber("nameplate_aura_size", 20, 14, 32)
    s.auraCount = math.floor(FNP.GetNumber("nameplate_aura_count", 3, 1, 6))
    s.combo = FNP.GetOverride("nameplate_combo", 1) == 1
    s.targeting = FNP.GetOverride("nameplate_targeting", 0) == 1
    s.fadeCritters = FNP.GetOverride("nameplate_fade_critters", 0) == 1
    s.fadeTotems = FNP.GetOverride("nameplate_fade_totems", 0) == 1
    s.fadePets = FNP.GetOverride("nameplate_fade_pets", 0) == 1
    s.fadeTrivial = FNP.GetOverride("nameplate_fade_trivial", 0) == 1
    s.fadeNeutral = FNP.GetOverride("nameplate_fade_neutral", 0) == 1
    s.fade = s.fadeCritters or s.fadeTotems or s.fadePets or s.fadeTrivial or s.fadeNeutral
    s.fadeAlpha = FNP.GetNumber("nameplate_fade_alpha", 0.3, 0.1, 0.8)
    -- UNIT_TARGET (ClassicAPI 1.18) says when an enemy turns to someone else,
    -- UNIT_FLAGS when a unit's combat flag changes.
    if driver then
        if self.active and s.targeting then FNP.RegisterPlateEvent(driver, "UNIT_TARGET") else driver:UnregisterEvent("UNIT_TARGET") end
        if self.active and s.fadeNeutral then FNP.RegisterPlateEvent(driver, "UNIT_FLAGS") else driver:UnregisterEvent("UNIT_FLAGS") end
    end
    for plate in pairs(lib.plates) do plate.fnpFixedFade = nil end
    if self.active then self:TargetChanged() end
    for plate in pairs(lib.plates) do
        if self.active then
            -- A plate that got its unit while details were off.
            if plate.fnpUnitGUID and plate.fnpDetailGUID ~= plate.fnpUnitGUID then
                Bind(plate, plate.fnpUnitGUID)
            else
                self:LayoutMark(plate)
                if not s.level then NativeLevel(plate, true) end
                if plate:IsShown() and not layoutOnly then
                    self:Queue(plate, "health"); self:Queue(plate, "level"); self:Queue(plate, "auras"); self:Queue(plate, "targeting")
                    self:Combo(plate)
                end
            end
        elseif wasActive then
            plate.fnpIsTarget = false
            Clear(plate); self:LayoutMark(plate, true); NativeLevel(plate, true)
            plate:SetAlpha(1); plate.fnpAlpha, plate.fnpDrawnAlpha, plate.fnpDetailGUID = nil, nil, nil
        end
    end
    if wasActive and not self.active then self.targetPlate, self.targetGUID = nil, nil; FNP.RefreshNameplateScale() end
end

module.enable = function(self)
    if not driver then
        driver = CreateFrame("Frame", "FNPNameplateDetailsEvents")
        FNP.SetEventHandler(driver, function(_, ev, unit, info)
            if not NP.active then return end
            if ev == "PLAYER_TARGET_CHANGED" then NP:TargetChanged()
            elseif ev == "PLAYER_COMBO_POINTS" then if NP.targetPlate then NP:Combo(NP.targetPlate) end
            elseif ev == "RAID_TARGET_UPDATE" then NP:RefreshMarks()
            elseif ev == "PLAYER_ENTERING_WORLD" then
                -- Queued, not cleared first: a cleared plate showed no text until
                -- the next frame (the flicker Bind avoids).
                for plate in pairs(lib.plates) do
                    NP:Queue(plate, "health"); NP:Queue(plate, "level"); NP:Queue(plate, "auras"); NP:Queue(plate, "targeting")
                end
                NP:TargetChanged()
            elseif unit then
                if ev == "UNIT_TARGET" or ev == "UNIT_FLAGS" or ev == "UNIT_FACTION" then
                    local plate = C_NamePlate.GetNamePlateForUnit(unit)
                    if not plate or not lib.plates[plate] then return end
                    if ev == "UNIT_TARGET" then NP:Queue(plate, "targeting"); return end
                    if ev == "UNIT_FACTION" then
                        plate.fnpFixedFade = nil; NP:Queue(plate, "auras"); NP:Queue(plate, "targeting")
                    end
                    if plate.fnpDetailGUID then NP:Alpha(plate, plate.fnpDetailGUID) end
                    return
                end
                local kind = ev == "UNIT_AURA_DELTA" and "auras" or (ev == "UNIT_LEVEL" and "level" or "health")
                if (kind == "level" and not NP.settings.level) or (kind == "auras" and not NP.settings.own and not NP.settings.cc and not NP.settings.buffs)
                    or (kind == "health" and NP.settings.health == 0) then return end
                local plate = C_NamePlate.GetNamePlateForUnit(unit)
                if plate and lib.plates[plate] then
                    if kind == "auras" then
                        if NP:AuraDeltaShows(plate, unit, info) then NP:Queue(plate, kind) end
                    elseif kind ~= "health" or not NP.settings.healthTarget or plate.fnpIsTarget then NP:Queue(plate, kind) end
                end
            end
        end)
        table.insert(lib.OnUpdate, Render)
        table.insert(lib.OnAdded, function(plate, unit)
            if NP.active then Bind(plate, unit) end
        end)
        local function Removed(plate)
            Clear(plate); plate.fnpDetailGUID, plate.fnpAlpha, plate.fnpDrawnAlpha = nil, nil, nil
            if NP.targetPlate == plate then NP.targetPlate = nil end
            if plate.fnpIsTarget then plate.fnpIsTarget = false; FNP.ApplyNameplateScale(plate) end
        end
        table.insert(lib.OnRemoved, Removed)
        table.insert(lib.OnShow, function(plate)
            -- Native z-order rebuilds can hide/show the same bound frame.
            -- Lifecycle events own identity; do not rescan on transient shows.
            if NP.active then
                NP:LayoutMark(plate)
                if plate.fnpNeedsDetails or not plate.fnpDetailGUID then
                    NP:Queue(plate, "health"); NP:Queue(plate, "level"); NP:Queue(plate, "auras"); NP:Queue(plate, "targeting")
                end
            end
        end)
    end
    NP:ApplyConfiguration()
end

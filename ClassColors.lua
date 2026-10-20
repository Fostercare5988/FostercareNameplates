local FNP = FostercareNameplates
if not FNP then return end
local module = FNP:register({ title = "Nameplate Class Colors", category = "Nameplates",
    enabled = true, description = "Changes player nameplate health bars to their class color." })
local initialized, active

local function Reset(plate)
    plate.fnpClassUnit, plate.fnpCachedClass, plate.fnpNextClassQuery = nil, nil, nil
    plate.fnpReactionColor = nil
end

module.enable = function()
    active = FNP.IsEnabled(module.title) and FNP.OwnsNameplates()
    module.rendering = active
    FNP.RefreshRendering()
    if not initialized then
        initialized = true
        table.insert(FNP.libnameplate.OnShow, function(plate)
            if plate.fnpClassUnit ~= plate.fnpUnitGUID then Reset(plate) end
        end)
        table.insert(FNP.libnameplate.OnAdded, Reset)
        table.insert(FNP.libnameplate.OnRemoved, Reset)
        table.insert(FNP.libnameplate.OnUpdate, function(plate, unit, now)
            if not active or not plate.healthbar then return end
            if unit ~= plate.fnpClassUnit or not plate.fnpNextClassQuery or now >= plate.fnpNextClassQuery then
                local class
                if unit and UnitIsPlayer(unit) then local localized; localized, class = UnitClass(unit) end
                plate.fnpClassUnit, plate.fnpCachedClass = unit, class
                -- A class cannot change for a GUID. Retry unresolved identities
                -- slowly; avoid recurring class/name/level queries once known.
                plate.fnpNextClassQuery = class and math.huge or now + 0.5
            end
            local class = plate.fnpCachedClass
            local color = class and RAID_CLASS_COLORS[class]
            if not unit or not color then return end
            local r, g, b = plate.healthbar:GetStatusBarColor()
            if math.abs(r - color.r) > 0.01 or math.abs(g - color.g) > 0.01 or math.abs(b - color.b) > 0.01 then
                local reaction = plate.fnpReactionColor or {}
                reaction[1], reaction[2], reaction[3] = r, g, b
                plate.fnpReactionColor = reaction
                plate.healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
            end
        end)
    end
    if not active then
        for plate in pairs(FNP.libnameplate.plates) do
            if plate.fnpReactionColor then plate.healthbar:SetStatusBarColor(unpack(plate.fnpReactionColor)) end
            Reset(plate)
        end
    end
end

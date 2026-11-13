local FNP = FostercareNameplates
if not FNP then return end
local module = FNP:register({ title = "Nameplate Class Colors", category = "Nameplates",
    enabled = true, description = "Changes player nameplate health bars to their class color." })
local initialized, active

-- A player's class is read once, when the plate gets its unit: a GUID is a
-- player or it is not, and a class never changes.
local function Bind(plate, guid)
    local color
    if active and guid and UnitIsPlayer(guid) then
        local _, class = UnitClass(guid)
        color = class and RAID_CLASS_COLORS[class]
    end
    plate.fnpClassColor, plate.fnpBarR, plate.fnpBarG, plate.fnpBarB = color, nil, nil, nil
end

local function Unbind(plate) Bind(plate, nil) end

-- The engine colors the bar itself (reaction, tapped) and no event says when,
-- so each frame puts the class color back when the bar shows another one. The
-- color read back after our write is what "ours" looks like; the engine's own
-- is kept for when class colors are turned off.
-- UNVERIFIED: test in game: does the engine color the bar every frame? Target
-- an NPC; "300 0 0 1" (blue stays) means only on events (Paint can go), red
-- back at 2 means every frame (it stays):
-- /run local b,t=C_NamePlate.GetNamePlateForUnit("target"):GetChildren(),0 b:SetStatusBarColor(0,0,1) CreateFrame("Frame"):SetScript("OnUpdate",function() t=t+1 if t==2 or t==300 then print(t,b:GetStatusBarColor()) end end)
local function Paint(plate)
    local color = plate.fnpClassColor
    if not color then return end
    local bar = plate.healthbar
    local r, g, b = bar:GetStatusBarColor()
    if r ~= plate.fnpBarR or g ~= plate.fnpBarG or b ~= plate.fnpBarB then
        local reaction = plate.fnpReactionColor or {}
        reaction[1], reaction[2], reaction[3] = r, g, b
        plate.fnpReactionColor = reaction
        bar:SetStatusBarColor(color.r, color.g, color.b, 1)
        plate.fnpBarR, plate.fnpBarG, plate.fnpBarB = bar:GetStatusBarColor()
    end
end

module.enable = function()
    active = FNP.IsEnabled(module.title) and FNP.OwnsNameplates()
    module.rendering = active
    FNP.RefreshRendering()
    local lib = FNP.libnameplate
    if not initialized then
        initialized = true
        table.insert(lib.OnAdded, Bind)
        table.insert(lib.OnRemoved, Unbind)
        table.insert(lib.OnUpdate, Paint)
    end
    for plate in pairs(lib.plates) do
        if not active and plate.fnpClassColor and plate.fnpReactionColor then
            plate.healthbar:SetStatusBarColor(unpack(plate.fnpReactionColor))
        end
        Bind(plate, plate.fnpUnitGUID)
    end
end

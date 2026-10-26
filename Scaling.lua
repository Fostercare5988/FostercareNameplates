local FNP = FostercareNameplates
if not FNP then return end

local module = FNP:register({
    title = "Nameplate Scale", category = "Nameplates", enabled = true,
    description = "Adjust native nameplate size and castbar proportions.",
    config = { nameplate_scale = 1, nameplate_follow_ui = 0,
        nameplate_cast_height = 10, nameplate_cast_gap = 3 },
})

local function Dimensions(object, width, height)
    if not object then return end
    width, height = math.max(1, math.floor(width + 0.5)), math.max(1, math.floor(height + 0.5))
    if object:GetWidth() ~= width then object:SetWidth(width) end
    if object:GetHeight() ~= height then object:SetHeight(height) end
end

local function Capture(plate)
    if not plate.fnpOrigW then
        plate.fnpOrigW, plate.fnpOrigH = plate:GetWidth(), plate:GetHeight()
        if plate.fnpOrigW <= 20 then plate.fnpOrigW, plate.fnpOrigH = 110, 14 end
        for _, entry in ipairs({ {"healthbar", "fnpHb", 110, 14}, {"border", "fnpBorder", 128, 16},
            {"glow", "fnpGlow", 128, 16}, {"levelicon", "fnpLevel", 11, 11}, {"dragon", "fnpDragon", 128, 64} }) do
            local object, prefix = plate[entry[1]], entry[2]
            local w, h = object and object:GetWidth(), object and object:GetHeight()
            plate[prefix .. "OrigW"] = w and w > 0 and w or entry[3]
            plate[prefix .. "OrigH"] = h and h > 0 and h or entry[4]
        end
    end
end

function FNP.LayoutNameplateCastbar(plate)
    local cb = plate.fnpCastbar
    if not cb or not FNP.OwnsNameplates() then return end
    local scale = plate.fnpVisualScale or 1
    local height = FNP.GetNumber("nameplate_cast_height", 10, 6, 18) * scale
    local gap = FNP.GetNumber("nameplate_cast_gap", 3, 0, 16) * scale
    Dimensions(cb, (plate.healthbar or plate):GetWidth() - 22 * scale, height)
    local anchor = plate.healthbar or plate
    local p, a, r, x, y = cb:GetPoint(1)
    if p ~= "TOP" or a ~= anchor or r ~= "BOTTOM" or x ~= 8 * scale or y ~= -gap then
        cb:ClearAllPoints(); cb:SetPoint("TOP", anchor, "BOTTOM", 8 * scale, -gap)
    end
    Dimensions(cb.texture, height + 8 * scale, height + 8 * scale)
    Dimensions(cb.texture.icon, height + 2 * scale, height + 2 * scale)
    Dimensions(cb.spark, 20 * scale, 20 * scale)
    local font, oldSize, flags = cb.text:GetFont()
    local size = math.max(7, math.floor(9 * scale + 0.5))
    if oldSize ~= size or flags ~= "OUTLINE" then cb.text:SetFont(font, size, "OUTLINE") end
end

local function Apply(plate, restore)
    if not plate or (not FNP.OwnsNameplates() and not restore) then return end
    Capture(plate)
    local enabled = not restore and FNP.IsEnabled(module.title)
    local scale = 1
    if enabled then
        scale = FNP.GetNumber("nameplate_scale", 1, 0.1, 4)
        if FNP.GetOverride("nameplate_follow_ui", 0) == 1 then
            scale = scale * FNP.ClampNumber(UIParent:GetScale(), 1, 0.2, 2)
        end
        if plate.fnpIsTarget then scale = scale * FNP.GetNumber("nameplate_target_scale", 1.1, 1, 1.5) end
    end
    plate.fnpVisualScale, plate.fnpScaleOwned = scale, enabled
    -- Check every owned component at lifecycle/settings boundaries. Native
    -- projection may reset a child while leaving the root width unchanged.
    Dimensions(plate, plate.fnpOrigW * scale, plate.fnpOrigH * scale)
    Dimensions(plate.healthbar, plate.fnpHbOrigW * scale, plate.fnpHbOrigH * scale)
    Dimensions(plate.border, plate.fnpBorderOrigW * scale, plate.fnpBorderOrigH * scale)
    Dimensions(plate.glow, plate.fnpGlowOrigW * scale, plate.fnpGlowOrigH * scale)
    Dimensions(plate.levelicon, plate.fnpLevelOrigW * scale, plate.fnpLevelOrigH * scale)
    Dimensions(plate.dragon, plate.fnpDragonOrigW * scale, plate.fnpDragonOrigH * scale)
    -- Engine-created name/level regions retain their original parent, font,
    -- scale and anchors. Do not insert them into Lua-owned scaling frames.
    FNP.LayoutNameplateCastbar(plate)
    if FNP.Nameplates then FNP.Nameplates:LayoutExtras(plate) end
end

FNP.ApplyNameplateScale = Apply
function FNP.RestoreNameplateScale(plate)
    if plate.fnpScaleOwned then Apply(plate, true) end
end
function FNP.RefreshNameplateScale()
    for plate in pairs(FNP.libnameplate.plates) do
        if plate:IsShown() then Apply(plate) end
    end
end

module.enable = function(self)
    if not self.initialized then
        self.initialized = true
        table.insert(FNP.libnameplate.OnInit, function(plate) Apply(plate) end)
        table.insert(FNP.libnameplate.OnShow, function(plate) Apply(plate) end)
        self.watcher = CreateFrame("Frame")
        FNP.SetEventHandler(self.watcher, FNP.RefreshNameplateScale)
    end
    self.watcher:UnregisterAllEvents()
    if FNP.IsEnabled(module.title) and FNP.OwnsNameplates() then
        -- DISPLAY_SIZE_CHANGED is a 1.12 event. UI_SCALE_CHANGED is in no
        -- FrameXML file or DLL doc, so it is asked for only if the client knows it.
        self.watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
        if C_EventUtils.IsEventValid("UI_SCALE_CHANGED") then self.watcher:RegisterEvent("UI_SCALE_CHANGED") end
    end
    FNP.RefreshNameplateScale()
end

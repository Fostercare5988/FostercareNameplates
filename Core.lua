-- FostercareNameplates owns only nameplate features and their settings.
local superMajor, superMinor = string.match(tostring(SUPERWOW_VERSION or ""), "^(%d+)%.(%d+)")
superMajor, superMinor = tonumber(superMajor), tonumber(superMinor)
if type(CLASSIC_API_VERSION) ~= "number" or CLASSIC_API_VERSION < 11515
    or not superMajor or not (superMajor > 2 or (superMajor == 2 and superMinor >= 2)) then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("FostercareNameplates requires ClassicAPI 1.15.15+ and SuperWoW 2.2+.", 1, 0.3, 0.3)
    end
    return
end

local FNP = { mods = {}, moduleOrder = {}, overwrites = {}, version = "1.0.0" }
FostercareNameplates = FNP
-- Older Tweaks builds still own their plates. Treat them as a competing owner
-- rather than installing a second set of native hooks during an upgrade.
FNP.legacyOwner = FostercareTweaks and FostercareTweaks.libnameplate
    and FostercareTweaks.nameplatesEnabled
if type(FostercareNameplates_Config) ~= "table" then FostercareNameplates_Config = {} end
local config = FostercareNameplates_Config
if type(config.overwrites) ~= "table" then config.overwrites = {} end

-- Legacy settings cross only through this one-time scalar import. The optional
-- load ordering lets ClassicAPI expose Tweaks' saved table before this file.
-- Never alias its table, cache, registry, hooks or runtime objects.
if config.settingsVersion == nil then
    local legacy = FostercareTweaks_Config
    if type(legacy) == "table" then
        for _, key in ipairs({ "Nameplate Scale", "Nameplate Details", "Nameplate Class Colors",
            "Nameplate Castbar", "Enemy Nameplate Cooldowns", "nameplatesEnabled", "nameplate_layout_version" }) do
            local value = legacy[key]
            if config[key] == nil and type(value) == "number" then config[key] = value end
        end
        if type(legacy.overwrites) == "table" then
            for key, value in pairs(legacy.overwrites) do
                if type(key) == "string" and string.sub(key, 1, 10) == "nameplate_"
                    and config.overwrites[key] == nil and (type(value) == "number" or type(value) == "string") then
                    config.overwrites[key] = value
                end
            end
        end
        if config.overwrites.nameplate_uninterruptible == nil then
            config.overwrites.nameplate_uninterruptible = legacy["Uninterruptible Castbars"] == 0 and 0 or 1
        end
    end
    config.settingsVersion = 1
end

function FNP:register(module)
    if not self.mods[module.title] then table.insert(self.moduleOrder, module.title) end
    self.mods[module.title] = module
    return module
end

function FNP:Initialize()
    if self.initialized then return end
    self.initialized = true
    self.MigrateNameplateSettings()
    for _, title in ipairs(self.moduleOrder) do
        local module = self.mods[title]
        if config[title] == nil then config[title] = module.enabled and 1 or 0 end
        for key, value in pairs(module.config or {}) do
            if config.overwrites[key] ~= nil then value = config.overwrites[key] end
            self.overwrites[key] = value
        end
    end
    if not self.OwnsNameplates() then return end
    for _, title in ipairs(self.moduleOrder) do
        local module = self.mods[title]
        if config[title] == 1 and module.enable then
            local ok, err = pcall(module.enable, module)
            if not ok and DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("FostercareNameplates: " .. title .. ": " .. tostring(err), 1, 0.3, 0.3)
            end
        end
    end
end

local frame = CreateFrame("Frame", "FNPInitialize", UIParent)
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(...)
    local ev = FNP.EventArgs(...)
    if ev == "VARIABLES_LOADED" or ev == "PLAYER_LOGIN" then
        FNP:Initialize()
        frame:UnregisterAllEvents()
    end
end)

SLASH_FOSTERCARENAMEPLATES1 = "/fnp"
SLASH_FOSTERCARENAMEPLATES2 = "/fostercarenameplates"
SlashCmdList.FOSTERCARENAMEPLATES = function()
    local settings = FostercareNameplatesSettingsGUI
    if settings:IsShown() then settings:Hide() else settings:Show() end
end

-- FostercareNameplates owns only nameplate features and their settings.
local superMajor, superMinor = string.match(tostring(SUPERWOW_VERSION or ""), "^(%d+)%.(%d+)")
superMajor, superMinor = tonumber(superMajor), tonumber(superMinor)
if type(CLASSIC_API_VERSION) ~= "number" or CLASSIC_API_VERSION < 11711
    or not superMajor or not (superMajor > 2 or (superMajor == 2 and superMinor >= 2)) then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("FostercareNameplates requires ClassicAPI 1.17.11+ and SuperWoW 2.2+.", 1, 0.3, 0.3)
    end
    return
end

local FNP = { mods = {}, moduleOrder = {}, overwrites = {} }
FostercareNameplates = FNP
if type(FostercareNameplates_Config) ~= "table" then FostercareNameplates_Config = {} end
local config = FostercareNameplates_Config
if type(config.overwrites) ~= "table" then config.overwrites = {} end
config.settingsVersion = nil -- retired with the FostercareTweaks settings import

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
frame:SetScript("OnEvent", function(a1, a2)
    local ev = FNP.EventArgs(a1, a2)
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

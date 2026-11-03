-- FostercareNameplates owns only nameplate features and their settings.
-- Requires ClassicAPI and SuperWoW, checked as loaded; VanillaForge's
-- UPSTREAM_VERSIONS.json names the versions.
if type(CLASSIC_API_VERSION) ~= "number" or not SUPERWOW_VERSION then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[FostercareNameplates]|r requires ClassicAPI and SuperWoW.", 1, 0.2, 0.2)
    end
    return
end

local FNP = { mods = {}, moduleOrder = {}, overwrites = {} }
FostercareNameplates = FNP
if type(FostercareNameplates_Config) ~= "table" then FostercareNameplates_Config = {} end
local config = FostercareNameplates_Config
if type(config.overwrites) ~= "table" then config.overwrites = {} end
config.nameplate_layout_version = nil -- retired with the UI-scale size migration, 2026-11-03

function FNP:register(module)
    if not self.mods[module.title] then table.insert(self.moduleOrder, module.title) end
    self.mods[module.title] = module
    return module
end

function FNP:Initialize()
    if self.initialized then return end
    self.initialized = true
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

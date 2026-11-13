-- FostercareNameplates owns only nameplate features and their settings.
-- Requires ClassicAPI, SuperWoW and NamPower, checked as loaded; VanillaForge's
-- UPSTREAM_VERSIONS.json names the versions.
if type(CLASSIC_API_VERSION) ~= "number" or not SUPERWOW_VERSION or not GetNampowerVersion then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff2020[FostercareNameplates]|r requires ClassicAPI, SuperWoW and NamPower.", 1, 0.2, 0.2)
    return
end

local FNP = { mods = {}, moduleOrder = {}, overwrites = {} }
FostercareNameplates = FNP
if type(FostercareNameplates_Config) ~= "table" then FostercareNameplates_Config = {} end
local config = FostercareNameplates_Config
if type(config.overwrites) ~= "table" then config.overwrites = {} end

function FNP:register(module)
    if not self.mods[module.title] then table.insert(self.moduleOrder, module.title) end
    self.mods[module.title] = module
    return module
end

-- Saved keys besides each module's switch (its title) and options (its config
-- keys). Any other key is retired and goes at load, with no line of its own
-- (KNOWN_PATTERNS KP-64).
local SAVED = { nameplatesEnabled = true, overwrites = true }

-- A module that fails to start reaches the error handler with its stack, and
-- the modules after it still start (KNOWN_PATTERNS KP-63).
local starting
local function Start() starting:enable() end

function FNP:Initialize()
    for _, title in ipairs(self.moduleOrder) do
        local module = self.mods[title]
        if config[title] == nil then config[title] = module.enabled and 1 or 0 end
        if module.config then
            for key, value in pairs(module.config) do
                if config.overwrites[key] ~= nil then value = config.overwrites[key] end
                self.overwrites[key] = value
            end
        end
    end
    for key in pairs(config) do
        if not SAVED[key] and not self.mods[key] then config[key] = nil end
    end
    for key in pairs(config.overwrites) do
        if self.overwrites[key] == nil then config.overwrites[key] = nil end
    end
    if not self.OwnsNameplates() then return end
    for _, title in ipairs(self.moduleOrder) do
        starting = self.mods[title]
        if config[title] == 1 and starting.enable then xpcall(Start, geterrorhandler()) end
    end
    starting = nil
end

-- The saved table loads before the files (## LoadSavedVariablesFirst); every
-- module has registered by VARIABLES_LOADED.
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
    frame:UnregisterAllEvents()
    FNP:Initialize()
end)

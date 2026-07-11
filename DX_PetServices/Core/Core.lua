local addonName, ns = ...

ns.addonName = addonName
ns.displayName = "DX Pet Services"
ns.version = "0.5.4"
ns.modules = ns.modules or {}
ns.moduleOrder = ns.moduleOrder or {}
ns.initialized = false
ns.enabled = false

local CHAT_PREFIX = "|cff57c7ffDX Pet Services:|r"

local function CallModuleMethod(owner, methodName, ...)
    local method = owner and owner[methodName]
    if type(method) ~= "function" then
        return true
    end

    local args = { ... }
    local ok, err = xpcall(function()
        return method(owner, unpack(args))
    end, geterrorhandler())
    if not ok then
        return false, err
    end
    return true
end

-- Module registry

function ns:RegisterModule(name, module)
    assert(type(name) == "string" and name ~= "", "DX Pet Services: module name required")
    assert(type(module) == "table", "DX Pet Services: module table required")

    module.name = name
    module.addon = self
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = module
    return module
end

function ns:GetModule(name)
    return self.modules[name]
end

function ns:Print(...)
    print(CHAT_PREFIX, ...)
end

function ns:CountKeys(tbl)
    local count = 0
    if type(tbl) ~= "table" then
        return count
    end
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Addon lifecycle

function ns:Initialize()
    if self.initialized then
        return
    end

    if not self.Database then
        error("DX Pet Services database module did not load")
    end

    self.Database:Initialize()

    for _, module in ipairs(self.moduleOrder) do
        CallModuleMethod(module, "OnInitialize")
    end

    self.initialized = true
end

function ns:Enable()
    if self.enabled then
        return
    end

    for _, module in ipairs(self.moduleOrder) do
        CallModuleMethod(module, "OnEnable")
    end

    self.enabled = true
end

function ns:RefreshJournal()
    local journalUI = self:GetModule("JournalUI")
    if journalUI then
        journalUI:RefreshAll()
    end
end

-- Bootstrap

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ns:Initialize()
    elseif event == "PLAYER_LOGIN" then
        if not ns.initialized then
            ns:Initialize()
        end
        ns:Enable()
    end
end)

-- Slash commands

SLASH_DXPETS1 = "/dxpets"
SlashCmdList.DXPETS = function(message)
    message = strtrim(message or ""):lower()

    if message == "debug" then
        ns.db.settings.debug = not ns.db.settings.debug
        ns:Print("Debug mode", ns.db.settings.debug and "enabled." or "disabled.")
        return
    end

    if message == "settings" or message == "options" then
        ns:GetModule("SettingsUI"):Open()
        return
    end

    if message == "mode battle" or message == "battle" then
        local collectorMode = ns:GetModule("CollectorMode")
        if collectorMode then
            collectorMode:SetMode("BATTLE")
            ns:Print("Pet Journal view: Battle Pet Mode.")
        end
        return
    end

    if message == "mode collector" or message == "collector" then
        local collectorMode = ns:GetModule("CollectorMode")
        if collectorMode then
            collectorMode:SetMode("COLLECTOR")
            ns:Print("Pet Journal view: Collector Mode.")
        end
        return
    end

    if message == "resetfilter" then
        ns.charDB.journal.filterMode = "ALL"
        ns:RefreshJournal()
        ns:Print("Character favorite filter reset to All Pets.")
        return
    end

    if message == "tracker" or message == "pettracker" then
        local tracker = ns:GetModule("PetTracker")
        if not WorldMapFrame or not WorldMapFrame:IsShown() then
            ToggleWorldMap()
        end
        C_Timer.After(0.1, function()
            tracker:TogglePanel()
        end)
        return
    end

    if message == "trackerdebug" or message == "tracker debug" then
        local tracker = ns:GetModule("PetTracker")
        tracker:RefreshWorldMap()
        local stats = tracker and tracker.lastMapPinStats or nil
        if stats then
            ns:Print(string.format(
                "Tracker map pins | map=%s source=%s species=%d coordinates=%d acquired=%d provider=%s data=%s dense=%d",
                tostring(stats.mapID or "nil"),
                tostring(stats.sourceMapID or "nil"),
                tonumber(stats.species) or 0,
                tonumber(stats.coordinates) or 0,
                tonumber(stats.acquired) or 0,
                tostring(stats.renderer or (tracker.mapCanvasHooked and "dx-pet-canvas" or "missing")),
                tostring(stats.locationSource or "unknown"),
                tonumber(stats.denseCoordinates) or 0
            ))
        else
            ns:Print("Tracker map pins | no refresh statistics available; open the world map and try again.")
        end
        return
    end

    if message == "autosummon on" or message == "autosummon favorites" or message == "autosummon favorite" then
        local autoSummon = ns:GetModule("AutoSummon")
        if autoSummon then
            autoSummon:SetMode("ON")
            ns:Print("Auto Summon: ON (Character Favorites).")
        end
        return
    end

    if message == "autosummon random" or message == "autosummon all" then
        local autoSummon = ns:GetModule("AutoSummon")
        if autoSummon then
            autoSummon:SetMode("RANDOM")
            ns:Print("Auto Summon: RANDOM.")
        end
        return
    end

    if message == "autosummon off" then
        local autoSummon = ns:GetModule("AutoSummon")
        if autoSummon then
            autoSummon:SetMode("OFF")
            ns:Print("Auto Summon: OFF.")
        end
        return
    end

    if message == "autosummon" then
        local autoSummon = ns:GetModule("AutoSummon")
        if autoSummon then
            ns:Print("Auto Summon:", autoSummon:CycleMode() .. ".")
        end
        return
    end

    local favoriteCount = ns:CountKeys(ns.charDB and ns.charDB.favorites and ns.charDB.favorites.exact)
    local autoSummon = ns:GetModule("AutoSummon")
    local autoSummonMode = autoSummon and autoSummon:GetMode() or "OFF"
    local staticPetDB = ns.ATTPetSourceDB
    local staticSourceText = staticPetDB and string.format(
        "ATT %s: %d NPCs",
        tostring(staticPetDB.sourceVersion or "?"),
        tonumber(staticPetDB.npcCount) or 0
    ) or "ATT source DB unavailable"
    ns:Print(string.format("v%s | Character favorites: %d | Auto Summon: %s | %s", ns.version, favoriteCount, autoSummonMode, staticSourceText))
    ns:Print("Commands: /dxpets, /dxpets tracker, /dxpets trackerdebug, /dxpets settings, /dxpets mode [battle|collector], /dxpets autosummon [on|off|random], /dxpets resetfilter, /dxpets debug")
end

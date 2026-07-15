local addonName, ns = ...

local Database = {}
ns.Database = Database

local ACCOUNT_SCHEMA = 12
local CHARACTER_SCHEMA = 5

local ACCOUNT_DEFAULTS = {
    schemaVersion = ACCOUNT_SCHEMA,
    settings = {
        debug = false,
        defaultView = "BATTLE",
        npcPetDisplays = true,
        worldMapIcons = true,
        petTrackerMapIcons = true,
        petTrackerHideCapturedPins = true,
        petTrackerOnlyWhenPanelOpen = false,
        petTrackerPinMode = "ALL",
        petTrackerPinSize = 100,
        petTrackerPinOpacity = 100,
        petTrackerNearbyAlerts = true,
        petTrackerNearbyAutoNameplates = true,
        petTrackerNearbyAlertSound = true,
        petTrackerObjectiveTracker = false,
        dungeonTooltipInfo = true,
        bossIcons = true,
    },
    migrations = {
        nativeFavoritesImported = false,
    },
    npcPetSources = {},
    npcNames = {},
}

local CHARACTER_DEFAULTS = {
    schemaVersion = CHARACTER_SCHEMA,
    favorites = {
        exact = {},
        species = {},
    },
    journal = {
        filterMode = "ALL",
        viewMode = "BATTLE",
    },
    autoSummon = {
        enabled = false,
        source = "FAVORITES",
    },
}

local VALID_FILTER_MODES = { ALL = true, EXACT = true }
local VALID_VIEW_MODES = { BATTLE = true, COLLECTOR = true }
local VALID_AUTO_SUMMON_SOURCES = { FAVORITES = true, ALL = true }

local BOOLEAN_SETTINGS = {
    "npcPetDisplays",
    "worldMapIcons",
    "petTrackerMapIcons",
    "petTrackerHideCapturedPins",
    "petTrackerOnlyWhenPanelOpen",
    "petTrackerNearbyAlerts",
    "petTrackerNearbyAutoNameplates",
    "petTrackerNearbyAlertSound",
    "petTrackerObjectiveTracker",
    "dungeonTooltipInfo",
    "bossIcons",
}

local function CopyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function SanitizeNPCNames(tbl)
    if type(tbl) ~= "table" then
        return {}
    end

    local cleaned = {}
    for key, value in pairs(tbl) do
        local npcID = tonumber(key)
        if npcID and type(value) == "string" and value ~= "" then
            cleaned[npcID] = value
        end
    end
    return cleaned
end

local function SanitizeFavoriteTable(tbl)
    if type(tbl) ~= "table" then
        return {}
    end

    for key, value in pairs(tbl) do
        if value ~= true then
            tbl[key] = nil
        end
    end
    return tbl
end

function Database:Initialize()
    if type(DXPetServicesDB) ~= "table" then
        DXPetServicesDB = {}
    end
    if type(DXPetServicesCharDB) ~= "table" then
        DXPetServicesCharDB = {}
    end

    local hadDefaultView = type(DXPetServicesDB.settings) == "table"
        and (DXPetServicesDB.settings.defaultView == "BATTLE" or DXPetServicesDB.settings.defaultView == "COLLECTOR")
    local previousViewMode = type(DXPetServicesCharDB.journal) == "table" and DXPetServicesCharDB.journal.viewMode or nil

    CopyDefaults(ACCOUNT_DEFAULTS, DXPetServicesDB)
    CopyDefaults(CHARACTER_DEFAULTS, DXPetServicesCharDB)

    -- These settings were folded into other behavior in 0.5.1. Remove the old
    -- saved keys so the account database reflects the settings that still exist.
    DXPetServicesDB.settings.minimapIcons = nil
    DXPetServicesDB.settings.petTrackerPanel = nil

    DXPetServicesDB.schemaVersion = ACCOUNT_SCHEMA
    DXPetServicesCharDB.schemaVersion = CHARACTER_SCHEMA

    DXPetServicesDB.npcNames = SanitizeNPCNames(DXPetServicesDB.npcNames)
    DXPetServicesCharDB.favorites.exact = SanitizeFavoriteTable(DXPetServicesCharDB.favorites.exact)
    DXPetServicesCharDB.favorites.species = SanitizeFavoriteTable(DXPetServicesCharDB.favorites.species)

    if not VALID_FILTER_MODES[DXPetServicesCharDB.journal.filterMode] then
        DXPetServicesCharDB.journal.filterMode = "ALL"
    end

    if not VALID_VIEW_MODES[DXPetServicesCharDB.journal.viewMode] then
        DXPetServicesCharDB.journal.viewMode = "BATTLE"
    end

    if not VALID_AUTO_SUMMON_SOURCES[DXPetServicesCharDB.autoSummon.source] then
        DXPetServicesCharDB.autoSummon.source = "FAVORITES"
    end

    if not hadDefaultView and VALID_VIEW_MODES[previousViewMode] then
        DXPetServicesDB.settings.defaultView = previousViewMode
    elseif not VALID_VIEW_MODES[DXPetServicesDB.settings.defaultView] then
        DXPetServicesDB.settings.defaultView = "BATTLE"
    end

    for _, key in ipairs(BOOLEAN_SETTINGS) do
        if type(DXPetServicesDB.settings[key]) ~= "boolean" then
            DXPetServicesDB.settings[key] = ACCOUNT_DEFAULTS.settings[key]
        end
    end

    local validPinModes = { ALL = true, CLUSTER = true, SPECIES = true }
    if not validPinModes[DXPetServicesDB.settings.petTrackerPinMode] then
        DXPetServicesDB.settings.petTrackerPinMode = "ALL"
    end
    local pinSize = tonumber(DXPetServicesDB.settings.petTrackerPinSize) or 100
    DXPetServicesDB.settings.petTrackerPinSize = math.max(60, math.min(160, math.floor(pinSize + 0.5)))
    local pinOpacity = tonumber(DXPetServicesDB.settings.petTrackerPinOpacity) or 100
    DXPetServicesDB.settings.petTrackerPinOpacity = math.max(25, math.min(100, math.floor(pinOpacity + 0.5)))

    ns.db = DXPetServicesDB
    ns.charDB = DXPetServicesCharDB
end

local addonName, ns = ...

local Database = {}
ns.Database = Database

local ACCOUNT_SCHEMA = 14
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
        petTrackerNearbyAlertSound = true,
        petTrackerNearbyFadeInTime = 0.2,
        petTrackerNearbyFadeOutTime = 1.5,
        petTrackerNearbyDetectionRadius = 2.5,
        petTrackerNearbyStartupDelay = 8,
        petTrackerNearbyAlertPoint = "CENTER",
        petTrackerNearbyAlertRelativePoint = "CENTER",
        petTrackerNearbyAlertX = 0,
        petTrackerNearbyAlertY = 170,
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
local VALID_ANCHOR_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local BOOLEAN_SETTINGS = {
    "npcPetDisplays",
    "worldMapIcons",
    "petTrackerMapIcons",
    "petTrackerHideCapturedPins",
    "petTrackerOnlyWhenPanelOpen",
    "petTrackerNearbyAlerts",
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
    local fadeInTime = tonumber(DXPetServicesDB.settings.petTrackerNearbyFadeInTime) or 0.2
    DXPetServicesDB.settings.petTrackerNearbyFadeInTime = math.max(0, math.min(2, math.floor((fadeInTime / 0.1) + 0.5) * 0.1))
    local fadeOutTime = tonumber(DXPetServicesDB.settings.petTrackerNearbyFadeOutTime) or 1.5
    DXPetServicesDB.settings.petTrackerNearbyFadeOutTime = math.max(0.2, math.min(5, math.floor((fadeOutTime / 0.1) + 0.5) * 0.1))
    local detectionRadius = tonumber(DXPetServicesDB.settings.petTrackerNearbyDetectionRadius) or 2.5
    DXPetServicesDB.settings.petTrackerNearbyDetectionRadius = math.max(0.5, math.min(8, math.floor((detectionRadius / 0.5) + 0.5) * 0.5))
    local startupDelay = tonumber(DXPetServicesDB.settings.petTrackerNearbyStartupDelay) or 8
    DXPetServicesDB.settings.petTrackerNearbyStartupDelay = math.max(0, math.min(30, math.floor(startupDelay + 0.5)))
    if not VALID_ANCHOR_POINTS[DXPetServicesDB.settings.petTrackerNearbyAlertPoint] then
        DXPetServicesDB.settings.petTrackerNearbyAlertPoint = "CENTER"
    end
    if not VALID_ANCHOR_POINTS[DXPetServicesDB.settings.petTrackerNearbyAlertRelativePoint] then
        DXPetServicesDB.settings.petTrackerNearbyAlertRelativePoint = "CENTER"
    end
    DXPetServicesDB.settings.petTrackerNearbyAlertX = tonumber(DXPetServicesDB.settings.petTrackerNearbyAlertX) or 0
    DXPetServicesDB.settings.petTrackerNearbyAlertY = tonumber(DXPetServicesDB.settings.petTrackerNearbyAlertY) or 170

    ns.db = DXPetServicesDB
    ns.charDB = DXPetServicesCharDB
end

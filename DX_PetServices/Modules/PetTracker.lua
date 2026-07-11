local addonName, ns = ...

local PetTracker = {
    collectionDirty = true,
    collection = {},
    speciesInfo = {},
    panelOpen = false,
    refreshToken = 0,
    mapAncestry = {},
    mapExpansion = {},
    expansionSpecies = nil,
    expansionRows = {},
    zonePetRows = {},
    objectiveLines = {},
    objectiveCollapsed = false,
    mapCanvasHooked = false,
    mapCanvasFrames = {},
}
ns:RegisterModule("PetTracker", PetTracker)

local TRACKER_DISPLAY_MODE = "DXPetServices.PetTracker"
local EXPANSION_ROW_HEIGHT = 39
local ZONE_PET_ROW_HEIGHT = 20
local ZONE_PET_MAX_VISIBLE_ROWS = 4
local OBJECTIVE_LINE_HEIGHT = 20
local OBJECTIVE_LINE_STEP = 21

-- Map panel layout. Keep these values together when adjusting the tracker UI.
local PANEL_LAYOUT = {
    backdropTop = 0,
    backdropBottom = 0,
    contentLeft = 16,
    contentTop = -16,
    contentRight = -18,
    contentBottom = 8,
    titleY = 25,
}

local TAB_ICON_COLOR = { 1.0, 0.82, 0.0, 1.0 }

local QUALITY_NAMES = {
    [1] = _G.BATTLE_PET_BREED_QUALITY1 or _G.ITEM_QUALITY0_DESC or "Poor",
    [2] = _G.BATTLE_PET_BREED_QUALITY2 or _G.ITEM_QUALITY1_DESC or "Common",
    [3] = _G.BATTLE_PET_BREED_QUALITY3 or _G.ITEM_QUALITY2_DESC or "Uncommon",
    [4] = _G.BATTLE_PET_BREED_QUALITY4 or _G.ITEM_QUALITY3_DESC or "Rare",
    [5] = _G.BATTLE_PET_BREED_QUALITY5 or _G.ITEM_QUALITY4_DESC or "Epic",
    [6] = _G.BATTLE_PET_BREED_QUALITY6 or _G.ITEM_QUALITY5_DESC or "Legendary",
}

-- Wild-pet collection grouping. Species are assigned to the earliest expansion
-- area in which the ATT tracker database places them. This keeps one species
-- from being counted multiple times when it appears in several later zones.
local EXPANSIONS = {
    {
        key = "CLASSIC",
        name = "Classic",
        order = 1,
        rootIDs = { [12] = true, [13] = true },
        rootNames = { ["kalimdor"] = true, ["eastern kingdoms"] = true },
    },
    {
        key = "TBC",
        name = "The Burning Crusade",
        order = 2,
        rootIDs = { [101] = true },
        rootNames = { ["outland"] = true },
    },
    {
        key = "WRATH",
        name = "Wrath of the Lich King",
        order = 3,
        rootIDs = { [113] = true },
        rootNames = { ["northrend"] = true },
    },
    {
        key = "CATACLYSM",
        name = "Cataclysm",
        order = 4,
        rootIDs = { [948] = true },
        specificNames = {
            ["the maelstrom"] = true,
            ["deepholm"] = true,
            ["vashj'ir"] = true,
            ["kelp'thar forest"] = true,
            ["shimmering expanse"] = true,
            ["abyssal depths"] = true,
            ["mount hyjal"] = true,
            ["uldum"] = true,
            ["twilight highlands"] = true,
            ["tol barad"] = true,
        },
    },
    {
        key = "MISTS",
        name = "Mists of Pandaria",
        order = 5,
        rootIDs = { [424] = true },
        rootNames = { ["pandaria"] = true },
        specificNames = { ["isle of thunder"] = true, ["timeless isle"] = true },
    },
    {
        key = "WOD",
        name = "Warlords of Draenor",
        order = 6,
        rootIDs = { [572] = true },
        rootNames = { ["draenor"] = true },
    },
    {
        key = "LEGION",
        name = "Legion",
        order = 7,
        rootIDs = { [619] = true, [905] = true },
        rootNames = { ["broken isles"] = true, ["argus"] = true },
    },
    {
        key = "BFA",
        name = "Battle for Azeroth",
        order = 8,
        rootIDs = { [875] = true, [876] = true },
        rootNames = { ["kul tiras"] = true, ["zandalar"] = true },
        specificNames = { ["nazjatar"] = true, ["mechagon"] = true, ["mechagon island"] = true },
    },
    {
        key = "SHADOWLANDS",
        name = "Shadowlands",
        order = 9,
        rootIDs = { [1550] = true },
        rootNames = { ["shadowlands"] = true },
        specificNames = {
            ["bastion"] = true,
            ["maldraxxus"] = true,
            ["ardenweald"] = true,
            ["revendreth"] = true,
            ["the maw"] = true,
            ["zereth mortis"] = true,
        },
    },
    {
        key = "DRAGONFLIGHT",
        name = "Dragonflight",
        order = 10,
        rootIDs = { [1978] = true },
        rootNames = { ["dragon isles"] = true },
        specificNames = {
            ["the forbidden reach"] = true,
            ["forbidden reach"] = true,
            ["zaralek cavern"] = true,
            ["emerald dream"] = true,
        },
    },
    {
        key = "TWW",
        name = "The War Within",
        order = 11,
        rootIDs = { [2274] = true },
        rootNames = { ["khaz algar"] = true },
        specificNames = {
            ["isle of dorn"] = true,
            ["the ringing deeps"] = true,
            ["hallowfall"] = true,
            ["azj-kahet"] = true,
            ["siren isle"] = true,
            ["undermine"] = true,
            ["k'aresh"] = true,
        },
    },
    {
        key = "MIDNIGHT",
        name = "Midnight",
        order = 12,
        specificNames = {
            ["quel'thalas"] = true,
            ["zul'aman"] = true,
            ["eversong woods"] = true,
            ["silvermoon city"] = true,
            ["harandar"] = true,
            ["voidstorm"] = true,
        },
    },
}

local OTHER_EXPANSION = { key = "OTHER", name = "Other", order = 99 }

-- Utility helpers

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end
    return value
end

local function SafeNumber(value)
    return type(value) == "number" and value or nil
end

local function Lower(value)
    return type(value) == "string" and string.lower(value) or nil
end

local function GetQualityColor(quality)
    quality = tonumber(quality)
    local itemQuality = quality and math.max(0, quality - 1) or 0
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemQuality]
    if color then
        return color.r or 0.7, color.g or 0.7, color.b or 0.7, color.hex
    end
    return 0.55, 0.55, 0.55, "|cff8c8c8c"
end

-- Poor and Common share the same grey slice in collection bars.
local function GetTrackerColor(quality, ownedCount)
    if not ownedCount or ownedCount <= 0 then
        return 0.10, 0.10, 0.11
    end
    quality = tonumber(quality) or 2
    if quality <= 2 then
        return 0.50, 0.50, 0.50
    elseif quality == 3 then
        return 0.12, 0.75, 0.20
    elseif quality == 4 then
        return 0.15, 0.48, 0.95
    elseif quality == 5 then
        return 0.64, 0.25, 0.90
    end
    return 0.95, 0.50, 0.10
end


local function CopyTextureAppearance(source, destination)
    if not source or not destination then
        return false
    end

    local applied = false
    local atlas = source:GetAtlas()
    if atlas and atlas ~= "" then
        applied = pcall(destination.SetAtlas, destination, atlas, false)
    end

    if not applied then
        local texture = source:GetTexture()
        if texture then
            destination:SetTexture(texture)
            applied = true
        end
    end

    if applied then
        local left, right, top, bottom = source:GetTexCoord()
        if left and right and top and bottom then
            destination:SetTexCoord(left, right, top, bottom)
        end
        local r, g, b, a = source:GetVertexColor()
        destination:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end

    return applied
end

local function GetLargeTextureRegions(frame)
    if not frame then
        return {}
    end

    local matches = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region:GetObjectType() == "Texture" then
            local width = region:GetWidth() or 0
            local height = region:GetHeight() or 0
            local atlas = region:GetAtlas()
            local texture = region:GetTexture()
            local drawLayer = region:GetDrawLayer()
            if (atlas or texture) and width >= 100 and height >= 100 and (drawLayer == "BACKGROUND" or drawLayer == "BORDER" or drawLayer == "ARTWORK") then
                matches[#matches + 1] = region
            end
        end
    end
    table.sort(matches, function(a, b)
        local aArea = (a:GetWidth() or 0) * (a:GetHeight() or 0)
        local bArea = (b:GetWidth() or 0) * (b:GetHeight() or 0)
        return aArea > bArea
    end)
    return matches
end

local function FindPanelBackgroundTexture(frame, visited)
    if not frame then
        return nil
    end
    visited = visited or {}
    if visited[frame] then
        return nil
    end
    visited[frame] = true

    local directCandidates = {
        frame.Background,
        frame.background,
        frame.bg,
        frame.BG,
        frame.ScrollFrame and frame.ScrollFrame.Background,
        frame.ScrollContainer and frame.ScrollContainer.Background,
        frame.ContentFrame and frame.ContentFrame.Background,
        frame.NineSlice and frame.NineSlice.Center,
    }
    for _, candidate in ipairs(directCandidates) do
        if candidate and type(candidate.GetObjectType) == "function" and candidate:GetObjectType() == "Texture" then
            return candidate
        end
    end

    local regionMatches = GetLargeTextureRegions(frame)
    if regionMatches[1] then
        return regionMatches[1]
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        local found = FindPanelBackgroundTexture(child, visited)
        if found then
            return found
        end
    end

    return nil
end


local function ShouldKeepNativeLegendTexture(region, legendFrame)
    if not region or not legendFrame then
        return false
    end

    local width = region:GetWidth() or 0
    local height = region:GetHeight() or 0
    local legendWidth = legendFrame:GetWidth() or 0
    local legendHeight = legendFrame:GetHeight() or 0
    local legendLeft = legendFrame:GetLeft()
    local legendRight = legendFrame:GetRight()
    local legendTop = legendFrame:GetTop()
    local legendBottom = legendFrame:GetBottom()
    local left = region:GetLeft()
    local right = region:GetRight()
    local top = region:GetTop()
    local bottom = region:GetBottom()

    -- Keep any large texture regions, because these are the primary panel
    -- background, shading, vignette, and ornamental pieces.
    if width >= 72 or height >= 72 then
        return true
    end
    if legendWidth > 0 and width >= legendWidth * 0.22 then
        return true
    end
    if legendHeight > 0 and height >= legendHeight * 0.22 then
        return true
    end

    -- Small textures are kept only when they are genuine corner ornaments.
    if legendLeft and legendRight and legendTop and legendBottom and left and right and top and bottom then
        local inset = 14
        local touchesLeft = math.abs(left - legendLeft) <= inset
        local touchesRight = math.abs(right - legendRight) <= inset
        local touchesTop = math.abs(top - legendTop) <= inset
        local touchesBottom = math.abs(bottom - legendBottom) <= inset
        local isCorner = (touchesLeft or touchesRight) and (touchesTop or touchesBottom)
        if isCorner and width >= 8 and height >= 8 then
            return true
        end

        -- Keep the small centered ornament on the top edge of the native panel.
        local regionCenter = (left + right) * 0.5
        local legendCenter = (legendLeft + legendRight) * 0.5
        local nearTop = math.abs(top - legendTop) <= 18
        local centered = math.abs(regionCenter - legendCenter) <= 64
        if nearTop and centered and width >= 16 and width <= 180 and height >= 4 and height <= 48 then
            return true
        end
    end

    return false
end


local function CollectNativeLegendBackdropRegions(frame, legendFrame, visitedFrames, output)
    if not frame then
        return
    end
    visitedFrames = visitedFrames or {}
    output = output or {}
    if visitedFrames[frame] then
        return output
    end
    visitedFrames[frame] = true

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region:GetObjectType() == "Texture" and ShouldKeepNativeLegendTexture(region, legendFrame) then
            output[#output + 1] = region
        end
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        CollectNativeLegendBackdropRegions(child, legendFrame, visitedFrames, output)
    end

    return output
end

local function GetTrackerBucket(quality, ownedCount)
    if not ownedCount or ownedCount <= 0 then
        return 1
    end
    quality = tonumber(quality) or 2
    if quality <= 2 then
        return 2
    elseif quality == 3 then
        return 3
    elseif quality == 4 then
        return 4
    elseif quality == 5 then
        return 5
    end
    return 6
end

local function DisablePixelSnapping(region)
    if not region then
        return
    end
    region:SetTexelSnappingBias(0)
    region:SetSnapToPixelGrid(false)
end

local function ApplyCircularMask(texture, owner)
    if not texture or not owner or owner.DXPetMask then
        return
    end
    local mask = owner:CreateMaskTexture(nil, "ARTWORK")
    mask:SetAllPoints(texture)
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    texture:AddMaskTexture(mask)
    owner.DXPetMask = mask
end

-- Map data

local MAP_NAME_ROW_FALLBACKS = {
    -- Eversong can report an alternate UiMapID while the map canvas changes.
    ["eversong woods"] = 2395,
}

local function GetMapRowsWithSource(mapID)
    local db = ns.ATTPetTrackerDB
    local maps = db and db.maps
    if type(maps) ~= "table" or not mapID then
        return nil, nil
    end

    local rows = maps[mapID]
    if type(rows) == "table" then
        return rows, mapID
    end

    local info = C_Map.GetMapInfo(mapID)
    local mapName = type(info) == "table" and Lower(info.name) or nil
    local fallbackMapID = mapName and MAP_NAME_ROW_FALLBACKS[mapName] or nil
    local fallbackRows = fallbackMapID and maps[fallbackMapID] or nil
    if type(fallbackRows) == "table" then
        return fallbackRows, fallbackMapID
    end

    return nil, nil
end

local function GetMapRows(mapID)
    local rows = GetMapRowsWithSource(mapID)
    return rows
end

-- Packed runtime maps decode to flat integer coordinate pairs. The string path is
-- retained for developer-source compatibility when testing an unpacked database.
local function AppendDenseCoordinates(denseRow, encoded)
    local pointCount = 0

    if type(encoded) == "table" then
        for index = 1, #encoded - 1, 2 do
            local xValue = SafeNumber(encoded[index])
            local yValue = SafeNumber(encoded[index + 1])
            if xValue and yValue then
                local x = xValue / 1000
                local y = yValue / 1000
                if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    denseRow[#denseRow + 1] = { x, y }
                    pointCount = pointCount + 1
                end
            end
        end
    elseif type(encoded) == "string" and encoded ~= "" then
        for xCode, yCode in string.gmatch(encoded, "(%w%w)(%w%w)") do
            local xValue = tonumber(xCode, 36)
            local yValue = tonumber(yCode, 36)
            if xValue and yValue then
                local x = xValue / 1000
                local y = yValue / 1000
                if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    denseRow[#denseRow + 1] = { x, y }
                    pointCount = pointCount + 1
                end
            end
        end
    end

    return pointCount
end

local function DecodeDenseLocationRows(mapSpecies, rosterRows)
    if type(mapSpecies) ~= "table" or type(rosterRows) ~= "table" then
        return nil, 0, 0
    end

    local mergedRows = {}
    local densePointCount = 0
    local denseSpeciesCount = 0

    for _, row in ipairs(rosterRows) do
        local speciesID = SafeNumber(row[1])
        local encoded = speciesID and mapSpecies[speciesID] or nil
        local denseRow
        local pointCount = 0

        if speciesID and encoded ~= nil then
            denseRow = { speciesID }
            pointCount = AppendDenseCoordinates(denseRow, encoded)
        end

        if denseRow and pointCount > 0 then
            mergedRows[#mergedRows + 1] = denseRow
            densePointCount = densePointCount + pointCount
            denseSpeciesCount = denseSpeciesCount + 1
        else
            mergedRows[#mergedRows + 1] = row
        end
    end

    if denseSpeciesCount <= 0 then
        return nil, 0, 0
    end
    return mergedRows, densePointCount, denseSpeciesCount
end

-- Dense spawn locations are bundled with DX Pet Services and decoded one map at a time.
local function GetBundledDenseLocationRows(mapID, rosterRows)
    local db = ns.DXDenseLocationDB
    local mapSpecies

    if type(db) == "table" then
        if type(db.GetMap) == "function" then
            mapSpecies = db:GetMap(mapID)
        elseif type(db.maps) == "table" then
            mapSpecies = db.maps[mapID]
        end
    end

    return DecodeDenseLocationRows(mapSpecies, rosterRows)
end

local function CreateMapVector(x, y)
    return CreateVector2D(x, y)
end

local function ReadVectorXY(vector)
    if not vector then
        return nil, nil
    end
    if type(vector.GetXY) == "function" then
        local ok, x, y = pcall(vector.GetXY, vector)
        if ok then
            return SafeNumber(x), SafeNumber(y)
        end
    end
    return SafeNumber(vector.x), SafeNumber(vector.y)
end

local function ConvertMapPoint(sourceMapID, targetMapID, x, y)
    x, y = SafeNumber(x), SafeNumber(y)
    if not sourceMapID or not targetMapID or sourceMapID == targetMapID or not x or not y then
        return x, y
    end
    local sourceVector = CreateMapVector(x, y)
    if not sourceVector then
        return x, y
    end

    local first, second = C_Map.GetWorldPosFromMapPos(sourceMapID, sourceVector)

    local continentID, worldPosition
    if type(first) == "number" then
        continentID, worldPosition = SafeNumber(first), second
    else
        worldPosition, continentID = first, SafeNumber(second)
    end
    if not continentID or not worldPosition then
        return x, y
    end

    local _, mapPosition = C_Map.GetMapPosFromWorldPos(continentID, worldPosition, targetMapID)
    if not mapPosition then
        return x, y
    end

    local convertedX, convertedY = ReadVectorXY(mapPosition)
    if convertedX and convertedY and convertedX >= 0 and convertedX <= 1 and convertedY >= 0 and convertedY <= 1 then
        return convertedX, convertedY
    end
    return x, y
end

local function GetMapID()
    if WorldMapFrame then
        local mapID = SafeNumber(WorldMapFrame:GetMapID())
        if mapID then
            return mapID
        end
    end
    return SafeNumber(C_Map.GetBestMapForUnit("player"))
end

local function GetPlayerMapID()
    return SafeNumber(C_Map.GetBestMapForUnit("player"))
end

local function GetMapName(mapID)
    if mapID then
        local info = C_Map.GetMapInfo(mapID)
        if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    return _G.UNKNOWN or "Unknown Zone"
end

local function GetQuestLogFrame()
    if QuestMapFrame then
        return QuestMapFrame
    end
    if WorldMapFrame and WorldMapFrame.QuestLog then
        return WorldMapFrame.QuestLog
    end
    return nil
end

local function GetOwnedPetIDs()
    return C_PetJournal.GetOwnedPetIDs() or {}
end

local function GetSpeciesInfo(speciesID)
    local cached = PetTracker.speciesInfo[speciesID]
    if cached then
        return cached
    end

    local info = {
        speciesID = speciesID,
        name = string.format("Pet %d", speciesID),
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
    }
    local name, icon, petType, companionID, sourceText, description, isWild, canBattle, tradable, unique, obtainable = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
    if type(name) == "string" and name ~= "" then
        info.name = name
    end
    if icon then
        info.icon = icon
    end
    info.petType = petType
    info.companionID = companionID
    info.sourceText = sourceText
    info.description = description
    info.isWild = isWild
    info.canBattle = canBattle
    info.obtainable = obtainable
    PetTracker.speciesInfo[speciesID] = info
    return info
end

-- Collection state

function PetTracker:RebuildCollectionCache()
    self.collection = {}
    for _, petID in ipairs(GetOwnedPetIDs()) do
        local speciesID, _, level = C_PetJournal.GetPetInfoByPetID(petID)
        speciesID = tonumber(speciesID)
        if speciesID then
            local entry = self.collection[speciesID]
            if not entry then
                entry = { count = 0, bestQuality = nil, bestLevel = nil }
                self.collection[speciesID] = entry
            end
            entry.count = entry.count + 1
            level = tonumber(level)
            if level and (not entry.bestLevel or level > entry.bestLevel) then
                entry.bestLevel = level
            end

            local _, _, _, _, rarity = C_PetJournal.GetPetStats(petID)
            rarity = tonumber(rarity)
            if rarity and (not entry.bestQuality or rarity > entry.bestQuality) then
                entry.bestQuality = rarity
            end
        end
    end
    self.collectionDirty = false
end

function PetTracker:GetCollectionInfo(speciesID)
    if self.collectionDirty then
        self:RebuildCollectionCache()
    end
    return self.collection[speciesID] or { count = 0, bestQuality = nil, bestLevel = nil }
end

function PetTracker:GetMapAncestry(mapID)
    mapID = tonumber(mapID)
    if not mapID then
        return nil
    end
    if self.mapAncestry[mapID] then
        return self.mapAncestry[mapID]
    end

    local result = { ids = {}, names = {} }
    local current = mapID
    local seen = {}
    for _ = 1, 12 do
        if not current or current <= 0 or seen[current] then
            break
        end
        seen[current] = true
        result.ids[current] = true

        if not C_Map or type(C_Map.GetMapInfo) ~= "function" then
            break
        end
        local info = C_Map.GetMapInfo(current)
        if type(info) ~= "table" then
            break
        end
        local lowered = Lower(info.name)
        if lowered then
            result.names[lowered] = true
        end
        current = tonumber(info.parentMapID)
    end

    self.mapAncestry[mapID] = result
    return result
end

function PetTracker:ResolveExpansionForMap(mapID)
    mapID = tonumber(mapID)
    if not mapID then
        return OTHER_EXPANSION
    end
    if self.mapExpansion[mapID] then
        return self.mapExpansion[mapID]
    end

    local ancestry = self:GetMapAncestry(mapID)
    if not ancestry then
        self.mapExpansion[mapID] = OTHER_EXPANSION
        return OTHER_EXPANSION
    end

    -- Check expansion-specific zone names before continent roots. This keeps
    -- Cataclysm zones under Kalimdor/Eastern Kingdoms and Midnight's
    -- Quel'Thalas under Eastern Kingdoms from being classified as Classic.
    for index = #EXPANSIONS, 1, -1 do
        local expansion = EXPANSIONS[index]
        if expansion.specificNames then
            for name in pairs(expansion.specificNames) do
                if ancestry.names[name] then
                    self.mapExpansion[mapID] = expansion
                    return expansion
                end
            end
        end
    end

    for index = #EXPANSIONS, 1, -1 do
        local expansion = EXPANSIONS[index]
        if expansion.rootIDs then
            for rootID in pairs(expansion.rootIDs) do
                if ancestry.ids[rootID] then
                    self.mapExpansion[mapID] = expansion
                    return expansion
                end
            end
        end
        if expansion.rootNames then
            for name in pairs(expansion.rootNames) do
                if ancestry.names[name] then
                    self.mapExpansion[mapID] = expansion
                    return expansion
                end
            end
        end
    end

    self.mapExpansion[mapID] = OTHER_EXPANSION
    return OTHER_EXPANSION
end

function PetTracker:BuildExpansionSpeciesIndex()
    if self.expansionSpecies then
        return self.expansionSpecies
    end

    local assignments = {}
    local trackerDB = ns.ATTPetTrackerDB
    for mapID, rows in pairs((trackerDB and trackerDB.maps) or {}) do
        local expansion = self:ResolveExpansionForMap(mapID)
        for _, row in ipairs(rows) do
            local speciesID = tonumber(row[1])
            if speciesID then
                local current = assignments[speciesID]
                if not current or expansion.order < current.order then
                    assignments[speciesID] = expansion
                end
            end
        end
    end

    local grouped = {}
    for _, expansion in ipairs(EXPANSIONS) do
        grouped[expansion.key] = { definition = expansion, species = {} }
    end
    grouped[OTHER_EXPANSION.key] = { definition = OTHER_EXPANSION, species = {} }

    for speciesID, expansion in pairs(assignments) do
        local group = grouped[expansion.key] or grouped[OTHER_EXPANSION.key]
        group.species[#group.species + 1] = speciesID
    end
    for _, group in pairs(grouped) do
        table.sort(group.species)
    end

    self.expansionSpecies = grouped
    return grouped
end

function PetTracker:BuildZoneDisplay(mapID)
    local rows = GetMapRows(mapID)
    if not rows then
        return {}, 0, 0
    end

    local display = {}
    local collected = 0
    for _, sourceRow in ipairs(rows) do
        local speciesID = sourceRow[1]
        local species = GetSpeciesInfo(speciesID)
        local owned = self:GetCollectionInfo(speciesID)
        if owned.count > 0 then
            collected = collected + 1
        end
        display[#display + 1] = {
            speciesID = speciesID,
            name = species.name,
            icon = species.icon,
            count = owned.count,
            bestQuality = owned.bestQuality,
            bestLevel = owned.bestLevel,
            sourceText = species.sourceText,
            rosterOnly = type(sourceRow[2]) ~= "table",
        }
    end

    table.sort(display, function(a, b)
        local bucketA = GetTrackerBucket(a.bestQuality, a.count)
        local bucketB = GetTrackerBucket(b.bestQuality, b.count)
        -- Put collected pets on the left and missing pets on the right so the
        -- bar's visible progress grows naturally from left to right.
        local rankA = bucketA == 1 and 99 or bucketA
        local rankB = bucketB == 1 and 99 or bucketB
        if rankA ~= rankB then
            return rankA < rankB
        end
        return (a.name or "") < (b.name or "")
    end)

    return display, collected, #display
end

-- World map pins

local function SetWaypoint(data)
    local waypointX = data and (data.waypointX or data.x) or nil
    local waypointY = data and (data.waypointY or data.y) or nil
    if not data or data.rosterOnly or not data.mapID or not waypointX or not waypointY then
        return false
    end

    local point = UiMapPoint.CreateFromCoordinates(data.mapID, waypointX, waypointY)
    if not point then
        point = { uiMapID = data.mapID, position = CreateVector2D(waypointX, waypointY) }
    end
    if not point then
        return false
    end

    C_Map.SetUserWaypoint(point)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    return true
end

function PetTracker:ShowSpeciesTooltip(owner, data)
    if not owner or not data or not GameTooltip then
        return
    end
    local species = GetSpeciesInfo(data.speciesID)
    local owned = self:GetCollectionInfo(data.speciesID)
    local r, g, b = GetQualityColor(owned.bestQuality)

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(species.name, 1, 1, 1)
    if owned.count > 0 then
        GameTooltip:AddDoubleLine("Collected", tostring(owned.count), 0.75, 0.75, 0.75, 1, 1, 1)
        GameTooltip:AddDoubleLine("Best Quality", QUALITY_NAMES[owned.bestQuality] or _G.UNKNOWN or "Unknown", 0.75, 0.75, 0.75, r, g, b)
        if owned.bestLevel then
            GameTooltip:AddDoubleLine("Best Level", tostring(owned.bestLevel), 0.75, 0.75, 0.75, 1, 1, 1)
        end
    else
        GameTooltip:AddLine("Not collected", 1, 0.35, 0.25)
    end

    if data.rosterOnly ~= nil then
        GameTooltip:AddLine(" ")
        if data.rosterOnly then
            GameTooltip:AddLine("Catchable in this zone", 0.35, 0.75, 1)
            GameTooltip:AddLine("Zone roster marker: no precise spawn point is available for this pet.", 0.75, 0.75, 0.75, true)
        else
            GameTooltip:AddLine("ATT-confirmed wild pet location", 0.35, 0.75, 1)
            if data.mapID and data.x and data.y then
                GameTooltip:AddLine("Click to set waypoint", 0.35, 0.75, 1)
            end
        end
    end
    GameTooltip:Show()
end

local PETTRACKER_PIN_FRAME_LEVEL = "PIN_FRAME_LEVEL_DIG_SITE"

local function ConfigurePetTrackerPinFrameLevel(frame, pin, index)
    if not frame or not pin then
        return
    end
    local manager = type(frame.GetPinFrameLevelsManager) == "function" and frame:GetPinFrameLevelsManager() or nil
    if manager and type(manager.GetValidFrameLevel) == "function" then
        local ok, level = pcall(manager.GetValidFrameLevel, manager, PETTRACKER_PIN_FRAME_LEVEL)
        if ok and tonumber(level) then
            pin:SetFrameLevel(tonumber(level) + (tonumber(index) or 0))
            return
        end
    end
    pin:SetFrameLevel(200 + (tonumber(index) or 0))
end

function PetTracker:IsPetTrackerMapCanvas(frame)
    if not frame then
        return false
    end

    -- Draw only on map canvases carrying Blizzard's pet-tamer
    -- data provider. This avoids leaking wild-pet markers onto unrelated
    -- MapCanvasMixin frames such as embedded maps.
    if PetTamerDataProviderMixin and type(PetTamerDataProviderMixin.RefreshAllData) == "function" and type(frame.dataProviders) == "table" then
        for provider in pairs(frame.dataProviders) do
            if type(provider) == "table" and provider.RefreshAllData == PetTamerDataProviderMixin.RefreshAllData then
                return true
            end
        end
        return false
    end

    return frame == WorldMapFrame
end

function PetTracker:CreatePetTrackerMapPin(frame, index)
    if not frame or type(frame.GetCanvas) ~= "function" then
        return nil
    end
    local canvas = frame:GetCanvas()
    if not canvas then
        return nil
    end

    local pin = CreateFrame("Button", nil, canvas)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetSize(16, 16)
    pin:EnableMouse(true)
    ConfigurePetTrackerPinFrameLevel(frame, pin, index)

    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(14, 14)
    DisablePixelSnapping(icon)
    local maskApplied = false
    if type(icon.SetMask) == "function" then
        maskApplied = pcall(icon.SetMask, icon, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    end
    if not maskApplied then
        ApplyCircularMask(icon, pin)
    end
    pin.Icon = icon

    local border = pin:CreateTexture(nil, "OVERLAY")
    border:SetPoint("CENTER")
    border:SetSize(22, 22)
    DisablePixelSnapping(border)
    local atlasApplied = pcall(border.SetAtlas, border, "Neutraltrait-border-selected", false)
    if not atlasApplied then
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
    end
    pin.Border = border

    pin:SetScript("OnEnter", function(button)
        if button.data then
            PetTracker:ShowSpeciesTooltip(button, button.data)
        end
    end)
    pin:SetScript("OnLeave", function(button)
        if GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)
    pin:SetScript("OnClick", function(button, mouseButton)
        if mouseButton == "LeftButton" and button.data then
            SetWaypoint(button.data)
        end
    end)
    pin:Hide()
    return pin
end

function PetTracker:InitPetTrackerMapCanvas(frame)
    if not frame or self.mapCanvasFrames[frame] then
        return frame and self.mapCanvasFrames[frame] or nil
    end

    local state = {
        pins = {},
        activeCount = 0,
    }
    self.mapCanvasFrames[frame] = state

    if frame.OnCanvasScaleChanged then
        hooksecurefunc(frame, "OnCanvasScaleChanged", function(changedFrame)
            self:ScalePetTrackerMapPins(changedFrame)
        end)
    end
    frame:HookScript("OnShow", function(shownFrame)
        self:RedrawPetTrackerMapCanvas(shownFrame)
    end)
    frame:HookScript("OnHide", function(hiddenFrame)
        self:ClearPetTrackerMapCanvas(hiddenFrame)
    end)

    return state
end

function PetTracker:GetPetTrackerMapPin(frame, index)
    local state = self:InitPetTrackerMapCanvas(frame)
    if not state then
        return nil
    end

    local pin = state.pins[index]
    if not pin then
        pin = self:CreatePetTrackerMapPin(frame, index)
        if not pin then
            return nil
        end
        state.pins[index] = pin
    end

    local canvas = frame:GetCanvas()
    if canvas and pin:GetParent() ~= canvas then
        pin:SetParent(canvas)
    end
    ConfigurePetTrackerPinFrameLevel(frame, pin, index)
    return pin
end

function PetTracker:ClearPetTrackerMapCanvas(frame)
    local state = frame and self.mapCanvasFrames[frame]
    if not state then
        return
    end
    for _, pin in ipairs(state.pins) do
        pin.data = nil
        pin:Hide()
    end
    state.activeCount = 0
end

function PetTracker:ScalePetTrackerMapPins(frame)
    local state = frame and self.mapCanvasFrames[frame]
    if not state or not frame or type(frame.GetCanvasScale) ~= "function" or type(frame.GetGlobalPinScale) ~= "function" then
        return
    end

    local canvasScale = tonumber(frame:GetCanvasScale()) or 0
    local globalPinScale = tonumber(frame:GetGlobalPinScale()) or 0
    if canvasScale <= 0 or globalPinScale <= 0 then
        return
    end
    local scale = globalPinScale / canvasScale

    for index = 1, state.activeCount do
        local pin = state.pins[index]
        if pin and pin.data and pin.canvasX and pin.canvasY then
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", pin:GetParent(), "TOPLEFT", pin.canvasX / scale, pin.canvasY / scale)
            pin:SetScale(scale)
        end
    end
end

function PetTracker:IsMapPanelOpen()
    return self.panel ~= nil
        and self.panel:IsShown()
        and self.questLogFrame ~= nil
        and self.questLogFrame.displayMode == TRACKER_DISPLAY_MODE
end

function PetTracker:DrawPetTrackerMapCanvas(frame)
    local state = self:InitPetTrackerMapCanvas(frame)
    if not state then
        return
    end

    local settings = ns.db and ns.db.settings
    if not settings
        or settings.petTrackerMapIcons == false
        or (settings.petTrackerOnlyWhenPanelOpen == true and not self:IsMapPanelOpen())
        or not self:IsPetTrackerMapCanvas(frame)
    then
        self:ClearPetTrackerMapCanvas(frame)
        return
    end

    local mapID = SafeNumber(frame:GetMapID())
    local rows, sourceMapID = GetMapRowsWithSource(mapID)
    sourceMapID = sourceMapID or mapID

    -- Draw one pin for every stored spawn coordinate from the bundled dense
    -- DX dense-location database. ATT's sparse coordinates remain a final fallback only
    -- for maps not present in the bundled location database.
    local drawRows, densePointCount = GetBundledDenseLocationRows(sourceMapID, rows)
    local locationSource = drawRows and "dx-dense" or "att"
    drawRows = drawRows or rows

    local canvas = frame:GetCanvas()
    local canvasWidth = canvas and tonumber(canvas:GetWidth()) or 0
    local canvasHeight = canvas and tonumber(canvas:GetHeight()) or 0

    if not rows or not mapID or not canvas or canvasWidth <= 0 or canvasHeight <= 0 then
        self:ClearPetTrackerMapCanvas(frame)
        self.lastMapPinStats = {
            mapID = mapID,
            sourceMapID = sourceMapID,
            species = 0,
            coordinates = 0,
            acquired = 0,
            renderer = "dx-pet-canvas",
            locationSource = locationSource,
            denseCoordinates = densePointCount or 0,
        }
        return
    end

    local activeCount = 0
    local speciesCount = 0
    local coordinateCount = 0
    local hideCaptured = settings.petTrackerHideCapturedPins ~= false

    -- Only actual location points become map icons. Species
    -- with no precise coordinates remain in the zone tracker list instead of
    -- receiving invented map positions.
    for _, row in ipairs(drawRows) do
        local speciesID = SafeNumber(row[1])
        local isCaptured = speciesID and hideCaptured and self:GetCollectionInfo(speciesID).count > 0
        if speciesID and not isCaptured then
            speciesCount = speciesCount + 1
        end

        if speciesID and not isCaptured and type(row[2]) == "table" then
            for pointIndex = 2, #row do
                local point = row[pointIndex]
                local x = type(point) == "table" and SafeNumber(point[1]) or nil
                local y = type(point) == "table" and SafeNumber(point[2]) or nil
                if x and y then
                    coordinateCount = coordinateCount + 1
                end

                if x and y then
                    local displayX, displayY = ConvertMapPoint(sourceMapID, mapID, x, y)
                    displayX, displayY = SafeNumber(displayX), SafeNumber(displayY)
                    if displayX and displayY and displayX >= 0 and displayX <= 1 and displayY >= 0 and displayY <= 1 then
                        activeCount = activeCount + 1
                        local pin = self:GetPetTrackerMapPin(frame, activeCount)
                        if pin then
                            local species = GetSpeciesInfo(speciesID)
                            pin.data = {
                                speciesID = speciesID,
                                mapID = sourceMapID,
                                x = displayX,
                                y = displayY,
                                waypointX = x,
                                waypointY = y,
                                rosterOnly = false,
                            }
                            pin.Icon:SetTexture(species.icon)
                            pin.Icon:SetDesaturated(false)
                            pin.Icon:SetAlpha(1)
                            pin.Border:SetVertexColor(1, 1, 1, 1)
                            pin.canvasX = canvasWidth * displayX
                            pin.canvasY = -canvasHeight * displayY
                            pin:Show()
                        end
                    end
                end
            end
        end
    end

    for index = activeCount + 1, #state.pins do
        local pin = state.pins[index]
        pin.data = nil
        pin:Hide()
    end
    state.activeCount = activeCount

    self.lastMapPinStats = {
        mapID = mapID,
        sourceMapID = sourceMapID,
        species = speciesCount,
        coordinates = coordinateCount,
        acquired = activeCount,
        renderer = "dx-pet-canvas",
        locationSource = locationSource,
        denseCoordinates = densePointCount or 0,
    }
end

function PetTracker:RedrawPetTrackerMapCanvas(frame)
    if not frame then
        return
    end
    self:ClearPetTrackerMapCanvas(frame)
    self:DrawPetTrackerMapCanvas(frame)
    self:ScalePetTrackerMapPins(frame)
end

function PetTracker:InstallPetTrackerMapCanvasHook()
    if self.mapCanvasHooked then
        return true
    end
    if not MapCanvasMixin or type(hooksecurefunc) ~= "function" then
        return false
    end

    self.mapCanvasHooked = true
    hooksecurefunc(MapCanvasMixin, "OnMapChanged", function(frame)
        self:InitPetTrackerMapCanvas(frame)
        self:RedrawPetTrackerMapCanvas(frame)
    end)
    return true
end

function PetTracker:HideDirectMapPins()
    if WorldMapFrame then
        self:ClearPetTrackerMapCanvas(WorldMapFrame)
    end
end

function PetTracker:TryRegisterWorldMap()
    if not WorldMapFrame then
        return false
    end

    self:InstallPetTrackerMapCanvasHook()
    self:InitPetTrackerMapCanvas(WorldMapFrame)
    if WorldMapFrame:IsShown() then
        self:RedrawPetTrackerMapCanvas(WorldMapFrame)
    end
    return true
end

function PetTracker:RefreshWorldMap()
    self:TryRegisterWorldMap()
    for frame in pairs(self.mapCanvasFrames) do
        if frame:IsVisible() then
            self:RedrawPetTrackerMapCanvas(frame)
        end
    end
end

-- Progress bars and lists

local function CreateRoundCap(parent, layer, subLevel)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 0)
    local mask = parent:CreateMaskTexture(nil, "ARTWORK")
    mask:SetAllPoints(texture)
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    texture:AddMaskTexture(mask)
    return texture, mask
end

local function CreateRoundedBarShell(bar)
    local shell = {}

    shell.BorderCenter = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    shell.BorderLeft, shell.BorderLeftMask = CreateRoundCap(bar, "BACKGROUND", 0)
    shell.BorderRight, shell.BorderRightMask = CreateRoundCap(bar, "BACKGROUND", 0)

    shell.TrackCenter = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    shell.TrackLeft, shell.TrackLeftMask = CreateRoundCap(bar, "BACKGROUND", 1)
    shell.TrackRight, shell.TrackRightMask = CreateRoundCap(bar, "BACKGROUND", 1)

    shell.FillLeft, shell.FillLeftMask = CreateRoundCap(bar, "ARTWORK", 1)
    shell.FillRight, shell.FillRightMask = CreateRoundCap(bar, "ARTWORK", 1)

    shell.BorderCenter:SetColorTexture(0.30, 0.30, 0.34, 0.90)
    shell.BorderLeft:SetColorTexture(0.30, 0.30, 0.34, 0.90)
    shell.BorderRight:SetColorTexture(0.30, 0.30, 0.34, 0.90)

    shell.TrackCenter:SetColorTexture(0.035, 0.035, 0.045, 1)
    shell.TrackLeft:SetColorTexture(0.035, 0.035, 0.045, 1)
    shell.TrackRight:SetColorTexture(0.035, 0.035, 0.045, 1)

    bar.RoundShell = shell
end

local function LayoutRoundedBarShell(bar)
    local shell = bar and bar.RoundShell
    if not shell then
        return
    end

    local height = math.max(1, bar:GetHeight() or 18)
    local inset = 2
    local innerHeight = math.max(1, height - (inset * 2))

    shell.BorderLeft:ClearAllPoints()
    shell.BorderLeft:SetPoint("LEFT", bar, "LEFT", 0, 0)
    shell.BorderLeft:SetSize(height, height)
    shell.BorderRight:ClearAllPoints()
    shell.BorderRight:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    shell.BorderRight:SetSize(height, height)
    shell.BorderCenter:ClearAllPoints()
    shell.BorderCenter:SetPoint("TOPLEFT", bar, "TOPLEFT", height / 2, 0)
    shell.BorderCenter:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -(height / 2), 0)

    shell.TrackLeft:ClearAllPoints()
    shell.TrackLeft:SetPoint("LEFT", bar, "LEFT", inset, 0)
    shell.TrackLeft:SetSize(innerHeight, innerHeight)
    shell.TrackRight:ClearAllPoints()
    shell.TrackRight:SetPoint("RIGHT", bar, "RIGHT", -inset, 0)
    shell.TrackRight:SetSize(innerHeight, innerHeight)
    shell.TrackCenter:ClearAllPoints()
    shell.TrackCenter:SetPoint("TOPLEFT", bar, "TOPLEFT", inset + (innerHeight / 2), -inset)
    shell.TrackCenter:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -(inset + (innerHeight / 2)), inset)

    shell.FillLeft:ClearAllPoints()
    shell.FillLeft:SetPoint("LEFT", bar, "LEFT", inset, 0)
    shell.FillLeft:SetSize(innerHeight, innerHeight)
    shell.FillRight:ClearAllPoints()
    shell.FillRight:SetPoint("RIGHT", bar, "RIGHT", -inset, 0)
    shell.FillRight:SetSize(innerHeight, innerHeight)

    bar.RoundInset = inset
    bar.RoundInnerHeight = innerHeight
end

local function SetRoundedBarCapColors(bar, leftR, leftG, leftB, rightR, rightG, rightB, alpha)
    local shell = bar and bar.RoundShell
    if not shell then
        return
    end
    alpha = alpha or 0.96
    shell.FillLeft:SetColorTexture(leftR or 0.035, leftG or 0.035, leftB or 0.045, alpha)
    shell.FillRight:SetColorTexture(rightR or leftR or 0.035, rightG or leftG or 0.035, rightB or leftB or 0.045, alpha)
end

local function CreateSegmentedBar(parent, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(height or 18)
    CreateRoundedBarShell(bar)
    LayoutRoundedBarShell(bar)
    bar:HookScript("OnSizeChanged", function(frame)
        LayoutRoundedBarShell(frame)
    end)

    -- Slices are child Buttons so each species can own a tooltip. Keep the
    -- progress text on a deliberately higher frame level so those child frames
    -- can never cover it.
    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 20)
    overlay:EnableMouse(false)
    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    bar.Overlay = overlay
    bar.Text = text
    bar.Slices = {}
    return bar
end

function PetTracker:RefreshSegmentedBar(bar, display)
    if not bar then
        return
    end
    display = display or {}
    LayoutRoundedBarShell(bar)

    local count = #display
    local width = bar:GetWidth()
    if not width or width < 10 then
        width = 250
    end
    local padding = bar.RoundInset or 2
    local innerHeight = bar.RoundInnerHeight or math.max(1, (bar:GetHeight() or 18) - (padding * 2))
    local centerLeft = padding + (innerHeight / 2)
    local centerRight = width - padding - (innerHeight / 2)
    local gap = count > 1 and 1 or 0
    local usable = math.max(1, centerRight - centerLeft - (gap * math.max(0, count - 1)))
    local sliceWidth = count > 0 and usable / count or usable

    local firstR, firstG, firstB = GetTrackerColor(nil, 0)
    local lastR, lastG, lastB = firstR, firstG, firstB
    if count > 0 then
        firstR, firstG, firstB = GetTrackerColor(display[1].bestQuality, display[1].count)
        lastR, lastG, lastB = GetTrackerColor(display[count].bestQuality, display[count].count)
    end
    SetRoundedBarCapColors(bar, firstR, firstG, firstB, lastR, lastG, lastB, 0.96)

    for index, data in ipairs(display) do
        local slice = bar.Slices[index]
        if not slice then
            slice = CreateFrame("Button", nil, bar)
            slice:EnableMouse(true)
            local texture = slice:CreateTexture(nil, "ARTWORK")
            texture:SetAllPoints()
            slice.Texture = texture
            slice:SetScript("OnEnter", function(button)
                if button.data then
                    self:ShowSpeciesTooltip(button, button.data)
                end
            end)
            slice:SetScript("OnLeave", function(button)
                if GameTooltip:IsOwned(button) then
                    GameTooltip:Hide()
                end
            end)
            bar.Slices[index] = slice
        end

        local left = centerLeft + ((index - 1) * (sliceWidth + gap))
        slice:ClearAllPoints()
        slice:SetPoint("TOPLEFT", bar, "TOPLEFT", left, -padding)
        slice:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", left, padding)
        slice:SetWidth(math.max(1, sliceWidth))
        slice.data = data
        local r, g, b = GetTrackerColor(data.bestQuality, data.count)
        slice.Texture:SetColorTexture(r, g, b, 0.96)
        slice:Show()
    end
    for index = count + 1, #bar.Slices do
        bar.Slices[index]:Hide()
    end
end

function PetTracker:CreateExpansionRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(EXPANSION_ROW_HEIGHT)
    row:EnableMouse(true)
    row:SetPoint("TOPLEFT", 2, -((index - 1) * EXPANSION_ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -2, -((index - 1) * EXPANSION_ROW_HEIGHT))

    local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetPoint("TOPLEFT", 2, -1)
    name:SetPoint("RIGHT", -58, 0)
    name:SetJustifyH("LEFT")
    row.Name = name

    local count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    count:SetPoint("TOPRIGHT", -2, -2)
    count:SetJustifyH("RIGHT")
    row.Count = count

    local bar = CreateFrame("Frame", nil, row)
    bar:SetPoint("TOPLEFT", 2, -19)
    bar:SetPoint("TOPRIGHT", -2, -19)
    bar:SetHeight(10)
    CreateRoundedBarShell(bar)
    LayoutRoundedBarShell(bar)
    bar:HookScript("OnSizeChanged", function(frame)
        LayoutRoundedBarShell(frame)
    end)
    row.Bar = bar
    row.Segments = {}
    for bucket = 1, 6 do
        local texture = bar:CreateTexture(nil, "ARTWORK")
        row.Segments[bucket] = texture
    end

    row:SetScript("OnEnter", function(frame)
        if not frame.data or not GameTooltip then
            return
        end
        local data = frame.data
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:SetText(data.name, 1, 1, 1)
        GameTooltip:AddDoubleLine("Collected species", string.format("%d / %d", data.collected, data.total), 0.75, 0.75, 0.75, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Missing", tostring(data.buckets[1] or 0), 0.65, 0.65, 0.65, 0.65, 0.65, 0.65)
        GameTooltip:AddDoubleLine("Common or lower", tostring(data.buckets[2] or 0), 0.65, 0.65, 0.65, 0.65, 0.65, 0.65)
        GameTooltip:AddDoubleLine("Uncommon", tostring(data.buckets[3] or 0), 0.75, 0.75, 0.75, 0.12, 0.75, 0.20)
        GameTooltip:AddDoubleLine("Rare", tostring(data.buckets[4] or 0), 0.75, 0.75, 0.75, 0.15, 0.48, 0.95)
        GameTooltip:AddDoubleLine("Epic", tostring(data.buckets[5] or 0), 0.75, 0.75, 0.75, 0.64, 0.25, 0.90)
        GameTooltip:AddDoubleLine("Legendary", tostring(data.buckets[6] or 0), 0.75, 0.75, 0.75, 0.95, 0.50, 0.10)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(frame)
        if GameTooltip:IsOwned(frame) then
            GameTooltip:Hide()
        end
    end)
    return row
end

function PetTracker:RefreshExpansionRow(row, data)
    row.data = data
    row.Name:SetText(data.name)
    row.Count:SetText(string.format("%d / %d", data.collected, data.total))

    LayoutRoundedBarShell(row.Bar)
    local width = row.Bar:GetWidth()
    if not width or width < 10 then
        width = 244
    end
    local padding = row.Bar.RoundInset or 2
    local innerHeight = row.Bar.RoundInnerHeight or math.max(1, (row.Bar:GetHeight() or 10) - (padding * 2))
    local centerLeft = padding + (innerHeight / 2)
    local centerRight = width - padding - (innerHeight / 2)
    local innerWidth = math.max(1, centerRight - centerLeft)
    local left = centerLeft
    local firstColor, lastColor

    local bucketOrder = { 2, 3, 4, 5, 6, 1 }
    for _, bucket in ipairs(bucketOrder) do
        local count = data.buckets[bucket] or 0
        local segmentWidth = data.total > 0 and (innerWidth * count / data.total) or 0
        local texture = row.Segments[bucket]
        texture:ClearAllPoints()
        if segmentWidth > 0 then
            texture:SetPoint("TOPLEFT", row.Bar, "TOPLEFT", left, -padding)
            texture:SetPoint("BOTTOMLEFT", row.Bar, "BOTTOMLEFT", left, padding)
            texture:SetWidth(math.max(1, segmentWidth))
            local quality, owned
            if bucket == 1 then
                quality, owned = nil, 0
            elseif bucket == 2 then
                quality, owned = 2, 1
            else
                quality, owned = bucket, 1
            end
            local r, g, b = GetTrackerColor(quality, owned)
            local color = { r, g, b }
            firstColor = firstColor or color
            lastColor = color
            texture:SetColorTexture(r, g, b, 0.96)
            texture:Show()
            left = left + segmentWidth
        else
            texture:Hide()
        end
    end

    firstColor = firstColor or { GetTrackerColor(nil, 0) }
    lastColor = lastColor or firstColor
    SetRoundedBarCapColors(row.Bar, firstColor[1], firstColor[2], firstColor[3], lastColor[1], lastColor[2], lastColor[3], 0.96)
    row:Show()
end

function PetTracker:BuildExpansionProgress()
    local groups = self:BuildExpansionSpeciesIndex()
    local output = {}

    local function AddExpansion(expansion)
        local group = groups[expansion.key]
        if not group or #group.species == 0 then
            return
        end
        local data = {
            key = expansion.key,
            name = expansion.name,
            order = expansion.order,
            total = #group.species,
            collected = 0,
            buckets = { 0, 0, 0, 0, 0, 0 },
        }
        for _, speciesID in ipairs(group.species) do
            local owned = self:GetCollectionInfo(speciesID)
            if owned.count > 0 then
                data.collected = data.collected + 1
            end
            local bucket = GetTrackerBucket(owned.bestQuality, owned.count)
            data.buckets[bucket] = data.buckets[bucket] + 1
        end
        output[#output + 1] = data
    end

    for _, expansion in ipairs(EXPANSIONS) do
        AddExpansion(expansion)
    end
    AddExpansion(OTHER_EXPANSION)
    return output
end

function PetTracker:CreateZonePetRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ZONE_PET_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ZONE_PET_ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", 0, -((index - 1) * ZONE_PET_ROW_HEIGHT))
    row:RegisterForClicks("LeftButtonUp")

    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.18)
    highlight:Hide()
    row.Highlight = highlight

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 1, 0)
    icon:SetSize(16, 16)
    row.Icon = icon

    local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    name:SetPoint("RIGHT", -34, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.Name = name

    local count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    count:SetPoint("RIGHT", -3, 0)
    count:SetJustifyH("RIGHT")
    row.Count = count

    row:SetScript("OnEnter", function(button)
        if button.Highlight then
            button.Highlight:Show()
        end
        if button.data then
            self:ShowSpeciesTooltip(button, button.data)
        end
    end)
    row:SetScript("OnLeave", function(button)
        if button.Highlight then
            button.Highlight:Hide()
        end
        if GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)

    return row
end

function PetTracker:RefreshZonePetList(display)
    local scroll = self.zonePetScroll
    local content = self.zonePetContent
    if not scroll or not content then
        return
    end

    display = type(display) == "table" and display or {}
    local count = #display
    local visibleRows = math.min(math.max(count, 1), ZONE_PET_MAX_VISIBLE_ROWS)
    scroll:SetHeight(visibleRows * ZONE_PET_ROW_HEIGHT)
    content:SetHeight(math.max(1, count * ZONE_PET_ROW_HEIGHT))
    scroll:SetVerticalScroll(0)

    if self.zonePetsTitle then
        self.zonePetsTitle:SetShown(count > 0)
    end
    scroll:SetShown(count > 0)

    local scrollBar = scroll.ScrollBar or _G[scroll:GetName() and (scroll:GetName() .. "ScrollBar") or ""]
    if scrollBar then
        scrollBar:SetShown(count > ZONE_PET_MAX_VISIBLE_ROWS)
    end

    for index, data in ipairs(display) do
        local row = self.zonePetRows[index]
        if not row then
            row = self:CreateZonePetRow(content, index)
            self.zonePetRows[index] = row
        end

        row.data = data
        row.Icon:SetTexture(data.icon or 134400)
        row.Icon:SetDesaturated((data.count or 0) <= 0)
        row.Icon:SetAlpha((data.count or 0) > 0 and 1 or 0.62)
        row.Name:SetText(data.name or ("Pet " .. tostring(data.speciesID or "")))

        if (data.count or 0) > 0 then
            local r, g, b = GetQualityColor(data.bestQuality)
            row.Name:SetTextColor(r, g, b)
            row.Count:SetText("x" .. tostring(data.count))
            row.Count:SetTextColor(0.82, 0.82, 0.82)
        else
            row.Name:SetTextColor(0.62, 0.62, 0.62)
            row.Count:SetText("")
        end
        row:Show()
    end

    for index = count + 1, #self.zonePetRows do
        self.zonePetRows[index]:Hide()
    end
end

function PetTracker:RefreshExpansionPanel()
    if not self.expansionContent then
        return
    end
    local progress = self:BuildExpansionProgress()
    self.expansionContent:SetHeight(math.max(1, #progress * EXPANSION_ROW_HEIGHT))

    for index, data in ipairs(progress) do
        local row = self.expansionRows[index]
        if not row then
            row = self:CreateExpansionRow(self.expansionContent, index)
            self.expansionRows[index] = row
        end
        self:RefreshExpansionRow(row, data)
    end
    for index = #progress + 1, #self.expansionRows do
        self.expansionRows[index]:Hide()
    end
end

-- Map & Quest Log panel

function PetTracker:PrepareNativeBackdropFrame(frame)
    if not frame then
        return false
    end

    if type(frame.UnregisterAllEvents) == "function" then
        pcall(frame.UnregisterAllEvents, frame)
    end
    for _, scriptName in ipairs({ "OnShow", "OnHide", "OnEvent", "OnUpdate", "OnMouseDown", "OnMouseUp", "OnMouseWheel" }) do
        if type(frame.SetScript) == "function" then
            pcall(frame.SetScript, frame, scriptName, nil)
        end
    end

    local visited = {}
    local function StripContent(current)
        if not current or visited[current] then
            return
        end
        visited[current] = true

        if type(current.EnableMouse) == "function" then
            pcall(current.EnableMouse, current, false)
        end
        if type(current.SetMouseMotionEnabled) == "function" then
            pcall(current.SetMouseMotionEnabled, current, false)
        end
        if type(current.SetMouseClickEnabled) == "function" then
            pcall(current.SetMouseClickEnabled, current, false)
        end

        if type(current.GetRegions) == "function" then
            for _, region in ipairs({ current:GetRegions() }) do
                if region and type(region.GetObjectType) == "function" and type(region.SetAlpha) == "function" then
                    local objectType = region:GetObjectType()
                    local keep = objectType == "Texture" and ShouldKeepNativeLegendTexture(region, frame)
                    if objectType == "FontString" or (objectType == "Texture" and not keep) then
                        pcall(region.SetAlpha, region, 0)
                    end
                end
            end
        end

        if type(current.GetChildren) == "function" then
            for _, child in ipairs({ current:GetChildren() }) do
                StripContent(child)
            end
        end
    end

    StripContent(frame)
    return true
end

function PetTracker:CreateExactNativeBackdrop()
    if self.nativeBackdropFrame then
        self.nativeBackdropFrame:Show()
        self:PrepareNativeBackdropFrame(self.nativeBackdropFrame)
        return true
    end
    if not self.panel then
        return false
    end

    local ok, frame = pcall(CreateFrame, "Frame", nil, self.panel, "MapLegendFrameTemplate")
    if not ok or not frame then
        return false
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 0, PANEL_LAYOUT.backdropTop)
    frame:SetPoint("BOTTOMRIGHT", self.panel, "BOTTOMRIGHT", 0, PANEL_LAYOUT.backdropBottom)
    frame:EnableMouse(false)
    frame:SetFrameLevel(math.max(0, (self.panel:GetFrameLevel() or 1) - 1))
    self.nativeBackdropFrame = frame
    self:PrepareNativeBackdropFrame(frame)
    frame:Show()
    return true
end

function PetTracker:ClearClonedLegendBackdrop()
    local clone = self.nativeLegendBackdropClone
    if clone and clone.textures then
        for _, texture in ipairs(clone.textures) do
            if texture then
                texture:Hide()
                texture:SetTexture(nil)
            end
        end
        wipe(clone.textures)
    end
end

function PetTracker:RefreshClonedLegendBackdrop()
    local panel = self.panel
    local questLog = self.questLogFrame
    local legendFrame = questLog and questLog.MapLegend
    if not panel or not legendFrame then
        return false
    end

    local legendLeft = legendFrame:GetLeft()
    local legendTop = legendFrame:GetTop()
    if not legendLeft or not legendTop then
        return false
    end

    local clone = self.nativeLegendBackdropClone
    if not clone then
        clone = CreateFrame("Frame", nil, panel)
        clone:SetAllPoints(panel)
        clone:EnableMouse(false)
        clone.textures = {}
        self.nativeLegendBackdropClone = clone
    end
    clone:SetFrameLevel(math.max(0, (panel:GetFrameLevel() or 1) - 1))

    self:ClearClonedLegendBackdrop()
    local textures = clone.textures
    local regions = CollectNativeLegendBackdropRegions(legendFrame, legendFrame)
    table.sort(regions, function(a, b)
        local aLayer, aSub = a:GetDrawLayer()
        local bLayer, bSub = b:GetDrawLayer()
        local order = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
        local av = order[aLayer] or 99
        local bv = order[bLayer] or 99
        if av ~= bv then
            return av < bv
        end
        return (aSub or 0) < (bSub or 0)
    end)

    local created = 0
    for _, source in ipairs(regions) do
        local left = source:GetLeft()
        local top = source:GetTop()
        local width = source:GetWidth() or 0
        local height = source:GetHeight() or 0
        if left and top and width > 0 and height > 0 then
            local layer, sublevel = source:GetDrawLayer()
            local texture = clone:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
            if CopyTextureAppearance(source, texture) then
                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT", clone, "TOPLEFT", left - legendLeft, top - legendTop)
                texture:SetSize(width, height)
                local blend = source:GetBlendMode()
                if blend then
                    texture:SetBlendMode(blend)
                end
                texture:SetAlpha(source:GetAlpha() or 1)
                textures[#textures + 1] = texture
                created = created + 1
            else
                texture:Hide()
            end
        end
    end

    clone:SetShown(created > 0)
    if self.panelBackground then
        self.panelBackground:SetShown(created == 0)
    end
    return created > 0
end

function PetTracker:ActivatePanel()
    local questLog = self.questLogFrame
    if not questLog or not self.panel then
        return false
    end

    if questLog.displayMode ~= TRACKER_DISPLAY_MODE then
        self.previousDisplayMode = questLog.displayMode
    end
    questLog.displayMode = TRACKER_DISPLAY_MODE

    for _, frame in ipairs(questLog.TabButtons or {}) do
        if type(frame.SetChecked) == "function" then
            frame:SetChecked(frame.displayMode == TRACKER_DISPLAY_MODE)
        end
    end
    for _, frame in ipairs(questLog.ContentFrames or {}) do
        frame:SetShown(frame.displayMode == TRACKER_DISPLAY_MODE)
    end

    -- Prefer the native template, then cloned artwork, then the atlas fallback.
    local exact = self:CreateExactNativeBackdrop()
    local cloned = false
    if not exact then
        cloned = self:RefreshClonedLegendBackdrop()
    elseif self.nativeLegendBackdropClone then
        self.nativeLegendBackdropClone:Hide()
    end
    if self.panelBackground then
        self.panelBackground:SetShown(not exact and not cloned)
    end
    if not exact and not cloned then
        self:ApplyNativePanelBackground()
    end
    return true
end

function PetTracker:ApplyNativePanelBackground()
    local background = self.panelBackground
    local panel = self.panel
    local questLog = self.questLogFrame or GetQuestLogFrame()
    if not background or not panel or not questLog then
        return false
    end

    local candidates = {
        questLog.MapLegend,
        questLog.QuestsFrame,
        questLog.DetailsFrame,
        questLog.QuestDetailsFrame,
        questLog.CampaignOverviewFrame,
        questLog.EventDetailsFrame,
    }

    local applied = false
    for _, candidateFrame in ipairs(candidates) do
        if candidateFrame and candidateFrame ~= panel then
            local source = FindPanelBackgroundTexture(candidateFrame)
            if source and CopyTextureAppearance(source, background) then
                applied = true
                break
            end
        end
    end

    if not applied then
        for _, frame in ipairs(questLog.ContentFrames or {}) do
            if frame and frame ~= panel and frame:IsShown() then
                local source = FindPanelBackgroundTexture(frame)
                if source and CopyTextureAppearance(source, background) then
                    applied = true
                    break
                end
            end
        end
    end

    if not applied then
        applied = pcall(background.SetAtlas, background, "QuestLog-main-background", false)
    end

    if not applied then
        background:SetColorTexture(0.06, 0.055, 0.045, 1)
        background:SetVertexColor(1, 1, 1, 1)
        background:SetTexCoord(0, 1, 0, 1)
    end

    return applied
end

function PetTracker:CreateMapUI()
    if self.panel and self.mapTab then
        return true
    end
    if not WorldMapFrame then
        return false
    end

    local questLog = GetQuestLogFrame()
    if not questLog then
        return false
    end
    self.questLogFrame = questLog

    local panel = CreateFrame("Frame", "DXPetServicesPetTrackerPanel", questLog)
    panel.displayMode = TRACKER_DISPLAY_MODE
    local nativePanelFrame = questLog.MapLegend
    if nativePanelFrame then
        panel:SetAllPoints(nativePanelFrame)
    else
        local contentsAnchor = questLog.ContentsAnchor or questLog
        panel:SetPoint("TOPLEFT", contentsAnchor, "TOPLEFT", 0, -29)
        panel:SetPoint("BOTTOMRIGHT", contentsAnchor, "BOTTOMRIGHT", -22, 0)
    end
    -- The native border extends a few pixels beyond the content frame.
    panel:SetClipsChildren(false)
    panel:Hide()
    if nativePanelFrame then
        panel:SetFrameLevel((nativePanelFrame:GetFrameLevel() or 1) + 10)
    end
    self.panel = panel

    -- The tracker is its own display mode and borrows only Map Legend styling.
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(panel)
    background:Hide()
    self.panelBackground = background

    local exactBackdrop = self:CreateExactNativeBackdrop()
    local clonedBackdrop = false
    if not exactBackdrop then
        clonedBackdrop = self:RefreshClonedLegendBackdrop()
    end
    if not exactBackdrop and not clonedBackdrop then
        background:Show()
        self:ApplyNativePanelBackground()
    end

    if type(questLog.ContentFrames) == "table" then
        questLog.ContentFrames[#questLog.ContentFrames + 1] = panel
    end

    local contentRoot = CreateFrame("Frame", nil, panel)
    if self.nativeBackdropFrame then
        contentRoot:SetPoint("TOPLEFT", self.nativeBackdropFrame, "TOPLEFT", PANEL_LAYOUT.contentLeft, PANEL_LAYOUT.contentTop)
        contentRoot:SetPoint("BOTTOMRIGHT", self.nativeBackdropFrame, "BOTTOMRIGHT", PANEL_LAYOUT.contentRight, PANEL_LAYOUT.contentBottom)
    else
        contentRoot:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_LAYOUT.contentLeft, PANEL_LAYOUT.contentTop)
        contentRoot:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", PANEL_LAYOUT.contentRight, PANEL_LAYOUT.contentBottom)
    end
    self.contentRoot = contentRoot

    local pageTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pageTitle:SetPoint("TOP", panel, "TOP", 0, PANEL_LAYOUT.titleY)
    pageTitle:SetJustifyH("CENTER")
    pageTitle:SetText("Pet Tracker")
    pageTitle:SetTextColor(1, 1, 1)
    self.pageTitle = pageTitle

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", contentRoot, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", contentRoot, "TOPRIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    self.panelTitle = title

    local summary = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    summary:SetPoint("RIGHT", contentRoot, "RIGHT", 0, 0)
    summary:SetJustifyH("LEFT")
    summary:SetTextColor(0.75, 0.75, 0.75)
    self.panelSummary = summary

    local trackCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    trackCheck:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", -4, -7)
    trackCheck:SetSize(22, 22)
    local trackLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    trackLabel:SetPoint("LEFT", trackCheck, "RIGHT", 2, 0)
    trackLabel:SetText("Show in Objective Tracker")
    trackCheck:SetScript("OnClick", function(button)
        if ns.db and ns.db.settings then
            ns.db.settings.petTrackerObjectiveTracker = button:GetChecked() == true
            self:RefreshObjectiveTracker()
        end
    end)
    self.trackCheck = trackCheck

    local zoneBar = CreateSegmentedBar(panel, 20)
    zoneBar:SetPoint("TOPLEFT", trackCheck, "BOTTOMLEFT", 4, -8)
    zoneBar:SetPoint("TOPRIGHT", contentRoot, "TOPRIGHT", 0, 0)
    self.zoneBar = zoneBar

    local zonePetsTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    zonePetsTitle:SetPoint("TOPLEFT", zoneBar, "BOTTOMLEFT", 0, -12)
    zonePetsTitle:SetText("Pets in This Area")
    zonePetsTitle:SetTextColor(0.35, 0.75, 1.0)
    self.zonePetsTitle = zonePetsTitle

    local zonePetScroll = CreateFrame("ScrollFrame", "DXPetServicesPetTrackerZonePetScrollFrame", panel, "UIPanelScrollFrameTemplate")
    zonePetScroll:SetPoint("TOPLEFT", zonePetsTitle, "BOTTOMLEFT", -2, -4)
    zonePetScroll:SetPoint("TOPRIGHT", contentRoot, "TOPRIGHT", -18, 0)
    zonePetScroll:SetHeight(ZONE_PET_ROW_HEIGHT)
    self.zonePetScroll = zonePetScroll

    local zonePetContent = CreateFrame("Frame", nil, zonePetScroll)
    zonePetContent:SetSize(250, 1)
    zonePetScroll:SetScrollChild(zonePetContent)
    zonePetScroll:HookScript("OnSizeChanged", function(frame, width)
        zonePetContent:SetWidth(math.max(1, (tonumber(width) or frame:GetWidth() or 250) - 2))
    end)
    self.zonePetContent = zonePetContent

    local sectionTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionTitle:SetPoint("TOPLEFT", zonePetScroll, "BOTTOMLEFT", 2, -10)
    sectionTitle:SetText("Wild Pet Collection by Expansion")
    sectionTitle:SetTextColor(0.35, 0.75, 1.0)

    local rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -7)
    rule:SetPoint("TOPRIGHT", contentRoot, "TOPRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetColorTexture(0.35, 0.75, 1, 0.35)

    local scroll = CreateFrame("ScrollFrame", "DXPetServicesPetTrackerExpansionScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", -2, -8)
    scroll:SetPoint("BOTTOMRIGHT", contentRoot, "BOTTOMRIGHT", -13, 0)
    self.expansionScroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(250, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function(frame, width)
        content:SetWidth(math.max(1, (tonumber(width) or frame:GetWidth() or 250) - 2))
        self:RefreshExpansionPanel()
    end)
    self.expansionContent = content

    local tab
    local ok, created = pcall(CreateFrame, "Frame", nil, questLog, "DXPetServicesPetTrackerMapTabTemplate")
    if ok then
        tab = created
    end
    if not tab then
        tab = CreateFrame("Button", "DXPetServicesPetTrackerMapTab", questLog, "UIPanelButtonTemplate")
        tab:SetSize(38, 46)
        tab:SetText("")
        local paw = tab:CreateTexture(nil, "ARTWORK")
        paw:SetPoint("CENTER", 0, 0)
        paw:SetSize(25, 25)
        local pawAtlasOK = pcall(paw.SetAtlas, paw, "WildBattlePetCapturable", false)
        if not pawAtlasOK then
            paw:SetTexture("Interface\\Icons\\INV_Pet_BattlePetTraining")
            paw:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        tab.paw = paw
    end

    tab.displayMode = TRACKER_DISPLAY_MODE
    local relativeTab = questLog.MapLegendTab or questLog.EventsTab or questLog.QuestsTab
    tab:ClearAllPoints()
    if relativeTab then
        tab:SetPoint("TOP", relativeTab, "BOTTOM", 0, -3)
    else
        tab:SetPoint("TOPLEFT", questLog, "TOPRIGHT", 3, -178)
    end
    self.mapTab = tab

    local function TintTrackerTabIcon()
        local icon = tab.Icon or tab.icon or tab.paw
        if icon and type(icon.SetVertexColor) == "function" then
            icon:SetVertexColor(unpack(TAB_ICON_COLOR))
        end
    end
    TintTrackerTabIcon()
    tab:HookScript("OnShow", TintTrackerTabIcon)

    if type(questLog.TabButtons) == "table" then
        questLog.TabButtons[#questLog.TabButtons + 1] = tab
    end

    if type(tab.SetChecked) == "function" then
        tab:SetChecked(false)
        TintTrackerTabIcon()
    end

    local function OpenTrackerFromTab(_, button, upInside)
        if button == "LeftButton" and upInside then
            self:SetPanelOpen(true)
        end
    end
    if type(tab.SetCustomOnMouseUpHandler) == "function" then
        tab:SetCustomOnMouseUpHandler(OpenTrackerFromTab)
    elseif tab:GetObjectType() == "Button" then
        tab:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then
                self:SetPanelOpen(true)
            end
        end)
    else
        tab:HookScript("OnMouseUp", OpenTrackerFromTab)
    end

    tab:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Zone Pet Tracker")
        GameTooltip:AddLine("Show catchable pets and collection progress for the current map.", 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function(button)
        if GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)

    panel:SetScript("OnShow", function()
        self.panelOpen = true
        self:RefreshPanel()
        self:RefreshWorldMap()
    end)
    panel:SetScript("OnHide", function()
        self.panelOpen = false
        self:RefreshWorldMap()
    end)

    if not self.mapChangedHooked then
        self.mapChangedHooked = true
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            self:RefreshPanel()
            self.mapRefreshToken = (self.mapRefreshToken or 0) + 1
            local token = self.mapRefreshToken
            local function RefreshPinsAfterMapSettles()
                if token ~= self.mapRefreshToken then
                    return
                end
                self:RefreshWorldMap()
                self:RefreshPanel()
            end
            C_Timer.After(0, RefreshPinsAfterMapSettles)
            C_Timer.After(0.15, RefreshPinsAfterMapSettles)
        end)
    end
    if not self.mapShowRefreshHooked then
        self.mapShowRefreshHooked = true
        WorldMapFrame:HookScript("OnShow", function()
            C_Timer.After(0, function()
                self:RefreshWorldMap()
                self:RefreshPanel()
            end)
        end)
    end
    if not self.mapHidePinHooked then
        self.mapHidePinHooked = true
        WorldMapFrame:HookScript("OnHide", function()
            self:HideDirectMapPins()
        end)
    end

    self:RefreshSettings()
    return true
end

function PetTracker:SetPanelOpen(open)
    open = open == true
    if not self.panel then
        self:CreateMapUI()
    end
    if not self.panel then
        return false
    end
    if open and self.questLogFrame and not self.questLogFrame:IsShown() and WorldMapFrame then
        if type(WorldMapFrame.SetQuestLogPanelShown) == "function" then
            pcall(WorldMapFrame.SetQuestLogPanelShown, WorldMapFrame, true)
        elseif type(WorldMapFrame.HandleUserActionToggleSidePanel) == "function" then
            pcall(WorldMapFrame.HandleUserActionToggleSidePanel, WorldMapFrame)
        end
    end

    if open then
        self:ActivatePanel()
        self.panelOpen = true
        self:RefreshPanel()
    else
        local questLog = self.questLogFrame
        if questLog and questLog.displayMode == TRACKER_DISPLAY_MODE then
            local restore = self.previousDisplayMode
            if restore == TRACKER_DISPLAY_MODE or restore == nil then
                restore = QuestLogDisplayMode and QuestLogDisplayMode.Quests or nil
            end
            if restore then
                questLog:SetDisplayMode(restore)
            else
                self.panel:Hide()
                if self.mapTab and type(self.mapTab.SetChecked) == "function" then
                    self.mapTab:SetChecked(false)
                end
            end
        else
            self.panel:Hide()
        end
        self.panelOpen = false
    end
    self:RefreshWorldMap()
    return open
end

function PetTracker:TogglePanel()
    return self:SetPanelOpen(not self.panelOpen)
end

function PetTracker:RefreshPanel(mapID)
    if not self.panel then
        return
    end
    local exactBackdrop = self:CreateExactNativeBackdrop()
    local clonedBackdrop = false
    if not exactBackdrop then
        clonedBackdrop = self:RefreshClonedLegendBackdrop()
    elseif self.nativeLegendBackdropClone then
        self.nativeLegendBackdropClone:Hide()
    end
    if self.panelBackground then
        self.panelBackground:SetShown(not exactBackdrop and not clonedBackdrop)
    end
    if not exactBackdrop and not clonedBackdrop then
        self:ApplyNativePanelBackground()
    end
    mapID = tonumber(mapID) or GetMapID()
    local display, collectedSpecies, totalSpecies = self:BuildZoneDisplay(mapID)
    local zoneName = GetMapName(mapID)
    self.panelTitle:SetText(zoneName)

    if totalSpecies == 0 then
        self.panelSummary:SetText("No catchable pets indexed for this map")
        self.zoneBar.Text:SetText("0 / 0")
        self:RefreshSegmentedBar(self.zoneBar, {})
    else
        self.panelSummary:SetText(string.format("%d / %d species collected  •  %d need work", collectedSpecies, totalSpecies, totalSpecies - collectedSpecies))
        self.zoneBar.Text:SetText(string.format("%d / %d", collectedSpecies, totalSpecies))
        self:RefreshSegmentedBar(self.zoneBar, display)
    end
    self:RefreshZonePetList(display)

    if self.trackCheck and ns.db and ns.db.settings then
        self.trackCheck:SetChecked(ns.db.settings.petTrackerObjectiveTracker == true)
    end
    self:RefreshExpansionPanel()
end

-- Objective Tracker integration

function PetTracker:CreateObjectiveLine(parent, index)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(OBJECTIVE_LINE_HEIGHT)
    line:SetPoint("TOPLEFT", 0, -((index - 1) * OBJECTIVE_LINE_STEP))
    line:SetPoint("TOPRIGHT", 0, -((index - 1) * OBJECTIVE_LINE_STEP))
    line:EnableMouse(false)

    local icon = line:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 0, 0)
    icon:SetSize(16, 16)
    line.Icon = icon

    local text = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetPoint("RIGHT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    line.Text = text
    return line
end

function PetTracker:CreateObjectiveTrackerUI()
    if self.objectivePanel then
        return true
    end
    local parent = ObjectiveTrackerFrame
    if not parent then
        return false
    end

    -- Wait for Blizzard's objective tracker templates instead of creating a
    -- Wait for Blizzard's native objective-tracker header template to load.
    local ok, header = pcall(CreateFrame, "Frame", nil, parent, "ObjectiveTrackerModuleHeaderTemplate")
    if not ok or not header then
        return false
    end

    self.objectiveParent = parent
    self.objectiveHeader = header
    if header.Text then
        header.Text:SetText(_G.PETS or "Battle Pets")
    end
    if header.MinimizeButton then
        header.MinimizeButton:SetScript("OnClick", function()
            self.objectiveCollapsed = not self.objectiveCollapsed
            header:SetCollapsed(self.objectiveCollapsed)
            self:LayoutObjectiveTracker()
            if PlaySound and SOUNDKIT then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
        end)
    end
    header:Hide()

    local panel = CreateFrame("Frame", "DXPetServicesObjectivePetTracker", parent)
    panel:SetSize(280, 180)
    panel:EnableMouse(false)
    panel:Hide()
    self.objectivePanel = panel

    local bar = CreateSegmentedBar(panel, 17)
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", -5, 0)
    self.objectiveBar = bar

    local lines = CreateFrame("Frame", nil, panel)
    lines:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 1, -5)
    lines:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -1, -5)
    lines:SetHeight(1)
    self.objectiveLinesFrame = lines

    if ObjectiveTrackerContainerMixin and not self.objectiveUpdateHooked then
        self.objectiveUpdateHooked = true
        hooksecurefunc(ObjectiveTrackerContainerMixin, "Update", function(container)
            if container == self.objectiveParent then
                self:LayoutObjectiveTracker()
            end
        end)
    end
    parent:HookScript("OnShow", function()
        self:LayoutObjectiveTracker()
    end)
    parent:HookScript("OnSizeChanged", function()
        self:LayoutObjectiveTracker()
    end)
    return true
end

function PetTracker:RefreshObjectiveLines(display, maxEntries)
    if not self.objectiveLinesFrame then
        return
    end
    maxEntries = math.max(0, math.min(maxEntries or 0, #display))
    for index = 1, maxEntries do
        local data = display[index]
        local line = self.objectiveLines[index]
        if not line then
            line = self:CreateObjectiveLine(self.objectiveLinesFrame, index)
            self.objectiveLines[index] = line
        end
        line.Icon:SetTexture(data.icon)
        line.Icon:SetDesaturated(data.count <= 0)
        local r, g, b
        if data.count <= 0 then
            r, g, b = 1.0, 0.30, 0.25
        else
            r, g, b = GetTrackerColor(data.bestQuality, data.count)
        end
        line.Text:SetText(data.name)
        line.Text:SetTextColor(r, g, b)
        line:Show()
    end
    for index = maxEntries + 1, #self.objectiveLines do
        self.objectiveLines[index]:Hide()
    end
    self.objectiveLinesFrame:SetHeight(math.max(1, maxEntries * OBJECTIVE_LINE_STEP))
end

function PetTracker:LayoutObjectiveTracker()
    if not self:CreateObjectiveTrackerUI() then
        return
    end
    local parent = self.objectiveParent
    local panel = self.objectivePanel
    local header = self.objectiveHeader
    if not parent or not panel or not header then
        return
    end

    local enabled = ns.db and ns.db.settings and ns.db.settings.petTrackerObjectiveTracker == true
    local mapID = GetPlayerMapID()
    local display, collected, total = self:BuildZoneDisplay(mapID)
    if not enabled or total == 0 or parent.isCollapsed then
        panel:Hide()
        header:Hide()
        return
    end

    local used = 0
    for _, module in ipairs(parent.modules or {}) do
        if module and module ~= panel and type(module.GetContentsHeight) == "function" then
            local ok, height = pcall(module.GetContentsHeight, module)
            height = ok and tonumber(height) or 0
            if height and height > 0 then
                used = used + height + 10
            end
        end
    end

    local available = 600
    if type(parent.GetAvailableHeight) == "function" then
        local ok, height = pcall(parent.GetAvailableHeight, parent)
        if ok and tonumber(height) then
            available = tonumber(height)
        end
    elseif parent.GetHeight then
        available = parent:GetHeight() or available
    end
    local free = available - used
    if free < 103 then
        panel:Hide()
        header:Hide()
        return
    end

    local maxEntries = Clamp(math.floor((free - 103) / OBJECTIVE_LINE_STEP), 0, 12)
    local width = math.max(230, (parent:GetWidth() or 300) - 30)
    panel:SetWidth(width)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -(used + 73))

    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", -15, 35)
    header:SetCollapsed(self.objectiveCollapsed)

    self.objectiveBar.Text:SetText(string.format("%d / %d", collected, total))
    self:RefreshSegmentedBar(self.objectiveBar, display)
    self:RefreshObjectiveLines(display, maxEntries)

    panel:SetHeight(24 + (maxEntries * OBJECTIVE_LINE_STEP))
    header:Show()
    panel:SetShown(not self.objectiveCollapsed)

    -- Blizzard can finish laying out objective modules after our hook fires.
    -- Keep one delayed verification pending while this block is active.
    self.objectiveLayoutToken = (self.objectiveLayoutToken or 0) + 1
    local token = self.objectiveLayoutToken
    C_Timer.After(5, function()
        if token == self.objectiveLayoutToken and self.objectiveHeader and self.objectiveHeader:IsShown() then
            self:LayoutObjectiveTracker()
        end
    end)
end

function PetTracker:RefreshObjectiveTracker()
    self:CreateObjectiveTrackerUI()
    self:LayoutObjectiveTracker()
end

-- Module lifecycle

function PetTracker:OnInitialize()
    ns.Events:Register("ADDON_LOADED", self, "OnAddonLoaded")
    ns.Events:Register("PET_JOURNAL_LIST_UPDATE", self, "OnCollectionChanged")
    ns.Events:Register("NEW_PET_ADDED", self, "OnCollectionChanged")
    ns.Events:Register("PET_JOURNAL_PET_DELETED", self, "OnCollectionChanged")
    ns.Events:Register("ZONE_CHANGED_NEW_AREA", self, "OnZoneChanged")
    ns.Events:Register("ZONE_CHANGED", self, "OnZoneChanged")
    ns.Events:Register("PLAYER_ENTERING_WORLD", self, "OnZoneChanged")
end

function PetTracker:OnEnable()
    self:CreateMapUI()
    self:TryRegisterWorldMap()
    self:CreateObjectiveTrackerUI()
    self:RefreshObjectiveTracker()
end

function PetTracker:OnAddonLoaded(_, loadedAddon)
    if loadedAddon == "Blizzard_WorldMap" or loadedAddon == "Blizzard_UIPanels_Game" then
        self:CreateMapUI()
        self:TryRegisterWorldMap()
    elseif loadedAddon == "Blizzard_ObjectiveTracker" then
        self:CreateObjectiveTrackerUI()
        self:RefreshObjectiveTracker()
    end
end

function PetTracker:OnZoneChanged()
    C_Timer.After(0.15, function()
        self:RefreshObjectiveTracker()
    end)
end

function PetTracker:OnCollectionChanged()
    self.collectionDirty = true
    self.refreshToken = self.refreshToken + 1
    local token = self.refreshToken
    C_Timer.After(0.15, function()
        if token ~= self.refreshToken then
            return
        end
        self:RefreshWorldMap()
        self:RefreshPanel()
        self:RefreshObjectiveTracker()
    end)
end

function PetTracker:RefreshSettings()
    if self.panelOpen and self.panel then
        self:RefreshPanel()
    end
    if self.trackCheck then
        self.trackCheck:SetChecked(ns.db.settings.petTrackerObjectiveTracker == true)
    end
    self:RefreshWorldMap()
    self:RefreshObjectiveTracker()
end

-- XML template mixin. The MapCanvasPinMixin methods are copied in after the
-- Blizzard map framework is available, matching the addon's existing source pins.
if MapCanvasPinMixin and type(CreateFromMixins) == "function" then
    DXPetServicesWildPetMapPinMixin = CreateFromMixins(MapCanvasPinMixin)
else
    DXPetServicesWildPetMapPinMixin = {}
end

-- See MapPetPins.lua: Blizzard's inherited implementation calls the
-- protected SetPassThroughButtons API during AcquirePin. Addon-owned pins must
-- not mutate that protected state while the map refresh runs securely.
function DXPetServicesWildPetMapPinMixin:CheckMouseButtonPassthrough(...)
    -- Intentionally empty to prevent ADDON_BLOCKED on world-map refresh.
end

function DXPetServicesWildPetMapPinMixin:OnLoad()
    if type(self.SetScalingLimits) == "function" then
        self:SetScalingLimits(1, 1, 1.2)
    end
    if self.Icon then
        local maskApplied = type(self.Icon.SetMask) == "function" and pcall(self.Icon.SetMask, self.Icon, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        if not maskApplied then
            ApplyCircularMask(self.Icon, self)
        end
    end
end

function DXPetServicesWildPetMapPinMixin:OnAcquired(data)
    self.data = data
    self:SetPosition(data.x, data.y)
    local species = GetSpeciesInfo(data.speciesID)
    self:SetSize(16, 16)
    self.Icon:SetSize(14, 14)
    self.Icon:SetTexture(species.icon)
    self.Icon:SetDesaturated(false)
    self.Icon:SetAlpha(1)
    if self.Border then
        self.Border:SetSize(22, 22)
        self.Border:SetVertexColor(1, 1, 1, 1)
    end
    self:Show()
end

function DXPetServicesWildPetMapPinMixin:OnReleased()
    self.data = nil
end

function DXPetServicesWildPetMapPinMixin:OnMouseEnter()
    if self.data then
        PetTracker:ShowSpeciesTooltip(self, self.data)
    end
end

function DXPetServicesWildPetMapPinMixin:OnMouseLeave()
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

function DXPetServicesWildPetMapPinMixin:OnClick(button)
    if button == "LeftButton" and self.data and not self.data.rosterOnly then
        SetWaypoint(self.data)
    end
end

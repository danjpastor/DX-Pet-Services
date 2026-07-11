local addonName, ns = ...

local MapPetPins = {
    worldMapRegistered = false,
    worldMapProvider = nil,
    minimapPins = {},
    minimapUpdateFrame = nil,
    minimapRefreshElapsed = 0,
    minimapMapTransform = nil,
    currentMinimapMapID = nil,
    nameCache = {},
}
ns:RegisterModule("MapPetPins", MapPetPins)

local PAW_ATLAS = "WildBattlePetCapturable"
local WORLD_MAP_PIN_TEMPLATE = "DXPetServicesWorldMapPinTemplate"
local MAX_MINIMAP_PINS = 24
local BLUE_R, BLUE_G, BLUE_B = 0.35, 0.75, 1.0

-- Shared helpers

local function IsSecretValue(value)
    if value == nil then
        return false
    end
    if type(issecretvalue) == "function" then
        local ok, result = pcall(issecretvalue, value)
        if ok and result then
            return true
        end
    end
    if type(canaccessvalue) == "function" then
        local ok, result = pcall(canaccessvalue, value)
        if ok and result == false then
            return true
        end
    end
    return false
end

local function SafeNumber(value)
    if type(value) ~= "number" or IsSecretValue(value) then
        return nil
    end
    return value
end

local function GetCreatureName(npcID)
    npcID = tonumber(npcID)
    if not npcID then
        return "Pet Source"
    end

    local saved = ns.db and ns.db.npcNames and (ns.db.npcNames[npcID] or ns.db.npcNames[tostring(npcID)])
    if type(saved) == "string" and saved ~= "" then
        return saved
    end

    local cached = MapPetPins.nameCache[npcID]
    if type(cached) == "string" and cached ~= "" then
        return cached
    end

    local name
    if C_CreatureInfo and type(C_CreatureInfo.GetCreatureInfo) == "function" then
        local ok, info = pcall(C_CreatureInfo.GetCreatureInfo, npcID)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            name = info.name
        end
    end
    if not name and type(GetCreatureInfo) == "function" then
        local ok, value = pcall(GetCreatureInfo, npcID)
        if ok and type(value) == "string" and value ~= "" then
            name = value
        end
    end

    -- Creature names learned from visible nameplates and merchant sessions are
    -- persisted by NPCPetIndicators. Never expose a raw numeric NPC ID in the
    -- world-map tooltip while the client is still resolving a localized name.
    if name then
        MapPetPins.nameCache[npcID] = name
        if ns.db and type(ns.db.npcNames) == "table" then
            ns.db.npcNames[npcID] = name
            ns.db.npcNames[tostring(npcID)] = nil
        end
        return name
    end

    return "Pet Source"
end


local function DisablePixelSnapping(region)
    if not region then
        return
    end
    region:SetTexelSnappingBias(0)
    region:SetSnapToPixelGrid(false)
end

local function SetPawTexture(texture, size)
    DisablePixelSnapping(texture)
    texture:SetSize(size, size)
    local atlasOK = pcall(texture.SetAtlas, texture, PAW_ATLAS, false)
    if not atlasOK then
        texture:SetTexture("Interface\\Icons\\INV_Pet_BattlePetTraining")
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    texture:SetVertexColor(BLUE_R, BLUE_G, BLUE_B)
end

local function GetLocationRows(mapID)
    local db = ns.ATTPetWorldDB
    local byMap = db and db.locationsByMap
    local rows = mapID and byMap and byMap[mapID]
    return type(rows) == "table" and rows or nil
end

local function GetPlayerMapPosition(mapID)
    if not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then
        return nil, nil
    end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil, nil
    end
    local x, y = position:GetXY()
    return SafeNumber(x), SafeNumber(y)
end

local function GetMapWorldSize(mapID)
    if not C_Map or type(C_Map.GetMapWorldSize) ~= "function" then
        return nil, nil
    end
    local width, height = C_Map.GetMapWorldSize(mapID)
    return SafeNumber(width), SafeNumber(height)
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

local function GetWorldPositionForMapPoint(mapID, x, y)
    if not C_Map or type(C_Map.GetWorldPosFromMapPos) ~= "function" then
        return nil, nil, nil
    end
    local vector = CreateMapVector(x, y)
    if not vector then
        return nil, nil, nil
    end

    local first, second = C_Map.GetWorldPosFromMapPos(mapID, vector)

    local continentID, worldPosition
    if type(first) == "number" then
        continentID, worldPosition = SafeNumber(first), second
    else
        worldPosition, continentID = first, SafeNumber(second)
    end
    local wx, wy = ReadVectorXY(worldPosition)
    return continentID, wx, wy
end

local function GetReliableMapWorldSize(mapID)
    -- Prefer Blizzard's direct map span. Unlike converting each individual
    -- point to world space, this remains stable on scenario-style maps where
    -- point conversion can collapse multiple positions onto the player.
    local width, height = GetMapWorldSize(mapID)
    if width and height and width > 10 and height > 10 then
        return width, height, "GetMapWorldSize"
    end

    -- Derive the span from map corners only when the transform is meaningful.
    local continentA, x00, y00 = GetWorldPositionForMapPoint(mapID, 0, 0)
    local continentB, x10, y10 = GetWorldPositionForMapPoint(mapID, 1, 0)
    local continentC, x01, y01 = GetWorldPositionForMapPoint(mapID, 0, 1)
    if not x00 or not y00 or not x10 or not y10 or not x01 or not y01 then
        return nil, nil, nil
    end
    if continentA and continentB and continentA ~= continentB then
        return nil, nil, nil
    end
    if continentA and continentC and continentA ~= continentC then
        return nil, nil, nil
    end

    width = math.sqrt(((x10 - x00) ^ 2) + ((y10 - y00) ^ 2))
    height = math.sqrt(((x01 - x00) ^ 2) + ((y01 - y00) ^ 2))
    if width > 10 and height > 10 then
        return width, height, "map-corner transform"
    end
    return nil, nil, nil
end

local function GetUserWaypointData()
    if not C_Map or type(C_Map.GetUserWaypoint) ~= "function" then
        return nil
    end
    local ok, point = pcall(C_Map.GetUserWaypoint)
    if not ok or not point then
        return nil
    end

    local mapID = SafeNumber(point.uiMapID or point.mapID)
    local position = point.position or point
    local x, y = ReadVectorXY(position)
    if mapID and x and y then
        return { mapID = mapID, x = x, y = y }
    end
    return nil
end

local function IsSameWaypoint(data)
    if not data or not data.mapID or not data.x or not data.y then
        return false
    end
    local current = GetUserWaypointData()
    if not current or current.mapID ~= data.mapID then
        return false
    end
    return math.abs(current.x - data.x) < 0.0005 and math.abs(current.y - data.y) < 0.0005
end

local function SetWaypointMarkerTexture(texture)
    if not texture then
        return false
    end
    if type(texture.SetAtlas) == "function" then
        local ok = pcall(texture.SetAtlas, texture, "Waypoint-MapPin-Tracked", false)
        if ok then
            return true
        end
    end
    texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    texture:SetTexCoord(0, 1, 0, 1)
    return true
end

local function GetMinimapRadius()
    if C_Minimap and type(C_Minimap.GetViewRadius) == "function" then
        local ok, radius = pcall(C_Minimap.GetViewRadius)
        radius = ok and SafeNumber(radius) or nil
        if radius and radius > 0 then
            return radius
        end
    end
    return 200
end

local function IsRotateMinimapEnabled()
    if C_CVar and type(C_CVar.GetCVar) == "function" then
        local ok, value = pcall(C_CVar.GetCVar, "rotateMinimap")
        return ok and value == "1"
    end
    if type(GetCVar) == "function" then
        local ok, value = pcall(GetCVar, "rotateMinimap")
        return ok and value == "1"
    end
    return false
end

local function GetCurrentMinimapMapID()
    if C_Minimap and type(C_Minimap.GetUiMapID) == "function" then
        local ok, mapID = pcall(C_Minimap.GetUiMapID)
        mapID = ok and SafeNumber(mapID) or nil
        if mapID then
            return mapID
        end
    end
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        mapID = ok and SafeNumber(mapID) or nil
        if mapID then
            return mapID
        end
    end
    return nil
end

-- Lifecycle

function MapPetPins:OnInitialize()
    ns.Events:Register("ADDON_LOADED", self, "OnAddonLoaded")
    ns.Events:Register("PLAYER_ENTERING_WORLD", self, "OnZoneChanged")
    ns.Events:Register("ZONE_CHANGED_NEW_AREA", self, "OnZoneChanged")
    ns.Events:Register("PET_JOURNAL_LIST_UPDATE", self, "OnCollectionChanged")
    ns.Events:Register("NEW_PET_ADDED", self, "OnCollectionChanged")
    ns.Events:Register("PET_JOURNAL_PET_DELETED", self, "OnCollectionChanged")
    ns.Events:Register("USER_WAYPOINT_UPDATED", self, "OnWaypointUpdated")
end

function MapPetPins:OnEnable()
    self:TryRegisterWorldMap()
    self:CreateMinimapTicker()
    self:UpdateMinimapPins()
end

function MapPetPins:OnAddonLoaded(_, loadedAddon)
    if loadedAddon == "Blizzard_WorldMap" then
        self:TryRegisterWorldMap()
    end
end

function MapPetPins:OnZoneChanged()
    self.currentMinimapMapID = nil
    self.minimapMapTransform = nil
    self:UpdateMinimapPins()
end

function MapPetPins:OnCollectionChanged()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
end

function MapPetPins:OnWaypointUpdated()
    self:RefreshWorldMap()
end

-- Source data and tooltips

function MapPetPins:GetSpeciesForNPC(npcID)
    local indicators = ns:GetModule("NPCPetIndicators")
    if not indicators then
        return nil
    end

    local result = {}
    local found = false
    if type(indicators.GetSpeciesForNPC) == "function" then
        local species = indicators:GetSpeciesForNPC(npcID, nil)
        for speciesID in pairs(species or {}) do
            result[speciesID] = true
            found = true
        end
    end
    if type(indicators.GetBossSpecies) == "function" then
        local species = indicators:GetBossSpecies(npcID)
        for speciesID in pairs(species or {}) do
            result[speciesID] = true
            found = true
        end
    end
    return found and result or nil
end

function MapPetPins:GetTooltipEntries(speciesSet)
    local indicators = ns:GetModule("NPCPetIndicators")
    if indicators then
        return indicators:GetSpeciesTooltipEntries(speciesSet)
    end
    return {}
end

function MapPetPins:HasUncollectedPets(npcID)
    local speciesSet = self:GetSpeciesForNPC(npcID)
    if not speciesSet then
        return false, 0, 0
    end

    local indicators = ns:GetModule("NPCPetIndicators")
    if not indicators or type(indicators.GetCollectionProgress) ~= "function" then
        -- Fail open while the collection API is unavailable so sources do not
        -- disappear merely because Blizzard has not initialized the journal yet.
        return true, 0, 1
    end

    local collected, available = indicators:GetCollectionProgress(speciesSet)
    available = tonumber(available) or 0
    collected = tonumber(collected) or 0
    return available > 0 and collected < available, collected, available
end

function MapPetPins:ShowSourceTooltip(owner, data)
    if not owner or not data or not GameTooltip then
        return
    end
    local speciesSet = self:GetSpeciesForNPC(data.npcID)
    if not speciesSet then
        return
    end

    local indicators = ns:GetModule("NPCPetIndicators")
    local collected, available = 0, 0
    if indicators and type(indicators.GetCollectionProgress) == "function" then
        collected, available = indicators:GetCollectionProgress(speciesSet)
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(GetCreatureName(data.npcID), 1.0, 0.82, 0.0)
    GameTooltip:AddLine(string.format("Battle pets collected: %d/%d", collected, available), 0.82, 0.82, 0.82)
    GameTooltip:AddLine(" ")
    for _, entry in ipairs(self:GetTooltipEntries(speciesSet)) do
        if entry.collected > 0 then
            GameTooltip:AddDoubleLine(entry.name, "Collected", 1, 1, 1, 0.35, 1.0, 0.35)
        else
            GameTooltip:AddDoubleLine(entry.name, "Missing", 1, 1, 1, 1.0, 0.82, 0.15)
        end
    end
    if data.canWaypoint and data.mapID and data.x and data.y then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to set waypoint", 0.35, 0.75, 1.0)
    end
    GameTooltip:Show()
end

-- World map

function MapPetPins:TryRegisterWorldMap()
    if self.worldMapRegistered or not WorldMapFrame or not MapCanvasDataProviderMixin or type(CreateFromMixins) ~= "function" then
        return false
    end

    if MapCanvasPinMixin and type(DXPetServicesWorldMapPinMixin) == "table" then
        for key, value in pairs(MapCanvasPinMixin) do
            if DXPetServicesWorldMapPinMixin[key] == nil then
                DXPetServicesWorldMapPinMixin[key] = value
            end
        end
    end

    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.owner = self

    function provider:RefreshAllData()
        local map = self:GetMap()
        if not map then
            return
        end
        map:RemoveAllPinsByTemplate(WORLD_MAP_PIN_TEMPLATE)

        local owner = self.owner
        if not owner or not ns.db or not ns.db.settings or ns.db.settings.worldMapIcons == false then
            return
        end

        local mapID = map:GetMapID()
        local rows = GetLocationRows(mapID)
        if not rows then
            return
        end

        for _, row in ipairs(rows) do
            if owner:HasUncollectedPets(row[1]) then
                map:AcquirePin(WORLD_MAP_PIN_TEMPLATE, {
                    npcID = row[1],
                    mapID = mapID,
                    x = row[2],
                    y = row[3],
                    npcName = GetCreatureName(row[1]),
                    canWaypoint = true,
                })
            end
        end
    end

    self.worldMapProvider = provider
    WorldMapFrame:AddDataProvider(provider)
    self.worldMapRegistered = true
    provider:RefreshAllData()
    return true
end

function MapPetPins:RefreshWorldMap()
    if self.worldMapProvider then
        self.worldMapProvider:RefreshAllData()
    end
end

-- Minimap

function MapPetPins:CreateMinimapPin(index)
    local pin = CreateFrame("Frame", nil, Minimap)
    pin:SetSize(18, 18)
    pin:SetFrameStrata("MEDIUM")
    pin:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 12)
    pin:EnableMouse(true)
    pin:SetMouseClickEnabled(false)
    pin:SetMouseMotionEnabled(true)

    local glow = pin:CreateTexture(nil, "BACKGROUND")
    DisablePixelSnapping(glow)
    glow:SetPoint("CENTER")
    glow:SetSize(21, 21)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(BLUE_R, BLUE_G, BLUE_B, 0.35)

    local texture = pin:CreateTexture(nil, "ARTWORK")
    DisablePixelSnapping(texture)
    texture:SetPoint("CENTER")
    SetPawTexture(texture, 16)
    pin.icon = texture
    pin.index = index

    pin:SetScript("OnEnter", function(frame)
        MapPetPins:ShowSourceTooltip(frame, frame.data)
    end)
    pin:SetScript("OnLeave", function(frame)
        if GameTooltip:IsOwned(frame) then
            GameTooltip:Hide()
        end
    end)
    pin:Hide()
    return pin
end

function MapPetPins:GetMinimapPin(index)
    local pin = self.minimapPins[index]
    if not pin then
        pin = self:CreateMinimapPin(index)
        self.minimapPins[index] = pin
    end
    return pin
end

function MapPetPins:HideMinimapPins()
    for _, pin in ipairs(self.minimapPins) do
        pin.data = nil
        pin:Hide()
    end
end

local MINIMAP_SHAPES = {
    -- { upper-left, lower-left, upper-right, lower-right }
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { true,  false, false, false },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { false, false, false, true },
    ["SIDE-LEFT"]             = { true,  true,  false, false },
    ["SIDE-RIGHT"]            = { false, false, true,  true },
    ["SIDE-TOP"]              = { true,  false, true,  false },
    ["SIDE-BOTTOM"]           = { false, true,  false, true },
    ["TRICORNER-TOPLEFT"]     = { true,  true,  true,  false },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { false, true,  true,  true },
}

local function GetPlayerWorldPosition()
    -- UnitPosition returns north/south first and east/west second. Keep the
    -- same world-coordinate orientation used by HereBeDragons so map nodes
    -- and the live player position share one continuous coordinate system.
    local rawY, rawX, _, instanceID = UnitPosition("player")
    return SafeNumber(rawX), SafeNumber(rawY), SafeNumber(instanceID)
end

local function BuildMinimapWorldTransform(mapID)
    local width, height = GetReliableMapWorldSize(mapID)
    if not width or not height or width <= 10 or height <= 10 then
        return nil
    end

    local instanceID, left, top
    local vector = CreateMapVector(0.5, 0.5)
    if vector then
        local first, second = C_Map.GetWorldPosFromMapPos(mapID, vector)
        local center
        if type(first) == "number" then
            instanceID, center = SafeNumber(first), second
        else
            center, instanceID = first, SafeNumber(second)
        end

        -- Blizzard's map world vector uses the same orientation consumed
        -- by HereBeDragons: first component is top, second is left.
        local centerTop, centerLeft = ReadVectorXY(center)
        if centerTop and centerLeft then
            top = centerTop + (height * 0.5)
            left = centerLeft + (width * 0.5)
        end
    end

    local playerX, playerY, playerInstance = GetPlayerWorldPosition()
    local playerMapX, playerMapY = GetPlayerMapPosition(mapID)

    -- Some scenario/phased maps report a map-space instance which does not
    -- line up with UnitPosition. Calibrate the transform once from the live
    -- player position instead of reverting to timer-based player map deltas.
    if playerX and playerY and playerMapX and playerMapY then
        local needsLiveCalibration = not left or not top or not instanceID or (playerInstance and instanceID ~= playerInstance)
        if not needsLiveCalibration then
            local projectedX = left - (width * playerMapX)
            local projectedY = top - (height * playerMapY)
            local errorDistance = math.sqrt(((projectedX - playerX) ^ 2) + ((projectedY - playerY) ^ 2))
            needsLiveCalibration = errorDistance > math.max(150, math.min(width, height) * 0.03)
        end

        if needsLiveCalibration then
            left = playerX + (width * playerMapX)
            top = playerY + (height * playerMapY)
            instanceID = playerInstance or instanceID
        end
    end

    if not left or not top then
        return nil
    end

    return {
        mapID = mapID,
        width = width,
        height = height,
        left = left,
        top = top,
        instanceID = instanceID,
    }
end

local function IsRoundMinimapQuadrant(shape, xDist, yDist)
    if not shape or xDist == 0 or yDist == 0 then
        return true
    end

    local quadrant = (xDist < 0) and 1 or 3
    if yDist >= 0 then
        quadrant = quadrant + 1
    end
    return shape[quadrant]
end

function MapPetPins:CreateMinimapTicker()
    if self.minimapUpdateFrame then
        return
    end

    local frame = CreateFrame("Frame")
    self.minimapUpdateFrame = frame
    frame:SetScript("OnUpdate", function(_, elapsed)
        self:UpdateMinimapIconPositions()

        self.minimapRefreshElapsed = (self.minimapRefreshElapsed or 0) + elapsed
        if self.minimapRefreshElapsed >= 1 then
            self.minimapRefreshElapsed = 0
            self:UpdateMinimapPins()
        end
    end)
end

function MapPetPins:UpdateMinimapIconPositions()
    if not ns.db or not ns.db.settings or ns.db.settings.worldMapIcons == false or not Minimap or not Minimap:IsShown() then
        return
    end

    local playerX, playerY, playerInstance = GetPlayerWorldPosition()
    if not playerX or not playerY then
        return
    end

    local radius = GetMinimapRadius()
    if not radius or radius <= 0 then
        return
    end

    local halfWidth = math.max(1, (Minimap:GetWidth() or 140) * 0.5)
    local halfHeight = math.max(1, (Minimap:GetHeight() or 140) * 0.5)
    local rotate = self.minimapRotate == true
    local shape
    if GetMinimapShape then
        shape = MINIMAP_SHAPES[GetMinimapShape() or "ROUND"]
    end
    local facing
    local sinA, cosA
    if rotate then
        facing = SafeNumber(GetPlayerFacing())
        if not facing then
            return
        end
        sinA, cosA = math.sin(facing), math.cos(facing)
    end

    for _, pin in ipairs(self.minimapPins) do
        local data = pin.data
        if data and data.worldX and data.worldY and (not data.instanceID or not playerInstance or data.instanceID == playerInstance) then
            local xDist = playerX - data.worldX
            local yDist = playerY - data.worldY

            if rotate then
                local dx, dy = xDist, yDist
                xDist = (dx * cosA) - (dy * sinA)
                yDist = (dx * sinA) + (dy * cosA)
            end

            local diffX = xDist / radius
            local diffY = yDist / radius
            local isRound = IsRoundMinimapQuadrant(shape, xDist, yDist)
            local normalizedDistance
            if isRound then
                normalizedDistance = ((diffX * diffX) + (diffY * diffY)) / (0.9 ^ 2)
            else
                normalizedDistance = math.max(diffX * diffX, diffY * diffY) / (0.9 ^ 2)
            end

            if normalizedDistance <= 1 then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", Minimap, "CENTER", diffX * halfWidth, -diffY * halfHeight)
                pin:Show()
            else
                pin:Hide()
            end
        else
            pin:Hide()
        end
    end
end

function MapPetPins:UpdateMinimapPins()
    if not ns.db or not ns.db.settings or ns.db.settings.worldMapIcons == false or not Minimap or not Minimap:IsShown() then
        self:HideMinimapPins()
        return
    end

    local mapID = GetCurrentMinimapMapID()
    if not mapID then
        self:HideMinimapPins()
        return
    end

    local rows = GetLocationRows(mapID)
    if not rows then
        self:HideMinimapPins()
        return
    end

    if not self.minimapMapTransform or self.minimapMapTransform.mapID ~= mapID then
        self.minimapMapTransform = BuildMinimapWorldTransform(mapID)
    end
    local transform = self.minimapMapTransform
    if not transform then
        self:HideMinimapPins()
        return
    end

    local playerX, playerY, playerInstance = GetPlayerWorldPosition()
    if not playerX or not playerY then
        self:HideMinimapPins()
        return
    end

    self.currentMinimapMapID = mapID
    self.minimapRotate = IsRotateMinimapEnabled()

    local candidates = {}
    for _, row in ipairs(rows) do
        if self:HasUncollectedPets(row[1]) then
            local worldX = transform.left - (transform.width * row[2])
            local worldY = transform.top - (transform.height * row[3])
            local distance = math.sqrt(((playerX - worldX) ^ 2) + ((playerY - worldY) ^ 2))
            candidates[#candidates + 1] = {
                npcID = row[1],
                npcName = GetCreatureName(row[1]),
                mapID = mapID,
                mapX = row[2],
                mapY = row[3],
                worldX = worldX,
                worldY = worldY,
                instanceID = transform.instanceID or playerInstance,
                distance = distance,
            }
        end
    end

    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)

    local shown = math.min(#candidates, MAX_MINIMAP_PINS)
    for index = 1, shown do
        local pin = self:GetMinimapPin(index)
        pin.data = candidates[index]
        if pin:GetParent() ~= Minimap then
            pin:SetParent(Minimap)
        end
    end
    for index = shown + 1, #self.minimapPins do
        local pin = self.minimapPins[index]
        pin.data = nil
        pin:Hide()
    end

    -- Position immediately, then the OnUpdate frame keeps the pins moving at
    -- the same cadence as the minimap instead of waiting for a 0.20s timer.
    self:UpdateMinimapIconPositions()
end

-- Waypoints and settings

function MapPetPins:SetWaypointForLocation(data)
    if not data or not data.mapID or not data.x or not data.y or not C_Map or type(C_Map.SetUserWaypoint) ~= "function" then
        return false
    end

    local point = UiMapPoint.CreateFromCoordinates(data.mapID, data.x, data.y)
    if not point then
        point = { uiMapID = data.mapID, position = CreateMapVector(data.x, data.y) }
    end
    if not point then
        return false
    end

    C_Map.SetUserWaypoint(point)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    self:RefreshWorldMap()
    return true
end

function MapPetPins:IsWaypointLocation(data)
    return IsSameWaypoint(data)
end

function MapPetPins:RefreshSettings()
    self:TryRegisterWorldMap()
    self:RefreshWorldMap()
    self:UpdateMinimapPins()
end

-- The XML template references this global mixin. MapCanvasPinMixin is part of
-- Blizzard's map framework; the plain table fallback keeps addon loading safe
-- if the world map framework has not initialized yet.
if MapCanvasPinMixin and type(CreateFromMixins) == "function" then
    DXPetServicesWorldMapPinMixin = CreateFromMixins(MapCanvasPinMixin)
else
    DXPetServicesWorldMapPinMixin = {}
end

-- Blizzard calls CheckMouseButtonPassthrough after every AcquirePin.
-- The inherited implementation uses the protected SetPassThroughButtons API,
-- which addon-owned pins cannot safely invoke during secure map refreshes.
-- DX pins therefore opt out of runtime pass-through mutation.
function DXPetServicesWorldMapPinMixin:CheckMouseButtonPassthrough(...)
    -- Intentionally empty. Right-clicking directly on this small pin may be
    -- consumed by the pin instead of zooming the map, but avoids taint/blocking.
end

function DXPetServicesWorldMapPinMixin:OnLoad()
    self:SetScalingLimits(1, 1, 1.15)
end

function DXPetServicesWorldMapPinMixin:UpdateWaypointState()
    local selected = MapPetPins:IsWaypointLocation(self.data)
    if self.WaypointIcon then
        if selected then
            SetWaypointMarkerTexture(self.WaypointIcon)
            self.WaypointIcon:Show()
        else
            self.WaypointIcon:Hide()
        end
    end
end

function DXPetServicesWorldMapPinMixin:OnAcquired(data)
    self.data = data
    self:SetPosition(data.x, data.y)
    SetPawTexture(self.Icon, 20)
    self:UpdateWaypointState()
    self:Show()
end

function DXPetServicesWorldMapPinMixin:OnReleased()
    self.data = nil
    if self.WaypointIcon then
        self.WaypointIcon:Hide()
    end
end

function DXPetServicesWorldMapPinMixin:OnMouseEnter()
    MapPetPins:ShowSourceTooltip(self, self.data)
end

function DXPetServicesWorldMapPinMixin:OnMouseLeave()
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

function DXPetServicesWorldMapPinMixin:OnClick(button)
    if button == "LeftButton" and self.data then
        MapPetPins:SetWaypointForLocation(self.data)
        self:UpdateWaypointState()
    end
end

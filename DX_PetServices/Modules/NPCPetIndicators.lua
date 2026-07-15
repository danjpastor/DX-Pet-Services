local addonName, ns = ...

local NPCPetIndicators = {
    overlays = {},
    bossIcons = {},
    fadeDriver = nil,
    stackRefreshTicker = nil,
    sourceCandidates = {},
    sourceNameCache = {},
    speciesNameIndex = {},
    sourceScanComplete = false,
    sourceScanTicker = nil,
    sourceScanIndex = 1,
    sourceScanMax = 7000,
    sourceScanChunk = 80,
    refreshToken = 0,
    collectionRefreshToken = 0,
    recentNPCsByName = {},
    lastRecentNPC = nil,
    activeMerchantNPCID = nil,
    activeMerchantNPCName = nil,
    activeMerchantResolveMethod = nil,
    collectionPollElapsed = 0,
}
ns:RegisterModule("NPCPetIndicators", NPCPetIndicators)

local PAW_ATLAS = "WildBattlePetCapturable"
local VENDOR_SOURCE = _G.BATTLE_PET_SOURCE_3 or "Vendor"
local QUEST_SOURCE = _G.BATTLE_PET_SOURCE_2 or "Quest"
local SOURCE_CACHE_VERSION = 2
local DISTANCE_FADE_NEAR = 5
local DISTANCE_FADE_FAR = 45
local DISTANCE_FADE_RESPONSE = 4.5
local NAMEPLATE_STACK_GAP = 4
local OVERLAY_BG_R, OVERLAY_BG_G, OVERLAY_BG_B, OVERLAY_BG_A = 0.025, 0.025, 0.025, 0.92
local OVERLAY_BORDER_A = 0.95

-- General helpers

local function DebugPrint(...)
    if ns.db and ns.db.settings and ns.db.settings.debug then
        ns:Print("NPC Pet Indicators:", ...)
    end
end

local function IsSecretValue(value)
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

local function SafeString(value)
    if IsSecretValue(value) or type(value) ~= "string" then
        return nil
    end
    return value
end

local function SafeNumber(value)
    if IsSecretValue(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

local function Clamp01(value)
    value = SafeNumber(value) or 0
    if value <= 0 then
        return 0
    end
    if value >= 1 then
        return 1
    end
    return value
end

local function ApplyOverlayVisualAlpha(overlay, alpha)
    if not overlay then
        return
    end

    alpha = Clamp01(alpha)
    overlay.visualAlpha = alpha

    -- The container stays at full alpha for its lifetime. Fade the actual
    -- visible regions directly because nameplate child-frame alpha can behave
    -- like an on/off switch.
    if type(overlay.SetBackdropColor) == "function" then
        overlay:SetBackdropColor(OVERLAY_BG_R, OVERLAY_BG_G, OVERLAY_BG_B, OVERLAY_BG_A * alpha)
    end
    if type(overlay.SetBackdropBorderColor) == "function" then
        overlay:SetBackdropBorderColor(
            overlay.borderR or 0.72,
            overlay.borderG or 0.56,
            overlay.borderB or 0.15,
            OVERLAY_BORDER_A * alpha
        )
    end
    if overlay.icon and type(overlay.icon.SetAlpha) == "function" then
        overlay.icon:SetAlpha(alpha)
    end
    if overlay.text and type(overlay.text.SetAlpha) == "function" then
        overlay.text:SetAlpha(alpha)
    end
end

local function SetOverlayCollectionStyle(overlay, complete)
    if not overlay then
        return
    end

    if complete then
        overlay.borderR, overlay.borderG, overlay.borderB = 0.28, 0.78, 0.28
        if overlay.text then
            overlay.text:SetTextColor(0.35, 1.0, 0.35)
        end
    else
        overlay.borderR, overlay.borderG, overlay.borderB = 0.72, 0.56, 0.15
        if overlay.text then
            overlay.text:SetTextColor(1.0, 0.82, 0.15)
        end
    end

    ApplyOverlayVisualAlpha(overlay, overlay.visualAlpha or 0)
end

local function IsFrameForbidden(frame)
    if not frame or type(frame.IsForbidden) ~= "function" then
        return false
    end
    local ok, forbidden = pcall(frame.IsForbidden, frame)
    return ok and forbidden == true
end

local function IsFrameProtected(frame)
    if not frame or type(frame.IsProtected) ~= "function" then
        return false
    end
    local ok, protected = pcall(frame.IsProtected, frame)
    return ok and protected == true
end

local function SafeGetObjectType(region)
    if not region or type(region.GetObjectType) ~= "function" then
        return nil
    end
    local ok, objectType = pcall(region.GetObjectType, region)
    return ok and SafeString(objectType) or nil
end

local function SafeGetParent(region)
    if not region or type(region.GetParent) ~= "function" then
        return nil
    end
    local ok, parent = pcall(region.GetParent, region)
    return ok and parent or nil
end

local function HasProtectedAncestor(region)
    local current = region
    for _ = 1, 8 do
        if not current then
            return false
        end
        if IsFrameProtected(current) then
            return true
        end
        current = SafeGetParent(current)
    end
    return false
end

local function SafeGetSize(region)
    if not region then
        return nil, nil
    end
    local width, height
    if type(region.GetWidth) == "function" then
        local ok, value = pcall(region.GetWidth, region)
        if ok then
            width = SafeNumber(value)
        end
    end
    if type(region.GetHeight) == "function" then
        local ok, value = pcall(region.GetHeight, region)
        if ok then
            height = SafeNumber(value)
        end
    end
    return width, height
end

local function CapturePoints(region)
    if not region or IsFrameForbidden(region) or type(region.GetNumPoints) ~= "function" or type(region.GetPoint) ~= "function" then
        return nil
    end

    local okCount, pointCount = pcall(region.GetNumPoints, region)
    pointCount = okCount and SafeNumber(pointCount) or nil
    if not pointCount or pointCount < 1 or pointCount > 8 then
        return nil
    end

    local points = {}
    for index = 1, pointCount do
        local ok, point, relativeTo, relativePoint, xOfs, yOfs = pcall(region.GetPoint, region, index)
        if not ok then
            return nil
        end

        point = SafeString(point)
        relativePoint = SafeString(relativePoint) or point
        xOfs = SafeNumber(xOfs)
        yOfs = SafeNumber(yOfs)
        if not point or not relativePoint or xOfs == nil or yOfs == nil then
            return nil
        end

        points[#points + 1] = { point, relativeTo, relativePoint, xOfs, yOfs }
    end
    return #points > 0 and points or nil
end

local function RestorePoints(region, points, yOffset)
    if not region or not points or #points == 0 or IsFrameForbidden(region) or type(region.ClearAllPoints) ~= "function" or type(region.SetPoint) ~= "function" then
        return false
    end

    local ok = pcall(region.ClearAllPoints, region)
    if not ok then
        return false
    end

    for _, point in ipairs(points) do
        local y = point[5] + (yOffset or 0)
        ok = pcall(region.SetPoint, region, point[1], point[2], point[3], point[4], y)
        if not ok then
            return false
        end
    end
    return true
end

local function IsRelatedToNamePlate(region, overlay)
    local current = region
    for _ = 1, 8 do
        if not current then
            return false
        end
        if current == overlay.namePlate or current == overlay.anchor then
            return true
        end
        current = SafeGetParent(current)
    end
    return false
end

local function IsTopDecoration(points, overlay)
    if not points or not overlay then
        return false
    end

    local overlayHeight = SafeNumber(overlay:GetHeight()) or 21
    local maxOffset = overlayHeight + 14
    for _, pointData in ipairs(points) do
        local point = string.upper(pointData[1] or "")
        local relativeTo = pointData[2]
        local relativePoint = string.upper(pointData[3] or "")
        local xOfs = SafeNumber(pointData[4])
        local yOfs = SafeNumber(pointData[5])

        if xOfs and yOfs and math.abs(xOfs) <= 90 and yOfs >= -14 and yOfs <= maxOffset and IsRelatedToNamePlate(relativeTo, overlay) then
            local anchoredFromBottom = point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" or point == "CENTER"
            local anchoredToTop = relativePoint == "TOP" or relativePoint == "TOPLEFT" or relativePoint == "TOPRIGHT" or relativePoint == "CENTER"
            if anchoredFromBottom and anchoredToTop then
                return true
            end
        end
    end
    return false
end

local function StripColors(text)
    text = SafeString(text)
    if not text then
        return nil
    end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function NormalizeLabel(text)
    text = StripColors(text)
    if not text then
        return ""
    end
    return text:lower():gsub("[%s%p]+", "")
end

local function NormalizeName(text)
    text = StripColors(text)
    if not text then
        return nil
    end
    text = text:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end
    return text
end

local function IsWordCharacter(char)
    return char ~= nil and char ~= "" and char:match("[%w]") ~= nil
end

local function SourceTextContainsNPCName(sourceText, npcName)
    sourceText = NormalizeName(sourceText)
    npcName = NormalizeName(npcName)
    if not sourceText or not npcName then
        return false
    end

    local searchFrom = 1
    while true do
        local first, last = sourceText:find(npcName, searchFrom, true)
        if not first then
            return false
        end

        local before = first > 1 and sourceText:sub(first - 1, first - 1) or nil
        local after = last < #sourceText and sourceText:sub(last + 1, last + 1) or nil
        if not IsWordCharacter(before) and not IsWordCharacter(after) then
            return true
        end

        searchFrom = first + 1
    end
end

local function SourceLabelsMatch(a, b)
    a = NormalizeLabel(a)
    b = NormalizeLabel(b)
    if a == "" or b == "" then
        return false
    end
    return a == b or a:find(b, 1, true) == 1 or b:find(a, 1, true) == 1
end

local function GetSourceCategory(sourceText)
    sourceText = StripColors(sourceText)
    if not sourceText then
        return nil
    end

    local mainSource = sourceText:match("^%s*(.-):") or sourceText
    if SourceLabelsMatch(mainSource, VENDOR_SOURCE) then
        return "VENDOR"
    end
    if SourceLabelsMatch(mainSource, QUEST_SOURCE) then
        return "QUEST"
    end
    return nil
end

local function GetUnitReadableGUID(unit)
    if type(UnitGUID) ~= "function" then
        return nil
    end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok then
        return nil
    end
    return SafeString(guid)
end

local function ParseNPCIDFromGUID(guid)
    guid = SafeString(guid)
    if not guid then
        return nil
    end

    -- Only world NPC GUID types are eligible. This prevents player names from
    -- ever reaching the source-text matcher and also rejects pets/companions.
    local guidType = guid:match("^([^-]+)-")
    if guidType ~= "Creature" and guidType ~= "Vehicle" then
        return nil
    end

    -- The NPC ID is the numeric field immediately before the final spawn UID.
    local npcID = guid:match("%-(%d+)%-[0-9A-Fa-f]+$")
    return npcID and tonumber(npcID) or nil
end

local function GetUnitNPCID(unit)
    return ParseNPCIDFromGUID(GetUnitReadableGUID(unit))
end

local function GetReadableBoolean(func, unit)
    if type(func) ~= "function" then
        return nil
    end
    local ok, result = pcall(func, unit)
    if not ok or IsSecretValue(result) or type(result) ~= "boolean" then
        return nil
    end
    return result
end

local function GetUnitReadableName(unit)
    if type(UnitName) ~= "function" then
        return nil
    end
    local ok, name = pcall(UnitName, unit)
    if not ok then
        return nil
    end
    return SafeString(name)
end

local function GetUnitNPCContext(unit)
    local npcID = GetUnitNPCID(unit)
    if not npcID then
        return nil
    end
    return {
        unit = unit,
        npcID = npcID,
        name = GetUnitReadableName(unit),
        guid = GetUnitReadableGUID(unit),
    }
end

local function GetMerchantFrameDisplayName()
    local candidates = {}

    if MerchantFrame then
        candidates[#candidates + 1] = MerchantFrame.TitleText
        candidates[#candidates + 1] = MerchantFrame.TitleContainer and MerchantFrame.TitleContainer.TitleText
        candidates[#candidates + 1] = MerchantFrame.title
    end
    candidates[#candidates + 1] = _G.MerchantFrameTitleText
    candidates[#candidates + 1] = _G.MerchantNameText

    for _, region in ipairs(candidates) do
        if region and type(region.GetText) == "function" then
            local ok, text = pcall(region.GetText, region)
            text = ok and SafeString(text) or nil
            if text and text ~= "" then
                return text
            end
        end
    end

    return nil
end

local function GetMerchantNumItemsSafe()
    if type(GetMerchantNumItems) == "function" then
        local ok, count = pcall(GetMerchantNumItems)
        if ok and tonumber(count) then
            return tonumber(count) or 0
        end
    end

    if C_MerchantFrame and type(C_MerchantFrame.GetNumItems) == "function" then
        local ok, count = pcall(C_MerchantFrame.GetNumItems)
        if ok and tonumber(count) then
            return tonumber(count) or 0
        end
    end

    return 0
end

local function GetMerchantItemLinkSafe(index)
    if type(GetMerchantItemLink) == "function" then
        local ok, link = pcall(GetMerchantItemLink, index)
        if ok and SafeString(link) then
            return link
        end
    end

    if C_MerchantFrame and type(C_MerchantFrame.GetMerchantItemLink) == "function" then
        local ok, link = pcall(C_MerchantFrame.GetMerchantItemLink, index)
        if ok and SafeString(link) then
            return link
        end
    end

    return nil
end

local function GetMerchantItemNameSafe(index)
    if type(GetMerchantItemInfo) == "function" then
        local ok, info = pcall(GetMerchantItemInfo, index)
        if ok then
            if type(info) == "table" then
                return SafeString(info.name)
            end
            if SafeString(info) then
                return info
            end
        end
    end

    if C_MerchantFrame and type(C_MerchantFrame.GetMerchantItemInfo) == "function" then
        local ok, info = pcall(C_MerchantFrame.GetMerchantItemInfo, index)
        if ok then
            if type(info) == "table" then
                return SafeString(info.name)
            end
            if SafeString(info) then
                return info
            end
        end
    end

    return nil
end

local function GetMerchantItemIDSafe(index)
    -- Some 12.x merchant rows expose neither a readable name nor hyperlink,
    -- especially inside scenario-style content, while the numeric merchant
    -- item ID is still available. Resolve that ID directly before falling
    -- back to any text-based matching.
    if type(GetMerchantItemID) == "function" then
        local ok, itemID = pcall(GetMerchantItemID, index)
        if ok and not IsSecretValue(itemID) then
            itemID = tonumber(itemID)
            if itemID and itemID > 0 then
                return itemID, "GetMerchantItemID"
            end
        end
    end

    -- Future-proof against clients exposing an item ID on the structured
    -- MerchantItemInfo record. This costs no additional item-data requests.
    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok and type(info) == "table" then
            local itemID = info.itemID or info.itemId
            if not IsSecretValue(itemID) then
                itemID = tonumber(itemID)
                if itemID and itemID > 0 then
                    return itemID, "C_MerchantFrame.GetItemInfo"
                end
            end
        end
    end

    return nil, nil
end

local function ExtractItemID(link)
    link = SafeString(link)
    if not link then
        return nil
    end
    local itemID = link:match("item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

local function ExtractBattlePetSpeciesID(link)
    link = SafeString(link)
    if not link then
        return nil
    end

    -- Merchant entries for learnable companion pets can be exposed as native
    -- battle-pet hyperlinks instead of ordinary item links. In that case the
    -- first numeric field is already the Pet Journal species ID.
    local speciesID = link:match("battlepet:(%d+)")
    speciesID = speciesID and tonumber(speciesID) or nil
    return speciesID and speciesID > 0 and speciesID or nil
end

local function GetSpeciesIDFromItem(itemID)
    if not itemID or not C_PetJournal or type(C_PetJournal.GetPetInfoByItemID) ~= "function" then
        return nil
    end

    -- The legacy/mainline API returns full pet-species information here, with
    -- speciesID as the 13th return value. Some client/API shapes may instead
    -- return a direct numeric species ID or a structured table, so support all
    -- three forms without requesting any additional item data.
    local ok,
        firstResult,
        icon,
        petType,
        creatureID,
        sourceText,
        description,
        isWild,
        canBattle,
        tradeable,
        unique,
        obtainable,
        displayID,
        speciesID = pcall(C_PetJournal.GetPetInfoByItemID, itemID)

    if not ok or firstResult == nil then
        return nil
    end

    if type(firstResult) == "table" then
        return tonumber(firstResult.speciesID or firstResult.speciesId)
    end

    local directSpeciesID = tonumber(firstResult)
    if directSpeciesID and directSpeciesID > 0 then
        return directSpeciesID
    end

    speciesID = tonumber(speciesID)
    return speciesID and speciesID > 0 and speciesID or nil
end

local function GetSpeciesIDFromLink(link)
    local speciesID = ExtractBattlePetSpeciesID(link)
    if speciesID then
        return speciesID
    end
    return GetSpeciesIDFromItem(ExtractItemID(link))
end

local function AddSpeciesToSet(set, speciesID)
    speciesID = tonumber(speciesID)
    if not speciesID or speciesID <= 0 then
        return false
    end
    if set[speciesID] then
        return false
    end
    set[speciesID] = true
    return true
end

-- Lifecycle and source indexing

function NPCPetIndicators:OnInitialize()
    ns.Events:Register("NAME_PLATE_UNIT_ADDED", self, "OnNamePlateUnitAdded")
    ns.Events:Register("NAME_PLATE_UNIT_REMOVED", self, "OnNamePlateUnitRemoved")
    ns.Events:Register("PET_JOURNAL_LIST_UPDATE", self, "OnCollectionChanged")
    ns.Events:Register("NEW_PET_ADDED", self, "OnCollectionChanged")
    ns.Events:Register("PET_JOURNAL_PET_DELETED", self, "OnCollectionChanged")
    ns.Events:Register("BAG_UPDATE_DELAYED", self, "OnCollectionInventoryChanged")
    ns.Events:Register("COMPANION_UPDATE", self, "OnCollectionChanged")
    ns.Events:Register("MERCHANT_SHOW", self, "OnMerchantShown")
    ns.Events:Register("MERCHANT_UPDATE", self, "OnMerchantUpdated")
    ns.Events:Register("MERCHANT_CLOSED", self, "OnMerchantClosed")
    ns.Events:Register("UPDATE_MOUSEOVER_UNIT", self, "OnInteractionUnitChanged")
    ns.Events:Register("PLAYER_TARGET_CHANGED", self, "OnInteractionUnitChanged")
    ns.Events:Register("QUEST_COMPLETE", self, "OnQuestComplete")
    ns.Events:Register("PLAYER_REGEN_DISABLED", self, "OnCombatStateChanged")
    ns.Events:Register("PLAYER_REGEN_ENABLED", self, "OnCombatStateChanged")
    ns.Events:Register("UNIT_FLAGS", self, "OnUnitFlagsChanged")

    -- Older caches may contain heuristic matches. Reset them once, then keep
    -- only mappings learned from merchant and quest-reward interactions.
    if type(ns.db.npcPetSources) ~= "table" or ns.db.npcPetSourceCacheVersion ~= SOURCE_CACHE_VERSION then
        ns.db.npcPetSources = {}
        ns.db.npcPetSourceCacheVersion = SOURCE_CACHE_VERSION
    end
end

function NPCPetIndicators:OnEnable()
    -- Drive opacity every rendered frame. The previous 0.05-second ticker could
    -- visibly step even when the distance source itself was continuous.
    if not self.fadeDriver then
        self.fadeDriver = CreateFrame("Frame")
        self.fadeDriver:SetScript("OnUpdate", function(_, elapsed)
            if not ns.enabled then
                return
            end
            self:UpdateDistanceFades(elapsed or 0)
            self.collectionPollElapsed = (self.collectionPollElapsed or 0) + (elapsed or 0)
            if self.collectionPollElapsed >= 0.50 then
                self.collectionPollElapsed = 0
                self:UpdateVisibleCollectionProgress()
            end
        end)
    end

    if not self.stackRefreshTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
        self.stackRefreshTicker = C_Timer.NewTicker(0.75, function()
            self:RefreshVisibleDecorationStacks()
        end)
    end

    C_Timer.After(1.5, function()
        if ns.enabled then
            self:StartSourceScan()
            self:RefreshAllNameplates()
        end
    end)
end

function NPCPetIndicators:StartSourceScan()
    if self.sourceScanComplete or self.sourceScanTicker then
        return
    end

    self.sourceScanIndex = 1
    self.sourceScanTicker = C_Timer.NewTicker(0.03, function()
        self:ProcessSourceScanChunk()
    end)
end

function NPCPetIndicators:ProcessSourceScanChunk()
    local firstID = self.sourceScanIndex
    local lastID = math.min(firstID + self.sourceScanChunk - 1, self.sourceScanMax)

    for speciesID = firstID, lastID do
        local ok, name, icon, petType, companionID, sourceText, description, isWild, canBattle,
            isTradeable, isUnique, obtainable = pcall(C_PetJournal.GetPetInfoBySpeciesID, speciesID)

        if ok and name and obtainable ~= false then
            local normalizedName = NormalizeName(name)
            if normalizedName then
                local indexed = self.speciesNameIndex[normalizedName]
                if not indexed then
                    indexed = {}
                    self.speciesNameIndex[normalizedName] = indexed
                end
                indexed[speciesID] = true
            end
        end

        if ok and name and obtainable ~= false and sourceText then
            local category = GetSourceCategory(sourceText)
            if category == "VENDOR" or category == "QUEST" then
                local cleaned = StripColors(sourceText)
                if cleaned then
                    self.sourceCandidates[#self.sourceCandidates + 1] = {
                        speciesID = speciesID,
                        category = category,
                        sourceLower = cleaned:lower(),
                    }
                end
            end
        end
    end

    self.sourceScanIndex = lastID + 1
    if self.sourceScanIndex > self.sourceScanMax then
        if self.sourceScanTicker then
            self.sourceScanTicker:Cancel()
            self.sourceScanTicker = nil
        end
        self.sourceScanComplete = true
        self:RefreshAllNameplates()
    end
end

-- NPC context and source resolution

function NPCPetIndicators:RememberNPCName(npcID, npcName)
    npcID = tonumber(npcID)
    npcName = SafeString(npcName)
    if not npcID or not npcName or npcName == "" or not ns.db then
        return false
    end
    if type(ns.db.npcNames) ~= "table" then
        ns.db.npcNames = {}
    end
    if ns.db.npcNames[npcID] == npcName then
        return false
    end
    ns.db.npcNames[npcID] = npcName
    ns.db.npcNames[tostring(npcID)] = nil
    return true
end

function NPCPetIndicators:GetKnownNPCName(npcID)
    npcID = tonumber(npcID)
    local names = ns.db and ns.db.npcNames
    local name = names and npcID and (names[npcID] or names[tostring(npcID)]) or nil
    return SafeString(name)
end

function NPCPetIndicators:RememberRecentNPC(unit, reason)
    unit = SafeString(unit)
    if not unit then
        return nil
    end

    local context = GetUnitNPCContext(unit)
    if not context or not context.name then
        return nil
    end

    local normalized = NormalizeName(context.name)
    if not normalized then
        return nil
    end

    self:RememberNPCName(context.npcID, context.name)
    context.normalizedName = normalized
    context.seenAt = type(GetTime) == "function" and GetTime() or 0
    context.reason = reason or unit
    self.recentNPCsByName[normalized] = context
    if reason ~= "nameplate" then
        self.lastRecentNPC = context
    end
    return context
end

function NPCPetIndicators:GetRecentNPCByName(name, maxAge)
    local normalized = NormalizeName(name)
    if not normalized then
        return nil
    end

    local context = self.recentNPCsByName[normalized]
    if not context then
        return nil
    end

    local now = type(GetTime) == "function" and GetTime() or context.seenAt or 0
    if maxAge and context.seenAt and (now - context.seenAt) > maxAge then
        return nil
    end

    return context
end

function NPCPetIndicators:FindActiveNPCByName(name)
    local normalized = NormalizeName(name)
    if not normalized or not C_NamePlate or type(C_NamePlate.GetNamePlates) ~= "function" then
        return nil
    end

    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then
        return nil
    end

    local match
    for _, plate in ipairs(plates) do
        local unit = plate and (SafeString(plate.namePlateUnitToken) or SafeString(plate.unit)) or nil
        if not unit and plate and type(plate.GetUnit) == "function" then
            local unitOK, plateUnit = pcall(plate.GetUnit, plate)
            if unitOK then
                unit = SafeString(plateUnit)
            end
        end

        if unit then
            local unitName = GetUnitReadableName(unit)
            if unitName and NormalizeName(unitName) == normalized then
                local context = GetUnitNPCContext(unit)
                if context then
                    if match and match.npcID ~= context.npcID then
                        return nil
                    end
                    match = context
                end
            end
        end
    end

    return match
end

function NPCPetIndicators:ResolveMerchantContext()
    local merchantName = GetMerchantFrameDisplayName()
    local normalizedMerchantName = NormalizeName(merchantName)

    -- The dedicated npc token is authoritative when the client exposes it.
    local npcContext = GetUnitNPCContext("npc")
    if npcContext then
        self:RememberRecentNPC("npc", "merchant-npc")
        return npcContext, "npc"
    end

    -- Mouseover/target can refer to unrelated units. When the merchant frame
    -- exposes a title, only accept an exact name match.
    for _, unit in ipairs({ "mouseover", "target" }) do
        local context = GetUnitNPCContext(unit)
        if context and (not normalizedMerchantName or NormalizeName(context.name) == normalizedMerchantName) then
            self:RememberRecentNPC(unit, "merchant-" .. unit)
            return context, unit
        end
    end

    if merchantName then
        local active = self:FindActiveNPCByName(merchantName)
        if active then
            return active, "nameplate-title"
        end

        local recent = self:GetRecentNPCByName(merchantName, 30)
        if recent then
            return recent, "recent-title"
        end
    end

    local recent = self.lastRecentNPC
    if recent then
        local now = type(GetTime) == "function" and GetTime() or recent.seenAt or 0
        if recent.seenAt and (now - recent.seenAt) <= 3.0 then
            return recent, "recent-interaction"
        end
    end

    return nil, "unresolved"
end

function NPCPetIndicators:BindMerchantContext()
    local context, method = self:ResolveMerchantContext()
    self.activeMerchantNPCID = context and context.npcID or nil
    self.activeMerchantNPCName = context and context.name or GetMerchantFrameDisplayName()
    self.activeMerchantResolveMethod = method
    if self.activeMerchantNPCID and self.activeMerchantNPCName then
        self:RememberNPCName(self.activeMerchantNPCID, self.activeMerchantNPCName)
    end

    DebugPrint(string.format(
        "merchant context: name=%s npcID=%s via=%s",
        tostring(self.activeMerchantNPCName),
        tostring(self.activeMerchantNPCID),
        tostring(method)
    ))

    return self.activeMerchantNPCID
end

function NPCPetIndicators:OnInteractionUnitChanged(event)
    if event == "UPDATE_MOUSEOVER_UNIT" then
        self:RememberRecentNPC("mouseover", "mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:RememberRecentNPC("target", "target")
    end
end

function NPCPetIndicators:GetStaticSpecies(npcID)
    npcID = tonumber(npcID)
    local db = ns.ATTPetSourceDB
    local npcSpecies = db and db.npcSpecies
    if not npcID or type(npcSpecies) ~= "table" then
        return nil
    end

    local species = npcSpecies[npcID]
    return type(species) == "table" and species or nil
end

function NPCPetIndicators:GetLearnedSpecies(npcID)
    if not npcID then
        return nil
    end
    local saved = ns.db.npcPetSources[npcID]
    if type(saved) ~= "table" then
        saved = ns.db.npcPetSources[tostring(npcID)]
    end
    return type(saved) == "table" and saved or nil
end

function NPCPetIndicators:RememberNPCSpecies(npcID, speciesID)
    npcID = tonumber(npcID)
    speciesID = tonumber(speciesID)
    if not npcID or not speciesID then
        return false
    end

    local saved = ns.db.npcPetSources[npcID]
    if type(saved) ~= "table" then
        saved = {}
        ns.db.npcPetSources[npcID] = saved
        ns.db.npcPetSources[tostring(npcID)] = nil
    end

    if saved[speciesID] then
        return false
    end

    saved[speciesID] = true
    return true
end

function NPCPetIndicators:GetSourceMatchedSpecies(npcName)
    local normalized = NormalizeName(npcName)
    if not normalized or #normalized < 3 then
        return nil
    end

    local cached = self.sourceNameCache[normalized]
    if cached ~= nil then
        return cached or nil
    end

    local species = {}
    for _, candidate in ipairs(self.sourceCandidates) do
        -- Match the NPC name as a complete word/phrase, never as a raw
        -- substring. A short NPC name such as "Thor" must not match unrelated
        -- source text containing a longer word or name that happens to include
        -- those letters.
        if SourceTextContainsNPCName(candidate.sourceLower, normalized) then
            species[candidate.speciesID] = true
        end
    end

    if next(species) then
        self.sourceNameCache[normalized] = species
        return species
    end

    if self.sourceScanComplete then
        self.sourceNameCache[normalized] = false
    end
    return nil
end

function NPCPetIndicators:GetSpeciesForNPC(npcID, npcName)
    local result = {}
    local hasAuthoritativeSource = false

    -- Shipped ATT-derived mappings are the primary source. They are keyed by
    -- the actual NPC ID, so phased/scenario variants such as Kifaan in Val and
    -- Naigtal can display immediately without opening the merchant first.
    local static = self:GetStaticSpecies(npcID)
    if static and #static > 0 then
        hasAuthoritativeSource = true
        for _, speciesID in ipairs(static) do
            AddSpeciesToSet(result, speciesID)
        end
    end

    -- Live merchant/quest learning remains an additive fallback. This lets the
    -- addon discover brand-new or incomplete ATT entries and preserve them
    -- account-wide without modifying the shipped static database.
    local learned = self:GetLearnedSpecies(npcID)
    if learned and next(learned) then
        hasAuthoritativeSource = true
        for speciesID, enabled in pairs(learned) do
            if enabled == true then
                AddSpeciesToSet(result, speciesID)
            end
        end
    end

    -- Pet Journal source-text matching is deliberately last-resort only. Once
    -- an NPC has an exact static or learned mapping, heuristic name matching is
    -- not allowed to add unrelated pets to that NPC.
    if not hasAuthoritativeSource then
        local matched = self:GetSourceMatchedSpecies(npcName)
        if matched then
            for speciesID in pairs(matched) do
                AddSpeciesToSet(result, speciesID)
            end
        end
    end

    return next(result) and result or nil
end

function NPCPetIndicators:GetCollectionProgress(speciesSet)
    local collected = 0
    local available = 0

    for speciesID in pairs(speciesSet or {}) do
        available = available + 1
        local ok, numCollected = pcall(C_PetJournal.GetNumCollectedInfo, speciesID)
        if ok and tonumber(numCollected) and numCollected > 0 then
            collected = collected + 1
        end
    end

    return collected, available
end

function NPCPetIndicators:GetBossSpecies(npcID)
    npcID = tonumber(npcID)
    local db = ns.ATTPetWorldDB
    local bossSpecies = db and db.bossSpecies
    local species = npcID and bossSpecies and bossSpecies[npcID]
    if type(species) ~= "table" or #species == 0 then
        return nil
    end

    local result = {}
    for _, speciesID in ipairs(species) do
        AddSpeciesToSet(result, speciesID)
    end
    return next(result) and result or nil
end

local mapWorldSizeCache = {}

-- Distance fading

local function GetPlayerMapXY(mapID)
    mapID = SafeNumber(mapID)
    if not mapID or not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then
        return nil, nil
    end

    local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not position then
        return nil, nil
    end

    if type(position.GetXY) == "function" then
        local xyOK, x, y = pcall(position.GetXY, position)
        if xyOK then
            return SafeNumber(x), SafeNumber(y)
        end
    end

    return SafeNumber(position.x), SafeNumber(position.y)
end

local function GetReliableMapWorldSizeForFade(mapID)
    mapID = SafeNumber(mapID)
    if not mapID then
        return nil, nil
    end

    local cached = mapWorldSizeCache[mapID]
    if cached then
        return cached[1], cached[2]
    end

    if C_Map and type(C_Map.GetMapWorldSize) == "function" then
        local ok, width, height = pcall(C_Map.GetMapWorldSize, mapID)
        width = ok and SafeNumber(width) or nil
        height = ok and SafeNumber(height) or nil
        if width and height and width > 10 and height > 10 then
            mapWorldSizeCache[mapID] = { width, height }
            return width, height
        end
    end

    -- No reliable yard scale is required here. Known ATT sources fall back to
    -- their continuously changing normalized map-coordinate distance.
    return nil, nil
end

local function GetPlayerMapSearchIDs()
    local results, seen = {}, {}
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then
        return results
    end

    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = ok and SafeNumber(mapID) or nil
    for _ = 1, 6 do
        if not mapID or seen[mapID] then
            break
        end
        seen[mapID] = true
        results[#results + 1] = mapID

        if type(C_Map.GetMapInfo) ~= "function" then
            break
        end
        local infoOK, info = pcall(C_Map.GetMapInfo, mapID)
        mapID = infoOK and type(info) == "table" and SafeNumber(info.parentMapID) or nil
    end

    return results
end

function NPCPetIndicators:BuildFadeMapContext()
    local context = {}
    for _, mapID in ipairs(GetPlayerMapSearchIDs()) do
        local playerX, playerY = GetPlayerMapXY(mapID)
        if playerX and playerY then
            local width, height = GetReliableMapWorldSizeForFade(mapID)
            context[#context + 1] = {
                mapID = mapID,
                playerX = playerX,
                playerY = playerY,
                width = width,
                height = height,
            }
        end
    end
    return context
end

function NPCPetIndicators:GetMappedSourceFadeData(npcID, mapContext)
    npcID = tonumber(npcID)
    local worldDB = ns.ATTPetWorldDB
    local locationsByMap = worldDB and worldDB.locationsByMap
    if not npcID or type(locationsByMap) ~= "table" then
        return nil
    end

    -- Search the player's current map first, then parents. Return the nearest
    -- matching coordinate on the first map layer that actually contains this
    -- NPC. This avoids comparing normalized distances from unrelated map scales.
    for _, mapData in ipairs(mapContext or {}) do
        local rows = locationsByMap[mapData.mapID]
        local best
        if type(rows) == "table" then
            for _, row in ipairs(rows) do
                if tonumber(row[1]) == npcID then
                    local sourceX, sourceY = SafeNumber(row[2]), SafeNumber(row[3])
                    if sourceX and sourceY then
                        local dx = sourceX - mapData.playerX
                        local dy = sourceY - mapData.playerY
                        local normalizedDistance = math.sqrt((dx * dx) + (dy * dy))
                        if not best or normalizedDistance < best.normalizedDistance then
                            local yardDistance
                            if mapData.width and mapData.height then
                                local yardX = dx * mapData.width
                                local yardY = dy * mapData.height
                                yardDistance = math.sqrt((yardX * yardX) + (yardY * yardY))
                            end
                            best = {
                                mapID = mapData.mapID,
                                normalizedDistance = normalizedDistance,
                                yardDistance = yardDistance,
                            }
                        end
                    end
                end
            end
        end
        if best then
            return best
        end
    end

    return nil
end

function NPCPetIndicators:GetUnitDistance(unit)
    unit = SafeString(unit)
    if not unit then
        return nil
    end

    if type(UnitDistanceSquared) == "function" then
        local ok, distanceSquared = pcall(UnitDistanceSquared, unit)
        distanceSquared = ok and SafeNumber(distanceSquared) or nil
        if distanceSquared and distanceSquared >= 0 then
            return math.sqrt(distanceSquared)
        end
    end

    if type(UnitPosition) == "function" then
        local okPlayer, px, py, pz, pInstance = pcall(UnitPosition, "player")
        local okUnit, ux, uy, uz, uInstance = pcall(UnitPosition, unit)
        px, py, pInstance = okPlayer and SafeNumber(px) or nil, okPlayer and SafeNumber(py) or nil, okPlayer and SafeNumber(pInstance) or nil
        ux, uy, uInstance = okUnit and SafeNumber(ux) or nil, okUnit and SafeNumber(uy) or nil, okUnit and SafeNumber(uInstance) or nil
        if px and py and ux and uy and (not pInstance or not uInstance or pInstance == uInstance) then
            local dx, dy = ux - px, uy - py
            return math.sqrt((dx * dx) + (dy * dy))
        end
    end

    return nil
end

local function GetInteractionFadeSeed()
    -- CheckInteractDistance is protected in current WoW clients when queried
    -- from the recurring nameplate fade update. Calling it through pcall still
    -- produces ADDON BLOCKED, so do not touch that API from addon code.
    return nil
end

function NPCPetIndicators:GetDistanceFadeTarget(unit, npcID, overlay, mapContext)
    -- Prefer the stable ATT/source coordinate for known NPCs. In current WoW
    -- clients, nameplate unit distance APIs can return nil, secret values, or
    -- implausible zero-like results for distant units. Those bad readings were
    -- winning before the map path and forcing the badge to full opacity.
    local mapped = npcID and self:GetMappedSourceFadeData(npcID, mapContext) or nil
    if mapped then
        if mapped.yardDistance then
            local t = (DISTANCE_FADE_FAR - mapped.yardDistance) / (DISTANCE_FADE_FAR - DISTANCE_FADE_NEAR)
            return math.max(0, math.min(1, t)), "map-yards", mapped.yardDistance
        end

        -- Scenario and modern sub-zone maps often withhold their world size.
        -- The normalized coordinate delta still changes continuously as the
        -- player moves, so calibrate it against the farthest value observed
        -- while this nameplate is active.
        local metric = mapped.normalizedDistance
        if overlay and metric then
            if overlay.fadeMapID ~= mapped.mapID or overlay.fadeNPCID ~= npcID then
                overlay.fadeMapID = mapped.mapID
                overlay.fadeNPCID = npcID
                overlay.fadeOuterMetric = nil
            end

            local seed = GetInteractionFadeSeed(unit)
            local seededOuter = metric
            if seed and seed >= 0.95 then
                seededOuter = metric * 5
            elseif seed and seed >= 0.40 then
                seededOuter = metric * 2
            end

            overlay.fadeOuterMetric = math.max(overlay.fadeOuterMetric or 0, seededOuter, metric)
            local outer = overlay.fadeOuterMetric

            if metric <= 0.0005 then
                return 1, "map-normalized", metric
            end
            if outer and outer > 0.00001 then
                local nearMetric = outer * 0.08
                local t = (outer - metric) / math.max(0.000001, outer - nearMetric)
                return math.max(0, math.min(1, t)), "map-normalized", metric
            end
        end
    end

    -- Use direct unit distance only after the authoritative source-coordinate
    -- path. Reject a zero/near-zero result unless the unit is actually close
    -- enough to interact; this guards against restricted nameplate APIs that
    -- return an unusable zero-like value.
    local distance = self:GetUnitDistance(unit)
    if distance then
        local believable = distance > 1
        if not believable then
            local seed = GetInteractionFadeSeed(unit)
            believable = seed and seed >= 0.95
        end
        if believable then
            local t = (DISTANCE_FADE_FAR - distance) / (DISTANCE_FADE_FAR - DISTANCE_FADE_NEAR)
            return math.max(0, math.min(1, t)), "unit", distance
        end
    end

    -- Last resort for live-learned sources with no static coordinate.
    local seed = GetInteractionFadeSeed(unit) or 0
    return seed, "interaction", seed
end

function NPCPetIndicators:UpdateDistanceFades(elapsed)
    local enabled = ns.db and ns.db.settings and ns.db.settings.npcPetDisplays ~= false
    -- Frame-rate independent exponential smoothing prevents visible stepping
    -- when the distance source updates in uneven intervals.
    local blend = 1 - math.exp(-math.max(0, elapsed or 0.016) * DISTANCE_FADE_RESPONSE)
    local mapContext = self:BuildFadeMapContext()

    for _, overlay in pairs(self.overlays) do
        if overlay and overlay.fadeActive and overlay.unit and enabled then
            local target, source, metric = self:GetDistanceFadeTarget(overlay.unit, overlay.npcID, overlay, mapContext)
            local current = SafeNumber(overlay.visualAlpha) or 0
            local alpha = current + ((target - current) * blend)
            if math.abs(alpha - target) < 0.01 then
                alpha = target
            end
            overlay.fadeTarget = target
            overlay.fadeSource = source
            overlay.fadeMetric = metric
            ApplyOverlayVisualAlpha(overlay, alpha)
            if type(overlay.SetMouseMotionEnabled) == "function" then
                overlay:SetMouseMotionEnabled(alpha > 0.08)
            end
            if alpha <= 0.02 and not overlay.stackSuppressed then
                self:RestoreShiftedDecorations(overlay)
                overlay.stackSuppressed = true
            elseif alpha > 0.08 and overlay.stackSuppressed then
                overlay.stackSuppressed = false
                self:ScheduleDecorationStack(overlay)
            end
        elseif overlay and overlay:IsShown() and not enabled then
            ApplyOverlayVisualAlpha(overlay, 0)
        end
    end
end

function NPCPetIndicators:UpdateVisibleCollectionProgress()
    if not ns.db or not ns.db.settings or ns.db.settings.npcPetDisplays == false then
        return
    end

    for _, overlay in pairs(self.overlays) do
        if overlay and overlay.fadeActive and overlay:IsShown() and overlay.speciesSet then
            local collected, available = self:GetCollectionProgress(overlay.speciesSet)
            if collected ~= overlay.collected or available ~= overlay.available then
                overlay.collected = collected
                overlay.available = available
                overlay.text:SetText(string.format("%d/%d", collected, available))

                local textWidth = overlay.text:GetStringWidth() or 22
                overlay:SetWidth(math.max(46, 5 + 15 + 3 + textWidth + 6))
                SetOverlayCollectionStyle(overlay, collected >= available)

                if GameTooltip and type(GameTooltip.IsOwned) == "function" and GameTooltip:IsOwned(overlay) then
                    self:ShowOverlayTooltip(overlay)
                end
            end
        end
    end
end

-- Nameplate layout

function NPCPetIndicators:RestoreShiftedDecorations(overlay)
    if not overlay or type(overlay.shiftedDecorations) ~= "table" then
        return true
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        -- Never re-anchor another addon's or Blizzard's decoration during
        -- combat. Keep the captured points and restore them on combat exit.
        return false
    end

    for _, entry in ipairs(overlay.shiftedDecorations) do
        if entry.region and entry.points and not IsFrameForbidden(entry.region) then
            pcall(RestorePoints, entry.region, entry.points, 0)
        end
    end
    wipe(overlay.shiftedDecorations)
    return true
end

function NPCPetIndicators:IsDecorationCandidate(frame, overlay, anchor)
    if not frame or frame == overlay or frame == anchor or frame == overlay.namePlate then
        return false
    end
    if frame == self.bossIcons[overlay.namePlate] or IsFrameForbidden(frame) then
        return false
    end

    if type(frame.IsShown) == "function" then
        local ok, shown = pcall(frame.IsShown, frame)
        if not ok or shown == false then
            return false
        end
    end

    local width, height = SafeGetSize(frame)
    if not width or not height or width < 6 or height < 6 or width > 72 or height > 72 then
        return false
    end

    local objectType = SafeGetObjectType(frame)
    if objectType == "Texture" then
        return true
    end

    if type(frame.GetRegions) ~= "function" then
        return false
    end
    local ok, regions = pcall(function()
        return { frame:GetRegions() }
    end)
    if not ok or type(regions) ~= "table" then
        return false
    end
    for _, region in ipairs(regions) do
        if SafeGetObjectType(region) == "Texture" then
            return true
        end
    end
    return false
end

function NPCPetIndicators:GetDecorationCandidates(overlay)
    local candidates, seen = {}, {}
    local function addCandidate(candidate)
        if candidate and not seen[candidate] then
            seen[candidate] = true
            candidates[#candidates + 1] = candidate
        end
    end

    local function addChildren(parent)
        if not parent or type(parent.GetChildren) ~= "function" then
            return
        end
        local ok, children = pcall(function()
            return { parent:GetChildren() }
        end)
        if not ok or type(children) ~= "table" then
            return
        end
        for _, child in ipairs(children) do
            if child and not seen[child] and self:IsDecorationCandidate(child, overlay, overlay.anchor) then
                addCandidate(child)
            end
        end
    end

    local function addTextureRegions(parent)
        if not parent or type(parent.GetRegions) ~= "function" then
            return
        end
        local ok, regions = pcall(function()
            return { parent:GetRegions() }
        end)
        if not ok or type(regions) ~= "table" then
            return
        end
        for _, region in ipairs(regions) do
            if region and not seen[region] and self:IsDecorationCandidate(region, overlay, overlay.anchor) then
                addCandidate(region)
            end
        end
    end

    addChildren(overlay.namePlate)
    addChildren(overlay.anchor)
    addTextureRegions(overlay.namePlate)
    addTextureRegions(overlay.anchor)
    return candidates
end

function NPCPetIndicators:StackNameplateDecorations(overlay)
    if not overlay or not overlay:IsShown() or not overlay.namePlate or not overlay.anchor then
        return
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return
    end

    overlay.stackSuppressed = false
    self:RestoreShiftedDecorations(overlay)

    local overlayHeight = SafeNumber(overlay:GetHeight()) or 21
    local movable = {}
    local immovableOffset = 0

    for _, region in ipairs(self:GetDecorationCandidates(overlay)) do
        local points = CapturePoints(region)
        if points and IsTopDecoration(points, overlay) then
            local objectType = SafeGetObjectType(region)
            local parent = SafeGetParent(region)
            local _, height = SafeGetSize(region)
            height = height or 20

            -- Raw Blizzard textures and protected frames are never re-anchored.
            -- Reserve space for them by moving only our own badge upward.
            if objectType == "Texture" or HasProtectedAncestor(region) or IsFrameProtected(parent) then
                immovableOffset = math.max(immovableOffset, height + NAMEPLATE_STACK_GAP)
            else
                movable[#movable + 1] = {
                    region = region,
                    points = points,
                }
            end
        end
    end

    overlay:ClearAllPoints()
    overlay:SetPoint("BOTTOM", overlay.anchor, "TOP", 0, 5 + immovableOffset)

    local shift = overlayHeight + NAMEPLATE_STACK_GAP + immovableOffset
    for _, entry in ipairs(movable) do
        if RestorePoints(entry.region, entry.points, shift) then
            overlay.shiftedDecorations[#overlay.shiftedDecorations + 1] = entry
        end
    end
end

function NPCPetIndicators:ScheduleDecorationStack(overlay)
    if not overlay or not C_Timer or type(C_Timer.After) ~= "function" then
        return
    end
    C_Timer.After(0, function()
        if overlay.fadeActive and overlay:IsShown() then
            self:StackNameplateDecorations(overlay)
        end
    end)
end

function NPCPetIndicators:RefreshVisibleDecorationStacks()
    if not ns.db or not ns.db.settings or ns.db.settings.npcPetDisplays == false then
        return
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return
    end
    for _, overlay in pairs(self.overlays) do
        if overlay and overlay.fadeActive and overlay:IsShown() and (SafeNumber(overlay.visualAlpha) or 0) > 0.05 then
            self:StackNameplateDecorations(overlay)
        end
    end
end

-- Nameplate frames and tooltips

function NPCPetIndicators:CreateOverlay(namePlate)
    if not namePlate or (type(namePlate.IsForbidden) == "function" and namePlate:IsForbidden()) then
        return nil
    end

    local overlay = CreateFrame("Frame", nil, namePlate, "BackdropTemplate")
    overlay:SetSize(48, 21)
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 9,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    overlay.borderR, overlay.borderG, overlay.borderB = 0.72, 0.56, 0.15
    overlay:SetBackdropColor(OVERLAY_BG_R, OVERLAY_BG_G, OVERLAY_BG_B, 0)
    overlay:SetBackdropBorderColor(overlay.borderR, overlay.borderG, overlay.borderB, 0)
    overlay:SetFrameStrata(namePlate:GetFrameStrata())
    overlay:SetFrameLevel((namePlate:GetFrameLevel() or 0) + 30)

    -- Hover needs mouse-motion events, but the badge should not steal clicks
    -- from the underlying nameplate.
    overlay:EnableMouse(true)
    if type(overlay.SetMouseClickEnabled) == "function" then
        overlay:SetMouseClickEnabled(false)
    end
    if type(overlay.SetMouseMotionEnabled) == "function" then
        overlay:SetMouseMotionEnabled(true)
    end

    local anchor = namePlate.UnitFrame or namePlate
    overlay.namePlate = namePlate
    overlay.anchor = anchor
    overlay.shiftedDecorations = {}
    overlay.fadeActive = false
    overlay.stackSuppressed = false
    overlay.visualAlpha = 0
    -- Keep the container fixed at full alpha; ApplyOverlayVisualAlpha only
    -- changes the backdrop, border, paw, and text.
    overlay:SetAlpha(1)
    overlay:SetPoint("BOTTOM", anchor, "TOP", 0, 5)

    local icon = overlay:CreateTexture(nil, "ARTWORK")
    icon:SetSize(15, 15)
    icon:SetPoint("LEFT", 5, 0)
    local atlasOK = type(icon.SetAtlas) == "function" and pcall(icon.SetAtlas, icon, PAW_ATLAS, false)
    if not atlasOK then
        -- Use Blizzard's battle-pet icon when the preferred paw atlas is unavailable.
        icon:SetTexture("Interface\\Icons\\INV_Pet_BattlePetTraining")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    overlay.icon = icon

    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    text:SetJustifyH("LEFT")
    overlay.text = text
    ApplyOverlayVisualAlpha(overlay, 0)

    overlay:SetScript("OnEnter", function(frame)
        NPCPetIndicators:ShowOverlayTooltip(frame)
    end)
    overlay:SetScript("OnLeave", function(frame)
        if GameTooltip and type(GameTooltip.IsOwned) == "function" and GameTooltip:IsOwned(frame) then
            GameTooltip:Hide()
        end
    end)

    overlay:Hide()
    return overlay
end

function NPCPetIndicators:CreateBossIcon(namePlate)
    if not namePlate or IsFrameForbidden(namePlate) then
        return nil
    end

    local anchor = namePlate.UnitFrame or namePlate
    local iconFrame = CreateFrame("Frame", nil, namePlate)
    iconFrame:SetSize(22, 22)
    iconFrame:SetFrameStrata(namePlate:GetFrameStrata())
    iconFrame:SetFrameLevel((namePlate:GetFrameLevel() or 0) + 31)
    iconFrame:SetPoint("LEFT", anchor, "RIGHT", 5, 0)
    iconFrame:EnableMouse(true)
    if type(iconFrame.SetMouseClickEnabled) == "function" then
        iconFrame:SetMouseClickEnabled(false)
    end
    if type(iconFrame.SetMouseMotionEnabled) == "function" then
        iconFrame:SetMouseMotionEnabled(true)
    end

    local glow = iconFrame:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER")
    glow:SetSize(25, 25)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.15, 0.55, 1.0, 0.45)
    iconFrame.glow = glow

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local atlasOK = type(icon.SetAtlas) == "function" and pcall(icon.SetAtlas, icon, PAW_ATLAS, false)
    if not atlasOK then
        icon:SetTexture("Interface\\Icons\\INV_Pet_BattlePetTraining")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    icon:SetVertexColor(0.35, 0.75, 1.0)
    iconFrame.icon = icon

    iconFrame:SetScript("OnEnter", function(frame)
        NPCPetIndicators:ShowBossTooltip(frame)
    end)
    iconFrame:SetScript("OnLeave", function(frame)
        if GameTooltip and type(GameTooltip.IsOwned) == "function" and GameTooltip:IsOwned(frame) then
            GameTooltip:Hide()
        end
    end)

    iconFrame.namePlate = namePlate
    iconFrame.anchor = anchor
    iconFrame:Hide()
    return iconFrame
end

function NPCPetIndicators:GetBossIconForPlate(namePlate)
    if not namePlate then
        return nil
    end
    local icon = self.bossIcons[namePlate]
    if not icon then
        icon = self:CreateBossIcon(namePlate)
        self.bossIcons[namePlate] = icon
    end
    return icon
end

function NPCPetIndicators:ResetBossIcon(icon)
    if not icon then
        return
    end
    if GameTooltip and type(GameTooltip.IsOwned) == "function" and GameTooltip:IsOwned(icon) then
        GameTooltip:Hide()
    end
    icon.unit = nil
    icon.guid = nil
    icon.npcID = nil
    icon.npcName = nil
    icon.speciesSet = nil
    icon:Hide()
end

function NPCPetIndicators:ShowBossTooltip(icon)
    if not icon or not icon:IsShown() or not icon.speciesSet or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
    GameTooltip:SetText(icon.npcName or "Pet Drop", 1.0, 0.82, 0.0)
    GameTooltip:AddLine("Possible battle pet drops", 0.35, 0.75, 1.0)
    GameTooltip:AddLine(" ")
    for _, entry in ipairs(self:GetSpeciesTooltipEntries(icon.speciesSet)) do
        local status = entry.collected > 0 and "Collected" or "Missing"
        local r, g, b = entry.collected > 0 and 0.35 or 1.0, entry.collected > 0 and 1.0 or 0.82, entry.collected > 0 and 0.35 or 0.15
        GameTooltip:AddDoubleLine(entry.name, status, 1, 1, 1, r, g, b)
    end
    GameTooltip:Show()
end

function NPCPetIndicators:GetOverlay(unit)
    if not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
        return nil
    end

    local ok, namePlate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not namePlate then
        return nil
    end

    local overlay = self.overlays[namePlate]
    if not overlay then
        overlay = self:CreateOverlay(namePlate)
        self.overlays[namePlate] = overlay
    end
    return overlay
end

function NPCPetIndicators:ResetOverlay(overlay)
    if not overlay then
        return
    end

    if GameTooltip and type(GameTooltip.IsOwned) == "function" and GameTooltip:IsOwned(overlay) then
        GameTooltip:Hide()
    end

    self:RestoreShiftedDecorations(overlay)
    overlay.fadeActive = false
    overlay.stackSuppressed = false
    overlay.fadeMapID = nil
    overlay.fadeNPCID = nil
    overlay.fadeOuterMetric = nil
    overlay.fadeTarget = nil
    overlay.fadeSource = nil
    overlay.fadeMetric = nil
    ApplyOverlayVisualAlpha(overlay, 0)

    overlay.unit = nil
    overlay.guid = nil
    overlay.npcID = nil
    overlay.npcName = nil
    overlay.speciesSet = nil
    overlay.collected = nil
    overlay.available = nil
    if overlay.text then
        overlay.text:SetText("")
    end
    overlay:Hide()
end

function NPCPetIndicators:GetSpeciesTooltipEntries(speciesSet)
    local entries = {}

    for speciesID in pairs(speciesSet or {}) do
        local name
        local ok, petName = pcall(C_PetJournal.GetPetInfoBySpeciesID, speciesID)
        if ok then
            name = SafeString(petName)
        end
        name = name or string.format("Pet Species %d", speciesID)

        local collected = 0
        local countOK, numCollected = pcall(C_PetJournal.GetNumCollectedInfo, speciesID)
        if countOK and tonumber(numCollected) then
            collected = tonumber(numCollected) or 0
        end

        entries[#entries + 1] = {
            speciesID = speciesID,
            name = name,
            collected = collected,
        }
    end

    table.sort(entries, function(a, b)
        local aName = a.name:lower()
        local bName = b.name:lower()
        if aName == bName then
            return a.speciesID < b.speciesID
        end
        return aName < bName
    end)

    return entries
end

function NPCPetIndicators:ShowOverlayTooltip(overlay)
    if not overlay or not overlay:IsShown() or not overlay.speciesSet or not overlay.npcName or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(overlay, "ANCHOR_RIGHT")
    GameTooltip:SetText(overlay.npcName, 1.0, 0.82, 0.0)
    GameTooltip:AddLine(string.format("Battle pets collected: %d/%d", overlay.collected or 0, overlay.available or 0), 0.82, 0.82, 0.82)
    if ns.db and ns.db.settings and ns.db.settings.debug then
        local source = overlay.fadeSource or "unknown"
        local target = math.floor(((overlay.fadeTarget or 0) * 100) + 0.5)
        local shown = math.floor(((overlay.visualAlpha or 0) * 100) + 0.5)
        local metric = SafeNumber(overlay.fadeMetric)
        if metric then
            GameTooltip:AddLine(string.format("Fade debug: %s  target=%d%%  shown=%d%%  metric=%.4f", source, target, shown, metric), 0.45, 0.75, 1.0)
        else
            GameTooltip:AddLine(string.format("Fade debug: %s  target=%d%%  shown=%d%%", source, target, shown), 0.45, 0.75, 1.0)
        end
    end

    local entries = self:GetSpeciesTooltipEntries(overlay.speciesSet)
    if #entries > 0 then
        GameTooltip:AddLine(" ")
        for _, entry in ipairs(entries) do
            if entry.collected > 0 then
                local status = entry.collected > 1 and string.format("Collected x%d", entry.collected) or "Collected"
                GameTooltip:AddDoubleLine(entry.name, status, 1.0, 1.0, 1.0, 0.35, 1.0, 0.35)
            else
                GameTooltip:AddDoubleLine(entry.name, "Missing", 1.0, 1.0, 1.0, 1.0, 0.82, 0.15)
            end
        end
    end

    GameTooltip:Show()
end

-- Nameplate updates

function NPCPetIndicators:UpdateUnit(unit)
    unit = SafeString(unit)
    if not unit then
        return false
    end

    local overlay = self:GetOverlay(unit)
    if not overlay then
        return false
    end
    local bossIcon = self.bossIcons[overlay.namePlate]
    local previousGUID = overlay.guid
    local previousAlpha = SafeNumber(overlay.visualAlpha) or 0

    -- Nameplate frames are recycled aggressively. Clear every piece of the old
    -- binding before deciding whether the newly assigned unit is eligible.
    self:ResetOverlay(overlay)
    self:ResetBossIcon(bossIcon)

    local isPlayer = GetReadableBoolean(UnitIsPlayer, unit)
    if isPlayer == true then
        return true
    end

    local isPlayerControlled = GetReadableBoolean(UnitPlayerControlled, unit)
    if isPlayerControlled == true then
        return true
    end

    local guid = GetUnitReadableGUID(unit)
    if not guid then
        -- Unit data can be temporarily unavailable on the first add event in
        -- crowded zones; the caller will schedule a lightweight rebind.
        return false
    end

    local npcID = ParseNPCIDFromGUID(guid)
    if not npcID then
        -- Readable non-NPC GUID (player pet, object, etc.). Fully resolved but
        -- intentionally ineligible.
        return true
    end

    local npcName = GetUnitReadableName(unit)
    if not npcName then
        return false
    end

    self:RememberNPCName(npcID, npcName)
    self:RememberRecentNPC(unit, "nameplate")

    local settings = ns.db and ns.db.settings or {}

    if settings.npcPetDisplays ~= false then
        overlay.unit = unit
        overlay.guid = guid
        overlay.npcID = npcID
        overlay.npcName = npcName

        local species = self:GetSpeciesForNPC(npcID, npcName)
        if species then
            local collected, available = self:GetCollectionProgress(species)
            if available > 0 then
                overlay.speciesSet = species
                overlay.collected = collected
                overlay.available = available
                overlay.text:SetText(string.format("%d/%d", collected, available))
                local textWidth = overlay.text:GetStringWidth() or 22
                overlay:SetWidth(math.max(46, 5 + 15 + 3 + textWidth + 6))

                SetOverlayCollectionStyle(overlay, collected >= available)

                overlay.fadeActive = true
                if previousGUID == guid then
                    ApplyOverlayVisualAlpha(overlay, previousAlpha)
                else
                    ApplyOverlayVisualAlpha(overlay, 0)
                end
                overlay:Show()
                self:ScheduleDecorationStack(overlay)
            end
        end
    end

    -- Boss icons are intentionally combat-free. Hiding them whenever the
    -- player is in combat is stricter than checking only the boss and avoids
    -- touching nameplate decorations during protected combat transitions.
    if settings.bossIcons ~= false and not (type(InCombatLockdown) == "function" and InCombatLockdown()) then
        local bossSpecies = self:GetBossSpecies(npcID)
        local unitInCombat = GetReadableBoolean(UnitAffectingCombat, unit)
        if bossSpecies and unitInCombat ~= true then
            bossIcon = bossIcon or self:GetBossIconForPlate(overlay.namePlate)
            bossIcon.unit = unit
            bossIcon.guid = guid
            bossIcon.npcID = npcID
            bossIcon.npcName = npcName
            bossIcon.speciesSet = bossSpecies
            bossIcon:Show()
        end
    end

    return true
end

function NPCPetIndicators:ScheduleNamePlateRebind(unit, namePlate, delay)
    if not C_Timer or type(C_Timer.After) ~= "function" then
        return
    end

    C_Timer.After(delay or 0.1, function()
        if not ns.enabled or not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
            return
        end

        local ok, currentPlate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and currentPlate and (not namePlate or currentPlate == namePlate) then
            self:UpdateUnit(unit)
        end
    end)
end

function NPCPetIndicators:OnNamePlateUnitAdded(_, unit)
    local namePlate
    if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok then
            namePlate = plate
        end
    end

    local resolved = self:UpdateUnit(unit)
    if not resolved then
        -- Two tiny unit-data retries only; no merchant rescans or item loading.
        -- A nil initial plate is allowed because crowded-zone add events can
        -- arrive before GetNamePlateForUnit resolves the frame.
        self:ScheduleNamePlateRebind(unit, namePlate, 0.05)
        self:ScheduleNamePlateRebind(unit, namePlate, 0.25)
    end
end

function NPCPetIndicators:OnNamePlateUnitRemoved(_, unit)
    -- The nameplate API may already have forgotten the unit by the time this
    -- event fires, so clear by our cached binding instead of trusting a lookup.
    for _, overlay in pairs(self.overlays) do
        if overlay.unit == unit then
            self:ResetOverlay(overlay)
        end
    end
    for _, icon in pairs(self.bossIcons) do
        if icon.unit == unit then
            self:ResetBossIcon(icon)
        end
    end
end

function NPCPetIndicators:RefreshAllNameplates()
    if not C_NamePlate or type(C_NamePlate.GetNamePlates) ~= "function" then
        return
    end

    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then
        return
    end

    local activePlates = {}
    for _, plate in ipairs(plates) do
        local unit
        if plate then
            activePlates[plate] = true
            -- Prefer Blizzard's explicit nameplate unit token. GetUnit is only
            -- a fallback because mixin methods can lag behind frame recycling.
            unit = SafeString(plate.namePlateUnitToken) or SafeString(plate.unit)
            if not unit and type(plate.GetUnit) == "function" then
                local unitOK, plateUnit = pcall(plate.GetUnit, plate)
                if unitOK and SafeString(plateUnit) then
                    unit = plateUnit
                end
            end
        end

        if unit then
            self:UpdateUnit(unit)
        else
            local overlay = self.overlays[plate]
            if overlay then
                self:ResetOverlay(overlay)
            end
            local bossIcon = self.bossIcons[plate]
            if bossIcon then
                self:ResetBossIcon(bossIcon)
            end
        end
    end

    -- Clean any overlay/icon whose recycled plate is no longer active.
    for plate, overlay in pairs(self.overlays) do
        if not activePlates[plate] then
            self:ResetOverlay(overlay)
        end
    end
    for plate, icon in pairs(self.bossIcons) do
        if not activePlates[plate] then
            self:ResetBossIcon(icon)
        end
    end
end

function NPCPetIndicators:OnCombatStateChanged(event)
    if event == "PLAYER_REGEN_DISABLED" then
        for _, icon in pairs(self.bossIcons) do
            self:ResetBossIcon(icon)
        end
        return
    end

    -- Restore any external decoration anchors that were intentionally left
    -- untouched during combat, then rebuild the current out-of-combat stack.
    for _, overlay in pairs(self.overlays) do
        self:RestoreShiftedDecorations(overlay)
    end
    self:ScheduleRefresh(0.1)
end

function NPCPetIndicators:OnUnitFlagsChanged(_, unit)
    unit = SafeString(unit)
    if not unit or not unit:match("^nameplate%d+$") then
        return
    end
    self:UpdateUnit(unit)
end

function NPCPetIndicators:RefreshSettings()
    local settings = ns.db and ns.db.settings or {}
    if settings.npcPetDisplays == false then
        for _, overlay in pairs(self.overlays) do
            self:ResetOverlay(overlay)
        end
    end
    if settings.bossIcons == false or (type(InCombatLockdown) == "function" and InCombatLockdown()) then
        for _, icon in pairs(self.bossIcons) do
            self:ResetBossIcon(icon)
        end
    end
    self:ScheduleRefresh(0.05)
end

function NPCPetIndicators:ScheduleRefresh(delay)
    self.refreshToken = self.refreshToken + 1
    local token = self.refreshToken
    C_Timer.After(delay or 0.1, function()
        if token == self.refreshToken then
            self:RefreshAllNameplates()
        end
    end)
end

function NPCPetIndicators:RefreshCollectionProgress()
    self.collectionRefreshToken = (self.collectionRefreshToken or 0) + 1
    local token = self.collectionRefreshToken
    self:ScheduleRefresh(0.03)
    C_Timer.After(0.30, function()
        if ns.enabled and token == self.collectionRefreshToken then
            self:RefreshAllNameplates()
        end
    end)
    C_Timer.After(1.00, function()
        if ns.enabled and token == self.collectionRefreshToken then
            self:RefreshAllNameplates()
        end
    end)
end

function NPCPetIndicators:OnCollectionChanged()
    self:RefreshCollectionProgress()
end

function NPCPetIndicators:OnCollectionInventoryChanged()
    -- Pet purchases and learned companion items can update bags/collection in
    -- different orders. Only do the extra refresh while a merchant is active
    -- or while visible pet-source badges exist.
    if self.activeMerchantNPCID then
        self:RefreshCollectionProgress()
    end
end

-- Live source learning

function NPCPetIndicators:GetSpeciesByExactMerchantName(itemName)
    local normalized = NormalizeName(itemName)
    if not normalized then
        return nil
    end
    local species = self.speciesNameIndex[normalized]
    return type(species) == "table" and species or nil
end

function NPCPetIndicators:ScanMerchant()
    local npcID = self.activeMerchantNPCID or self:BindMerchantContext()
    if not npcID then
        DebugPrint("merchant scan skipped: vendor NPC ID unresolved")
        return false
    end

    local changed = false
    local resolvedCount = 0
    local count = GetMerchantNumItemsSafe()
    DebugPrint(string.format("merchant scan: npcID=%s items=%d", tostring(npcID), count))

    for index = 1, count do
        local speciesFound = false
        local link = GetMerchantItemLinkSafe(index)
        local merchantItemID, itemIDSource = GetMerchantItemIDSafe(index)

        if link then
            local speciesID = GetSpeciesIDFromLink(link)
            if speciesID then
                changed = self:RememberNPCSpecies(npcID, speciesID) or changed
                speciesFound = true
                resolvedCount = resolvedCount + 1
                DebugPrint(string.format("merchant item %d -> species %d via link", index, speciesID))
            end
        end

        -- Scenario merchants can withhold readable row text/link data while
        -- still exposing a stable numeric item ID. Resolve that ID directly
        -- through the Pet Journal before attempting any name-based fallback.
        if not speciesFound and merchantItemID then
            local speciesID = GetSpeciesIDFromItem(merchantItemID)
            if speciesID then
                changed = self:RememberNPCSpecies(npcID, speciesID) or changed
                speciesFound = true
                resolvedCount = resolvedCount + 1
                DebugPrint(string.format(
                    "merchant item %d itemID=%d -> species %d via %s",
                    index, merchantItemID, speciesID, tostring(itemIDSource or "numeric item ID")
                ))
            end
        end

        -- Some companion-pet merchant rows do not resolve through the usual
        -- item-link/item-ID -> GetPetInfoByItemID paths. Fall back to an exact
        -- name match against the Pet Journal index built by the lightweight
        -- source scan. This stays strict and cannot match partial names.
        if not speciesFound then
            local itemName = GetMerchantItemNameSafe(index)
            if itemName then
                local speciesSet = self:GetSpeciesByExactMerchantName(itemName)
                if speciesSet then
                    for speciesID in pairs(speciesSet) do
                        changed = self:RememberNPCSpecies(npcID, speciesID) or changed
                        resolvedCount = resolvedCount + 1
                        DebugPrint(string.format("merchant item %d '%s' -> species %d via exact name", index, itemName, speciesID))
                    end
                elseif ns.db and ns.db.settings and ns.db.settings.debug then
                    DebugPrint(string.format(
                        "merchant item %d unresolved: name='%s' link=%s itemID=%s",
                        index, itemName, tostring(link), tostring(merchantItemID)
                    ))
                end
            elseif ns.db and ns.db.settings and ns.db.settings.debug then
                DebugPrint(string.format(
                    "merchant item %d unresolved: no readable name/link; itemID=%s",
                    index, tostring(merchantItemID)
                ))
            end
        end
    end

    DebugPrint(string.format("merchant scan complete: resolved=%d changed=%s", resolvedCount, tostring(changed)))

    if changed then
        self:ScheduleRefresh(0.05)
    end
    return changed
end

function NPCPetIndicators:OnMerchantShown()
    self:BindMerchantContext()
    self:ScanMerchant()
    self:RefreshCollectionProgress()
    C_Timer.After(0.25, function()
        if self.activeMerchantNPCID then
            self:ScanMerchant()
        else
            self:BindMerchantContext()
            self:ScanMerchant()
        end
    end)
    C_Timer.After(1.0, function()
        if self.activeMerchantNPCID then
            self:ScanMerchant()
        else
            self:BindMerchantContext()
            self:ScanMerchant()
        end
    end)
end

function NPCPetIndicators:OnMerchantUpdated()
    if not self.activeMerchantNPCID then
        self:BindMerchantContext()
    end
    self:ScanMerchant()
    self:RefreshCollectionProgress()
end

function NPCPetIndicators:OnMerchantClosed()
    self:RefreshCollectionProgress()
    self.activeMerchantNPCID = nil
    self.activeMerchantNPCName = nil
    self.activeMerchantResolveMethod = nil
end

function NPCPetIndicators:ScanQuestRewards()
    local context = GetUnitNPCContext("npc") or GetUnitNPCContext("target") or GetUnitNPCContext("mouseover")
    local npcID = context and context.npcID or nil
    if not npcID or type(GetQuestItemLink) ~= "function" then
        return false
    end

    local changed = false
    local groups = {
        { rewardType = "choice", count = type(GetNumQuestChoices) == "function" and (GetNumQuestChoices() or 0) or 0 },
        { rewardType = "reward", count = type(GetNumQuestRewards) == "function" and (GetNumQuestRewards() or 0) or 0 },
    }

    for _, group in ipairs(groups) do
        for index = 1, group.count do
            local ok, link = pcall(GetQuestItemLink, group.rewardType, index)
            if ok and link then
                local speciesID = GetSpeciesIDFromLink(link)
                if speciesID then
                    changed = self:RememberNPCSpecies(npcID, speciesID) or changed
                end
            end
        end
    end

    if changed then
        self:ScheduleRefresh(0.05)
    end
    return changed
end

function NPCPetIndicators:OnQuestComplete()
    self:ScanQuestRewards()
    C_Timer.After(0.15, function() self:ScanQuestRewards() end)
end

local addonName, ns = ...

local DungeonPetTooltips = {
    hooked = {},
    dynamicTooltips = setmetatable({}, { __mode = "k" }),
    instanceNameIndex = {},
    indexBuilt = false,
    appending = false,
    tooltipWatcher = nil,
    watcherElapsed = 0,
    lastDebugSignature = nil,
    handyNotesWorldMapHooked = false,
}
ns:RegisterModule("DungeonPetTooltips", DungeonPetTooltips)

local DX_SECTION_HEADER = "DX Pet Services — Battle Pets"

-- Data helpers

local function Normalize(text)
    if type(text) ~= "string" then
        return nil
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:lower():gsub("[%s%p]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text or nil
end

local function EnsureEncounterJournalLoaded()
    if type(EJ_GetInstanceInfo) == "function"
        or (C_EncounterJournal and type(C_EncounterJournal.GetInstanceInfo) == "function") then
        return true
    end

    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    elseif type(LoadAddOn) == "function" then
        pcall(LoadAddOn, "Blizzard_EncounterJournal")
    end

    return type(EJ_GetInstanceInfo) == "function"
        or (C_EncounterJournal and type(C_EncounterJournal.GetInstanceInfo) == "function")
end

local function AddUniqueName(names, seen, name)
    if type(name) ~= "string" or name == "" or seen[name] then
        return
    end
    seen[name] = true
    names[#names + 1] = name
end

local function GetJournalInstanceName(instanceID)
    if not instanceID then
        return nil
    end

    -- ATTPetWorldDB.instances is keyed directly by Encounter Journal instance
    -- ID. Resolve that ID as-is; do not pass it through EJ_GetInstanceForMap.
    if type(EJ_GetInstanceInfo) == "function" then
        local ok, name = pcall(EJ_GetInstanceInfo, instanceID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    if C_EncounterJournal and type(C_EncounterJournal.GetInstanceInfo) == "function" then
        local ok, info = pcall(C_EncounterJournal.GetInstanceInfo, instanceID)
        if ok then
            if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                return info.name
            elseif type(info) == "string" and info ~= "" then
                return info
            end
        end
    end

    return nil
end

local function GetInstanceAliases(instanceID)
    local names, seen = {}, {}
    local worldDB = ns.ATTPetWorldDB

    -- Prefer Blizzard's localized Encounter Journal name for the exact ATT
    -- instance ID. This automatically expands the alias layer across the full
    -- bundled database in every client locale.
    AddUniqueName(names, seen, GetJournalInstanceName(instanceID))

    -- Keep shipped aliases as deterministic fallbacks for instances whose
    -- journal data is temporarily unavailable or known to resolve late.
    if worldDB and type(worldDB.instanceNames) == "table" then
        AddUniqueName(names, seen, worldDB.instanceNames[instanceID])
    end

    return names
end

local function GetBossName(source)
    if source.encounterID and type(EJ_GetEncounterInfo) == "function" then
        local ok, name = pcall(EJ_GetEncounterInfo, source.encounterID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    if C_CreatureInfo and type(C_CreatureInfo.GetCreatureInfo) == "function" then
        local ok, info = pcall(C_CreatureInfo.GetCreatureInfo, source.npcID)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    return string.format("Boss %d", tonumber(source.npcID) or 0)
end

local function GetPetName(speciesID)
    if C_PetJournal and type(C_PetJournal.GetPetInfoBySpeciesID) == "function" then
        local ok, name = pcall(C_PetJournal.GetPetInfoBySpeciesID, speciesID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return string.format("Pet Species %d", tonumber(speciesID) or 0)
end

local function IsCollected(speciesID)
    if C_PetJournal and type(C_PetJournal.GetNumCollectedInfo) == "function" then
        local ok, count = pcall(C_PetJournal.GetNumCollectedInfo, speciesID)
        return ok and tonumber(count) and count > 0
    end
    return false
end

local function GetTooltipLines(tooltip)
    local lines = {}
    local seen = {}
    if not tooltip then
        return lines
    end

    local tooltipName = type(tooltip.GetName) == "function" and tooltip:GetName() or nil
    if tooltipName then
        for index = 1, 40 do
            for _, side in ipairs({ "Left", "Right" }) do
                local region = _G[tooltipName .. "Text" .. side .. index]
                if region and type(region.GetText) == "function" then
                    local text = region:GetText()
                    if type(text) == "string" and text ~= "" and not seen[text] then
                        seen[text] = true
                        lines[#lines + 1] = text
                    end
                end
            end
        end
    end

    -- Anonymous or addon-owned tooltip frames may not expose globally named
    -- TextLeft/TextRight font strings. Read their FontString regions directly
    -- so HandyNotes-style custom tooltip frames can still be inspected.
    if #lines == 0 and type(tooltip.GetRegions) == "function" then
        local ok, regions = pcall(function()
            return { tooltip:GetRegions() }
        end)
        if ok and type(regions) == "table" then
            for _, region in ipairs(regions) do
                if region and type(region.GetText) == "function" then
                    local text = region:GetText()
                    if type(text) == "string" and text ~= "" and not seen[text] then
                        seen[text] = true
                        lines[#lines + 1] = text
                    end
                end
            end
        end
    end

    if #lines == 0 and type(tooltip.GetText) == "function" then
        local text = tooltip:GetText()
        if type(text) == "string" and text ~= "" then
            lines[1] = text
        end
    end
    return lines
end

local function DebugPrint(...)
    if ns.db and ns.db.settings and ns.db.settings.debug then
        ns:Print("Dungeon Pet Tooltips:", ...)
    end
end

local function IsTooltipFeatureActive()
    return ns.db
        and ns.db.settings
        and ns.db.settings.dungeonTooltipInfo ~= false
        and WorldMapFrame
        and WorldMapFrame:IsShown()
end

-- Lifecycle and hooks

function DungeonPetTooltips:OnInitialize()
    ns.Events:Register("ADDON_LOADED", self, "OnAddonLoaded")
    ns.Events:Register("PLAYER_LOGIN", self, "OnPlayerLogin")

    self:HookKnownTooltips()
    self:CreateTooltipWatcher()
end

function DungeonPetTooltips:OnEnable()
    self:BuildInstanceIndex()
end

function DungeonPetTooltips:OnPlayerLogin()
    self.indexBuilt = false
    self:BuildInstanceIndex()
    self:HookKnownTooltips()
end

function DungeonPetTooltips:OnAddonLoaded(_, loadedAddon)
    if loadedAddon == "Blizzard_EncounterJournal"
        or loadedAddon == "Blizzard_WorldMap"
        or loadedAddon == "MapNotes"
        or loadedAddon == "HandyNotes" then
        self.indexBuilt = false
        self:BuildInstanceIndex()
        self:HookKnownTooltips()
    end
end

function DungeonPetTooltips:HookKnownTooltips()
    self:TryHookTooltip(_G.GameTooltip)
    if _G.WorldMapTooltip and _G.WorldMapTooltip ~= _G.GameTooltip then
        self:TryHookTooltip(_G.WorldMapTooltip)
    end

    -- These addons normally use GameTooltip, but keep optional support for a
    -- dedicated global tooltip if one is present in a user's configuration.
    for _, globalName in ipairs({
        "MapNotesTooltip",
        "MapNotesWorldMapTooltip",
        "HandyNotesTooltip",
    }) do
        local tooltip = _G[globalName]
        if tooltip and tooltip ~= _G.GameTooltip and tooltip ~= _G.WorldMapTooltip then
            self:TryHookTooltip(tooltip)
        end
    end

    self:HookHandyNotesWorldMapPins()
end

function DungeonPetTooltips:CreateTooltipWatcher()
    if self.tooltipWatcher or type(CreateFrame) ~= "function" then
        return
    end

    local watcher = CreateFrame("Frame")
    self.tooltipWatcher = watcher

    -- Keep this tiny watcher alive and do no work unless the world map is open.
    -- This avoids depending on a specific map-provider event and catches addon
    -- tooltips that reuse an already-visible GameTooltip frame.
    watcher:SetScript("OnUpdate", function(_, elapsed)
        self.watcherElapsed = self.watcherElapsed + elapsed
        if self.watcherElapsed < 0.08 then
            return
        end
        self.watcherElapsed = 0

        if not IsTooltipFeatureActive() then
            return
        end

        self:CheckVisibleTooltips()
    end)
end

function DungeonPetTooltips:GetTooltipCandidates()
    local candidates, seen = {}, {}
    local function add(tooltip)
        if tooltip and not seen[tooltip] then
            seen[tooltip] = true
            candidates[#candidates + 1] = tooltip
        end
    end

    add(_G.GameTooltip)
    add(_G.WorldMapTooltip)
    add(_G.MapNotesTooltip)
    add(_G.MapNotesWorldMapTooltip)
    add(_G.HandyNotesTooltip)

    for tooltip in pairs(self.dynamicTooltips) do
        add(tooltip)
    end

    return candidates
end

function DungeonPetTooltips:CheckVisibleTooltips()
    self:HookKnownTooltips()
    for _, tooltip in ipairs(self:GetTooltipCandidates()) do
        if type(tooltip.IsShown) == "function" and tooltip:IsShown() then
            self:AppendDungeonInfo(tooltip)
        end
    end
end

-- Instance lookup

function DungeonPetTooltips:BuildInstanceIndex()
    EnsureEncounterJournalLoaded()
    local db = ns.ATTPetWorldDB
    if not db or type(db.instances) ~= "table" then
        return false
    end

    local index = {}
    local canonicalByInstanceID = {}
    local resolvedInstances = 0
    local aliasCount = 0
    local unresolvedInstanceIDs = {}

    for instanceID, sources in pairs(db.instances) do
        local aliases = GetInstanceAliases(instanceID)
        if #aliases > 0 then
            local entry = canonicalByInstanceID[instanceID]
            if not entry then
                entry = {
                    instanceID = instanceID,
                    name = aliases[1],
                    sources = {},
                }
                canonicalByInstanceID[instanceID] = entry
                for _, source in ipairs(sources) do
                    entry.sources[#entry.sources + 1] = source
                end
            end

            for _, name in ipairs(aliases) do
                local normalized = Normalize(name)
                if normalized then
                    local existing = index[normalized]
                    if existing and existing ~= entry then
                        -- Rarely, multiple ATT instance IDs can share one display
                        -- name. Merge unique source rows under that tooltip alias.
                        local seenSource = {}
                        for _, source in ipairs(existing.sources) do
                            seenSource[string.format("%s:%s", tostring(source.encounterID or source.npcID or 0), table.concat(source.species or {}, ","))] = true
                        end
                        for _, source in ipairs(entry.sources) do
                            local sourceKey = string.format("%s:%s", tostring(source.encounterID or source.npcID or 0), table.concat(source.species or {}, ","))
                            if not seenSource[sourceKey] then
                                existing.sources[#existing.sources + 1] = source
                                seenSource[sourceKey] = true
                            end
                        end
                        entry = existing
                    else
                        index[normalized] = entry
                    end
                    aliasCount = aliasCount + 1
                end
            end
            resolvedInstances = resolvedInstances + 1
        else
            unresolvedInstanceIDs[#unresolvedInstanceIDs + 1] = tonumber(instanceID) or 0
        end
    end

    if resolvedInstances > 0 then
        self.instanceNameIndex = index
        self.indexBuilt = true
        table.sort(unresolvedInstanceIDs)
        DebugPrint(string.format(
            "indexed %d/%d pet instances with %d tooltip-name aliases",
            resolvedInstances,
            tonumber(db.instanceCount) or resolvedInstances + #unresolvedInstanceIDs,
            aliasCount
        ))
        if #unresolvedInstanceIDs > 0 then
            DebugPrint("unresolved instance IDs:", table.concat(unresolvedInstanceIDs, ", "))
        end
        return true
    end

    DebugPrint("instance-name index unresolved; Encounter Journal names unavailable")
    return false
end

-- Tooltip state

function DungeonPetTooltips:TooltipHasDXSection(tooltip)
    local wanted = Normalize(DX_SECTION_HEADER)
    for _, text in ipairs(GetTooltipLines(tooltip)) do
        if Normalize(text) == wanted then
            return true
        end
    end
    return false
end

function DungeonPetTooltips:ResetTooltipState(tooltip)
    if not tooltip then
        return
    end
    tooltip.__DXPetServicesDungeonKey = nil
    tooltip.__DXPetServicesAppendSerial = (tooltip.__DXPetServicesAppendSerial or 0) + 1
end

function DungeonPetTooltips:ScheduleAppend(tooltip)
    if not tooltip then
        return
    end

    tooltip.__DXPetServicesAppendSerial = (tooltip.__DXPetServicesAppendSerial or 0) + 1
    local serial = tooltip.__DXPetServicesAppendSerial

    local function tryAppend()
        if serial ~= tooltip.__DXPetServicesAppendSerial
            or not tooltip
            or type(tooltip.IsShown) ~= "function"
            or not tooltip:IsShown() then
            return
        end
        self:AppendDungeonInfo(tooltip)
    end

    if C_Timer and type(C_Timer.After) == "function" then
        -- Addons such as MapNotes and HandyNotes often build or rebuild their
        -- tooltip after the initial hover callback. Recheck after each common
        -- content pass rather than assuming OnShow means the tooltip is final.
        C_Timer.After(0, tryAppend)
        C_Timer.After(0.01, tryAppend)
        C_Timer.After(0.05, tryAppend)
        C_Timer.After(0.15, tryAppend)
        C_Timer.After(0.30, tryAppend)
    else
        tryAppend()
    end
end

function DungeonPetTooltips:HookTooltipMutationMethods(tooltip)
    if not tooltip or tooltip.__DXPetServicesMutationHooks then
        return
    end
    tooltip.__DXPetServicesMutationHooks = true

    if type(hooksecurefunc) ~= "function" then
        return
    end

    for _, methodName in ipairs({ "ClearLines", "SetText", "AddLine", "AddDoubleLine" }) do
        if type(tooltip[methodName]) == "function" then
            pcall(hooksecurefunc, tooltip, methodName, function()
                if self.appending or not IsTooltipFeatureActive() then
                    return
                end
                -- Coalesce all of the source addon's writes into one append
                -- after its current tooltip-building pass finishes.
                self:ScheduleAppend(tooltip)
            end)
        end
    end
end

function DungeonPetTooltips:TryHookTooltip(tooltip)
    if not tooltip then
        return
    end

    self.dynamicTooltips[tooltip] = true
    self:HookTooltipMutationMethods(tooltip)

    if self.hooked[tooltip] or type(tooltip.HookScript) ~= "function" then
        return
    end
    self.hooked[tooltip] = true

    tooltip:HookScript("OnShow", function(frame)
        self:ScheduleAppend(frame)
    end)
    tooltip:HookScript("OnTooltipCleared", function(frame)
        self:ResetTooltipState(frame)
        if IsTooltipFeatureActive() then
            self:ScheduleAppend(frame)
        end
    end)
    tooltip:HookScript("OnHide", function(frame)
        self:ResetTooltipState(frame)
    end)
end

function DungeonPetTooltips:DiscoverTooltipFramesForOwner(owner)
    if type(EnumerateFrames) ~= "function" then
        return
    end

    local frame = EnumerateFrames()
    local scanned = 0
    while frame and scanned < 6000 do
        scanned = scanned + 1
        local isTooltip = false
        if type(frame.IsObjectType) == "function" then
            local ok, result = pcall(frame.IsObjectType, frame, "GameTooltip")
            isTooltip = ok and result == true
        end

        if isTooltip and type(frame.IsShown) == "function" and frame:IsShown() then
            local ownerMatches = owner == nil
            if owner and type(frame.GetOwner) == "function" then
                local ok, tooltipOwner = pcall(frame.GetOwner, frame)
                ownerMatches = ok and tooltipOwner == owner
            end

            if ownerMatches then
                self:TryHookTooltip(frame)
                self:ScheduleAppend(frame)
            end
        end

        frame = EnumerateFrames(frame)
    end
end

-- HandyNotes integration

function DungeonPetTooltips:OnHandyNotesWorldMapPinEnter(pin)
    -- HandyNotes delegates tooltip creation to each plugin's OnEnter handler,
    -- so there is no single mandatory tooltip frame. Run after that handler,
    -- inspect all known frames, and discover any owner-bound custom tooltip.
    local function inspectHandyNotesTooltip()
        self:HookKnownTooltips()
        for _, tooltip in ipairs(self:GetTooltipCandidates()) do
            if type(tooltip.IsShown) == "function" and tooltip:IsShown() then
                self:ScheduleAppend(tooltip)
            end
        end
        self:DiscoverTooltipFramesForOwner(pin)
    end

    inspectHandyNotesTooltip()
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.05, inspectHandyNotesTooltip)
        C_Timer.After(0.15, inspectHandyNotesTooltip)
    end
end

function DungeonPetTooltips:HookHandyNotesWorldMapPins()
    if self.handyNotesWorldMapHooked or type(hooksecurefunc) ~= "function" then
        return
    end

    local mixin = _G.HandyNotesWorldMapPinMixin
    if type(mixin) ~= "table" or type(mixin.OnMouseEnter) ~= "function" then
        return
    end

    local ok = pcall(hooksecurefunc, mixin, "OnMouseEnter", function(pin)
        if IsTooltipFeatureActive() then
            self:OnHandyNotesWorldMapPinEnter(pin)
        end
    end)
    if ok then
        self.handyNotesWorldMapHooked = true
        DebugPrint("HandyNotes world-map pin tooltip hook active")
    end
end

-- Tooltip content

function DungeonPetTooltips:GetDungeonEntryForTooltip(tooltip)
    if not IsTooltipFeatureActive() then
        return nil
    end

    if not self.indexBuilt then
        self:BuildInstanceIndex()
    end
    if not self.indexBuilt then
        return nil
    end

    local lines = GetTooltipLines(tooltip)
    local normalizedLines = {}
    for _, text in ipairs(lines) do
        local normalized = Normalize(text)
        if normalized then
            normalizedLines[#normalizedLines + 1] = normalized
            local entry = self.instanceNameIndex[normalized]
            if entry then
                return entry, normalized
            end
        end
    end

    -- Strict containment fallback for tooltips that decorate the title, e.g.
    -- "Dungeon: Cinderbrew Meadery". The complete instance name must be a
    -- whole normalized phrase, never a partial word match.
    for _, normalized in ipairs(normalizedLines) do
        local paddedLine = " " .. normalized .. " "
        for key, candidate in pairs(self.instanceNameIndex) do
            local paddedKey = " " .. key .. " "
            if paddedLine:find(paddedKey, 1, true) then
                return candidate, key
            end
        end
    end

    if ns.db.settings.debug then
        local signature = table.concat(normalizedLines, " | ")
        if signature ~= "" and signature ~= self.lastDebugSignature then
            self.lastDebugSignature = signature
            DebugPrint("no pet-instance match for tooltip:", signature)
        end
    end

    return nil
end

function DungeonPetTooltips:AppendDungeonInfo(tooltip)
    if self.appending or not tooltip then
        return
    end

    local entry, key = self:GetDungeonEntryForTooltip(tooltip)
    if not entry then
        return
    end

    -- A tooltip rebuild can erase our lines without clearing Lua fields on the
    -- frame. Only trust the cached key while the actual DX section is present.
    if tooltip.__DXPetServicesDungeonKey == key and self:TooltipHasDXSection(tooltip) then
        return
    end

    local rows = {}
    local seenRows = {}
    for _, source in ipairs(entry.sources) do
        local bossName = GetBossName(source)
        for _, speciesID in ipairs(source.species or {}) do
            local rowKey = string.format("%s:%s", tostring(source.encounterID or source.npcID or 0), tostring(speciesID))
            if not seenRows[rowKey] then
                seenRows[rowKey] = true
                rows[#rows + 1] = {
                    petName = GetPetName(speciesID),
                    bossName = bossName,
                    collected = IsCollected(speciesID),
                    speciesID = speciesID,
                }
            end
        end
    end

    if #rows == 0 then
        return
    end

    table.sort(rows, function(a, b)
        if a.bossName == b.bossName then
            if a.petName == b.petName then
                return a.speciesID < b.speciesID
            end
            return a.petName < b.petName
        end
        return a.bossName < b.bossName
    end)

    self.appending = true
    local ok, err = pcall(function()
        tooltip:AddLine(" ")
        tooltip:AddLine(DX_SECTION_HEADER, 0.35, 0.75, 1.0)
        for _, row in ipairs(rows) do
            local status = row.collected and "Collected" or "Missing"
            local r, g, b = row.collected and 0.35 or 1.0, row.collected and 1.0 or 0.82, row.collected and 0.35 or 0.15
            tooltip:AddDoubleLine(row.petName .. " — " .. row.bossName, status, 1, 1, 1, r, g, b)
        end

        if type(tooltip.Layout) == "function" then
            pcall(tooltip.Layout, tooltip)
        end
        tooltip:Show()
    end)
    self.appending = false

    if not ok then
        DebugPrint("failed to append pet rows:", tostring(err))
        return
    end

    tooltip.__DXPetServicesDungeonKey = key
    DebugPrint(string.format("appended %d pet rows for %s", #rows, entry.name or key or "instance"))

    -- Verify that a source addon did not immediately rebuild the tooltip and
    -- erase the injected section. The watcher also continues to repair reused
    -- tooltip frames while the world map remains open.
    if C_Timer and type(C_Timer.After) == "function" then
        for _, delay in ipairs({ 0.03, 0.10, 0.25 }) do
            C_Timer.After(delay, function()
                if tooltip and type(tooltip.IsShown) == "function" and tooltip:IsShown()
                    and not self:TooltipHasDXSection(tooltip) then
                    tooltip.__DXPetServicesDungeonKey = nil
                    self:AppendDungeonInfo(tooltip)
                end
            end)
        end
    end
end

function DungeonPetTooltips:RefreshSettings()
    -- Tooltip behavior is checked dynamically on each show/update.
end

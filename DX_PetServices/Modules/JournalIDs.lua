local addonName, ns = ...

local JournalIDs = {
    hooksInstalled = false,
    journalHooksInstalled = false,
    petCardHookInstalled = false,
    parentHideHooks = {},
}
ns:RegisterModule("JournalIDs", JournalIDs)

local UNKNOWN = "—"
local PROTECTED = "<protected>"
local BreedInfo

local function IsSecretValue(value)
    if type(issecretvalue) ~= "function" then
        return false
    end

    local ok, result = pcall(issecretvalue, value)
    return ok and result == true
end

local function ValueOrUnknown(value)
    if IsSecretValue(value) then
        return PROTECTED
    end
    if value == nil or value == "" then
        return UNKNOWN
    end

    local ok, text = pcall(tostring, value)
    if not ok or text == "" then
        return UNKNOWN
    end
    return text
end

local function GetFamilyName(petType)
    if not petType then
        return UNKNOWN
    end

    local globalName = _G["BATTLE_PET_NAME_" .. tostring(petType)]
    return globalName or tostring(petType)
end

local function FindPetIDOnFrame(frame)
    local current = frame

    for _ = 1, 10 do
        if not current then
            break
        end

        for _, field in ipairs({ "petID", "battlePetID", "bPetID" }) do
            local petID = current[field]
            if IsSecretValue(petID) or petID ~= nil then
                return petID
            end
        end

        if type(current.GetElementData) == "function" then
            local ok, data = pcall(current.GetElementData, current)
            if ok and type(data) == "table" then
                for _, field in ipairs({ "petID", "battlePetID", "bPetID" }) do
                    local petID = data[field]
                    if IsSecretValue(petID) or petID ~= nil then
                        return petID
                    end
                end
            end
        end

        if type(current.GetParent) ~= "function" then
            break
        end
        current = current:GetParent()
    end

    return nil
end

local function GetTooltipFrame(name)
    local tooltip = _G[name]
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", name, nil, "GameTooltipTemplate")
    end
    return tooltip
end

function JournalIDs:OnInitialize()
    BreedInfo = ns:GetModule("BreedInfo")
    ns.Events:Register("ADDON_LOADED", self, "OnAddonLoaded")
    self:InstallTooltipHooks()
end

function JournalIDs:OnEnable()
    self:InstallTooltipHooks()
end

function JournalIDs:OnAddonLoaded(_, loadedAddon)
    if loadedAddon == "Blizzard_Collections" or loadedAddon == "Blizzard_FrameXML" then
        self:InstallTooltipHooks()
    end
end

function JournalIDs:GetInfoByPetID(petID)
    if IsSecretValue(petID) or not petID then
        return nil
    end

    if C_PetJournal.GetPetInfoTableByPetID then
        local info = C_PetJournal.GetPetInfoTableByPetID(petID)
        if info then
            info.petID = petID
            return info
        end
    end

    if C_PetJournal.GetPetInfoByPetID then
        local speciesID, customName, level, xp, maxXP, displayID, isFavorite, name, icon,
            petType, creatureID, sourceText, description, isWild, canBattle, tradable, unique, obtainable =
            C_PetJournal.GetPetInfoByPetID(petID)

        if speciesID then
            return {
                petID = petID,
                speciesID = speciesID,
                customName = customName,
                petLevel = level,
                xp = xp,
                maxXP = maxXP,
                displayID = displayID,
                isFavorite = isFavorite,
                name = name,
                icon = icon,
                petType = petType,
                creatureID = creatureID,
                sourceText = sourceText,
                description = description,
                isWild = isWild,
                canBattle = canBattle,
                tradable = tradable,
                unique = unique,
                obtainable = obtainable,
            }
        end
    end

    return nil
end

function JournalIDs:GetInfoBySpeciesID(speciesID)
    speciesID = tonumber(speciesID)
    if not speciesID or not C_PetJournal.GetPetInfoBySpeciesID then
        return nil
    end

    local name, icon, petType, creatureID, sourceText, description, isWild, canBattle, tradable, unique, obtainable =
        C_PetJournal.GetPetInfoBySpeciesID(speciesID)

    if not name and not petType and not creatureID then
        return nil
    end

    local displayID
    if C_PetJournal.GetDisplayIDByIndex then
        displayID = C_PetJournal.GetDisplayIDByIndex(speciesID, 1)
    end

    return {
        speciesID = speciesID,
        name = name,
        icon = icon,
        petType = petType,
        creatureID = creatureID,
        displayID = displayID,
        sourceText = sourceText,
        description = description,
        isWild = isWild,
        canBattle = canBattle,
        tradable = tradable,
        unique = unique,
        obtainable = obtainable,
    }
end

function JournalIDs:GetInfoByJournalIndex(index)
    if not index or not C_PetJournal.GetPetInfoByIndex then
        return nil
    end

    local petID, speciesID, isOwned, customName, level, isFavorite, isRevoked, name, icon,
        petType, companionID, tooltipSource, description, isWild, canBattle, tradable, unique, obtainable =
        C_PetJournal.GetPetInfoByIndex(index)

    if not speciesID then
        return nil
    end

    local info = self:GetInfoByPetID(petID)
    if info then
        return info
    end

    return {
        petID = petID,
        speciesID = speciesID,
        isOwned = isOwned,
        customName = customName,
        petLevel = level,
        isFavorite = isFavorite,
        isRevoked = isRevoked,
        name = name,
        icon = icon,
        petType = petType,
        creatureID = companionID,
        sourceText = tooltipSource,
        description = description,
        isWild = isWild,
        canBattle = canBattle,
        tradable = tradable,
        unique = unique,
        obtainable = obtainable,
    }
end

function JournalIDs:GetInfoForListButton(button)
    if not button then
        return nil
    end

    local info = self:GetInfoByPetID(button.petID)
    if info then
        return info
    end

    info = self:GetInfoByJournalIndex(button.index)
    if info then
        return info
    end

    return self:GetInfoBySpeciesID(button.speciesID)
end

function JournalIDs:GetAbilityIDs(speciesID)
    speciesID = tonumber(speciesID)
    if not speciesID or not C_PetJournal.GetPetAbilityListTable then
        return {}
    end

    local entries = C_PetJournal.GetPetAbilityListTable(speciesID)
    if type(entries) ~= "table" then
        return {}
    end

    local abilityIDs = {}
    for _, entry in ipairs(entries) do
        local abilityID = type(entry) == "table" and entry.abilityID or nil
        if abilityID then
            abilityIDs[#abilityIDs + 1] = abilityID
        end
    end
    return abilityIDs
end

function JournalIDs:HideTooltipStack()
    local idTooltip = _G.DXPS_IDTooltip
    if idTooltip then
        idTooltip:Hide()
    end
    if BreedInfo then
        BreedInfo:HideTooltip()
    end
end

function JournalIDs:HookParentHide(parent)
    if not parent or self.parentHideHooks[parent] or type(parent.HookScript) ~= "function" then
        return
    end

    parent:HookScript("OnHide", function()
        self:HideTooltipStack()
    end)
    self.parentHideHooks[parent] = true
end

function JournalIDs:GetExternalBreedTooltip(parent)
    if BreedInfo and BreedInfo.GetExternalTooltip then
        return BreedInfo:GetExternalTooltip(parent)
    end
    return nil
end

function JournalIDs:ShowIDTooltip(parent, info, anchorFrame)
    if not parent or not info then
        return nil
    end

    local tooltip = GetTooltipFrame("DXPS_IDTooltip")
    tooltip:Hide()
    tooltip:ClearLines()
    tooltip:ClearAllPoints()
    tooltip:SetParent(parent)
    tooltip:SetOwner(parent, "ANCHOR_NONE")

    anchorFrame = anchorFrame or parent
    tooltip:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, 2)
    tooltip:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 2)

    tooltip:AddLine("DX Pet Information", 0.35, 0.80, 1.00)
    tooltip:AddDoubleLine("Species ID", ValueOrUnknown(info.speciesID), 0.75, 0.82, 0.90, 1, 1, 1)

    if info.petID then
        tooltip:AddLine("Pet GUID", 0.75, 0.82, 0.90)
        tooltip:AddLine(ValueOrUnknown(info.petID), 1, 1, 1, true)
    end

    tooltip:AddDoubleLine("Creature ID", ValueOrUnknown(info.creatureID), 0.75, 0.82, 0.90, 1, 1, 1)
    tooltip:AddDoubleLine("Display ID", ValueOrUnknown(info.displayID), 0.75, 0.82, 0.90, 1, 1, 1)
    tooltip:AddDoubleLine("Pet Type", GetFamilyName(info.petType), 0.75, 0.82, 0.90, 1, 1, 1)

    if ns.db and ns.db.settings and ns.db.settings.showAbilityIDs then
        local abilityIDs = self:GetAbilityIDs(info.speciesID)
        local abilityText = #abilityIDs > 0 and table.concat(abilityIDs, ", ") or UNKNOWN
        tooltip:AddDoubleLine("Ability IDs", abilityText, 0.75, 0.82, 0.90, 1, 1, 1)
    end

    tooltip:Show()
    return tooltip
end

function JournalIDs:ShowTooltipStack(parent, info, breedContext, tooltipDistance)
    if not parent or not info then
        self:HideTooltipStack()
        return false
    end

    self:HookParentHide(parent)

    local breedTooltip
    if BreedInfo and breedContext then
        breedTooltip = BreedInfo:ShowTooltip(parent, breedContext, tooltipDistance)
    end

    -- If the official Battle Pet BreedID addon is installed, its hook may run after ours.
    -- Re-anchor once on the next frame so the DX ID panel lands below its exact tooltip.
    local idTooltip = self:ShowIDTooltip(parent, info, breedTooltip)
    if BreedInfo and BreedInfo:IsExternalAddonLoaded() and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if not idTooltip or not idTooltip:IsShown() or not parent:IsShown() then
                return
            end
            local external = self:GetExternalBreedTooltip(parent)
            if external then
                if BreedInfo then
                    BreedInfo:HideTooltip()
                end
                idTooltip:ClearAllPoints()
                idTooltip:SetPoint("TOPLEFT", external, "BOTTOMLEFT", 0, 2)
                idTooltip:SetPoint("TOPRIGHT", external, "BOTTOMRIGHT", 0, 2)
            end
        end)
    end

    return true
end

function JournalIDs:ShowForPetID(parent, petID)
    local info = self:GetInfoByPetID(petID)
    if not info then
        return false
    end

    local breedContext = BreedInfo and BreedInfo:BuildPetContext(petID) or { speciesID = info.speciesID, petID = petID }
    return self:ShowTooltipStack(parent, info, breedContext)
end

function JournalIDs:ShowForSpeciesStats(parent, speciesID, level, rarity, maxHealth, power, speed, petID)
    local info = self:GetInfoByPetID(petID) or self:GetInfoBySpeciesID(speciesID)
    if not info then
        return false
    end

    local breedContext
    if petID and BreedInfo then
        breedContext = BreedInfo:BuildPetContext(petID)
    elseif BreedInfo then
        breedContext = BreedInfo:BuildStatsContext(speciesID, level, rarity, maxHealth, power, speed)
    else
        breedContext = { speciesID = speciesID }
    end

    return self:ShowTooltipStack(parent, info, breedContext)
end

function JournalIDs:ResolvePetIDForTooltip(tooltip)
    if tooltip then
        local petID = tooltip.battlePetID
        if IsSecretValue(petID) or petID ~= nil then
            return petID
        end
    end

    if tooltip and type(tooltip.GetOwner) == "function" then
        return FindPetIDOnFrame(tooltip:GetOwner())
    end

    return nil
end

function JournalIDs:InstallCompanionTooltipHook(tooltip)
    if not tooltip or tooltip.DXPSCompanionPetHooked or type(tooltip.SetCompanionPet) ~= "function" then
        return false
    end

    hooksecurefunc(tooltip, "SetCompanionPet", function(parentTooltip, petID)
        self:ShowForPetID(parentTooltip, petID)
    end)
    tooltip.DXPSCompanionPetHooked = true
    return true
end

function JournalIDs:InstallStandardTooltipHooks()
    -- Widget methods can become useful only after Blizzard UI modules load, so these
    -- two hooks are retried even after the global tooltip hooks are installed.
    self:InstallCompanionTooltipHook(GameTooltip)
    self:InstallCompanionTooltipHook(ItemRefTooltip)

    if self.hooksInstalled then
        return true
    end

    if type(BattlePetToolTip_Show) == "function" then
        hooksecurefunc("BattlePetToolTip_Show", function(speciesID, level, rarity, maxHealth, power, speed)
            local petID = self:ResolvePetIDForTooltip(BattlePetTooltip)
            self:ShowForSpeciesStats(BattlePetTooltip, speciesID, level, rarity, maxHealth, power, speed, petID)
        end)
    end

    if type(FloatingBattlePet_Show) == "function" then
        hooksecurefunc("FloatingBattlePet_Show", function(speciesID, level, rarity, maxHealth, power, speed, _, petID)
            self:ShowForSpeciesStats(FloatingBattlePetTooltip, speciesID, level, rarity, maxHealth, power, speed, petID)
        end)
    end

    self.hooksInstalled = true
    return true
end

function JournalIDs:InstallJournalTooltipHooks()
    if self.journalHooksInstalled then
        return true
    end

    local installed = false

    if type(PetJournalDragButtonMixin) == "table" and type(PetJournalDragButtonMixin.OnEnter) == "function" then
        hooksecurefunc(PetJournalDragButtonMixin, "OnEnter", function(button)
            local petID = FindPetIDOnFrame(button)
            if petID and GameTooltip and GameTooltip:IsShown() then
                self:ShowForPetID(GameTooltip, petID)
            end
        end)
        installed = true
    end

    if type(PetJournalLoadoutDragButtonMixin) == "table" and type(PetJournalLoadoutDragButtonMixin.OnEnter) == "function" then
        hooksecurefunc(PetJournalLoadoutDragButtonMixin, "OnEnter", function(button)
            local petID = FindPetIDOnFrame(button)
            if petID and GameTooltip and GameTooltip:IsShown() then
                self:ShowForPetID(GameTooltip, petID)
            end
        end)
        installed = true
    end

    if installed then
        self.journalHooksInstalled = true
    end
    return installed
end

function JournalIDs:InstallPetCardTooltipHook()
    if self.petCardHookInstalled then
        return true
    end

    if not PetJournalPetCardPetInfo or type(PetJournalPetCardPetInfo.HookScript) ~= "function" then
        return false
    end

    PetJournalPetCardPetInfo:HookScript("OnEnter", function()
        if not GameTooltip or not GameTooltip:IsShown() or not PetJournalPetCard then
            return
        end
        local petID = PetJournalPetCard.petID
        if petID then
            self:ShowForPetID(GameTooltip, petID)
        elseif PetJournalPetCard.speciesID then
            local info = self:GetInfoBySpeciesID(PetJournalPetCard.speciesID)
            if info then
                self:ShowTooltipStack(GameTooltip, info, { speciesID = info.speciesID })
            end
        end
    end)

    self.petCardHookInstalled = true
    return true
end

function JournalIDs:InstallTooltipHooks()
    self:InstallStandardTooltipHooks()
    self:InstallJournalTooltipHooks()
    self:InstallPetCardTooltipHook()
end

function JournalIDs:AppendPetTooltip(tooltip, petID)
    -- Compatibility helper retained for future modules; it now shows the dedicated stack.
    return self:ShowForPetID(tooltip, petID)
end

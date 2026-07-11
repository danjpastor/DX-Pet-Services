local addonName, ns = ...

local PetTooltips = {
    hooksInstalled = false,
    journalHooksInstalled = false,
    petCardHookInstalled = false,
    parentHideHooks = {},
}
ns:RegisterModule("PetTooltips", PetTooltips)

local BreedInfo

local function IsSecretValue(value)
    if type(issecretvalue) ~= "function" then
        return false
    end

    local ok, result = pcall(issecretvalue, value)
    return ok and result == true
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

-- Lifecycle

function PetTooltips:OnInitialize()
    BreedInfo = ns:GetModule("BreedInfo")
    ns.Events:Register("ADDON_LOADED", self, "OnAddonLoaded")
    self:InstallTooltipHooks()
end

function PetTooltips:OnEnable()
    self:InstallTooltipHooks()
end

function PetTooltips:OnAddonLoaded(_, loadedAddon)
    if loadedAddon == "Blizzard_Collections" or loadedAddon == "Blizzard_FrameXML" then
        self:InstallTooltipHooks()
    end
end

-- Tooltip content

function PetTooltips:HideTooltip()
    if BreedInfo then
        BreedInfo:HideTooltip()
    end
end

function PetTooltips:HookParentHide(parent)
    if not parent or self.parentHideHooks[parent] or type(parent.HookScript) ~= "function" then
        return
    end

    parent:HookScript("OnHide", function()
        self:HideTooltip()
        if BreedInfo then
            BreedInfo:RestoreParentTooltipWidth(parent)
        end
    end)
    self.parentHideHooks[parent] = true
end

function PetTooltips:ShowContext(parent, context)
    if not BreedInfo or not parent or not context then
        return false
    end

    self:HookParentHide(parent)
    local tooltip = BreedInfo:ShowTooltip(parent, context)

    -- If the official Battle Pet BreedID hook runs after ours, remove the
    -- duplicate DX panel on the next frame and let the official tooltip remain.
    if BreedInfo:IsExternalAddonLoaded() then
        C_Timer.After(0, function()
            if parent and parent.IsShown and parent:IsShown() then
                local external = BreedInfo:GetExternalTooltip(parent)
                if external then
                    BreedInfo:HideTooltip()
                end
            end
        end)
    end

    return tooltip ~= nil
end

function PetTooltips:ShowForPetID(parent, petID)
    if not BreedInfo or not parent or not petID or IsSecretValue(petID) then
        return false
    end

    local context = BreedInfo:BuildPetContext(petID)
    if not context then
        return false
    end

    return self:ShowContext(parent, context)
end

function PetTooltips:ShowForSpeciesStats(parent, speciesID, level, rarity, maxHealth, power, speed, petID)
    if not BreedInfo or not parent or not speciesID then
        return false
    end

    local context
    if petID and not IsSecretValue(petID) then
        context = BreedInfo:BuildPetContext(petID)
    end
    if not context then
        context = BreedInfo:BuildStatsContext(speciesID, level, rarity, maxHealth, power, speed)
    end
    if not context then
        return false
    end

    return self:ShowContext(parent, context)
end

function PetTooltips:ResolvePetIDForTooltip(tooltip)
    if not tooltip then
        return nil
    end

    local petID = tooltip.battlePetID
    if IsSecretValue(petID) or petID ~= nil then
        return petID
    end

    if type(tooltip.GetOwner) == "function" then
        local ok, owner = pcall(tooltip.GetOwner, tooltip)
        if ok and owner then
            return FindPetIDOnFrame(owner)
        end
    end

    return nil
end

-- Hook installation

function PetTooltips:InstallCompanionTooltipHook(tooltip)
    if not tooltip or tooltip.DXPSCompanionPetHooked or type(tooltip.SetCompanionPet) ~= "function" then
        return false
    end

    hooksecurefunc(tooltip, "SetCompanionPet", function(parentTooltip, petID)
        self:ShowForPetID(parentTooltip, petID)
    end)
    tooltip.DXPSCompanionPetHooked = true
    return true
end

function PetTooltips:InstallStandardTooltipHooks()
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

function PetTooltips:InstallJournalTooltipHooks()
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

function PetTooltips:InstallPetCardTooltipHook()
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

        if PetJournalPetCard.petID then
            self:ShowForPetID(GameTooltip, PetJournalPetCard.petID)
        elseif PetJournalPetCard.speciesID and BreedInfo then
            self:ShowContext(GameTooltip, { speciesID = PetJournalPetCard.speciesID })
        end
    end)

    self.petCardHookInstalled = true
    return true
end

function PetTooltips:InstallTooltipHooks()
    self:InstallStandardTooltipHooks()
    self:InstallJournalTooltipHooks()
    self:InstallPetCardTooltipHook()
end

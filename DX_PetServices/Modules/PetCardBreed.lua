local addonName, ns = ...

local PetCardBreed = {
    hookInstalled = false,
    tooltip = nil,
}
ns:RegisterModule("PetCardBreed", PetCardBreed)

local BreedInfo
local Arrays

local STAT_NAMES = {
    PET_BATTLE_STAT_HEALTH or "Health",
    PET_BATTLE_STAT_POWER or "Power",
    PET_BATTLE_STAT_SPEED or "Speed",
}

local BREED_LABEL = "Breed"
local BREED_EXPLANATION = "Determines how stats gained at each level are distributed."

local function AddHeader(tooltip, text)
    tooltip:AddLine(text, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end

local function CopyFont(source, target)
    if not source or not target or type(source.GetFont) ~= "function" or type(target.SetFont) ~= "function" then
        return
    end

    local fontFile, fontSize, fontFlags = source:GetFont()
    if fontFile and fontSize then
        target:SetFont(fontFile, fontSize, fontFlags)
    end
end

local function MatchBreedSectionScale(tooltip, breedHeaderLine, breedBodyStartLine)
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    if not name then
        return
    end

    local qualityHeader = _G[name .. "TextLeft1"]
    local qualityBody = _G[name .. "TextLeft2"]
    local breedHeader = _G[name .. "TextLeft" .. breedHeaderLine]
    CopyFont(qualityHeader, breedHeader)

    local numLines = tooltip:NumLines()
    for line = breedBodyStartLine, numLines do
        CopyFont(qualityBody, _G[name .. "TextLeft" .. line])
    end
end

-- Lifecycle

function PetCardBreed:OnInitialize()
    BreedInfo = ns:GetModule("BreedInfo")
    Arrays = ns.BreedArrays
    ns.Events:Register("ADDON_LOADED", self, "OnAddonLoaded")
    self:InstallHook()
end

function PetCardBreed:OnEnable()
    self:InstallHook()
end

function PetCardBreed:OnAddonLoaded(_, loadedAddon)
    if loadedAddon == "Blizzard_Collections" then
        self:InstallHook()
    end
end

function PetCardBreed:InstallHook()
    if self.hookInstalled then
        return true
    end
    if type(PetJournal_UpdatePetCard) ~= "function" then
        return false
    end

    hooksecurefunc("PetJournal_UpdatePetCard", function(card)
        self:ModifyCard(card)
    end)

    self.hookInstalled = true
    return true
end

-- Breed tooltip

function PetCardBreed:GetTooltip()
    if self.tooltip then
        return self.tooltip
    end

    local tooltip = CreateFrame("GameTooltip", "DXPS_PetCardInfoTooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    self.tooltip = tooltip
    return tooltip
end

function PetCardBreed:ShowTooltip(footer)
    if not BreedInfo or not footer or not footer.DXPSPetID then
        return
    end

    local display = BreedInfo:GetPetCardDisplay(footer.DXPSPetID)
    if not display then
        return
    end

    local tooltip = self:GetTooltip()
    tooltip:SetOwner(footer, "ANCHOR_RIGHT", -54, 0)
    tooltip:ClearLines()

    -- Use the DX selected-pet footer tooltip information and order.
    AddHeader(tooltip, PET_BATTLE_STAT_QUALITY or "Quality")
    tooltip:AddLine(PET_BATTLE_TOOLTIP_RARITY or "Higher quality pets have stronger stats.", 1, 1, 1, true)

    tooltip:AddLine(" ")
    AddHeader(tooltip, BREED_LABEL)
    tooltip:AddLine(BREED_EXPLANATION, 1, 1, 1, true)

    if type(display.breedID) == "number" then
        tooltip:AddLine(" ")
        tooltip:AddLine(display.name or "", 1, 1, 1)

        local breedStats = Arrays and Arrays.BreedStats and Arrays.BreedStats[display.breedID]
        if type(breedStats) == "table" then
            for stat, bonus in ipairs(breedStats) do
                if type(bonus) == "number" and bonus > 0 then
                    tooltip:AddLine(string.format("+ %d%% %s", bonus * 50, STAT_NAMES[stat] or ""), 1, 1, 1)
                end
            end
        end
    end

    -- The first tooltip line automatically uses Blizzard's larger tooltip
    -- header font. Apply that same scale to the later Breed heading, then use
    -- the Quality body font for all Breed body lines so both sections are
    -- visually equal.
    MatchBreedSectionScale(tooltip, 4, 5)
    tooltip:Show()
end

function PetCardBreed:HideTooltip()
    if self.tooltip then
        self.tooltip:Hide()
    end
end

-- Pet card integration

function PetCardBreed:ModifyCard(card)
    if not BreedInfo or not card or not card.petID then
        return
    end

    local footer = card.QualityFrame
    if not footer or not footer.quality or not footer:IsShown() then
        return
    end

    local display = BreedInfo:GetPetCardDisplay(card.petID)
    if not display or not display.name or display.name == "" then
        return
    end

    -- Use DX's selected-card integration: reuse Blizzard's
    -- existing QualityFrame in place rather than adding a new row or frame.
    -- Give the larger label a little more breathing room than the original.
    footer:SetWidth(180)

    local region = footer:GetRegions()
    if region then
        region:Hide()
    end

    local qualityText = footer.quality:GetText() or ""
    footer.quality:SetText((display.icon or "") .. qualityText .. " " .. display.name)

    -- Enlarge the existing Blizzard font once, then position it slightly lower.
    if not footer.DXPSOriginalFontSize then
        local fontFile, fontSize, fontFlags = footer.quality:GetFont()
        if fontFile and fontSize then
            footer.DXPSOriginalFontSize = fontSize
            footer.quality:SetFont(fontFile, fontSize + 2, fontFlags)
        end
    end
    footer.quality:ClearAllPoints()
    footer.quality:SetPoint("LEFT", footer, "LEFT", 4, -3)

    footer.DXPSPetID = card.petID
    footer:SetScript("OnEnter", function(frame)
        self:ShowTooltip(frame)
    end)
    footer:SetScript("OnLeave", function()
        self:HideTooltip()
    end)
    footer:SetScript("OnHide", function()
        self:HideTooltip()
    end)
end

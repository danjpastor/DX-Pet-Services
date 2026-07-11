local addonName, ns = ...

local JournalUI = {
    integrated = false,
    applyingFilter = false,
    hooksInstalled = false,
    menusInstalled = false,
    autoSummonButton = nil,
}
ns:RegisterModule("JournalUI", JournalUI)

local Favorites
local AutoSummon

local function AddMenuButton(rootDescription, text, callback)
    rootDescription:CreateButton(text, callback)
end

-- Lifecycle

function JournalUI:OnInitialize()
    Favorites = ns:GetModule("Favorites")
    AutoSummon = ns:GetModule("AutoSummon")

    ns.Events:Register("ADDON_LOADED", self, "OnAddonLoaded")
    ns.Events:Register("PET_JOURNAL_LIST_UPDATE", self, "OnPetJournalListUpdate")
    ns.Events:Register("NEW_PET_ADDED", self, "OnPetCollectionChanged")
    ns.Events:Register("PET_JOURNAL_PET_DELETED", self, "OnPetCollectionChanged")

    self:TryIntegrate()
end

function JournalUI:OnEnable()
    self:TryIntegrate()
end

function JournalUI:OnAddonLoaded(_, loadedAddon)
    if loadedAddon == "Blizzard_Collections" then
        self:TryIntegrate()
    end
end

function JournalUI:OnPetJournalListUpdate()
    if self.integrated and Favorites:GetFilterMode() ~= "ALL" then
        self:ApplyCharacterFilter()
    end
end

function JournalUI:OnPetCollectionChanged()
    if self.integrated then
        self:RefreshAll()
    end
end

function JournalUI:TryIntegrate()
    if self.integrated then
        return true
    end

    if not PetJournal or not PetJournal.ScrollBox then
        return false
    end

    if type(PetJournal_UpdatePetList) ~= "function" then
        return false
    end

    self:InstallHooks()
    self:InstallMenuIntegration()
    self:CreateAutoSummonButton()
    self.integrated = true
    self:RefreshAll()
    return true
end


-- Auto Summon button

function JournalUI:ShowAutoSummonTooltip(owner)
    if not AutoSummon then
        return
    end

    local mode = AutoSummon:GetMode()

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Auto Summon Pet", HIGHLIGHT_FONT_COLOR:GetRGB())

    if mode == "ON" then
        GameTooltip:AddLine("Summoning from this character's favorite pets.", 0.35, 0.78, 1.0, true)
        GameTooltip:AddLine("Automatically summons a favorite whenever no companion is active.", nil, nil, nil, true)
    elseif mode == "RANDOM" then
        GameTooltip:AddLine("Summoning randomly from your pet collection.", 0.35, 0.78, 1.0, true)
        GameTooltip:AddLine("Automatically summons a random pet whenever no companion is active.", nil, nil, nil, true)
    else
        GameTooltip:AddLine("Auto Summon is off.", nil, nil, nil, true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to cycle: OFF -> ON -> RANDOM", 0.75, 0.75, 0.75)
    GameTooltip:Show()
end

function JournalUI:CreateAutoSummonButton()
    if self.autoSummonButton or not PetJournal then
        return self.autoSummonButton
    end

    local button = CreateFrame("Button", "DXPetServicesAutoSummonButton", PetJournal, "UIPanelButtonTemplate")

    local summonButton = _G.PetJournalSummonButton
    local findBattleButton = _G.PetJournalFindBattle
    if summonButton and findBattleButton then
        -- Keep the control compact while centering it in the available gap.
        -- The invisible anchor follows Blizzard's native footer buttons, so the
        -- DX button stays perfectly aligned without stretching across the gap.
        local anchor = CreateFrame("Frame", nil, PetJournal)
        anchor:SetPoint("LEFT", summonButton, "RIGHT", 8, 0)
        anchor:SetPoint("RIGHT", findBattleButton, "LEFT", -8, 0)
        anchor:SetPoint("BOTTOM", summonButton, "BOTTOM", 0, 0)
        anchor:SetHeight(summonButton:GetHeight())

        button:SetHeight(summonButton:GetHeight())
        button:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        self.autoSummonAnchor = anchor
    else
        -- Safe fallback for unexpected Pet Journal layouts.
        button:SetHeight(22)
        button:SetPoint("BOTTOM", PetJournal, "BOTTOM", 0, 8)
    end

    button:SetFrameLevel((PetJournal:GetFrameLevel() or 0) + 5)

    -- Size to the longest of the three state labels plus comfortable native-button padding.
    -- This keeps the control compact while guaranteeing "Auto Summon: RANDOM" never crowds the edges.
    local fontString = button:GetFontString()
    local longestWidth = 0
    local buttonWidth = 165 -- safe fallback if the template font string is unexpectedly unavailable
    if fontString then
        local labels = {
            "Auto Summon: OFF",
            "Auto Summon: ON",
            "Auto Summon: RANDOM",
        }
        for _, label in ipairs(labels) do
            fontString:SetText(label)
            longestWidth = math.max(longestWidth, fontString:GetStringWidth() or 0)
        end
        buttonWidth = math.max(140, math.ceil(longestWidth + 32))
    end
    button:SetWidth(buttonWidth)

    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function()
        if not AutoSummon then
            return
        end

        local mode = AutoSummon:CycleMode()
        if mode == "ON" and not C_PetJournal.HasFavoritePets() then
            ns:Print("Auto Summon is on, but this character has no favorite pets.")
        end

        if GameTooltip:IsOwned(button) then
            self:ShowAutoSummonTooltip(button)
        end
    end)

    button:SetScript("OnEnter", function(owner)
        self:ShowAutoSummonTooltip(owner)
    end)

    button:SetScript("OnLeave", GameTooltip_Hide)

    self.autoSummonButton = button
    if AutoSummon then
        AutoSummon:SetButton(button)
    end

    return button
end

-- Journal integration

function JournalUI:InstallHooks()
    if self.hooksInstalled then
        return
    end

    hooksecurefunc("PetJournal_UpdatePetList", function()
        self:ApplyCharacterFilter()
    end)

    PetJournal:HookScript("OnShow", function()
        self:RefreshAll()
    end)

    self.hooksInstalled = true
end

function JournalUI:InstallMenuIntegration()
    if self.menusInstalled then
        return
    end

    Menu.ModifyMenu("MENU_PET_COLLECTION_FILTER", function(_, rootDescription)
        self:AddFilterMenuEntries(rootDescription)
    end)

    self.menusInstalled = true
end

function JournalUI:AddFilterMenuEntries(rootDescription)
    rootDescription:CreateDivider()
    rootDescription:CreateTitle("DX Character Favorites")

    local currentMode = Favorites:GetFilterMode()
    for _, mode in ipairs(Favorites.filterOrder) do
        local label = Favorites.filterLabels[mode]
        local text = currentMode == mode and ("|cff57c7ff✓|r " .. label) or label
        AddMenuButton(rootDescription, text, function()
            Favorites:SetFilterMode(mode)
            self:RefreshAll()
        end)
    end
end

-- Character favorite filter

function JournalUI:ApplyCharacterFilter()
    if self.applyingFilter or not self.integrated then
        return
    end

    if Favorites:GetFilterMode() == "ALL" then
        return
    end

    self.applyingFilter = true

    local provider = CreateDataProvider()
    local visiblePets = C_PetJournal.GetNumPets() or 0

    for index = 1, visiblePets do
        local petID, speciesID = C_PetJournal.GetPetInfoByIndex(index)
        if speciesID and Favorites:MatchesFilter(petID) then
            provider:Insert({
                index = index,
                petID = petID,
                speciesID = speciesID,
                owned = petID ~= nil,
            })
        end
    end

    local retain = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition or nil
    PetJournal.ScrollBox:SetDataProvider(provider, retain)

    self.applyingFilter = false
end

function JournalUI:RefreshAll()
    if not self.integrated then
        self:TryIntegrate()
        if not self.integrated then
            return
        end
    end

    PetJournal_UpdatePetList()
end

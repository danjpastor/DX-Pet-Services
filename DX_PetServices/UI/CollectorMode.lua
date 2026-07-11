local addonName, ns = ...

local CollectorMode = {
    integrated = false,
    hooksInstalled = false,
    modeSwitch = nil,
    collectorFrame = nil,
    lastSpeciesID = nil,
    visibilityEnforceToken = 0,
    nativeLayout = nil,
    collectorFooterAnchor = nil,
    collectorFooterYOffset = nil,
}
ns:RegisterModule("CollectorMode", CollectorMode)

local MODE_BATTLE = "BATTLE"
local MODE_COLLECTOR = "COLLECTOR"

-- Frame helpers

local function GetPetCard()
    return _G.PetJournalPetCard or (PetJournal and PetJournal.PetCard)
end

local function GetCloseButton()
    return _G.CollectionsJournalCloseButton
        or (_G.CollectionsJournal and CollectionsJournal.CloseButton)
        or (PetJournal and PetJournal.CloseButton)
end

local function GetHealPetFrame()
    return (PetJournal and PetJournal.HealPetSpellFrame)
        or _G.PetJournalHealPetSpellFrame
end

local function GetRandomPetFrame()
    return (PetJournal and PetJournal.SummonRandomPetSpellFrame)
        or _G.PetJournalSummonRandomPetSpellFrame
        or (PetJournal and PetJournal.SummonRandomPetButton)
        or _G.PetJournalSummonRandomPetButton
end

local function GetSummonButton()
    return (PetJournal and PetJournal.SummonButton)
        or _G.PetJournalSummonButton
end

local function GetAutoSummonButton()
    local journalUI = ns:GetModule("JournalUI")
    return journalUI and journalUI.autoSummonButton
end

local function CaptureFramePoints(frame)
    if not frame or type(frame.GetNumPoints) ~= "function" then
        return nil
    end

    local points = {}
    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(index)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end
    return points
end

local function RestoreFramePoints(frame, points)
    if not frame or not points or #points == 0 then
        return false
    end

    frame:ClearAllPoints()
    for _, data in ipairs(points) do
        frame:SetPoint(data.point, data.relativeTo, data.relativePoint, data.xOfs, data.yOfs)
    end
    return true
end

local function CopyFramePoints(target, source)
    if not target or not source then
        return false
    end
    return RestoreFramePoints(target, CaptureFramePoints(source))
end

local function AddUniqueFrame(frames, seen, frame)
    if frame and not seen[frame] then
        seen[frame] = true
        frames[#frames + 1] = frame
    end
end

local function GetBattleOnlyFrames()
    local frames, seen = {}, {}

    AddUniqueFrame(frames, seen, PetJournal and PetJournal.PetCardInset)
    AddUniqueFrame(frames, seen, PetJournal and PetJournal.RightInset)
    AddUniqueFrame(frames, seen, _G.PetJournalRightInset)
    AddUniqueFrame(frames, seen, GetPetCard())

    AddUniqueFrame(frames, seen, PetJournal and PetJournal.Loadout)
    AddUniqueFrame(frames, seen, _G.PetJournalLoadout)
    AddUniqueFrame(frames, seen, PetJournal and PetJournal.loadoutBorder)
    AddUniqueFrame(frames, seen, _G.PetJournalLoadoutBorder)

    AddUniqueFrame(frames, seen, GetHealPetFrame())

    AddUniqueFrame(frames, seen, PetJournal and PetJournal.FindBattleButton)
    AddUniqueFrame(frames, seen, _G.PetJournalFindBattleButton)
    AddUniqueFrame(frames, seen, _G.PetJournalFindBattle)

    return frames
end

local function SetFrameShown(frame, shown)
    if frame then
        frame:SetShown(shown)
    end
end

local VOIDLIGHT_MARL_RAW_ICON = "INV_112_RaidTrinkets_VoidPrism.BLP"
local VOIDLIGHT_MARL_ICON_TAG = "|T7137586:14:14:0:0|t"

local function FormatSourceText(sourceText)
    if type(sourceText) ~= "string" or sourceText == "" then
        return sourceText
    end

    if not sourceText:find(VOIDLIGHT_MARL_RAW_ICON, 1, true) then
        return sourceText
    end

    -- Do not rewrite an already-valid texture escape. Some 12.0.7 source
    -- strings expose the raw icon filename instead; convert only that broken
    -- placeholder to the native Voidlight Marl icon FileDataID.
    if sourceText:find("|T[^|]-INV_112_RaidTrinkets_VoidPrism%.BLP[^|]-|t") then
        return sourceText
    end

    sourceText = sourceText:gsub("%[INV_112_RaidTrinkets_VoidPrism%.BLP%]", VOIDLIGHT_MARL_ICON_TAG)
    sourceText = sourceText:gsub("%(INV_112_RaidTrinkets_VoidPrism%.BLP%)", VOIDLIGHT_MARL_ICON_TAG)
    sourceText = sourceText:gsub("INV_112_RaidTrinkets_VoidPrism%.BLP", VOIDLIGHT_MARL_ICON_TAG)
    return sourceText
end

-- Pet data

local function GetSelectedPetContext()
    local card = GetPetCard()
    if not card then
        return nil, nil
    end

    return card.petID, card.speciesID
end

local function GetSpeciesInfo(speciesID)
    if not speciesID or not C_PetJournal then
        return nil
    end

    local info = {
        speciesID = speciesID,
    }

    if type(C_PetJournal.GetPetInfoBySpeciesID) == "function" then
        local name, icon, petType, companionID, sourceText, description, isWild, canBattle,
            isTradeable, isUnique, obtainable, displayID = C_PetJournal.GetPetInfoBySpeciesID(speciesID)

        info.name = name
        info.icon = icon
        info.petType = petType
        info.companionID = companionID
        info.sourceText = sourceText
        info.description = description
        info.isWild = isWild
        info.canBattle = canBattle
        info.isTradeable = isTradeable
        info.isUnique = isUnique
        info.obtainable = obtainable
        info.displayID = displayID
    end

    return info
end

local function MergeOwnedPetInfo(info, petID)
    if not info or not petID or not C_PetJournal then
        return info
    end

    if type(C_PetJournal.GetPetInfoTableByPetID) == "function" then
        local owned = C_PetJournal.GetPetInfoTableByPetID(petID)
        if type(owned) == "table" then
            info.name = owned.customName or owned.name or info.name
            info.icon = owned.icon or info.icon
            info.sourceText = owned.sourceText or info.sourceText
            info.description = owned.description or info.description
            info.displayID = owned.displayID or info.displayID
            info.petType = owned.petType or info.petType
        end
    elseif type(C_PetJournal.GetPetInfoByPetID) == "function" then
        local speciesID, customName, level, xp, maxXp, displayID, isFavorite, name, icon, petType = C_PetJournal.GetPetInfoByPetID(petID)
        info.name = customName or name or info.name
        info.icon = icon or info.icon
        info.displayID = displayID or info.displayID
        info.petType = petType or info.petType
        info.speciesID = speciesID or info.speciesID
    end

    return info
end

local function ResolveSelectedPetInfo()
    local petID, speciesID = GetSelectedPetContext()
    if not speciesID then
        return nil
    end

    local info = GetSpeciesInfo(speciesID)
    if not info then
        return nil
    end

    info.petID = petID
    MergeOwnedPetInfo(info, petID)

    if not info.displayID and type(C_PetJournal.GetDisplayIDByIndex) == "function" then
        info.displayID = C_PetJournal.GetDisplayIDByIndex(speciesID, 1)
    end

    return info
end

-- Lifecycle

function CollectorMode:OnInitialize()
    local defaultView = ns.db and ns.db.settings and ns.db.settings.defaultView
    ns.charDB.journal.viewMode = defaultView == MODE_COLLECTOR and MODE_COLLECTOR or MODE_BATTLE

    ns.Events:Register("ADDON_LOADED", self, "OnAddonLoaded")
    ns.Events:Register("PET_JOURNAL_LIST_UPDATE", self, "OnPetJournalChanged")
    ns.Events:Register("NEW_PET_ADDED", self, "OnPetJournalChanged")
    ns.Events:Register("PET_JOURNAL_PET_DELETED", self, "OnPetJournalChanged")
    ns.Events:Register("UI_MODEL_SCENE_INFO_UPDATED", self, "OnModelSceneInfoUpdated")

    self:TryIntegrate()
end

function CollectorMode:OnEnable()
    self:TryIntegrate()
end

function CollectorMode:OnAddonLoaded(_, loadedAddon)
    if loadedAddon == "Blizzard_Collections" then
        self:TryIntegrate()
    end
end

function CollectorMode:OnPetJournalChanged()
    if self.integrated and self:IsCollectorMode() then
        self:RefreshSelectedPet()
        self:EnforceModeVisibility()
    end
end

function CollectorMode:OnModelSceneInfoUpdated()
    if self.integrated and self:IsCollectorMode() and PetJournal and PetJournal:IsVisible() then
        self:RefreshSelectedPet(true)
    end
end

-- Mode state

function CollectorMode:GetMode()
    local mode = ns.charDB and ns.charDB.journal and ns.charDB.journal.viewMode
    if mode ~= MODE_COLLECTOR then
        return MODE_BATTLE
    end
    return MODE_COLLECTOR
end

function CollectorMode:IsCollectorMode()
    return self:GetMode() == MODE_COLLECTOR
end

function CollectorMode:SetMode(mode)
    if mode ~= MODE_COLLECTOR then
        mode = MODE_BATTLE
    end

    ns.charDB.journal.viewMode = mode
    self:ApplyMode()
    return mode
end

function CollectorMode:SetDefaultMode(mode)
    if mode ~= MODE_COLLECTOR then
        mode = MODE_BATTLE
    end

    ns.db.settings.defaultView = mode
    return self:SetMode(mode)
end

function CollectorMode:ToggleMode()
    if self:IsCollectorMode() then
        return self:SetMode(MODE_BATTLE)
    end
    return self:SetMode(MODE_COLLECTOR)
end

-- UI construction

function CollectorMode:TryIntegrate()
    if self.integrated then
        return true
    end

    if not PetJournal or not GetPetCard() or not PetJournal.PetCardInset or not PetJournal.RightInset then
        return false
    end

    self:CreateCollectorFrame()
    self:CreateModeSwitch()
    self:CaptureNativeLayout()
    self:InstallHooks()

    self.integrated = true
    self:UpdateModeSwitchVisibility()
    self:ApplyMode()
    return true
end

function CollectorMode:CreateModeSwitch()
    if self.modeSwitch or not PetJournal then
        return self.modeSwitch
    end

    local closeButton = GetCloseButton()
    local switchParent = (closeButton and closeButton:GetParent()) or _G.CollectionsJournal or PetJournal
    local switch = CreateFrame("Button", "DXPetServicesModeSwitch", switchParent, "BackdropTemplate")
    switch:SetSize(122, 22)
    switch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    switch:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
    switch:SetBackdropBorderColor(0.45, 0.38, 0.18, 1)

    if closeButton then
        switch:SetFrameStrata(closeButton:GetFrameStrata())
        switch:SetFrameLevel((closeButton:GetFrameLevel() or 0) + 2)
        switch:SetPoint("RIGHT", closeButton, "LEFT", -7, 0)
    else
        switch:SetFrameStrata(switchParent:GetFrameStrata())
        switch:SetFrameLevel((switchParent:GetFrameLevel() or 0) + 50)
        switch:SetPoint("TOPRIGHT", switchParent, "TOPRIGHT", -34, -3)
    end

    local selected = switch:CreateTexture(nil, "ARTWORK")
    selected:SetTexture("Interface\\Buttons\\WHITE8x8")
    selected:SetVertexColor(0.20, 0.45, 0.72, 0.72)
    selected:SetSize(58, 16)
    switch.Selected = selected

    local divider = switch:CreateTexture(nil, "OVERLAY")
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetVertexColor(0.45, 0.38, 0.18, 0.8)
    divider:SetWidth(1)
    divider:SetPoint("TOP", switch, "TOP", 0, -3)
    divider:SetPoint("BOTTOM", switch, "BOTTOM", 0, 3)

    local battle = switch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    battle:SetPoint("CENTER", switch, "LEFT", 31, 0)
    battle:SetText("Battle")
    switch.BattleLabel = battle

    local collector = switch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collector:SetPoint("CENTER", switch, "RIGHT", -31, 0)
    collector:SetText("Collector")
    switch.CollectorLabel = collector

    switch:SetScript("OnClick", function()
        self:ToggleMode()
    end)

    switch:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Pet Journal View", HIGHLIGHT_FONT_COLOR:GetRGB())
        if self:IsCollectorMode() then
            GameTooltip:AddLine("Collector Mode", 0.35, 0.78, 1.0)
            GameTooltip:AddLine("A collection-focused pet view with a large 3D preview, description, and source information.", nil, nil, nil, true)
        else
            GameTooltip:AddLine("Battle Pet Mode", 0.35, 0.78, 1.0)
            GameTooltip:AddLine("The standard Battle Pet Journal with pet details, loadouts, and battle controls.", nil, nil, nil, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to switch views.", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    switch:SetScript("OnLeave", GameTooltip_Hide)

    self.modeSwitch = switch
    self:UpdateModeSwitch()
    return switch
end

function CollectorMode:UpdateModeSwitch()
    local switch = self.modeSwitch
    if not switch then
        return
    end

    switch.Selected:ClearAllPoints()
    if self:IsCollectorMode() then
        switch.Selected:SetPoint("RIGHT", switch, "RIGHT", -3, 0)
        switch.BattleLabel:SetTextColor(0.62, 0.62, 0.62)
        switch.CollectorLabel:SetTextColor(1.0, 0.82, 0.0)
    else
        switch.Selected:SetPoint("LEFT", switch, "LEFT", 3, 0)
        switch.BattleLabel:SetTextColor(1.0, 0.82, 0.0)
        switch.CollectorLabel:SetTextColor(0.62, 0.62, 0.62)
    end
end

function CollectorMode:UpdateModeSwitchVisibility()
    if not self.modeSwitch then
        return
    end

    self.modeSwitch:SetShown(PetJournal and PetJournal:IsShown())
end

function CollectorMode:CreateCollectorFrame()
    if self.collectorFrame or not PetJournal then
        return self.collectorFrame
    end

    local frame = CreateFrame("Frame", "DXPetServicesCollectorModeFrame", PetJournal, "InsetFrameTemplate")
    frame:SetPoint("TOPLEFT", PetJournal.PetCardInset, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", PetJournal.RightInset, "BOTTOMRIGHT", 0, 0)
    frame:SetFrameLevel((PetJournal:GetFrameLevel() or 0) + 2)
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    background:SetTexture("Interface\\PetBattles\\MountJournal-BG")
    background:SetTexCoord(0, 0.78515625, 0, 1)
    frame.Background = background

    local modelScene = CreateFrame("ModelScene", nil, frame, "WrappedAndUnwrappedModelScene")
    modelScene:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    modelScene:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    modelScene:SetFrameLevel(frame:GetFrameLevel() + 1)
    modelScene:EnableMouse(true)
    frame.ModelScene = modelScene

    local controls
    local controlsCreated, controlFrame = pcall(CreateFrame, "Frame", nil, modelScene, "ModelSceneControlFrameTemplate")
    if controlsCreated and controlFrame then
        controls = controlFrame
        controls:SetPoint("BOTTOM", modelScene, "BOTTOM", 0, 10)
        controls:SetFrameLevel(modelScene:GetFrameLevel() + 500)

        -- Blizzard's Mount Journal creates the control frame with parentKey="ControlFrame",
        -- which places it directly on the ModelScene object. The inherited
        -- WrappedAndUnwrappedModelScene hover methods look for this exact field.
        modelScene.ControlFrame = controls
        frame.ControlFrame = controls

        controls:SetModelScene(modelScene)
    end

    -- Capture the inherited mixin methods before installing scripts. This mirrors
    -- MountJournal_ModelScene_OnEnter/OnLeave, which forward the hovered model scene
    -- to ModelScene:OnEnter/OnLeave. A direct Show/Hide fallback keeps the toolbar
    -- usable even if Blizzard changes the mixin implementation later.
    local inheritedModelSceneOnEnter = modelScene.OnEnter
    local inheritedModelSceneOnLeave = modelScene.OnLeave

    modelScene:SetScript("OnEnter", function(scene)
        if type(inheritedModelSceneOnEnter) == "function" then
            inheritedModelSceneOnEnter(scene, scene)
        end

        if controls and not controls:IsShown() then
            controls:Show()
        end
    end)

    modelScene:SetScript("OnLeave", function(scene)
        if type(inheritedModelSceneOnLeave) == "function" then
            inheritedModelSceneOnLeave(scene, scene)
        elseif controls then
            controls:Hide()
        end
    end)

    modelScene:SetResetCallback(function()
        if self:IsCollectorMode() then
            self:RefreshSelectedPet(true)
        end
    end)

    -- Start in the same resting state as the Mount Journal: controls are hidden
    -- until the cursor enters the model area.
    if controls then
        controls:Hide()
    end

    local info = CreateFrame("Frame", nil, frame)
    info:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -18)
    info:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -18)
    info:SetHeight(175)
    info:SetFrameLevel(modelScene:GetFrameLevel() + 20)
    info:EnableMouse(false)
    frame.Info = info

    local icon = info:CreateTexture(nil, "ARTWORK")
    icon:SetSize(38, 38)
    icon:SetPoint("TOPLEFT", info, "TOPLEFT", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Box_PetCarrier_01")
    frame.Icon = icon

    local name = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", info, "RIGHT", 0, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText("Pet")
    frame.Name = name

    local source = info:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    source:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    source:SetPoint("RIGHT", info, "RIGHT", 0, 0)
    source:SetJustifyH("LEFT")
    source:SetJustifyV("TOP")
    source:SetWordWrap(true)
    source:SetTextColor(1.0, 0.82, 0.0)
    frame.Source = source

    local description = info:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    description:SetPoint("TOPLEFT", source, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", info, "RIGHT", 0, 0)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    frame.Description = description

    local emptyOverlay = CreateFrame("Frame", nil, frame)
    emptyOverlay:SetAllPoints(modelScene)
    emptyOverlay:SetFrameLevel(modelScene:GetFrameLevel() + 30)
    emptyOverlay:EnableMouse(false)

    local noPreview = emptyOverlay:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    noPreview:SetPoint("CENTER", emptyOverlay, "CENTER", 0, -35)
    noPreview:SetText("Preview unavailable for this pet.")
    noPreview:Hide()
    frame.NoPreview = noPreview

    self.collectorFrame = frame
    return frame
end

-- Native control layout

function CollectorMode:CaptureNativeLayout()
    if self.nativeLayout then
        return self.nativeLayout
    end

    local summonButton = GetSummonButton()
    local randomPetFrame = GetRandomPetFrame()
    local autoSummonButton = GetAutoSummonButton()

    self.nativeLayout = {
        summonButton = {
            frame = summonButton,
            points = CaptureFramePoints(summonButton),
        },
        randomPetFrame = {
            frame = randomPetFrame,
            points = CaptureFramePoints(randomPetFrame),
            parent = randomPetFrame and randomPetFrame:GetParent() or nil,
            frameLevel = randomPetFrame and randomPetFrame:GetFrameLevel() or nil,
            frameStrata = randomPetFrame and randomPetFrame:GetFrameStrata() or nil,
        },
        autoSummonButton = {
            frame = autoSummonButton,
            points = CaptureFramePoints(autoSummonButton),
        },
    }

    return self.nativeLayout
end

function CollectorMode:GetCollectorFooterAnchor()
    if self.collectorFooterAnchor then
        return self.collectorFooterAnchor
    end

    if not PetJournal or not self.collectorFrame then
        return nil
    end

    local anchor = CreateFrame("Frame", nil, PetJournal)
    anchor:SetHeight(24)
    anchor:Hide()
    self.collectorFooterAnchor = anchor
    return anchor
end

function CollectorMode:ApplyCollectorControlLayout()
    self:CaptureNativeLayout()

    local summonButton = GetSummonButton()
    local autoSummonButton = GetAutoSummonButton()
    local healPetFrame = GetHealPetFrame()
    local randomPetFrame = GetRandomPetFrame()

    -- Put Blizzard's Summon Random Favorite Pet control in the exact area
    -- normally occupied by Revive Battle Pets.
    if randomPetFrame and healPetFrame then
        if randomPetFrame:GetParent() ~= PetJournal then
            randomPetFrame:SetParent(PetJournal)
        end
        CopyFramePoints(randomPetFrame, healPetFrame)
        if self.collectorFrame then
            randomPetFrame:SetFrameLevel((self.collectorFrame:GetFrameLevel() or 0) + 20)
        end
        SetFrameShown(randomPetFrame, true)
    end

    -- Center Summon and Auto Summon together beneath the Collector preview.
    if summonButton and autoSummonButton and self.collectorFrame then
        local footer = self:GetCollectorFooterAnchor()
        local gap = 10
        local summonWidth = summonButton:GetWidth() or 0
        local autoWidth = autoSummonButton:GetWidth() or 0
        local height = math.max(summonButton:GetHeight() or 22, autoSummonButton:GetHeight() or 22)
        local totalWidth = summonWidth + gap + autoWidth

        if not self.collectorFooterYOffset then
            local journalBottom = PetJournal:GetBottom()
            local summonBottom = summonButton:GetBottom()
            if journalBottom and summonBottom then
                self.collectorFooterYOffset = summonBottom - journalBottom
            end
        end

        footer:ClearAllPoints()
        footer:SetSize(totalWidth, height)
        -- Center the two-button group against the entire Pet Journal window,
        -- not the right-side Collector preview pane.
        footer:SetPoint("BOTTOM", PetJournal, "BOTTOM", 0, self.collectorFooterYOffset or 11)
        footer:Show()

        summonButton:ClearAllPoints()
        summonButton:SetPoint("LEFT", footer, "LEFT", 0, 0)

        autoSummonButton:ClearAllPoints()
        autoSummonButton:SetPoint("RIGHT", footer, "RIGHT", 0, 0)

        SetFrameShown(summonButton, true)
        SetFrameShown(autoSummonButton, true)
    end
end

function CollectorMode:RestoreNativeControlLayout()
    local layout = self.nativeLayout or self:CaptureNativeLayout()
    if not layout then
        return
    end

    if self.collectorFooterAnchor then
        self.collectorFooterAnchor:Hide()
    end

    if layout.summonButton then
        RestoreFramePoints(layout.summonButton.frame, layout.summonButton.points)
    end

    if layout.randomPetFrame then
        local randomPetFrame = layout.randomPetFrame.frame
        if randomPetFrame and layout.randomPetFrame.parent and randomPetFrame:GetParent() ~= layout.randomPetFrame.parent then
            randomPetFrame:SetParent(layout.randomPetFrame.parent)
        end
        if randomPetFrame and layout.randomPetFrame.frameStrata then
            randomPetFrame:SetFrameStrata(layout.randomPetFrame.frameStrata)
        end
        if randomPetFrame and layout.randomPetFrame.frameLevel then
            randomPetFrame:SetFrameLevel(layout.randomPetFrame.frameLevel)
        end
        RestoreFramePoints(randomPetFrame, layout.randomPetFrame.points)
    end

    if layout.autoSummonButton then
        RestoreFramePoints(layout.autoSummonButton.frame, layout.autoSummonButton.points)
    end
end

function CollectorMode:ShowBattleModeFrames()
    for _, frame in ipairs(GetBattleOnlyFrames()) do
        SetFrameShown(frame, true)
    end

    SetFrameShown(GetSummonButton(), true)
    SetFrameShown(GetRandomPetFrame(), true)
    SetFrameShown(GetHealPetFrame(), true)
end

-- Hooks and visibility

function CollectorMode:InstallHooks()
    if self.hooksInstalled then
        return
    end

    local function CollectorRefreshHook()
        if self.integrated and self:IsCollectorMode() then
            self:RefreshSelectedPet()
            self:EnforceModeVisibility()
            self:ScheduleVisibilityEnforcement()
        end
    end

    local function CollectorVisibilityHook()
        if self.integrated and self:IsCollectorMode() then
            self:EnforceModeVisibility()
            self:ScheduleVisibilityEnforcement()
        end
    end

    hooksecurefunc("PetJournal_UpdatePetCard", CollectorRefreshHook)

    hooksecurefunc("PetJournal_UpdatePetLoadOut", CollectorVisibilityHook)

    hooksecurefunc("PetJournal_UpdateFindBattleButton", CollectorVisibilityHook)

    hooksecurefunc("PetJournal_ShowPetCard", CollectorVisibilityHook)

    hooksecurefunc("PetJournal_ShowPetCardByID", CollectorVisibilityHook)

    hooksecurefunc("PetJournal_ShowPetCardBySpeciesID", CollectorVisibilityHook)

    PetJournal:HookScript("OnShow", function()
        self:UpdateModeSwitchVisibility()
        self:ApplyMode()
    end)

    PetJournal:HookScript("OnHide", function()
        self:UpdateModeSwitchVisibility()
    end)

    self.hooksInstalled = true
end

function CollectorMode:ScheduleVisibilityEnforcement()
    self.visibilityEnforceToken = (self.visibilityEnforceToken or 0) + 1
    local token = self.visibilityEnforceToken

    local function Enforce()
        if token ~= self.visibilityEnforceToken then
            return
        end
        if self.integrated and self:IsCollectorMode() then
            self:EnforceModeVisibility()
        end
    end

    C_Timer.After(0, Enforce)
    C_Timer.After(0.05, Enforce)
end

function CollectorMode:EnforceModeVisibility()
    if not self.integrated then
        return
    end

    local collector = self:IsCollectorMode()

    if collector then
        for _, frame in ipairs(GetBattleOnlyFrames()) do
            SetFrameShown(frame, false)
        end

        if PetJournal and PetJournal.SpellSelect then
            SetFrameShown(PetJournal.SpellSelect, false)
        end

        SetFrameShown(self.collectorFrame, true)
        self:ApplyCollectorControlLayout()
    else
        SetFrameShown(self.collectorFrame, false)
    end
end

function CollectorMode:RestoreBattleMode()
    -- Invalidate any deferred Collector visibility pass before restoring native UI.
    self.visibilityEnforceToken = (self.visibilityEnforceToken or 0) + 1

    SetFrameShown(self.collectorFrame, false)
    self:RestoreNativeControlLayout()

    -- Collector Mode hides native parent insets as well as their contents.
    -- Explicitly restore the complete frame tree before asking Blizzard to refresh it.
    self:ShowBattleModeFrames()

    PetJournal_UpdatePetCard(GetPetCard(), true)
    PetJournal_UpdatePetLoadOut(true)
    PetJournal_UpdateFindBattleButton()
    PetJournal_UpdateSummonButtonState()

    -- Native refreshes update contents, but some paths do not re-show parents that
    -- an addon explicitly hid. Reassert the Battle layout after those refreshes.
    self:ShowBattleModeFrames()
end

function CollectorMode:ApplyMode()
    if not self.integrated then
        if not self:TryIntegrate() then
            return
        end
    end

    self:UpdateModeSwitch()
    self:UpdateModeSwitchVisibility()

    if self:IsCollectorMode() then
        self:EnforceModeVisibility()
        self:ScheduleVisibilityEnforcement()
        self:RefreshSelectedPet(true)
    else
        self:RestoreBattleMode()
    end
end

-- Collector model and selected pet

function CollectorMode:ApplyModel(info, forceSceneChange)
    local frame = self.collectorFrame
    local modelScene = frame and frame.ModelScene
    if not frame or not modelScene or not info or not info.speciesID then
        return
    end

    if not info.displayID then
        frame.NoPreview:Show()
        return
    end

    local cardModelSceneID = C_PetJournal.GetPetModelSceneInfoBySpeciesID(info.speciesID)

    if not cardModelSceneID then
        frame.NoPreview:Show()
        return
    end

    frame.NoPreview:Hide()
    modelScene:TransitionToModelSceneID(
        cardModelSceneID,
        _G.CAMERA_TRANSITION_TYPE_IMMEDIATE,
        _G.CAMERA_MODIFICATION_TYPE_MAINTAIN,
        forceSceneChange == true
    )

    local attempts = 0
    local maxAttempts = 4

    local function SetActorModel()
        attempts = attempts + 1

        if not self.collectorFrame or not self.collectorFrame:IsShown() then
            return false
        end
        if self.lastSpeciesID ~= info.speciesID then
            return false
        end

        local actor = modelScene:GetActorByTag("unwrapped") or modelScene:GetActorByTag("pet")
        if not actor then
            if attempts >= maxAttempts then
                frame.NoPreview:Show()
            end
            return false
        end

        actor:Show()
        actor:SetModelByCreatureDisplayID(info.displayID, true)
        actor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None)
        actor:SetAnimation(0, -1)

        frame.NoPreview:Hide()
        return true
    end

    if SetActorModel() then
        return
    end

    C_Timer.After(0, SetActorModel)
    C_Timer.After(0.05, SetActorModel)
    C_Timer.After(0.20, SetActorModel)
end

function CollectorMode:RefreshSelectedPet(forceSceneChange)
    if not self.integrated or not self:IsCollectorMode() or not self.collectorFrame then
        return
    end

    local info = ResolveSelectedPetInfo()
    local frame = self.collectorFrame

    if not info then
        self.lastSpeciesID = nil
        frame.Icon:SetTexture("Interface\\Icons\\INV_Box_PetCarrier_01")
        frame.Name:SetText("No Pet Selected")
        frame.Source:SetText("")
        frame.Description:SetText("Select a pet from the list to preview it.")
        frame.ModelScene:Hide()
        frame.NoPreview:Hide()
        return
    end

    self.lastSpeciesID = info.speciesID
    frame.Icon:SetTexture(info.icon or "Interface\\Icons\\INV_Box_PetCarrier_01")
    frame.Name:SetText(info.name or "Unknown Pet")
    frame.Source:SetText(FormatSourceText(info.sourceText) or "")
    frame.Description:SetText(info.description or "")
    frame.ModelScene:Show()
    frame.NoPreview:Hide()

    self:ApplyModel(info, forceSceneChange)
end


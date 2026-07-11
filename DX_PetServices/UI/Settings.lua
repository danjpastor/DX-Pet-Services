local addonName, ns = ...

local SettingsUI = {
    panel = nil,
    category = nil,
    categoryID = nil,
    controls = {},
}
ns:RegisterModule("SettingsUI", SettingsUI)

local SETTINGS_OBSERVERS = {
    "NPCPetIndicators",
    "MapPetPins",
    "PetTracker",
    "DungeonPetTooltips",
}

local TOGGLE_KEYS = {
    "npcPetDisplays",
    "bossIcons",
    "worldMapIcons",
    "petTrackerMapIcons",
    "petTrackerHideCapturedPins",
    "petTrackerOnlyWhenPanelOpen",
    "petTrackerNearbyAlerts",
    "petTrackerNearbyAlertSound",
    "petTrackerObjectiveTracker",
    "dungeonTooltipInfo",
}

local function SetSetting(key, value)
    ns.db.settings[key] = value

    for _, moduleName in ipairs(SETTINGS_OBSERVERS) do
        ns:GetModule(moduleName):RefreshSettings()
    end
end

local function CreateLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    return label
end

local function CreateSectionHeader(parent, text, y)
    local header = CreateLabel(parent, text, "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetTextColor(0.35, 0.75, 1.0)
    return y - 28
end

function SettingsUI:CreateCheckbox(parent, key, title, description, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 18, y)
    check:SetSize(24, 24)

    local label = CreateLabel(parent, title, "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 4, 1)

    local desc = CreateLabel(parent, description, "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    desc:SetTextColor(0.72, 0.72, 0.72)
    desc:SetWordWrap(true)

    check:SetScript("OnClick", function(button)
        SetSetting(key, button:GetChecked() == true)
    end)

    self.controls[key] = check
    return y - 56
end


function SettingsUI:CreateDropdown(parent, key, title, description, options, y)
    local label = CreateLabel(parent, title, "GameFontNormal")
    label:SetPoint("TOPLEFT", 22, y)

    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -2, -5)
    dropdown:SetWidth(230)
    dropdown:SetupMenu(function(_, rootDescription)
        for _, option in ipairs(options) do
            rootDescription:CreateRadio(option.text, function()
                return ns.db.settings[key] == option.value
            end, function()
                SetSetting(key, option.value)
                dropdown:SetDefaultText(option.text)
            end)
        end
    end)

    local desc = CreateLabel(parent, description, "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 4, -4)
    desc:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    desc:SetTextColor(0.72, 0.72, 0.72)
    desc:SetWordWrap(true)

    dropdown.RefreshValue = function(control)
        local value = ns.db.settings[key]
        for _, option in ipairs(options) do
            if option.value == value then
                control:SetDefaultText(option.text)
                return
            end
        end
    end
    self.controls[key] = dropdown
    return y - 82
end

local function FormatSliderValue(value, step, suffix)
    suffix = suffix or "%"
    if step < 1 then
        return string.format("%.1f%s", value, suffix)
    end
    return tostring(math.floor(value + 0.5)) .. suffix
end

function SettingsUI:CreateSlider(parent, key, title, description, minValue, maxValue, step, y, suffix)
    local label = CreateLabel(parent, title, "GameFontNormal")
    label:SetPoint("TOPLEFT", 22, y)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 2, -8)
    slider:SetWidth(250)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    if slider.Low then slider.Low:SetText(FormatSliderValue(minValue, step, suffix)) end
    if slider.High then slider.High:SetText(FormatSliderValue(maxValue, step, suffix)) end

    local valueText = CreateLabel(parent, "", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", slider, "RIGHT", 12, 0)
    slider.ValueText = valueText
    slider.FormatValue = function(value)
        return FormatSliderValue(value, step, suffix)
    end

    local desc = CreateLabel(parent, description, "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -2, -8)
    desc:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    desc:SetTextColor(0.72, 0.72, 0.72)
    desc:SetWordWrap(true)

    slider:SetScript("OnValueChanged", function(control, value)
        value = math.floor((value / step) + 0.5) * step
        control.ValueText:SetText(control.FormatValue(value))
        if control._refreshing then return end
        ns.db.settings[key] = value
        ns:GetModule("PetTracker"):RefreshSettings()
    end)
    slider:SetScript("OnMouseUp", function(control)
        local value = math.floor((control:GetValue() / step) + 0.5) * step
        SetSetting(key, value)
    end)
    self.controls[key] = slider
    return y - 80
end

function SettingsUI:CreateButton(parent, title, description, buttonText, onClick, y)
    local label = CreateLabel(parent, title, "GameFontNormal")
    label:SetPoint("TOPLEFT", 22, y)

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(150, 24)
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    button:SetText(buttonText)
    button:SetScript("OnClick", onClick)

    local desc = CreateLabel(parent, description, "GameFontHighlightSmall")
    desc:SetPoint("LEFT", button, "RIGHT", 12, 0)
    desc:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    desc:SetTextColor(0.72, 0.72, 0.72)
    desc:SetWordWrap(true)

    return y - 58
end

function SettingsUI:CreateDefaultViewRadios(parent, y)
    local battle = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    battle:SetPoint("TOPLEFT", 22, y)
    battle:SetSize(20, 20)

    local battleLabel = CreateLabel(parent, "Battle Pet Mode", "GameFontNormal")
    battleLabel:SetPoint("LEFT", battle, "RIGHT", 4, 0)

    local collector = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    collector:SetPoint("TOPLEFT", 190, y)
    collector:SetSize(20, 20)

    local collectorLabel = CreateLabel(parent, "Collector Mode", "GameFontNormal")
    collectorLabel:SetPoint("LEFT", collector, "RIGHT", 4, 0)

    local desc = CreateLabel(parent, "Chooses which Pet Journal view is active by default each time you log in.", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 22, y - 25)
    desc:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    desc:SetTextColor(0.72, 0.72, 0.72)

    local function Choose(mode)
        ns.db.settings.defaultView = mode
        ns:GetModule("CollectorMode"):SetDefaultMode(mode)
        self:RefreshControls()
    end

    battle:SetScript("OnClick", function()
        Choose("BATTLE")
    end)
    collector:SetScript("OnClick", function()
        Choose("COLLECTOR")
    end)

    self.controls.defaultBattle = battle
    self.controls.defaultCollector = collector
    return y - 58
end

function SettingsUI:BuildPanel()
    if self.panel then
        return self.panel
    end

    local panel = CreateFrame("Frame", "DXPetServicesSettingsPanel")
    panel.name = "DX Pet Services"
    self.panel = panel

    local scroll = CreateFrame("ScrollFrame", "DXPetServicesSettingsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    self.scrollFrame = scroll

    local content = CreateFrame("Frame", "DXPetServicesSettingsScrollChild", scroll)
    content:SetSize(650, 1)
    scroll:SetScrollChild(content)
    self.scrollChild = content

    scroll:HookScript("OnSizeChanged", function(frame, width)
        content:SetWidth(math.max(1, (width or frame:GetWidth()) - 4))
    end)

    local title = CreateLabel(content, "DX Pet Services", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local subtitle = CreateLabel(content, "Pet Journal, world indicator, map, and dungeon integration settings.", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    subtitle:SetPoint("RIGHT", content, "RIGHT", -24, 0)
    subtitle:SetTextColor(0.72, 0.72, 0.72)

    local y = -68
    y = CreateSectionHeader(content, "Pet Journal", y)
    y = self:CreateDefaultViewRadios(content, y)

    y = CreateSectionHeader(content, "World Indicators", y)
    y = self:CreateCheckbox(content, "npcPetDisplays", "NPC Pet Displays", "Show the collected/available pet badge above vendors and quest NPCs. The badge fades smoothly with distance.", y)
    y = self:CreateCheckbox(content, "bossIcons", "Boss Paw Icons", "Show a blue paw to the right of dungeon and world boss nameplates when they can drop a pet. Hidden during combat.", y)

    y = CreateSectionHeader(content, "Map and Dungeon Information", y)
    y = self:CreateCheckbox(content, "worldMapIcons", "World Map Paw Icons", "Show blue paw markers at known static pet-source NPC locations on both the world map and minimap.", y)
    y = self:CreateCheckbox(content, "petTrackerMapIcons", "Pet Tracker Map Icons", "Show circular wild-pet species icons on zone maps. Known spawn data is drawn at every bundled location.", y)
    y = self:CreateCheckbox(content, "petTrackerHideCapturedPins", "Hide Captured Pet Locations", "Remove a species' Pet Tracker portraits from the world map after you have captured at least one of that pet. Enabled by default.", y)
    y = self:CreateCheckbox(content, "petTrackerOnlyWhenPanelOpen", "Only Show Pet Icons While Tracker Is Open", "Only draw wild-pet portraits while the Pet Tracker side tab is the active world-map panel.", y)
    y = self:CreateDropdown(content, "petTrackerPinMode", "Pet Portrait Display", "Choose every saved location, merge nearby locations, or show one portrait per species. Hold Shift on the map to temporarily show every hidden location.", {
        { value = "ALL", text = "Every Location" },
        { value = "CLUSTER", text = "Cluster Nearby Locations" },
        { value = "SPECIES", text = "One Portrait per Species" },
    }, y)
    y = self:CreateSlider(content, "petTrackerPinSize", "Pet Portrait Size", "Adjust the size of Pet Tracker portraits on the world map.", 60, 160, 10, y)
    y = self:CreateSlider(content, "petTrackerPinOpacity", "Pet Portrait Opacity", "Adjust the opacity of Pet Tracker portraits on the world map.", 25, 100, 5, y)
    y = self:CreateCheckbox(content, "petTrackerNearbyAlerts", "Nearby Uncollected Pet Alerts", "Play an alert when an uncollected wild pet is detected nearby through nameplates, target, focus, minimap/world-map signals, or known spawn proximity. Enabled by default.", y)
    y = self:CreateCheckbox(content, "petTrackerNearbyAlertSound", "Nearby Alert Sound", "Play a sound when the nearby uncollected-pet alert appears.", y)
    y = self:CreateButton(content, "Nearby Alert Preview", "Shows a sample pet alert so you can drag it into position.", "Show Sample Alert", function()
        ns:GetModule("PetTracker"):ShowSampleNearbyAlert()
    end, y)
    y = self:CreateButton(content, "Hide Nearby Alert Preview", "Hides the sample pet alert after you are done positioning it.", "Hide Sample Alert", function()
        ns:GetModule("PetTracker"):HideSampleNearbyAlert()
    end, y)
    y = self:CreateSlider(content, "petTrackerNearbyFadeInTime", "Nearby Alert Fade In", "Adjust how quickly the nearby pet alert slides/fades in.", 0, 2, 0.1, y, "s")
    y = self:CreateSlider(content, "petTrackerNearbyFadeOutTime", "Nearby Alert Fade Out", "Adjust how quickly the nearby pet alert fades out.", 0.2, 5, 0.1, y, "s")
    y = self:CreateSlider(content, "petTrackerNearbyDetectionRadius", "Nearby Detection Radius", "Adjust how close you need to be to a known wild-pet spawn before the alert can fire.", 0.5, 8, 0.5, y, "%")
    y = self:CreateSlider(content, "petTrackerNearbyStartupDelay", "Nearby Startup Delay", "Wait this many seconds after login or reload before nearby alerts can fire.", 0, 30, 1, y, "s")
    y = self:CreateCheckbox(content, "petTrackerObjectiveTracker", "Objective Tracker Pet List", "Attach the current zone's wild-pet progress and upgrade list to the objective tracker.", y)
    y = self:CreateCheckbox(content, "dungeonTooltipInfo", "Dungeon Tooltip Pet Info", "Append a Battle Pets section to dungeon and raid icon tooltips on the world map.", y)

    content:SetHeight(math.max(1, -y + 24))

    panel:SetScript("OnShow", function()
        self:RefreshControls()
    end)

    return panel
end

function SettingsUI:RegisterPanel()
    local panel = self:BuildPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, "DX Pet Services")
    Settings.RegisterAddOnCategory(category)

    self.category = category
    self.categoryID = category:GetID()
end

function SettingsUI:OnInitialize()
    self:RegisterPanel()
end

function SettingsUI:RefreshControls()
    local settings = ns.db.settings

    self.controls.defaultBattle:SetChecked(settings.defaultView ~= "COLLECTOR")
    self.controls.defaultCollector:SetChecked(settings.defaultView == "COLLECTOR")

    for _, key in ipairs(TOGGLE_KEYS) do
        self.controls[key]:SetChecked(settings[key] ~= false)
    end
    if self.controls.petTrackerPinMode and self.controls.petTrackerPinMode.RefreshValue then
        self.controls.petTrackerPinMode:RefreshValue()
    end
    for _, key in ipairs({ "petTrackerPinSize", "petTrackerPinOpacity", "petTrackerNearbyFadeInTime", "petTrackerNearbyFadeOutTime", "petTrackerNearbyDetectionRadius", "petTrackerNearbyStartupDelay" }) do
        local slider = self.controls[key]
        if slider then
            slider._refreshing = true
            slider:SetValue(settings[key])
            slider.ValueText:SetText(slider.FormatValue(settings[key]))
            slider._refreshing = false
        end
    end
end

function SettingsUI:Open()
    Settings.OpenToCategory(self.categoryID)
end

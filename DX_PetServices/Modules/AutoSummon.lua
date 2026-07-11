local addonName, ns = ...

local AutoSummon = {
    checkToken = 0,
    retryCount = 0,
    button = nil,
}
ns:RegisterModule("AutoSummon", AutoSummon)

local INITIAL_DELAY = 1.5
local RETRY_DELAY = 2.0
local MAX_RETRIES = 3

local function IsPetBattleActive()
    return C_PetBattles.IsInBattle()
end

-- Lifecycle and events

function AutoSummon:OnInitialize()
    ns.Events:Register("PLAYER_ENTERING_WORLD", self, "OnContextEvent")
    ns.Events:Register("LOADING_SCREEN_DISABLED", self, "OnContextEvent")
    ns.Events:Register("ZONE_CHANGED", self, "OnContextEvent")
    ns.Events:Register("ZONE_CHANGED_INDOORS", self, "OnContextEvent")
    ns.Events:Register("ZONE_CHANGED_NEW_AREA", self, "OnContextEvent")
    ns.Events:Register("PET_BATTLE_CLOSE", self, "OnContextEvent")
    ns.Events:Register("COMPANION_UPDATE", self, "OnCompanionUpdate")
    ns.Events:Register("PLAYER_REGEN_ENABLED", self, "OnContextEvent")
    ns.Events:Register("PET_JOURNAL_LIST_UPDATE", self, "OnPetJournalChanged")
end

function AutoSummon:OnEnable()
    if self:IsEnabled() then
        self:ScheduleCheck(INITIAL_DELAY, "enable")
    end
end

-- Mode state

function AutoSummon:IsEnabled()
    return ns.charDB
        and ns.charDB.autoSummon
        and ns.charDB.autoSummon.enabled == true
end

function AutoSummon:GetSourceMode()
    local source = ns.charDB
        and ns.charDB.autoSummon
        and ns.charDB.autoSummon.source

    if source == "ALL" then
        return "ALL"
    end
    return "FAVORITES"
end

function AutoSummon:GetSourceLabel()
    if self:GetSourceMode() == "ALL" then
        return "Any Random Pet"
    end
    return "Character Favorites"
end

function AutoSummon:GetMode()
    if not self:IsEnabled() then
        return "OFF"
    end

    if self:GetSourceMode() == "ALL" then
        return "RANDOM"
    end

    return "ON"
end

function AutoSummon:SetMode(mode)
    mode = tostring(mode or "OFF"):upper()

    if mode == "RANDOM" or mode == "ALL" then
        ns.charDB.autoSummon.enabled = true
        ns.charDB.autoSummon.source = "ALL"
        mode = "RANDOM"
    elseif mode == "ON" or mode == "FAVORITES" or mode == "FAVORITE" then
        ns.charDB.autoSummon.enabled = true
        ns.charDB.autoSummon.source = "FAVORITES"
        mode = "ON"
    else
        ns.charDB.autoSummon.enabled = false
        mode = "OFF"
    end

    self.retryCount = 0
    self.checkToken = self.checkToken + 1
    self:UpdateButton()

    if mode ~= "OFF" and not self:HasSummonedPet() then
        self:ScheduleCheck(0.1, "mode-changed")
    end

    return mode
end

function AutoSummon:CycleMode()
    local current = self:GetMode()
    if current == "OFF" then
        return self:SetMode("ON")
    elseif current == "ON" then
        return self:SetMode("RANDOM")
    end
    return self:SetMode("OFF")
end

-- Compatibility helpers retained for slash commands and older internal calls.
function AutoSummon:SetSourceMode(source)
    if source == "ALL" then
        return self:SetMode("RANDOM")
    end
    return self:SetMode("ON")
end

function AutoSummon:ToggleSourceMode()
    if self:GetSourceMode() == "FAVORITES" then
        return self:SetMode("RANDOM")
    end
    return self:SetMode("ON")
end

function AutoSummon:SetEnabled(enabled)
    if enabled == true then
        return self:SetMode("ON") ~= "OFF"
    end
    self:SetMode("OFF")
    return false
end

function AutoSummon:Toggle()
    return self:CycleMode()
end

function AutoSummon:OnContextEvent(event)
    if not self:IsEnabled() then
        return
    end

    self.retryCount = 0
    self:ScheduleCheck(INITIAL_DELAY, event)
end

function AutoSummon:OnCompanionUpdate(_, companionType)
    if companionType and companionType ~= "CRITTER" then
        return
    end

    if not self:IsEnabled() then
        return
    end

    self.retryCount = 0
    self:ScheduleCheck(0.75, "COMPANION_UPDATE")
end

function AutoSummon:OnPetJournalChanged()
    if self:IsEnabled() and not self:HasSummonedPet() then
        self:ScheduleCheck(INITIAL_DELAY, "PET_JOURNAL_LIST_UPDATE")
    end
end

-- Summoning

function AutoSummon:HasSummonedPet()
    return C_PetJournal.GetSummonedPetGUID() ~= nil
end

function AutoSummon:CanAttemptSummon()
    if not self:IsEnabled() then
        return false
    end

    if self:GetSourceMode() == "FAVORITES" then
        local favorites = ns:GetModule("Favorites")
        if favorites and favorites.IsInitialSyncComplete and not favorites:IsInitialSyncComplete() then
            return false
        end
    end

    if IsPetBattleActive() then
        return false
    end

    if InCombatLockdown() then
        return false
    end

    if self:HasSummonedPet() then
        return false
    end

    if self:GetSourceMode() == "FAVORITES" then
        if not C_PetJournal.HasFavoritePets() then
            return false
        end
    else
        local _, numOwned = C_PetJournal.GetNumPets()
        if not numOwned or numOwned <= 0 then
            return false
        end
    end

    return true
end

function AutoSummon:ScheduleCheck(delay, reason)
    if not self:IsEnabled() then
        return
    end

    self.checkToken = self.checkToken + 1
    local token = self.checkToken

    C_Timer.After(delay or 0, function()
        if token ~= self.checkToken then
            return
        end
        self:TryAutoSummon(reason)
    end)
end

function AutoSummon:TryAutoSummon(reason)
    if not self:IsEnabled() or self:HasSummonedPet() then
        self.retryCount = 0
        return false
    end

    if IsPetBattleActive() then
        return false
    end

    if InCombatLockdown() then
        return false
    end

    if not self:CanAttemptSummon() then
        return false
    end

    local favoritesOnly = self:GetSourceMode() == "FAVORITES"
    local ok, err = pcall(C_PetJournal.SummonRandomPet, favoritesOnly)
    if not ok then
        if ns.db and ns.db.settings and ns.db.settings.debug then
            ns:Print("Auto summon failed:", err or "unknown error")
        end
        return false
    end

    if ns.db and ns.db.settings and ns.db.settings.debug then
        ns:Print("Auto summon requested:", reason or "unknown", "| Source:", self:GetSourceLabel())
    end

    self:ScheduleVerification()
    return true
end

function AutoSummon:ScheduleVerification()
    C_Timer.After(RETRY_DELAY, function()
        if not self:IsEnabled() or self:HasSummonedPet() then
            self.retryCount = 0
            return
        end

        if IsPetBattleActive() or InCombatLockdown() then
            return
        end

        if self.retryCount >= MAX_RETRIES then
            self.retryCount = 0
            return
        end

        self.retryCount = self.retryCount + 1
        self:ScheduleCheck(RETRY_DELAY, "retry")
    end)
end

-- Button

function AutoSummon:SetButton(button)
    self.button = button
    self:UpdateButton()
end

function AutoSummon:UpdateButton()
    if not self.button then
        return
    end

    self.button:SetText("Auto Summon: " .. self:GetMode())
end

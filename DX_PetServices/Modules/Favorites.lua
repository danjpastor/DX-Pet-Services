local addonName, ns = ...

local Favorites = {
    nativeHookInstalled = false,
    syncingNativeFavorites = false,
    initialSyncComplete = false,
    active = false,
    syncToken = 0,
    captureToken = 0,
}
ns:RegisterModule("Favorites", Favorites)

Favorites.filterOrder = { "ALL", "EXACT" }
Favorites.filterLabels = {
    ALL = "All Pets",
    EXACT = "Character Favorites",
}

local INITIAL_SYNC_RETRY_DELAY = 0.5

local function NormalizeSpeciesID(speciesID)
    local value = tonumber(speciesID)
    if not value then
        return nil
    end
    return value
end

local function GetOwnedPetIDsAndReady()
    local petIDs = C_PetJournal.GetOwnedPetIDs() or {}
    if #petIDs > 0 then
        return petIDs, true
    end

    -- The journal can briefly report an empty list while the collection is
    -- loading. Treat it as ready only when the account truly owns no pets.
    local _, numOwned = C_PetJournal.GetNumPets()
    return petIDs, numOwned == 0
end

local function CountFavorites(tbl)
    local count = 0
    if type(tbl) ~= "table" then
        return count
    end

    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Favorites:Debug(message, ...)
    if not ns.db or not ns.db.settings or not ns.db.settings.debug then
        return
    end

    if select("#", ...) > 0 then
        ns:Print(string.format(message, ...))
    else
        ns:Print(message)
    end
end

-- Lifecycle and synchronization

function Favorites:OnInitialize()
    ns.Events:Register("PET_JOURNAL_PET_DELETED", self, "OnPetDeleted")
    ns.Events:Register("PET_JOURNAL_LIST_UPDATE", self, "OnPetJournalListUpdate")
    ns.Events:Register("PLAYER_LOGOUT", self, "OnPlayerLogout")
    self:InstallNativeFavoriteHook()
end

function Favorites:OnEnable()
    self.active = true
    self.initialSyncComplete = false
    self:InstallNativeFavoriteHook()
    self:ScheduleInitialSync(0)
end

function Favorites:InstallNativeFavoriteHook()
    if self.nativeHookInstalled then
        return true
    end

    hooksecurefunc(C_PetJournal, "SetFavorite", function(petID)
        self:OnNativeFavoriteChanged(petID)
    end)

    self.nativeHookInstalled = true
    return true
end

function Favorites:ScheduleInitialSync(delay)
    if not self.active or self.initialSyncComplete then
        return
    end

    self.syncToken = self.syncToken + 1
    local token = self.syncToken

    local function Run()
        if token ~= self.syncToken or not self.active or self.initialSyncComplete then
            return
        end

        if not self:TryInitialSync() then
            self:ScheduleInitialSync(INITIAL_SYNC_RETRY_DELAY)
        end
    end

    C_Timer.After(delay or 0, Run)
end

function Favorites:TryInitialSync()
    local petIDs, ready = GetOwnedPetIDsAndReady()
    if not ready then
        self:Debug("Favorite sync waiting for the Pet Journal collection to finish loading.")
        return false
    end

    ns.db.migrations = ns.db.migrations or {}

    if not ns.db.migrations.nativeFavoritesImported then
        self:ImportNativeFavorites(petIDs)
        ns.db.migrations.nativeFavoritesImported = true
        self:Debug("Imported %d existing native favorites for this character.", CountFavorites(ns.charDB.favorites.exact))
    else
        self:ApplyCharacterFavoritesToNative(petIDs)
    end

    self.initialSyncComplete = true
    self:Debug("Character favorite sync complete with %d saved favorites.", CountFavorites(ns.charDB.favorites.exact))
    ns:RefreshJournal()

    local autoSummon = ns:GetModule("AutoSummon")
    if autoSummon:IsEnabled() then
        autoSummon:ScheduleCheck(0.2, "favorite-sync-complete")
    end

    return true
end

function Favorites:ImportNativeFavorites(petIDs)
    local imported = {}
    for _, petID in ipairs(petIDs or {}) do
        if C_PetJournal.PetIsFavorite(petID) then
            imported[petID] = true
        end
    end

    ns.charDB.favorites.exact = imported
    return true
end

function Favorites:ApplyCharacterFavoritesToNative(petIDs)
    if petIDs == nil then
        local ready
        petIDs, ready = GetOwnedPetIDsAndReady()
        if not ready then
            return false
        end
    end

    -- Do not prune saved favorites here. The pet collection can temporarily report
    -- an empty or incomplete owned-pet list during login and character transitions.
    -- Actual pet removals are handled by PET_JOURNAL_PET_DELETED instead.
    self.syncingNativeFavorites = true

    local changed = false
    for _, petID in ipairs(petIDs) do
        local shouldBeFavorite = ns.charDB.favorites.exact[petID] == true
        local isNativeFavorite = C_PetJournal.PetIsFavorite(petID) == true
        if shouldBeFavorite ~= isNativeFavorite then
            C_PetJournal.SetFavorite(petID, shouldBeFavorite and 1 or 0)
            changed = true
        end
    end

    self.syncingNativeFavorites = false
    return changed
end

function Favorites:CaptureNativeFavoritesToCharacter(reason)
    if self.syncingNativeFavorites or not self.initialSyncComplete then
        return false
    end

    local petIDs, ready = GetOwnedPetIDsAndReady()
    if not ready then
        self:Debug("Skipped favorite snapshot (%s): collection not ready.", reason or "unknown")
        return false
    end

    local snapshot = {}
    for _, petID in ipairs(petIDs) do
        if C_PetJournal.PetIsFavorite(petID) then
            snapshot[petID] = true
        end
    end

    ns.charDB.favorites.exact = snapshot
    self:Debug("Saved %d character favorites (%s).", CountFavorites(snapshot), reason or "snapshot")
    return true
end

function Favorites:ScheduleCapture(delay, reason)
    if not self.initialSyncComplete or self.syncingNativeFavorites then
        return
    end

    self.captureToken = self.captureToken + 1
    local token = self.captureToken

    local function Run()
        if token ~= self.captureToken or not self.initialSyncComplete or self.syncingNativeFavorites then
            return
        end
        self:CaptureNativeFavoritesToCharacter(reason)
    end

    C_Timer.After(delay or 0, Run)
end

function Favorites:OnNativeFavoriteChanged(petID)
    if self.syncingNativeFavorites or not petID or not ns.charDB or not ns.charDB.favorites then
        return
    end

    -- Read back the actual native state after SetFavorite finishes instead of
    -- trusting the function's second argument, whose representation can vary.
    local isFavorite = C_PetJournal.PetIsFavorite(petID) == true

    if isFavorite then
        ns.charDB.favorites.exact[petID] = true
    else
        ns.charDB.favorites.exact[petID] = nil
    end

    self:Debug("Favorite changed: %s -> %s", tostring(petID), isFavorite and "favorite" or "not favorite")

    C_Timer.After(0, function()
        ns:RefreshJournal()
    end)
end

function Favorites:OnPetJournalListUpdate()
    if not self.active then
        return
    end

    if not self.initialSyncComplete then
        self:ScheduleInitialSync(0)
        return
    end

    if not self.syncingNativeFavorites then
        self:ScheduleCapture(0, "PET_JOURNAL_LIST_UPDATE")
    end
end

function Favorites:OnPlayerLogout()
    -- PLAYER_LOGOUT fires before SavedVariables are serialized, so take one final
    -- authoritative snapshot of the native favorite set for this character.
    self:CaptureNativeFavoritesToCharacter("PLAYER_LOGOUT")
end

function Favorites:OnPetDeleted(_, petID)
    if petID then
        ns.charDB.favorites.exact[petID] = nil
    end
end

-- Favorite state

function Favorites:IsInitialSyncComplete()
    return self.initialSyncComplete == true
end

function Favorites:IsExactFavorite(petID)
    return petID ~= nil and ns.charDB.favorites.exact[petID] == true
end

-- Kept for saved-data compatibility with the 0.1.0-0.1.7 builds.
-- Species favorites are no longer part of the active native-style favorite UI.
function Favorites:IsSpeciesFavorite(speciesID)
    speciesID = NormalizeSpeciesID(speciesID)
    return speciesID ~= nil and ns.charDB.favorites.species[speciesID] == true
end

function Favorites:SetCharacterFavorite(petID, isFavorite)
    if not petID then
        return false
    end

    isFavorite = isFavorite == true
    if isFavorite then
        ns.charDB.favorites.exact[petID] = true
    else
        ns.charDB.favorites.exact[petID] = nil
    end

    if C_PetJournal.PetIsFavorite(petID) ~= isFavorite then
        C_PetJournal.SetFavorite(petID, isFavorite and 1 or 0)
    end

    return isFavorite
end

function Favorites:ToggleExactFavorite(petID)
    return self:SetCharacterFavorite(petID, not self:IsExactFavorite(petID))
end

function Favorites:ToggleSpeciesFavorite(speciesID)
    speciesID = NormalizeSpeciesID(speciesID)
    if not speciesID then
        return false
    end

    local favorites = ns.charDB.favorites.species
    if favorites[speciesID] then
        favorites[speciesID] = nil
        return false
    end

    favorites[speciesID] = true
    return true
end

-- Journal filtering

function Favorites:GetFilterMode()
    local mode = ns.charDB.journal.filterMode or "ALL"
    if not self.filterLabels[mode] then
        return "ALL"
    end
    return mode
end

function Favorites:SetFilterMode(mode)
    if not self.filterLabels[mode] then
        mode = "ALL"
    end
    ns.charDB.journal.filterMode = mode
    return mode
end

function Favorites:GetFilterLabel()
    return self.filterLabels[self:GetFilterMode()] or self.filterLabels.ALL
end

function Favorites:MatchesFilter(petID)
    local mode = self:GetFilterMode()
    if mode == "EXACT" then
        return self:IsExactFavorite(petID)
    end
    return true
end

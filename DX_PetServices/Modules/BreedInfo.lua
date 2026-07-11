local addonName, ns = ...

local BreedInfo = {
    tooltipName = "DXPS_BreedTooltip",
}
ns:RegisterModule("BreedInfo", BreedInfo)

local Arrays = ns.BreedArrays
local MAX_BREEDS = 10
local BREED_FORMAT = 3 -- Match Battle Pet BreedID default: letter names (B/B, P/P, S/S, etc.)
local TOOLTIP_MIN_WIDTH = 120
local TOOLTIP_HORIZONTAL_PADDING = 30
local is_ptr = false
local CPB = C_PetBattles
local ceil = math.ceil
local min = math.min
local abs = math.abs
local floor = math.floor
local tostring = tostring
local tonumber = tonumber
local sub = string.sub

local LABEL = "|cFFD4A017"
local WHITE = "|r"

local function EnsureArrays()
    if Arrays and not Arrays.BasePetStats and type(Arrays.InitializeArrays) == "function" then
        Arrays.InitializeArrays()
    end
    return Arrays and Arrays.BasePetStats ~= nil
end

local function CalculateBreedID(nSpeciesID, nQuality, nLevel, nMaxHP, nPower, nSpeed, wild, flying)
    
    -- Abandon ship! (if missing inputs)
    if (not nSpeciesID) or (not nQuality) or (not nMaxHP) or (not nPower) or (not nSpeed) then return "ERR" end
    
    -- Arrays are now initialized
    if (not Arrays.BasePetStats) then Arrays.InitializeArrays() end
    
    local breedID, nQL, minQuality, maxQuality
    
    -- Due to a Blizzard bug, some pets from tooltips will have quality = 0. this means we don't know what the quality is.
    -- So, we'll just test them all by adding another loop for rarity.
    -- This bug was fixed in Patch 5.2, but there is no harm in having this remain here.
    if (nQuality < 1) then
        nQuality = 2
        minQuality = 1
        if is_ptr then
            maxQuality = 6
        else
            maxQuality = 4
        end
    else
        minQuality = nQuality
        maxQuality = nQuality
    end
    
    -- End here and return "NEW" if species is new to the game (has unknown base stats)
    if not Arrays.BasePetStats[nSpeciesID] then
        if ((false) and (not CPB.IsInBattle())) then
            print("Species " .. nSpeciesID .. " is completely unknown.")
        end
        return "NEW", nQuality, {"NEW"}
    end
    
    -- Localize base species stats and upconvert to avoid floating point errors (Blizzard could learn from this)
    local ihp = Arrays.BasePetStats[nSpeciesID][1] * 10
    local ipower = Arrays.BasePetStats[nSpeciesID][2] * 10
    local ispeed = Arrays.BasePetStats[nSpeciesID][3] * 10
    
    -- Account for wild pet HP / Power reductions
    nLevel = tonumber(nLevel)
    local wildHPFactor, wildPowerFactor = 1, 1
    if wild then
        wildHPFactor = 1.2
        if nLevel < 6 then
            wildPowerFactor = 1.4
        else
            wildPowerFactor = 1.25
        end
    end
    
    -- Upconvert to avoid floating point errors
    local thp = nMaxHP * 100
    local tpower = nPower * 100
    local tspeed = nSpeed * 100
    
    -- Account for flying pet passive
    if flying then tspeed = tspeed / 1.5 end
    
    local trueresults = {}
    local lowest
    for i = minQuality, maxQuality do -- Accounting for BlizzBug with rarity
		-- Note that this value is also upconverted by 10x. Together with the upconversion from stats, it opposes the upconversion
        nQL = Arrays.RealRarityValues[i] * 20 * nLevel
        
        -- Higher level pets can never have duplicate breeds, so calculations can be less accurate and faster (they remain the same since version 0.7)
        if (nLevel > 2) then
        
            -- Calculate diffs
            local diff3 = (abs(((ihp + 5) * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs(((ipower + 5) * nQL) / wildPowerFactor - tpower) + abs(((ispeed + 5) * nQL) - tspeed)
            local diff4 = (abs((ihp * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs(((ipower + 20) * nQL) / wildPowerFactor - tpower) + abs((ispeed * nQL) - tspeed)
            local diff5 = (abs((ihp * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs((ipower * nQL) / wildPowerFactor - tpower) + abs(((ispeed + 20) * nQL) - tspeed)
            local diff6 = (abs(((ihp + 20) * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs((ipower * nQL) / wildPowerFactor - tpower) + abs((ispeed * nQL) - tspeed)
            local diff7 = (abs(((ihp + 9) * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs(((ipower + 9) * nQL) / wildPowerFactor - tpower) + abs((ispeed * nQL) - tspeed)
            local diff8 = (abs((ihp * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs(((ipower + 9) * nQL) / wildPowerFactor - tpower) + abs(((ispeed + 9) * nQL) - tspeed)
            local diff9 = (abs(((ihp + 9) * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs((ipower * nQL) / wildPowerFactor - tpower) + abs(((ispeed + 9) * nQL) - tspeed)
            local diff10 = (abs(((ihp + 4) * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs(((ipower + 9) * nQL) / wildPowerFactor - tpower) + abs(((ispeed + 4) * nQL) - tspeed)
            local diff11 = (abs(((ihp + 4) * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs(((ipower + 4) * nQL) / wildPowerFactor - tpower) + abs(((ispeed + 9) * nQL) - tspeed)
            local diff12 = (abs(((ihp + 9) * nQL * 5 + 10000) / wildHPFactor - thp) / 5) + abs(((ipower + 4) * nQL) / wildPowerFactor - tpower) + abs(((ispeed + 4) * nQL) - tspeed)
            
            -- Calculate min diff
            local current = min(diff3, diff4, diff5, diff6, diff7, diff8, diff9, diff10, diff11, diff12)
            
            if not lowest or current < lowest then
                lowest = current
                nQuality = i
                
                -- Determine breed from min diff
                if (lowest == diff3) then breedID = 3
                elseif (lowest == diff4) then breedID = 4
                elseif (lowest == diff5) then breedID = 5
                elseif (lowest == diff6) then breedID = 6
                elseif (lowest == diff7) then breedID = 7
                elseif (lowest == diff8) then breedID = 8
                elseif (lowest == diff9) then breedID = 9
                elseif (lowest == diff10) then breedID = 10
                elseif (lowest == diff11) then breedID = 11
                elseif (lowest == diff12) then breedID = 12
                else return "ERR-MIN", -1, {"ERR-MIN"} -- Should be impossible (keeping for debug)
                end
                
                trueresults[1] = breedID
            end
        
        -- Lowbie pets go here, the bane of my existence. Calculations must be intense and logic loops numerous.
        else
            -- Calculate diffs much more intensely. Round calculations with 10^-2 and by using math.floor after adding 0.5. Also, properly devalue HP by dividing its absolute value by 5.
            local diff3 = (abs((floor(((ihp + 5) * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( ((ipower + 5) * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( ((ispeed + 5) * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff4 = (abs((floor((ihp * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( ((ipower + 20) * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( (ispeed * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff5 = (abs((floor((ihp * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( (ipower * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( ((ispeed + 20) * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff6 = (abs((floor(((ihp + 20) * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( (ipower * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( (ispeed * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff7 = (abs((floor(((ihp + 9) * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( ((ipower + 9) * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( (ispeed * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff8 = (abs((floor((ihp * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( ((ipower + 9) * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( ((ispeed + 9) * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff9 = (abs((floor(((ihp + 9) * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( (ipower * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( ((ispeed + 9) * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff10 = (abs((floor(((ihp + 4) * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( ((ipower + 9) * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( ((ispeed + 4) * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff11 = (abs((floor(((ihp + 4) * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( ((ipower + 4) * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( ((ispeed + 9) * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            local diff12 = (abs((floor(((ihp + 9) * nQL * 5 + 10000) / wildHPFactor * 0.01 + 0.5) / 0.01) - thp) / 5) + abs((floor( ((ipower + 4) * nQL) / wildPowerFactor * 0.01 + 0.5) / 0.01) - tpower) + abs((floor( ((ispeed + 4) * nQL) * 0.01 + 0.5) / 0.01) - tspeed)
            
            -- Use custom replacement code for math.min to find duplicate breed possibilities
            local numberlist = { diff3, diff4, diff5, diff6, diff7, diff8, diff9, diff10, diff11, diff12 }
            local secondnumberlist = {}
            local resultslist = {}
            local numResults = 0
            local smallest
            
            -- If we know the breeds for species, use this series of logic statements to eliminate impossible breeds
            if (Arrays.BreedsPerSpecies[nSpeciesID] and Arrays.BreedsPerSpecies[nSpeciesID][1]) then
                
                -- This half of the table stores the diffs for the breeds that passed inspection 
                secondnumberlist[1] = {}
                -- This half of the table stores the number corresponding to the breeds that passed inspection since we can no longer rely on the index
                secondnumberlist[2] = {}
                
                -- "inspection" time! if the breed is not found in the array, it doesn't get passed on to secondnumberlist and is effectively discarded
                for q = 1, #Arrays.BreedsPerSpecies[nSpeciesID] do
                    local currentbreed = Arrays.BreedsPerSpecies[nSpeciesID][q]
                    -- Subtracting 2 from the breed to use it as an index (scale of 3-13 becomes 1-10)
                    secondnumberlist[1][q] = numberlist[currentbreed - 2]
                    secondnumberlist[2][q] = currentbreed
                end
                
                -- Find the smallest number out of the breeds left
                for x = 1, #secondnumberlist[2] do
                    -- If this breed is the closest to perfect we've seen, make it our only result (destroy all other results)
                    if (not smallest) or (secondnumberlist[1][x] < smallest) then 
                        smallest = secondnumberlist[1][x]
                        numResults = 1
                        resultslist = {}
                        resultslist[1] = secondnumberlist[2][x]
                    -- If we find a duplicate, add it to the list (but it can still be destroyed if better is found)
                    elseif (secondnumberlist[1][x] == smallest) then
                        numResults = numResults + 1
                        resultslist[numResults] = secondnumberlist[2][x]
                    end
                end
            
            -- If we don't know the species, use this series of logic statements to consider all possibilities
            else
                for y = 1, #numberlist do
                    -- If this breed is the closest to perfect we've seen, make it our only result (destroy all other results)
                    if (not smallest) or (numberlist[y] < smallest) then 
                        smallest = numberlist[y]
                        numResults = 1
                        resultslist = {}
                        resultslist[1] = y + 2
                    -- If we find a duplicate, add it to the list (but it can still be destroyed if better is found)
                    elseif (numberlist[y] == smallest) then
                        numResults = numResults + 1
                        resultslist[numResults] = y + 2
                    end
                end
            end
            
            -- Check to see if this is the smallest value reported out of all qualities (or if the quality is not in question)
            if not lowest or smallest < lowest then
                lowest = smallest
                nQuality = i
                
                trueresults = resultslist
                
                -- Set breedID to best suited breed (or ??? if matching breeds) (or ERR-BMN if error)
                if resultslist[2] then
                    breedID = "???"
                elseif resultslist[1] then
                    breedID = resultslist[1]
                else
                    return "ERR-BMN", -1, {"ERR-BMN"} -- Should be impossible (keeping for debug)
                end
                
                -- If something is perfectly accurate, there is no need to continue (obviously)
                if (smallest == 0) then break end
            end
        end
    end
    
    -- Debug section (to enable, you must manually set this value in-game using "/run false = true")
    if (false) and (not CPB.IsInBattle()) then
        if not (Arrays.BreedsPerSpecies[nSpeciesID]) then
            print("Species " .. nSpeciesID .. ": Possible breeds unknown. Current Breed is " .. breedID .. ".")
        elseif (breedID ~= "???") then
            local exists = false
            for i = 1, #Arrays.BreedsPerSpecies[nSpeciesID] do
                if (Arrays.BreedsPerSpecies[nSpeciesID][i] == breedID) then exists = true end
            end
            if not (exists) then
                print("Species " .. nSpeciesID .. ": Current breed is outside the range of possible breeds. Current Breed is " .. breedID .. ".")
            end
        end
    end
    
    -- Return breed (or error)
    if breedID then
        return breedID, nQuality, trueresults
    else
        return "ERR-CAL", -1, {"ERR-CAL"} -- Should be impossible (keeping for debug)
    end
end

-- Match breedID to name, second number, double letter code (S/S), entire base+breed stats, or just base stats
local function RetrieveBreedName(breedID)
    -- Exit if no breedID found
    if not breedID then return "ERR-ELY" end -- Should be impossible (keeping for debug)
    
    -- Exit if error message found
    if (sub(tostring(breedID), 1, 3) == "ERR") or (tostring(breedID) == "???") or (tostring(breedID) == "NEW") then return breedID end
    
    local numberBreed = tonumber(breedID)
    
    if (BREED_FORMAT == 1) then -- Return single number
        return numberBreed
    elseif (BREED_FORMAT == 2) then -- Return two numbers
        return numberBreed .. "/" .. numberBreed + MAX_BREEDS
    else -- Select correct letter breed
        if (numberBreed == 3) then
            return "B/B"
        elseif (numberBreed == 4) then
            return "P/P"
        elseif (numberBreed == 5) then
            return "S/S"
        elseif (numberBreed == 6) then
            return "H/H"
        elseif (numberBreed == 7) then
            return "H/P"
        elseif (numberBreed == 8) then
            return "P/S"
        elseif (numberBreed == 9) then
            return "H/S"
        elseif (numberBreed == 10) then
            return "P/B"
        elseif (numberBreed == 11) then
            return "S/B"
        elseif (numberBreed == 12) then
            return "H/B"
        else
            return "ERR-NAM" -- Should be impossible (keeping for debug)
        end
    end
end




local function GetDXBreedName(breedID)
    breedID = tonumber(breedID)
    if breedID == 3 then
        return BALANCE or "Balance"
    elseif breedID == 4 then
        local name
        if type(GetSpecializationInfoByID) == "function" then
            local _
            _, name = GetSpecializationInfoByID(267)
        end
        return name or PET_BATTLE_STAT_POWER or "Power"
    elseif breedID == 5 then
        return "Ninja"
    elseif breedID == 6 then
        local name
        if type(GetSpecializationInfoByID) == "function" then
            local _
            _, name = GetSpecializationInfoByID(104)
        end
        return name or PET_BATTLE_STAT_HEALTH or "Health"
    elseif breedID == 7 then
        return (PET_BATTLE_STAT_POWER or "Power") .. " & " .. (PET_BATTLE_STAT_HEALTH or "Health")
    elseif breedID == 8 then
        return (PET_BATTLE_STAT_POWER or "Power") .. " & " .. (PET_BATTLE_STAT_SPEED or "Speed")
    elseif breedID == 9 then
        return (PET_BATTLE_STAT_HEALTH or "Health") .. " & " .. (PET_BATTLE_STAT_SPEED or "Speed")
    elseif breedID == 10 then
        return PET_BATTLE_STAT_POWER or "Power"
    elseif breedID == 11 then
        return PET_BATTLE_STAT_SPEED or "Speed"
    elseif breedID == 12 then
        return PET_BATTLE_STAT_HEALTH or "Health"
    end
    return RetrieveBreedName(breedID)
end

local STAT_ICON_FORMAT = "|TInterface/PetBattles/PetBattle-StatIcons:%d:%d:%d:%d:32:32:%d:%d:%d:%d|t"
local COMBAT_ICON_FORMAT = "|TInterface/WorldStateFrame/CombatSwords:%d:%d:%d:%d:64:64:0:32:0:32|t"

local function NativeStatIcon(stat, size, x, y)
    size = size or 12
    x = x or 0
    y = y or 0
    if stat == "power" then
        return STAT_ICON_FORMAT:format(size, size, x, y, 0, 16, 0, 16)
    elseif stat == "speed" then
        return STAT_ICON_FORMAT:format(size, size, x, y, 0, 16, 16, 32)
    elseif stat == "health" then
        return STAT_ICON_FORMAT:format(size, size, x, y, 16, 32, 16, 32)
    end
    return ""
end

local function GetDXBreedIcon(breedID, scale, x, y)
    breedID = tonumber(breedID)
    scale = scale or 1
    x = x or 0
    y = y or 0

    if breedID == 3 then
        return STAT_ICON_FORMAT:format(math.floor(22 * scale + 0.5), math.floor(22 * scale + 0.5), x, y, 16, 32, 0, 16)
    elseif breedID == 4 then
        local size = math.floor(19 * scale + 0.5)
        return COMBAT_ICON_FORMAT:format(size, size, x, y)
    elseif breedID == 5 or breedID == 11 then
        return NativeStatIcon("speed", math.floor(17 * scale + 0.5), x, y)
    elseif breedID == 6 or breedID == 12 then
        return NativeStatIcon("health", math.floor(17 * scale + 0.5), x, y)
    elseif breedID == 10 then
        return NativeStatIcon("power", math.floor(17 * scale + 0.5), x, y)
    elseif breedID == 7 then
        local size = math.max(8, math.floor(11 * scale + 0.5))
        return NativeStatIcon("power", size, x, y) .. NativeStatIcon("health", size, -2, y)
    elseif breedID == 8 then
        local size = math.max(8, math.floor(11 * scale + 0.5))
        return NativeStatIcon("power", size, x, y) .. NativeStatIcon("speed", size, -2, y)
    elseif breedID == 9 then
        local size = math.max(8, math.floor(11 * scale + 0.5))
        return NativeStatIcon("health", size, x, y) .. NativeStatIcon("speed", size, -2, y)
    end
    return ""
end

local function ResetTooltipMinimumWidth(tooltip)
    if tooltip and type(tooltip.SetMinimumWidth) == "function" then
        pcall(tooltip.SetMinimumWidth, tooltip, 0)
    end
end

local function GetFontStringWidth(fontString)
    if not fontString then
        return 0
    end

    local width
    if type(fontString.GetUnboundedStringWidth) == "function" then
        local ok, result = pcall(fontString.GetUnboundedStringWidth, fontString)
        if ok and type(result) == "number" then
            width = result
        end
    end
    if (not width or width <= 0) and type(fontString.GetStringWidth) == "function" then
        local ok, result = pcall(fontString.GetStringWidth, fontString)
        if ok and type(result) == "number" then
            width = result
        end
    end
    return width or 0
end

local function CalculateTooltipContentWidth(tooltip)
    if not tooltip or type(tooltip.GetName) ~= "function" then
        return TOOLTIP_MIN_WIDTH
    end

    local name = tooltip:GetName()
    if not name then
        return TOOLTIP_MIN_WIDTH
    end

    local widest = 0
    local numLines = type(tooltip.NumLines) == "function" and tooltip:NumLines() or 0
    for line = 1, numLines do
        local left = _G[name .. "TextLeft" .. line]
        local right = _G[name .. "TextRight" .. line]
        local leftWidth = GetFontStringWidth(left)
        local rightWidth = GetFontStringWidth(right)
        local lineWidth = leftWidth
        if rightWidth > 0 then
            lineWidth = leftWidth + rightWidth + 16
        end
        if lineWidth > widest then
            widest = lineWidth
        end
    end

    return math.max(TOOLTIP_MIN_WIDTH, math.ceil(widest + TOOLTIP_HORIZONTAL_PADDING))
end

local function ApplyExactTooltipWidth(tooltip, width)
    if not tooltip or type(width) ~= "number" then
        return
    end

    ResetTooltipMinimumWidth(tooltip)
    if type(tooltip.SetMinimumWidth) == "function" then
        pcall(tooltip.SetMinimumWidth, tooltip, width)
    end
    if type(tooltip.SetWidth) == "function" then
        tooltip:SetWidth(width)
    end
end

local function RememberParentTooltipWidth(parent)
    if not parent or parent.DXPSMatchedBreedWidth then
        return
    end

    if type(parent.GetWidth) == "function" then
        parent.DXPSOriginalTooltipWidth = parent:GetWidth()
    end
end

local function CalculateMatchedTooltipWidth(tooltip, parent)
    local breedWidth = CalculateTooltipContentWidth(tooltip)
    local parentWidth = parent and CalculateTooltipContentWidth(parent) or 0
    return math.max(breedWidth, parentWidth)
end

local function ApplyMatchedTooltipWidths(tooltip, parent)
    if not tooltip then
        return nil
    end

    local width = CalculateMatchedTooltipWidth(tooltip, parent)
    ApplyExactTooltipWidth(tooltip, width)

    if parent then
        RememberParentTooltipWidth(parent)
        parent.DXPSMatchedBreedWidth = width
        parent.DXPSMatchedBreedTooltip = tooltip
        ApplyExactTooltipWidth(parent, width)
    end

    return width
end

local function FitTooltipToContent(tooltip, parent)
    if not tooltip then
        return nil
    end

    local width = ApplyMatchedTooltipWidths(tooltip, parent)

    -- Blizzard can finish populating or sizing its native tooltip after our
    -- secure hook returns. Re-measure BOTH panels on the next frame, then use
    -- the larger content requirement as the shared width. This keeps the
    -- stack as narrow as possible without allowing either tooltip to wrap,
    -- clip, or overflow.
    if parent and C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if not parent or not tooltip then
                return
            end
            if parent.DXPSMatchedBreedTooltip ~= tooltip then
                return
            end
            if parent.IsShown and parent:IsShown() and tooltip.IsShown and tooltip:IsShown() then
                width = ApplyMatchedTooltipWidths(tooltip, parent) or width
            end
        end)
    end

    return width
end

local function JoinBreedNames(tblBreedID)
    if type(tblBreedID) ~= "table" or #tblBreedID == 0 then
        return nil
    end

    local text = ""
    local numBreeds = #tblBreedID
    for i = 1, numBreeds do
        local name = RetrieveBreedName(tblBreedID[i])
        if i == 1 then
            text = name
        elseif i == 2 and i == numBreeds then
            text = text .. " or " .. name
        elseif i == numBreeds then
            text = text .. ", or " .. name
        else
            text = text .. ", " .. name
        end
    end
    return text
end

local function JoinPossibleBreeds(speciesID)
    if not EnsureArrays() then
        return "Unknown"
    end

    local breeds = Arrays.BreedsPerSpecies[speciesID]
    if not breeds then
        return "Unknown"
    end
    if #breeds == MAX_BREEDS then
        return "All"
    end

    local text = ""
    for i = 1, #breeds do
        local name = RetrieveBreedName(breeds[i])
        if #breeds == 1 then
            text = name
        elseif i == 1 then
            text = name
        elseif i == 2 and i == #breeds then
            text = text .. " and " .. name
        elseif i == #breeds then
            text = text .. ", and " .. name
        else
            text = text .. ", " .. name
        end
    end
    return text
end

local function GetPetInfo(petID)
    if not petID or not C_PetJournal.GetPetInfoByPetID or not C_PetJournal.GetPetStats then
        return nil
    end

    local speciesID, _, level = C_PetJournal.GetPetInfoByPetID(petID)
    local _, maxHealth, power, speed, rarity = C_PetJournal.GetPetStats(petID)
    if not speciesID or not level or not maxHealth or not power or not speed or not rarity then
        return nil
    end

    local breedNum, quality, resultslist = CalculateBreedID(speciesID, rarity, level, maxHealth, power, speed, false, false)
    return {
        petID = petID,
        speciesID = speciesID,
        level = level,
        maxHealth = maxHealth,
        power = power,
        speed = speed,
        rarity = rarity,
        breedNum = breedNum,
        quality = quality,
        resultslist = resultslist,
    }
end

local function GetOwnedPetIDs()
    if C_PetJournal.GetOwnedPetIDs then
        local ids = C_PetJournal.GetOwnedPetIDs()
        if type(ids) == "table" then
            return ids
        end
    end

    local ids = {}
    if not C_PetJournal.GetNumPets or not C_PetJournal.GetPetInfoByIndex then
        return ids
    end
    local count = C_PetJournal.GetNumPets() or 0
    for index = 1, count do
        local petID = C_PetJournal.GetPetInfoByIndex(index)
        if petID then
            ids[#ids + 1] = petID
        end
    end
    return ids
end

local function GetCollectedText(speciesID)
    local collected = {}
    for _, petID in ipairs(GetOwnedPetIDs()) do
        local petSpeciesID, _, level = C_PetJournal.GetPetInfoByPetID(petID)
        if petSpeciesID == speciesID then
            local _, maxHealth, power, speed, rarity = C_PetJournal.GetPetStats(petID)
            if level and maxHealth and power and speed and rarity then
                local breedNum, quality = CalculateBreedID(speciesID, rarity, level, maxHealth, power, speed, false, false)
                local breed = RetrieveBreedName(breedNum)
                local color = ITEM_QUALITY_COLORS[math.max(0, (quality or rarity or 1) - 1)]
                local hex = color and color.hex or "|cffffffff"
                collected[#collected + 1] = hex .. "L" .. level .. " (" .. breed .. ")|r"
            end
        end
    end
    return #collected > 0 and table.concat(collected, ", ") or nil
end

local function Level25Stats(speciesID, breedID, quality)
    if not EnsureArrays() then
        return nil
    end
    local base = Arrays.BasePetStats[speciesID]
    local breed = Arrays.BreedStats[breedID]
    local rarityValue = Arrays.RealRarityValues[quality]
    if not base or not breed or not rarityValue then
        return nil
    end

    local multiplier = ((rarityValue - 0.5) * 2 + 1)
    local hp = ceil((base[1] + breed[1]) * 25 * multiplier * 5 + 100 - 0.5)
    local power = ceil((base[2] + breed[2]) * 25 * multiplier - 0.5)
    local speed = ceil((base[3] + breed[3]) * 25 * multiplier - 0.5)
    return hp .. "/" .. power .. "/" .. speed
end

local function BuildCurrentSet(resultslist)
    local set = {}
    if type(resultslist) == "table" then
        for _, breedID in ipairs(resultslist) do
            set[breedID] = true
        end
    end
    return set
end

local function GetTooltip(name)
    local tooltip = _G[name]
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", name, nil, "GameTooltipTemplate")
    end
    return tooltip
end

local function MatchTooltipFonts(tooltip)
    local name = tooltip:GetName()
    local first = name and _G[name .. "TextLeft1"]
    if first and first.CanNonSpaceWrap then
        first:CanNonSpaceWrap(true)
    end
    if not name or not first then
        return
    end

    local fontPath, fontHeight, fontFlags = first:GetFont()
    local line = 2
    while _G[name .. "TextLeft" .. line] do
        local fs = _G[name .. "TextLeft" .. line]
        fs:SetFont(fontPath, fontHeight, fontFlags)
        if fs.CanNonSpaceWrap then
            fs:CanNonSpaceWrap(true)
        end
        line = line + 1
    end
end

function BreedInfo:IsExternalAddonLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("BattlePetBreedID")
    end
    return IsAddOnLoaded and IsAddOnLoaded("BattlePetBreedID")
end

function BreedInfo:GetExternalTooltip(parent)
    if not self:IsExternalAddonLoaded() then
        return nil
    end

    local tooltip
    if parent == FloatingBattlePetTooltip then
        tooltip = _G.BPBID_BreedTooltip2
    else
        tooltip = _G.BPBID_BreedTooltip
    end
    if tooltip and tooltip:IsShown() then
        MatchTooltipFonts(tooltip)
        FitTooltipToContent(tooltip, parent)
        return tooltip
    end
    return nil
end

function BreedInfo:HideTooltip()
    local tooltip = _G[self.tooltipName]
    if tooltip then
        tooltip:Hide()
    end
end

function BreedInfo:RestoreParentTooltipWidth(parent)
    if not parent or not parent.DXPSMatchedBreedWidth then
        return
    end

    parent.DXPSMatchedBreedWidth = nil
    parent.DXPSMatchedBreedTooltip = nil
    ResetTooltipMinimumWidth(parent)
    if parent.DXPSOriginalTooltipWidth and type(parent.SetWidth) == "function" then
        parent:SetWidth(parent.DXPSOriginalTooltipWidth)
    end
    parent.DXPSOriginalTooltipWidth = nil
end

function BreedInfo:ShowTooltip(parent, context, tooltipDistance)
    if not parent or not context or not context.speciesID then
        self:HideTooltip()
        return nil
    end

    -- Reuse the official addon's exact tooltip if it is already visible.
    local external = self:GetExternalTooltip(parent)
    if external then
        self:HideTooltip()
        return external
    end

    if not EnsureArrays() then
        return nil
    end

    local speciesID = context.speciesID
    local rarity = context.rarity or context.quality or 4
    local resultslist = context.resultslist
    local quality = context.quality

    if context.petID then
        local petInfo = GetPetInfo(context.petID)
        if petInfo then
            speciesID = petInfo.speciesID
            rarity = petInfo.rarity
            resultslist = petInfo.resultslist
            quality = petInfo.quality
        end
    elseif context.level and context.maxHealth and context.power and context.speed then
        local breedNum
        breedNum, quality, resultslist = CalculateBreedID(
            speciesID,
            context.rarity or 4,
            context.level,
            context.maxHealth,
            context.power,
            context.speed,
            context.wild or false,
            context.flying or false
        )
    end

    local tooltip = GetTooltip(self.tooltipName)
    tooltip:Hide()
    tooltip:ClearLines()
    tooltip:ClearAllPoints()
    tooltip:SetParent(parent)
    tooltip:SetOwner(parent, "ANCHOR_NONE")
    tooltip:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, tooltipDistance or 2)
    ResetTooltipMinimumWidth(tooltip)

    local currentNames = JoinBreedNames(resultslist)
    if currentNames then
        tooltip:AddLine(LABEL .. "Current Breed:" .. WHITE .. " " .. currentNames, 1, 1, 1, true)
    end

    local collected = GetCollectedText(speciesID)
    if collected then
        tooltip:AddLine(LABEL .. "Collected:" .. WHITE .. " " .. collected, 1, 1, 1, true)
    end

    local possibleBreeds = Arrays.BreedsPerSpecies[speciesID]
    local possibleLabel = possibleBreeds and #possibleBreeds == 1 and "Possible Breed:" or "Possible Breeds:"
    tooltip:AddLine(LABEL .. possibleLabel .. WHITE .. " " .. JoinPossibleBreeds(speciesID), 1, 1, 1, true)

    local base = Arrays.BasePetStats[speciesID]
    if base and possibleBreeds then
        local currentSet = BuildCurrentSet(resultslist)
        local statQuality = 4 -- Match BPBID defaults: assume Rare at level 25.
        if rarity and rarity > 4 then
            statQuality = rarity
        end
        local qualityColor = ITEM_QUALITY_COLORS[math.max(0, statQuality - 1)]
        local hex = qualityColor and qualityColor.hex or "|cFF0070DD"

        if type(resultslist) == "table" then
            for _, breedID in ipairs(resultslist) do
                local stats = Level25Stats(speciesID, breedID, statQuality)
                if stats then
                    tooltip:AddLine(hex .. RetrieveBreedName(breedID) .. "* at 25:|r " .. stats, 1, 1, 1, true)
                end
            end
        end

        for _, breedID in ipairs(possibleBreeds) do
            if not currentSet[breedID] then
                local stats = Level25Stats(speciesID, breedID, statQuality)
                if stats then
                    tooltip:AddLine(hex .. RetrieveBreedName(breedID) .. " at 25:|r " .. stats, 1, 1, 1, true)
                end
            end
        end
    end

    if tooltip:NumLines() == 0 then
        tooltip:Hide()
        return nil
    end

    MatchTooltipFonts(tooltip)
    FitTooltipToContent(tooltip, parent)
    tooltip:Show()
    return tooltip
end

function BreedInfo:BuildPetContext(petID)
    return GetPetInfo(petID)
end

function BreedInfo:BuildStatsContext(speciesID, level, rarity, maxHealth, power, speed)
    if not speciesID then
        return nil
    end
    local adjustedRarity = rarity
    if adjustedRarity ~= nil and adjustedRarity <= 5 then
        -- BattlePetToolTip_Show/FloatingBattlePet_Show pass zero-based rarity.
        adjustedRarity = adjustedRarity + 1
    end
    return {
        speciesID = speciesID,
        level = level,
        rarity = adjustedRarity,
        maxHealth = maxHealth,
        power = power,
        speed = speed,
    }
end


function BreedInfo:GetPetCardDisplay(petID)
    local info = GetPetInfo(petID)
    if not info or type(info.breedNum) ~= "number" then
        return nil
    end

    return {
        breedID = info.breedNum,
        quality = info.quality or info.rarity,
        name = GetDXBreedName(info.breedNum),
        icon = GetDXBreedIcon(info.breedNum, 0.75, -3, -1),
    }
end

BreedInfo.GetDXBreedName = GetDXBreedName
BreedInfo.GetDXBreedIcon = GetDXBreedIcon

BreedInfo.CalculateBreedID = CalculateBreedID
BreedInfo.RetrieveBreedName = RetrieveBreedName

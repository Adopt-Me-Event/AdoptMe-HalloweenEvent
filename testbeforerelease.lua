-- // ================================================================= --
-- // 1. Rayfield Library Loading & Core Services
-- // // ================================================================= --
local START_TIME = tick() 
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))() -- KEEP YOUR CURRENT LOADER URL HERE!

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Configuration Constants
local REAL_CLIENT_DATA_PATH = "ClientModules.Core.ClientData"
local DISPLAY_CLIENT_MODULE_NAME = "PlayersDataModule"
local DAILY_MODULE_PATH = "new.modules.Dailies.DailiesClient"
local DAILY_MANAGER_FUNC = "get_manager"
local DAILY_DATA_SECTION_KEY = "vanilla"
local TIME_KEY = "next_distribution_timestamp"
local AGE_POTION_KIND = "pet_age_potion"
local TINY_AGE_POTION_KIND = "tiny_pet_age_potion" 
local PET_OBJECT_CREATOR_TYPE = "__Enum_PetObjectCreatorType_2"
local FULL_GROWN_AGE_THRESHOLD = 6 -- Adopt Me Pet Ages usually go from 1 to 6 (Full Grown)

-- Black Friday Merchant Configuration (From User's script)
local TARGET_INVENTORY_TABLES = {
    "pet_accessories",
    "toys",
}
local TARGET_MERCHANT_NAME = "black_friday_2025_merchant"
local MAX_ITEMS_TO_SEND = 100 
local ACTION_STRING = "UseBlock" 
local blockIdToUse = nil -- This will be dynamically discovered later

-- Remote Function Paths & Refs (Now defined centrally)
local API = ReplicatedStorage:WaitForChild("API", 10)
local ToolAPI_Equip = nil 
local ToolAPI_Unequip = nil 
local PetObjectAPI_CreatePetObject = nil 
local DoNeonFusion = API and API:WaitForChild("PetAPI/DoNeonFusion", 10) 
local ActivateInteriorFurniture = API and API:WaitForChild("HousingAPI/ActivateInteriorFurniture", 10) 

-- Global State & Cache
local ClientDataModule = nil
local DailyClientModule = nil
local PetDataMap = {} 
local cachedDailyData = nil
local isPetDataModuleLoaded = false
local currentSelectedPetName = "No Pets Found" 
local currentMassAgeTargetName = nil 
local currentRemainingTime = 0
local timerLoop = nil 
local isUpdatingDailyData = false
local christmasTimerConnection = nil 
local isChristmasTimerEnabled = true 

-- Automation States
local isColliderSearchActive = false 
local isMassAgingEnabled = false 
local isMassTinyAgingEnabled = false 
local isAutoNeonEnabled = false 
local isMegaNeonEnabled = false 
local agePotionUniqueId = nil 

-- UI References
local PetInspectorDropdown = nil 
local MassAgeTargetDropdown = nil 
local BucksXPAmountLabel = nil
local BucksRawAmountLabel = nil
local PotionsLabel = nil
local DailyTaskTimerLabel = nil 
local DailyTaskAchievementsLabel = nil 
local ReleaseNotesLabel = nil
local ChristmasTimerLabel = nil 
local PetsTab = nil
local OthersTab = nil 
local FeaturesTab = nil
local EventsTab = nil 

local SelectedPetNameLabel = nil 
local SelectedPetAgeLabel = nil  
local SelectedPetXPLabel = nil   
local AdminAbuseTab = nil 
local ColliderCountLabel = nil 
local ColliderSearchConnection = nil 

local InteriorsM = nil
local UIManager = nil

-- Connections
local clientDataChangedConnection = nil 

-- ICON ID
local PLACEHOLDER_ICON_ID = 4483362458
local AGE_ICON_ID = 14030790575 -- Birthday Cake
local XP_ICON_ID = 6520790805    -- Speedometer


-- // ================================================================= --
-- // 2. Core Helper Functions
-- // ================================================================= --

function requireNestedModule(pathString)
    local pathParts = string.split(pathString, ".")
    local currentInstance = ReplicatedStorage
    
    for i = 1, #pathParts - 1 do
        local part = pathParts[i]
        local nextInstance = currentInstance:FindFirstChild(part)
        if nextInstance then currentInstance = nextInstance else warn(string.format("requireNestedModule: Could not find intermediate path part '%s' for path '%s'.", part, pathString)); return nil end
    end
    
    local moduleName = pathParts[#pathParts]
    local moduleScript = currentInstance:WaitForChild(moduleName, 10)

    if moduleScript and moduleScript:IsA("ModuleScript") then
        local success, module = pcall(require, moduleScript)
        if success and typeof(module) == "table" and next(module) ~= nil then
            return module
        else
            warn(string.format("requireNestedModule: ModuleScript at '%s' loaded, but result was nil, not a table, or empty (Success: %s).", pathString, tostring(success)))
        end
    elseif not moduleScript then
        warn(string.format("requireNestedModule: Final module '%s' timed out or was not found in '%s'.", moduleName, currentInstance.Name))
    else
        warn(string.format("requireNestedModule: Found instance '%s', but it is not a ModuleScript.", moduleScript.Name))
    end
    return nil
end

function formatTime(seconds)
    local displaySeconds = math.max(0, seconds)
    if displaySeconds <= 0 then return "NOW (Reset Overdue)" end
    local totalHours = displaySeconds / 3600
    return string.format("%.1f Total Hours", totalHours)
end

local function getAchievementSummary(activeDailies)
    local dailies = activeDailies and activeDailies.active_dailies
    if not dailies or next(dailies) == nil then return "No active daily tasks found." end
    local summary = "Active Tasks:\n"
    local sortedTaskNames = {}
    for name, data in pairs(dailies) do table.insert(sortedTaskNames, name) end
    table.sort(sortedTaskNames)
    for _, taskName in ipairs(sortedTaskNames) do
        local taskData = dailies[taskName]
        local progress = (taskData.state and taskData.state.steps_completed) or 0
        local target = (taskData.state and taskData.state.steps_to_complete) or 0
        local stateIcon = " (NEW!)"
        if progress >= target and target > 0 then stateIcon = " (COMPLETED)" elseif progress > 0 then stateIcon = " (IN PROGRESS)" end
        local taskDescription = taskData.kind or taskName
        summary = summary .. string.format("  - %s: %d/%d%s\n", taskDescription, progress, target, stateIcon)
    end
    return "Active Tasks Summary:\n" .. summary:gsub("\n", " | "):sub(1, -4)
end

function fetchDailyTaskData()
    if not DailyClientModule then
        DailyClientModule = requireNestedModule(DAILY_MODULE_PATH)
        if not DailyClientModule then warn("Could not load DailyClientModule."); return nil end
    end
    local success, manager = pcall(DailyClientModule[DAILY_MANAGER_FUNC], DailyClientModule)
    if not success or not manager then warn("fetchDailyTaskData: Failed to get Manager object via get_manager()."); return nil end
    local tabData = manager.serialized_tabs
    if tabData and typeof(tabData) == "table" and tabData[DAILY_DATA_SECTION_KEY] then
        local targetData = tabData[DAILY_DATA_SECTION_KEY]
        if targetData and targetData[TIME_KEY] then
            cachedDailyData = targetData
            return cachedDailyData
        end
    end
    warn("fetchDailyTaskData: Manager data did not yield valid data for '" .. TIME_KEY .. "'."); return nil
end

function getAgePotionCount()
    if not ClientDataModule or not ClientDataModule.get_data or not LocalPlayer then return "N/A" end
    local serverData = ClientDataModule:get_data()
    if not serverData then return "N/A" end
    local playerData = serverData[LocalPlayer.Name]
    local playerFoods = playerData and playerData.inventory and playerData.inventory.food
    if not playerFoods then return "N/A" end
    
    local normalPotions = 0
    local tinyPotions = 0
    
    for _, itemData in pairs(playerFoods) do
        local count = (typeof(itemData.count) == "number") and itemData.count or 1
        if itemData.id == AGE_POTION_KIND then
            normalPotions = normalPotions + count
        elseif itemData.id == TINY_AGE_POTION_KIND then
            tinyPotions = tinyPotions + count
        end
    end
    
    return string.format("Normal: %d | Tiny: %d", normalPotions, tinyPotions)
end

-- Attempt to read Bucks XP multiplier from potentially changed UI path
function getBucksXPAmount()
    if not LocalPlayer then return "N/A (LocalPlayer Not Ready)" end
    local indicatorPath = Players.LocalPlayer.PlayerGui:FindFirstChild("BucksIndicatorApp")
    
    -- Primary Path
    local amountLabel = indicatorPath 
        and indicatorPath:FindFirstChild("CurrencyIndicator") 
        and indicatorPath.CurrencyIndicator:FindFirstChild("Container") 
        and indicatorPath.CurrencyIndicator.Container:FindFirstChild("Multiplier") 
        and indicatorPath.CurrencyIndicator.Container.Multiplier:FindFirstChild("Amount")
        
    if not amountLabel then
        -- Fallback Path (Trying common alternative naming structure)
        amountLabel = indicatorPath 
            and indicatorPath:FindFirstChild("CurrencyIndicator") 
            and indicatorPath.CurrencyIndicator:FindFirstChild("MultiplierAmount")
    end

    if amountLabel and amountLabel:IsA("TextLabel") then 
        if amountLabel.Text ~= "" then
            return amountLabel.Text 
        end
    end
    
    return "N/A (Label Path Invalid or Not a TextLabel)"
end

function getBucksRawAmount()
    if not LocalPlayer then return "N/A (LocalPlayer Not Ready)" end
    local indicatorPath = Players.LocalPlayer.PlayerGui:FindFirstChild("BucksIndicatorApp")
    local rawAmountLabel = indicatorPath and indicatorPath:FindFirstChild("CurrencyIndicator") and indicatorPath.CurrencyIndicator:FindFirstChild("Container") and indicatorPath.CurrencyIndicator.Container:FindFirstChild("Amount")
    if rawAmountLabel and rawAmountLabel:IsA("TextLabel") then return rawAmountLabel.Text end
    return "N/A (Label Path Invalid or Not a TextLabel)"
end

function getTimeUntilChristmas()
    local now = os.time()
    local currentYear = tonumber(os.date("%Y", now))
    local christmasDate = os.time({year = currentYear, month = 12, day = 25, hour = 0, min = 0, sec = 0})
    if now > christmasDate then christmasDate = os.time({year = currentYear + 1, month = 12, day = 25, hour = 0, min = 0, sec = 0}) end
    local remainingSeconds = christmasDate - now
    local seconds = remainingSeconds % 60
    local minutes = math.floor(remainingSeconds / 60) % 60
    local hours = math.floor(remainingSeconds / 3600) % 24
    local days = math.floor(remainingSeconds / 86400)
    if remainingSeconds <= 0 then return "Christmas has arrived! Merry Christmas!", 0 end
    return string.format("%d days, %02d:%02d:%02d", days, hours, minutes, seconds), remainingSeconds
end

function getPetDataForUI()
    if not isPetDataModuleLoaded or not ClientDataModule or not LocalPlayer then return {"Module Not Ready"}, {} end
    local serverData = ClientDataModule:get_data()
    if not serverData then return {"No Server Data"}, {} end
    local playerData = serverData[LocalPlayer.Name]
    local playerPets = playerData and playerData.inventory and playerData.inventory.pets
    if not playerPets or next(playerPets) == nil then return {"No Pets Found"}, {} end

    local options = {}
    local tempPetDataMap = {}

    for uniqueId, petData in pairs(playerPets) do
        local properties = petData.properties or {}
        local petKind = petData.id or "Unknown Pet"
        local displayPrefix = ""
        if properties.mega_neon then displayPrefix = "[MEGA NEON] " elseif properties.neon then displayPrefix = "[NEON] " end
        local uniqueIdStart = string.sub(uniqueId, 1, 6)
        local uniqueIdEnd = string.sub(uniqueId, -6)
        local petAge = math.floor(properties.age or 0)
        local petXP = math.floor(properties.xp or 0)
        local displayName = string.format("%s%s | Age: %d | XP: %d | ID: [%s...%s]", displayPrefix, petKind, petAge, petXP, uniqueIdStart, uniqueIdEnd)
        local count = 1
        local originalDisplayName = displayName
        while tempPetDataMap[displayName] do count = count + 1; displayName = string.format("%s #%d", originalDisplayName, count) end

        table.insert(options, displayName)
        tempPetDataMap[displayName] = petData
        tempPetDataMap[displayName].unique = uniqueId
        tempPetDataMap[displayName].age = petAge 
        tempPetDataMap[displayName].xp = petXP   
        tempPetDataMap[displayName].kind = petKind 
    end
    return options, tempPetDataMap
end

-- --- Utility Function to Wait for Data (for Automation) ---
local function waitForData()
    local data = ClientDataModule:get_data()
    while not data do
        task.wait(0.5)
        data = ClientDataModule:get_data()
    end
    return data
end

-- Function to find the unique ID of the first food item/age potion
local function findAgePotionUniqueId(foodInventory, potionKindId)
    for uniqueId, itemData in pairs(foodInventory) do
        if itemData.id == potionKindId then 
             return uniqueId 
        end
    end
    return nil 
end


-- // ================================================================= --
-- // 3. UI Handlers & Initialization
-- // ================================================================= --

function startChristmasTimer()
    if christmasTimerConnection then
        christmasTimerConnection:Disconnect()
        christmasTimerConnection = nil
    end

    if ChristmasTimerLabel then
        christmasTimerConnection = RunService.Heartbeat:Connect(function()
            local timeString, remaining = getTimeUntilChristmas()
            
            if ChristmasTimerLabel then
                ChristmasTimerLabel:Set("Time Until Christmas:\n" .. timeString, PLACEHOLDER_ICON_ID)
            end
            
            if remaining <= 0 and christmasTimerConnection then
                christmasTimerConnection:Disconnect()
                christmasTimerConnection = nil
            end
        end)
    end
end

function startTimerCountdown()
    if timerLoop and task.cancel then 
        local success, err = pcall(task.cancel, timerLoop)
        if not success then warn("Failed to cancel previous daily timer thread (might be dead): " .. tostring(err)) end
    end
    timerLoop = nil
    task.wait() 

    if currentRemainingTime <= 0 then
        if DailyTaskTimerLabel then DailyTaskTimerLabel:Set(string.format("Time until next achievement reset:\n%s", formatTime(0)), PLACEHOLDER_ICON_ID) end
        return
    end
    
    timerLoop = task.spawn(function()
        while currentRemainingTime > 0 do
            if DailyTaskTimerLabel then DailyTaskTimerLabel:Set(string.format("Time until next achievement reset:\n%s", formatTime(currentRemainingTime)), PLACEHOLDER_ICON_ID) end
            wait(1)
            currentRemainingTime = currentRemainingTime - 1
            if currentRemainingTime < 0 then currentRemainingTime = 0 end
        end
        if DailyTaskTimerLabel then DailyTaskTimerLabel:Set(string.format("Time until next achievement reset:\n%s", formatTime(0)), PLACEHOLDER_ICON_ID) end
        timerLoop = nil 
        updateDailyTaskLabels(true)
    end)
end

function updateDailyTaskLabels(forceTimerRestart)
    if isUpdatingDailyData then return end
    isUpdatingDailyData = true
    local success, err = pcall(function()
        if DailyTaskTimerLabel and DailyTaskAchievementsLabel then
            local dailyData = fetchDailyTaskData()
            local achievementsText = "Active Achievements: Data Unavailable"
            if dailyData then
                local nextTimestamp = tonumber(dailyData[TIME_KEY]) or 0
                local remainingSeconds = math.max(0, nextTimestamp - tick())
                local timeHasChanged = math.abs(currentRemainingTime - remainingSeconds) > 5
                
                if forceTimerRestart or timeHasChanged or currentRemainingTime <= 0 then
                    currentRemainingTime = remainingSeconds
                    startTimerCountdown()
                end

                if currentRemainingTime <= 0 and DailyTaskTimerLabel then
                    DailyTaskTimerLabel:Set(string.format("Time until next achievement reset:\n%s", formatTime(0)), PLACEHOLDER_ICON_ID)
                end
                achievementsText = getAchievementSummary(dailyData)
            end
            DailyTaskAchievementsLabel:Set(achievementsText, PLACEHOLDER_ICON_ID)
        end
    end)
    isUpdatingDailyData = false
    if not success then
        warn("Error in updateDailyTaskLabels pcall: " .. tostring(err))
        if DailyTaskTimerLabel then DailyTaskTimerLabel:Set("ERROR: Data update failed.", PLACEHOLDER_ICON_ID) end
    end
end

function updateInventoryLabels()
    if PotionsLabel and BucksXPAmountLabel and BucksRawAmountLabel then
        local potionCountString = getAgePotionCount() 
        local xpAmount = getBucksXPAmount()
        local rawAmount = getBucksRawAmount()
        PotionsLabel:Set(string.format("Pet Age Potions: %s", potionCountString), PLACEHOLDER_ICON_ID)
        BucksXPAmountLabel:Set(string.format("Bucks XP Amount (Multiplier): %s", tostring(xpAmount)), PLACEHOLDER_ICON_ID)
        BucksRawAmountLabel:Set(string.format("Bucks Amount (Cash): %s", tostring(rawAmount)), PLACEHOLDER_ICON_ID)
    end
end

-- Ensuring Age and XP are correctly pulled from the map
function updatePetDetailsLabels()
    -- This function only uses the selection from the PETS tab dropdown
    local petData = PetDataMap[currentSelectedPetName]
    local petNameText = "N/A (No Pet Selected)"
    local ageText = "N/A"
    local xpText = "N/A"
    
    if petData and petData.kind then
        local rawKind = petData.kind
        petNameText = rawKind:gsub("_", " "):gsub("([%a])([%a]*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
        
        -- Use math.floor to remove decimals and tostring to ensure display compatibility
        ageText = tostring(math.floor(petData.age or 0)) 
        xpText = tostring(math.floor(petData.xp or 0))   
    end

    if SelectedPetNameLabel then
        SelectedPetNameLabel:Set(string.format("Selected Pet: %s", petNameText), PLACEHOLDER_ICON_ID) 
    end
    if SelectedPetAgeLabel then
        SelectedPetAgeLabel:Set(string.format("Selected Pet Age: %s", ageText), AGE_ICON_ID)
    end
    if SelectedPetXPLabel then
        SelectedPetXPLabel:Set(string.format("Selected Pet XP: %s", xpText), XP_ICON_ID)
    end
end

function handleClientDataRefresh()
    local newOptions, newMap = getPetDataForUI()
    
    -- Check if Pet Data changed significantly enough to warrant a dropdown refresh
    local petsDataChanged = (#PetDataMap ~= #newMap) or (PetDataMap[currentSelectedPetName] == nil)
    
    PetDataMap = newMap
    
    -- === PETS TAB DROPDOWN (Equip Target) Logic ===
    local equipSelectionToSet = currentSelectedPetName
    if not PetDataMap[currentSelectedPetName] then
        equipSelectionToSet = newOptions[1] or "No Pets Found"
        currentSelectedPetName = equipSelectionToSet
        petsDataChanged = true
    end
    if PetInspectorDropdown and petsDataChanged then
        PetInspectorDropdown:Refresh(newOptions)
        PetInspectorDropdown:Set(equipSelectionToSet)
    end
    
    -- === OTHERS TAB DROPDOWN (Mass Age Target) Logic ===
    local massAgeSelectionToSet = currentMassAgeTargetName
    if not PetDataMap[currentMassAgeTargetName] then
        massAgeSelectionToSet = newOptions[1] or "No Pets Found"
        currentMassAgeTargetName = massAgeSelectionToSet
        petsDataChanged = true 
    end
    if MassAgeTargetDropdown and petsDataChanged then
        MassAgeTargetDropdown:Refresh(newOptions)
        MassAgeTargetDropdown:Set(massAgeSelectionToSet)
    end
    
    updatePetDetailsLabels() 
    updateInventoryLabels()
end

function equipSelectedPet()
    local petData = PetDataMap[currentSelectedPetName]
    local isInvalidSelection = not petData or not petData.unique or currentSelectedPetName == "No Pets Found" or currentSelectedPetName == "Module Not Ready"
    if isInvalidSelection then
        local message = "equipSelectedPet: Invalid pet selected or pet data missing."
        if currentSelectedPetName == "No Pets Found" or currentSelectedPetName == "Module Not Ready" then print(message) else warn(message) end
        updatePetDetailsLabels(); return
    end
    local petUniqueId = petData.unique
    if not ToolAPI_Equip then
        Rayfield:Notify({ Title = "Error", Content = "Remote function 'ToolAPI/Equip' not found. Check if the remote path is correct.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 }); warn("Could not find ReplicatedStorage.API.ToolAPI/Equip RemoteFunction."); return
    end
    local options = { use_sound_delay = false, equip_as_last = false }
    local invokeSuccess, result = pcall( ToolAPI_Equip.InvokeServer, ToolAPI_Equip, petUniqueId, options )
    if invokeSuccess then
        Rayfield:Notify({ Title = "Pet Equipped Automatically", Content = string.format("Equip call sent for pet: %s", petData.id or petUniqueId), Icon = PLACEHOLDER_ICON_ID, Duration = 2 })
    else
        Rayfield:Notify({ Title = "Equip Failed", Content = string.format("InvokeServer failed for equip call: %s", tostring(result)), Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn(string.format("Pet Equip Call Failed for ID: %s. Error: %s", petUniqueId, tostring(result)))
    end
    updatePetDetailsLabels()
end

-- 💡 Unequip the currently selected pet
function unequipSelectedPet()
    local petData = PetDataMap[currentSelectedPetName]
    local isInvalidSelection = not petData or not petData.unique or currentSelectedPetName == "No Pets Found" or currentSelectedPetName == "Module Not Ready"
    if isInvalidSelection then
        Rayfield:Notify({ Title = "Unequip Failed", Content = "Invalid pet selected or pet data missing for unequip target.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Unequip Failed: Invalid pet selected for unequip.")
        updatePetDetailsLabels(); return
    end
    local petUniqueId = petData.unique
    if not ToolAPI_Unequip then
        Rayfield:Notify({ Title = "Error", Content = "Remote function 'ToolAPI/Unequip' not found. Check if the remote path is correct.", Icon = PLACEHED_ICON_ID, Duration = 5 }); warn("Could not find ReplicatedStorage.API.ToolAPI/Unequip RemoteFunction."); return
    end
    
    local args = {
        petUniqueId,
        {
            use_sound_delay = false,
            equip_as_last = false
        }
    }
    
    local invokeSuccess, result = pcall( ToolAPI_Unequip.InvokeServer, ToolAPI_Unequip, unpack(args) )
    if invokeSuccess then
        Rayfield:Notify({ Title = "Pet Unequipped", Content = string.format("Unequip call sent for pet: %s", petData.id or petUniqueId), Icon = PLACEHOLDER_ICON_ID, Duration = 2 })
    else
        Rayfield:Notify({ Title = "Unequip Failed", Content = string.format("InvokeServer failed for unequip call: %s", tostring(result)), Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn(string.format("Pet Unequip Call Failed for ID: %s. Error: %s", petUniqueId, tostring(result)))
    end
    updatePetDetailsLabels()
end


-- The main function to execute the SINGLE-TARGET aging logic once (NORMAL POTION)
local function executeMassAge()
    local petData = PetDataMap[currentMassAgeTargetName]
    local isInvalidSelection = not petData or not petData.unique or currentMassAgeTargetName == "No Pets Found" or currentMassAgeTargetName == "Module Not Ready"
    
    if isInvalidSelection then
        Rayfield:Notify({ Title = "Mass Age Failed", Content = "Invalid pet selected or pet data missing for mass age target.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Mass Age Failed: Invalid pet selected for aging.")
        return false 
    end
    
    local petUniqueId = petData.unique
    
    -- Get potion ID
    local serverData = waitForData()
    local playerData = serverData[LocalPlayer.Name]
    local playerFood = playerData and playerData.inventory and playerData.inventory.food or {}
    local potionUniqueId = findAgePotionUniqueId(playerFood, AGE_POTION_KIND) 
    
    if not potionUniqueId then 
        Rayfield:Notify({ Title = "Mass Age Failed", Content = "Normal Age Potion not found in inventory. Cannot age.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Mass Age Failed: Normal Age Potion not found.")
        return false 
    end

    local args = {
        PET_OBJECT_CREATOR_TYPE,
        {
            pet_unique = petUniqueId, 
            unique_id = potionUniqueId, 
            additional_consume_uniques = {}, 
        }
    }
    
    if not PetObjectAPI_CreatePetObject then
        Rayfield:Notify({ Title = "Mass Age Error", Content = "Remote function 'PetObjectAPI/CreatePetObject' not found.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Mass Age Error: PetObjectAPI/CreatePetObject not found.")
        return false
    end

    local success, result = pcall(function()
        return PetObjectAPI_CreatePetObject:InvokeServer(unpack(args))
    end)

    if not success then
        warn(string.format("-> Error invoking server for single pet %s: %s", petUniqueId, result))
    end

    task.wait(0.1) 
    
    handleClientDataRefresh() 
    return true
end

-- The main function to execute the SINGLE-TARGET aging logic once (TINY POTION)
local function executeMassTinyAge()
    local petData = PetDataMap[currentMassAgeTargetName]
    local isInvalidSelection = not petData or not petData.unique or currentMassAgeTargetName == "No Pets Found" or currentMassAgeTargetName == "Module Not Ready"
    
    if isInvalidSelection then
        Rayfield:Notify({ Title = "Tiny Age Failed", Content = "Invalid pet selected or pet data missing for mass age target.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Tiny Age Failed: Invalid pet selected for aging.")
        return false 
    end
    
    local petUniqueId = petData.unique
    
    -- Get potion ID
    local serverData = waitForData()
    local playerData = serverData[LocalPlayer.Name]
    local playerFood = playerData and playerData.inventory and playerData.inventory.food or {}
    local potionUniqueId = findAgePotionUniqueId(playerFood, TINY_AGE_POTION_KIND) 
    
    if not potionUniqueId then 
        Rayfield:Notify({ Title = "Tiny Age Failed", Content = "Tiny Age Potion not found in inventory. Cannot age.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Tiny Age Failed: Tiny Age Potion not found.")
        return false 
    end

    local args = {
        PET_OBJECT_CREATOR_TYPE,
        {
            pet_unique = petUniqueId, 
            unique_id = potionUniqueId, 
            additional_consume_uniques = {}, 
        }
    }
    
    if not PetObjectAPI_CreatePetObject then
        Rayfield:Notify({ Title = "Tiny Age Error", Content = "Remote function 'PetObjectAPI/CreatePetObject' not found.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Tiny Age Error: PetObjectAPI/CreatePetObject not found.")
        return false
    end

    local success, result = pcall(function()
        return PetObjectAPI_CreatePetObject:InvokeServer(unpack(args))
    end)

    if not success then
        warn(string.format("-> Error invoking server for single pet %s: %s", petUniqueId, result))
    end

    task.wait(0.1) 
    
    handleClientDataRefresh() 
    return true
end

-- 🔥 NEW FUNCTION: Auto Neon Fusion (4 Full Grown Pets)
local function executeNeonFusion()
    if not DoNeonFusion then
        Rayfield:Notify({ Title = "Neon Fusion Error", Content = "Remote function 'PetAPI/DoNeonFusion' not found.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Neon Fusion Error: PetAPI/DoNeonFusion not found.")
        return false
    end

    local petsRequired = 4
    local serverData = waitForData()
    local localPlayer = Players.LocalPlayer
    
    if not localPlayer then return false end

    local playerData = serverData[localPlayer.Name]
    if not (playerData and playerData.inventory and playerData.inventory.pets) then
        warn("Required pet inventory data tables not found.")
        return false
    end

    local playerPets = playerData.inventory.pets
    local eligiblePetsBySpecies = {}
    local targetSpeciesId = nil
    local maxCount = 0

    for uniqueId, petData in pairs(playerPets) do
        local properties = petData.properties or {}
        local isFullGrown = (properties.age or 0) >= FULL_GROWN_AGE_THRESHOLD -- Check for Full Grown age
        local isNotFused = not properties.neon and not properties.mega_neon -- Check it's not already Neon/Mega

        if isFullGrown and isNotFused then
            -- Use the base species ID
            local speciesId = petData.id:gsub("_[0-9]+$", "")
            
            if not eligiblePetsBySpecies[speciesId] then
                eligiblePetsBySpecies[speciesId] = {}
            end
            
            table.insert(eligiblePetsBySpecies[speciesId], {
                uniqueId = uniqueId,
                originalId = petData.id
            })
            
            local currentCount = #eligiblePetsBySpecies[speciesId]
            if currentCount >= petsRequired and currentCount > maxCount then
                targetSpeciesId = speciesId
                maxCount = currentCount
            end
        end
    end

    if targetSpeciesId then
        local fusionPetIds = {}
        for i = 1, petsRequired do
            table.insert(fusionPetIds, eligiblePetsBySpecies[targetSpeciesId][i].uniqueId)
        end
        
        local targetPetName = eligiblePetsBySpecies[targetSpeciesId][1].originalId
        
        local args = { fusionPetIds } 
        local fusionSuccess, result = pcall(function()
            return DoNeonFusion:InvokeServer(unpack(args))
        end)

        if fusionSuccess then
            Rayfield:Notify({ Title = "Neon Fusion Attempt", Content = string.format("Neon Fusion call sent for 4 Full Grown %s. Response: %s", targetPetName, tostring(result)), Icon = PLACEHOLDER_ICON_ID, Duration = 4 })
            handleClientDataRefresh()
            return true
        else
            Rayfield:Notify({ Title = "Neon Fusion Error", Content = "Error during InvokeServer: " .. tostring(result), Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
            warn("Error during Neon Fusion InvokeServer call: " .. tostring(result))
            return false
        end
    else
        Rayfield:Notify({ Title = "Neon Fusion Failed", Content = string.format("Could not find any species with %d eligible FULL GROWN pets (Highest count: %d).", petsRequired, maxCount), Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        return false
    end
end


-- The main function to execute the MEGA NEON fusion logic once
local function executeMegaNeonFusion()
    if not DoNeonFusion then
        Rayfield:Notify({ Title = "Mega Neon Fusion Error", Content = "Remote function 'PetAPI/DoNeonFusion' not found.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Mega Neon Fusion Error: PetAPI/DoNeonFusion not found.")
        return false
    end
    
    local petsRequired = 4
    local serverData = waitForData()
    local localPlayer = Players.LocalPlayer
    
    if not localPlayer then return false end

    local playerData = serverData[localPlayer.Name]
    if not (playerData and playerData.inventory and playerData.inventory.pets) then
        warn("Required pet inventory data tables not found.")
        return false
    end

    local playerPets = playerData.inventory.pets
    local eligiblePetsBySpecies = {}
    local targetSpeciesId = nil
    local maxCount = 0

    for uniqueId, petData in pairs(playerPets) do
        local properties = petData.properties
        if properties then
            local isNeonPet = properties.neon == true
            local hasCreationData = properties.neon_created_from and type(properties.neon_created_from) == "table"
            local isMegaNeon = properties.mega_neon == true
            
            if isNeonPet and hasCreationData and not isMegaNeon then
                -- Use the base species ID
                local speciesId = petData.id:gsub("_[0-9]+$", "")
                
                if not eligiblePetsBySpecies[speciesId] then
                    eligiblePetsBySpecies[speciesId] = {}
                end
                
                table.insert(eligiblePetsBySpecies[speciesId], {
                    uniqueId = uniqueId,
                    originalId = petData.id
                })
                
                local currentCount = #eligiblePetsBySpecies[speciesId]
                if currentCount >= petsRequired and currentCount > maxCount then
                    targetSpeciesId = speciesId
                    maxCount = currentCount
                end
            end
        end
    end

    if targetSpeciesId then
        local fusionPetIds = {}
        for i = 1, petsRequired do
            table.insert(fusionPetIds, eligiblePetsBySpecies[targetSpeciesId][i].uniqueId)
        end

        local args = { fusionPetIds } 
        local fusionSuccess, result = pcall(function()
            return DoNeonFusion:InvokeServer(unpack(args))
        end)

        if fusionSuccess then
            local targetPetName = eligiblePetsBySpecies[targetSpeciesId][1].originalId
            Rayfield:Notify({ Title = "Mega Neon Fusion Attempt", Content = string.format("Mega Neon Fusion call sent for 4 Neon %s. Response: %s", targetPetName, tostring(result)), Icon = PLACEHOLDER_ICON_ID, Duration = 4 })
            handleClientDataRefresh()
            return true
        else
            Rayfield:Notify({ Title = "Fusion Error", Content = "Error during InvokeServer: " .. tostring(result), Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
            warn("Error during InvokeServer call: " .. tostring(result))
            return false
        end
    else
        Rayfield:Notify({ Title = "Fusion Failed", Content = string.format("Could not find any species with %d eligible NEON pets (Highest count: %d).", petsRequired, maxCount), Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        return false
    end
end


-- // ================================================================= --
-- // 4. Admin Abuse (Teleport and Collider) Core Logic
-- // // ================================================================= --

-- The CFrame provided by the user for the MainMap spawn location
local spawn_cframe = CFrame.new(-275.9091491699219, 25.812084197998047, -1548.145751953125, -0.9798217415809631, 0.0000227206928684609, 0.19986890256404877, -0.000003862579433189239, 1, -0.00013261348067317158, -0.19986890256404877, -0.00013070966815575957, -0.9798217415809631)

-- Recursive function to search for the specific merchant model and return the instance
local function searchForMerchant(rootInstance, merchantName)
    if not rootInstance or not rootInstance:IsA("Instance") then
        return nil
    end

    for _, child in ipairs(rootInstance:GetDescendants()) do
        if child.Name == merchantName then
            return child 
        end
    end

    return nil
end

local function loadInteriorsModules()
    local successInteriorsM, errorMessageInteriorsM = pcall(function()
        InteriorsM = require(ReplicatedStorage.ClientModules.Core.InteriorsM.InteriorsM)
    end)

    if not successInteriorsM or not InteriorsM then
        warn("Failed to require InteriorsM:", errorMessageInteriorsM)
        InteriorsM = nil 
        return false
    end

    local successUIManager, errorMessageUIManager = pcall(function()
        UIManager = require(ReplicatedStorage:WaitForChild("Fsys")).load("UIManager")
    end)

    if not successUIManager or not UIManager then
        warn("Failed to require UIManager module:", errorMessageUIManager)
        UIManager = nil
        return false
    end
    
    return true
end

-- Teleport function now accepts a callback
local function executeMainMapTeleport(callbackOnComplete)
    if not InteriorsM or not UIManager then
        Rayfield:Notify({ Title = "TP Disabled", Content = "Core teleport modules (InteriorsM/UIManager) are missing.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("MainMap teleport failed: Core modules not loaded.")
        return
    end

    Rayfield:Notify({ Title = "Auto Teleport", Content = "Initiating smooth teleport to MainMap... (Wait 2-3 seconds)", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
    
    local destinationId = "MainMap"
    local doorIdForTeleport = "MainDoor" 
    
    local teleportSettings = {
        house_owner = LocalPlayer; 
        spawn_cframe = spawn_cframe; 
        fade_in_length = 0.5, 
        fade_out_length = 0.4, 
        fade_color = Color3.new(0, 0, 0),
        teleport_completed_callback = function() 
            print("MainMap teleport completed.")
            task.wait(1.0) -- Wait a bit after completion before running the callback
            if callbackOnComplete and type(callbackOnComplete) == "function" then
                callbackOnComplete()
            end
        end,
        anchor_char_immediately = true,
        post_character_anchored_wait = 0.5,
        move_camera = true,
    }

    task.spawn(function()
        InteriorsM.enter_smooth(destinationId, doorIdForTeleport, teleportSettings, nil)
    end)
end

local function startColliderSearch()
    if ColliderSearchConnection then return end

    local collidersFound = 0
    
    ColliderSearchConnection = RunService.Heartbeat:Connect(function()
        if not isColliderSearchActive or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if ColliderCountLabel then
                 ColliderCountLabel:Set("Colliders Found: 0 (Disabled/No Character)", PLACEHOLDER_ICON_ID)
            end
            return
        end
        
        local characterHRP = LocalPlayer.Character.HumanoidRootPart
        collidersFound = 0 
        local didTeleport = false

        for _, object in pairs(Workspace:GetChildren()) do
            if object.Name == "StaticMap" or object:IsA("Folder") then continue end

            for _, colliderPart in pairs(object:GetDescendants()) do
                if colliderPart.Name == "Collider" and colliderPart:IsA("BasePart") then
                    collidersFound = collidersFound + 1
                    
                    if not didTeleport then
                        -- Teleport to the collider
                        characterHRP.CFrame = CFrame.new(colliderPart.Position + Vector3.new(0, 5, 0))
                        didTeleport = true
                    end
                end
            end
        end

        if ColliderCountLabel then
             ColliderCountLabel:Set(string.format("Colliders Found: %d%s", collidersFound, didTeleport and " (Teleported!)" or ""), PLACEHOLDER_ICON_ID)
        end
        
    end)
end

local function stopColliderSearch()
    if ColliderSearchConnection then
        ColliderSearchConnection:Disconnect()
        ColliderSearchConnection = nil
    end
     if ColliderCountLabel then
         ColliderCountLabel:Set("Colliders Found: 0 (Disabled)", PLACEHOLDER_ICON_ID)
     end
end

-- 🔥 NEW FUNCTION: Executes the merchant trade logic after successful setup
local function executeMerchantTrade()
    if not ActivateInteriorFurniture then
        Rayfield:Notify({ Title = "Trade Failed", Content = "HousingAPI/ActivateInteriorFurniture RemoteFunction not found.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Trade Failed: HousingAPI/ActivateInteriorFurniture not found.")
        return
    end

    if not blockIdToUse then
        Rayfield:Notify({ Title = "Trade Failed", Content = "Block ID for merchant was not discovered. Cannot proceed.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        warn("Trade Failed: Block ID not set.")
        return
    end
    
    Rayfield:Notify({ Title = "Trade Started", Content = string.format("Collecting inventory items (max %d) for trade...", MAX_ITEMS_TO_SEND), Icon = PLACEHOLDER_ICON_ID, Duration = 3 })


    local allTradeItems = {}
    local totalItemsCollected = 0
    local rKeyCounter = 1 

    local serverData = waitForData()
    local localPlayer = Players.LocalPlayer

    if not localPlayer or not serverData then
        Rayfield:Notify({ Title = "Trade Failed", Content = "Player or data not ready.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        return
    end

    local playerData = serverData[localPlayer.Name]
    local playerInventory = playerData and playerData.inventory

    if not playerInventory or type(playerInventory) ~= "table" then
        Rayfield:Notify({ Title = "Trade Failed", Content = "Required inventory data not found.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        return
    end

    -- Process all configured inventory types
    for _, category in ipairs(TARGET_INVENTORY_TABLES) do
        local inventoryTable = playerInventory[category]
        if inventoryTable then
            for itemKey, _ in pairs(inventoryTable) do
                if totalItemsCollected < MAX_ITEMS_TO_SEND then
                    local rKey = "r_" .. rKeyCounter
                    
                    allTradeItems[rKey] = itemKey
                    
                    totalItemsCollected = totalItemsCollected + 1
                    rKeyCounter = rKeyCounter + 1
                else
                    break
                end
            end
        end
        if totalItemsCollected >= MAX_ITEMS_TO_SEND then
            break
        end
    end
    
    if totalItemsCollected == 0 then
        Rayfield:Notify({ Title = "Trade Cancelled", Content = "Found 0 eligible items (pet accessories/toys).", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
        return
    end

    Rayfield:Notify({ Title = "Trade Items Ready", Content = string.format("Collected %d items. Invoking server API...", totalItemsCollected), Icon = PLACEHOLDER_ICON_ID, Duration = 2 })

    local Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    
    -- The arguments for the InvokeServer call
    local args = {
        blockIdToUse,
        ACTION_STRING,
        allTradeItems,
        Character
    }
    
    local success, result = pcall(function()
        return ActivateInteriorFurniture:InvokeServer(unpack(args))
    end)

    if success then
        local responseMsg = (type(result) == "table" and "Success (Table response)" or tostring(result) or "Success (nil response)")
        Rayfield:Notify({ 
            Title = "Trade SUCCESS! ✅", 
            Content = string.format("Successfully traded %d items to the merchant. Server response: %s", totalItemsCollected, responseMsg), 
            Icon = PLACEHOLDER_ICON_ID, 
            Duration = 7 
        })
    else
        Rayfield:Notify({ 
            Title = "Trade FAILED ❌", 
            Content = string.format("Error trading %d items to the merchant. Error: %s", totalItemsCollected, tostring(result)), 
            Icon = PLACEHOLDER_ICON_ID, 
            Duration = 7 
        })
        warn("Error during InvokeServer:", result)
    end
end


-- // ================================================================= --
-- // 5. UI Initialization Functions
-- // ================================================================= --

local function createAdminAbuseUI()
    if AdminAbuseTab then
        AdminAbuseTab:CreateSection("Map Teleport / Collider Finder")
        
        -- Assign the UI reference globally
        ColliderCountLabel = AdminAbuseTab:CreateLabel("Colliders Found: 0 (Disabled/No Character)", PLACEHOLDER_ICON_ID)

        AdminAbuseTab:CreateToggle({
            Name = "Enable Collider Search & Teleport (Auto-TP to MainMap) 🚀",
            Description = "**Enables Auto-Teleport to MainMap on activation.** Then starts searching for objects named 'Collider' and teleports you to the first one found for easy collection.",
            Callback = function(state)
                isColliderSearchActive = state
                if state then
                    -- 1. Execute MainMap Teleport first (No callback needed here, as the collider search will run on its own thread after a delay)
                    executeMainMapTeleport(function()
                        -- This callback runs after teleport, but we rely on the loop for collider finding
                        task.wait(1) 
                        startColliderSearch()
                    end)
                    Rayfield:Notify({ Title = "Admin TP Active", Content = "Auto-Teleport initiated. Starting Collider Search now.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                else
                    stopColliderSearch()
                    Rayfield:Notify({ Title = "Admin TP Disabled", Content = "Stopped Collider Search.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                end
            end
        })
    end
end


function initializeClientDataModule()
    local INIT_START_TIME = tick() 

    if not ClientDataModule then
        ClientDataModule = requireNestedModule(REAL_CLIENT_DATA_PATH) 
        if ClientDataModule then
            isPetDataModuleLoaded = true
            
            -- Load Interiors Modules for Admin Abuse Teleport
            local modulesLoaded = loadInteriorsModules()
            
            -- Find Remote Functions (API)
            if API then
                local equipFunction = API:WaitForChild("ToolAPI/Equip", 10)
                if equipFunction and equipFunction:IsA("RemoteFunction") then ToolAPI_Equip = equipFunction end
                
                local unequipFunction = API:WaitForChild("ToolAPI/Unequip", 10)
                if unequipFunction and unequipFunction:IsA("RemoteFunction") then ToolAPI_Unequip = unequipFunction end

                local createPetObjectFunction = API:WaitForChild("PetObjectAPI/CreatePetObject", 10)
                if createPetObjectFunction and createPetObjectFunction:IsA("RemoteFunction") then PetObjectAPI_CreatePetObject = createPetObjectFunction end
            end
            
            -- Hook Data Callback
            if ClientDataModule.register_callback and ClientDataModule.get_data then
                clientDataChangedConnection = ClientDataModule:register_callback(function()
                    handleClientDataRefresh()
                end)
            else
                warn(DISPLAY_CLIENT_MODULE_NAME .. ":register_callback() is missing. Falling back to periodic updates.")
                -- FALLBACK: Heartbeat for Inventory/Pet Data
                local lastLiveUpdateTick = 0
                RunService.Heartbeat:Connect(function()
                    local currentTime = tick()
                    if currentTime - lastLiveUpdateTick >= 3 then
                        handleClientDataRefresh()
                        lastLiveUpdateTick = currentTime
                    end
                end)
            end
            
            
            -- Initialize UI components and populate dropdowns
            local newOptions, newMap = getPetDataForUI()
            PetDataMap = newMap
            local defaultSelection = newOptions[1] or "No Pets Found"
            currentSelectedPetName = defaultSelection
            currentMassAgeTargetName = defaultSelection
            
            
            -- 🔥 DISCOVER BLOCK ID FOR TRADE SCRIPT
            if modulesLoaded then
                local furnitureContainer = Workspace:FindFirstChild("HouseInteriors", true)
                if furnitureContainer then
                    furnitureContainer = furnitureContainer:FindFirstChild("furniture", true)
                end

                if furnitureContainer then
                    local merchantInstance = searchForMerchant(furnitureContainer, TARGET_MERCHANT_NAME)

                    if merchantInstance and merchantInstance.Parent then
                        local fullBlockId = merchantInstance.Parent.Name
                        blockIdToUse = fullBlockId:match("[^/]*$")
                        print(string.format("Merchant Block ID discovered: %s", blockIdToUse))
                    else
                        warn(string.format("Merchant block '%s' NOT found after module load.", TARGET_MERCHANT_NAME))
                    end
                else
                    warn("Furniture container not found for block ID discovery.")
                end
            end


            -- [[ Pets Tab ]]
            if PetsTab then
                PetsTab:CreateSection("Pet Manager")
                
                -- **FIXED:** Updated icons for Age/XP labels
                SelectedPetNameLabel = PetsTab:CreateLabel("Selected Pet: N/A (No Pet Selected)", PLACEHOLDER_ICON_ID)
                
                SelectedPetAgeLabel = PetsTab:CreateLabel("Selected Pet Age: N/A", AGE_ICON_ID)
                SelectedPetXPLabel = PetsTab:CreateLabel("Selected Pet XP: N/A", XP_ICON_ID)

                PetInspectorDropdown = PetsTab:CreateDropdown({
                    Name = "Select Pet (Species | Age | XP | ID)",
                    Description = "Select a single pet from your inventory. Selection will **automatically equip** the pet.",
                    Options = newOptions,
                    CurrentOption = {defaultSelection},
                    MultipleOptions = false, 
                    Flag = "PetInspectorDropdown",
                    Callback = function(options)
                        local selected = options[1]
                        currentSelectedPetName = selected
                        -- Automatic equip on dropdown selection for the Pets tab
                        equipSelectedPet() 
                    end
                })
                
                -- Explicit Equip Button
                PetsTab:CreateButton({
                    Name = "Re-Equip Selected Pet 🎒",
                    Description = "Sends a server request to explicitly equip the pet, even if already equipped.",
                    Callback = function()
                        equipSelectedPet()
                    end
                })
                
                -- Explicit Unequip Button
                PetsTab:CreateButton({
                    Name = "Unequip Selected Pet 🚫",
                    Description = "Sends a server request to unequip the pet currently selected in the dropdown.",
                    Callback = function()
                        unequipSelectedPet()
                    end
                })
                
                -- === NEW "FARMING" TOGGLES ===
                PetsTab:CreateSection("Farming Status (Coming Soon)")
                
                PetsTab:CreateToggle({
                    Name = "Pet Farm Coming Soon! 🐕",
                    Description = "Placeholder for future auto-farm logic for pets.",
                    CurrentValue = false,
                    Flag = "PetFarmToggle", 
                    Callback = function(Value)
                        if Value then
                            Rayfield:Notify({ Title = "Future Feature", Content = "Pet Farm logic is not yet implemented.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                        end
                    end,
                })
                
                PetsTab:CreateToggle({
                    Name = "Baby Farm Coming Soon! 👶",
                    Description = "Placeholder for future auto-farm logic for baby mode needs.",
                    CurrentValue = false,
                    Flag = "BabyFarmToggle", 
                    Callback = function(Value)
                        if Value then
                            Rayfield:Notify({ Title = "Future Feature", Content = "Baby Farm logic is not yet implemented.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                        end
                    end,
                })

                PetsTab:CreateToggle({
                    Name = "Egg Farm Coming Soon! 🥚",
                    Description = "Placeholder for future egg hatching/collection automation.",
                    CurrentValue = false,
                    Flag = "EggFarmToggle", 
                    Callback = function(Value)
                        if Value then
                            Rayfield:Notify({ Title = "Future Feature", Content = "Egg Farm logic is not yet implemented.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                        end
                    end,
                })
                -- === END NEW "FARMING" TOGGLES ===


                PetsTab:CreateSection("Inventory Status (Live Update)")
                PotionsLabel = PetsTab:CreateLabel("Pet Age Potions: %s", PLACEHOLDER_ICON_ID)
                BucksXPAmountLabel = PetsTab:CreateLabel("Bucks XP Amount (Multiplier): %s", PLACEHOLDER_ICON_ID)
                BucksRawAmountLabel = PetsTab:CreateLabel("Bucks Amount (Cash): %s", PLACEHOLDER_ICON_ID)
                
                PetsTab:CreateButton({
                    Name = "Manual Refresh All Data",
                    Description = "Force a refresh of all pet, inventory, and Bucks data from the server. Use if automatic updates fail.",
                    Callback = function()
                        handleClientDataRefresh()
                        Rayfield:Notify({ Title = "Data Refreshed", Content = "Pet and Inventory data manually updated.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                    end
                })
            end
            
            -- [[ Others Tab: Holds Automation & Daily Tasks/Achievements ]]
            if OthersTab then
                
                -- --- PET AUTOMATION SECTION (PRIORITY) ---
                OthersTab:CreateSection("Pet Automation / Exploits (Targeted Age)")
                
                -- Pet Data Selector (Auto-Age Target)
                MassAgeTargetDropdown = OthersTab:CreateDropdown({
                    Name = "Pet Data Selector (Auto-Age Target)",
                    Description = "Choose the ONE pet that will be fed Age Potions repeatedly or used for equip/unequip buttons below. **Does NOT auto-equip.**",
                    Options = newOptions,
                    CurrentOption = {defaultSelection},
                    MultipleOptions = false, 
                    Flag = "MassAgeTargetDropdown",
                    Callback = function(options)
                        local selected = options[1]
                        currentMassAgeTargetName = selected
                        currentSelectedPetName = selected 
                        updatePetDetailsLabels()
                        -- NOTE: Intentionally NOT calling equipSelectedPet() here.                 
                    end
                })
                
                -- Explicit Equip Button (Utility)
                OthersTab:CreateButton({
                    Name = "Equip Selected Pet (Utility) 🎒",
                    Description = "Equips the pet selected above. Useful for checking the equipped status.",
                    Callback = function()
                        equipSelectedPet()
                    end
                })

                -- Explicit Unequip Button (Utility)
                OthersTab:CreateButton({
                    Name = "Unequip Selected Pet (Utility) 🚫",
                    Description = "Unequips the pet selected above.",
                    Callback = function()
                        unequipSelectedPet()
                    end
                })


                -- 1. Mass Age Pets Toggle (Normal Potion)
                local MassAgeToggle = OthersTab:CreateToggle({
                    Name = "Auto Give Age Potions (Normal)",
                    CurrentValue = false,
                    Flag = "MassAgeToggle", 
                    Description = "Continuously uses the Normal Age Potion (`pet_age_potion`) on the selected single pet. Ensure you have potions in your inventory.",
                    Callback = function(Value)
                        isMassAgingEnabled = Value
                        if isMassAgingEnabled then
                            
                            local petData = PetDataMap[currentMassAgeTargetName]
                            if not petData then
                                Rayfield:Notify({ Title = "Auto Aging Failed", Content = "Please select a pet for aging first.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
                                isMassAgingEnabled = false
                                MassAgeToggle:Set(false)
                                return
                            end
                            
                            task.spawn(function()
                                Rayfield:Notify({ Title = "Auto Aging Started", Content = string.format("Targeting pet: %s. Disable toggle to stop.", petData.id), Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                                
                                while isMassAgingEnabled do
                                    executeMassAge()
                                    task.wait(5) 
                                end
                            end)
                        else
                            Rayfield:Notify({ Title = "Auto Aging Stopped", Content = "Normal Age Potion loop has been halted.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                        end
                    end,
                })

                -- 2. Mass Age Pets Toggle (Tiny Potion)
                local MassTinyAgeToggle = OthersTab:CreateToggle({
                    Name = "Auto Give Tiny Age Potions",
                    CurrentValue = false,
                    Flag = "MassTinyAgeToggle", 
                    Description = "Continuously uses the Tiny Age Potion (`tiny_pet_age_potion`) on the selected single pet. Ensure you have potions in your inventory.",
                    Callback = function(Value)
                        isMassTinyAgingEnabled = Value
                        if isMassTinyAgingEnabled then
                            
                            local petData = PetDataMap[currentMassAgeTargetName]
                            if not petData then
                                Rayfield:Notify({ Title = "Tiny Aging Failed", Content = "Please select a pet for aging first.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
                                isMassTinyAgingEnabled = false
                                MassTinyAgeToggle:Set(false)
                                return
                            end
                            
                            task.spawn(function()
                                Rayfield:Notify({ Title = "Tiny Aging Started", Content = string.format("Targeting pet: %s. Disable toggle to stop.", petData.id), Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                                
                                while isMassTinyAgingEnabled do
                                    executeMassTinyAge()
                                    task.wait(5) 
                                end
                            end)
                        else
                            Rayfield:Notify({ Title = "Tiny Aging Stopped", Content = "Tiny Age Potion loop has been halted.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                        end
                    end,
                })
                
                
                -- 🔥 NEW: Auto Neon Fusion Toggle (4 Full Grown Pets)
                OthersTab:CreateSection("Pet Fusion Automation")
                
                local AutoNeonFusionToggle = OthersTab:CreateToggle({
                    Name = "Auto Neon Fusion (4 Full Grown Pets) ✨",
                    CurrentValue = false,
                    Flag = "AutoNeonFusionToggle", 
                    Description = "Automatically attempts to fuse 4 Full Grown (Age $\\ge 6$) pets of the same species into a Neon pet when the toggle is enabled.",
                    Callback = function(Value)
                        isAutoNeonEnabled = Value
                        if isAutoNeonEnabled then
                            task.spawn(function()
                                Rayfield:Notify({ Title = "Auto Neon Fusion Started", Content = "Scanning for 4 Full Grown pets of the same kind and starting fusion attempt...", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                                while isAutoNeonEnabled do
                                    executeNeonFusion()
                                    task.wait(5) -- Wait before next attempt
                                end
                            end)
                        else
                            Rayfield:Notify({ Title = "Auto Neon Fusion Stopped", Content = "The Auto Neon Fusion loop has been halted.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                        end
                    end
                }) 
                
                -- Mega Neon Fusion Toggle (Updated to use correct state name)
                local MegaNeonFusionToggle = OthersTab:CreateToggle({
                    Name = "Mega Neon Fusion Automation (4 Neon Pets) 🌈",
                    CurrentValue = false,
                    Flag = "MegaNeonFusionToggle", 
                    Description = "Automatically attempts to fuse 4 NEON pets of the same species into a MEGA NEON pet when the toggle is enabled.",
                    Callback = function(Value)
                        isMegaNeonEnabled = Value
                        if isMegaNeonEnabled then
                            task.spawn(function()
                                Rayfield:Notify({ Title = "Mega Neon Fusion Started", Content = "Scanning for 4 Neon pets of the same kind and starting fusion attempt...", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                                while isMegaNeonEnabled do
                                    executeMegaNeonFusion()
                                    task.wait(5) -- Wait before next attempt
                                end
                            end)
                        else
                            Rayfield:Notify({ Title = "Mega Neon Fusion Stopped", Content = "The Mega Neon Fusion loop has been halted.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                        end
                    end
                }) 
                
                
                -- --- DAILY TASK SECTION (SECONDARY) ---
                OthersTab:CreateSection("Daily Tasks / Achievements Status")
                
                DailyTaskTimerLabel = OthersTab:CreateLabel("Time until next achievement reset:\nN/A", PLACEHOLDER_ICON_ID)
                DailyTaskAchievementsLabel = OthersTab:CreateLabel("Active Achievements: Data Unavailable", PLACEHOLDER_ICON_ID)
                
                OthersTab:CreateButton({
                    Name = "Manual Refresh All Data",
                    Description = "Force a refresh of Daily Task/Achievement data from the server.",
                    Callback = function()
                        updateDailyTaskLabels(true)
                        Rayfield:Notify({ Title = "Data Refreshed", Content = "Daily Task data manually updated.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                    end
                })

            end
            
            -- [[ Events Tab: Holds the Christmas Timer and new Toggle/Button ]]
            if EventsTab then
                EventsTab:CreateSection("Utility Timers")

                local christmasString, _ = getTimeUntilChristmas()
                ChristmasTimerLabel = EventsTab:CreateLabel("Time Until Christmas:\n" .. christmasString, PLACEHOLDER_ICON_ID)
                
                startChristmasTimer()

                -- === NEW BLACK FRIDAY BUTTON (Teleport then Trade) ===
                EventsTab:CreateSection("Event Automation")
                
                EventsTab:CreateButton({
                    Name = "Claim Black Friday Sale Merchant 💸",
                    Description = "Teleports to the MainMap, then executes the script to trade up to 100 pet accessories/toys to the merchant to claim the sale reward.",
                    Callback = function()
                        if not blockIdToUse then
                            Rayfield:Notify({ Title = "Merchant Error", Content = "Could not find the Block ID for the merchant. Ensure you are in a game instance where the merchant exists.", Icon = PLACEHOLDER_ICON_ID, Duration = 5 })
                            return
                        end
                        -- Teleport and then execute the trade function as a callback
                        executeMainMapTeleport(executeMerchantTrade)
                    end
                })

                EventsTab:CreateToggle({
                    Name = "Christmas Event Coming Soon! 🎄",
                    Description = "Placeholder for future Christmas event automation logic.",
                    CurrentValue = false,
                    Flag = "ChristmasEventToggle", 
                    Callback = function(Value)
                        if Value then
                            Rayfield:Notify({ Title = "Future Feature", Content = "Christmas Event logic is not yet implemented.", Icon = PLACEHOLDER_ICON_ID, Duration = 3 })
                        end
                    end,
                })
                -- === END EVENT CONTROL ===
            end
            
            -- [[ Features Tab (Info) ]]
            if FeaturesTab then
                FeaturesTab:CreateSection("Release Notes")
                ReleaseNotesLabel = FeaturesTab:CreateLabel(
                    [[
**v1.7.0 (11/30/2025) Release Notes:**
* **NEW FEATURE**: Added **Claim Black Friday Sale Merchant** button under the Events tab.
* **Trade Logic**: Button executes a MainMap teleport followed by the automated inventory trade (max 100 pet accessories/toys).
* **NEW FEATURE**: Added **Auto Neon Fusion** toggle to the Others tab (Fuses 4 Full Grown pets into a Neon).
* **Admin Abuse**: Collider Search now includes Teleport to MainMap.
* **Pet Control**: Added Equip/Unequip buttons to Pets and Others tabs.
* **Auto Age**: Added Auto Give Normal and Tiny Potions to the Others tab.
* **Events**: Events tab is ready for Christmas (placeholder toggle added).
]],
                    PLACEHOLDER_ICON_ID
                )
            end
            
            -- Perform initial data load and UI update
            handleClientDataRefresh()
            updateDailyTaskLabels(true) 
            
            -- Log initialization time
            local INIT_END_TIME = tick()
            local elapsed = string.format("%.4f", INIT_END_TIME - INIT_START_TIME)
            print("[Script Loader] initializeClientDataModule finished loading core data and modules in " .. elapsed .. " seconds.")

        else
            warn("Could not initialize " .. DISPLAY_CLIENT_MODULE_NAME .. ". Script execution halted.")
        end
    end
end


-- // ================================================================= --
-- // 6. Rayfield UI Construction & Lifetime Management / Final Loops
-- // ================================================================= --

local Window = Rayfield:CreateWindow({
    Name = "Adopt Me Utility Script (Safe Name)",
    LoadingTitle = "Loading EventSploit", 
    LoadingSubtitle = "Loading EventSploit", 
    Icon = 16019271248, 
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil, 
        FileName = "AdoptMeUtility"
    },
    CloseCallback = function()
        if timerLoop and task.cancel then 
             pcall(task.cancel, timerLoop) 
        end
        if christmasTimerConnection then christmasTimerConnection:Disconnect() end 
        if ColliderSearchConnection then ColliderSearchConnection:Disconnect(); ColliderSearchConnection = nil end
    end,
})

-- Tab Creation in the desired order: Features, Pets/Equip, Others, Events, AdminAbuse
FeaturesTab = Window:CreateTab("Features") 
PetsTab = Window:CreateTab("Pets/Equip")
OthersTab = Window:CreateTab("Others") 
EventsTab = Window:CreateTab("Events") 
AdminAbuseTab = Window:CreateTab("AdminAbuse") 

-- FIX: Immediately create the content for the AdminAbuse tab after the tabs are defined.
createAdminAbuseUI()

task.spawn(function()
    initializeClientDataModule()
    
    -- Log total script load time, including Rayfield window creation
    local END_TIME = tick()
    local totalElapsed = string.format("%.4f", END_TIME - START_TIME)
    print("======================================================")
    print("[Script Loader] Total Script Execution and UI Load time: " .. totalElapsed .. " seconds.")
    print("======================================================")
end)


local lastDailyTaskUpdateTick = 0
RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    if currentTime - lastDailyTaskUpdateTick >= 60 then 
        updateDailyTaskLabels(false)
        lastDailyTaskUpdateTick = currentTime
    end
end)

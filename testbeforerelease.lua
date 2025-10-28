-- EVENTSPLOIT 1.2.9.2
--- --- GLOBAL DEBUG/LOGGING UTILITY ---
-- Set to 'true' if you ever need to debug the script in the console.
local DEBUG_ENABLED = false 
local function log(...) if DEBUG_ENABLED then print(...) end end
local function log_warn(...) if DEBUG_ENABLED then warn(...) end end

-- --- REMOTE DEHASHING SCRIPT (RUNS FIRST FOR PROPER REMOTE LOADING) ---
local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys", 999)).load 

local initFunction = Fsys("RouterClient").init

local printedOnce = false

local function inspectUpvalues()
    local remotes = {} 
    for i = 1, math.huge do
        local success, upvalue = pcall(getupvalue, initFunction, i)
        if not success then break end
        if typeof(upvalue) == "table" then
            for k, v in pairs(upvalue) do
                if typeof(v) == "Instance" then
                    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("BindableEvent") or v:IsA("BindableFunction") then
                        table.insert(remotes, {key = k, remote = v})
                        if not printedOnce then
                       
                        end
                    end
                end
            end
        end
    end
    return remotes
end

local function rename(remote, key)
    local nameParts = string.split(key, "/") 
    if #nameParts > 1 then
        local remotename = table.concat(nameParts, "/", 1, 2) 
        remote.Name = remotename
    else
        log_warn("Invalid key format for remote: " .. key) 
    end
end

local function renameExistingRemotes()
    local remotes = inspectUpvalues()
    for _, entry in ipairs(remotes) do
        rename(entry.remote, entry.key)
    end
end

local function displayDehashedMessage()
    local uiElement = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("HintApp") and 
                      game:GetService("Players").LocalPlayer.PlayerGui.HintApp:FindFirstChild("LargeTextLabel")

    if uiElement and uiElement:IsA("TextLabel") then
        uiElement.Text = "Remotes has been Dehashed!"
        uiElement.TextColor3 = Color3.fromRGB(0, 255, 0)
        task.wait(3)
        uiElement.Text = ""
        uiElement.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function monitorForNewRemotes()
    local remoteFolder = game.ReplicatedStorage:WaitForChild("API", 999)
    remoteFolder.ChildAdded:Connect(function(child)
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("BindableEvent") or child:IsA("BindableFunction") then
            log("New remote added: " .. child:GetFullName())
            local remotes = inspectUpvalues()
            for _, entry in ipairs(remotes) do
                rename(entry.remote, entry.key)
            end
        end
    end)
end

local function periodicCheck()
    while true do
        task.wait(10) 
        pcall(renameExistingRemotes)
    end
end

coroutine.wrap(periodicCheck)()
pcall(renameExistingRemotes)
pcall(displayDehashedMessage)
printedOnce = true
log("Script initialized and monitoring remotes.")
-- --- END OF REMOTE DEHASHING SCRIPT ---








--EVENTSPLOIT 1.2.9.0

-- 1. Require necessary Roblox Services and Modules for data retrieval
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientDataModule = require(ReplicatedStorage.ClientModules.Core.ClientData)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer 
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService") -- Added RunService for FPS pacing

-- Remote function references
local ToolAPI_ServerUseTool = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool")
local ToolAPI_Equip = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip") 
local ToolAPI_Unequip = ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip")
local PetObjectAPI_CreatePetObject = ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject")
local LootBoxAPI_ExchangeItemForReward = ReplicatedStorage:WaitForChild("API"):WaitForChild("LootBoxAPI/ExchangeItemForReward") 
local ShopAPI_IndicateOpenGift = ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/IndicateOpenGift")
local ShopAPI_OpenGift = ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/OpenGift")
local ShopAPI_BuyItem = ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem") 
local progressRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("HalloweenEventAPI/ProgressTaming")
local claimRemote = ReplicatedStorage:WaitForChild("API"):WaitForChild("HalloweenEventAPI/ClaimTreatBag")


-- Global maps (used for lookups by UI components)
local giftIdMap = {} 
local giftGenericNameMap = {} 
local genericGiftNames = {} 
local petDetailMap = {} 
local currentItemIdMap = {} 
local currentItemGenericNameMap = {} 

-- Utility state variables for the new looping toggles
local isHotbarManagerActive = false
local isSandmanActive = false
local isAutoOpenKindActive = false 
local isAntiAfkActive = false -- New AFK State
local LOADING_PLACEHOLDER = {"Loading Data..."}

-- Pet lookup table and utility functions
local PetNames = {
    starter_egg_2025_mouse = "2025 Mouse Pet",
    practice_dog = "Practice Dog",
    cat = "Cat",
    halloween_2025_spider = "Halloween 2025 Spider",
    basic_egg_2022_mouse = "Basic Egg 2022 Mouse",
}

-- Buyable items 
local allBuyableItems = {
    { id = "halloween_2025_spider_box", category = "gifts", defaultCount = 1, name = "Halloween Spider Box" },
    { id = "halloween_2025_sticker_pack", category = "gifts", defaultCount = 1, name = "Halloween Sticker Pack" },
    { id = "halloween_2025_haunted_piano", category = "gifts", defaultCount = 1, name = "Haunted Piano" },
    { id = "halloween_2025_haunted_cupboard", category = "gifts", defaultCount = 1, name = "Haunted cupboard" },
    { id = "halloween_2025_haunted_sofa_set", category = "gifts", defaultCount = 1, name = "Haunted Sofa Set" },
    { id = "halloween_2025_stalagmite", category = "gifts", defaultCount = 1, name = "halloween_2025_stalagmite" },
    { id = "halloween_2025_stalactite", category = "gifts", defaultCount = 1, name = "2025_stalactite" },

    { id = "halloween_2025_noob_voodoo_doll_chew_toy", category = "toys", defaultCount = 1, name = "Voodoo Doll" },
    { id = "halloween_2025_keyboard_skateboard", category = "transport", defaultCount = 1, name = "Keyobard SkateBoard" },
    { id = "halloween_2025_keyboard_leash", category = "toys", defaultCount = 1, name = "Keyobard Leash" },
    { id = "halloween_2025_noob_voodoo_doll_chew_toy", category = "toys", defaultCount = 1, name = "Keyobard SkateBoard" },
    { id = "halloween_2025_keyboard_leash", category = "accessories", defaultCount = 1, name = "Keyboard Leash" },
    { id = "halloween_2025_haunted_piano", category = "furniture", defaultCount = 1, name = "Haunted Piano" },


    { id = "halloween_2025_slimingo", category = "pets", defaultCount = 16, name = "Slimingo 2025 Halloween" },
    { id = "summerfest_2025_island_tarsier", category = "pets", defaultCount = 16, name = "Black Dog Cominng Soon!" },

}


local shopItemsDisplay = {}
local shopItemDetails = {}

for _, item in ipairs(allBuyableItems) do
    local displayString = string.format("%s (%s - %s)", item.name, item.category, item.id)
    table.insert(shopItemsDisplay, displayString)
    shopItemDetails[displayString] = item
end


-- USER-PROVIDED AGE CALCULATION LOGIC
local function calculateAge(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then
        return "N/A (Invalid Timestamp)"
    end
    
    local SECONDS_IN_MINUTE = 60
    local SECONDS_IN_HOUR = 3600
    local SECONDS_IN_DAY = 86400
    
    local currentTime = os.time()
    local ageSeconds = math.floor(currentTime - timestamp)

    if ageSeconds < 0 then return "N/A (Future Timestamp)" end

    local days = math.floor(ageSeconds / SECONDS_IN_DAY)
    local remainingSeconds = ageSeconds % SECONDS_IN_DAY
    
    local hours = math.floor(remainingSeconds / SECONDS_IN_HOUR)
    remainingSeconds = remainingSeconds % SECONDS_IN_HOUR
    
    local minutes = math.floor(remainingSeconds / SECONDS_IN_MINUTE)
    
    local ageString = ""
    if days > 0 then ageString = ageString .. days .. (days == 1 and " day" or " days") end
    
    if days == 0 or (days > 0 and days < 10) then
        if ageString ~= "" then ageString = ageString .. ", " end
        ageString = ageString .. hours .. (hours == 1 and " hr" or " hrs")
        if days == 0 or (days > 0 and days < 1) then -- Show minutes only for young pets
            ageString = ageString .. ", " .. minutes .. (minutes == 1 and " min" or " mins")
        end
    end
    
    return ageString
end
-- END USER-PROVIDED AGE CALCULATION LOGIC


-- *****************************************************************
-- *** CUSTOM FPS PACING LOGIC (CRITICAL FIX 30) ***
-- *****************************************************************
local currentTargetFPS = 60
local fpsPacingConnection = nil
local frameStart = os.clock()
local MAX_FPS_CAP = 240 -- Max value used by the slider

--- The core function that runs every frame to enforce the cap.
local function capFrameRate()
	-- The required time in seconds for a single frame at the currentTargetFPS.
    -- Use math.max to prevent division by zero or negative FPS (though clamped)
	local requiredTime = 1 / math.max(currentTargetFPS, 1) 

	-- The busy-wait loop: blocks the script until the required time for the frame has elapsed.
	while os.clock() - frameStart < requiredTime do
		-- Intentional busy-wait: consuming CPU cycles to enforce the time limit.
	end

	-- Mark the start of the next frame immediately before the current frame is rendered.
	frameStart = os.clock()
end

--- Sets the new target frame rate for the custom pacer.
local function setCustomFPSCap(newFPS)
    newFPS = math.floor(newFPS)
    -- Clamp the value to the slider's practical range (e.g., 30 FPS up to MAX_FPS_CAP)
    newFPS = math.clamp(newFPS, 30, MAX_FPS_CAP)

    currentTargetFPS = newFPS
    print("FPS Cap target updated to: " .. currentTargetFPS .. " FPS (Custom Pacer)")

    -- Ensure the cap is running (it should be started on load, but this is a safeguard)
    if not fpsPacingConnection then
        fpsPacingConnection = RunService.PreSimulation:Connect(capFrameRate)
    end
end
-- *****************************************************************
-- *** END CUSTOM FPS PACING LOGIC ***
-- *****************************************************************


-- *****************************************************************
-- *** NON-BLOCKING DATA FUNCTIONS (CRITICAL FIX FOR FREEZING) ***
-- *****************************************************************

-- Non-blocking wait for player data (for up to 5 seconds)
local function getPlayerData()
    local MAX_WAIT_TIME = 5 
    local startTime = tick()
    local playerName = Players.LocalPlayer.Name
    local data = ClientDataModule.get_data()
    
    while (not data or not data[playerName]) and (tick() - startTime < MAX_WAIT_TIME) do
        task.wait(0.1) 
        data = ClientDataModule.get_data()
    end

    return data and data[playerName]
end

-- Utility function to fetch inventory items (non-blocking)
local function getInventoryItems(category, playerData)
    local itemIdMap = {} 
    local itemGenericNameMap = {}
    local genericNameSet = {} 
    local TARGET_CATEGORY_PATH = playerData and playerData.inventory and playerData.inventory[category]
    local names = {}
    
    -- Clear globals ONLY if we are fetching 'gifts' to ensure fresh data
    if category == "gifts" then 
        giftIdMap = {}
        giftGenericNameMap = {}
    end

    if TARGET_CATEGORY_PATH and type(TARGET_CATEGORY_PATH) == "table" then
        for itemKey, itemData in pairs(TARGET_CATEGORY_PATH) do
            local uniqueInstanceId = tostring(itemKey)
            local readableName = itemData.kind or itemData.id or itemKey or "Unknown Item"
            local formattedString = string.format("%s | %s", readableName, uniqueInstanceId)
            table.insert(names, formattedString)
            
            itemIdMap[formattedString] = uniqueInstanceId
            itemGenericNameMap[formattedString] = readableName 

            if category == "gifts" then
                giftIdMap[formattedString] = uniqueInstanceId
                giftGenericNameMap[formattedString] = readableName
                
                if not genericNameSet[readableName] then
                    genericNameSet[readableName] = true
                end
            end
        end
    end
    
    if category == "gifts" then
        genericGiftNames = {} 
        for name, _ in pairs(genericNameSet) do
            table.insert(genericGiftNames, name)
        end
        -- Sort the gift names for cleaner display
        table.sort(genericGiftNames) 
    end

    if #names == 0 then
        return {"No Items Found in '" .. category .. "'"}, itemIdMap, itemGenericNameMap
    end
    
    return names, itemIdMap, itemGenericNameMap
end

-- Utility function to fetch pet data (non-blocking)
local function getPetData(playerData)
    local TARGET_CATEGORY_PATH = playerData and playerData.inventory and playerData.inventory.pets
    local dropdownValues = {}
    local petDetailMap_Local = {} 

    if TARGET_CATEGORY_PATH and type(TARGET_CATEGORY_PATH) == "table" then
        local playerPets = TARGET_CATEGORY_PATH

        for uniqueId, petData in pairs(playerPets) do
            local speciesId = petData.id or "unknown_id"
            local readableName = PetNames[speciesId] or string.gsub(speciesId, "_", " ")
            local petAge = "Age Data Not Found" 

            local rawAgeValue = petData.properties and petData.properties.age
            if type(rawAgeValue) == "number" and rawAgeValue >= 0 and rawAgeValue < 100000 then 
                petAge = "Stage: " .. tostring(rawAgeValue) 
            else
                local ageTimestamp = petData.created_timestamp or petData.birth_timestamp
                if type(ageTimestamp) == "number" and ageTimestamp > 0 then
                    petAge = calculateAge(ageTimestamp)
                end
            end
            
            local formattedString = string.format("%s | ID: %s | Age: %s", readableName, uniqueId, petAge)
            table.insert(dropdownValues, formattedString)
            
            local details = { UniqueId = uniqueId, SpeciesId = speciesId, Age = petAge }
            petDetailMap_Local[formattedString] = details
        end
    end

    if #dropdownValues == 0 then
        return {"No Pets Found"}, petDetailMap_Local
    end
    
    return dropdownValues, petDetailMap_Local
end

-- Utility function to fetch uniques (non-blocking)
local function getAllUniquesOfItemType(category, genericItemName, playerData)
    local uniqueIds = {}
    local TARGET_CATEGORY_PATH = playerData and playerData.inventory and playerData.inventory[category]

    if TARGET_CATEGORY_PATH and type(TARGET_CATEGORY_PATH) == "table" and type(genericItemName) == "string" then
        for itemKey, itemData in pairs(TARGET_CATEGORY_PATH) do
            local itemType = itemData.kind or itemData.id or ""
            if itemType == genericItemName then
                table.insert(uniqueIds, tostring(itemKey))
            end
        end
    end
    return uniqueIds
end

-- 2. Require the Fluent UI Library and Addons using loadstring
local Fluent = loadstring(game:HttpGet("https://github.com/1dontgiveaf/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/1dontgiveaf/Fluent/main/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/1dontgiveaf/Fluent/main/Addons/InterfaceManager.lua"))()

-- 3. Create the main Window
local Window = Fluent:CreateWindow({
    Title = "EventSploit | 1.2.9.4", 
    SubTitle = "Halloween & Utilities",
    Icon = 16019271248, 
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    ReleaseNotes = Window:AddTab({ Title = "Release Notes", Icon = "rbxassetid://16019271248" }),
    Main = Window:AddTab({ Title = "Main", Icon = "box" }), 
    Support = Window:AddTab({ Title = "Support", Icon = "wrench" }),
    Utilities = Window:AddTab({ Title = "Utilities", Icon = "wrench" }),
    Extra = Window:AddTab({ Title = "Extra", Icon = "wrench" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "calendar" }),
    Event = Window:AddTab({ Title = "Event", Icon = "calendar" }),
    PetManagement = Window:AddTab({ Title = "Pet Management", Icon = "rbxassetid://14433695350" }),
    PetPen = Window:AddTab({ Title = "PetPen", Icon = "rbxassetid://14433695350" }),
    Shop = Window:AddTab({ Title = "Shop", Icon = "rbxassetid://2567693356" }), 
    InteriorDebug = Window:AddTab({ Title = "InteriorDebug", Icon = "settings" }), 
    Teleport = Window:AddTab({ Title = "TeleportLocations", Icon = "settings" }), 
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
    
}

local Options = Fluent.Options
local petDropdown -- Forward declaration
local GiftsDropdown -- Forward declaration
local GiftKindDropdown -- Forward declaration
local InventoryItems -- Forward declaration

-- Utility function for character stats
local function getHumanoid()
    local character = Players.LocalPlayer.Character
    if not character or not character.Parent then
        character = Players.LocalPlayer.CharacterAdded:Wait()
    end
    return character and character:FindFirstChildOfClass("Humanoid")
end

-- --- Hotbar/Sandman AutoClicker Logic (integrated) ---
local CLICK_DELAY = 0.01 
local function clickButton(button)
    if not button or not button:IsA("GuiButton") then return end
    
    local function fireEvent(event)
        pcall(function()
            for _, connection in pairs(getconnections(event)) do
                connection:Fire() 
            end
        end)
    end
    
    fireEvent(button.MouseButton1Down)
    task.wait(CLICK_DELAY)
    fireEvent(button.MouseButton1Click)
    task.wait(CLICK_DELAY)
    fireEvent(button.MouseButton1Up)
end

local function clickAllHotbarItems()
    local hotbar = LocalPlayer.PlayerGui:FindFirstChild("MinigameHotbarApp")
        and LocalPlayer.PlayerGui.MinigameHotbarApp:FindFirstChild("Hotbar")

    if not hotbar then return end

    for _, container in ipairs(hotbar:GetChildren()) do
        local button = container:FindFirstChild("Button")
        
        if button and button:IsA("GuiButton") and button.Visible and button.Active then
            clickButton(button)
            task.wait(0.05) 
        end
    end
end

local function clickSandmanButton()
    local sandmanApp = LocalPlayer.PlayerGui:FindFirstChild("SandmanApp", true)
    
    if not sandmanApp then return end
    
    local sandmanButton = sandmanApp:FindFirstChild("Background", true)
    sandmanButton = sandmanButton and sandmanButton:FindFirstChild("Sleep", true)
    sandmanButton = sandmanButton and sandmanButton:FindFirstChild("Button")

    if sandmanButton and sandmanButton:IsA("GuiButton") then
        clickButton(sandmanButton)
    end
end

-- NEW: Anti-AFK logic
local function activateAntiAfk()
    local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
    local lastKeyPress = tick()
    
    while isAntiAfkActive do
        -- Only move if player hasn't moved recently to avoid spam
        if tick() - lastKeyPress > 10 then 
            local key = keys[math.random(1, #keys)]
            
            -- Simulate key press and release quickly
            VirtualInputManager:SendKeyEvent(true, key, false, LocalPlayer)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, key, false, LocalPlayer)

            print(string.format("Anti-AFK: Simulating movement with key %s", key.Name))
            lastKeyPress = tick()
        end
        task.wait(5) -- Wait between movement checks
    end
end
-- --- End AutoClicker Logic ---


-- 5. Main UI Initialization (FAST, non-blocking code)
task.spawn(function()
    
    -- 6. Release Notes Tab Content 
    Tabs.ReleaseNotes:AddParagraph({
        Title = "Latest Updates",
        Content = "## Release Notes 10/27/2025 v1.2.9.4\n\n- **Fix (Critical):** Applied a definitive fix by adding an explicit **Title** field to all internal Paragraph definitions to resolve the persistent `Paragraph - Missing Title` fatal error."
    })

  Tabs.ReleaseNotes:AddParagraph({
        Title = "Latest Updates",
        Content = "## Release Notes 10/27/2025 v1.2.9.4\n\n- **Fix (Critical):** Fixed the Fashion Frenzy clicking hopefully."
    })

      Tabs.ReleaseNotes:AddParagraph({
        Title = "Latest Updates",
        Content = "## Release Notes 10/27/2025 v1.2.9.4\n\n- **Fix (Critical):** Added a PetPenTab! with pet selection auto progression and pet adding and removal!"
    })





    -- 7. Main Tab Content (Speed/Jump Sliders)
    Tabs.Main:AddParagraph({
        Title = "Movement Controls",
        Content = "Customize your character's movement stats below."
    })
    
    local SpeedSlider = Tabs.Main:AddSlider("WalkSpeedSlider", {
        Title = "Velocity Control (Walk Speed)",
        Description = "Adjusts how fast your character moves (Default: 16).",
        Min = 16, Max = 100, Default = 16, Steps = 1, Rounding = 0, 
        Callback = function(Value)
            local humanoid = getHumanoid()
            if humanoid then humanoid.WalkSpeed = Value end
        end
    })

    local JumpSlider = Tabs.Main:AddSlider("JumpPowerSlider", {
        Title = "Airborne Thrusters (Jump Power)",
        Description = "Adjusts how high your character jumps (Default: 50).",
        Min = 50, Max = 150, Default = 50, Steps = 5, Rounding = 0, 
        Callback = function(Value)
            local humanoid = getHumanoid()
            if humanoid then humanoid.JumpPower = Value end
        end
    })

    Players.LocalPlayer.CharacterAdded:Connect(function(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Options.WalkSpeedSlider.Value
            humanoid.JumpPower = Options.JumpPowerSlider.Value
        end
    end)
    
    -- NEW: FPS Changer
    local fpsSlider = Tabs.Main:AddSlider("FPSCapSlider", {
        Title = "Frame Rate Cap (FPS)",
        Description = "Sets the client's target FPS cap using a custom frame pacer (Max 240).", -- Updated description
        Min = 30, Max = 240, Default = 60, Steps = 1, Rounding = 0,
        Callback = function(Value)
            -- CRITICAL FIX 30: Use the custom FPS cap logic
            local success, err = pcall(setCustomFPSCap, Value)
            if not success and err then
                warn("FPSCapSlider Error: Failed to set custom fps cap. Error: " .. tostring(err))
            end
        end
    })

    -- NEW: Anti-AFK Toggle
    local antiAfkToggle = Tabs.Main:AddToggle("AntiAfkToggle", {
        Title = "Simple Anti-AFK",
        Description = "Sends a small, periodic movement input to prevent being kicked for inactivity.",
        Default = false
    })

    antiAfkToggle:OnChanged(function(isEnabled)
        isAntiAfkActive = isEnabled
        if isEnabled then
            task.spawn(activateAntiAfk)
        else
            print("Anti-AFK: Disabled.")
        end
    end)


    -- 8. Pet Management Tab Content
    Tabs.PetManagement:AddParagraph({
        Title = "Pet Management",
        Content = "Select a pet to view its details and perform actions like equipping or unequipping."
    })

    petDropdown = Tabs.PetManagement:AddDropdown("PetsDropdown", {
        Title = "Select Pet",
        Description = "Lists all pets with their unique ID and age. Equips pet upon selection. Details printed to console.",
        Values = LOADING_PLACEHOLDER,
        Multi = false, Default = 1,
        Callback = function(Value)
            -- FIX: Check if the value is the placeholder before trying to look it up
            if Value == LOADING_PLACEHOLDER[1] then
                return 
            end
            
            local details = petDetailMap[Value]
            -- Pet details are now ONLY printed to the console
            print(string.format("Selected Pet Details:\n  Age: %s\n  Unique ID: %s\n  Species ID: %s", details.Age, details.UniqueId, details.SpeciesId))

            if not details or not details.UniqueId or details.UniqueId == "N/A (No Pets Found)" then 
                return 
            end
            
            local uniquePetID = details.UniqueId
            local equipOptions = { use_sound_delay = false, equip_as_last = false }
            local success, result = pcall(function() return ToolAPI_Equip:InvokeServer(uniquePetID, equipOptions) end)
            
            -- This log is used by the error analysis logic, so we keep it.
            print(string.format("Fired ToolAPI/Equip for Pet ID: %s", uniquePetID))
            
            if not success or not result then
                 -- Notify if the equip failed, even though it was fired
                 warn(string.format("ToolAPI/Equip failed for Pet ID: %s", uniquePetID))
            end
        end
    })
    
    Tabs.PetManagement:AddButton({
        Title = "Unequip Selected Pet",
        Description = "Invokes ToolAPI/Unequip for the currently selected pet.",
        Callback = function()
            local selectedPetString = Options.PetsDropdown.Value
            local details = petDetailMap[selectedPetString]
            
            if not details or not details.UniqueId or selectedPetString == LOADING_PLACEHOLDER[1] then
                Fluent:Notify({ Title = "Error", Content = "Please select a valid pet first.", Duration = 5 })
                return
            end

            local uniquePetID = details.UniqueId
            local args = { uniquePetID, { use_sound_delay = false, equip_as_last = false } }
            local success, result = pcall(function() return ToolAPI_Unequip:InvokeServer(unpack(args)) end)

            if success and result then
                Fluent:Notify({ Title = "Unequip Success", Content = string.format("Unequipped Pet ID: %s", uniquePetID), Duration = 3 })
            else
                Fluent:Notify({ Title = "Unequip Failed", Content = "Action failed. Check console for RMC error details.", Duration = 5 })
            end
        end
    })
    


    -- 9. Utilities Tab Content
    Tabs.Utilities:AddParagraph({
        Title = "Inventory Utilities",
        Content = "Select an inventory category to manage items."
    })
    
    local CategorySelector = Tabs.Utilities:AddDropdown("UtilityCategorySelector", {
        Title = "Select Inventory Category",
        Description = "Choose whether to list Gifts or Food items.",
        Values = {"gifts", "food"}, Multi = false, Default = "gifts",
    })

    InventoryItems = Tabs.Utilities:AddDropdown("UtilityInventoryItems", {
        Title = "Inventory Items",
        Description = "Items in the selected category. Equips item on selection.",
        Values = LOADING_PLACEHOLDER,
        Multi = false, Default = 1,
        Callback = function(Value)
            local uniqueItemID = currentItemIdMap[Value]

            if uniqueItemID and Value ~= LOADING_PLACEHOLDER[1] then
                local equipOptions = { use_sound_delay = false, equip_as_last = false }
                local success, result = pcall(function() return ToolAPI_Equip:InvokeServer(uniqueItemID, equipOptions) end)
                
                -- This log is used by the error analysis logic, so we keep it.
                print(string.format("Fired ToolAPI/Equip. Result: %s", tostring(success)))
            end
        end
    })

    -- Function to refresh the Utility/Gifts items
    local function refreshUtilityDropdown(category, playerData)
        -- NOTE: If category is 'gifts', this will also update the global gift maps again.
        local newItems, newItemIdMap, newItemGenericNameMap = getInventoryItems(category, playerData)
        currentItemIdMap = newItemIdMap
        currentItemGenericNameMap = newItemGenericNameMap
        InventoryItems:SetValues(newItems)
        InventoryItems:SetValue(newItems[1] or 1) 
        return newItems[1]
    end

    CategorySelector:OnChanged(function(newCategory)
        -- Data must be re-fetched asynchronously or use the cached data (if available)
        task.spawn(function()
            local playerData = getPlayerData() -- Get the latest player data
            if playerData then
                 refreshUtilityDropdown(newCategory, playerData)
            end
        end)
    end)


    local AgeFoodToggle = Tabs.Utilities:AddToggle("AgeFoodToggle", {
        Title = "Auto Age Pet with Selected Food (Pet & Food Required)",
        Description = "Consumes ALL unique instances of the selected food and applies them to the selected pet.",
        Default = false
    })

    AgeFoodToggle:OnChanged(function(isEnabled)
        if not isEnabled then return end
        
        local playerData = getPlayerData()
        if not playerData then Fluent:Notify({ Title = "Error", Content = "Player data not loaded yet.", Duration = 5 }); AgeFoodToggle:SetValue(false); return end

        local currentCategory = Options.UtilityCategorySelector.Value
        local selectedPetString = Options.PetsDropdown.Value 
        local petDetails = petDetailMap[selectedPetString] 
        local petUniqueId = petDetails and petDetails.UniqueId

        if not petUniqueId or currentCategory ~= "food" or Options.PetsDropdown.Value == LOADING_PLACEHOLDER[1] then
            Fluent:Notify({ Title = "Error", Content = "Auto Age requires a pet and category 'food'.", Duration = 5 })
            AgeFoodToggle:SetValue(false)
            return
        end

        local selectedFoodString = Options.UtilityInventoryItems.Value
        local genericFoodName = currentItemGenericNameMap[selectedFoodString]
        
        if not genericFoodName or selectedFoodString == LOADING_PLACEHOLDER[1] then
            Fluent:Notify({ Title = "Error", Content = "Could not identify the selected food item type.", Duration = 5 })
            AgeFoodToggle:SetValue(false)
            return
        end

        local potionUniques = getAllUniquesOfItemType(currentCategory, genericFoodName, playerData)
        if #potionUniques == 0 then
            Fluent:Notify({ Title = "Error", Content = string.format("No unique IDs found for item type: %s", genericFoodName), Duration = 5 })
            AgeFoodToggle:SetValue(false)
            return
        end

        local primaryUniqueId = table.remove(potionUniques, 1) 
        local additionalUniques = potionUniques 
        local potionCount = 1 + #additionalUniques 

        local args = {
            "__Enum_PetObjectCreatorType_2",
            { additional_consume_uniques = additionalUniques, pet_unique = petUniqueId, unique_id = primaryUniqueId }
        }

        local success, result = pcall(function() return PetObjectAPI_CreatePetObject:InvokeServer(unpack(args)) end)

        if success and result then
            Fluent:Notify({ Title = "Auto Age Success", Content = string.format("Applied %d items to pet: %s", potionCount, petUniqueId), Duration = 3 })
        else
            Fluent:Notify({ Title = "Auto Age Failed", Content = "Action failed. Check console for RMC error details.", Duration = 5 })
        end
        
        AgeFoodToggle:SetValue(false)
    end)


    -- 10. Event Tab Content (Gifts and Event Toggles)

    Tabs.Event:AddParagraph({
        Title = "Gift Control",
        Content = "Manage and automatically open event gifts from your inventory. Use 'by Kind' to open all instances of a specific gift."
    })
    
    GiftsDropdown = Tabs.Event:AddDropdown("GiftsDropdown", {
        Title = "Select Gift (by Unique ID)",
        Description = "Selects a single unique gift instance from inventory. Equips item on selection.",
        Values = LOADING_PLACEHOLDER, Multi = false, Default = 1,
        Callback = function(Value)
            local uniqueGiftID = giftIdMap[Value]
            if uniqueGiftID and Value ~= LOADING_PLACEHOLDER[1] then
                pcall(function() ToolAPI_Equip:InvokeServer(uniqueGiftID, {use_sound_delay = false, equip_as_last = false}) end)
                print(string.format("Fired ToolAPI/Equip for Gift ID: %s", uniqueGiftID))
            end
        end
    })

    GiftKindDropdown = Tabs.Event:AddDropdown("GiftKindDropdown", {
        Title = "Select Gift Type (by Kind)",
        Description = "Select the generic gift type to auto-open ALL its unique instances.",
        Values = LOADING_PLACEHOLDER, Multi = false, Default = 1,
    })

    local autoOpenKindToggle = Tabs.Event:AddToggle("AutoOpenAllByKind", {
        Title = "Auto Open ALL Gifts by Kind",
        Description = "Loops and opens all unique instances of the selected gift type (using ShopAPI/OpenGift).",
        Default = false
    })

    autoOpenKindToggle:OnChanged(function(isEnabled)
        isAutoOpenKindActive = isEnabled
        if isEnabled then
            task.spawn(function()
                local playerData = getPlayerData()
                if not playerData then Fluent:Notify({ Title = "Error", Content = "Player data not loaded yet.", Duration = 5 }); autoOpenKindToggle:SetValue(false); return end

                while isAutoOpenKindActive do
                    local genericGiftName = Options.GiftKindDropdown.Value
                    
                    if not genericGiftName or genericGiftName == LOADING_PLACEHOLDER[1] then
                        Fluent:Notify({ Title = "Error", Content = "Please select a valid gift type first.", Duration = 5 })
                        autoOpenKindToggle:SetValue(false)
                        break 
                    end
                    
                    -- NOTE: Need to fetch the list of uniques inside the loop to get updated counts
                    local uniqueGiftIDs = getAllUniquesOfItemType("gifts", genericGiftName, playerData) 
                    
                    if #uniqueGiftIDs == 0 then
                        Fluent:Notify({ Title = "Success", Content = string.format("Finished opening all gifts of type: %s", genericGiftName), Duration = 5 })
                        autoOpenKindToggle:SetValue(false)
                        break 
                    end

                    local giftID = table.remove(uniqueGiftIDs, 1) 

                    print(string.format("Attempting to open gift: %s (Type: %s)", giftID, genericGiftName))

                    pcall(function() ToolAPI_ServerUseTool:FireServer(giftID, "START") end)
                    pcall(function() ShopAPI_IndicateOpenGift:FireServer(giftID) end)
                    
                    local success, result = pcall(function() return ShopAPI_OpenGift:InvokeServer(giftID) end)
                    
                    if success and result and result ~= "failed" then
                        print(string.format("Successfully opened gift ID: %s", giftID))
                        Fluent:Notify({ Title = "Auto Open Status", Content = string.format("Opened one %s. %d remaining.", genericGiftName, #uniqueGiftIDs), Duration = 2 })
                    else
                        print(string.format("Failed to open gift ID: %s. Result: %s", giftID, tostring(result)))
                        Fluent:Notify({ Title = "Error", Content = string.format("Failed to open gift ID %s. Stopping loop.", giftID), Duration = 5 })
                        autoOpenKindToggle:SetValue(false)
                        break 
                    end

                    task.wait(0.5) 
                end
            end)
        else
            print("Auto Open ALL Gifts by Kind: Disabled.")
        end
    end)


    local giftToggle = Tabs.Event:AddToggle("AutoOpenGift", {
        Title = "Auto Open Selected Gift (By Unique ID)",
        Description = "Fires all RMC calls needed to automatically open the selected gift (uses LootBoxAPI).",
        Default = false
    })

    giftToggle:OnChanged(function(isEnabled)
        if isEnabled then
            local selectedString = Options.GiftsDropdown.Value
            local uniqueGiftID = giftIdMap[selectedString]
            
            -- FIX: Get the generic name from the global map using the full string
            local genericGiftName = giftGenericNameMap[selectedString] 

            if not uniqueGiftID or not genericGiftName or selectedString == LOADING_PLACEHOLDER[1] then 
                Fluent:Notify({ Title = "Error", Content = "Please select a valid gift first.", Duration = 5 })
                giftToggle:SetValue(false)
                return 
            end

            pcall(function() ToolAPI_ServerUseTool:FireServer(uniqueGiftID, "START") end)
            pcall(function() ToolAPI_ServerUseTool:FireServer(uniqueGiftID, "END") end)
            
            -- CRITICAL FIX: The LootBox API expects the generic kind/id, not the unique gift instance name.
            local lootboxArgs = { genericGiftName, uniqueGiftID } 
            local success, reward = pcall(function() return LootBoxAPI_ExchangeItemForReward:InvokeServer(unpack(lootboxArgs)) end)
            
            if success and reward and reward ~= "failed" then
                Fluent:Notify({ Title = "Gift Automation Complete", Content = "Opened gift successfully!", Duration = 3 })
            else
                -- The error message often includes "exchange_item kind does not match lootbox_reward_kind"
                Fluent:Notify({ Title = "Gift Automation Failed", Content = "Action failed. Check console for RMC error details (e.g., 'exchange_item kind does not match lootbox_reward_kind').", Duration = 8 })
            end
            
            task.wait(0.1) 
            giftToggle:SetValue(false)
        end
    end)
    
    -- *** This paragraph was missing a title, which was fixed earlier, but it is kept now ***
    Tabs.Event:AddParagraph({
        Title = "Event Toggles", -- This Title is present
        Content = "Toggles for various event-specific activities and exploits."
    })

    local hotbarManagerToggle = Tabs.Event:AddToggle("HotBarManagerToggle", {
        Title = "Hot Bar Manager (Auto-Click Items)",
        Description = "Loops through the hotbar and fires MouseButton events on all active items.",
        Default = false
    })

    hotbarManagerToggle:OnChanged(function(isEnabled)
        isHotbarManagerActive = isEnabled
        if isEnabled then
            task.spawn(function()
                while isHotbarManagerActive do
                    pcall(clickAllHotbarItems)
                    task.wait(1) 
                end
            end)
        else
            print("Hot Bar Manager: Disabled.")
        end
    end) 


    local sandmanAppToggle = Tabs.Event:AddToggle("AutoClickSandManApp", {
        Title = "AutoClick Sandman App",
        Description = "Continuously clicks the 'Sleep' button in the SandmanApp GUI.",
        Default = false
    })

    sandmanAppToggle:OnChanged(function(isEnabled)
        isSandmanActive = isEnabled
        if isEnabled then
            task.spawn(function()
                while isSandmanActive do
                    pcall(clickSandmanButton)
                    task.wait(2.5) 
                end
            end)
        else
            print("AutoClick Sandman App: Disabled.")
        end
    end)

    








-------------TOGGLES--------------



















--[[
    This script creates the Pet Selection UI components (Dropdown, Status, 
    Refresh, and Progression Button) inside your existing 'PetPen' tab.

    This file ASSUMES a 'Tabs' dictionary variable exists in the scope
    where this code is executed, and that 'Tabs.PetPen' is a valid 
    Fluent UI tab object.
]]

-- GAME SERVICES AND DATA MODULES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientDataModule = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Ensure the necessary tab object exists in the current scope.
-- *** CRITICAL UPDATE: Changed reference from Tabs.PetPenTab to Tabs.PetPen ***
-- This assumes the tab object is stored under the key 'PetPen' in the 'Tabs' table.
local PetPen = Tabs and Tabs.PetPen 

-- If 'Tabs' is not accessible or 'PetPen' isn't in it, we stop here.
if not PetPen or typeof(PetPen.AddDropdown) ~= "function" then
    warn("[PetSelectorUI Error] The 'Tabs' dictionary or 'Tabs.PetPen' tab object is missing from the current script scope.")
    warn("Make sure this code is placed *after* the line where the 'Tabs' dictionary is created and populated.")
    return
end

-- State management variables
-- This now holds the Unique ID (string) of the currently selected pet.
local currentSelectedPetId = nil 
local PetSelectorDropdown = nil
local StatusParagraph = nil 
local CommitToggle = nil -- New reference for the Toggle
local idMapping = {} -- Maps display string to Unique ID

-- Define the RemoteEvent paths
local ADD_PET_REMOTE = ReplicatedStorage:WaitForChild("API"):WaitForChild("IdleProgressionAPI/AddPet")
local REMOVE_PET_REMOTE = ReplicatedStorage:WaitForChild("API"):WaitForChild("IdleProgressionAPI/RemovePet")
-- NEW: Remote for committing progression
local COMMIT_REMOTE = ReplicatedStorage:WaitForChild("API"):WaitForChild("IdleProgressionAPI/CommitAllProgression")

-- Function to safely wait for client data to load
local function waitForData()
    local data = ClientDataModule.get_data()
    while not data do
        task.wait(0.5)
        data = ClientDataModule.get_data()
    end
    return data
end

-- Function to process pet data, build the dropdown list, and refresh the UI component
local function PopulateAndRefreshDropdown()
    -- Reset state and mappings
    currentSelectedPetId = nil -- Reset the selection
    local dropdownValues = {}
    idMapping = {}

    -- Display loading status (using SetContent for AddParagraph element)
    if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
        StatusParagraph:SetContent("Status: Refreshing pet list...")
    end

    -- 1. Fetch Data
    local serverData = waitForData()
    local localPlayer = Players.LocalPlayer
    local targetPlayerName = localPlayer and localPlayer.Name

    if not targetPlayerName then
        warn("LocalPlayer is not available! Cannot fetch pet data.")
    end

    local playerData = serverData and serverData[targetPlayerName]
    local petDataFound = false

    -- 2. Data Processing
    if playerData and playerData.inventory and playerData.inventory.pets then
        local playerPets = playerData.inventory.pets

        if next(playerPets) then
            petDataFound = true
            for uniqueId, petData in pairs(playerPets) do
                local speciesId = petData.id
                local petAge = "N/A"

                -- **Get Age from nested properties, falling back to top level**
                if petData.properties and petData.properties.age ~= nil then
                    petAge = petData.properties.age
                elseif petData.age ~= nil then
                    petAge = petData.age
                end

                -- *** CRITICAL CHANGE: Include the Unique ID in the display string ***
                -- New user-friendly display string: "[Species ID] - Age: [Age] (ID: Unique ID)"
                local displayString = string.format("[%s] - Age: %s (ID: %s)", speciesId, tostring(petAge), uniqueId)

                -- Add the display string to the list for the dropdown
                table.insert(dropdownValues, displayString)

                -- Map the display string to the actual uniqueId for later lookup
                idMapping[displayString] = uniqueId
            end
        end
    end

    -- 3. Ensure the dropdown values list has at least a placeholder if no pets are found
    if #dropdownValues == 0 then
        -- Add a placeholder if no pets are found or data is missing
        table.insert(dropdownValues, "No Pets Available/Data Error")
    end
    
    -- Delay for stability
    task.wait(0.1)

    -- 4. Update Dropdown
    if PetSelectorDropdown and typeof(PetSelectorDropdown.SetValues) == "function" then
        -- SetValues expects a simple list of strings, which is what dropdownValues is.
        PetSelectorDropdown:SetValues(dropdownValues)
    end

    -- 5. Update status paragraph
    local petCount = #dropdownValues
    if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
        if petDataFound then
            StatusParagraph:SetContent(string.format("Status: Loaded %d pets. Select one to proceed.", petCount))
        else
            StatusParagraph:SetContent("Status: Pet data refreshed. No pets found.")
        end
    end
end

-- **Function to add the SELECTED pet to progression**
local function AddSelectedPetToProgression()
    local uniqueId = currentSelectedPetId
    
    if uniqueId then
        if ADD_PET_REMOTE then
            print(string.format("ACTION: Firing AddPet RemoteEvent for single pet: %s", uniqueId))

            -- **Fire the remote with the single selected pet ID**
            ADD_PET_REMOTE:FireServer(uniqueId) 

            if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
                StatusParagraph:SetContent(string.format("Status: Attempting to add pet %s to progression...", uniqueId))
            end
        else
             print("ERROR: IdleProgressionAPI/AddPet RemoteEvent not found!")
             if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
                StatusParagraph:SetContent("Status: ERROR! Add Progression API not found.")
            end
        end
    else
        print("WARNING: No pet is currently selected.")
        if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
            StatusParagraph:SetContent("Status: WARNING! Please select a pet first.")
        end
    end
end

-- **Function to remove the SELECTED pet from progression**
local function RemoveSelectedPetFromProgression()
    local uniqueId = currentSelectedPetId
    
    if uniqueId then
        if REMOVE_PET_REMOTE then
            print(string.format("ACTION: Firing RemovePet RemoteEvent for single pet: %s", uniqueId))

            -- **Fire the remote with the single selected pet ID**
            REMOVE_PET_REMOTE:FireServer(uniqueId) 

            if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
                StatusParagraph:SetContent(string.format("Status: Attempting to remove pet %s from progression...", uniqueId))
            end
        else
             print("ERROR: IdleProgressionAPI/RemovePet RemoteEvent not found!")
             if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
                StatusParagraph:SetContent("Status: ERROR! Remove Progression API not found.")
            end
        end
    else
        print("WARNING: No pet is currently selected.")
        if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
            StatusParagraph:SetContent("Status: WARNING! Please select a pet first.")
        end
    end
end

-- **NEW: Loop function for committing progression in the background**
local function CommitProgressionLoop(isEnabled)
    if not COMMIT_REMOTE then
        warn("CommitAllProgression RemoteEvent not found!")
        if CommitToggle and typeof(CommitToggle.SetValue) == "function" then
            CommitToggle:SetValue(false) -- Disable toggle if remote is missing
        end
        return
    end

    if isEnabled then
        -- Start the loop in a new task thread
        task.spawn(function()
            local loopCanceled = false
            
            -- Keep looping as long as the toggle is enabled
            while CommitToggle.Value do
                -- Check if the remote is ready
                if COMMIT_REMOTE then
                    -- Fire the remote (no arguments needed for CommitAllProgression)
                    COMMIT_REMOTE:FireServer()
                    print("BACKGROUND: Fired IdleProgressionAPI/CommitAllProgression.")
                else
                    loopCanceled = true
                end

                -- Wait 5 seconds before firing again
                task.wait(5)

                if loopCanceled then break end
            end
            print("BACKGROUND: CommitAllProgression loop stopped.")
        end)
    else
        -- When the toggle is disabled, the 'while CommitToggle.Value' loop will exit.
        print("BACKGROUND: CommitAllProgression loop waiting to exit...")
    end
end


-- ===================================
-- UI CREATION
-- ===================================

-- 1. Create Dropdown (Restores functionality to store the selected ID)
PetSelectorDropdown = PetPen:AddDropdown("Pet_Selector", {
    Title = "Select Pet for Action", -- Updated Title
    Description = "Select a single pet's Unique ID to Add or Remove it.",
    Values = {}, 
    Multi = false, 
    Default = 1,
    
    -- Callback now stores the selected ID
    Callback = function(displayString)
        local uniqueId = idMapping[displayString]
        
        if uniqueId then
            currentSelectedPetId = uniqueId -- Store the ID
            print(string.format("Dropdown Selection: Selected Pet Unique ID: %s", uniqueId))
            if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
                StatusParagraph:SetContent(string.format("Selected: [%s]. Ready to process.", displayString))
            end
        else
            currentSelectedPetId = nil
            print("Info: Placeholder selected or pet data missing.")
            if StatusParagraph and typeof(StatusParagraph.SetContent) == "function" then
                StatusParagraph:SetContent("Status: Select a valid pet from the list.")
            end
        end
    end
})

-- 2. Add Status Paragraph (Correct, uses single options table with Title and Content)
StatusParagraph = PetPen:AddParagraph({
    Title = "Progression Status", 
    Content = "Status: Initializing..."
})

-- 3. Add Commit Progression Toggle (NEW ELEMENT)
CommitToggle = PetPen:AddToggle("AutoCommitProgression", {
    Title = "Auto Commit Progression (5s Loop)",
    Description = "Automatically calls CommitAllProgression every 5 seconds.",
    Default = false,
    Callback = CommitProgressionLoop -- Starts/Stops the background loop
})

-- 4. Add Refresh Button
PetPen:AddButton({
    Title = "Refresh Pet List",
    Description = "Reloads your pet inventory data.",
    Callback = PopulateAndRefreshDropdown
})

-- 5. Add Progression Button (Add Selected)
PetPen:AddButton({
    Title = "ADD SELECTED PET TO PROGRESSION",
    Description = "Sends the unique ID of the selected pet to the Idle Progression API.",
    Callback = AddSelectedPetToProgression -- Uses the single selected pet ID
})

-- 6. Add Removal Button (Remove Selected)
PetPen:AddButton({
    Title = "REMOVE SELECTED PET FROM PROGRESSION",
    Description = "Sends the unique ID of the selected pet to the Idle Progression API for removal.",
    Callback = RemoveSelectedPetFromProgression -- Uses the single selected pet ID
})

-- 7. Initial Data Load
PopulateAndRefreshDropdown()


































-- The provided Discord Webhook URL
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1424980657813065738/AXKHKuxccMtq7PuYC41s9huySco4YmUNEqDqubKZWlhRTsGbgu-4NnRTlTWprcnIQV80"
-- The user's website URL to send report data to
local WEBSITE_URL = "https://beamish-bienenstitch-178b02.netlify.app/"
-- The Discord invite link for the new button
local DISCORD_INVITE_LINK = "https://discord.gg/ARfAnTAf"

-- Get necessary Roblox services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Local variable to hold the text from the input field
local currentReportText = ""

-- IMPORTANT SECURITY CHECK: PostAsync will fail if HTTP is not enabled!
if not HttpService.HttpEnabled then
    warn("HttpService is NOT enabled! Please go to Game Settings -> Security and check 'Allow HTTP Requests'.")
end

---
-- @function SendReportData
-- @brief Sends the report data to both the Discord Webhook and the specified website URL.
---
local function SendReportData(playerName, reportText)
    
    -- Headers required for all JSON requests
    local headers = {
        ["Content-Type"] = "application/json"
    }

    -- 1. --- Discord Webhook Payload & Request ---
    local payloadDiscord = {
        content = string.format(":warning: **New Report Request** from **%s**.", playerName),
        username = "Roblox Report Bot",
        embeds = {
            {
                title = "Report Details",
                description = reportText, 
                fields = {
                    {name = "Player Name", value = playerName, inline = true},
                    {name = "Report Content Length", value = tostring(string.len(reportText)), inline = true},
                },
                color = 16711680 -- Red color (0xFF0000)
            }
        }
    }

    local dataToSendDiscord = HttpService:JSONEncode(payloadDiscord)
    
    print("Attempting to send report to Discord using custom 'request' function...")

    local successDiscord, responseDiscord = pcall(function()
        return request({
            Url = DISCORD_WEBHOOK_URL,
            Method = "POST",
            Headers = headers,
            Body = dataToSendDiscord
        })
    end)
    
    if successDiscord then
        print("Discord Webhook Status: SUCCESS. Response:", responseDiscord)
    else
        warn("Discord Webhook Status: FAILED. Error:", responseDiscord)
    end
    
    -- 2. --- Website Payload & Request ---
    -- We send a simplified payload for the custom website endpoint.
    local payloadWebsite = {
        player = playerName,
        report = reportText,
        timestamp = os.time() -- Send timestamp for better data tracking
    }
    
    local dataToSendWebsite = HttpService:JSONEncode(payloadWebsite)
    
    print("Attempting to send report to Website using custom 'request' function...")
    
    local successWebsite, responseWebsite = pcall(function()
        return request({
            Url = WEBSITE_URL,
            Method = "POST",
            Headers = headers,
            Body = dataToSendWebsite
        })
    end)
    
    if successWebsite then
        print("Website Endpoint Status: SUCCESS. Response:", responseWebsite)
        -- Clear text only after all sends have been attempted
        currentReportText = ""
    else
        warn("Website Endpoint Status: FAILED. Error:", responseWebsite)
    end
end

-- Assuming 'Tabs' and 'Main' are already defined and functional from the Fluent UI library

-- 1. Input Field (Stores the text)
local Input = Tabs.Support:AddInput("Report Request Input", {
    Title = "Enter Report Details",
    Description = "Type the details of the issue you want to report.",
    Default = "",
    Placeholder = "Describe the issue...",
    Numeric = false,
    Finished = false, -- Updates state immediately on every keypress
    
    Callback = function(Value)
        currentReportText = tostring(Value)
        print("Report text updated:", currentReportText)
    end
})

-- 2. Button (Confirms and sends the webhook)
Tabs.Support:AddButton({
    Title = "Send Report to Discord & Website",
    Description = "Confirms the report request and sends the message to both Discord and your custom website.",
    
    Callback = function()
        local localPlayer = Players.LocalPlayer
        local playerName = localPlayer and localPlayer.Name or "Unknown Player"
        
        -- Check if there is data to send
        if not currentReportText or string.len(currentReportText) == 0 then
            print("Report text is empty. Please enter details before sending.")
            return
        end

        print(string.format("Preparing to send report from %s with content: %s", playerName, currentReportText))
        
        -- Call the dedicated function to send the data to both endpoints
        SendReportData(playerName, currentReportText)
    end
})

-- 3. New Button (Copies Discord link)
Tabs.Support:AddButton({
    Title = "Join the Discord!",
    Description = "Click to copy the Discord invite link to your clipboard.",
    
    Callback = function()
        -- Fluent UI and custom environments often provide a global setclipboard function
        if setclipboard then
            setclipboard(DISCORD_INVITE_LINK)
            print("Discord link copied to clipboard: " .. DISCORD_INVITE_LINK)
        else
            warn("setclipboard() function is not available in this environment.")
        end
    end
})














Tabs.Event:AddButton({
    Title = "FarmWhereBear",
    Description = "you need 2 people max for it to work FarmWhereBear WIP",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/AdoptME-Halloween/refs/heads/main/WhereBear.lua')))()
        print("loading where bear logic!")
        loadstring(game:HttpGet((' https://raw.githubusercontent.com/AdoptmeEvent/AdoptME-Halloween/refs/heads/main/WhereBereLogic.lua')))()
        print("Teleporting, To MainMap!")
    end
})









--[[
    Title: Fluent UI Dynamic Data Monitor
    Description: Reads specific properties from Roblox Instances defined by string paths
    and displays them in single, continuously updated Fluent UI paragraphs in multiple tabs.
    
    V9: Refactored to support monitoring in multiple tabs (Main, PetManagement, Event)
    by creating three separate watch lists and update loops.
]]

-- ====================================================================
-- 1. DATA DEFINITION - Separate Watch Lists for Each Tab
-- ====================================================================

local MainWatchList = {

    { Path = 'Players.LocalPlayer.PlayerGui.FashionFrenzyInGameApp.Body.Right.Container.ValueLabel', Property = "Text", Title = "FashionFrenzyInGameScore" },
    { Path = 'Players.LocalPlayer.PlayerGui.FashionFrenzyInGameApp.Body.Left.Container.ValueLabel', Property = "Text", Title = "FashionFrenzyInGameTime" },
    { Path = 'Players.LocalPlayer.PlayerGui.HauntletInGameApp.Body.Right.Container.ValueLabel', Property = "Text", Title = "HauntletInGameScore" },
    { Path = 'Players.LocalPlayer.PlayerGui.HauntletInGameApp.Body.Left.Container.ValueLabel', Property = "Text", Title = "HauntletInGameTime" },
    { Path = 'Players.LocalPlayer.PlayerGui.MinigameInGameApp.Body.Left.Container.ValueLabel', Property = "Text", Title = "SleepyOrTreatInGameTime" },
    { Path = 'Players.LocalPlayer.PlayerGui.MinigameInGameApp.Body.Right.Container.ValueLabel', Property = "Text", Title = "SleepyOrTreatInGameScore" },
    { Path = 'Workspace.Interiors["MainMap!Fall"].HauntletMinigameJoinZone.Billboard.BillboardGui.TimerLabel', Property = "Text", Title = "Hauntlet Timer" },
    { Path = 'Workspace.Interiors["MainMap!Fall"].FashionFrenzyJoinZone.Billboard.BillboardGui.TimerLabel', Property = "Text", Title = "Fashion Frenzy Timer" },
    { Path = 'Workspace.Interiors["MainMap!Fall"].SleepOrTreatJoinZone.Billboard.BillboardGui.TimerLabel', Property = "Text", Title = "Sleep or Treat Timer" },
    { Path = 'Players.LocalPlayer.PlayerGui.BucksIndicatorApp.CurrencyIndicator.Container.Amount', Property = "Text", Title = "Bucks Amount (Main)" },
    { Path = 'Players.LocalPlayer.PlayerGui.AltCurrencyIndicatorApp.CurrencyIndicator.Container.Amount', Property = "Text", Title = "Alt Currency (Main)" },
    { Path = 'Players.LocalPlayer.PlayerGui.QuestIconApp.ImageButton.EventContainer.EventFrame.EventImageBottom.EventTime', Property = "Text", Title = "Quest Event Time" },
}

local PetManagementWatchList = {
    -- Duplicated Bucks Amount for PetManagement Tab
    { Path = 'Players.LocalPlayer.PlayerGui.BucksIndicatorApp.CurrencyIndicator.Container.Amount', Property = "Text", Title = "Bucks Amount" },
}

local EventWatchList = {
    -- Duplicated Alt Currency for Event Tab
    { Path = 'Players.LocalPlayer.PlayerGui.AltCurrencyIndicatorApp.CurrencyIndicator.Container.Amount', Property = "Text", Title = "Candy Currency" },
}

-- ====================================================================
-- 2. CORE UTILITY FUNCTIONS (Unchanged)
-- ====================================================================

--- Attempt to resolve a Roblox Instance path string to an actual Instance.
local function FindInstanceByPath(path)
    local cleanedPath = path:gsub('%["([^%]]+)%"]', '.%1'):gsub('%[([^%]]+)%]', '.%1')
    local CurrentInstance = nil
    local pathParts = {}
    
    for part in cleanedPath:gmatch("([^%.]+)") do
        table.insert(pathParts, part)
    end
    
    if #pathParts == 0 then return nil end
    
    local FirstPart = table.remove(pathParts, 1)

    if FirstPart == 'Workspace' then
        CurrentInstance = game.Workspace
    elseif FirstPart == 'Players' then
        local NextPart = table.remove(pathParts, 1)
        if NextPart == 'LocalPlayer' then
            CurrentInstance = game:GetService("Players").LocalPlayer
        else
            CurrentInstance = game:GetService("Players"):FindFirstChild(NextPart)
        end
    else
        CurrentInstance = game:FindFirstChild(FirstPart)
    end

    if not CurrentInstance then 
        return nil 
    end

    for _, part in ipairs(pathParts) do
        if part ~= "" then
            CurrentInstance = CurrentInstance:FindFirstChild(part)
            if not CurrentInstance then
                return nil
            end
        end
    end

    return CurrentInstance
end

--- Retrieves the specified property value from an Instance safely.
local function GetPropertyValue(Instance, Property)
    local Success, Value = pcall(function()
        return Instance[Property]
    end)

    if not Success then
        return "<ERROR: Property Access>"
    end

    return tostring(Value)
end

-- ====================================================================
-- 3. FLUENT UI MONITOR FACTORY
-- ====================================================================

--- Creates and manages a single, continuously updating paragraph for a specific tab.
--- @param tabName string The name of the tab (e.g., 'Visual', 'Event', 'PetManagement')
--- @param watchList table The list of data points for this tab.
local function StartDataMonitor(tabName, watchList)
    local ParagraphTitle = tabName .. " Currency Data Watcher"
    local DataParagraphReference = nil
    local TargetTab = Tabs[tabName]
    
    if not TargetTab then
        warn("Cannot start data monitor: Tab '" .. tabName .. "' does not exist in Tabs service.")
        return
    end

    -- Create the initial 'Initializing...' paragraph outside the loop
    DataParagraphReference = TargetTab:AddParagraph({
        Title = ParagraphTitle,
        Content = "Initializing..."
    })

    local function UpdateDataDisplay()
        local CurrentContent = {}
        for _, item in ipairs(watchList) do
            local Instance = FindInstanceByPath(item.Path)
            local Value = "NIL/MISSING"

            if Instance then
                Value = GetPropertyValue(Instance, item.Property)
            end

            table.insert(CurrentContent, string.format("%s: %s", item.Title, Value))
        end

        local newContent = table.concat(CurrentContent, "\n")

        -- CRITICAL FIX: Delete the old paragraph before creating the new one
        if DataParagraphReference then
            pcall(function()
                if DataParagraphReference.Remove then
                    DataParagraphReference:Remove()
                elseif DataParagraphReference.Destroy then
                    DataParagraphReference:Destroy()
                end
            end)
        end

        -- Create the NEW paragraph and capture the new reference for the next cycle
        DataParagraphReference = TargetTab:AddParagraph({
            Title = ParagraphTitle,
            Content = newContent
        })
    end

    -- Create a background loop to update the data constantly.
    local UpdateThread = coroutine.create(function()
        task.wait(1) 
        
        while true do 
            local Success, Error = pcall(UpdateDataDisplay) 
            if not Success then
                warn(ParagraphTitle .. " Update Failed (CRITICAL):", Error)
            end
            task.wait(0.5) -- Update every half-second
        end
    end)

    coroutine.resume(UpdateThread)
    print("Data Monitor for '" .. tabName .. "' started.")
end

-- ====================================================================
-- 4. EXECUTION
-- ====================================================================

-- Start monitors for the requested tabs
StartDataMonitor("Visual", MainWatchList)
StartDataMonitor("PetManagement", PetManagementWatchList)
StartDataMonitor("Event", EventWatchList)











-- This script provides the core logic to connect the Fluent Colorpicker 
-- to your existing UIStroke instance.
--
-- ASSUMPTION: The 'Tabs' object (part of the Fluent UI library) is already 
-- defined and initialized in your environment and accessible here.

local Players = game:GetService("Players")

-- Helper function to safely locate the specific UIStroke instance.
local function getTargetStroke()
    local Player = Players.LocalPlayer
    local PlayerGui = Player and Player:FindFirstChild("PlayerGui")
    
    -- The exact path to the UIStroke instance provided by you:
    local strokeInstance = PlayerGui
        and PlayerGui:FindFirstChild("Toggle_Button_GUI")
        and PlayerGui.Toggle_Button_GUI:FindFirstChild("VisibilityToggle")
        and PlayerGui.Toggle_Button_GUI.VisibilityToggle:FindFirstChild("UIStroke")
        
    return strokeInstance
end


-- Add the Colorpicker to the Main tab of the Fluent UI.
-- The first argument ("VisibilityToggleStrokeColor") is the unique internal name.
local StrokeColorPicker = Tabs.Main:AddColorpicker("VisibilityToggleStrokeColor", {
    Title = "Toggle Stroke Color",
    Description = "Control the outline color of the VisibilityToggle button.",
    Default = Color3.fromRGB(96, 205, 255), -- Initial default color
    
    -- This Callback function executes every time the user moves the color selector.
    Callback = function(color)
        local TargetStroke = getTargetStroke()
        
        if TargetStroke and TargetStroke:IsA("UIStroke") then
            -- *** This is the critical line: setting the UIStroke's Color property ***
            TargetStroke.Color = color
            
            -- Optionally log the change (can be removed in production)
            -- print("✅ UIStroke Color updated successfully to: " .. tostring(color))
        else
            warn("Target UIStroke not found at the expected path.")
        end
    end
})




 








Tabs.Teleport:AddButton({
    Title = "MainMap",
    Description = "TeleportingToMainMap",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/TeleportToMainMapManager.lua')))()
        print("Teleporting, To MainMap!")
    end
})



Tabs.Teleport:AddButton({
    Title = "Housing",
    Description = "TeleportingTohousing",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/TeleportToHousingManager.lua')))()
        print("Teleporting, To housing!")
    end
})





Tabs.Teleport:AddButton({
    Title = "PizzaShop",
    Description = "TeleportingToPizzaShop",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/PizzaShopManager.lua')))()
        print("Teleporting, To PizzaShop!")
    end
})


Tabs.Teleport:AddButton({
    Title = "School",
    Description = "TeleportingToSchool",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/SchoolManager.lua')))()
        print("Teleporting, To School!")
    end
})


Tabs.Teleport:AddButton({
    Title = "Salon",
    Description = "TeleportingToSalon",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/SalonManager.lua')))()
        print("Teleporting, To Salon!")
    end
})





Tabs.Teleport:AddButton({
    Title = "VIP",
    Description = "TeleportingToVIP",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/VIPManager.lua')))()
        print("Teleporting, To VIP!")
    end
})


Tabs.InteriorDebug:AddButton({
    Title = "HauntletInteriorDebug",
    Description = "TeleportingToHauntletInterior",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/HauntletInterior.lua')))()
         print("Teleporting, To HauntletInterior!")
    end
})


Tabs.InteriorDebug:AddButton({
    Title = "FashionFrenzyInteriorDebug",
    Description = "TeleportingToFashionFrenzyInterior",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/FashionFrenzyInterior.lua')))()
        print("Teleporting, To FashionFrenzyInterior!!")
    end
})



Tabs.InteriorDebug:AddButton({
    Title = "Sleep or Treat Interior",
    Description = "TeleportingToSleep orTreatInterior",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/SleepOrTreatInterior.lua')))()
        print("Teleporting, To School!")
    end
})



Tabs.InteriorDebug:AddButton({
    Title = "DebugInterior",
    Description = "TeleportingToDebugInterior",
    Callback = function()
        loadstring(game:HttpGet(('https://raw.githubusercontent.com/AdoptmeEvent/TeleportLocationsHandler/refs/heads/main/DebugInterior.lua')))()
        print("Teleporting, To Salon!")
    end
})



    


-- Initialize the global kill switch. This flag is what the external scripts 
-- are expected to check in their main loops to know when to stop.
_G.SOT_TELEPORTER_RUNNING = false 

Tabs.Event:AddToggle("SleepyOrTreatFarmToggle", {
    Title = "AutoFarmAll",
    Description = "Does all 3 minigame CandyTornado AutoLillyPads etc.",
    Default = false,
    Callback = function(isEnabled) 
        if isEnabled then
            -- 1. Set the global flag to TRUE to signal scripts to run
            _G.SOT_TELEPORTER_RUNNING = true
            print("[AutoFarmAll] Starting all 4 scripts...")
            
            -- 2. Wrap each loadstring in a 'spawn()' to execute them in separate threads

            spawn(function()
                print("[Scriptk 0] AutoClaimLillyPads started.")
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Adopt-Me-Event/AdoptMe-HalloweenEvent/refs/heads/main/AutoClaimLillyPadsInMainMap.lua"))()
            end)


            spawn(function()
                print("[Script 1]Candy Tornado started.")
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Adopt-Me-Event/AdoptMe-HalloweenEvent/refs/heads/main/CandyTornadoWeek4.lua"))() 
            end)


            spawn(function()
                print("[Script 2] SleepOrTreat started.")
                loadstring(game:HttpGet("github.com/Adopt-Me-Event/AdoptMe-HalloweenEvent/blob/main/SleepyOrTreatWeek3.lua"))() 
            end)



            spawn(function()
                print("[Scriptk 3] HauntletFarm started.")
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Adopt-Me-Event/AdoptMe-HalloweenEvent/refs/heads/main/HauntletFarmWeek1.lua"))()
            end)



            spawn(function()
                print("[Scriptk 4] Fashion Frenzy started.")
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Adopt-Me-Event/AdoptMe-HalloweenEvent/refs/heads/main/FashionFrenzyFixer.lua"))()
            end)




            spawn(function()
                print("[Scriptk 5] Fashion Fixer started.")
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Adopt-Me-Event/AdoptMe-HalloweenEvent/refs/heads/main/FashionFrenzyFixer.lua"))()
            end)

             spawn(function()
                print("[Scriptk 5] JoinZoneDetection Loaded!")
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Adopt-Me-Event/AdoptMe-HalloweenEvent/refs/heads/main/JoinZoneDetection.lua"))()
            end)



        else
            -- Set the global flag to FALSE to stop all running threads
            _G.SOT_TELEPORTER_RUNNING = false
            print("[AutoFarmAll] Global stop requested. All running threads should now cease.")
        end
    end
})








-- Initialize the global kill switch. This flag is what the external scripts 
-- are expected to check in their main loops to know when to stop.
_G.SOT_TELEPORTER_RUNNING = false 

Tabs.Event:AddToggle("SleepyOrTreatFarmToggle", {
    Title = "JoinZoneDetection",
    Description = "Starts Detection Of JoinZones.",
    Default = false,
    Callback = function(isEnabled) 
        if isEnabled then
            -- 1. Set the global flag to TRUE to signal scripts to run
            _G.SOT_TELEPORTER_RUNNING = true
            print("[AutoFarmAll] Starting all 4 scripts...")
            
            -- 2. Wrap each loadstring in a 'spawn()' to execute them in separate threads
            
           
            spawn(function()
                print("[Script 4] JoinZoneDetection started.")
                loadstring(game:HttpGet("https://raw.githubusercontent.com/AdoptmeEvent/AdoptME-Halloween/refs/heads/main/JoinZoneDetection"))()
            end)

        else
            -- Set the global flag to FALSE to stop all running threads
            _G.SOT_TELEPORTER_RUNNING = false
            print("[AutoFarmAll] Global stop requested. All running threads should now cease.")
        end
    end
})






-- This script assumes you have a variable 'Tabs' or a similar structure 
-- from your external UI framework where 'Tabs.ExtraTab' is accessible (corresponding to the "Extra Tab" UI element).

-- Define the RemoteFunction path once for efficiency
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RedemptionAPI = ReplicatedStorage:WaitForChild("API"):WaitForChild("CodeRedemptionAPI/AttemptRedeemCode")

-- Check if the API is found before proceeding
if not RedemptionAPI or not RedemptionAPI:IsA("RemoteFunction") then
    print("ERROR: Code Redemption API RemoteFunction not found! Check your API path.")
    return
end

-- --- UI Elements Setup ---

-- ADDED DEBUG: Check if Tabs.ExtraTab exists before attempting to add elements
-- Assuming the UI element "Extra Tab" is accessed via Tabs.ExtraTab
if not Tabs or not Tabs.Extra then
    print("DEBUG ERROR: The 'Tabs.ExtraTab' object is not found. The UI elements will not be created.")
    return -- Stop execution if the main UI object is missing
end
print("DEBUG: Tabs.ExtraTab object found. Proceeding to create UI elements.")

-- 1. Redemption Status Paragraph: This element will display the result/status to the user.
local RedemptionStatusParagraph = Tabs.Extra:AddParagraph({
    Title = "Redemption Status",
    -- Initial content guides the user.
    Content = "Ready to redeem code. Enter it in the box below and press Enter."
})
print("DEBUG: Redemption Status Paragraph created.")


-- Helper function to update the visual status in the paragraph element.
-- NOTE: You may need to adjust 'SetContent' based on your specific UI framework's API
-- (e.g., it might be :SetValue() or setting a .Content property directly).
local function updateStatus(message)
    -- Assuming the paragraph object has a method to update its content:
    -- Fluent UI components are generally objects returned by AddParagraph, etc.
    if RedemptionStatusParagraph and RedemptionStatusParagraph.SetContent then
        RedemptionStatusParagraph:SetContent(message)
    else
        -- Fallback print if the UI framework doesn't provide a visual update method
        print("UI Status Update (Fallback):", message)
    end
end

-- 2. Redemption Input Field: This is where the user types the code.
local Input = Tabs.Extra:AddInput("RedemptionCodeInput", {
    Title = "Code Input", -- Minimal title here
    Description = "", -- Removing the description as the paragraph now handles guidance/status
    Default = "", 
    Placeholder = "Example: 2xCOPPERKEY",
    Numeric = false, 
    Finished = true, -- CRITICAL: Only call the callback when the user presses ENTER
    
    Callback = function(CodeValue)
        -- The 'CodeValue' argument contains the text the user entered.
        
        -- Trim whitespace from the input value
        local TrimmedCode = string.sub(CodeValue, 1, string.len(CodeValue))

        if string.len(TrimmedCode) > 0 then
            -- Update status immediately to show the attempt is starting
            updateStatus("Attempting to redeem code: " .. TrimmedCode .. "...")
            
            -- Call the server
            local success, result = pcall(function()
                return RedemptionAPI:InvokeServer(TrimmedCode)
            end)

            if success then
                -- Check the result returned by the server
                if typeof(result) == "string" then
                    -- Server typically returns an error string (e.g., "Code expired") or a success message
                    updateStatus("Redemption Complete: " .. result)
                elseif typeof(result) == "boolean" and result == true then
                    updateStatus("Success! Code redeemed and rewards granted.")
                else
                    updateStatus("Code redeemed successfully! Server response type: " .. typeof(result))
                end
            else
                -- InvokeServer failed (network issue, server script error, etc.)
                updateStatus("ERROR: Redemption failed due to an internal issue. Details: " .. tostring(result))
                warn("Redemption InvokeServer failed! Error:", result) -- Keep a warn for debugging
            end
            
        else
            updateStatus("Input is empty. Please enter a valid code.")
        end
    end
})
print("DEBUG: Code Input Field created.")










--[[
    Fluent UI Toggle Logic for CatBat Taming Automation
    
    This script is designed to work with a custom exploit library where 'Tabs'
    is an available object containing the UI functions.
    
    FIX: The Remote Functions are now referenced using the user's specified
    lookup format: ReplicatedStorage.API["Full/Path/String"]. This should 
    resolve connection issues if the API exists.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. Reference the Remote Functions
-- Using the user's specified path structure (assuming ReplicatedStorage.API is a table 
-- that supports string-based lookups for the full path).
local ClaimTreatBagRF = ReplicatedStorage.API and ReplicatedStorage.API["HalloweenEventAPI/ClaimTreatBag"]
local ProgressTamingRF = ReplicatedStorage.API and ReplicatedStorage.API["HalloweenEventAPI/ProgressTaming"]

-----------------------------------------
-- TOGGLE 1: AUTO CLAIM TREAT BAG (ClaimTreatBagRF)
-----------------------------------------
if not ClaimTreatBagRF or not ClaimTreatBagRF:IsA("RemoteFunction") then
    -- CRITICAL: This warning confirms if the game's API is missing.
    warn("FATAL ERROR: RemoteFunction 'HalloweenEventAPI/ClaimTreatBag' not found, or is not a RemoteFunction. AutoClaimYarnApples cannot be activated.")
else
    local isYarnApplesActive = false
    local CLAIM_FIRE_INTERVAL = 1.5 -- Seconds

    Tabs.Event:AddToggle("AutoClaimYarnApples", {
        Title = "Auto Claim Yarn Apples (RMC)",
        Description = string.format("Safely fires ClaimTreatBag RMC in a loop every %.1f seconds.", CLAIM_FIRE_INTERVAL),
        Default = false,
        Callback = function(isEnabled)
            print(string.format("--> [TOGGLE 1] AutoClaimYarnApples: Toggled %s", tostring(isEnabled)))
            
            isYarnApplesActive = isEnabled
            
            if isEnabled then
                task.spawn(function()
                    while isYarnApplesActive do
                        local success, result = pcall(ClaimTreatBagRF.InvokeServer, ClaimTreatBagRF)

                        if success then
                            -- Assuming result could be a table of rewards or nil
                            if result and type(result) == "table" then
                                print(string.format("TREAT BAG CLAIMED! Rewards received: %s", table.concat(result, ", ")))
                            else
                                print("ClaimTreatBag returned nil/non-table. (On cooldown or no rewards)")
                            end
                        else
                            warn(string.format("ClaimTreatBag failed: %s", result))
                        end
                        
                        task.wait(CLAIM_FIRE_INTERVAL)
                    end
                    print("AutoClaimYarnApples loop stopped.")
                end)
            end
        end
    })
end

-----------------------------------------
-- TOGGLE 2: AUTO PROGRESS TAMING (ProgressTamingRF)
-----------------------------------------
if not ProgressTamingRF or not ProgressTamingRF:IsA("RemoteFunction") then
    -- CRITICAL: This warning confirms if the game's API is missing.
    warn("FATAL ERROR: RemoteFunction 'HalloweenEventAPI/ProgressTaming' not found, or is not a RemoteFunction. AutoProgressTaming cannot be activated.")
else
    local isTamingActive = false
    local IS_TAMING_SUCCESSFUL = true -- Always simulate a successful attempt
    local TAMING_FIRE_INTERVAL = 3 -- Seconds

    Tabs.Event:AddToggle("AutoProgressTaming", {
        Title = "Auto Progress Taming (RMC)",
        Description = string.format("Safely fires ProgressTaming RMC in a loop every %d seconds.", TAMING_FIRE_INTERVAL),
        Default = false,
        Callback = function(isEnabled)
            print(string.format("--> [TOGGLE 2] AutoProgressTaming: Toggled %s", tostring(isEnabled)))
            
            isTamingActive = isEnabled
            
            if isEnabled then
                task.spawn(function()
                    while isTamingActive do
                        -- ProgressTaming requires the success status as the only argument
                        local success, serverResult = pcall(ProgressTamingRF.InvokeServer, ProgressTamingRF, IS_TAMING_SUCCESSFUL)

                        if success then
                            if serverResult then
                                print(string.format("Taming COMPLETE! Cat Bat item ID received: %s", tostring(serverResult)))
                            else
                                print("ProgressTaming returned: nil (Progress updated)")
                            end
                        else
                            warn(string.format("ProgressTaming failed: %s", serverResult))
                        end
                        
                        task.wait(TAMING_FIRE_INTERVAL)
                    end
                    print("AutoProgressTaming loop stopped.")
                end)
            end
        end
    })
end












    -- 11. Shop Tab Content 
    
    Tabs.Shop:AddParagraph({
        Title = "Item Spawner (Shop API)", 
        Content = "Uses ShopAPI/BuyItem to purchase items. Item Category and ID are automatically parsed from the dropdown selection."
    })

    local shopDropdown = Tabs.Shop:AddDropdown("ShopItemDropdown", {
        Title = "Select Item to Buy",
        Description = "Select the item (by ID) you wish to purchase.",
        Values = shopItemsDisplay, Multi = false, Default = 1,
        Callback = function(Value)
            local item = shopItemDetails[Value]
            if item and item.defaultCount then
                local suggestedCount = math.min(item.defaultCount, 100)
                Options.ShopQuantitySlider:SetValue(suggestedCount)
            end
        end
    })

    local quantitySlider = Tabs.Shop:AddSlider("ShopQuantitySlider", {
        Title = "Quantity",
        Description = "How many of the item to purchase (Max 256).",
        Min = 1, Max = 256, Default = 1, Steps = 1, Rounding = 0,
    })

    Tabs.Shop:AddButton({
        Title = "Execute Purchase",
        Description = "Invokes ShopAPI/BuyItem with the correct category and buy_count object.",
        Callback = function()
            local selectedString = Options.ShopItemDropdown.Value
            local itemDetails = shopItemDetails[selectedString]
            local quantity = Options.ShopQuantitySlider.Value
            
            if not itemDetails then Fluent:Notify({ Title = "Error", Content = "Please select a valid item first.", Duration = 3 }); return end

            local itemId = itemDetails.id
            local itemCategory = itemDetails.category
            
            local success, result = pcall(function()
                return ShopAPI_BuyItem:InvokeServer( itemCategory, itemId, { buy_count = quantity } )
            end)
            
            if success and result and result ~= "failed" then
                Fluent:Notify({ Title = "Purchase Successful", Content = string.format("Bought %d x %s", quantity, itemDetails.name), Duration = 3 })
            else
                Fluent:Notify({ Title = "Purchase Failed", Content = "Purchase failed. Check console for details (e.g., currency, server validation).", Duration = 5 })
            end
        end
    })


    -- 12. Addons Setup (MUST be inside task.spawn block or it might break)
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    InterfaceManager:SetFolder("FluentScriptHub")
    SaveManager:SetFolder("FluentScriptHub/specific-game")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
    Window:SelectTab(1)
    
    -- Notify user the UI is ready, but data is loading
    Fluent:Notify({ Title = "EventSploit", Content = "UI is ready! Loading pet and inventory data in the background (may take a moment)...", Duration = 5 })
    
    -- CRITICAL FIX 26: Load saved settings in a pcall to handle potential errors from loading config for removed UI elements.
    local success, err = pcall(function() return SaveManager:LoadAutoloadConfig() end)
    if not success and err then
        warn("SaveManager Autoload Failed: " .. tostring(err) .. ". Proceeding with defaults.")
    end
    
    -- Initialize custom FPS cap with the saved value or default
    setCustomFPSCap(Options.FPSCapSlider.Value) 

end) -- End of main UI task.spawn block


-- *****************************************************************
-- *** ASYNCHRONOUS DATA LOADING AND POPULATION (Non-Blocking) ***
-- *****************************************************************
task.spawn(function()
    local playerData = getPlayerData()
    if not playerData then
        warn("Could not retrieve player data. Check if ClientDataModule.get_data() is ready.")
        return
    end

    -- --- 1. Load Pet Data ---
    local availablePets, petDetailMap_Loaded = getPetData(playerData) 
    petDetailMap = petDetailMap_Loaded
    
    -- Update Pet Dropdown
    if petDropdown and #availablePets > 0 then
        petDropdown:SetValues(availablePets)
        petDropdown:SetValue(availablePets[1] or 1)
    end
    -- If no pets found, ensure the display is updated
    if #availablePets == 0 and petDropdown then
        petDropdown:SetValues(availablePets)
        petDropdown:SetValue(availablePets[1] or 1)
    end


    -- --- 2. Load Inventory/Gift Data (FIXED TO RUN ONLY ONCE) ---
    local availableGifts_Loaded, giftItemIdMap_Loaded, giftItemGenericNameMap_Loaded = getInventoryItems("gifts", playerData)
    
    -- 2a. Update Utility Dropdown (Default is 'gifts')
    currentItemIdMap = giftItemIdMap_Loaded
    currentItemGenericNameMap = giftItemGenericNameMap_Loaded
    if InventoryItems and #availableGifts_Loaded > 0 then
        InventoryItems:SetValues(availableGifts_Loaded)
        InventoryItems:SetValue(availableGifts_Loaded[1] or 1) 
    end

    -- 2b. Update Event Unique ID Dropdown
    if GiftsDropdown and #availableGifts_Loaded > 0 then
        GiftsDropdown:SetValues(availableGifts_Loaded)
        GiftsDropdown:SetValue(availableGifts_Loaded[1] or 1)
    end
    
    -- 2c. Update Event Generic Kind Dropdown (Uses the genericGiftNames global populated by the single getInventoryItems call)
    if GiftKindDropdown and #genericGiftNames > 0 then
        GiftKindDropdown:SetValues(genericGiftNames)
        GiftKindDropdown:SetValue(genericGiftNames[1])
    else
        -- If no gifts are found, ensure placeholder is set
        if GiftKindDropdown then GiftKindDropdown:SetValues(LOADING_PLACEHOLDER) end
    end

    -- --- 3. ScreenGui Renaming Fix (Runs after all data is loaded and UI is stable) ---
    local targetName = "EventSploit_GUI"
    local CoreGui = game:GetService("CoreGui")
    local success = false
    
    -- Robustly wait for the Window.Container to exist and be parented
    local windowMainFrame = Window and Window.Container
    local attemptCount = 0
    while not windowMainFrame and attemptCount < 10 do
        task.wait(0.1)
        windowMainFrame = Window and Window.Container
        attemptCount = attemptCount + 1
    end
    
    if not windowMainFrame then
        warn("Window.Container is nil after data load attempts. Renaming skipped.")
        return
    end

    -- Loop through CoreGui to find the ancestor and rename it
    for i = 1, 10 do 
        for _, gui in pairs(CoreGui:GetChildren()) do
            -- CRITICAL FIX 29: Added check for windowMainFrame inside the loop to prevent nil value error
            if windowMainFrame and gui:IsA("ScreenGui") and gui:IsAncestorOf(windowMainFrame) then
                gui.Name = targetName
                print("Successfully renamed ScreenGui to: " .. targetName)
                success = true
                break
            end
        end
        
        if success then break end
        task.wait(0.1)
    end
    
    if not success then
        warn("Failed to rename the ScreenGui object in CoreGui after multiple attempts.")
    end
end)




--- END OF FLUENT UI LOAD SCRIPT!----



wait(1)

-- This LocalScript performs two primary tasks:
-- 1. Finds the specific "ScreenGui" and renames it to "EventSploit".
-- 2. Creates a separate, draggable circular button to toggle the visibility of the first 4 Frame children inside "EventSploit".

-- Get necessary services
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- === CONFIGURATION ===
local TARGET_NAME = "EventSploit"
local INITIAL_TARGET_NAME = "ScreenGui" -- The name the GUI currently has (based on your request)
local TOGGLE_IMAGE_ID = "rbxassetid://16019271248" -- Button icon asset ID

-- Variables for Drag/Click Detection
local isDragging = false
local dragStart = Vector2.new(0, 0)
local clickThreshold = 10 -- Minimum pixel distance required to register as a drag (prevents accidental clicks)
local hasMoved = false -- Flag to track if the input resulted in movement
-- =============================================

-- Task 1: Find and Rename the Target ScreenGui
local function renameScreenGui()
    local MAX_WAIT_TIME = 5 -- seconds
    local startTime = tick()
    local targetScreenGui = nil

    print("Renamer: Starting search for " .. INITIAL_TARGET_NAME .. " in CoreGui...")

    while tick() - startTime < MAX_WAIT_TIME and not targetScreenGui do
        -- Search directly for the ScreenGui by its initial name
        targetScreenGui = CoreGui:FindFirstChild(INITIAL_TARGET_NAME)

        if targetScreenGui and targetScreenGui:IsA("ScreenGui") then
            
            -- Rename it to TARGET_NAME if necessary
            if targetScreenGui.Name ~= TARGET_NAME then
                targetScreenGui.Name = TARGET_NAME
                print("Renamer: Successfully renamed target ScreenGui to: " .. TARGET_NAME)
            else
                print("Renamer: ScreenGui is already named: " .. TARGET_NAME)
            end
            break
        end
        -- Use legacy wait function for better compatibility
        wait(0.1) 
    end

    if not targetScreenGui then
        warn("Renamer: Failed to find and rename the ScreenGui object within the timeout. Looked for '" .. INITIAL_TARGET_NAME .. "' in CoreGui.")
    end
end

-- Function to find and return the first 4 top-level Frame descendants of a GUI
local function getFramesToToggle(gui)
    local frames = {}
    local count = 0
    for _, child in ipairs(gui:GetChildren()) do
        if child:IsA("Frame") then
            count = count + 1
            table.insert(frames, child)
            if count >= 4 then
                break
            end
        end
    end
    return frames
end


-- Task 2: Create a Draggable Toggle Button
local function createToggleButton()
    -- Wait for PlayerGui to ensure we can place the toggle button
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- 1. Setup the containing ScreenGui for the button
    local ButtonGui = Instance.new("ScreenGui")
    ButtonGui.Name = "Toggle_Button_GUI"
    ButtonGui.DisplayOrder = 999 
    ButtonGui.IgnoreGuiInset = true
    ButtonGui.Parent = PlayerGui

    -- 2. Create the circular ImageButton
    local ToggleButton = Instance.new("ImageButton")
    ToggleButton.Name = "VisibilityToggle"
    ToggleButton.Size = UDim2.new(0, 50, 0, 50) 
    -- FIX: Increased Y Offset from 80 to 160 to move it further down.
    -- Scale X: 0.5 (center)
    -- Offset X: -25 (half the button's width to truly center it)
    -- Scale Y: 0 (top edge)
    -- Offset Y: 160 (pushed significantly further down)
    ToggleButton.Position = UDim2.new(0.5, -25, 0, 160) 
    ToggleButton.BorderColor3 = Color3.new(0, 0, 0)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Active = true 
    ToggleButton.BackgroundTransparency = 0.2
    
    -- Aesthetic components
    Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(1, 0) 
    
    local outline = Instance.new("UIStroke")
    outline.Thickness = 3
    outline.Color = Color3.new(0, 0, 0) 
    outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outline.Parent = ToggleButton

    -- Set appearance
    ToggleButton.Image = TOGGLE_IMAGE_ID 
    
    -- Initial color (Grey until target is found or checked)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100) 
    ToggleButton.Parent = ButtonGui

    -- Set initial color based on target GUI's current state
    local targetGui = CoreGui:FindFirstChild(TARGET_NAME)
    if targetGui and targetGui:IsA("ScreenGui") then
        local frames = getFramesToToggle(targetGui)
        -- Check visibility of the first frame found to set initial color
        if #frames > 0 and frames[1].Visible then
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 50) -- Green (ON)
        else
            ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Red (OFF)
        end
    end


    -- === Dragging Logic (FIXED) ===
    local frameStart = Vector2.new(0, 0)

    ToggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            hasMoved = false 
            dragStart = input.Position
            -- Store the absolute position of the button when the drag starts
            frameStart = Vector2.new(ToggleButton.AbsolutePosition.X, ToggleButton.AbsolutePosition.Y)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            
            if delta.Magnitude > clickThreshold then
                hasMoved = true 
            end
            
            local screenW = game.Workspace.CurrentCamera.ViewportSize.X
            local screenH = game.Workspace.CurrentCamera.ViewportSize.Y
            
            local newX = frameStart.X + delta.X
            local newY = frameStart.Y + delta.Y
            
            -- Clamp position to stay within the screen bounds
            newX = math.clamp(newX, 0, screenW - ToggleButton.AbsoluteSize.X)
            newY = math.clamp(newY, 0, screenH - ToggleButton.AbsoluteSize.Y)
            
            -- Set the position directly using UDim2.fromOffset
            ToggleButton.Position = UDim2.fromOffset(newX, newY)
        end
    end)

    -- === Click/Toggle Logic (MODIFIED) ===
    ToggleButton.InputEnded:Connect(function(input)
        if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then 
            return 
        end
        
        isDragging = false

        -- Only execute the toggle if it was NOT a drag
        if not hasMoved then
            local targetGuiToToggle = CoreGui:FindFirstChild(TARGET_NAME)
            
            if targetGuiToToggle and targetGuiToToggle:IsA("ScreenGui") then
                
                local framesToToggle = getFramesToToggle(targetGuiToToggle)
                
                if #framesToToggle > 0 then
                    -- Base the new state on the FIRST frame's current visibility
                    local newVisibleState = not framesToToggle[1].Visible
                    
                    -- Toggle visibility for all collected frames (up to 4)
                    for _, frame in ipairs(framesToToggle) do
                        frame.Visible = newVisibleState
                        print("Toggling frame: " .. frame.Name .. " to " .. tostring(newVisibleState))
                    end
                    
                    -- Update the button's color
                    if newVisibleState then
                        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 50) -- Green when ON (Visible)
                        print(TARGET_NAME .. " children are now ON (Visible).")
                    else
                        ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Red when OFF (Hidden)
                        print(TARGET_NAME .. " children are now OFF (Hidden).")
                    end
                else
                    warn("Toggle: Could not find any Frame descendants in " .. TARGET_NAME .. " to toggle.")
                end
            else
                warn("Toggle: Could not find the ScreenGui named " .. TARGET_NAME .. " to toggle.")
                ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Dark gray if failed to find target
            end
        end
        
        hasMoved = false 
    end)
    
    print("Toggle Button: Created and ready to use.")
end

-- Execution Sequence:
-- 1. Run renaming in a new, non-blocking thread using the standard 'spawn'.
spawn(renameScreenGui)

-- 2. Create the button immediately.
createToggleButton()

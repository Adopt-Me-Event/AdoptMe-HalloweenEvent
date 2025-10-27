--[[
    CandyMagnet.lua (LocalScript)
    Place this script in StarterPlayerScripts.
    
    This script implements the candy magnet feature. It controls the movement 
    and collection of the CandyPickupable models.
    
    -- CHANGES APPLIED IN THIS VERSION --
    1. **CANDY NAME FIX:** Corrected the CANDY_NAME constant by removing extraneous tags. (Fixes silent failure to find items).
    2. **TELEPORT SPEED:** Increased MOVE_SPEED to 100 to make the movement look more like a teleport.
    3. **GUI FORCE ENABLED:** Now explicitly sets `AltCurrencyIndicatorApp.Enabled = true`.
    4. **LOCAL PLAYER TARGET:** Changed magnet logic to exclusively target the **local player's** character, not the nearest player.
    5. **NON-DESTRUCTIVE CLEANUP:** Retains the non-destructive freeze and 
       rename on collection (no destruction, no server events, no parenting).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CANDY_NAME = "CandyPickupable"
local GUI_PATH = "AltCurrencyIndicatorApp" -- Name of the GUI to look for
local PLAYER_CHARACTERS_CONTAINER = Workspace:FindFirstChild("PlayerCharacters")

-- Configuration
local MOVE_SPEED = 100 -- DOUBLED for a more "teleport-like" feel
local PICKUP_DISTANCE_SQUARED = 9 -- Distance^2 (3 studs) for pickup/event trigger
local MAGNET_RANGE_SQUARED = 10000 -- Max distance^2 (100 studs) for magnet effect. 
local LERP_SPEED_FACTOR = 0.1

-- Tracks models that have already been collected and handled
local CANDY_HANDLED = {} 

local localPlayer = Players.LocalPlayer
local magnetConnection = nil

print("CandyMagnet script starting...")

-- Wait for PlayerGui to be fully loaded
local playerGui = localPlayer:WaitForChild("PlayerGui")
print("PlayerGui found, starting monitoring loop...")


-- --- UTILITY FUNCTION: FIND NEAREST PLAYER ROOT ---
-- NOTE: This function is still defined but no longer used in gameLoop, 
-- as we are now targeting the LocalPlayer exclusively.

local function getNearestPlayerRoot(candyPosition)
    local closestRoot = nil
    local shortestDistanceSquared = MAGNET_RANGE_SQUARED
    
    -- Check if the PlayerCharacters container exists
    if not PLAYER_CHARACTERS_CONTAINER then return nil, shortestDistanceSquared end

    -- Iterate through the children in the Workspace.PlayerCharacters container
    for _, character in ipairs(PLAYER_CHARACTERS_CONTAINER:GetChildren()) do
        -- Ensure the child is a Model (a Character)
        if character:IsA("Model") then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            
            if rootPart and character:FindFirstChildOfClass("Humanoid") then
                local distanceSquared = (rootPart.Position - candyPosition).Magnitude^2
                
                if distanceSquared < shortestDistanceSquared then
                    shortestDistanceSquared = distanceSquared
                    closestRoot = rootPart
                end
            end
        end
    end
    
    return closestRoot, shortestDistanceSquared
end


-- --- GAMEPLAY LOGIC FUNCTIONS ---

-- Function to handle collection by freezing and renaming the model on the client.
local function collectCandy(candyModel)
    if CANDY_HANDLED[candyModel] then return end
    
    print(string.format("Model reached player. Freezing non-destructively: %s", candyModel.Name))

    local rootPart = candyModel:FindFirstChild("RootPart")
    
    if rootPart then
        -- Freeze the candy immediately on the client (stops movement)
        rootPart.Anchored = true 
        rootPart.CanCollide = false
    end
    
    CANDY_HANDLED[candyModel] = true
    
    -- CRITICAL: Change the name to prevent the original tracking script from seeing it.
    candyModel.Name = "CollectedCandy_FROZEN"
    print("Action: Model frozen at pickup and name changed. Not destroyed or moved.")
end

-- Function to handle the actual movement and collection check
local function moveCandy(candyModel, destinationRoot, deltaTime, distanceSquared)
    
    if CANDY_HANDLED[candyModel] then return end
    
    local rootPart = candyModel.PrimaryPart
    if not rootPart then
        rootPart = candyModel:FindFirstChild("RootPart")
        if not rootPart then return end
    end

    -- 1. Check for event trigger distance (FREEZE/RENAME)
    if distanceSquared <= PICKUP_DISTANCE_SQUARED then
        -- Candy is close enough, trigger client-side freeze/rename
        collectCandy(candyModel)
        return
    end
    
    -- 2. LOCAL MOVEMENT: Move the entire model using CFrame Lerp.
    local distance = math.sqrt(distanceSquared)
    
    -- Ensure physics are disabled just before movement
    rootPart.Anchored = false
    rootPart.CanCollide = false
    
    local moveAlpha = LERP_SPEED_FACTOR * MOVE_SPEED * (1 / math.max(1, distance / 5)) * deltaTime
    
    local newCFrame = rootPart.CFrame:Lerp(
        destinationRoot.CFrame, 
        moveAlpha
    )
    
    candyModel:SetPrimaryPartCFrame(newCFrame)

    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

-- MAIN GAME LOOP (Handles finding the closest candy and calling moveCandy)
local function gameLoop(deltaTime)
    
    -- Get the local player's character and root part for targeting
    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local localRoot = character:FindFirstChild("HumanoidRootPart")
    
    if not localRoot then return end -- Cannot target if local player has no root part

    -- PHASE 1: Find ALL unhandled candy within range and move them
    for _, item in ipairs(Workspace:GetChildren()) do 
        
        if item.Name == CANDY_NAME and item:IsA("Model") and not CANDY_HANDLED[item] then
            local rootPart = item:FindFirstChild("RootPart")
            
            if rootPart and rootPart:IsA("BasePart") then
                
                -- FORCE PrimaryPart assignment here to guarantee SetPrimaryPartCFrame works
                item.PrimaryPart = rootPart
                
                -- Calculate distance to the local player
                local distSq = (rootPart.Position - localRoot.Position).Magnitude^2
                
                if distSq <= MAGNET_RANGE_SQUARED then
                    
                    -- MOVE IT (moves the whole model towards the local player)
                    moveCandy(item, localRoot, deltaTime, distSq)
                end
            end
        end
    end
end

-- --- START/STOP LOGIC ---

local function startMagnetLoop()
    if not magnetConnection then
        print("Magnet enabled. Connecting to Heartbeat.")
        magnetConnection = RunService.Heartbeat:Connect(gameLoop)
    end
end

-- The stopMagnetLoop function is retained but currently unused in the permanent loop logic.
local function stopMagnetLoop()
    if magnetConnection then
        print("Magnet disabled. Disconnecting Heartbeat.")
        magnetConnection:Disconnect()
        magnetConnection = nil
    end
end

-- MAIN GUI MONITORING LOOP
while true do
    -- Find the GUI element
    local gui = playerGui:FindFirstChild(GUI_PATH)

    -- New logic: If the GUI exists, start the magnet and break the loop.
    if gui then
        print("GUI element found. Setting Enabled=true and permanently enabling magnet.")
        
        -- Force the GUI's Enabled property to true as requested
        gui.Enabled = true 
        
        startMagnetLoop()
        break -- Exit the loop as the magnet is now permanently running
    else
        -- Keep waiting for the GUI to appear
        task.wait(1) 
    end
end

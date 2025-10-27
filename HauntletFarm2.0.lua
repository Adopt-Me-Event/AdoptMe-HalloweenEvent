-- Configuration
-- The script will use the external global variable: _G.SOT_TELEPORTER_RUNNING
-- If the global variable is not set externally, we initialize it to true for immediate console execution.
_G.SOT_TELEPORTER_RUNNING = (_G.SOT_TELEPORTER_RUNNING ~= nil) and _G.SOT_TELEPORTER_RUNNING or true

local TELEPORT_DELAY = 0.3 -- Increased to 0.3s for slightly better physics stability
local SEARCH_INTERVAL = 3 -- Time in seconds to wait between search attempts
local MARKER_SIZE = Vector3.new(3, 3, 3)
local MARKER_COLOR = BrickColor.new("Really green") -- CHANGED: Marker color is now green
local TELEPORT_OFFSET_Y = 1 -- 1 stud above the ring for a smooth, sticky landing

-- Core Roblox services and objects
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local localPlayer = game.Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local currentTeleportIndex = 0

-- 1. Identify the search root as 'workspace.Interiors'
local interiorsRoot = game.Workspace:FindFirstChild("Interiors")

--------------------------------------------------------------------------------
-- 🔨 Utility Functions
--------------------------------------------------------------------------------

-- Function to safely get the physical part from a target object
local function getPhysicalPart(targetObject)
    if targetObject:IsA("BasePart") then
        return targetObject
    elseif targetObject:IsA("Model") then
        local primaryPart = targetObject.PrimaryPart
        if primaryPart and primaryPart:IsA("BasePart") then
            return primaryPart
        end
        for _, descendant in pairs(targetObject:GetDescendants()) do
            if descendant:IsA("BasePart") then
                return descendant
            end
        end
    end
    return nil
end

-- Helper to safely use task.wait() inside the loop
local function fastWait(duration)
    if RunService:IsRunning() then
        task.wait(duration)
    end
end

--------------------------------------------------------------------------------
-- 🚀 Core Execution Block
--------------------------------------------------------------------------------

local spawn_cframe = CFrame.new(-275.9091491699219, 25.812084197998047, -1548.145751953125, -0.9798217415809631, 0.0000227206928684609, 0.19986890256404877, -0.000003862579433189239, 1, -0.00013261348067317158, -0.19986890256404877, -0.00013070966815575957, -0.9798217415809631)

local InteriorsM = nil

-- Attempt to require necessary modules.
local successInteriorsM, errorMessageInteriorsM = pcall(function()
    local ClientModules = ReplicatedStorage:WaitForChild("ClientModules")
    local Core = ClientModules:WaitForChild("Core")
    local InteriorsMContainer = Core:WaitForChild("InteriorsM")
    InteriorsM = require(InteriorsMContainer.InteriorsM)
end)

if not successInteriorsM then
    warn("Failed to require InteriorsM:", errorMessageInteriorsM)
    -- Disable the script if core module is missing
    _G.SOT_TELEPORTER_RUNNING = false
    print("[Teleport] ERROR: Cannot load InteriorsM. Script halted.")
else
    print("[Teleport] InteriorsM module loaded successfully.")
end

---

local function initialTeleportSetup()
    if not InteriorsM then return end -- Don't run if module load failed
    if not _G.SOT_TELEPORTER_RUNNING then return end -- Check global kill switch

    print("[Teleport] Initial Teleporting to MainMap...")

    local destinationId = "MainMap"
    local doorIdForTeleport = "MainDoor" 

    local teleportSettings = {
        house_owner = localPlayer; 
        spawn_cframe = spawn_cframe; 
        anchor_char_immediately = true,
        post_character_anchored_wait = 0.5,
        move_camera = true,
    }

    local waitBeforeTeleport = 5 
    print(string.format("[Teleport] Waiting %d seconds for game stability before initial teleport...", waitBeforeTeleport))
    task.wait(waitBeforeTeleport) -- OPTIMIZED: Replaced wait() with task.wait()

    print("\n[Teleport] --- Initiating Direct Teleport to MainMap ---")
    InteriorsM.enter_smooth(destinationId, doorIdForTeleport, teleportSettings, nil)

    local postTeleportWait = 10 
    print(string.format("[Teleport] Teleporting to MainMap. Waiting %d seconds for map to load...", postTeleportWait))
    task.wait(postTeleportWait) -- OPTIMIZED: Replaced wait() with task.wait()
end

---

local function intermediateTeleportToRing()
    if not InteriorsM then return end
    if not _G.SOT_TELEPORTER_RUNNING then return end -- Check global kill switch

    local ringTarget = nil
    local interiorsFolder = game.Workspace:FindFirstChild("Interiors")

    if interiorsFolder then
        print("[Teleport] Starting persistent search for HauntletMinigameJoinZone...")

        local maxAttempts = 20
        local attempt = 0

        repeat
            if not _G.SOT_TELEPORTER_RUNNING then return end -- Check global kill switch
            attempt = attempt + 1
            print(string.format("[Teleport] Searching for Join Zone... (Attempt %d/%d)", attempt, maxAttempts))

            local minigameRingParent = interiorsFolder:FindFirstChild("MainMap!Fall", true)
            
            if minigameRingParent then
                -- Note: Using FindFirstChild(name, true) is better than GetDescendants() here for a specific path
                local joinZone = minigameRingParent:FindFirstChild("HauntletMinigameJoinZone", true)
                if joinZone then
                    ringTarget = joinZone:FindFirstChild("Ring", true)
                end
            end

            if not ringTarget then
                task.wait(1) -- OPTIMIZED: Replaced wait() with task.wait()
            end
        until ringTarget or attempt >= maxAttempts or not localPlayer.Parent

    end

    if ringTarget and ringTarget:IsA("BasePart") then
        print("[Teleport] Found Minigame Join Zone Ring. Teleporting in 5 seconds...")

        local countdownTime = 5
        for i = countdownTime, 1, -1 do
            if not _G.SOT_TELEPORTER_RUNNING then return end -- Check global kill switch
            print(string.format("[Teleport] Teleporting to Join Zone in... %d seconds", i))
            task.wait(1) -- OPTIMIZED: Replaced wait() with task.wait()
        end
        
        if not _G.SOT_TELEPORTER_RUNNING then return end -- Final check

        print("[Teleport] Teleporting to Minigame Join Zone Ring NOW...")
        
        rootPart.Anchored = true
        rootPart.CFrame = ringTarget.CFrame * CFrame.new(0, TELEPORT_OFFSET_Y, 0)
        rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        task.wait(TELEPORT_DELAY) -- OPTIMIZED: Replaced wait() with task.wait()
        rootPart.Anchored = false
        
        print("[Teleport] Teleport to Join Zone complete. Starting continuous search.")
        task.wait(1) -- OPTIMIZED: Replaced wait() with task.wait()
    else
        warn("[Teleport] Failed to find Minigame Join Zone Ring.")
        print("[Teleport] Join Zone not found. Starting persistent door search directly.")
        task.wait(2) -- OPTIMIZED: Replaced wait() with task.wait()
    end
end

-- Initial setup only runs if the script is currently enabled
if _G.SOT_TELEPORTER_RUNNING then
    initialTeleportSetup()
    intermediateTeleportToRing()
end

-- **OPTIMIZATION:** The entire loop is now spawned into a separate thread.
-- This prevents the slow GetDescendants() search from freezing the main game/physics thread.
task.spawn(function()
    -- MAIN CONTINUOUS LOOP
    while true do
        -- **CRITICAL CHECK**: Only proceed if the global kill switch is true
        while not _G.SOT_TELEPORTER_RUNNING do
            print("[Teleport] Teleport System is OFF. Awaiting activation...")
            task.wait(1) -- OPTIMIZED: Replaced wait() with task.wait()
        end
        
        -- Check if the primary container exists
        if not interiorsRoot then
            print("[Teleport] Error: Could not find 'Interiors' folder.")
            _G.SOT_TELEPORTER_RUNNING = false
            print("[Teleport] ERROR: Missing 'Interiors' folder. Script halted.")
            break
        end

        local teleportTargets = {}
        local roomModels = {}
        
        -- 2. Persistent Search Loop for Room Models
        while #roomModels == 0 do
            if not _G.SOT_TELEPORTER_RUNNING then break end -- Check global kill switch
            print("[Teleport] Searching for Hauntlet Minigame...")
            
            roomModels = {}
            
            for _, object in pairs(interiorsRoot:GetChildren()) do
                if string.match(object.Name, "^HauntletInterior::") and object:IsA("Model") then
                    table.insert(roomModels, object)
                end
            end
            
            if #roomModels == 0 then
                task.wait(SEARCH_INTERVAL) -- OPTIMIZED: Replaced wait() with task.wait()
            end
        end
        
        if not _G.SOT_TELEPORTER_RUNNING then continue end -- Restart loop if turned off during search

        print(string.format("[Teleport] Found %d HauntletInterior Room Models. Starting target scan.", #roomModels))

        -- Now, search within these models for the actual teleport rings
        -- Note: This GetDescendants() call is what causes the most lag. Running it
        -- inside a task.spawned thread minimizes the impact on framerate.
        for _, roomModel in ipairs(roomModels) do
            if not _G.SOT_TELEPORTER_RUNNING then break end -- Check global kill switch
            for _, object in pairs(roomModel:GetDescendants()) do
                if not _G.SOT_TELEPORTER_RUNNING then break end -- Check global kill switch
                if string.match(string.lower(object.Name), "teleport") and (object:IsA("BasePart") or object:IsA("Model")) then
                    local physicalPart = getPhysicalPart(object)
                    if physicalPart then
                        table.insert(teleportTargets, {
                            part = physicalPart,
                            roomModel = roomModel
                        })
                    end
                end
            end
        end
        
        if not _G.SOT_TELEPORTER_RUNNING then continue end -- Restart loop if turned off during target scan

        local totalTargets = #teleportTargets
        print(string.format("[Teleport] Found %d total teleport targets. Starting sequence...", totalTargets))

        -- 3. Teleport to each target and update console
        if totalTargets > 0 then
            for i, targetData in ipairs(teleportTargets) do
                if not _G.SOT_TELEPORTER_RUNNING then break end -- Check global kill switch
                
                local ring = targetData.part
                local roomModel = targetData.roomModel
                currentTeleportIndex = i
                
                local doorHitName = ring.Name
                local roomName = string.match(roomModel.Name, "^(HauntletInterior::[^:]+)") or "Unknown Room"

                local statusText = string.format("Teleporting: %d/%d | DoorHit: %s | Room: %s", 
                    currentTeleportIndex, totalTargets, doorHitName, roomName)
                print("[Teleport] " .. statusText)

                -- Create and position the marker cube
                -- This is a small source of overhead, but is kept for functionality.
                local marker = Instance.new("Part")
                marker.Name = "TeleportMarker_" .. i
                marker.Size = MARKER_SIZE
                marker.CFrame = ring.CFrame
                marker.Anchored = true
                marker.CanCollide = false
                marker.BrickColor = MARKER_COLOR
                marker.Material = Enum.Material.Neon
                marker.Transparency = 0.2
                marker.Parent = game.Workspace

                -- Perform Teleportation (Physical change happens on the main thread)
                rootPart.Anchored = true
                rootPart.CFrame = ring.CFrame * CFrame.new(0, TELEPORT_OFFSET_Y, 0)
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                task.wait(TELEPORT_DELAY) -- OPTIMIZED: Replaced wait() with task.wait()
                rootPart.Anchored = false

                marker:Destroy()
            end
            
            if _G.SOT_TELEPORTER_RUNNING then -- Only print status and wait if the script is still ON
                print(string.format("[Teleport] Teleport sequence complete! Hit all %d targets. Restarting search...", totalTargets))
                task.wait(SEARCH_INTERVAL) -- OPTIMIZED: Replaced wait() with task.wait()
            end
        else
            if _G.SOT_TELEPORTER_RUNNING then
                print("[Teleport] Error: Found 0 teleport targets. Restarting search...")
                task.wait(SEARCH_INTERVAL) -- OPTIMIZED: Replaced wait() with task.wait()
            end
        end
    end
end)

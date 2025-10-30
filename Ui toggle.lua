-- This LocalScript performs two primary tasks:
-- 1. Finds the specific "ScreenGui" and renames it to "EventSploit".
-- 2. Creates a separate, draggable circular button to toggle the visibility of the first 4 Frame children inside "EventSploit".

-- Get necessary services (using :GetService is the robust way)
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- === CONFIGURATION ===
local TARGET_NAME = "EventSploit"
local INITIAL_TARGET_NAME = "ScreenGui" -- The name the GUI currently has
local TOGGLE_IMAGE_ID = "rbxassetid://16019271248" -- Button icon asset ID (Ensure this ID is valid/yours)

-- Global variable to hold the reference to the target ScreenGui after it is found and renamed.
local targetGui = nil 

-- Variables for Drag/Click Detection
local isDragging = false
local dragStart = Vector2.new(0, 0)
local clickThreshold = 10 -- Minimum pixel distance required to register as a drag
local hasMoved = false -- Flag to track if the input resulted in movement
-- =============================================

-- Task 1: Find and Rename the Target ScreenGui
local function renameScreenGui()
    local MAX_WAIT_TIME = 5 -- seconds
    local startTime = tick()
    local foundGui = nil

    print("Renamer: Starting search for " .. INITIAL_TARGET_NAME .. " in CoreGui...")

    while tick() - startTime < MAX_WAIT_TIME and not foundGui do
        -- Search directly for the ScreenGui by its initial name
        foundGui = CoreGui:FindFirstChild(INITIAL_TARGET_NAME)

        if foundGui and foundGui:IsA("ScreenGui") then
            
            -- Rename it to TARGET_NAME if necessary
            if foundGui.Name ~= TARGET_NAME then
                foundGui.Name = TARGET_NAME
                print("Renamer: Successfully renamed target ScreenGui to: " .. TARGET_NAME)
            else
                print("Renamer: ScreenGui is already named: " .. TARGET_NAME)
            end
            return foundGui -- Return the found GUI
        end
        -- FIX: Replaced deprecated 'wait' with modern 'task.wait'
        task.wait(0.1) 
    end

    if not foundGui then
        warn("Renamer: Failed to find and rename the ScreenGui object within the timeout. Looked for '" .. INITIAL_TARGET_NAME .. "' in CoreGui.")
    end
    return nil
end

-- Function to find and return the first 4 top-level Frame descendants of a GUI
local function getFramesToToggle(gui)
    local frames = {}
    local count = 0
    -- Use pairs/ipairs on the results of GetChildren()
    for _, child in gui:GetChildren() do 
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
    -- Position: centered on X, pushed down on Y (adjusted for screen safe area)
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

    -- Set initial color based on target GUI's current state (using the global targetGui variable)
    if targetGui and targetGui:IsA("ScreenGui") then
        local frames = getFramesToToggle(targetGui)
        -- Check visibility of the first frame found to set initial color
        if #frames > 0 and frames[1].Visible then
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 50) -- Green (ON)
        else
            ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Red (OFF)
        end
    end


    -- === Dragging Logic ===
    local frameStart = Vector2.new(0, 0)

    -- InputBegan: Start the drag process
    ToggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            hasMoved = false 
            dragStart = input.Position
            -- Store the button's absolute position when the drag starts
            frameStart = Vector2.new(ToggleButton.AbsolutePosition.X, ToggleButton.AbsolutePosition.Y)
        end
    end)

    -- InputChanged: Move the button while dragging
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            
            -- Check if movement exceeds the click threshold
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

    -- InputEnded: End drag and perform toggle if it was a click
    ToggleButton.InputEnded:Connect(function(input)
        -- Only process mouse/touch inputs
        if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then 
            return 
        end
        
        isDragging = false

        -- Only execute the toggle if it was NOT a drag (i.e., it was a quick click)
        if not hasMoved then
            -- Use the globally stored reference
            local targetGuiToToggle = targetGui 
            
            if targetGuiToToggle and targetGuiToToggle:IsA("ScreenGui") then
                
                local framesToToggle = getFramesToToggle(targetGuiToToggle)
                
                if #framesToToggle > 0 then
                    -- Base the new state on the FIRST frame's current visibility
                    local newVisibleState = not framesToToggle[1].Visible
                    
                    -- Toggle visibility for all collected frames (up to 4)
                    for _, frame in framesToToggle do
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
-- 1. Run renaming in a new, non-blocking thread and store the result.
-- We use a connection here to wait for the rename to finish before setting the global variable.
task.spawn(function()
    targetGui = renameScreenGui()
end)

-- 2. Create the button immediately.
createToggleButton()

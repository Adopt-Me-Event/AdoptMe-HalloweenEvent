-- Configuration
local TELEPORT_DELAY = 0.15 -- Time in seconds to wait at each physical target (reduced for speed)
local SEARCH_WAIT_TIME = 2.0 -- Time in seconds to wait between search attempts
local TIMER_STOP_VALUES = {"00:10", "00:20"} -- Values that trigger a sequence stop
local TIMER_START_THRESHOLD = "00:30" -- If the timer is <= this value when starting, abort the sequence
local MANNEQUIN_TEST_TIME = 5.0 -- Time in seconds to wait at each mannequin for testing
local PAW_WAIT_TIME = 6.0 -- Time in seconds to wait at the Paw for initial interaction (still used as a main loop wait time)
local MAX_CLICK_RETRIES = 5 -- Max retries for Inventory and BasicSelects clicks.
local PET_CLICK_RETRIES = 5 -- Max retries specifically for individual pet buttons.
local VERSION_TEXT = "V4.8 Console Mode Active." -- Console-specific version text

-- Services and Player Setup
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Wait for the character and HumanoidRootPart to be ready
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Global Control Flags (Set to TRUE by default as there is no UI to toggle them)
local IS_SCRIPT_ACTIVE = true        -- Is the entire script running
local IS_AUTO_PET_CLICK_ACTIVE = true -- Controls pet clicking within the sequence
local IsSequenceActive = false       -- Is the teleport/click sequence currently running?
local ShouldStop = false             -- Has the timer triggered a stop signal?

-- State for prioritization across game rounds
local cycleCount = 0

-- Define the path components up to the MINIGAME container
local MINIGAME_CONTAINER_COMPONENTS = {
	"Interiors",
	"FashionFrenzy", -- The script handles the UID suffix when searching for this object.
	"Customize",
	"Minigame" -- This is the common parent container
}

--------------------------------------------------------------------------------
-- 🚀 INITIAL STATUS
--------------------------------------------------------------------------------

print("--------------------------------------------------")
print("Fashion Frenzy Automation Console Mode Initialized")
print(string.format("Version: %s", VERSION_TEXT))
-- FIX: Added tostring() to convert boolean values to strings for string.format
print(string.format("Main Script Active: %s | Auto Pet Click Active: %s", tostring(IS_SCRIPT_ACTIVE), tostring(IS_AUTO_PET_CLICK_ACTIVE)))
print("--------------------------------------------------")

--------------------------------------------------------------------------------
-- TIMER MONITOR THREAD
--------------------------------------------------------------------------------

-- Utility function to read the current timer text from the GUI
local function getCurrentTimerText()
	-- Find the timer label relative to the PlayerGui
	local app = LocalPlayer.PlayerGui:FindFirstChild("FashionFrenzyInGameApp", true)

	-- Refactored for safety against misplaced symbols
	local body = app and app:FindFirstChild("Body")
	local left = body and body:FindFirstChild("Left")
	local container = left and left.Container
	local valueLabel = container and container:FindFirstChild("ValueLabel")

	if valueLabel and valueLabel:IsA("TextLabel") then
		return valueLabel.Text
	end
	return nil
end

-- Function to safely wait for a duration while checking the global stop flag
local function waitWithStopCheck(duration)
	local checkInterval = 1 -- Check every 1 second
	local remaining = duration

	while remaining > 0 and not ShouldStop do
		local waitTime = math.min(checkInterval, remaining)
		task.wait(waitTime)
		remaining = remaining - checkInterval
	end
end

local function timerMonitor()
	while true do
		if IsSequenceActive then
			local text = getCurrentTimerText()

			if text then
				-- Check if the current time matches any of the stop values
				for _, stopValue in ipairs(TIMER_STOP_VALUES) do
					if text == stopValue then
						if not ShouldStop then
							print(string.format("[TIMER STOP] !! Timer HIT STOP VALUE (%s). Stopping sequence.", stopValue))
							ShouldStop = true
							break
						end
					end
				end
			end
		end
		task.wait(0.1) -- Check the timer frequently
	end
end

task.spawn(timerMonitor)

--------------------------------------------------------------------------------
-- GUI INTERACTION FUNCTIONS (Integrated Click Logic)
--------------------------------------------------------------------------------

-- Function to calculate the absolute center position of a GuiObject
local function getGuiCenter(guiObject)
	local absPos = guiObject.AbsolutePosition
	local absSize = guiObject.AbsoluteSize
	local centerX = absPos.X + (absSize.X / 2)
	local centerY = absPos.Y + (absSize.Y / 2)
	return centerX, centerY
end

-- Function to simulate click events using event firing OR positional click as a fallback.
local function clickButton(button, retries)
	if not button or not getconnections then return false end
	retries = retries or 1
	local success = false

	for attempt = 1, retries do
		-- 1. Attempt to simulate MouseButton1Down/Up/Click events
		for _, connection in pairs(getconnections(button.MouseButton1Down)) do connection:Fire() end
		task.wait(0.01)
		
		local clickConnections = getconnections(button.MouseButton1Click)
		if #clickConnections > 0 then
			for _, connection in pairs(clickConnections) do connection:Fire() end
			success = true
		else
			for _, connection in pairs(getconnections(button.MouseButton1Up)) do connection:Fire() end
			success = true
		end
		task.wait(0.01)
		for _, connection in pairs(getconnections(button.MouseButton1Up)) do connection:Fire() end

		if success then break end

		-- 2. FALLBACK: Positional Click
		if not success and type(setcursorpos) == "function" and type(mouse1click) == "function" then
			local x, y = getGuiCenter(button)
			setcursorpos(math.floor(x), math.floor(y))
			task.wait(0.05)
			mouse1click(math.floor(x), math.floor(y))
			success = true
			task.wait(0.1)
			break
		end

		task.wait(0.2)
	end

	if not success then
		warn(string.format("[CLICK FAIL] Failed to click: %s after %d attempts.", button.Name, retries))
	end

	return success
end

-- Helper function to check the current visibility state of the BackpackApp
local function checkBackpackVisibility()
	local gui = LocalPlayer.PlayerGui
	local backpackApp = gui:FindFirstChild("BackpackApp")
	local isVisible = backpackApp and backpackApp:IsA("ScreenGui") and backpackApp.Enabled
	return isVisible
end

-- Safely finds the primary inventory/backpack button using recursive search.
local function findInventoryButton()
	local gui = LocalPlayer.PlayerGui
	local SEARCH_NAMES = {"InventoryButton", "BackpackButton", "BagButton", "ItemsButton"}
	for _, name in ipairs(SEARCH_NAMES) do
		local button = gui:FindFirstChild(name, true)
		if button and (button:IsA("TextButton") or button:IsA("ImageButton")) then
			return button
		end
	end
	return nil
end

-- Function to safely open the main Inventory/Backpack UI
local function openMainInventory()
	if checkBackpackVisibility() then return end

	local button = findInventoryButton()

	if button then
		local success = false
		for attempt = 1, MAX_CLICK_RETRIES do
			if clickButton(button, 1) then
				success = true
				break
			end
			task.wait(0.2)
		end

		if success then
			task.wait(0.5)
		else
			warn("[INVENTORY] Failed to open Backpack via Inventory button after all retries.")
		end
	else
		warn("[INVENTORY] Could not find the main Backpack/Inventory UI button.")
	end
end

-- Clicks all buttons in the BasicSelects container
local function clickAllBasicSelects()
	if ShouldStop or not IS_SCRIPT_ACTIVE then return end

	local basicSelectsContainer = LocalPlayer.PlayerGui:FindFirstChild("InteractionsApp")
		and LocalPlayer.PlayerGui.InteractionsApp:FindFirstChild("BasicSelects")

	if not basicSelectsContainer then
		warn("[INTERACTION] InteractionsApp.BasicSelects container not found. Skipping clicks.")
		return
	end

	local clickCount = 0
	for _, templateFrame in ipairs(basicSelectsContainer:GetChildren()) do
		if ShouldStop or not IS_SCRIPT_ACTIVE then break end

		if templateFrame:IsA("GuiObject") then
			local buttonToClick = templateFrame:FindFirstChild("TapButton", true)

			if buttonToClick and (buttonToClick:IsA("TextButton") or buttonToClick:IsA("ImageButton")) then
				local success = false
				for attempt = 1, MAX_CLICK_RETRIES do
					if clickButton(buttonToClick, 1) then
						success = true
						break
					end
					task.wait(0.1)
				end

				if success then
					clickCount = clickCount + 1
					task.wait(0.1)
				else
					warn(string.format("[INTERACTION] Failed to click BasicSelects button %s after %d retries.", buttonToClick.Parent.Name, MAX_CLICK_RETRIES))
				end
			end
		end
	end
	print(string.format("[INTERACTION] Finished clicking %d BasicSelect buttons.", clickCount))
end

--------------------------------------------------------------------------------
-- CONTINUOUS ROW0 PET CLICK LOOP
--------------------------------------------------------------------------------

-- The main continuous loop function
local function continuousRow0ClickLoop()
	local gui = LocalPlayer:WaitForChild("PlayerGui")

	while true do
		if IS_SCRIPT_ACTIVE and IS_AUTO_PET_CLICK_ACTIVE then
			openMainInventory()
			task.wait(0.2)

			local BackpackApp = gui:FindFirstChild("BackpackApp")

			if BackpackApp and BackpackApp.Enabled then
				local scrollingFrame = BackpackApp:FindFirstChild("Frame", true)
				local targetContainer

				if scrollingFrame then
					local Body = scrollingFrame:FindFirstChild("Body", true)
					local ScrollComplex = Body and Body:FindFirstChild("ScrollComplex", true)
					local ScrollingFrame = ScrollComplex and ScrollComplex:FindFirstChild("ScrollingFrame")
					local Content = ScrollingFrame and ScrollingFrame:FindFirstChild("Content")
					local pets = Content and Content:FindFirstChild("pets")
					targetContainer = pets and pets:FindFirstChild("Row0")
				end

				if targetContainer then
					local clickCount = 0
					task.wait(0.2)

					for _, descendant in ipairs(targetContainer:GetDescendants()) do
						if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
							local lowerName = descendant.Name:lower()
							local isPetItemButton = lowerName == "button" or lowerName == "tapbutton" or lowerName:match("^%d+%_")

							if isPetItemButton then
								if clickButton(descendant, PET_CLICK_RETRIES) then
									clickCount = clickCount + 1
									task.wait(0.01)
								end
							end
						end
					end
					print(string.format("[PET MODE] Backpack is open. Clicked %d pets in Row0. Looping...", clickCount))
				else
					print("[PET MODE] Backpack is open, but Row0 container not found (Waiting for items).")
				end
			else
				print("[PET MODE] Backpack is not open (Attempting to open).")
			end

			task.wait(0.1)
		else
			-- Print less frequently when inactive
			task.wait(1.0)
		end
	end
end

task.spawn(continuousRow0ClickLoop)

--------------------------------------------------------------------------------
-- UTILITY & TELEPORT FUNCTIONS
--------------------------------------------------------------------------------

-- Helper function to find a child whose name starts with a specific prefix.
local function findChildByPrefix(parent, prefix)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name:sub(1, #prefix) == prefix then
			return child
		end
	end
	return nil
end

-- Function to find the best physical part to teleport to within a model.
local function findBestPartToTeleportTo(model, primaryName)
	local primaryPart = model:FindFirstChild(primaryName, true)
	if primaryPart and primaryPart:IsA("BasePart") then
		return primaryPart
	end
	if model:IsA("BasePart") then
		return model
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			return descendant
		end
	end
	return nil
end

-- Function to handle the marker creation and teleportation
local function TeleportTo(position)
	if ShouldStop or not IS_SCRIPT_ACTIVE then return end

	-- Create the small target cube (Teleport Marker)
	local marker = Instance.new("Part")
	marker.Name = "TeleportMarker"
	marker.Size = Vector3.new(1.5, 1.5, 1.5)
	marker.Position = position + Vector3.new(0, 3, 0)
	marker.Transparency = 0.2
	marker.Anchored = true
	marker.CanCollide = false
	marker.BrickColor = BrickColor.new("Really red")
	marker.Material = Enum.Material.Neon
	marker.Parent = Workspace

	-- Teleport the character's HumanoidRootPart to the marker's location
	HumanoidRootPart.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))

	-- Wait at the location
	task.wait(TELEPORT_DELAY)

	-- Clean up the marker
	marker:Destroy()
end

-- Function to find the position of the first available Paw part (now uses robust finding)
local function findFirstPawPosition(minigameContainer)
	local petPodiumsContainer = minigameContainer:FindFirstChild("PetPodiums")
	if not petPodiumsContainer then return nil end

	for _, podiumModel in ipairs(petPodiumsContainer:GetChildren()) do
		local targetPart = findBestPartToTeleportTo(podiumModel, "Paw")
		if targetPart then
			return targetPart.Position
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- TELEPORT SEQUENCE FUNCTIONS (Main Accessory Cycle)
--------------------------------------------------------------------------------

-- Function to handle Mannequin teleportation and accessory equip cycle (The "others" step)
local function teleportToMannequins(minigameContainer, returnPosition)
	print("--- STARTING MANNEQUIN TELEPORT & ACCESSORY CYCLE ---")
	local mannequinsContainer = minigameContainer:FindFirstChild("AccessoryMannequins")

	if not mannequinsContainer or ShouldStop or not IS_SCRIPT_ACTIVE then warn("[SEQUENCE] Mannequin container not found or sequence stopped."); return end

	local targetsFound = 0
	for _, mannequinModel in ipairs(mannequinsContainer:GetChildren()) do
		if ShouldStop or not IS_SCRIPT_ACTIVE then return end

		targetsFound = targetsFound + 1
		local targetPart = findBestPartToTeleportTo(mannequinModel, "Head")

		if targetPart then
			print(string.format("[MANNEQUIN %d] Teleporting to Mannequin: %s (Target: %s) - Testing accessories.", targetsFound, mannequinModel.Name, targetPart.Name))

			-- 1. Teleport to Mannequin HRP/Part
			TeleportTo(targetPart.Position)

			-- 2. Click all buttons in BasicSelects (Accessory Selection)
			clickAllBasicSelects()
			if ShouldStop or not IS_SCRIPT_ACTIVE then return end

			-- 3. Wait 5 seconds (safe wait with timer check)
			print(string.format("[MANNEQUIN %d] Waiting %d seconds for accessory testing...", targetsFound, MANNEQUIN_TEST_TIME))
			waitWithStopCheck(MANNEQUIN_TEST_TIME)
			if ShouldStop or not IS_SCRIPT_ACTIVE then return end

			-- 4. Teleport back to Paw position to finalize accessory selection
			if returnPosition then
				print(string.format("[MANNEQUIN %d] Confirmation Step: Teleporting back to Paw for finalize click.", targetsFound))
				TeleportTo(returnPosition)
				if ShouldStop or not IS_SCRIPT_ACTIVE then return end
			end
		end
	end
	print("--- MANNEQUIN TELEPORT & ACCESSORY CYCLE FINISHED ---")
end

-- Function to run the primary sequence (teleport, click, wait)
local function runPrimarySequence(minigameContainer)
	IsSequenceActive = true
	ShouldStop = false
	cycleCount = cycleCount + 1
	print(string.format("--- STARTING NEW FASHION FRENZY CYCLE #%d ---", cycleCount))

	-- 1. Find the Paw position (The main hub location)
	local pawPosition = findFirstPawPosition(minigameContainer)

	if not pawPosition then
		warn("[CYCLE ABORT] Could not find a Paw part to start the sequence.")
		IsSequenceActive = false
		return
	end

	-- 2. Teleport to the Paw position
	TeleportTo(pawPosition)
	print(string.format("[CYCLE %d] Teleported to Paw. Running Mannequin cycle...", cycleCount))

	-- 3. *REMOVED PAW CLICK* - Only proceeding to mannequins.

	-- 4. Run the main Mannequin Cycle, returning to the Paw after each one
	teleportToMannequins(minigameContainer, pawPosition)

	-- 5. Final step: Teleport back to the Paw position one last time for confirmation/final click
	TeleportTo(pawPosition)
	print(string.format("[CYCLE %d] Teleported to Paw for final selection.", cycleCount))

	-- 6. End sequence housekeeping
	IsSequenceActive = false
	ShouldStop = false -- Reset for the next round
	print(string.format("--- CYCLE #%d COMPLETE. Searching for new round. ---", cycleCount))
end

--------------------------------------------------------------------------------
-- 🚀 MAIN GAME SEARCH LOOP
--------------------------------------------------------------------------------

local function mainSearchLoop()
	while true do
		if IS_SCRIPT_ACTIVE then
			if not IsSequenceActive and not ShouldStop then
				
				local containerNamePrefix = table.remove(MINIGAME_CONTAINER_COMPONENTS, 2) -- "FashionFrenzy"
				
				local fashionFrenzyContainer = findChildByPrefix(Workspace.Interiors, containerNamePrefix)

				if fashionFrenzyContainer then
					local minigameContainer = fashionFrenzyContainer:FindFirstChild("Customize", true)
						and fashionFrenzyContainer.Customize:FindFirstChild("Minigame", true)

					if minigameContainer then
						local currentTimer = getCurrentTimerText()
						
						if currentTimer and currentTimer > TIMER_START_THRESHOLD then
							print(string.format("[SEARCH] Minigame ready. Timer is %s (above %s). Starting sequence...", currentTimer, TIMER_START_THRESHOLD))
							runPrimarySequence(minigameContainer)
						else
							print(string.format("[SEARCH] Minigame ready, but timer is low (%s). Waiting for the round to end.", currentTimer or "N/A"))
						end

					else
						print("[SEARCH] Round Found, but Minigame parts still loading...")
					end
				else
					print("[SEARCH] Searching for new Fashion Frenzy round...")
				end
				
				table.insert(MINIGAME_CONTAINER_COMPONENTS, 2, containerNamePrefix)

			end
		else
			print("[SEARCH] Main Script is INACTIVE. Waiting for toggle.")
		end

		task.wait(SEARCH_WAIT_TIME)
	end
end

task.spawn(mainSearchLoop)

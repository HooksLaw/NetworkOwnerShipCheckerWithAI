--[[
    This is a test script for the PartOwnershipDetector module.
    Run this as a LocalScript in a Roblox place to test the functionality.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Assuming the module is placed in ReplicatedStorage
local detector = require(ReplicatedStorage.PartOwnershipDetector)

-- Create a test function
local function testDetector()
    -- Wait for the player character to load
    local player = Players.LocalPlayer
    repeat wait() until player.Character
    
    print("Testing PartOwnershipDetector...")
    
    -- Create some test parts
    local testParts = {}
    
    -- Test part 1: Server-owned (anchored)
    local serverPart = Instance.new("Part")
    serverPart.Name = "ServerPart"
    serverPart.Anchored = true
    serverPart.Size = Vector3.new(4, 1, 4)
    serverPart.Position = player.Character.HumanoidRootPart.Position + Vector3.new(0, 5, 0)
    serverPart.BrickColor = BrickColor.new("Really red")
    serverPart.Parent = workspace
    table.insert(testParts, serverPart)
    
    -- Test part 2: Likely client-owned (unanchored, near player)
    local clientPart = Instance.new("Part")
    clientPart.Name = "ClientPart"
    clientPart.Anchored = false
    clientPart.Size = Vector3.new(2, 2, 2)
    clientPart.Position = player.Character.HumanoidRootPart.Position + Vector3.new(0, 10, 0)
    clientPart.BrickColor = BrickColor.new("Bright green")
    clientPart.Parent = workspace
    table.insert(testParts, clientPart)
    
    -- Wait a moment for network ownership to be assigned
    wait(1)
    
    -- Apply a small force to potentially trigger client ownership
    clientPart:ApplyImpulse(Vector3.new(0, 5, 0))
    
    -- Test part 3: Player character part (usually client-owned)
    local characterPart = player.Character.HumanoidRootPart
    table.insert(testParts, characterPart)
    
    -- Function to display result
    local function displayResult(part, ownership, confidence)
        local status = "⚠️ Unknown"
        
        if ownership == detector.OWNERSHIP.CLIENT then
            status = "✅ Client-owned"
        elseif ownership == detector.OWNERSHIP.SERVER then
            status = "🔒 Server-owned"
        end
        
        print(string.format("%s (%s): %s (Confidence: %.2f)", 
            part.Name, 
            part.Anchored and "Anchored" or "Not Anchored", 
            status, 
            confidence))
    end
    
    -- Test individual methods
    local methodNames = {
        "DetectByNetworkOwnership",
        "DetectByReceiveAge",
        "DetectByPhysicsModification",
        "DetectByCFrameModification",
        "DetectByAnchorModification",
        "DetectByCollisionModification"
    }
    
    -- Wait a bit more to let physics settle
    wait(2)
    
    -- Test each part
    for _, part in ipairs(testParts) do
        print("\n--- Testing " .. part.Name .. " ---")
        
        -- Get detailed info
        local info = detector:GetDetailedOwnershipInfo(part)
        
        print("Detailed Method Results:")
        
        for _, method in ipairs(methodNames) do
            local result = info[method] or "Not Available"
            print(" - " .. method .. ": " .. tostring(result))
        end
        
        -- Get combined result
        local ownership, confidence = detector:DetectOwnership(part)
        displayResult(part, ownership, confidence)
        
        -- Boolean tests
        print("Is Client Owned (0.6 confidence):", detector:IsClientOwned(part))
        print("Is Server Owned (0.6 confidence):", detector:IsServerOwned(part))
    end
    
    -- Test position tracking for one part asynchronously
    print("\nTesting position tracking on ClientPart...")
    detector:DetectByPositionTracking(clientPart, 2, function(result)
        print("Position tracking result:", result)
    end)
    
    -- Apply some force to the client part to test position tracking
    for i = 1, 5 do
        clientPart:ApplyImpulse(Vector3.new(math.random(-5, 5), 5, math.random(-5, 5)))
        wait(0.2)
    end
    
    print("\nTesting complete!")
end

-- Run the test
testDetector()
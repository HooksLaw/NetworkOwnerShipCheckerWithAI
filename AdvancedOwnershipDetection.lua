--[[
    Advanced Ownership Detection Example
    
    This script demonstrates how to use the PartOwnershipDetector in a more complex scenario,
    like a physics-based game where you need to know which parts can be modified locally.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Require the module (assuming it's in ReplicatedStorage)
local detector = require(ReplicatedStorage.PartOwnershipDetector)

-- Initialize a table to keep track of ownership
local cachedOwnership = {}

-- Function to safely get ownership with caching
local function getPartOwnership(part)
    if not part or not part:IsA("BasePart") then return detector.OWNERSHIP.UNKNOWN, 0 end
    
    -- Check cache first (only use cache for a short time to account for network ownership changes)
    if cachedOwnership[part] and (os.clock() - cachedOwnership[part].timestamp) < 1 then
        return cachedOwnership[part].ownership, cachedOwnership[part].confidence
    end
    
    -- Get fresh ownership data
    local ownership, confidence = detector:DetectOwnership(part)
    
    -- Cache the result
    cachedOwnership[part] = {
        ownership = ownership,
        confidence = confidence,
        timestamp = os.clock()
    }
    
    return ownership, confidence
end

-- Highlight parts based on ownership (visual helper)
local function highlightPart(part, ownership)
    -- Create a highlight effect if it doesn't exist
    if not part:FindFirstChild("OwnershipHighlight") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "OwnershipHighlight"
        highlight.Parent = part
    end
    
    local highlight = part.OwnershipHighlight
    
    if ownership == detector.OWNERSHIP.CLIENT then
        -- Green for client-owned
        highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
        highlight.FillColor = Color3.fromRGB(0, 150, 0)
    elseif ownership == detector.OWNERSHIP.SERVER then
        -- Red for server-owned
        highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
        highlight.FillColor = Color3.fromRGB(150, 0, 0)
    else
        -- Yellow for unknown
        highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
        highlight.FillColor = Color3.fromRGB(150, 150, 0)
    end
    
    highlight.Enabled = true
end

-- Process a single part
local function processPartForInteraction(part)
    local ownership, confidence = getPartOwnership(part)
    
    -- Highlight the part based on ownership for visualization
    highlightPart(part, ownership)
    
    -- Example interaction: Allow client-owned parts to be modified by keyboard input
    if ownership == detector.OWNERSHIP.CLIENT and confidence >= 0.7 then
        part.Material = Enum.Material.Neon
        
        -- Example of applying physics if the part is client-owned
        if RunService:IsClient() and not part.Anchored then
            local randomForce = Vector3.new(
                math.random(-10, 10), 
                math.random(5, 15), 
                math.random(-10, 10)
            )
            
            part:ApplyImpulse(randomForce)
        end
    end
    
    return ownership
end

-- Process all parts in the workspace
local function scanWorkspaceForInteractableParts()
    local interactableParts = {}
    local totalParts = 0
    local clientParts = 0
    local serverParts = 0
    local unknownParts = 0
    
    -- Loop through all parts in workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:IsDescendantOf(Players.LocalPlayer.Character) then
            totalParts = totalParts + 1
            
            local ownership = processPartForInteraction(obj)
            
            if ownership == detector.OWNERSHIP.CLIENT then
                clientParts = clientParts + 1
                table.insert(interactableParts, obj)
            elseif ownership == detector.OWNERSHIP.SERVER then
                serverParts = serverParts + 1
            else
                unknownParts = unknownParts + 1
            end
        end
    end
    
    -- Report statistics
    print(string.format("Scan complete: %d total parts (%d client, %d server, %d unknown)", 
        totalParts, clientParts, serverParts, unknownParts))
    
    return interactableParts
end

-- Example of continuous monitoring of specific parts
local function monitorPart(part)
    local previousOwnership = nil
    
    -- Function to check for ownership changes
    local function checkOwnership()
        local currentOwnership = getPartOwnership(part)
        
        if previousOwnership ~= currentOwnership then
            print(string.format("Part %s ownership changed from %s to %s", 
                part.Name, tostring(previousOwnership), tostring(currentOwnership)))
            
            previousOwnership = currentOwnership
            highlightPart(part, currentOwnership)
        end
    end
    
    -- Connect to heartbeat for continuous monitoring
    local connection = RunService.Heartbeat:Connect(checkOwnership)
    
    -- Return a function to stop monitoring
    return function()
        connection:Disconnect()
    end
end

-- Example usage
local function main()
    -- Wait for character to load
    local player = Players.LocalPlayer
    repeat wait() until player.Character
    
    print("Starting advanced ownership detection...")
    
    -- Initial scan
    local interactableParts = scanWorkspaceForInteractableParts()
    
    -- Set up monitoring for the first few interactable parts
    local monitors = {}
    for i = 1, math.min(5, #interactableParts) do
        monitors[i] = monitorPart(interactableParts[i])
    end
    
    -- Run another scan periodically
    spawn(function()
        while wait(10) do
            interactableParts = scanWorkspaceForInteractableParts()
        end
    end)
    
    print("Advanced detection system running!")
    
    -- Example of cleanup function (call this when the script should stop)
    local function cleanup()
        for _, stopMonitoring in pairs(monitors) do
            stopMonitoring()
        end
        
        -- Remove highlights
        for _, part in pairs(workspace:GetDescendants()) do
            if part:IsA("BasePart") and part:FindFirstChild("OwnershipHighlight") then
                part.OwnershipHighlight:Destroy()
            end
        end
    end
    
    -- Return cleanup function
    return cleanup
end

-- Start the system
local stopSystem = main()

-- To stop the system later, call:
-- stopSystem()
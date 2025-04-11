--[[
    PartOwnershipDetector
    A module for detecting part ownership (player vs server) client-side
    
    This module provides multiple methods to detect whether a part is owned by 
    the client or the server, without using RemoteEvents. The module combines
    different heuristics for improved reliability.
]]

local PartOwnershipDetector = {}

-- Constants for return values
PartOwnershipDetector.OWNERSHIP = {
    SERVER = "Server",
    CLIENT = "Client",
    UNKNOWN = "Unknown"
}

-- Cache common services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local NetworkSettings = settings():GetService("NetworkSettings")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get local player
local localPlayer = Players.LocalPlayer

-- Track the performance of different detection methods
PartOwnershipDetector.Statistics = {
    methodAccuracy = {}, -- Tracks how often each method is right
    lastResults = {},    -- Stores last 100 results for analysis
    maxHistorySize = 100 -- Maximum number of historical results to keep
}

--[[
    Detects part ownership using the NetworkOwnership property
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value
]]
function PartOwnershipDetector:DetectByNetworkOwnership(part)
    if not part or not part:IsA("BasePart") then
        warn("DetectByNetworkOwnership: Invalid part provided")
        return self.OWNERSHIP.UNKNOWN
    end
    
    -- Check if NetworkOwner exists and if it's the LocalPlayer
    if part:GetNetworkOwner() == localPlayer then
        return self.OWNERSHIP.CLIENT
    elseif part:GetNetworkOwner() == nil then
        -- nil could mean server-owned or no ownership assigned
        return self.OWNERSHIP.SERVER
    else
        -- Another player owns it, which from our perspective is server
        return self.OWNERSHIP.SERVER
    end
end

--[[
    Detects part ownership using the ReceiveAge property
    Parts owned by the client will have lower ReceiveAge values
    
    @param part (BasePart) - The part to check
    @param threshold (number) - Optional threshold in seconds (default: 0.1)
    @return (string) - PartOwnershipDetector.OWNERSHIP value
]]
function PartOwnershipDetector:DetectByReceiveAge(part, threshold)
    if not part or not part:IsA("BasePart") then
        warn("DetectByReceiveAge: Invalid part provided")
        return self.OWNERSHIP.UNKNOWN
    end
    
    threshold = threshold or 0.1
    
    -- ReceiveAge is the time since the part's state was last received from the server
    -- Client-owned parts will have lower ReceiveAge since they're updated locally
    if part.ReceiveAge < threshold then
        return self.OWNERSHIP.CLIENT
    else
        return self.OWNERSHIP.SERVER
    end
end

--[[
    Detects part ownership by attempting a temporary physics modification
    Client-owned parts can have physics properties modified locally
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value
]]
function PartOwnershipDetector:DetectByPhysicsModification(part)
    if not part or not part:IsA("BasePart") then
        warn("DetectByPhysicsModification: Invalid part provided")
        return self.OWNERSHIP.UNKNOWN
    end
    
    -- Store original values
    local originalVelocity = part.Velocity
    local originalAssemblyLinearVelocity = part.AssemblyLinearVelocity
    
    -- Try to modify the physics temporarily
    local success = pcall(function()
        -- Make a tiny change that shouldn't be noticeable
        part.Velocity = originalVelocity + Vector3.new(0.001, 0, 0)
        
        -- Compare to verify the change was applied
        if part.Velocity ~= originalVelocity then
            -- We were able to modify it, so revert back
            part.Velocity = originalVelocity
            return true
        end
        return false
    end)
    
    -- Ensure we revert any changes
    pcall(function()
        part.Velocity = originalVelocity
        part.AssemblyLinearVelocity = originalAssemblyLinearVelocity
    end)
    
    if success then
        return self.OWNERSHIP.CLIENT
    else
        return self.OWNERSHIP.SERVER
    end
end

--[[
    Detects part ownership by checking if CFrame can be modified
    Client-owned parts can have their CFrame modified locally
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value
]]
function PartOwnershipDetector:DetectByCFrameModification(part)
    if not part or not part:IsA("BasePart") then
        warn("DetectByCFrameModification: Invalid part provided")
        return self.OWNERSHIP.UNKNOWN
    end
    
    -- Store original value
    local originalCFrame = part.CFrame
    
    -- Try to modify the CFrame temporarily
    local success = pcall(function()
        -- Make a tiny rotation that shouldn't be noticeable
        local newCFrame = originalCFrame * CFrame.Angles(0.0001, 0, 0)
        part.CFrame = newCFrame
        
        -- Compare to verify the change was applied
        if part.CFrame ~= originalCFrame then
            -- We were able to modify it, so revert back
            part.CFrame = originalCFrame
            return true
        end
        return false
    end)
    
    -- Ensure we revert any changes
    pcall(function()
        part.CFrame = originalCFrame
    end)
    
    if success then
        return self.OWNERSHIP.CLIENT
    else
        return self.OWNERSHIP.SERVER
    end
end

--[[
    Detects part ownership by checking Anchored property changes
    Client-owned parts can have their Anchored property changed locally
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value
]]
function PartOwnershipDetector:DetectByAnchorModification(part)
    if not part or not part:IsA("BasePart") then
        warn("DetectByAnchorModification: Invalid part provided")
        return self.OWNERSHIP.UNKNOWN
    end
    
    -- Don't attempt this test on parts that are welded as it can cause physics issues
    if part.Anchored == false and #part:GetConnectedParts() > 0 then
        return self.OWNERSHIP.UNKNOWN
    end
    
    -- Store original value
    local originalAnchor = part.Anchored
    
    -- Try to modify the Anchored property temporarily
    local success = pcall(function()
        part.Anchored = not originalAnchor
        
        -- Compare to verify the change was applied
        if part.Anchored ~= originalAnchor then
            -- We were able to modify it, so revert back
            part.Anchored = originalAnchor
            return true
        end
        return false
    end)
    
    -- Ensure we revert any changes
    pcall(function()
        part.Anchored = originalAnchor
    end)
    
    if success then
        return self.OWNERSHIP.CLIENT
    else
        return self.OWNERSHIP.SERVER
    end
end

--[[
    Detects part ownership by checking CanCollide property changes
    Client-owned parts can have their CanCollide property changed locally
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value
]]
function PartOwnershipDetector:DetectByCollisionModification(part)
    if not part or not part:IsA("BasePart") then
        warn("DetectByCollisionModification: Invalid part provided")
        return self.OWNERSHIP.UNKNOWN
    end
    
    -- Store original value
    local originalCanCollide = part.CanCollide
    
    -- Try to modify the CanCollide property temporarily
    local success = pcall(function()
        part.CanCollide = not originalCanCollide
        
        -- Compare to verify the change was applied
        if part.CanCollide ~= originalCanCollide then
            -- We were able to modify it, so revert back
            part.CanCollide = originalCanCollide
            return true
        end
        return false
    end)
    
    -- Ensure we revert any changes
    pcall(function()
        part.CanCollide = originalCanCollide
    end)
    
    if success then
        return self.OWNERSHIP.CLIENT
    else
        return self.OWNERSHIP.SERVER
    end
end

--[[
    Detects part ownership by tracking position changes during physics simulation
    Parts owned by client will have their position updated locally first
    
    @param part (BasePart) - The part to check
    @param duration (number) - Duration to track in seconds (default: 0.5)
    @param callback (function) - Optional callback function with result
    @return (string) - PartOwnershipDetector.OWNERSHIP value if callback is nil
]]
function PartOwnershipDetector:DetectByPositionTracking(part, duration, callback)
    if not part or not part:IsA("BasePart") then
        warn("DetectByPositionTracking: Invalid part provided")
        if callback then
            callback(self.OWNERSHIP.UNKNOWN)
            return
        end
        return self.OWNERSHIP.UNKNOWN
    end
    
    duration = duration or 0.5
    
    -- If we need immediate result with no callback
    if not callback then
        -- Fallback to other methods for immediate response
        return self:DetectByNetworkOwnership(part)
    end
    
    -- For tracking position changes
    local initialTime = os.clock()
    local initialPosition = part.Position
    local lastUpdateTime = initialTime
    local lastPosition = initialPosition
    local positionChanges = 0
    local serverUpdates = 0
    
    -- Used to detect if the server updated the position
    local function checkServerUpdate()
        if part.ReceiveAge < 0.1 and part.Position ~= lastPosition then
            serverUpdates = serverUpdates + 1
            lastPosition = part.Position
        end
    end
    
    -- Connect to heartbeat to track changes
    local connection
    connection = RunService.Heartbeat:Connect(function()
        local currentTime = os.clock()
        
        -- Check if position changed
        if part.Position ~= lastPosition then
            positionChanges = positionChanges + 1
            lastPosition = part.Position
            lastUpdateTime = currentTime
        end
        
        -- Check for server updates
        checkServerUpdate()
        
        -- Finished tracking
        if currentTime - initialTime >= duration then
            connection:Disconnect()
            
            -- Analyze results
            local result
            if positionChanges == 0 then
                -- No movement, can't determine
                result = self.OWNERSHIP.UNKNOWN
            elseif serverUpdates > positionChanges * 0.5 then
                -- Most updates came from server
                result = self.OWNERSHIP.SERVER
            else
                -- Most updates were local
                result = self.OWNERSHIP.CLIENT
            end
            
            callback(result)
        end
    end)
    
    -- If called without callback, return UNKNOWN
    if not callback then
        return self.OWNERSHIP.UNKNOWN
    end
end

--[[
    Combines multiple detection methods for a more reliable result
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value with confidence level
    @return (number) - Confidence level (0-1)
]]
function PartOwnershipDetector:DetectOwnership(part)
    if not part or not part:IsA("BasePart") then
        warn("DetectOwnership: Invalid part provided")
        return self.OWNERSHIP.UNKNOWN, 0
    end
    
    local results = {
        self:DetectByNetworkOwnership(part),
        self:DetectByReceiveAge(part),
        self:DetectByPhysicsModification(part),
        self:DetectByCFrameModification(part),
        self:DetectByCollisionModification(part),
        self:DetectByAnchorModification(part)
    }
    
    -- Count occurrences of each result
    local counts = {
        [self.OWNERSHIP.CLIENT] = 0,
        [self.OWNERSHIP.SERVER] = 0,
        [self.OWNERSHIP.UNKNOWN] = 0
    }
    
    for _, result in ipairs(results) do
        counts[result] = counts[result] + 1
    end
    
    -- Determine majority
    local majorityOwnership = self.OWNERSHIP.UNKNOWN
    local highestCount = 0
    
    for ownership, count in pairs(counts) do
        if count > highestCount and ownership ~= self.OWNERSHIP.UNKNOWN then
            highestCount = count
            majorityOwnership = ownership
        end
    end
    
    -- Calculate confidence (excluding UNKNOWN results)
    local validResults = #results - counts[self.OWNERSHIP.UNKNOWN]
    local confidence = validResults > 0 and counts[majorityOwnership] / validResults or 0
    
    return majorityOwnership, confidence
end

--[[
    Determines if the part is likely owned by the local client
    
    @param part (BasePart) - The part to check
    @param confidenceThreshold (number) - Minimum confidence level (0-1, default: 0.6)
    @return (boolean) - True if client-owned, false otherwise
]]
function PartOwnershipDetector:IsClientOwned(part, confidenceThreshold)
    if not part or not part:IsA("BasePart") then
        warn("IsClientOwned: Invalid part provided")
        return false
    end
    
    confidenceThreshold = confidenceThreshold or 0.6
    
    local ownership, confidence = self:DetectOwnership(part)
    return ownership == self.OWNERSHIP.CLIENT and confidence >= confidenceThreshold
end

--[[
    Determines if the part is likely owned by the server
    
    @param part (BasePart) - The part to check
    @param confidenceThreshold (number) - Minimum confidence level (0-1, default: 0.6)
    @return (boolean) - True if server-owned, false otherwise
]]
function PartOwnershipDetector:IsServerOwned(part, confidenceThreshold)
    if not part or not part:IsA("BasePart") then
        warn("IsServerOwned: Invalid part provided")
        return false
    end
    
    confidenceThreshold = confidenceThreshold or 0.6
    
    local ownership, confidence = self:DetectOwnership(part)
    return ownership == self.OWNERSHIP.SERVER and confidence >= confidenceThreshold
end

--[[
    Get detailed information about part ownership using all available methods
    
    @param part (BasePart) - The part to check
    @return (table) - Table with detailed results from all detection methods
]]
function PartOwnershipDetector:GetDetailedOwnershipInfo(part)
    if not part or not part:IsA("BasePart") then
        warn("GetDetailedOwnershipInfo: Invalid part provided")
        return {
            valid = false,
            error = "Invalid part provided"
        }
    end
    
    local info = {
        valid = true,
        part = part,
        partName = part.Name,
        partClass = part.ClassName,
        networkOwnership = self:DetectByNetworkOwnership(part),
        receiveAge = {
            value = part.ReceiveAge,
            result = self:DetectByReceiveAge(part)
        },
        physicsModification = self:DetectByPhysicsModification(part),
        cframeModification = self:DetectByCFrameModification(part),
        anchorModification = self:DetectByAnchorModification(part),
        collisionModification = self:DetectByCollisionModification(part),
        -- Additional properties that can help in ownership detection
        isAnchored = part.Anchored,
        isMassless = part.Massless,
        velocityMagnitude = part.Velocity.Magnitude,
        networkOwnerPlayer = part:GetNetworkOwner() and part:GetNetworkOwner().Name or "None",
        connectedParts = #part:GetConnectedParts()
    }
    
    -- Calculate overall result
    local ownership, confidence = self:DetectOwnership(part)
    info.overallOwnership = ownership
    info.confidence = confidence
    
    return info
end

--[[
    USAGE EXAMPLES:
    
    -- Basic usage
    local detector = require(path.to.PartOwnershipDetector)
    local part = workspace.SomePart
    
    -- Simple detection
    local ownership, confidence = detector:DetectOwnership(part)
    print("Part is owned by:", ownership, "with confidence:", confidence)
    
    -- Boolean checks
    if detector:IsClientOwned(part) then
        print("This part is client-owned, I can modify it!")
    end
    
    if detector:IsServerOwned(part) then
        print("This part is server-owned, I should request changes through the server")
    end
    
    -- Detailed information
    local info = detector:GetDetailedOwnershipInfo(part)
    for k, v in pairs(info) do
        print(k, v)
    end
    
    -- Async position tracking (useful for moving parts)
    detector:DetectByPositionTracking(part, 1, function(result)
        print("Position tracking result:", result)
    end)
    
    -- Detect multiple parts
    local parts = workspace:GetDescendants()
    local clientOwnedParts = {}
    local serverOwnedParts = {}
    
    for _, obj in ipairs(parts) do
        if obj:IsA("BasePart") then
            if detector:IsClientOwned(obj) then
                table.insert(clientOwnedParts, obj)
            elseif detector:IsServerOwned(obj) then
                table.insert(serverOwnedParts, obj)
            end
        end
    end
    
    print("Found", #clientOwnedParts, "client-owned parts and", #serverOwnedParts, "server-owned parts")
]]

--[[
    TESTING RECOMMENDATIONS:
    
    1. Create a simple LocalScript with parts that have different ownership:
       - Anchored parts (server-owned)
       - Parts affected by client physics (client-owned)
       - Parts affected by server physics (server-owned)
       - Parts in a character (mix of client/server owned)
       
    2. Test individual detection methods:
       local results = {}
       for _, method in ipairs({"DetectByNetworkOwnership", "DetectByReceiveAge", etc.}) do
           results[method] = detector[method](detector, part)
       end
       
    3. Test with different confidence thresholds:
       for threshold = 0.1, 1, 0.1 do
           print(detector:IsClientOwned(part, threshold))
       end
       
    4. Test edge cases:
       - Very large parts
       - Parts moving at high velocities
       - Parts that are constrained by joints
       - Parts within models
]]

return PartOwnershipDetector

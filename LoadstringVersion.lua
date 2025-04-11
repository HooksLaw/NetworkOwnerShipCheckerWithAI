--[[
    Part Ownership Detector - Loadstring Version
    
    This file contains all modules in a single file for easy import via loadstring.
    
    Usage:
    local Detector = loadstring(game:HttpGet("URL_TO_THIS_FILE"))()
    
    Returns a table with all modules:
    {
        Core = PartOwnershipDetector,
        HighPerformance = HighPerformanceOwnershipDetector,
        Character = CharacterSpecificOwnershipDetector,
        Physics = PhysicsToolDetector
    }
]]

-- Create the return object
local DetectorPackage = {}

--===== CORE MODULE =====--

local PartOwnershipDetector = {}
DetectorPackage.Core = PartOwnershipDetector

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

--===== HIGH PERFORMANCE MODULE =====--

local HighPerformanceDetector = {}
DetectorPackage.HighPerformance = HighPerformanceDetector

-- Constants
HighPerformanceDetector.OWNERSHIP = PartOwnershipDetector.OWNERSHIP

-- Cache for ownership results
local ownershipCache = {}
local cacheLifetime = 1  -- Cache results for 1 second
local lastCleanup = os.clock()

-- Frequency to scan the cache for expired entries
local CACHE_CLEANUP_FREQUENCY = 5  -- seconds

--[[
    Fast check that prioritizes cached results and quick methods
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value
]]
function HighPerformanceDetector:FastCheck(part)
    if not part or not part:IsA("BasePart") then
        return self.OWNERSHIP.UNKNOWN
    end
    
    -- Check cache first
    local cacheEntry = ownershipCache[part]
    if cacheEntry and (os.clock() - cacheEntry.timestamp) < cacheLifetime then
        return cacheEntry.ownership
    end
    
    -- Quick check #1: Anchored parts are almost always server-owned
    if part.Anchored then
        self:CacheResult(part, self.OWNERSHIP.SERVER)
        return self.OWNERSHIP.SERVER
    end
    
    -- Quick check #2: Network ownership is a reliable indicator
    if part:GetNetworkOwner() == localPlayer then
        self:CacheResult(part, self.OWNERSHIP.CLIENT)
        return self.OWNERSHIP.CLIENT
    elseif part:GetNetworkOwner() ~= nil then
        self:CacheResult(part, self.OWNERSHIP.SERVER)
        return self.OWNERSHIP.SERVER
    end
    
    -- Quick check #3: ReceiveAge check (very fast)
    if part.ReceiveAge < 0.05 then
        self:CacheResult(part, self.OWNERSHIP.CLIENT)
        return self.OWNERSHIP.CLIENT
    end
    
    -- For unclear cases, do a minimal property check
    local success = pcall(function()
        local originalVelocity = part.Velocity
        part.Velocity = originalVelocity + Vector3.new(0.001, 0, 0)
        part.Velocity = originalVelocity
    end)
    
    if success then
        self:CacheResult(part, self.OWNERSHIP.CLIENT)
        return self.OWNERSHIP.CLIENT
    else
        self:CacheResult(part, self.OWNERSHIP.SERVER)
        return self.OWNERSHIP.SERVER
    end
end

--[[
    Cache a result for quick future lookups
    
    @param part (BasePart) - The part being checked
    @param ownership (string) - The ownership result to cache
]]
function HighPerformanceDetector:CacheResult(part, ownership)
    ownershipCache[part] = {
        ownership = ownership,
        timestamp = os.clock()
    }
    
    -- Periodically clean up the cache to prevent memory leaks
    if os.clock() - lastCleanup > CACHE_CLEANUP_FREQUENCY then
        self:CleanupCache()
    end
end

--[[
    Remove old entries from the cache
]]
function HighPerformanceDetector:CleanupCache()
    local currentTime = os.clock()
    local itemsRemoved = 0
    
    for part, entry in pairs(ownershipCache) do
        if currentTime - entry.timestamp > cacheLifetime or not part:IsDescendantOf(workspace) then
            ownershipCache[part] = nil
            itemsRemoved = itemsRemoved + 1
        end
    end
    
    lastCleanup = currentTime
end

--[[
    Performs a batched analysis of multiple parts at once
    
    @param parts (table) - Array of BaseParts to check
    @return (table) - Map of parts to their ownership values
]]
function HighPerformanceDetector:BatchProcess(parts)
    local results = {}
    
    for _, part in ipairs(parts) do
        results[part] = self:FastCheck(part)
    end
    
    return results
end

--[[
    Get all parts in workspace with specific ownership type
    
    @param ownershipType (string) - The ownership type to filter for (CLIENT, SERVER, or UNKNOWN)
    @param options (table) - Optional settings:
      - ignoreAnchored (boolean): Skip anchored parts for faster processing
      - maxParts (number): Maximum number of parts to process
      - region (Region3): Only check parts in this region
    @return (table) - Array of parts with the specified ownership
]]
function HighPerformanceDetector:GetPartsWithOwnership(ownershipType, options)
    options = options or {}
    
    local result = {}
    local processed = 0
    local maxParts = options.maxParts or 1000
    
    local partsToCheck = {}
    
    -- Get parts to check, either by region or from the whole workspace
    if options.region then
        partsToCheck = workspace:FindPartsInRegion3(options.region, nil, maxParts)
    else
        -- Collect parts from workspace
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                if not (options.ignoreAnchored and obj.Anchored) then
                    table.insert(partsToCheck, obj)
                    processed = processed + 1
                    
                    if processed >= maxParts then
                        break
                    end
                end
            end
        end
    end
    
    -- Check ownership of collected parts
    for _, part in ipairs(partsToCheck) do
        local ownership = self:FastCheck(part)
        
        if ownership == ownershipType then
            table.insert(result, part)
        end
    end
    
    return result
end

--[[
    Perform a more detailed check when accuracy is needed
    Falls back to the base detector but with caching
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value
    @return (number) - Confidence level (0-1)
]]
function HighPerformanceDetector:DetailedCheck(part)
    if not part or not part:IsA("BasePart") then
        return self.OWNERSHIP.UNKNOWN, 0
    end
    
    -- For detailed checks, use the base detector but cache the result
    local ownership, confidence = PartOwnershipDetector:DetectOwnership(part)
    
    -- Cache the result
    self:CacheResult(part, ownership)
    
    return ownership, confidence
end

-- Configure cache settings
function HighPerformanceDetector:SetCacheLifetime(seconds)
    cacheLifetime = seconds
end

-- Clear the cache
function HighPerformanceDetector:ClearCache()
    ownershipCache = {}
    lastCleanup = os.clock()
end

--===== CHARACTER-SPECIFIC MODULE =====--

local CharacterOwnershipDetector = {}
DetectorPackage.Character = CharacterOwnershipDetector

-- Constants
CharacterOwnershipDetector.OWNERSHIP = PartOwnershipDetector.OWNERSHIP

--[[
    Determines if a part belongs to a player character
    
    @param part (BasePart) - The part to check
    @return (boolean, Player) - Whether it's a character part and which player
]]
function CharacterOwnershipDetector:IsCharacterPart(part)
    if not part or not part:IsA("BasePart") then
        return false, nil
    end
    
    -- Check if part is in a character model
    local ancestor = part
    while ancestor and ancestor.Parent ~= workspace do
        ancestor = ancestor.Parent
    end
    
    if not ancestor or not ancestor:IsA("Model") then
        return false, nil
    end
    
    -- Check if the model is a player character
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character == ancestor then
            return true, player
        end
    end
    
    return false, nil
end

--[[
    Detects ownership for a character part with specialized rules
    
    @param part (BasePart) - The part to check
    @return (string) - PartOwnershipDetector.OWNERSHIP value
    @return (number) - Confidence level (0-1)
]]
function CharacterOwnershipDetector:DetectCharacterPartOwnership(part)
    local isCharacterPart, player = self:IsCharacterPart(part)
    
    if not isCharacterPart then
        -- Not a character part, use base detector
        return PartOwnershipDetector:DetectOwnership(part)
    end
    
    -- Special rules for character parts
    if player == localPlayer then
        -- Local player's character parts have specific ownership patterns
        
        -- Check if it's a root part (often server-controlled)
        if part.Name == "HumanoidRootPart" then
            -- For root parts, use base detection but with higher threshold
            local ownership, confidence = PartOwnershipDetector:DetectOwnership(part)
            
            -- Override HumanoidRootPart to be classified as server unless test is very confident
            if ownership == PartOwnershipDetector.OWNERSHIP.CLIENT and confidence < 0.8 then
                return PartOwnershipDetector.OWNERSHIP.SERVER, 0.7
            end
            
            return ownership, confidence
        end
        
        -- Check if it's a limb (often client-controlled)
        if part.Name:find("Arm") or part.Name:find("Leg") or part.Name:find("Hand") or part.Name:find("Foot") then
            -- Limbs are typically client-owned in many cases
            local baseOwnership, baseConfidence = PartOwnershipDetector:DetectOwnership(part)
            
            -- Increase confidence for client ownership of limbs
            if baseOwnership == PartOwnershipDetector.OWNERSHIP.CLIENT then
                return PartOwnershipDetector.OWNERSHIP.CLIENT, math.min(1, baseConfidence + 0.15)
            end
            
            return baseOwnership, baseConfidence
        end
        
        -- For torso and head
        if part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Head" then
            -- These parts are more complex, so use detailed detection
            return PartOwnershipDetector:DetectOwnership(part)
        end
        
        -- For other parts, use base detection
        return PartOwnershipDetector:DetectOwnership(part)
    else
        -- Other players' character parts are always server-owned from our perspective
        return PartOwnershipDetector.OWNERSHIP.SERVER, 1
    end
end

--[[
    Gets detailed ownership for a part, with character-specific info when applicable
    
    @param part (BasePart) - The part to check
    @return (table) - Detailed information about the part's ownership
]]
function CharacterOwnershipDetector:GetDetailedInfo(part)
    local isCharacterPart, player = self:IsCharacterPart(part)
    
    -- Get base info
    local baseInfo = PartOwnershipDetector:GetDetailedOwnershipInfo(part)
    
    if isCharacterPart then
        -- Add character-specific information
        baseInfo.isCharacterPart = true
        baseInfo.characterOwner = player.Name
        baseInfo.isLocalCharacter = player == localPlayer
        baseInfo.partType = part.Name
        
        -- Override the overall ownership with character-specific detection
        local ownership, confidence = self:DetectCharacterPartOwnership(part)
        baseInfo.characterSpecificOwnership = ownership
        baseInfo.characterSpecificConfidence = confidence
        
        -- Update overall result to use character-specific logic
        baseInfo.overallOwnership = ownership
        baseInfo.confidence = confidence
    else
        baseInfo.isCharacterPart = false
    end
    
    return baseInfo
end

--[[
    Evaluates whether a part can be locally manipulated based on combined heuristics
    
    @param part (BasePart) - The part to check
    @return (boolean) - Whether the part is safe to manipulate locally
]]
function CharacterOwnershipDetector:CanManipulateLocally(part)
    local isCharacterPart, player = self:IsCharacterPart(part)
    
    if isCharacterPart then
        if player ~= localPlayer then
            -- Never manipulate other players' parts
            return false
        end
        
        -- For local character, apply specialized rules
        local ownership, confidence = self:DetectCharacterPartOwnership(part)
        
        -- Be cautious with character parts
        return ownership == PartOwnershipDetector.OWNERSHIP.CLIENT and confidence > 0.7
    else
        -- For non-character parts, use the base detector with standard threshold
        return PartOwnershipDetector:IsClientOwned(part, 0.6)
    end
end

--===== PHYSICS TOOL MODULE =====--

local PhysicsToolDetector = {}
DetectorPackage.Physics = PhysicsToolDetector

-- Constants
PhysicsToolDetector.OWNERSHIP = PartOwnershipDetector.OWNERSHIP

--[[
    Determine if a part is completely safe to apply physics to on the client
    This will use a combination of checks and a high confidence threshold
    
    @param part (BasePart) - The part to check
    @return (boolean) - Whether it's safe to apply physics
]]
function PhysicsToolDetector:IsSafeForPhysics(part)
    if not part or not part:IsA("BasePart") then
        return false
    end
    
    -- Quick rejection checks (Server parts will immediately fail these)
    if part.Anchored then
        return false
    end
    
    -- Check that part is not connected to server-owned parts
    local connectedParts = part:GetConnectedParts()
    if #connectedParts > 0 then
        for _, connectedPart in ipairs(connectedParts) do
            if PartOwnershipDetector:IsServerOwned(connectedPart, 0.7) then
                return false
            end
        end
    end
    
    -- Verify ownership with high confidence for physics
    local ownership, confidence = PartOwnershipDetector:DetectOwnership(part)
    return ownership == PartOwnershipDetector.OWNERSHIP.CLIENT and confidence >= 0.8
end

--[[
    Find which parts would be affected by a force applied to this part
    and check if all of them can be safely manipulated
    
    @param part (BasePart) - The part to apply force to
    @param recursive (boolean) - Whether to recursively check connected parts (default: true)
    @return (boolean) - Whether all affected parts are safe to manipulate
    @return (table) - List of parts that would be affected
]]
function PhysicsToolDetector:CanApplyForceToAssembly(part, recursive)
    if recursive == nil then recursive = true end
    
    if not part or not part:IsA("BasePart") then
        return false, {}
    end
    
    -- Get all parts that would be affected by physics
    local affectedParts = {}
    local checkedParts = {}
    
    local function collectParts(currentPart)
        if checkedParts[currentPart] then return end
        checkedParts[currentPart] = true
        
        table.insert(affectedParts, currentPart)
        
        if recursive then
            for _, connectedPart in ipairs(currentPart:GetConnectedParts()) do
                collectParts(connectedPart)
            end
        end
    end
    
    collectParts(part)
    
    -- Check if all parts can be safely manipulated
    for _, affectedPart in ipairs(affectedParts) do
        if not self:IsSafeForPhysics(affectedPart) then
            return false, affectedParts
        end
    end
    
    return true, affectedParts
end

--[[
    Creates a physics sandbox to test how a part would respond to physics
    without actually modifying the game state
    
    @param part (BasePart) - The part to test
    @param force (Vector3) - The force to apply in the simulation
    @param duration (number) - Simulation duration in seconds
    @param callback (function) - Function called with the simulation results
]]
function PhysicsToolDetector:SimulatePhysics(part, force, duration, callback)
    if not part or not part:IsA("BasePart") then
        if callback then
            callback({ success = false, error = "Invalid part" })
        end
        return
    end
    
    -- Check if we can manipulate this part first
    if not self:IsSafeForPhysics(part) then
        if callback then
            callback({ 
                success = false, 
                error = "Part cannot be safely manipulated", 
                ownership = PartOwnershipDetector:DetectOwnership(part)
            })
        end
        return
    end
    
    -- Get the assembly of connected parts
    local canApplyForce, affectedParts = self:CanApplyForceToAssembly(part)
    
    if not canApplyForce then
        if callback then
            callback({ 
                success = false, 
                error = "Cannot safely apply force to the entire assembly",
                affectedParts = affectedParts
            })
        end
        return
    end
    
    -- Create a simulation by cloning the part and its assembly
    local simulation = {}
    local partToClonedPart = {}
    
    -- Clone all parts in the assembly
    for _, affectedPart in ipairs(affectedParts) do
        local clone = affectedPart:Clone()
        clone.Anchored = false
        clone.CanCollide = false
        clone.Transparency = 0.8
        clone.Parent = workspace
        
        simulation[affectedPart] = {
            clone = clone,
            initialPosition = affectedPart.Position,
            initialVelocity = affectedPart.Velocity,
            currentVelocity = affectedPart.Velocity,
            positions = {}
        }
        
        partToClonedPart[affectedPart] = clone
    end
    
    -- Run the simulation
    local startTime = os.clock()
    local heartbeatConnection
    
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime
        
        if elapsed >= duration then
            -- Simulation complete
            heartbeatConnection:Disconnect()
            
            -- Collect results
            local results = {
                success = true,
                duration = elapsed,
                parts = {}
            }
            
            for original, data in pairs(simulation) do
                -- Calculate final values
                table.insert(results.parts, {
                    part = original,
                    displacement = (data.clone.Position - data.initialPosition).Magnitude,
                    trajectory = data.positions,
                    finalVelocity = data.clone.Velocity
                })
                
                -- Remove the clone
                data.clone:Destroy()
            end
            
            if callback then
                callback(results)
            end
            
            return
        end
        
        -- Update simulation
        for original, data in pairs(simulation) do
            -- Record the position
            table.insert(data.positions, data.clone.Position)
            
            -- Apply the force specifically to the clone of the original part that was passed in
            if original == part then
                data.clone:ApplyImpulse(force * 0.1) -- Scaled down for simulation
            end
        end
    end)
end

--[[
    Try to safely apply a force to a part, checking ownership first
    
    @param part (BasePart) - The part to apply force to
    @param force (Vector3) - The force to apply
    @return (boolean) - Whether the force was applied successfully
]]
function PhysicsToolDetector:SafeApplyForce(part, force)
    if not self:IsSafeForPhysics(part) then
        return false
    end
    
    local canApplyForce, _ = self:CanApplyForceToAssembly(part)
    if not canApplyForce then
        return false
    end
    
    -- Apply the force
    part:ApplyForce(force)
    return true
end

--[[
    Try to safely apply an impulse to a part, checking ownership first
    
    @param part (BasePart) - The part to apply impulse to
    @param impulse (Vector3) - The impulse to apply
    @return (boolean) - Whether the impulse was applied successfully
]]
function PhysicsToolDetector:SafeApplyImpulse(part, impulse)
    if not self:IsSafeForPhysics(part) then
        return false
    end
    
    local canApplyForce, _ = self:CanApplyForceToAssembly(part)
    if not canApplyForce then
        return false
    end
    
    -- Apply the impulse
    part:ApplyImpulse(impulse)
    return true
end

-- Return the package with all modules
return DetectorPackage
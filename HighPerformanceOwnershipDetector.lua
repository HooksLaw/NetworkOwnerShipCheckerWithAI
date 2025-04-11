--[[
    High Performance Ownership Detector
    
    This is an optimized version of the PartOwnershipDetector that prioritizes
    performance over accuracy, useful for scenarios where you need to quickly
    check many parts with minimal performance impact.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require the base detector module
local baseDetector = require(ReplicatedStorage.PartOwnershipDetector)

-- Create a specialized high-performance detector
local HighPerformanceDetector = {}

-- Constants
HighPerformanceDetector.OWNERSHIP = baseDetector.OWNERSHIP

-- Cache local player
local localPlayer = Players.LocalPlayer

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
    local ownership, confidence = baseDetector:DetectOwnership(part)
    
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

-- Return the high-performance detector
return HighPerformanceDetector
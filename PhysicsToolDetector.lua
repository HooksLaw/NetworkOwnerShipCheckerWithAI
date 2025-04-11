--[[
    Physics Tool Detector
    
    A specialized module that extends the PartOwnershipDetector specifically for tools
    that use physics manipulation, like building tools, guns with physics, etc.
    
    This module helps determine which parts can be affected by client-side physics
    and is optimal for tools that need to interact with the environment.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Require the base detector
local baseDetector = require(ReplicatedStorage.PartOwnershipDetector)

-- Create new module
local PhysicsToolDetector = {}

-- Import constants
PhysicsToolDetector.OWNERSHIP = baseDetector.OWNERSHIP

-- Cache local player
local localPlayer = Players.LocalPlayer

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
            if baseDetector:IsServerOwned(connectedPart, 0.7) then
                return false
            end
        end
    end
    
    -- Verify ownership with high confidence for physics
    local ownership, confidence = baseDetector:DetectOwnership(part)
    return ownership == baseDetector.OWNERSHIP.CLIENT and confidence >= 0.8
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
                ownership = baseDetector:DetectOwnership(part)
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

-- Return the PhysicsToolDetector module
return PhysicsToolDetector
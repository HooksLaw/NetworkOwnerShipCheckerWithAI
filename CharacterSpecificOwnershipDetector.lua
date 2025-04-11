--[[
    Character-Specific Ownership Detector
    
    This script focuses on detecting part ownership specifically for character parts,
    which can have unique ownership properties in Roblox.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require the main detector module
local baseDetector = require(ReplicatedStorage.PartOwnershipDetector)

-- Create a specialized detector for character parts
local CharacterOwnershipDetector = {}

-- Constants
CharacterOwnershipDetector.OWNERSHIP = baseDetector.OWNERSHIP

-- Cache local player
local localPlayer = Players.LocalPlayer

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
        return baseDetector:DetectOwnership(part)
    end
    
    -- Special rules for character parts
    if player == localPlayer then
        -- Local player's character parts have specific ownership patterns
        
        -- Check if it's a root part (often server-controlled)
        if part.Name == "HumanoidRootPart" then
            -- For root parts, use base detection but with higher threshold
            local ownership, confidence = baseDetector:DetectOwnership(part)
            
            -- Override HumanoidRootPart to be classified as server unless test is very confident
            if ownership == baseDetector.OWNERSHIP.CLIENT and confidence < 0.8 then
                return baseDetector.OWNERSHIP.SERVER, 0.7
            end
            
            return ownership, confidence
        end
        
        -- Check if it's a limb (often client-controlled)
        if part.Name:find("Arm") or part.Name:find("Leg") or part.Name:find("Hand") or part.Name:find("Foot") then
            -- Limbs are typically client-owned in many cases
            local baseOwnership, baseConfidence = baseDetector:DetectOwnership(part)
            
            -- Increase confidence for client ownership of limbs
            if baseOwnership == baseDetector.OWNERSHIP.CLIENT then
                return baseDetector.OWNERSHIP.CLIENT, math.min(1, baseConfidence + 0.15)
            end
            
            return baseOwnership, baseConfidence
        end
        
        -- For torso and head
        if part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Head" then
            -- These parts are more complex, so use detailed detection
            return baseDetector:DetectOwnership(part)
        end
        
        -- For other parts, use base detection
        return baseDetector:DetectOwnership(part)
    else
        -- Other players' character parts are always server-owned from our perspective
        return baseDetector.OWNERSHIP.SERVER, 1
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
    local baseInfo = baseDetector:GetDetailedOwnershipInfo(part)
    
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
        return ownership == baseDetector.OWNERSHIP.CLIENT and confidence > 0.7
    else
        -- For non-character parts, use the base detector with standard threshold
        return baseDetector:IsClientOwned(part, 0.6)
    end
end

-- Return the specialized detector
return CharacterOwnershipDetector
# Part Ownership Detector Documentation

Welcome to the Part Ownership Detector documentation. This suite of modules helps you detect whether parts in your Roblox game are owned by the client or server without using RemoteEvents.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Core Module (PartOwnershipDetector)](#core-module)
4. [Specialized Modules](#specialized-modules)
   - [High Performance Detector](#high-performance-detector)
   - [Character-Specific Detector](#character-specific-detector)
   - [Physics Tool Detector](#physics-tool-detector)
5. [Example Usage](#example-usage)
6. [API Reference](#api-reference)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Techniques](#advanced-techniques)

## Quick Start

```lua
-- Quick installation with loadstring
local PartOwnershipDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/PartOwnershipDetector.lua"))()

-- Check if a part is owned by the client
local part = workspace.SomePart
if PartOwnershipDetector:IsClientOwned(part) then
    print("This part is client-owned, I can modify it!")
end
```

## Installation

### Method 1: Loadstring

```lua
-- Core module
local PartOwnershipDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/PartOwnershipDetector.lua"))()

-- Specialized modules (if needed)
local HighPerformanceDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/HighPerformanceOwnershipDetector.lua"))()
local CharacterDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/CharacterSpecificOwnershipDetector.lua"))()
local PhysicsDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/PhysicsToolDetector.lua"))()
```

### Method 2: Module Scripts

1. Create ModuleScripts in ReplicatedStorage for each of the modules
2. Copy the module code into each ModuleScript
3. Require the modules in your LocalScripts:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartOwnershipDetector = require(ReplicatedStorage.PartOwnershipDetector)
```

## Core Module

The `PartOwnershipDetector` module is the foundation of the library. It provides multiple methods to detect part ownership and combines them for reliable results.

### Key Features

- Multiple detection methods using different properties and techniques
- Confidence-based ownership determination
- Detailed ownership information
- Simple boolean helper methods

### Main Methods

```lua
-- Basic detection with confidence level
local ownership, confidence = PartOwnershipDetector:DetectOwnership(part)
print("Part is owned by:", ownership, "with confidence:", confidence)

-- Simple boolean checks
if PartOwnershipDetector:IsClientOwned(part) then
    print("Client-owned part")
end

if PartOwnershipDetector:IsServerOwned(part) then
    print("Server-owned part")
end

-- Get detailed ownership information
local info = PartOwnershipDetector:GetDetailedOwnershipInfo(part)
```

## Specialized Modules

### High Performance Detector

Optimized for scenarios where you need to check many parts quickly with minimal performance impact.

```lua
local HighPerformanceDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/HighPerformanceOwnershipDetector.lua"))()

-- Fast check with caching
local ownership = HighPerformanceDetector:FastCheck(part)

-- Process multiple parts at once
local parts = workspace:GetDescendants()
local results = HighPerformanceDetector:BatchProcess(parts)

-- Get all client-owned parts in a region
local region = Region3.new(Vector3.new(0, 0, 0), Vector3.new(10, 10, 10))
local clientOwnedParts = HighPerformanceDetector:GetPartsWithOwnership(
    HighPerformanceDetector.OWNERSHIP.CLIENT,
    {region = region, maxParts = 100}
)
```

### Character-Specific Detector

Specialized for detecting ownership of character parts, which have unique ownership behaviors.

```lua
local CharacterDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/CharacterSpecificOwnershipDetector.lua"))()

-- Check if a part belongs to a character
local isCharacterPart, player = CharacterDetector:IsCharacterPart(part)

-- Get detailed ownership for a character part
local info = CharacterDetector:GetDetailedInfo(part)

-- Check if a part can be safely manipulated
if CharacterDetector:CanManipulateLocally(part) then
    -- Safe to modify this part
end
```

### Physics Tool Detector

Specialized for tools that need to apply physics to parts.

```lua
local PhysicsDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/PhysicsToolDetector.lua"))()

-- Check if physics can be safely applied
if PhysicsDetector:IsSafeForPhysics(part) then
    -- Safe to apply physics
end

-- Check if force can be applied to an assembly
local canApplyForce, affectedParts = PhysicsDetector:CanApplyForceToAssembly(part)

-- Safely apply force or impulse
PhysicsDetector:SafeApplyForce(part, Vector3.new(0, 100, 0))
PhysicsDetector:SafeApplyImpulse(part, Vector3.new(0, 10, 0))

-- Simulate physics without affecting the game
PhysicsDetector:SimulatePhysics(part, Vector3.new(0, 100, 0), 1, function(results)
    if results.success then
        print("Physics simulation complete")
        print("Displacement:", results.parts[1].displacement)
    end
end)
```

## Example Usage

### Basic Part Detection

```lua
local detector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/PartOwnershipDetector.lua"))()

local function checkPart(part)
    local ownership, confidence = detector:DetectOwnership(part)
    
    if ownership == detector.OWNERSHIP.CLIENT and confidence > 0.7 then
        -- This part is very likely client-owned
        part.Color = Color3.fromRGB(0, 255, 0) -- Change color to green
    elseif ownership == detector.OWNERSHIP.SERVER then
        -- This part is server-owned
        part.Color = Color3.fromRGB(255, 0, 0) -- Change color to red (will only work if actually client-owned)
    end
end

-- Check a specific part
local testPart = workspace.TestPart
checkPart(testPart)

-- Find all client-owned parts in workspace
for _, obj in pairs(workspace:GetDescendants()) do
    if obj:IsA("BasePart") and detector:IsClientOwned(obj) then
        print("Found client-owned part:", obj.Name)
    end
end
```

### Building Tool Example

```lua
local PhysicsDetector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/PhysicsToolDetector.lua"))()

local function onPartClicked(part)
    -- Check if we can apply physics
    if PhysicsDetector:IsSafeForPhysics(part) then
        -- Apply upward force
        part:ApplyImpulse(Vector3.new(0, 1000, 0))
        print("Applied force to part:", part.Name)
    else
        print("Cannot modify part:", part.Name, "- It is not client-owned")
        
        -- Preview how physics would affect the part
        PhysicsDetector:SimulatePhysics(part, Vector3.new(0, 1000, 0), 2, function(results)
            if results.success then
                print("Physics simulation complete")
                print("Part would move:", results.parts[1].displacement, "studs")
            else
                print("Simulation failed:", results.error)
            end
        end)
    end
end

-- Connect to mouse clicks
local UserInputService = game:GetService("UserInputService")
local mouse = game.Players.LocalPlayer:GetMouse()

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local part = mouse.Target
        if part and part:IsA("BasePart") then
            onPartClicked(part)
        end
    end
end)
```

## API Reference

### PartOwnershipDetector

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `DetectByNetworkOwnership(part)` | Detects ownership using NetworkOwnership property | part (BasePart) | OWNERSHIP value |
| `DetectByReceiveAge(part, threshold)` | Detects ownership using ReceiveAge property | part (BasePart), threshold (number, default: 0.1) | OWNERSHIP value |
| `DetectByPhysicsModification(part)` | Detects ownership by attempting physics change | part (BasePart) | OWNERSHIP value |
| `DetectByCFrameModification(part)` | Detects ownership by attempting CFrame change | part (BasePart) | OWNERSHIP value |
| `DetectByAnchorModification(part)` | Detects ownership by attempting Anchored change | part (BasePart) | OWNERSHIP value |
| `DetectByCollisionModification(part)` | Detects ownership by attempting CanCollide change | part (BasePart) | OWNERSHIP value |
| `DetectByPositionTracking(part, duration, callback)` | Detects ownership by tracking position changes | part (BasePart), duration (number), callback (function) | OWNERSHIP value or via callback |
| `DetectOwnership(part)` | Combines multiple methods for reliable detection | part (BasePart) | OWNERSHIP value, confidence (0-1) |
| `IsClientOwned(part, confidenceThreshold)` | Checks if part is client-owned | part (BasePart), confidenceThreshold (number, default: 0.6) | boolean |
| `IsServerOwned(part, confidenceThreshold)` | Checks if part is server-owned | part (BasePart), confidenceThreshold (number, default: 0.6) | boolean |
| `GetDetailedOwnershipInfo(part)` | Gets detailed ownership information | part (BasePart) | table with detailed results |

## Troubleshooting

### Common Issues

1. **Inconsistent Results**
   - Try increasing the confidence threshold
   - Use the `GetDetailedOwnershipInfo` method to see which detection methods are giving inconsistent results
   - Remember that network ownership can change during gameplay

2. **Performance Issues**
   - Use the HighPerformanceDetector for checking many parts
   - Implement caching to avoid redundant checks
   - Only check parts when needed, not every frame

3. **Detection Not Working for Character Parts**
   - Use the CharacterSpecificOwnershipDetector for character parts
   - Character parts have special ownership rules in Roblox

### Best Practices

1. Always check ownership before modifying parts
2. Cache results when appropriate
3. Use appropriate confidence thresholds for your use case
4. Combine multiple detection methods for better reliability

## Advanced Techniques

### Visualizing Part Ownership

```lua
local function visualizeParts()
    for _, part in pairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") then
            local ownership, confidence = PartOwnershipDetector:DetectOwnership(part)
            
            -- Create a highlight effect
            local highlight = Instance.new("Highlight")
            highlight.Parent = part
            
            if ownership == PartOwnershipDetector.OWNERSHIP.CLIENT then
                highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Green
            elseif ownership == PartOwnershipDetector.OWNERSHIP.SERVER then
                highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red
            else
                highlight.FillColor = Color3.fromRGB(255, 255, 0) -- Yellow
            end
            
            -- Set transparency based on confidence
            highlight.FillTransparency = 1 - confidence
        end
    end
end
```

### Implementing a Custom Detection Method

```lua
function CustomDetector:DetectByMass(part)
    local detector = loadstring(game:HttpGet("https://raw.githubusercontent.com/username/PartOwnershipDetector/main/PartOwnershipDetector.lua"))()
    
    if not part or not part:IsA("BasePart") then
        return detector.OWNERSHIP.UNKNOWN
    end
    
    -- Store original value
    local originalMass = part:GetMass()
    
    -- Try to modify the density slightly
    local success = pcall(function()
        -- Temporarily change density to affect mass
        local originalDensity = part.CustomPhysicalProperties and 
                               part.CustomPhysicalProperties.Density or 0.7
        
        part.CustomPhysicalProperties = PhysicalProperties.new(
            originalDensity + 0.001,
            0.3,
            0.5,
            100,
            100
        )
        
        -- Check if mass changed
        if part:GetMass() ~= originalMass then
            -- Revert changes
            part.CustomPhysicalProperties = PhysicalProperties.new(
                originalDensity,
                0.3,
                0.5,
                100,
                100
            )
            return true
        end
        return false
    end)
    
    if success then
        return detector.OWNERSHIP.CLIENT
    else
        return detector.OWNERSHIP.SERVER
    end
end
```

---

## Additional Resources

- [Roblox Network Ownership Documentation](https://developer.roblox.com/en-us/articles/network-ownership)
- [Understanding Client vs Server in Roblox](https://developer.roblox.com/en-us/articles/Roblox-Client-Server-Model)
- [Physics in Roblox](https://developer.roblox.com/en-us/articles/physics)

---

## License

This library is available for free use in any Roblox game. Credit is appreciated but not required.

---

## Contact and Support

If you have questions or need support, please reach out through GitHub issues or the provided contact information.

---

*Documentation generated for PartOwnershipDetector v1.0.0*

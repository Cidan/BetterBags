# Animations Module

This folder contains animation utilities for the BetterBags addon, providing smooth visual transitions for UI elements.

## Overview

The animations module provides reusable animation functions that can be attached to any UI region (frame) in the addon. These animations enhance the user experience by providing smooth transitions when UI elements appear, disappear, or change state.

## Files

### fade.lua

The main animation module that provides fade and slide animation capabilities.

#### Key Functions

- **`AttachFadeGroup(region, nohide)`**: Creates fade-in and fade-out animation groups for a UI element
  - `region`: The UI element to attach animations to
  - `nohide`: Optional boolean - if true, element is set to alpha 0 instead of hidden after fade-out
  - Returns: Two AnimationGroup objects (fadeInGroup, fadeOutGroup)

- **`AttachFadeAndSlideLeft(region, nohide)`**: Combines fade animation with a left slide motion
  - Slides the element 10 pixels to the right during fade-out
  - Uses the same parameters as AttachFadeGroup

- **`AttachFadeAndSlideTop(region, nohide)`**: Combines fade animation with an upward slide motion
  - Slides the element 10 pixels upward during fade-out
  - Uses the same parameters as AttachFadeGroup

## Animation Details

### Fade Animations
- **Duration**: 0.10 seconds for both fade-in and fade-out
- **Smoothing**: Uses 'IN' smoothing for smooth transitions
- **Alpha Range**: Transitions between 0 (transparent) and 1 (opaque)

### Slide Animations
- **Distance**: 10 pixels in the specified direction
- **Timing**: Synchronized with fade animations (0.10 seconds)

## Usage Example

```lua
local animations = addon:GetModule('Animations')
local myFrame = CreateFrame("Frame")

-- Attach basic fade animations
local fadeIn, fadeOut = animations:AttachFadeGroup(myFrame)

-- Play fade-in animation
fadeIn:Play()

-- Play fade-out animation
fadeOut:Play()

-- Attach fade with slide effect
local fadeInSlide, fadeOutSlide = animations:AttachFadeAndSlideLeft(myFrame)
```

## Callback Support

Both fadeInGroup and fadeOutGroup support optional callbacks that execute when animations complete:

```lua
fadeInGroup.callback = function()
    -- Code to run after fade-in completes
end

fadeOutGroup.callback = function()
    -- Code to run after fade-out completes
end
```

## Integration

This module is integrated as an AceModule within the BetterBags addon framework and can be accessed via:
```lua
local animations = addon:GetModule('Animations')
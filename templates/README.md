# BetterBags Templates Module

The templates module contains XML template definitions and Lua mixins that define reusable UI elements for the BetterBags addon. These templates ensure consistent styling and behavior across the interface.

## Table of Contents

- [Overview](#overview)
- [Core Templates](#core-templates)
  - [Container Templates](#container-templates-containerxml)
  - [Debug Templates](#debug-templates-debugxml)
- [Era-Specific Templates](#era-specific-templates)
  - [Era Container Templates](#era-container-templates-eracontainerxml)
  - [Scrolling Flat Panel](#scrolling-flat-panel-erascrollingflatpanellua)
- [Template Structure](#template-structure)
- [Usage](#usage)
- [Template Inheritance](#template-inheritance)
- [Best Practices](#best-practices)

## Overview

Templates in WoW addons are XML-defined UI structures that can be inherited and reused across multiple frames. BetterBags uses templates to maintain consistent UI elements while supporting different WoW client versions (Retail vs Classic Era).

## Core Templates

### Container Templates (`container.xml`)

Defines basic container and button templates used throughout the addon.

#### BetterBagsSearchPanelTemplate
- **Inherits:** `SimplePanelTemplate`
- **Purpose:** Base template for search panels
- **Usage:** Search interface panels

```xml
<Frame name="BetterBagsSearchPanelTemplate" inherits="SimplePanelTemplate" virtual="true">
</Frame>
```

#### BetterBagsPlainTextListButton
- **Purpose:** Simple text list button
- **Height:** 30 pixels
- **Usage:** Generic list items

```xml
<Button name="BetterBagsPlainTextListButton" virtual="true">
  <Size>
    <AbsDimension y="30"/>
  </Size>
</Button>
```

#### BetterBagsSecureBagTabTemplate
- **Inherits:** `PanelTabButtonTemplate`, `InsecureActionButtonTemplate`
- **Purpose:** Secure tab buttons for bag switching
- **Usage:** Bank tabs, bag tabs

```xml
<Button name="BetterBagsSecureBagTabTemplate" virtual="true" 
        inherits="PanelTabButtonTemplate,InsecureActionButtonTemplate">
</Button>
```

### Debug Templates (`debug.xml`)

Templates specifically for the debug interface.

#### BetterBagsDebugListButton
- **Purpose:** Debug log list item
- **Height:** 20 pixels
- **Components:**
  - `RowNumber`: Line number display
  - `Category`: Debug category
  - `Message`: Debug message text

```xml
<Button name="BetterBagsDebugListButton" virtual="true">
  <Size><AbsDimension y="20"/></Size>
  <Layers>
    <Layer level="OVERLAY">
      <FontString parentKey="RowNumber" inherits="GameFontHighlightLarge">
        <!-- Row number: 50px wide -->
      </FontString>
      <FontString parentKey="Category" inherits="GameFontNormalLarge">
        <!-- Category: 120px wide -->
      </FontString>
      <FontString parentKey="Message" inherits="GameFontNormalLarge">
        <!-- Message: variable width -->
      </FontString>
    </Layer>
  </Layers>
</Button>
```

#### BetterBagsItemBrowserButton
- **Purpose:** Item browser list entry
- **Height:** 20 pixels
- **Components:**
  - `Title`: Item/category title

```xml
<Button name="BetterBagsItemBrowserButton" virtual="true">
  <Size><AbsDimension y="20"/></Size>
  <Layers>
    <Layer level="OVERLAY">
      <FontString parentKey="Title" inherits="GameFontHighlightLarge">
        <!-- Title: 200px wide -->
      </FontString>
    </Layer>
  </Layers>
</Button>
```

## Era-Specific Templates

### Era Container Templates (`era/container.xml`)

Classic Era versions require different templates due to UI differences.

#### BetterBagsBagDefaultPanelTemplate
- **Inherits:** `DefaultPanelTemplate`
- **Purpose:** Main bag panel for Classic Era
- **Components:**
  - `CloseButton`: Standard close button
  - `Backdrop`: Background frame

```xml
<Frame name="BetterBagsBagDefaultPanelTemplate" inherits="DefaultPanelTemplate" virtual="true">
  <Frames>
    <Button name="$parentCloseButton" parentKey="CloseButton" 
            inherits="UIPanelCloseButtonDefaultAnchors"/>
    <Frame name="$parentBackdrop" parentKey="Backdrop" 
           inherits="BackdropTemplate" mixin="BackdropTemplateMixin" 
           frameStrata="BACKGROUND" setAllPoints="true"/>
  </Frames>
</Frame>
```

#### BetterBagsBagSlotPanelTemplate
- **Inherits:** `ButtonFrameTemplate`
- **Purpose:** Bag slot panel for Classic Era
- **Usage:** Container for bag slot buttons

#### Era BetterBagsSearchPanelTemplate
- **Inherits:** `InsetFrameTemplate`
- **Purpose:** Search panel with Classic Era styling
- **Features:** Full border decoration with corners and edges

The Era search panel includes extensive border textures:
- Top, bottom, left, right borders
- Corner pieces for all four corners
- Proper Classic Era visual style

### Scrolling Flat Panel (`era/ScrollingFlatPanel.lua`)

A Lua mixin providing scrolling panel functionality for Classic Era.

**Key Features:**
- Animated open/close transitions
- Dynamic height calculation
- Scrollbar management
- Maximum height constraints

**Core Methods:**

```lua
ScrollingFlatPanelMixin = {}

-- Initialize the panel
function ScrollingFlatPanelMixin:OnLoad()
  self:SetTitle(self.panelTitle)
  -- Setup animations and callbacks
end

-- Open the panel with animation
function ScrollingFlatPanelMixin:Open(skipShow)
  self.isOpen = true
  if not skipShow then
    self:Show()
  end
  self:Resize()
  self:PlayOpenAnimation()
end

-- Dynamically resize based on content
function ScrollingFlatPanelMixin:Resize()
  local height = self:CalculateElementsHeight() + anchors + extra
  self:SetHeight(math.min(height, self.panelMaxHeight))
  
  local showScrollBar = self.ScrollBox:HasScrollableExtent()
  self:SetWidth(self.panelWidth + (showScrollBar and ScrollBarWidth or 0))
end

-- Close with animation
function ScrollingFlatPanelMixin:Close()
  self.isOpen = false
  self:PlayCloseAnimation()
end
```

**Required Implementation:**
```lua
-- Must be implemented by inheriting classes
function ScrollingFlatPanelMixin:CalculateElementsHeight()
  error("Requires implementation")
end
```

## Template Structure

### XML Template Anatomy

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
  <!-- Template definition -->
  <Frame/Button name="TemplateName" virtual="true" inherits="ParentTemplate">
    <!-- Size definition -->
    <Size>
      <AbsDimension x="width" y="height"/>
    </Size>
    
    <!-- Visual layers -->
    <Layers>
      <Layer level="BACKGROUND/BORDER/ARTWORK/OVERLAY">
        <!-- Textures and FontStrings -->
      </Layer>
    </Layers>
    
    <!-- Child frames -->
    <Frames>
      <!-- Nested frames and buttons -->
    </Frames>
    
    <!-- Scripts (if needed) -->
    <Scripts>
      <OnLoad><!-- Lua code --></OnLoad>
    </Scripts>
  </Frame/Button>
</Ui>
```

### Key Attributes

- **`virtual="true"`**: Makes the template non-instantiated (blueprint only)
- **`inherits="..."`**: Inherits properties from parent templates
- **`parentKey="..."`**: Creates a reference on the parent frame
- **`name="$parent..."`**: Uses parent's name as prefix

## Usage

### Creating Frames from Templates

```lua
-- In Lua code
local frame = CreateFrame("Frame", "MyFrame", parent, "BetterBagsSearchPanelTemplate")

-- For buttons
local button = CreateFrame("Button", "MyButton", parent, "BetterBagsPlainTextListButton")
```

### Accessing Template Elements

```lua
-- Access parentKey elements
local closeButton = frame.CloseButton
local backdrop = frame.Backdrop

-- Access named children
local rowNumber = button.RowNumber
local message = button.Message
```

### Extending Templates

```xml
<!-- Create a new template based on existing one -->
<Frame name="MyCustomTemplate" inherits="BetterBagsSearchPanelTemplate" virtual="true">
  <!-- Add custom elements -->
  <Frames>
    <Button name="$parentCustomButton" parentKey="CustomButton">
      <!-- Custom button definition -->
    </Button>
  </Frames>
</Frame>
```

## Template Inheritance

### Inheritance Chain Example

```
Blizzard Templates
    ↓
SimplePanelTemplate
    ↓
BetterBagsSearchPanelTemplate (Retail)

InsetFrameTemplate
    ↓
BetterBagsSearchPanelTemplate (Era)
```

### Multiple Inheritance

Templates can inherit from multiple parents:
```xml
<Button inherits="PanelTabButtonTemplate,InsecureActionButtonTemplate">
```

## Best Practices

### 1. Template Naming
- Use descriptive names with addon prefix
- Include purpose in name (e.g., `BetterBagsDebugListButton`)
- Keep virtual templates clearly marked

### 2. Size Management
- Define sizes at template level when consistent
- Allow runtime overrides for dynamic content
- Use relative sizing where appropriate

### 3. Parent Keys
- Always use `parentKey` for important child elements
- Provides clean access from Lua code
- Avoids global namespace pollution

### 4. Version Compatibility
- Maintain separate templates for different WoW versions
- Use era/ subfolder for Classic-specific templates
- Test templates across all supported versions

### 5. Performance
- Keep templates lightweight
- Avoid complex scripts in templates
- Use mixins for shared behavior

### 6. Documentation
- Comment complex template structures
- Document required parentKey elements
- Note any special usage requirements

## Integration with Other Modules

Templates work closely with:
- **Frames Module**: Uses templates to create UI elements
- **Themes Module**: Applies styling to templated elements
- **Forms Module**: Uses templates for form controls
- **Debug Module**: Uses debug templates for display

## Common Issues and Solutions

### Template Not Found
```lua
-- Error: Unable to find template
-- Solution: Ensure XML is loaded in .toc file
```

### Missing Parent Keys
```lua
-- Error: attempt to index field 'CloseButton' (a nil value)
-- Solution: Check template has parentKey defined
```

### Inheritance Conflicts
```xml
<!-- Problem: Multiple templates define same element -->
<!-- Solution: Use explicit overrides or different parent keys -->
```

## Version Differences

### Retail vs Classic Era

| Feature | Retail | Classic Era |
|---------|--------|-------------|
| Base Templates | SimplePanelTemplate | InsetFrameTemplate |
| Border Style | Minimal | Full decoration |
| Backdrop | Simple | Complex with corners |
| Animation | Built-in | Custom implementation |
| Scrolling | Native ScrollBox | ScrollingFlatPanelMixin |

## Template Loading Order

Templates must be loaded before use:
1. XML files listed in `.toc` or loaded via includes
2. Parent templates must load before children
3. Version-specific templates load based on client

## Debugging Templates

```lua
-- Check if template exists
if _G["BetterBagsSearchPanelTemplate"] then
  print("Template loaded")
end

-- Inspect template structure
DevTools_Dump(frame:GetChildren())
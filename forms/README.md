# Forms Module

The Forms module provides a comprehensive form-building system for creating complex UI forms with various input widgets, layouts, and styling options. It supports scrollable forms, multiple layout types, and a rich set of form controls.

## Overview

The Forms module offers:
- Dynamic form creation with scrollable content
- Multiple layout systems (stacked, two-column)
- Rich widget library (checkboxes, sliders, dropdowns, etc.)
- Automatic value binding and persistence
- Cross-version compatibility (Retail and Classic)
- Theme integration
- Index navigation for long forms

## Core Components

### Form Manager (`form.lua`)

The main form creation and management system.

#### Features
- **Scrollable Forms**: Built-in scroll support with smooth scrolling
- **Movable Windows**: Forms can be dragged around the screen
- **Fade Animations**: Smooth fade in/out transitions
- **Layout System**: Pluggable layout support
- **Auto-resize**: Forms automatically resize based on content

#### Creating a Form
```lua
local form = addon:GetModule('Form')

-- Create a new form
local myForm = form:Create({
  title = "Settings",
  layout = const.FORM_LAYOUT.STACKED,
  index = true  -- Enable index navigation
})

-- Add sections and widgets
myForm:AddSection({
  title = "General Settings",
  description = "Configure general addon behavior"
})

-- Show the form
myForm:Show()
```

### Layout System (`layouts/layout.lua`)

Defines the base layout interface and widget types.

#### Widget Types

##### Section
```lua
---@class FormSectionOptions
---@field title string
---@field description string
```

##### Checkbox
```lua
---@class FormCheckboxOptions
---@field title string
---@field description string
---@field getValue fun(ctx: Context): boolean
---@field setValue fun(ctx: Context, value: boolean)
```

##### Dropdown
```lua
---@class FormDropdownOptions
---@field title string
---@field description string
---@field items? string[]
---@field itemsFunction? fun(ctx: Context): string[]
---@field getValue fun(ctx: Context, value: string): boolean
---@field setValue fun(ctx: Context, value: string)
```

##### Slider
```lua
---@class FormSliderOptions
---@field title string
---@field description string
---@field min number
---@field max number
---@field step number
---@field getValue fun(ctx: Context): number
---@field setValue fun(ctx: Context, value: number)
```

##### Text Area
```lua
---@class FormTextAreaOptions
---@field title string
---@field description string
---@field getValue fun(ctx: Context): string
---@field setValue fun(ctx: Context, value: string)
```

##### Input Box
```lua
---@class FormInputBoxOptions
---@field title string
---@field description string
---@field getValue fun(ctx: Context): string
---@field setValue fun(ctx: Context, value: string)
```

##### Color Picker
```lua
---@class FormColorOptions
---@field title string
---@field description string
---@field getValue fun(ctx: Context): Colors
---@field setValue fun(ctx: Context, value: Colors)
```

##### Button Group
```lua
---@class FormButtonGroupOptions
---@field ButtonOptions FormButtonOption[]

---@class FormButtonOption
---@field title string
---@field onClick fun(ctx: Context)
```

##### Label
```lua
---@class FormLabelOptions
---@field description string
```

### Stacked Layout (`layouts/stacked.lua`)

A vertical stacking layout with optional index navigation.

#### Features
- **Index Navigation**: Jump to sections via clickable index
- **Auto-scroll**: Scroll to sections when clicked
- **Underline Tracking**: Visual indicator of current section
- **Cross-version Support**: Different implementations for Retail and Classic
- **Responsive**: Adjusts to content width

#### Layout Structure
```
┌─────────────────────────────────┐
│ [Index]  │  Form Content        │
│ ─────────│                      │
│ Section 1│  ┌─────────────────┐ │
│ Section 2│  │ Section Title   │ │
│ Section 3│  │ Description     │ │
│          │  │ ───────────     │ │
│          │  │ [Widget]         │ │
│          │  │ [Widget]         │ │
│          │  └─────────────────┘ │
└─────────────────────────────────┘
```

## Usage Examples

### Complete Form Example
```lua
local form = addon:GetModule('Form')
local db = addon:GetModule('Database')

-- Create form
local settingsForm = form:Create({
  title = "BetterBags Settings",
  layout = const.FORM_LAYOUT.STACKED,
  index = true
})

-- Add main section
settingsForm:AddSection({
  title = "Display Options",
  description = "Configure how items are displayed"
})

-- Add checkbox
settingsForm:AddCheckbox({
  title = "Show Item Level",
  description = "Display item level on equipment",
  getValue = function(ctx)
    return db:GetShowItemLevel()
  end,
  setValue = function(ctx, value)
    db:SetShowItemLevel(value)
  end
})

-- Add slider
settingsForm:AddSlider({
  title = "Icon Size",
  description = "Size of item icons",
  min = 20,
  max = 60,
  step = 1,
  getValue = function(ctx)
    return db:GetIconSize()
  end,
  setValue = function(ctx, value)
    db:SetIconSize(value)
  end
})

-- Add dropdown
settingsForm:AddDropdown({
  title = "Sort Method",
  description = "How to sort items",
  items = {"Type", "Quality", "Name", "Item Level"},
  getValue = function(ctx, value)
    return db:GetSortMethod() == value
  end,
  setValue = function(ctx, value)
    db:SetSortMethod(value)
  end
})

-- Show form
settingsForm:Show()
```

### Dynamic Content
```lua
-- Dropdown with dynamic items
form:AddDropdown({
  title = "Active Profile",
  description = "Select configuration profile",
  itemsFunction = function(ctx)
    return db:GetAllProfiles()
  end,
  getValue = function(ctx, value)
    return db:GetCurrentProfile() == value
  end,
  setValue = function(ctx, value)
    db:SetCurrentProfile(value)
  end
})
```

### Color Configuration
```lua
form:AddColor({
  title = "Section Color",
  description = "Color for section headers",
  getValue = function(ctx)
    local r, g, b, a = db:GetSectionColor()
    return {
      red = r,
      green = g,
      blue = b,
      alpha = a
    }
  end,
  setValue = function(ctx, color)
    db:SetSectionColor(color.red, color.green, color.blue, color.alpha)
  end
})
```

### Text Input
```lua
-- Multi-line text area
form:AddTextArea({
  title = "Custom Categories",
  description = "Enter custom category names (one per line)",
  getValue = function(ctx)
    return table.concat(db:GetCustomCategories(), "\n")
  end,
  setValue = function(ctx, value)
    local categories = {}
    for line in value:gmatch("[^\n]+") do
      table.insert(categories, line)
    end
    db:SetCustomCategories(categories)
  end
})

-- Single-line input
form:AddInputBox({
  title = "Search Filter",
  description = "Default search filter",
  getValue = function(ctx)
    return db:GetDefaultSearch()
  end,
  setValue = function(ctx, value)
    db:SetDefaultSearch(value)
  end
})
```

### Button Actions
```lua
form:AddButtonGroup({
  ButtonOptions = {
    {
      title = "Reset to Defaults",
      onClick = function(ctx)
        db:ResetToDefaults()
        form:ReloadAllFormElements()
      end
    },
    {
      title = "Export Settings",
      onClick = function(ctx)
        local exported = db:ExportSettings()
        -- Show export dialog
      end
    },
    {
      title = "Import Settings",
      onClick = function(ctx)
        -- Show import dialog
      end
    }
  }
})
```

## Form Methods

### Core Methods
```lua
-- Create a form
form:Create(opts: FormCreateOptions): FormFrame

-- Add widgets
formFrame:AddSection(opts: FormSectionOptions)
formFrame:AddSubSection(opts: FormSubSectionOptions)
formFrame:AddCheckbox(opts: FormCheckboxOptions)
formFrame:AddDropdown(opts: FormDropdownOptions)
formFrame:AddSlider(opts: FormSliderOptions)
formFrame:AddInputBox(opts: FormInputBoxOptions)
formFrame:AddTextArea(opts: FormTextAreaOptions)
formFrame:AddButtonGroup(opts: FormButtonGroupOptions)
formFrame:AddColor(opts: FormColorOptions)
formFrame:AddLabel(opts: FormLabelOptions)

-- Control form
formFrame:Show()
formFrame:Hide()
formFrame:ReloadAllFormElements()
formFrame:Resize()
formFrame:GetFrame(): Frame
```

## Layout Features

### Index Navigation
When enabled, provides a clickable index of all sections:
- Click section names to jump directly
- Underline indicates current viewport position
- Updates as user scrolls

### Auto-Scrolling
- Smooth scroll animations
- Pan extent for overscroll
- Interpolated scrolling for smoothness

### Responsive Design
- Forms adjust to content width
- Scrollbar appears only when needed
- Proper spacing and indentation

## Styling

### Theme Integration
Forms automatically use the addon's theme system:
```lua
themes:RegisterSimpleWindow(frame, title)
```

### Custom Styling
Widget appearance can be customized:
- Title and description colors
- Font sizes and styles
- Divider lines and spacing
- Background textures

## Cross-Version Compatibility

### Retail vs Classic
The form system handles differences between WoW versions:

#### Dropdowns
- **Retail**: Uses `WowStyle1DropdownTemplate`
- **Classic**: Uses `UIDropDownMenuTemplate`

#### Sliders
- **Retail**: Uses `UISliderTemplate`
- **Classic**: Uses `HorizontalSliderTemplate`

#### Scrolling
- **Retail**: Native `ScrollToOffset`
- **Classic**: Custom scroll percentage calculation

## Best Practices

### 1. Use Context
Always create proper context for callbacks:
```lua
getValue = function(ctx)
  -- Use ctx for tracking
  return database:GetValue()
end
```

### 2. Validate Input
Validate user input in setValue callbacks:
```lua
setValue = function(ctx, value)
  if type(value) == "number" and value >= 0 then
    database:SetValue(value)
  end
end
```

### 3. Reload on Change
Reload form elements when interdependent values change:
```lua
setValue = function(ctx, value)
  database:SetValue(value)
  formFrame:ReloadAllFormElements()
end
```

### 4. Group Related Settings
Use sections and subsections to organize:
```lua
form:AddSection({title = "General"})
-- General settings

form:AddSubSection({title = "Advanced"})
-- Advanced settings
```

### 5. Provide Clear Descriptions
Help users understand settings:
```lua
{
  title = "Compact Mode",
  description = "Reduces spacing between items for a more compact display. Useful for users with many items."
}
```

## Performance Considerations

- Forms are created once and reused
- Widget values are cached
- Scroll events are optimized
- Only visible widgets are rendered
- Animations use efficient fade groups

## Limitations

- Two-column layout not yet implemented
- Maximum form height limited by screen size
- Color picker uses global ColorPickerFrame
- Text areas have character limits

## Debugging

Enable debug mode to inspect form behavior:
```lua
debug:DrawBorder(formFrame.frame, 1, 0, 0)  -- Red border
```

## Future Enhancements

- Two-column layout implementation
- Tab-based forms
- Conditional widget visibility
- Form validation framework
- Export/import form states
- Keyboard navigation support
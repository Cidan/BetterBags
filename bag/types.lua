---@meta

---@class (exact) Bag
---@field window Window
---@field GetFrame fun(): Frame
---@field SetDecoration fun(self: Bag, b?: SonataBag)
---@field Hide fun(self: Bag, doNotAnimate?: boolean)
---@field Show fun(self: Bag, doNotAnimate?: boolean)
---@field GetTitle fun(): string
---@field GetWindow fun(): Window
---@field GetName fun(): string

---@class (exact) BagDataConfig
---@field BagNameAsSections boolean
---@field ShowEmptySlots boolean
---@field CombineAllItems boolean
---@field StackSimilarItems boolean
---@field ItemSortFunction fun(a: MoonlightItemButton, b: MoonlightItemButton): boolean
---@field SectionSetConfig? SectionsetConfig
---@field BagFilter? table<BagID, boolean> -- Optional filter specifying which bags this view should display
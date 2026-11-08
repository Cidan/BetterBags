local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class NextMenu: AceModule
local nextMenu = addon:GetModule('NextMenu')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

-- NextCategoryPicker is what an item dropped on a BetterBags Next bag's title opens (or, in a theme that says so, on its
-- bag button: Header.ItemDrop), to put the item in a category or in a new one without the settings (issue #1270; asked:
-- "drag an item to the bag name (or in the case of Plain, the bag button ...) to have a (pretty) popup appear that lets
-- you put an item in an existing category, or into a new category ... i don't just want to open the config screen"). It
-- is a NextMenu with a field (next-controls.md §2), under what the item was dropped on: headed by the item (its icon in
-- its quality's edge, its name, where it shows now), every category in their order (the one it shows in checked, a
-- plugin's not to be picked, each with how many of your items it holds), a new category named what is typed when no
-- category has that name, and, while nothing is typed, a way back to where the item belongs when it was added to a
-- category by hand. A category picked files the item as dropping it on that category's header does
-- (Categories:FileItem, docs/next-batch-2.md §8); a new one is made empty and saved first.
---@class NextCategoryPicker: AceModule
---@field item? NextHeldItem The item the picker shown is for.
---@field home? string The category the item was added to by hand, when it was.
---@field counts table<string, number> How many of the bags' items each category holds, counted as it opened.
local picker = addon:NewModule('NextCategoryPicker')

---@class (exact) NextHeldItem
---@field itemID number
---@field link? string Its link, as the cursor gave it.
---@field data? ItemData What the bags hold of it: its bag slot's, else an item of its ID; none for one they do not hold.
---@field natural? string Where it lands without the category it was added to by hand (Items:NaturalCategory).

picker.counts = {}

-- A category's dot without a color of its own: the settings list's.
local GOLD = { 1, 0.82, 0 }

-- isShownIn says whether a section name is a category's own or one of its group by's.
---@param name string
---@param section string
---@return boolean
local function isShownIn(name, section)
  return section == name or section:sub(1, #name + 3) == name .. " - "
end

---@param n number
---@return string
local function count(n)
  return format(n == 1 and L:G("%d item") or L:G("%d items"), n)
end

-- countItems counts the items in the backpack and the bank each category holds, as the settings list does: each item
-- once, its group by's sections with it (an item in "Potions - Flask" counts for Potions).
---@return table<string, number>
local function countItems()
  local seen, counts = {}, {}
  local slots = items:GetAllSlotInfo()
  for _, kind in ipairs({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK }) do
    local info = slots[kind]
    for _, data in pairs(info and info.itemsBySlotKey or {}) do
      if not data.isItemEmpty and data.itemInfo then
        local id, name = data.itemInfo.itemID, data.itemInfo.category
        while name ~= nil and name ~= "" do
          seen[name] = seen[name] or {}
          if not seen[name][id] then
            seen[name][id] = true
            counts[name] = (counts[name] or 0) + 1
          end
          name = name:match("^(.*) %- ")
        end
      end
    end
  end
  return counts
end

-- head says what the picker is for: the item's icon (the bags', else its ID's) in its quality's edge (Uncommon and up,
-- as an item grid draws it), its link without the brackets, and the section it shows in.
---@param item NextHeldItem
---@return NextMenuHead
local function head(item)
  local info = item.data and item.data.itemInfo
  local icon = info and info.itemIcon or select(5, C_Item.GetItemInfoInstant(item.itemID))
  local quality = info and info.itemQuality
  local color = quality ~= nil and quality >= 2 and const.ITEM_QUALITY_COLOR[quality] or nil
  local text = item.link and (item.link:gsub("|h%[(.-)%]|h", "|h%1|h")) or tostring(item.itemID)
  local where = info and info.category
  return {
    icon = icon,
    edge = color and { color[1], color[2], color[3] } or nil,
    text = text,
    note = where ~= nil and where ~= "" and format(L:G("In %s"), where) or nil,
  }
end

-- Choices lists what the picker offers for what is typed (spaces round it are nothing): while nothing is, the way
-- back to where the item belongs (when it was added to a category by hand and would land elsewhere) and every category
-- in their order; else the categories whose name has the text, and a new category of that name first unless one has it
-- (in any case) or the name is taken. Enter takes the first category that matches, else the new one; nothing while
-- nothing is typed.
---@param text string
---@return NextMenuItem[] list, number? lit
function picker:Choices(text)
  local typed = strtrim(text or "")
  local needle = typed:lower()
  local item = self.item
  local info = item and item.data and item.data.itemInfo
  local current = info and info.category
  local P = style.Theme.Controls.Menu.Picker
  local list, exact, first = {}, false, nil
  if needle == "" and self.home ~= nil and item.natural ~= nil and not isShownIn(self.home, item.natural) then
    table.insert(list, { text = format(L:G("Back to %s"), item.natural), value = { back = self.home }, glyph = P.BackIcon })
  end
  for _, name in ipairs(categories:GetOrder()) do
    local lower = name:lower()
    if needle == "" or lower:find(needle, 1, true) then
      exact = exact or lower == needle
      local filter = categories:GetCategoryByName(name)
      local plugin = filter ~= nil and filter.save ~= true
      local n = self.counts[name] or 0
      table.insert(list, {
        text = name,
        value = { name = name },
        color = filter and filter.color or GOLD,
        selected = (current ~= nil and isShownIn(name, current)) or nil,
        disabled = plugin or nil,
        note = (plugin and L:G("Made by a plugin")) or (n > 0 and count(n)) or nil,
      })
      if first == nil and not plugin then
        first = #list
      end
    end
  end
  if needle == "" then
    return list, nil
  end
  -- A name taken by what GetOrder does not list (a group by's section) is refused too, as the settings refuse it.
  if not exact and not categories:DoesCategoryExist(typed) then
    table.insert(list, 1, { text = format(L:G('New category "%s"'), typed), value = { create = typed }, glyph = P.NewIcon })
    first = first and first + 1 or 1
  end
  return list, first
end

-- Open opens the picker under anchor for the item the panel took off the cursor (NextPanel:PickCategory).
---@param ctx Context
---@param anchor Frame
---@param item NextHeldItem
function picker:Open(ctx, anchor, item)
  local _ = ctx
  self.item = item
  self.home = database:GetItemCategoryByItemID(item.itemID).name
  self.counts = countItems()
  nextMenu:Open(anchor, {
    head = head(item),
    filter = { help = L:G("Find or name a category"), items = function(text) return self:Choices(text) end },
    onPick = function(c, choice) self:Pick(c, item, choice.value) end,
  })
end

-- Pick does what the player picked for the item: back to where it belongs (its category by hand forgotten), into a new
-- category (made empty and saved, then filed in it), or into a category; then the bags are recalculated, as every
-- category change does (refresh-scheduler.md §10).
---@param ctx Context
---@param item NextHeldItem
---@param choice { back?: string, create?: string, name?: string }
function picker:Pick(ctx, item, choice)
  if choice.back ~= nil then
    categories:RemoveItemFromCategory(item.itemID, choice.back)
  elseif choice.create ~= nil then
    categories:CreateCategory(ctx, { name = choice.create, itemList = {}, save = true })
    categories:FileItem(ctx, item.itemID, choice.create, item.natural)
  else
    categories:FileItem(ctx, item.itemID, choice.name, item.natural)
  end
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
end

-- Hint says what dropping the item held on owner does, in its tooltip at point.
---@param owner Frame
---@param point TooltipAnchor
function picker:Hint(owner, point)
  GameTooltip:SetOwner(owner, point)
  GameTooltip:SetText(L:G("Add to a Category"))
  GameTooltip:AddLine(L:G("Drop the item here to put it in a category, or in a new one."), 1, 1, 1, true)
  GameTooltip:Show()
end

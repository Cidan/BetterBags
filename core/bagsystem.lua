local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class BagFrame: AceModule
local bagFrame = addon:GetModule('BagFrame')

---@class NextBag: AceModule
local nextBag = addon:GetModule('NextBag')

---@class NextBank: AceModule
local nextBank = addon:GetModule('NextBank')

---@class NextVendor: AceModule
local nextVendor = addon:GetModule('NextVendor')

---@class NextGuildBank: AceModule
local nextGuildBank = addon:GetModule('NextGuildBank')

---@class ConsolePort: AceModule
local consoleport = addon:GetModule('ConsolePort')

-- BagSystem makes BetterBags' bags in one of its two designs, the classic bags or BetterBags Next,
-- and switches between them without a reload (next.md §11). Each design is made once, the first
-- time it is used, in an event scope of its own (events:InScope), so everything it registers can be
-- unhooked: the design not in use costs nothing. Switching hides the design in use, lets go of its
-- buttons and switches its scope off; then it makes the other design, or switches its scope back on
-- and lets it catch up (Activate), and draws what was last read into it.
---@class BagSystem: AceModule
---@field sets table<BagDesign, BagSystemSet>
---@field active? BagDesign
local bagSystem = addon:NewModule('BagSystem')

---@alias BagDesign "classic"|"next"

---@class (exact) BagSystemSet
---@field design BagDesign
---@field scope EventScope
---@field backpack? table
---@field bank? table
---@field vendor? NextVendorPanel
---@field guild? NextGuildBankPanel BetterBags Next's guild bank, on a client with a guild bank.

function bagSystem:Init()
  self.sets = {}
  self.active = nil
end

-- SavedDesign is the design the setting names.
---@return BagDesign
function bagSystem:SavedDesign()
  return database:GetNextEnabled() and "next" or "classic"
end

-- ActiveDesign is the design in use.
---@return BagDesign?
function bagSystem:ActiveDesign()
  return self.active
end

---@private
---@param design BagDesign
---@return BagSystemSet
function bagSystem:set(design)
  local s = self.sets[design]
  if s == nil then
    s = { design = design, scope = events:NewScope(design) }
    self.sets[design] = s
  end
  return s
end

-- CreateBackpack makes a design's backpack, everything it registers in the design's scope.
---@param ctx Context
---@param design BagDesign
---@return table
function bagSystem:CreateBackpack(ctx, design)
  local s = self:set(design)
  events:InScope(s.scope, function()
    if design == "next" then
      s.backpack = nextBag:Create(ctx)
    else
      s.backpack = bagFrame:Create(ctx, const.BAG_KIND.BACKPACK)
    end
  end)
  return s.backpack
end

-- CreateRest makes the rest of a design in its scope: its bank, with Enable Bank Bags, and for
-- BetterBags Next the vendor, which takes over Blizzard's merchant frame, and on a client with a guild
-- bank the guild bank, which takes over Blizzard's guild bank frame (guild-bank.md §5).
---@param ctx Context
---@param design BagDesign
function bagSystem:CreateRest(ctx, design)
  local s = self:set(design)
  events:InScope(s.scope, function()
    if database:GetEnableBankBag() then
      if design == "next" then
        s.bank = nextBank:Create(ctx)
      else
        s.bank = bagFrame:Create(ctx, const.BAG_KIND.BANK)
      end
    end
    if design == "next" then
      s.vendor = nextVendor:Create(ctx)
      if addon.hasGuildBank then
        s.guild = nextGuildBank:Create(ctx)
      end
    end
  end)
  if design == "next" then
    self:takeOver(s)
  end
end

-- takeOver has BetterBags Next's panels stand in for Blizzard's merchant and guild bank frames.
---@private
---@param s BagSystemSet
function bagSystem:takeOver(s)
  nextVendor:TakeOver(_G.BetterBagsSneakyFrame)
  if s.guild then
    nextGuildBank:TakeOver(_G.BetterBagsSneakyFrame)
  end
end

-- giveBack gives Blizzard's merchant and guild bank frames back when BetterBags Next is switched off.
---@private
---@param s BagSystemSet
function bagSystem:giveBack(s)
  nextVendor:GiveBack()
  if s.guild then
    nextGuildBank:GiveBack()
  end
end

-- others are a design's bags beside its backpack, in the order they are made.
---@param s BagSystemSet
---@return table[]
local function others(s)
  local list = {}
  for _, bag in ipairs({ s.bank or false, s.vendor or false, s.guild or false }) do
    if bag then
      table.insert(list, bag)
    end
  end
  return list
end

-- Use makes a design's bags the addon's.
---@param design BagDesign
function bagSystem:Use(design)
  local s = self.sets[design]
  self.active = design
  addon.Bags.Backpack = s.backpack
  addon.Bags.Bank = s.bank
  addon.Bags.GuildBank = s.guild
  addon.Vendor = s.vendor
  -- A Next theme styles the item buttons only while BetterBags Next is in use (next-themes.md).
  addon:GetModule('SonataNext'):SetActive(design == "next")
end

-- Finish titles a design's backpack and lets Escape close its windows.
---@param design BagDesign
function bagSystem:Finish(design)
  local s = self.sets[design]
  s.backpack:SetTitle(L:G("Backpack"))
  table.insert(UISpecialFrames, s.backpack:GetName())
  for _, bag in ipairs(others(s)) do
    table.insert(UISpecialFrames, bag:GetName())
  end
end

-- refuse says why the bags cannot be switched now.
---@param message string
---@return boolean
local function refuse(message)
  UIErrorsFrame:AddMessage(message, 1.0, 0.1, 0.1, 1.0)
  return false
end

---@param bag? table
---@return string?
local function searchText(bag)
  return bag and bag.searchBox and bag.searchBox.textBox:GetText() or nil
end

-- Switch puts a design's bags in place of the ones in use, and saves the choice. It refuses in
-- combat (making the classic bags makes secure tab buttons), at the bank, at a vendor and at the
-- guild bank (their frames would have to change hands open: a shown merchant frame reparented to a
-- visible parent runs Blizzard's OnShow from our code). It returns whether the design is in use now.
---@param ctx Context
---@param design BagDesign
---@return boolean
function bagSystem:Switch(ctx, design)
  if design == self.active then
    return true
  end
  if InCombatLockdown() then
    return refuse(L:G("You can't switch bags in combat."))
  end
  if addon.atBank then
    return refuse(L:G("Close the bank to switch bags."))
  end
  if (MerchantFrame and MerchantFrame:IsShown()) or (addon.Vendor and addon.Vendor.atMerchant) then
    return refuse(L:G("Close the vendor to switch bags."))
  end
  if addon.atGuildBank then
    return refuse(L:G("Close the guild bank to switch bags."))
  end

  local old = self.sets[self.active]
  local wasOpen = old.backpack:IsShown() and not old.backpack:IsClosing()
  local backpackSearch, bankSearch = searchText(old.backpack), searchText(old.bank)
  old.backpack:Deactivate(ctx)
  for _, bag in ipairs(others(old)) do
    bag:Deactivate(ctx)
  end
  old.scope:Disable()
  if old.design == "next" then
    self:giveBack(old)
  end

  local new = self.sets[design]
  if new == nil then
    self:CreateBackpack(ctx, design)
    self:CreateRest(ctx, design)
    new = self.sets[design]
    self:Finish(design)
    addon:WatchBackpackFrame(new.backpack.frame)
    consoleport:Add(new.backpack.frame)
    if new.bank then
      consoleport:Add(new.bank.frame)
    end
    if new.guild then
      consoleport:Add(new.guild.frame)
    end
  else
    new.scope:Enable()
    if design == "next" then
      self:takeOver(new)
    end
    new.backpack:Activate(ctx)
    for _, bag in ipairs(others(new)) do
      bag:Activate(ctx)
    end
  end

  self:Use(design)
  database:SetNextEnabled(design == "next")
  new.backpack.loaded = old.backpack.loaded
  if new.bank and old.bank then
    new.bank.loaded = old.bank.loaded
  end
  new.backpack:Draw(ctx, items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK], function() end)
  if wasOpen then
    new.backpack:Show(ctx)
  end
  if new.backpack.searchBox and backpackSearch then
    new.backpack.searchBox.textBox:SetText(backpackSearch)
  end
  if new.bank and new.bank.searchBox and bankSearch then
    new.bank.searchBox.textBox:SetText(bankSearch)
  end
  addon:UpdateButtonHighlight()
  events:SendMessage(ctx, 'bags/DesignChanged', design)
  return true
end

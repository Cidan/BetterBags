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

-- vendorInUse says whether BetterBags Next's vendor stands in for Blizzard's merchant frame (Enable Vendor Window).
---@return boolean
local function vendorInUse()
  return database:GetNextVendorEnabled() and true or false
end

-- guildInUse says whether BetterBags Next's guild bank stands in for Blizzard's guild bank frame (Enable Guild Bank
-- Window), on a client with a guild bank.
---@return boolean
local function guildInUse()
  return addon.hasGuildBank and database:GetNextGuildBankEnabled() and true or false
end

-- CreateRest makes the rest of a design in its scope: its bank, with Enable Bank Bags, and for
-- BetterBags Next the vendor, which takes over Blizzard's merchant frame, and on a client with a guild
-- bank the guild bank, which takes over Blizzard's guild bank frame (guild-bank.md §5), each only while
-- it is switched on (Enable Vendor Window, Enable Guild Bank Window): off, it is made when switched on.
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
      if vendorInUse() then
        s.vendor = nextVendor:Create(ctx)
      end
      if guildInUse() then
        s.guild = nextGuildBank:Create(ctx)
      end
    end
  end)
  if design == "next" then
    self:takeOver(s)
  end
end

-- takeOver has BetterBags Next's panels stand in for Blizzard's merchant and guild bank frames, those switched on.
---@private
---@param s BagSystemSet
function bagSystem:takeOver(s)
  if s.vendor and vendorInUse() then
    nextVendor:TakeOver(_G.BetterBagsSneakyFrame)
  end
  if s.guild and guildInUse() then
    nextGuildBank:TakeOver(_G.BetterBagsSneakyFrame)
  end
end

-- giveBack gives Blizzard's merchant and guild bank frames back when BetterBags Next is switched off. One switched
-- off gave its frame back then.
---@private
---@param s BagSystemSet
function bagSystem:giveBack(s)
  if s.vendor and vendorInUse() then
    nextVendor:GiveBack()
  end
  if s.guild and guildInUse() then
    nextGuildBank:GiveBack()
  end
end

-- others are a design's bags beside its backpack in use, in the order they are made: a vendor or guild bank switched
-- off is left out (it was switched off then, and catches up when switched on).
---@param s BagSystemSet
---@return table[]
local function others(s)
  local list = {}
  for _, bag in ipairs({ s.bank or false, vendorInUse() and s.vendor or false, guildInUse() and s.guild or false }) do
    if bag then
      table.insert(list, bag)
    end
  end
  return list
end

-- make makes BetterBags Next's vendor or guild bank after the rest of the design, the first time it is switched on, in
-- the design's scope; Escape closes it, and the cursor (ConsolePort) reaches the guild bank, as the other bags.
---@private
---@param ctx Context
---@param s BagSystemSet
---@param key "vendor"|"guild"
function bagSystem:make(ctx, s, key)
  events:InScope(s.scope, function()
    if key == "vendor" then
      s.vendor = nextVendor:Create(ctx)
    else
      s.guild = nextGuildBank:Create(ctx)
    end
  end)
  table.insert(UISpecialFrames, s[key]:GetName())
  if key == "guild" then
    consoleport:Add(s.guild.frame)
  end
end

-- makeMissing makes the vendor and guild bank switched on that BetterBags Next was made without.
---@private
---@param ctx Context
---@param s BagSystemSet
function bagSystem:makeMissing(ctx, s)
  if s.vendor == nil and vendorInUse() then
    self:make(ctx, s, "vendor")
  end
  if s.guild == nil and guildInUse() then
    self:make(ctx, s, "guild")
  end
end

-- useBags makes a design's bags in use the addon's.
---@private
---@param s BagSystemSet
function bagSystem:useBags(s)
  addon.Bags.Backpack = s.backpack
  addon.Bags.Bank = s.bank
  addon.Bags.GuildBank = guildInUse() and s.guild or nil
  addon.Vendor = vendorInUse() and s.vendor or nil
end

-- Use makes a design's bags the addon's.
---@param design BagDesign
function bagSystem:Use(design)
  local s = self.sets[design]
  self.active = design
  self:useBags(s)
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

-- atVendor says whether a vendor is open, in Blizzard's merchant frame or BetterBags Next's vendor.
---@return boolean
local function atVendor()
  return (MerchantFrame and MerchantFrame:IsShown()) or (addon.Vendor and addon.Vendor.atMerchant) or false
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
  if atVendor() then
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
    local caughtUp = others(new)
    if design == "next" then
      self:makeMissing(ctx, new)
      self:takeOver(new)
    end
    new.backpack:Activate(ctx)
    for _, bag in ipairs(caughtUp) do
      bag:Activate(ctx)
    end
  end

  self:Use(design)
  local view = database:GetBagView(const.BAG_KIND.BACKPACK)
  local sectionOrder = database:GetSectionSortType(const.BAG_KIND.BACKPACK, view)
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
  -- Each design has its own Section Order, and what the bags last read was sorted by the other's. Only the backpack:
  -- the bags cannot switch at the bank or the guild bank, and each is read when it opens.
  if database:GetSectionSortType(const.BAG_KIND.BACKPACK, view) ~= sectionOrder then
    events:SendMessage(ctx, 'bags/Rederive', { backpack = true, bank = false, categoriesUnchanged = true })
  end
  events:SendMessage(ctx, 'bags/DesignChanged', design)
  return true
end

-- apply puts BetterBags Next's vendor or guild bank as its setting has it, at once while BetterBags Next is in use: on,
-- it is made the first time (else it catches up) and takes Blizzard's frame; off, it hides, lets go of its buttons and
-- answers nothing more (Deactivate), and gives Blizzard's frame back, which then shows the vendor or the guild bank.
-- While the classic bags are in use there is nothing to do: BetterBags Next follows the setting when switched to.
---@private
---@param ctx Context
---@param key "vendor"|"guild"
function bagSystem:apply(ctx, key)
  local s = self.active == "next" and self.sets[self.active] or nil
  if s == nil then
    return
  end
  local module, inUse = nextVendor, vendorInUse()
  if key == "guild" then
    module, inUse = nextGuildBank, guildInUse()
  end
  if inUse then
    if s[key] == nil then
      self:make(ctx, s, key)
    else
      s[key]:Activate(ctx)
    end
    module:TakeOver(_G.BetterBagsSneakyFrame)
  elseif s[key] ~= nil then
    s[key]:Deactivate(ctx)
    module:GiveBack()
  end
  self:useBags(s)
end

-- SetVendorEnabled switches BetterBags Next's vendor on or off (Enable Vendor Window), saving the choice, at once
-- (apply). It refuses at a vendor: its frame would change hands open (Switch). It returns whether it switched.
---@param ctx Context
---@param on boolean
---@return boolean
function bagSystem:SetVendorEnabled(ctx, on)
  if atVendor() then
    return refuse(L:G("Close the vendor to switch vendor windows."))
  end
  database:SetNextVendorEnabled(on)
  self:apply(ctx, "vendor")
  return true
end

-- SetGuildBankEnabled switches BetterBags Next's guild bank on or off (Enable Guild Bank Window), saving the choice, at
-- once (apply). It refuses at the guild bank, as Switch does. It returns whether it switched.
---@param ctx Context
---@param on boolean
---@return boolean
function bagSystem:SetGuildBankEnabled(ctx, on)
  if addon.atGuildBank then
    return refuse(L:G("Close the guild bank to switch guild bank windows."))
  end
  database:SetNextGuildBankEnabled(on)
  self:apply(ctx, "guild")
  return true
end

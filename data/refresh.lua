local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class (exact) Refresh: AceModule
---@field private isSorting boolean
local refresh = addon:NewModule('Refresh')

function refresh:Init()
  self.isSorting = false
end

---@param ctx Context
function refresh:RedrawBackpack(ctx)
  debug:Log('RedrawBackpack', 'Redrawing backpack')
  ctx:Set('redraw', true)
  addon.Bags.Backpack:Draw(ctx, items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK], function()
    events:SendMessage(ctx, 'bags/Draw/Backpack/Done')
  end)
end

function refresh:AfterSort(ctx)
  -- TODO(lobato): Detect if only new items were moved,
  -- and only refresh the backpack if that's the case.
  -- After moving an item, the client state does not update right
  -- away, and there is a delay. This delay will prevent issues
  -- with drawing.
  C_Timer.After(0.5, function()
    self.isSorting = false
    events:SendMessage(ctx, 'bags/FullRefreshAll')
  end)

  --if ctx:GetBool('moved') then
  --  events:SendMessage(ctx, 'bags/FullRefreshAll')
  --else
  --  events:SendMessage(ctx, 'bags/FullRefreshAll')
  --end
end

-- RequestUpdate processes an update request instantly and synchronously
---@class RefreshRequest
---@field wipe? boolean Clear cache before refresh
---@field backpack? boolean Update backpack items
---@field bank? boolean Update bank items
---@field sort? boolean Sort backpack items
---@field sortBank? boolean Sort character bank items
---@field sortWarbank? boolean Sort account/warbank items
---@field bags? table<number, boolean> Table of specific bagIDs that changed
---@field resetLayout? boolean Ignore the previous gap layout and rebuild a fresh, gapless sort

---@param request RefreshRequest
function refresh:RequestUpdate(request)
  local ctx = context:New('BagUpdate')

  if request.bags then
    ctx:Set('targetedBags', request.bags)
  end

  -- resetLayout collapses any persistent item gaps: the sweep rebuilds a fresh,
  -- gapless sort instead of diffing against the previous layout. Set before the
  -- bank ctx:Copy() below so both kinds inherit it.
  if request.resetLayout then
    ctx:Set('resetLayout', true)
  end

  if request.wipe then
    items:ClearItemCache(ctx)
    ctx:Set('wipe', true)
    request.backpack = true
    request.bank = true
  end

  if request.sort then
    ctx:Set('resetLayout', true)
    items:ClearNewItems(const.BAG_KIND.BACKPACK)
    request.backpack = true
  end

  if request.sortBank or request.sortWarbank then
    ctx:Set('resetLayout', true)
    items:ClearNewItems(const.BAG_KIND.BANK)
    request.bank = true
  end

  if request.bank and addon.atBank and addon.Bags.Bank then
    local accountBankStart = addon.isRetail and Enum.BagIndex.AccountBankTab_1 or const.BANK_TAB.ACCOUNT_BANK_1
    if addon.atWarbank and addon.Bags.Bank.bankTab and accountBankStart and addon.Bags.Bank.bankTab < accountBankStart then
      addon.Bags.Bank.bankTab = accountBankStart
    end

    local refreshCtx = ctx:Copy()
    items:RefreshBank(refreshCtx)
  end

  if request.backpack then
    items:RefreshBackpack(ctx)
  end

  if not InCombatLockdown() then
    if request.sort then
      if addon.isRetail and C_Container and C_Container.SortBags then
        C_Container.SortBags()
      elseif _G.SortBags then
        _G.SortBags()
      end
    end

    if request.sortBank then
      if addon.isRetail and C_Container and C_Container.SortBankBags then
        C_Container.SortBankBags()
      elseif _G.SortBankBags then
        _G.SortBankBags()
      end
    end

    if request.sortWarbank then
      if addon.isRetail and C_Container and C_Container.SortAccountBankBags then
        C_Container.SortAccountBankBags()
      end
    end
  end
end

function refresh:OnEnable()
  local itemLoader = addon:GetModule('ItemLoader')
  itemLoader:TellMeWhenABagIsUpdated(function(updatedBags)
    local backpackChanged = false
    local bankChanged = false

    for bagID in pairs(updatedBags) do
      if const.BACKPACK_BAGS[bagID] then
        backpackChanged = true
      elseif const.BANK_BAGS[bagID] or (const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagID]) then
        bankChanged = true
      end
    end

    if backpackChanged or bankChanged then
      self:RequestUpdate({
        backpack = backpackChanged,
        bank = bankChanged,
        bags = updatedBags
      })
    end
  end)

  events:RegisterMessage('bags/RefreshAll', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)
  events:RegisterMessage('bags/FullRefreshAll', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)
  events:RegisterMessage('bags/RefreshBackpack', function()
    self:RequestUpdate({ backpack = true })
  end)
  events:RegisterMessage('bags/RefreshBank', function()
    self:RequestUpdate({ bank = true })
  end)
  events:RegisterMessage('bags/SortBackpack', function()
    self:RequestUpdate({ sort = true })
  end)
  events:RegisterMessage('bags/SortBank', function()
    self:RequestUpdate({ sortBank = true })
  end)
  events:RegisterMessage('bags/SortWarbank', function()
    self:RequestUpdate({ sortWarbank = true })
  end)

  events:RegisterEvent('BAG_CONTAINER_UPDATE', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function()
    self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  end)

  events:RegisterEvent('BANKFRAME_OPENED', function()
    if GameMenuFrame:IsShown() then
      return
    end
    addon.atBank = true
    if addon.isRetail and database:GetShowBankTabs()
      and addon.Bags and addon.Bags.Bank then
      local slots = addon.Bags.Bank.slots
      local firstButton = slots and slots.buttons and slots.buttons[1]
      if firstButton then
        addon.Bags.Bank.blizzardBankTab = firstButton.bagIndex
      end
    end
    -- Opening the bank starts from a clean, gapless layout; any gaps held from a
    -- previous session are collapsed here.
    self:RequestUpdate({ bank = true, resetLayout = true })
  end)

  events:RegisterEvent('BANKFRAME_CLOSED', function()
    addon.atBank = false
  end)

  if not addon.isRetail then
    events:RegisterEvent('PLAYERBANKSLOTS_CHANGED', function()
      self:RequestUpdate({ bank = true, bags = { [-1] = true } })
    end)
  end

  self:RequestUpdate({ wipe = true, backpack = true, bank = true })
end

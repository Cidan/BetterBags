local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Groups: AceModule
local groups = addon:GetModule('Groups')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class MoneyFrame: AceModule
local money = addon:GetModule('MoneyFrame')

---@class BankBehavior: AceModule
local bankBehavior = addon:GetModule('BankBehavior')

---@class BagMenuButton: AceModule
local menuButton = addon:GetModule('BagMenuButton')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPanel: AceModule
local nextPanel = addon:GetModule('NextPanel')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

-- NextBank is BetterBagsNext's bank (next.md §6): the backpack's panel mirrored on the left of the
-- screen (next/panel.lua). It does what the classic retail, WoW: Forever and Classic banks do,
-- reusing their code wherever it is not drawing: the groups and the Warbank, Blizzard's bank tabs
-- and their bag sockets, purchases, deposits, sorting, money, and opening and closing the bank. It
-- stands in for the bank everywhere the addon talks to it.
---@class NextBank: AceModule
local nextBank = addon:NewModule('NextBank')

local EMPTY_BAG_SLOT_TEXTURE = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]

---@class NextBankPanel: NextPanelFrame
---@field closeButton Button
---@field settingsButton Button
---@field bankTabsButton? Button Retail: switches between groups and Blizzard's bank tabs.
---@field depositButton? Button Retail with a Warbank.
---@field sortButton? Button Where the client can sort the bank.
---@field purchaseBankButton? Button Retail: shown while the character owns no character bank tab.
---@field bankTab number The bank tab the bank shows: what deposits, drops and the backpack's grey-out go by.
---@field blizzardBankTab? number The Blizzard bank tab shown, in tab mode.
---@field helper BankBehaviorProto The classic bank behavior's methods, for its dialogs and the purchase rule.
---@field behavior {SwitchToGroup: fun(self: any, ctx: Context, id: number), SwitchToBlizzardTab: fun(self: any, ctx: Context, bagIndex: number)}
---@field wipeWhenHidden boolean The bank closed while the panel slid out: clear it once hidden.
---@field endingInteraction boolean It is ending the bank interaction.
local bankProto = nextPanel:Extend({}, 'NextBankPanel')

---@return BankSlots?
local function bankSlots()
  return addon:GetModule('BankSlots', true)
end

---@param ctx Context
---@return NextBankPanel
function nextBank:Create(ctx)
  local _ = ctx
  ---@type NextBankPanel
  local b = nextPanel:Create(bankProto, {
    kind = const.BAG_KIND.BANK,
    side = "LEFT",
    name = "BetterBagsNextBank",
    scrollName = "BetterBagsNextBankScroll",
    title = L:G("Bank"),
    openSound = SOUNDKIT.IG_MAINMENU_OPEN,
    closeSound = SOUNDKIT.IG_MAINMENU_CLOSE,
    chainRole = "companion",
  })
  b.bankTab = const.BANK_TAB.BANK
  b.wipeWhenHidden = false
  b.endingInteraction = false
  b.helper = setmetatable({ bag = b }, { __index = bankBehavior.proto })
  b.behavior = {
    SwitchToGroup = function(_, ectx, id)
      b:SwitchToGroup(ectx, id)
    end,
    SwitchToBlizzardTab = function(_, ectx, bagIndex)
      b:SwitchToBlizzardTab(ectx, bagIndex)
    end,
  }
  b:BuildPurchaseBankButton()
  return b
end

---@return NextHeaderButton[]
function bankProto:GetHeaderButtons()
  local buttons = {
    { key = "closeButton", tooltip = L:G("Close"), onClick = function(ctx) self:Hide(ctx) end },
    { key = "settingsButton", tooltip = L:G("Open Options Screen"),
      onClick = function(ctx) events:SendMessage(ctx, "config/Open") end },
  }
  if addon.isRetail then
    table.insert(buttons, { key = "bankTabsButton", tooltip = L:G("Switch between your groups and the bank's own tabs"),
      onClick = function(ctx) self:ToggleBankTabs(ctx) end })
  end
  if addon.hasWarbank then
    table.insert(buttons, { key = "depositButton", tooltip = L:G("Deposit Warbank Items"),
      onClick = function() C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account) end })
  end
  if (C_Container and C_Container.SortBankBags) or _G.SortBankBags then
    table.insert(buttons, { key = "sortButton", tooltip = L:G("Sort Bank"), onClick = function(ctx) self:Sort(ctx) end })
  end
  return buttons
end

-- CreateMoney makes the money frame the classic bank shows: the Warbank's gold on retail with a
-- Warbank, the character's on WoW: Forever, none on Classic.
---@return Money?
function bankProto:CreateMoney()
  if not addon.isRetail then
    return nil
  end
  return money:Create(addon.hasWarbank)
end

-- BuildPurchaseBankButton makes the "Purchase Bank" button (retail, camelot-forever.md §10).
-- Buying a bank tab is protected (C_Bank.PurchaseBankTab), so the click must be the template's
-- own OnClick, which opens Blizzard's purchase dialog: it is never given an OnClick.
function bankProto:BuildPurchaseBankButton()
  if not addon.isRetail then
    return
  end
  local button = CreateFrame("Button", "BetterBagsNextPurchaseBankButton", self.frame,
    "BankPanelPurchaseButtonScriptTemplate, UIPanelButtonTemplate")
  button:SetAttribute("overrideBankType", Enum.BankType.Character)
  button:SetText(L:G("Purchase Bank"))
  button:SetFrameLevel(self.scroll.frame:GetFrameLevel() + 10)
  button:Hide()
  self.purchaseBankButton = button
  addon.HookScript(self.scroll.frame, "OnSizeChanged", function() self:placePurchaseBankButton() end)
  self:placePurchaseBankButton()
end

-- placePurchaseBankButton puts the Purchase Bank button in the middle of the content by its top left, in
-- whole pixels (docs/next-pixel-perfect.md): its size, and the parts of its template (UIPanelButtonTemplate:
-- its 12-unit end pieces, its text at its middle) rounded in place. It keeps its template, scripts and all.
---@private
function bankProto:placePurchaseBankButton()
  local button, area = self.purchaseBankButton, self.scroll.frame
  pixel:Size(button, pixel:Ceil(button, button:GetTextWidth()) + 40, 26)
  local width, height = button:GetWidth(), button:GetHeight()
  button:ClearAllPoints()
  pixel:Center(button, area, area:GetWidth(), area:GetHeight(), width, height)
  if button.Left ~= nil and button.Right ~= nil then
    pixel:Width(button.Left, 12)
    pixel:Width(button.Right, 12)
  end
  local text = button:GetFontString()
  if text ~= nil then
    text:ClearAllPoints()
    pixel:Row(text, "TOPLEFT", button, pixel:Middle(button, width, pixel:Ceil(button, text:GetStringWidth())), height)
  end
end

-- UpdatePurchaseBankButton shows the Purchase Bank button by the classic bank's rule
-- (bank.proto:NeedsBankPurchase), in the middle of the content as it is now.
function bankProto:UpdatePurchaseBankButton()
  if self.purchaseBankButton then
    self.helper:UpdatePurchaseBankButton()
    self:placePurchaseBankButton()
  end
end

-- TabOrderKey saves the order of the bank's group tabs and, apart, of Blizzard's bank tabs.
---@return string
function bankProto:TabOrderKey()
  return self:InTabMode() and "bankTabs" or "bank"
end

-- InTabMode is whether the bank shows Blizzard's bank tabs (the classic bank's Show Bags) rather
-- than its groups. Classic clients have no bank tabs.
---@return boolean
function bankProto:InTabMode()
  return addon.isRetail and database:GetShowBankTabs() and true or false
end

---@return number
function bankProto:GetCurrentTabID()
  if database:GetShowBankTabs() then
    return self.blizzardBankTab or -1
  end
  return nextPanel.proto.GetCurrentTabID(self)
end

---@param group Group
---@return boolean
local function isWarbankGroup(group)
  return addon.hasWarbank and group.bankType == Enum.BankType.Account
end

---@param bagIndex number
---@return BankType
local function bankTypeOfTab(bagIndex)
  if const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagIndex] ~= nil then
    return Enum.BankType.Account
  end
  return Enum.BankType.Character
end

-- ShownBankType is the bank type the bank shows (retail), what drops and moves go by.
---@return BankType?
function bankProto:ShownBankType()
  if not addon.isRetail then
    return nil
  end
  return bankTypeOfTab(self.bankTab)
end

-- BankTypeOfTab is a Blizzard bank tab's bank type.
---@param bagIndex number
---@return BankType
function bankProto:BankTypeOfTab(bagIndex)
  return bankTypeOfTab(bagIndex)
end

-- PurchasedTabs returns the purchased bank tabs of a bank type, in tab order.
---@param bankType BankType
---@return BankTabData[]
function bankProto:PurchasedTabs(bankType)
  local tabs = {}
  for _, t in ipairs(C_Bank.FetchPurchasedBankTabData(bankType) or {}) do
    table.insert(tabs, t)
  end
  table.sort(tabs, function(a, b) return a.ID < b.ID end)
  return tabs
end

-- FirstBankTab returns the first purchased bank tab: the character bank's, else the Warbank's.
---@return number?
function bankProto:FirstBankTab()
  local first = self:PurchasedTabs(Enum.BankType.Character)[1]
  if first == nil and addon.hasWarbank then
    first = self:PurchasedTabs(Enum.BankType.Account)[1]
  end
  return first and first.ID or nil
end

---@param bagIndex number
---@return BankTabData?
function bankProto:TabData(bagIndex)
  for _, t in ipairs(self:PurchasedTabs(bankTypeOfTab(bagIndex))) do
    if t.ID == bagIndex then
      return t
    end
  end
  return nil
end

-- RefreshTabs lists Blizzard's bank tabs in tab mode, else the bank's groups (none while groups
-- are off), and selects the one shown.
function bankProto:RefreshTabs()
  if self:InTabMode() then
    self:ListBankTabs()
    return
  end
  if not database:GetGroupsEnabled(self.kind) then
    self.tabs.frame:Hide()
    return
  end
  local bank, warbank = {}, {}
  for id, group in pairs(groups:GetAllGroups(self.kind)) do
    if isWarbankGroup(group) then
      table.insert(warbank, { id = id, name = group.name, accent = "Warbank", atlas = "warbands-icon", block = "warbank" })
    else
      table.insert(bank, { id = id, name = group.name, block = "bank" })
    end
  end
  local byID = function(a, b) return a.id < b.id end
  table.sort(bank, byID)
  table.sort(warbank, byID)
  local entries = self:OrderedTabs(bank)
  for i, entry in ipairs(self:OrderedTabs(warbank)) do
    if i == 1 and #bank > 0 then
      entry.gap = style.TAB_GROUP_GAP
    end
    table.insert(entries, entry)
  end
  table.insert(entries, {
    id = 0,
    name = "+",
    fixed = true,
    tooltip = { L:G("Create New Group Tab"), L:G("Click to create a new group tab for organizing your items.") },
  })
  self.tabs:SetTabs(entries)
  self.tabs:Select(self:GetCurrentTabID())
  self.tabs.frame:Show()
end

-- tabIcon is what a Blizzard bank tab shows beside its name: the bag in its socket on WoW:
-- Forever (or an empty bag slot), else the tab's own icon.
---@private
---@param bankType BankType
---@param t BankTabData
---@return number|string
function bankProto:tabIcon(bankType, t)
  local slots = bankSlots()
  local socketIndex = slots and slots:GetBagSocketIndex(bankType, t.ID)
  if socketIndex then
    local location = ItemLocation:CreateFromBagAndSlot(Enum.BagIndex.Characterbanktab, socketIndex)
    if C_Item.DoesItemExist(location) then
      return C_Item.GetItemIcon(location)
    end
    return EMPTY_BAG_SLOT_TEXTURE
  end
  return t.icon
end

-- ShowTabTooltip fills the tooltip for a Blizzard bank tab, as the classic bank tab panel does:
-- the socketed bag first (WoW: Forever), the tab's name and bank, and what clicking does.
---@param bankType BankType
---@param t BankTabData
function bankProto:ShowTabTooltip(bankType, t)
  local slots = bankSlots()
  local socketIndex = slots and slots:GetBagSocketIndex(bankType, t.ID)
  local hasBag = socketIndex ~= nil and GameTooltip:SetBagItem(Enum.BagIndex.Characterbanktab, socketIndex)
  if hasBag then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(t.name, 1, 1, 1, true)
  else
    GameTooltip:SetText(t.name, 1, 1, 1, 1, true)
  end
  if bankType == Enum.BankType.Character then
    GameTooltip:AddLine(L:G("Bank"), 0.6, 0.8, 1.0, true)
  else
    GameTooltip:AddLine(L:G("Warbank"), 1.0, 0.85, 0.1, true)
  end
  if socketIndex and not hasBag then
    GameTooltip:AddLine(L:G("No bag in this slot"), 1.0, 0.3, 0.3, true)
  elseif addon.isForever and bankType == Enum.BankType.Character then
    local numSlots = C_Container.GetContainerNumSlots(t.ID)
    local numFree = C_Container.GetContainerNumFreeSlots(t.ID)
    GameTooltip:AddLine(format(L:G("%d of %d slots free"), numFree, numSlots), 1, 1, 1, true)
  end
  GameTooltip:AddLine(L:G("Left-click to view this tab"), 0.8, 0.8, 0.8, true)
  if hasBag then
    GameTooltip:AddLine(L:G("Drag to remove this bag"), 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(L:G("Drop a bag here to swap it"), 0.8, 0.8, 0.8, true)
  elseif socketIndex then
    GameTooltip:AddLine(L:G("Drop a bag here to use this tab"), 0.8, 0.8, 0.8, true)
  end
  GameTooltip:AddLine(L:G("Right-click to configure this tab"), 0.8, 0.8, 0.8, true)
end

-- ListBankTabs lists Blizzard's purchased bank tabs, character tabs first and then the Warbank's,
-- each followed by a purchase tab while one of that bank type can be bought.
function bankProto:ListBankTabs()
  local entries = {}
  local slots = bankSlots()
  local function add(bankType, purchaseID, purchaseTitle, gap)
    local warbank = bankType == Enum.BankType.Account
    local tabs = {}
    for _, t in ipairs(self:PurchasedTabs(bankType)) do
      table.insert(tabs, {
        id = t.ID,
        name = t.name,
        icon = self:tabIcon(bankType, t),
        accent = warbank and "Warbank" or nil,
        block = warbank and "warbank" or "bank",
        draggable = slots ~= nil and slots:GetBagSocketIndex(bankType, t.ID) ~= nil,
        tooltip = function()
          self:ShowTabTooltip(bankType, t)
        end,
      })
    end
    for i, entry in ipairs(self:OrderedTabs(tabs)) do
      entry.gap = i == 1 and gap or nil
      table.insert(entries, entry)
    end
    if C_Bank.FetchNextPurchasableBankTabData(bankType) ~= nil then
      table.insert(entries, {
        id = purchaseID,
        name = "+",
        secure = bankType,
        accent = bankType == Enum.BankType.Account and "Warbank" or nil,
        tooltip = { purchaseTitle, L:G("Click to purchase this tab") },
      })
    end
  end
  add(Enum.BankType.Character, -1, L:G("Unpurchased Bank Tab"))
  if addon.hasWarbank then
    add(Enum.BankType.Account, -2, L:G("Unpurchased Warbank Tab"), #entries > 0 and style.TAB_GROUP_GAP or nil)
  end
  self.tabs:SetTabs(entries)
  self.tabs:Select(self.blizzardBankTab)
  self.tabs.frame:Show()
end

-- OnTabClicked runs a click on a tab. Groups: a left click shows the group, a right click opens
-- a custom group's menu, "+" opens the group dialog. Bank tabs: a left click shows the tab (on
-- WoW: Forever, holding an item or with Shift, it moves the socketed bag instead), a right click
-- opens Blizzard's tab settings.
---@param ctx Context
---@param id number
---@param button string
function bankProto:OnTabClicked(ctx, id, button)
  if self:InTabMode() then
    local slots = bankSlots()
    if button == "RightButton" then
      if slots then
        slots:OpenTabConfig(id)
      end
      return
    end
    local bankType = bankTypeOfTab(id)
    if slots and slots:GetBagSocketIndex(bankType, id) and (GetCursorInfo() == "item" or IsModifiedClick("PICKUPITEM")) then
      slots:PickupBag(bankType, id)
      return
    end
    self:SwitchToBlizzardTab(ctx, id)
    return
  end
  if id == 0 then
    self.helper:ShowCreateGroupDialog()
    return
  end
  if button == "RightButton" then
    if not groups:IsDefaultGroup(self.kind, id) then
      self.helper:ShowGroupContextMenu(ctx, id)
    end
    return
  end
  self:SwitchToGroup(ctx, id)
end

-- OnTabDragged moves the bag in a WoW: Forever bank tab's socket: the tab was dragged, or a bag
-- was dropped on it.
---@param ctx Context
---@param id number
function bankProto:OnTabDragged(ctx, id)
  local _ = ctx
  local slots = bankSlots()
  if slots then
    slots:PickupBag(bankTypeOfTab(id), id)
  end
end

-- useBankType points everything that goes by the bank type at the one shown: Blizzard's bank
-- panel (right-click deposits), bankTab (drops, the backpack's grey-out) and the wash.
---@private
---@param warbank boolean
---@param bagIndex? number The Blizzard bank tab shown, in tab mode.
function bankProto:useBankType(warbank, bagIndex)
  if addon.isRetail then
    addon.SetBlizzardBankType(warbank and Enum.BankType.Account or Enum.BankType.Character)
  end
  if bagIndex then
    self.bankTab = bagIndex
  elseif warbank then
    self.bankTab = Enum.BagIndex.AccountBankTab_1
  else
    self.bankTab = const.BANK_TAB.BANK
  end
  self:SetWash(warbank and "Warbank" or "Default")
  self:UpdatePurchaseBankButton()
end

-- selectGroup makes a group the one shown, without drawing.
---@private
---@param group Group
function bankProto:selectGroup(group)
  database:SetActiveGroup(self.kind, group.id)
  self:useBankType(isWarbankGroup(group))
  self:SetTitle(group.name)
end

-- selectBlizzardTab makes a Blizzard bank tab the one shown, without drawing.
---@private
---@param bagIndex number
function bankProto:selectBlizzardTab(bagIndex)
  self.blizzardBankTab = bagIndex
  self:useBankType(bankTypeOfTab(bagIndex) == Enum.BankType.Account, bagIndex)
  local t = self:TabData(bagIndex)
  self:SetTitle(t and t.name or L:G("Bank"))
end

-- shown draws the bank for the tab just selected, fading in, and has the backpack recalculated
-- while at the bank: its grey-out follows the bank type shown (item-drawing.md §8).
---@private
---@param ctx Context
---@param id number
function bankProto:shown(ctx, id)
  self.tabs:Select(id, true)
  self.tabChanged = true
  self:Draw(ctx, items:GetAllSlotInfo()[self.kind], function() end)
  addon.TriggerItemContextChanged()
  if addon.atBank then
    events:SendMessage(ctx, 'bags/Rederive', { backpack = true, bank = false, categoriesUnchanged = true })
  end
end

-- SwitchToGroup shows a group of the bank.
---@param ctx Context
---@param id number
function bankProto:SwitchToGroup(ctx, id)
  local group = groups:GetGroup(self.kind, id)
  if group == nil then
    return
  end
  self:selectGroup(group)
  self:shown(ctx, id)
end

-- SwitchToBlizzardTab shows one of Blizzard's bank tabs.
---@param ctx Context
---@param bagIndex number
function bankProto:SwitchToBlizzardTab(ctx, bagIndex)
  self:selectBlizzardTab(bagIndex)
  self:shown(ctx, bagIndex)
end

-- ToggleBankTabs switches between the groups and Blizzard's bank tabs, as the classic bank's Show
-- Bags does (ContextMenu:ToggleBagSlots): the setting, the Show Bags view and back, and a
-- recalculation of the bags, which draws them.
---@param ctx Context
function bankProto:ToggleBankTabs(ctx)
  if InCombatLockdown() then
    print("BetterBags: " .. L:G("Cannot toggle bag slots in combat."))
    return
  end
  if database:GetShowBankTabs() then
    database:SetShowBankTabs(false)
    database:SetBagView(self.kind, database:GetPreviousView(self.kind))
    self.blizzardBankTab = nil
    local group = groups:GetGroup(self.kind, database:GetActiveGroup(self.kind)) or groups:GetDefaultBankGroup()
    if group then
      self:selectGroup(group)
    end
  else
    database:SetShowBankTabs(true)
    database:SetPreviousView(self.kind, database:GetBagView(self.kind))
    database:SetBagView(self.kind, const.BAG_VIEW.SECTION_ALL_BAGS)
    local first = self:FirstBankTab()
    if first then
      self:selectBlizzardTab(first)
    end
  end
  self.tabChanged = true
  self:RefreshTabs()
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true })
end

-- OnShowing sets the bank up as it opens: Blizzard's bank panel suppressed, the group (or in tab
-- mode the Blizzard tab) shown, the tabs listed, the money updated, and the bank's last read
-- data drawn once the panel shows.
---@param ctx Context
function bankProto:OnShowing(ctx)
  local _ = ctx
  bankBehavior:SuppressBlizzardBankPanel()
  if self:InTabMode() then
    local bagIndex = self.blizzardBankTab
    if bagIndex == nil or self:TabData(bagIndex) == nil then
      bagIndex = self:FirstBankTab()
    end
    if bagIndex then
      self:selectBlizzardTab(bagIndex)
    end
  else
    local group = groups:GetGroup(self.kind, database:GetActiveGroup(self.kind)) or groups:GetDefaultBankGroup()
    if group then
      self:selectGroup(group)
    end
  end
  self:RefreshTabs()
  if self.moneyFrame then
    self.moneyFrame:Update()
  end
  self.lastSlotInfo = items:GetAllSlotInfo()[self.kind]
  self.drawPendingOnShow = true
end

-- EndBankInteraction ends the bank interaction, once: ending it fires BANKFRAME_CLOSED, which
-- hides the bank again (addon.CloseBank). Never from OnHide: Escape hides the panel from a
-- protected path, and CloseSpecialWindows ends the interaction.
function bankProto:EndBankInteraction()
  if self.endingInteraction or not addon.atBank then
    return
  end
  self.endingInteraction = true
  if C_Bank and C_Bank.CloseBankFrame then
    C_Bank.CloseBankFrame()
  elseif CloseBankFrame then
    CloseBankFrame()
  end
  self.endingInteraction = false
end

-- Hide slides the panel out; on retail it ends the bank interaction at once, as the classic
-- bank's hook on its Hide does.
---@param ctx Context
function bankProto:Hide(ctx)
  nextPanel.proto.Hide(self, ctx)
  if addon.isRetail then
    self:EndBankInteraction()
  end
end

-- OnSlidOut ends the bank interaction on Classic once the panel has slid out, as the classic
-- Classic bank's hide callback does.
---@param ctx Context
function bankProto:OnSlidOut(ctx)
  local _ = ctx
  if not addon.isRetail then
    self:EndBankInteraction()
  end
end

-- OnHidden clears the bank once hidden when the bank closed while the panel slid out.
---@param ctx Context
function bankProto:OnHidden(ctx)
  nextPanel.proto.OnHidden(self, ctx)
  if self.wipeWhenHidden then
    self.wipeWhenHidden = false
    self:Wipe(ctx)
  end
end

-- SwitchToBankAndWipe resets the bank when it closes (addon.CloseBank): the character bank, the
-- title, the bank's data cleared and its buttons released, after the slide when the panel is
-- still sliding out, so it never slides out empty.
---@param ctx Context
function bankProto:SwitchToBankAndWipe(ctx)
  ctx:Set("wipe", true)
  self.bankTab = const.BANK_TAB.BANK
  if addon.isRetail then
    addon.SetBlizzardBankType(Enum.BankType.Character)
  elseif BankFrame then
    BankFrame.selectedTab = 1
  end
  self:SetTitle(L:G("Bank"))
  items:ClearBankCache(ctx)
  if self.closing then
    self.wipeWhenHidden = true
  else
    self:Wipe(ctx)
  end
end

-- WatchKind lists the tabs again when the bank's tabs or groups change.
function bankProto:WatchKind()
  if addon.isRetail then
    events:RegisterEvent("BANK_TABS_CHANGED", function()
      self:RefreshTabs()
      self:UpdatePurchaseBankButton()
    end)
    events:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", function()
      self:RefreshTabs()
    end)
    events:RegisterEvent("BANK_TAB_SETTINGS_UPDATED", function()
      self:RefreshTabs()
    end)
  end
  if addon.isForever then
    -- A bag placed in or taken out of a bank tab's socket (camelot-forever.md §9).
    events:RegisterEvent("PLAYERBANKSLOTS_CHANGED", function()
      self:RefreshTabs()
    end)
    events:RegisterEvent("BAG_CONTAINER_UPDATE", function()
      self:RefreshTabs()
    end)
  end
  events:RegisterMessage("groups/Created", function(_, group)
    if group.kind == self.kind then
      self:RefreshTabs()
    end
  end)
  events:RegisterMessage("groups/Changed", function(_, _, _, _, kind)
    if kind == self.kind then
      self:RefreshTabs()
    end
  end)
  events:RegisterMessage("groups/Deleted", function(ctx, groupID, _, kind)
    if kind ~= self.kind then
      return
    end
    if database:GetActiveGroup(self.kind) == groupID then
      local default = groups:GetDefaultBankGroup()
      if default then
        self:SwitchToGroup(ctx, default.id)
      end
    end
    self:RefreshTabs()
  end)
  events:RegisterMessage("groups/EnabledChanged", function(_, kind)
    if kind == self.kind then
      self:RefreshTabs()
    end
  end)
end

-- Activate catches the bank up as every panel does, and its Purchase Bank button, which
-- BANK_TABS_CHANGED updates on retail.
---@param ctx Context
function bankProto:Activate(ctx)
  nextPanel.proto.Activate(self, ctx)
  if addon.isRetail then
    self:UpdatePurchaseBankButton()
  end
end

-- Refresh recalculates the bank from what was last read; it does nothing while the bank is
-- closed (refresh-scheduler.md §10).
---@param ctx Context
function bankProto:Refresh(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { backpack = false, bank = true, categoriesUnchanged = true })
end

-- Sort sorts the bank as the menu button's right click does on retail (the Warbank while a
-- Warbank tab shows, Shift to deposit), and the bank on Classic.
---@param ctx Context
function bankProto:Sort(ctx)
  PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  if addon.isRetail then
    menuButton:Sort(ctx, self)
  else
    events:SendMessage(ctx, "bags/SortBank")
  end
end

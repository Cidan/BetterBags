local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPanel: AceModule
local nextPanel = addon:GetModule('NextPanel')

---@class NextMerchant: AceModule
local merchant = addon:GetModule('NextMerchant')

---@class NextVendorButton: AceModule
local vendorButton = addon:GetModule('NextVendorButton')

---@class NextDrag: AceModule
local nextDrag = addon:GetModule('NextDrag')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

-- NextVendor is BetterBags Next's vendor (next.md §10): a panel on the left, as the bank's, that
-- stands in for Blizzard's merchant frame while BetterBags Next is on. It shows what the vendor
-- sells in the backpack's categories (Buy), what was sold to it (Buyback) and, at a vendor that
-- repairs, what needs repair (Repair); its header sells junk, repairs everything (from the guild
-- bank too) and filters by spec. An item dropped on it is sold, and so is a backpack section dragged
-- onto it (a NextDrag seller). Blizzard's merchant frame stays
-- shown but is never seen (TakeOver): Blizzard's bag code sells on a right click while
-- MerchantFrame:IsShown(), and its OnHide would end the visit.
---@class NextVendor: AceModule
---@field panel? NextVendorPanel
---@field hooked? Frame The merchant frame whose Hide is hooked (once: a hook cannot be taken off).
local nextVendor = addon:NewModule('NextVendor')

local TAB_BUY, TAB_BUYBACK, TAB_REPAIR = 1, 2, 3
-- How many times Classic's Sell Junk sells what junk is left, a moment apart (items lock while they
-- sell; GW2_UI sells the same way).
local SELL_ROUNDS = 3
local SELL_DELAY = 0.2
-- How many items sold buyback keeps (Blizzard's BUYBACK_ITEMS_PER_PAGE); a section sale of more
-- asks first.
local BUYBACK_KEEPS = 12
local REPAIR_ICONS = "Interface\\MerchantFrame\\UI-Merchant-RepairIcons"
-- Blizzard's merchant purchase prompts, closed when the vendor closes (MerchantFrame_OnHide).
local PROMPTS = { "CONFIRM_PURCHASE_TOKEN_ITEM", "CONFIRM_PURCHASE_ITEM_DELAYED", "CONFIRM_REFUND_TOKEN_ITEM",
  "CONFIRM_REFUND_MAX_HONOR", "CONFIRM_REFUND_MAX_ARENA_POINTS" }

---@class NextVendorPanel: NextPanelFrame
---@field closeButton Button
---@field settingsButton Button
---@field filterButton? Button Retail.
---@field sellJunkButton Button
---@field repairAllButton Button
---@field guildRepairButton Button
---@field tab number
---@field atMerchant boolean A vendor is open (MERCHANT_SHOW to MERCHANT_CLOSED).
---@field closeRequested boolean It asked the vendor to close.
---@field buttons table<string, NextVendorButtonFrame> This draw's buttons, by key.
local vendorProto = nextPanel:Extend({}, 'NextVendorPanel')

-- mainline is whether the client runs Blizzard's retail merchant frame (retail and WoW: Forever).
---@return boolean
local function mainline()
  return C_MerchantFrame ~= nil and C_MerchantFrame.GetItemInfo ~= nil
end

---@param ctx Context
---@return NextVendorPanel
function nextVendor:Create(ctx)
  local _ = ctx
  ---@type NextVendorPanel
  local v = nextPanel:Create(vendorProto, {
    kind = const.BAG_KIND.UNDEFINED,
    side = "LEFT",
    name = "BetterBagsNextVendor",
    scrollName = "BetterBagsNextVendorScroll",
    title = L:G("Vendor"),
    openSound = SOUNDKIT.IG_CHARACTER_INFO_OPEN,
    closeSound = SOUNDKIT.IG_CHARACTER_INFO_CLOSE,
    noDrag = true,
    chainRole = "companion",
  })
  v.tab = TAB_BUY
  v.atMerchant = false
  v.closeRequested = false
  v.buttons = {}
  v.content:SetCellHeight(style.ICON + style.VENDOR_PRICE)
  nextDrag:RegisterSeller(v)
  self.panel = v
  return v
end

-- TakeOver puts Blizzard's merchant frame under hidden: still shown to Blizzard's code, never seen,
-- its OnShow and OnHide never running. Whatever hides it while a vendor is open (the panel manager
-- opening another panel on the left, Escape) ends the visit a frame later, as its OnHide would.
---@param hidden Frame
function nextVendor:TakeOver(hidden)
  if MerchantFrame == nil then
    return
  end
  MerchantFrame:SetParent(hidden)
  if self.hooked == MerchantFrame then
    return
  end
  self.hooked = MerchantFrame
  hooksecurefunc(MerchantFrame, "Hide", function()
    if self.panel then
      self.panel:EndVisitLater()
    end
  end)
end

-- GiveBack returns Blizzard's merchant frame to UIParent when BetterBags Next is switched off
-- (next.md §11), only away from a vendor: a shown frame reparented to a visible parent would run
-- Blizzard's OnShow from our code. The hook stays and does nothing: the panel never sees a vendor
-- open while Next is off.
function nextVendor:GiveBack()
  if MerchantFrame == nil then
    return
  end
  MerchantFrame:SetParent(UIParent)
end

---@return NextHeaderButton[]
function vendorProto:GetHeaderButtons()
  local m = mainline()
  local buttons = {
    { key = "closeButton", atlas = "uitools-icon-close", tooltip = L:G("Close"),
      onClick = function(ctx) self:Hide(ctx) end },
    { key = "settingsButton", atlas = "uitools-icon-settings", tooltip = L:G("Open Options Screen"),
      onClick = function(ctx) events:SendMessage(ctx, "config/Open") end },
  }
  if m and SetMerchantFilter ~= nil and MenuUtil ~= nil then
    table.insert(buttons, { key = "filterButton", atlas = "ui-questtrackerbutton-filter",
      tooltip = L:G("Filter what the vendor shows"), onClick = function() self:OpenFilter() end })
  end
  table.insert(buttons, { key = "sellJunkButton", atlas = m and "SpellIcon-256x256-SellJunk" or nil,
    texture = not m and "Interface\\Icons\\INV_Misc_Coin_02" or nil, tooltip = L:G("Sell all junk"),
    onClick = function() self:SellJunk() end })
  table.insert(buttons, { key = "repairAllButton", atlas = m and "SpellIcon-256x256-RepairAll" or nil,
    texture = not m and REPAIR_ICONS or nil, texCoords = not m and { 0.28125, 0.5625, 0, 0.5625 } or nil,
    tooltipFunc = function() self:RepairTooltip(false) end, onClick = function() self:RepairAll(false) end })
  table.insert(buttons, { key = "guildRepairButton", atlas = m and "SpellIcon-256x256-RepairAllGuild" or nil,
    texture = not m and REPAIR_ICONS or nil, texCoords = not m and { 0.5625, 0.84375, 0, 0.5625 } or nil,
    tooltipFunc = function() self:RepairTooltip(true) end, onClick = function() self:RepairAll(true) end })
  return buttons
end

-- CreateSearchBox makes the vendor's own search box: it searches the vendor's items
-- (NextMerchant:Search), not the bags, and makes no search category from what is typed.
---@return table
function vendorProto:CreateSearchBox()
  local frame = CreateFrame("Frame", nil, self.frame)
  local textBox = CreateFrame("EditBox", nil, frame, "BagSearchBoxTemplate")
  textBox:SetAllPoints()
  textBox:SetAutoFocus(false)
  if textBox.Instructions then
    textBox.Instructions:SetText(L:G("Search Vendor"))
  end
  textBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
  textBox:SetScript("OnTextChanged", function()
    self:ApplySearch()
  end)
  return { frame = frame, textBox = textBox }
end

-- UpdateSearchShown keeps the vendor's search box shown: the in-bag search setting is the bags'.
function vendorProto:UpdateSearchShown()
  self.searchBox.frame:Show()
end

-- ApplySearch dims what the search box leaves out: by the vendor's index on Buy, by name elsewhere.
function vendorProto:ApplySearch()
  local text = self.searchBox.textBox:GetText() or ""
  local results = self.tab == TAB_BUY and merchant:Search(text) or nil
  local needle = text:lower()
  for key, button in pairs(self.buttons) do
    local match = true
    if text ~= "" then
      if button.mode == "buy" then
        match = results ~= nil and results[key] == true
      else
        local entry = button.buyback or button.repair
        local name = entry and (entry.name or (entry.link and entry.link:match("%[(.-)%]"))) or ""
        match = name:lower():find(needle, 1, true) ~= nil
      end
    end
    button:SetSearchMatch(match)
  end
end

-- UpdateHeader shows what the vendor offers and enables what can be done: the filter (retail,
-- unless a game rule turns it off), the repair buttons at a vendor that repairs (the guild's when
-- the guild pays), Sell Junk with junk in the bags.
function vendorProto:UpdateHeader()
  if self.filterButton then
    local disabled = C_GameRules and C_GameRules.IsGameRuleActive and Enum.GameRule
      and Enum.GameRule.MerchantFilterDisabled and C_GameRules.IsGameRuleActive(Enum.GameRule.MerchantFilterDisabled)
    self.filterButton:SetShown(not disabled)
  end
  local canRepair = CanMerchantRepair()
  local _, anything = GetRepairAllCost()
  self.repairAllButton:SetShown(canRepair)
  self.guildRepairButton:SetShown(canRepair and CanGuildBankRepair())
  self:setEnabled(self.repairAllButton, anything)
  self:setEnabled(self.guildRepairButton, anything)
  self:setEnabled(self.sellJunkButton, merchant:NumJunk() > 0)
  self:LayoutHeader()
  self:fitTitle()
end

-- fitTitle keeps the vendor's name (any length) on one line in the room right of the shown header
-- buttons, cut short rather than over them.
---@private
function vendorProto:fitTitle()
  local shown = 0
  for _, button in ipairs(self.headerButtons) do
    if button:IsShown() then
      shown = shown + 1
    end
  end
  local buttons = shown * 22 + math.max(0, shown - 1) * 8
  self.title:SetWordWrap(false)
  self.title:SetWidth(style.BODY_WIDTH - (style.PAD + 4) - (style.PAD + buttons) - 12)
end

---@private
---@param button Button
---@param enabled boolean
function vendorProto:setEnabled(button, enabled)
  button:SetEnabled(enabled and true or false)
  button.icon:SetDesaturated(not enabled)
end

-- RefreshTabs lists Buy and Buyback, and Repair at a vendor that repairs.
function vendorProto:RefreshTabs()
  local entries = { { id = TAB_BUY, name = L:G("Buy") }, { id = TAB_BUYBACK, name = L:G("Buyback") } }
  if CanMerchantRepair() then
    table.insert(entries, { id = TAB_REPAIR, name = L:G("Repair") })
  end
  self.tabs:SetTabs(entries)
  self.tabs:Select(self.tab)
  self.tabs.frame:Show()
end

---@param ctx Context
---@param id number
---@param button string
function vendorProto:OnTabClicked(ctx, id, button)
  if button == "RightButton" or id == self.tab then
    return
  end
  self.tab = id
  self.tabs:Select(id, true)
  self.tabChanged = true
  self:Draw(ctx)
end

---@return number
function vendorProto:GetCurrentTabID()
  return self.tab
end

-- OnShowing sets the vendor up as it opens: its name, the Buy tab, its tabs and header, and a draw
-- once it shows.
---@param ctx Context
function vendorProto:OnShowing(ctx)
  local _ = ctx
  self:SetTitle(UnitName("npc") or L:G("Vendor"))
  self.tab = TAB_BUY
  self:RefreshTabs()
  self:UpdateHeader()
  self.lastSlotInfo = self.lastSlotInfo or {}
  self.drawPendingOnShow = true
end

-- OnMerchantShow opens the vendor (MERCHANT_SHOW), resetting the filter as Blizzard's merchant
-- frame does on every open.
---@param ctx Context
function vendorProto:OnMerchantShow(ctx)
  self.atMerchant = true
  self.closeRequested = false
  if ResetSetMerchantFilter then
    ResetSetMerchantFilter()
  end
  self:Show(ctx)
end

-- OnMerchantClosed hides the vendor (MERCHANT_CLOSED), puts the cursor back and closes Blizzard's
-- purchase prompts, as Blizzard's merchant frame does when it hides.
---@param ctx Context
function vendorProto:OnMerchantClosed(ctx)
  self.atMerchant = false
  self.closeRequested = false
  ResetCursor()
  for _, which in ipairs(PROMPTS) do
    StaticPopup_Hide(which)
  end
  self:Hide(ctx)
end

-- Hide slides the panel out, ending the vendor visit at once when the panel is what closes.
---@param ctx Context
function vendorProto:Hide(ctx)
  nextPanel.proto.Hide(self, ctx)
  if self.atMerchant and not self.closeRequested then
    self.closeRequested = true
    CloseMerchant()
  end
end

-- EndVisitLater ends the vendor visit a frame later, when it is still open then: for a hide from
-- Blizzard's own code (Escape, the panel manager), which must not run ours.
function vendorProto:EndVisitLater()
  if not self.atMerchant or self.closeRequested then
    return
  end
  C_Timer.After(0, function()
    if self.atMerchant and not self.closeRequested then
      self.closeRequested = true
      CloseMerchant()
    end
  end)
end

-- OnHidden ends the vendor visit a frame later when the panel hid some other way than closing
-- (Escape hides it directly).
---@param ctx Context
function vendorProto:OnHidden(ctx)
  nextPanel.proto.OnHidden(self, ctx)
  self:EndVisitLater()
end

-- Activate has nothing to catch up on: BetterBags Next is switched only away from a vendor, and
-- the next vendor that opens draws everything (OnShowing).
---@param ctx Context
function vendorProto:Activate(ctx)
  local _ = ctx
end

-- OnClosed does nothing: the vendor has no Recent Items.
---@param ctx Context
function vendorProto:OnClosed(ctx)
  local _ = ctx
end

-- Refresh draws again while shown.
---@param ctx Context
function vendorProto:Refresh(ctx)
  if self.frame:IsShown() then
    self:Draw(ctx)
  end
end

-- button returns this draw's button for a key: the last draw's when it had one, else a new one.
---@private
---@param key string
---@param previous table<string, NextVendorButtonFrame>
---@return NextVendorButtonFrame
function vendorProto:button(key, previous)
  local b = previous[key]
  if b ~= nil then
    previous[key] = nil
  else
    b = vendorButton:Acquire()
  end
  self.buttons[key] = b
  return b
end

-- buildBuy builds the Buy tab: the vendor's items in the backpack's categories, and the player's
-- gold and the vendor's currencies for the footer.
---@private
---@param ctx Context
---@param previous table<string, NextVendorButtonFrame>
---@return NextCanvasSection[] sections, string footer, string empty
function vendorProto:buildBuy(ctx, previous)
  local sections = {}
  for _, s in ipairs(merchant:BuildSections(merchant:ReadItems(ctx))) do
    local buttons = {}
    for _, item in ipairs(s.items) do
      local b = self:button("vendor:" .. item.index, previous)
      b:SetBuy(item)
      table.insert(buttons, b)
    end
    table.insert(sections, { name = s.name, buttons = buttons })
  end
  local footer = C_CurrencyInfo.GetCoinTextureString(GetMoney())
  if C_MerchantFrame and C_MerchantFrame.GetMerchantCurrencies then
    local parts = {}
    for _, id in ipairs(C_MerchantFrame.GetMerchantCurrencies() or {}) do
      local info = C_CurrencyInfo.GetCurrencyInfo(id)
      if info then
        table.insert(parts, "|T" .. info.iconFileID .. ":0|t " .. info.quantity)
      end
    end
    if #parts > 0 then
      footer = footer .. "   " .. table.concat(parts, "  ")
    end
  end
  return sections, footer, L:G("This vendor sells nothing")
end

-- buildBuyback builds the Buyback tab: what was sold, newest first.
---@private
---@param previous table<string, NextVendorButtonFrame>
---@return NextCanvasSection[] sections, string footer, string empty
function vendorProto:buildBuyback(previous)
  local buttons = {}
  for _, entry in ipairs(merchant:ReadBuyback()) do
    local b = self:button("buyback:" .. entry.index, previous)
    b:SetBuyback(entry)
    table.insert(buttons, b)
  end
  local sections = {}
  if #buttons > 0 then
    sections[1] = { name = L:G("Sold"), buttons = buttons }
  end
  return sections, "", L:G("Nothing sold yet")
end

-- buildRepair builds the Repair tab: what is worn, then what is in the bags, that needs repair,
-- and what repairing it all costs for the footer.
---@private
---@param previous table<string, NextVendorButtonFrame>
---@return NextCanvasSection[] sections, string footer, string empty
function vendorProto:buildRepair(previous)
  local repair = merchant:ReadRepair()
  local sections, total = {}, 0
  for _, part in ipairs({ { L:G("Equipped"), repair.equipped }, { L:G("In your bags"), repair.bags } }) do
    local buttons = {}
    for _, entry in ipairs(part[2]) do
      local key = entry.bag and ("repair:" .. entry.bag .. ":" .. entry.slot) or ("repair:" .. entry.slot)
      local b = self:button(key, previous)
      b:SetRepair(entry)
      table.insert(buttons, b)
      total = total + (entry.cost or 0)
    end
    if #buttons > 0 then
      table.insert(sections, { name = part[1], buttons = buttons })
    end
  end
  local footer = total > 0 and (L:G("Repair all: ") .. C_CurrencyInfo.GetCoinTextureString(total)) or ""
  return sections, footer, L:G("Nothing needs repair")
end

-- Draw draws the tab shown, keeping each button that is drawn again; a draw while hidden waits
-- for Show.
---@param ctx Context
---@param _? table
---@param callback? fun()
function vendorProto:Draw(ctx, _, callback)
  if not self.frame:IsShown() then
    self.lastSlotInfo = self.lastSlotInfo or {}
    self.drawPendingOnShow = true
    if callback then
      callback()
    end
    return
  end
  local previous = self.buttons
  self.buttons = {}
  local sections, footer, empty
  if self.tab == TAB_BUYBACK then
    sections, footer, empty = self:buildBuyback(previous)
  elseif self.tab == TAB_REPAIR then
    sections, footer, empty = self:buildRepair(previous)
  else
    sections, footer, empty = self:buildBuy(ctx, previous)
  end
  self.content:BindSections(sections)
  for _, b in pairs(previous) do
    b:Release()
  end
  render:RenderNow(self.root, { ctx = ctx })
  self.freeText:SetText(footer)
  self.emptyText:SetText(empty)
  self.emptyText:SetShown(#sections == 0)
  if not self.opening then
    self.content:Cascade(self.tabChanged)
  end
  self.tabChanged = false
  self:ApplySearch()
  if callback then
    callback()
  end
end

-- Wipe lets go of every button and section.
---@param ctx Context
function vendorProto:Wipe(ctx)
  local _ = ctx
  self.content:Release()
  for _, b in pairs(self.buttons) do
    b:Release()
  end
  self.buttons = {}
end

-- SellCursorItem sells the item on the cursor, as dropping it on Blizzard's merchant frame does
-- (its OnMouseUp): Blizzard asks first about a refundable item.
function vendorProto:SellCursorItem()
  if not CursorHasItem() then
    return
  end
  if MerchantFrame and MerchantFrame.refundItem
    and ContainerFrame_GetExtendedPriceString(MerchantFrame.refundItem, MerchantFrame.refundItemEquipped) then
    return
  end
  PickupMerchantItem(0)
end

---@return string
function vendorProto:PlaceCursorItem()
  self:SellCursorItem()
  return "sold"
end

---@param section NextSection
function vendorProto:OnHeaderDragStart(section)
  local _ = section
end

---@param section NextSection
function vendorProto:OnHeaderDragStop(section)
  local _ = section
end

---@param ctx Context
---@param section NextSection
---@param button string
function vendorProto:OnHeaderClick(ctx, section, button)
  local _, _, _ = ctx, section, button
  self:SellCursorItem()
end

---@param ctx Context
---@param section NextSection
function vendorProto:OnHeaderReceiveDrag(ctx, section)
  local _, _ = ctx, section
  self:SellCursorItem()
end

---@param section NextSection
function vendorProto:OnHeaderEnter(section)
  GameTooltip:SetOwner(section.header, "ANCHOR_RIGHT")
  GameTooltip:SetText(section.name, 1, 1, 1, 1, true)
  GameTooltip:Show()
end

-- SaleOf returns what of a backpack section dropped on the vendor sells: every item and every pile
-- its virtual stack hides (sectionFrame:WithStacks, what Move Categories sells), in the backpack's
-- bags, once each, leaving out what the vendor does not buy (hasNoValue) and refundable purchases,
-- which Blizzard asks about before refunding them (ContainerFrame_GetExtendedPriceString).
---@param list ItemData[]
---@return ItemData[]
function vendorProto:SaleOf(list)
  local sale, seen = {}, {}
  for _, data in ipairs(sectionFrame:WithStacks(list)) do
    local bag, slot = data.bagid, data.slotid
    local key = bag .. "_" .. slot
    if not seen[key] and const.BACKPACK_BAGS[bag] ~= nil then
      seen[key] = true
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.hasNoValue and not C_Item.CanBeRefunded(ItemLocation:CreateFromBagAndSlot(bag, slot)) then
        table.insert(sale, data)
      end
    end
  end
  return sale
end

-- Sell sells a section's sale while the vendor is open: at once when buyback can keep all of it,
-- after asking past that. It returns "sold", or "asked" while the question is open.
---@param ctx Context
---@param sale ItemData[]
---@return string
function vendorProto:Sell(ctx, sale)
  local _ = ctx
  local slots = {}
  for _, data in ipairs(sale) do
    table.insert(slots, { bag = data.bagid, slot = data.slotid })
  end
  local function sell()
    merchant:SellSlots(slots, function() return self.atMerchant end)
  end
  if #slots <= BUYBACK_KEEPS then
    sell()
    return "sold"
  end
  question:YesNo(L:G("Sell Items"),
    format(L:G("Sell %d items? Only the last 12 items sold can be bought back."), #slots), sell, function() end)
  return "asked"
end

-- SellJunk sells the junk in the bags: through Blizzard's own Sell All Junk where the client has
-- it (its confirmation included), else after asking, a few rounds a moment apart.
function vendorProto:SellJunk()
  if merchant:HasSellAllJunk() then
    merchant:SellAllJunk()
    return
  end
  local n = merchant:NumJunk()
  if n == 0 then
    return
  end
  question:YesNo(L:G("Sell Junk"),
    format(L:G("Sell %d junk items? Only the last 12 items sold can be bought back."), n),
    function() self:sellJunkRound(SELL_ROUNDS) end, function() end)
end

---@private
---@param rounds number
function vendorProto:sellJunkRound(rounds)
  if not self.atMerchant then
    return
  end
  local slots = merchant:JunkSlots()
  if #slots == 0 then
    return
  end
  merchant:SellSlots(slots, function() return self.atMerchant end)
  if rounds > 1 then
    C_Timer.After(SELL_DELAY, function()
      self:sellJunkRound(rounds - 1)
    end)
  end
end

-- RepairAll repairs everything, from the guild bank with guild, as Blizzard's repair buttons do.
---@param guild boolean
function vendorProto:RepairAll(guild)
  if guild and not CanGuildBankRepair() then
    return
  end
  merchant:RepairAll(guild)
  PlaySound(SOUNDKIT.ITEM_REPAIR)
  GameTooltip:Hide()
end

-- RepairTooltip tells what repairing everything costs, and who pays: the player's money, or the
-- guild's up to what the player may withdraw (Blizzard's repair buttons' tooltips).
---@param guild boolean
function vendorProto:RepairTooltip(guild)
  local cost, canRepair = GetRepairAllCost()
  if not canRepair or cost <= 0 then
    GameTooltip:AddLine(L:G("Nothing needs repair"), 1, 1, 1)
    return
  end
  GameTooltip:AddLine(L:G("Repair all: ") .. C_CurrencyInfo.GetCoinTextureString(cost), 1, 1, 1)
  if guild then
    local amount = GetGuildBankWithdrawMoney()
    local funds = GetGuildBankMoney()
    if amount == -1 then
      amount = funds
    else
      amount = math.min(amount, funds)
    end
    GameTooltip:AddLine(L:G("The guild pays up to ") .. C_CurrencyInfo.GetCoinTextureString(amount), 0.8, 0.8, 0.8)
  elseif cost > GetMoney() then
    GameTooltip:AddLine(L:G("You do not have enough money"), 1, 0.25, 0.25)
  end
end

-- OpenFilter opens Blizzard's merchant filters as a menu (MerchantFrame_OnLoad's): each spec, the
-- class, Bind on Equip, everything.
function vendorProto:OpenFilter()
  local function isSelected(filter)
    return GetMerchantFilter() == filter
  end
  local function setSelected(filter)
    SetMerchantFilter(filter)
  end
  MenuUtil.CreateContextMenu(self.filterButton, function(_, root)
    root:SetTag("MENU_MERCHANT_FRAME")
    for index = 1, GetNumSpecializations() do
      local _, name = C_SpecializationInfo.GetSpecializationInfo(index)
      root:CreateRadio(name, isSelected, setSelected, LE_LOOT_FILTER_SPEC1 + index - 1)
    end
    root:CreateRadio(L:G("All Specializations"), isSelected, setSelected, LE_LOOT_FILTER_CLASS)
    root:CreateDivider()
    root:CreateRadio(L:G("Bind on Equip"), isSelected, setSelected, LE_LOOT_FILTER_BOE)
    root:CreateRadio(L:G("All"), isSelected, setSelected, LE_LOOT_FILTER_ALL)
  end)
end

-- WatchKind follows the vendor: it opens and closes with it, draws again when what it sells or
-- what the player has changes, and when item data arrives.
function vendorProto:WatchKind()
  events:RegisterEvent("MERCHANT_SHOW", function(ctx) self:OnMerchantShow(ctx) end)
  events:RegisterEvent("MERCHANT_CLOSED", function(ctx) self:OnMerchantClosed(ctx) end)
  events:RegisterEvent("MERCHANT_UPDATE", function(ctx) self:Refresh(ctx) end)
  events:RegisterEvent("MERCHANT_FILTER_ITEM_UPDATE", function(ctx) self:Refresh(ctx) end)
  for _, event in ipairs({ "UPDATE_INVENTORY_DURABILITY", "PLAYER_MONEY", "BAG_UPDATE_DELAYED" }) do
    events:RegisterEvent(event, function(ctx)
      if self.frame:IsShown() then
        self:UpdateHeader()
        self:Draw(ctx)
      end
    end)
  end
  if C_MerchantFrame and C_MerchantFrame.GetMerchantCurrencies then
    events:RegisterEvent("CURRENCY_DISPLAY_UPDATE", function(ctx) self:Refresh(ctx) end)
  end
  events:BucketEvent("GET_ITEM_INFO_RECEIVED", function(ctx) self:Refresh(ctx) end, function()
    return self.frame:IsShown()
  end)
end

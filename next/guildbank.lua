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

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class GuildBank: AceModule
local guildBank = addon:GetModule('GuildBank')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextPanel: AceModule
local nextPanel = addon:GetModule('NextPanel')

---@class NextGuildButton: AceModule
local guildButton = addon:GetModule('NextGuildButton')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class NextDrag: AceModule
local nextDrag = addon:GetModule('NextDrag')

-- NextGuildBank is BetterBags Next's guild bank (guild-bank.md §5): a panel on the left, as the
-- bank's, that stands in for Blizzard's guild bank frame while BetterBags Next is on. It shows every
-- tab's items in the categories the bags use (All Tabs), or a tab by itself, its slots in order (the
-- bank's Bank Tabs mode); its slots are the guild bank's own buttons (NextGuildButton). Its header
-- deposits and withdraws gold with Blizzard's own dialogs; its tabs are bought there too ("+", the
-- guild leader) and renamed by a right click. Blizzard's guild bank frame stays shown but is never
-- seen (TakeOver): Blizzard ends the visit when its frame is not visible right after showing it, and
-- when it hides.
---@class NextGuildBank: AceModule
---@field panel? NextGuildBankPanel
---@field active boolean It holds Blizzard's guild bank frame (BetterBags Next is in use).
---@field hidden? Frame The hidden frame Blizzard's guild bank frame is put under.
---@field tiny? Frame Shown and a thousandth of the size: where the frame waits out Blizzard's visibility check.
---@field hookedShow boolean ShowUIPanel is hooked (once: a hook cannot be taken off).
---@field hookedFrame? Frame The guild bank frame whose Hide is hooked (once).
---@field taken? Frame The frame taken, until given back.
---@field savedOnHide? function|false The frame's own OnHide, taken off while it is taken.
local nextGuildBank = addon:NewModule('NextGuildBank')

nextGuildBank.active = false
nextGuildBank.hookedShow = false

-- Blizzard's guild bank dialogs, closed when the visit ends (GuildBankFrameMixin:OnHide).
local DIALOGS = { "GUILDBANK_DEPOSIT", "GUILDBANK_WITHDRAW", "CONFIRM_BUY_GUILDBANK_TAB" }

---@class NextGuildBankPanel: NextPanelFrame
---@field closeButton Button
---@field settingsButton Button
---@field depositButton Button
---@field withdrawButton Button
---@field shownTab? number The container of the tab shown by itself, nil while every tab shows.
---@field closeRequested boolean It asked the guild bank to close.
---@field wipeWhenHidden boolean The visit ended while the panel slid out: let go of its buttons once hidden.
local guildProto = nextPanel:Extend({}, 'NextGuildBankPanel')

---@param ctx Context
---@return NextGuildBankPanel
function nextGuildBank:Create(ctx)
  local _ = ctx
  ---@type NextGuildBankPanel
  local g = nextPanel:Create(guildProto, {
    kind = const.BAG_KIND.GUILD,
    side = "LEFT",
    name = "BetterBagsNextGuildBank",
    scrollName = "BetterBagsNextGuildBankScroll",
    title = L:G("Guild Bank"),
    openSound = SOUNDKIT.GUILD_VAULT_OPEN,
    closeSound = SOUNDKIT.GUILD_VAULT_CLOSE,
    chainRole = "companion",
  })
  g.closeRequested = false
  g.wipeWhenHidden = false
  g.content:SetButtonSource(guildButton)
  g:paintWash(style.Color.GuildWash)
  self.panel = g
  return g
end

-- TakeOver makes Blizzard's guild bank frame, whenever it is shown (ShowUIPanel), stay shown and
-- never be seen. Blizzard's ShowGuildBankFrame ends the visit when the frame is not visible right
-- after ShowUIPanel, so the frame first goes under a tiny shown frame; its OnHide (which ends the
-- visit) is taken off, and a frame later it goes under hidden, as Bagnon does
-- (core/features/uiOverrides.lua). Whatever hides it during a visit (another panel opening on the
-- left) ends the visit a frame later, as its OnHide did. The frame is load on demand: nothing exists
-- to take until the guild bank first opens.
---@param hidden Frame
function nextGuildBank:TakeOver(hidden)
  self.hidden = hidden
  self.active = true
  if self.hookedShow then
    return
  end
  self.hookedShow = true
  hooksecurefunc("ShowUIPanel", function(frame)
    self:OnShowUIPanel(frame)
  end)
end

---@private
---@return Frame
function nextGuildBank:tinyFrame()
  if self.tiny == nil then
    self.tiny = CreateFrame("Frame", nil, UIParent)
    self.tiny:SetScale(0.001)
  end
  return self.tiny
end

-- OnShowUIPanel takes Blizzard's guild bank frame as it is shown, while BetterBags Next is in use.
---@param frame? Frame
function nextGuildBank:OnShowUIPanel(frame)
  if not self.active or frame == nil or frame ~= _G.GuildBankFrame then
    return
  end
  if self.hookedFrame ~= frame then
    self.hookedFrame = frame
    hooksecurefunc(frame, "Hide", function()
      if self.active and self.panel then
        self.panel:EndVisitLater()
      end
    end)
  end
  if self.taken ~= frame then
    self.taken = frame
    self.savedOnHide = frame:GetScript("OnHide") or false
  end
  frame:SetScript("OnHide", nil)
  local tiny = self:tinyFrame()
  frame:SetParent(tiny)
  C_Timer.After(0, function()
    if self.active and frame:GetParent() == tiny then
      frame:SetParent(self.hidden)
    end
  end)
end

-- GiveBack returns Blizzard's guild bank frame to UIParent, with its OnHide, when BetterBags Next is
-- switched off (next.md §11; switching is refused at the guild bank). The hooks stay and do nothing.
function nextGuildBank:GiveBack()
  self.active = false
  local frame = self.taken
  if frame == nil then
    return
  end
  self.taken = nil
  frame:SetParent(UIParent)
  if self.savedOnHide then
    frame:SetScript("OnHide", self.savedOnHide)
  end
  self.savedOnHide = nil
end

---@return NextHeaderButton[]
function guildProto:GetHeaderButtons()
  return {
    { key = "closeButton", atlas = "uitools-icon-close", tooltip = L:G("Close"),
      onClick = function(ctx) self:Hide(ctx) end },
    { key = "settingsButton", atlas = "uitools-icon-settings", tooltip = L:G("Open Options Screen"),
      onClick = function(ctx) events:SendMessage(ctx, "config/Open") end },
    { key = "depositButton", texture = "Interface\\Icons\\INV_Misc_Coin_01", tooltip = L:G("Deposit Gold"),
      onClick = function() guildBank:DepositMoney() end },
    { key = "withdrawButton", texture = "Interface\\Icons\\INV_Misc_Coin_02",
      tooltipFunc = function() self:WithdrawTooltip() end, onClick = function() guildBank:WithdrawMoney() end },
  }
end

-- WithdrawTooltip tells how much gold the player may take today: what the guild allows them, at most
-- what the guild has (GetGuildBankWithdrawMoney is -1 for the guild leader: the whole balance).
function guildProto:WithdrawTooltip()
  GameTooltip:SetText(L:G("Withdraw Gold"), 1, 1, 1, 1, true)
  if not CanWithdrawGuildBankMoney() then
    GameTooltip:AddLine(L:G("You may not withdraw gold from this guild bank"), 1, 0.25, 0.25, true)
    return
  end
  local amount, funds = GetGuildBankWithdrawMoney(), GetGuildBankMoney()
  if amount == -1 then
    amount = funds
  else
    amount = math.min(amount, funds)
  end
  GameTooltip:AddLine(L:G("You may withdraw up to ") .. C_CurrencyInfo.GetCoinTextureString(amount), 0.8, 0.8, 0.8, true)
end

-- CreateMoney makes the footer's gold: the guild's.
---@return table
function guildProto:CreateMoney()
  local frame = CreateFrame("Frame")
  frame:SetSize(200, 16)
  local text = frame:CreateFontString(nil, "OVERLAY")
  text:SetFontObject(style:Font("Footer"))
  text:SetPoint("LEFT", frame, "LEFT", 0, 0)
  return {
    frame = frame,
    text = text,
    Update = function()
      text:SetText(C_CurrencyInfo.GetCoinTextureString(GetGuildBankMoney() or 0))
    end,
  }
end

-- UpdateHeader enables what the player may do: withdrawing gold only for a member who may.
function guildProto:UpdateHeader()
  local enabled = CanWithdrawGuildBankMoney() and true or false
  self.withdrawButton:SetEnabled(enabled)
  self.withdrawButton.icon:SetDesaturated(not enabled)
end

---@return number
function guildProto:GetCurrentTabID()
  return self.shownTab or const.GUILD_BANK_ALL_TAB
end

-- InTabMode is whether a tab shows by itself (its slots in order, the Show Bags view).
---@return boolean
function guildProto:InTabMode()
  return self.shownTab ~= nil
end

-- ShownTab is the guild bank tab shown by itself, nil while every tab shows.
---@return number?
function guildProto:ShownTab()
  return self.shownTab and guildBank:TabOf(self.shownTab) or nil
end

---@param info GuildBankTabInfo
---@return string
local function accessOf(info)
  local canWithdraw = info.numWithdrawals ~= 0
  if info.canDeposit and canWithdraw then
    return GUILDBANK_TAB_FULL_ACCESS
  elseif info.canDeposit then
    return GUILDBANK_TAB_DEPOSIT_ONLY
  elseif canWithdraw then
    return GUILDBANK_TAB_WITHDRAW_ONLY
  end
  return GUILDBANK_TAB_LOCKED
end

-- ShowTabTooltip tells what a tab is: its name, what the player may do in it (Blizzard's words), how
-- many stacks they may still take today, and what clicks do.
---@param info GuildBankTabInfo
function guildProto:ShowTabTooltip(info)
  GameTooltip:SetText(info.name, 1, 1, 1, 1, true)
  GameTooltip:AddLine(accessOf(info), 0.4, 1.0, 0.5, true)
  if info.numWithdrawals ~= 0 then
    local left = info.remainingWithdrawals == -1 and L:G("Unlimited")
      or format(L:G("%d stacks"), info.remainingWithdrawals)
    GameTooltip:AddLine(format(L:G("Withdrawals left today: %s"), left), 1, 1, 1, true)
  end
  GameTooltip:AddLine(L:G("Left-click to view this tab"), 0.8, 0.8, 0.8, true)
  if CanEditGuildBankTabInfo(info.tab) then
    GameTooltip:AddLine(L:G("Right-click to rename this tab"), 0.8, 0.8, 0.8, true)
  end
end

-- RefreshTabs lists All Tabs, then every tab the player can view, then "+" while the guild leader can
-- buy one, and selects the one shown.
function guildProto:RefreshTabs()
  local entries = { { id = const.GUILD_BANK_ALL_TAB, name = L:G("All Tabs") } }
  local first = true
  for _, info in ipairs(guildBank:Tabs()) do
    if info.viewable then
      table.insert(entries, {
        id = info.container,
        name = info.name,
        icon = info.icon,
        accent = style.Color.Guild,
        gap = first and style.TAB_GROUP_GAP or nil,
        tooltip = function()
          self:ShowTabTooltip(info)
        end,
      })
      first = false
    end
  end
  if guildBank:CanBuyTab() then
    table.insert(entries, {
      id = 0,
      name = "+",
      tooltip = { L:G("Buy a Guild Bank Tab"), L:G("Click to buy the guild's next tab") },
    })
  end
  self.tabs:SetTabs(entries)
  self.tabs:Select(self:GetCurrentTabID())
  self.tabs.frame:Show()
end

-- viewable says whether a tab's container is a tab the player can view now.
---@param container number
---@return boolean
local function viewable(container)
  local tab = guildBank:TabOf(container)
  local info = tab and guildBank:TabInfo(tab)
  return info ~= nil and info.viewable
end

-- firstViewable is the container of the first tab the player can view.
---@return number?
local function firstViewable()
  for _, info in ipairs(guildBank:Tabs()) do
    if info.viewable then
      return info.container
    end
  end
  return nil
end

-- updateTitle titles the panel with the tab shown, else the guild's name.
---@private
function guildProto:updateTitle()
  local tab = self:ShownTab()
  local info = tab and guildBank:TabInfo(tab)
  if info then
    self:SetTitle(info.name)
    return
  end
  self:SetTitle(GetGuildInfo("player") or L:G("Guild Bank"))
end

-- useView sets the guild bank's view to the one its mode shows: a tab by itself in slot order (the
-- Show Bags view), or every tab's items in categories.
---@private
function guildProto:useView()
  database:SetBagView(self.kind, self.shownTab and const.BAG_VIEW.SECTION_ALL_BAGS or const.BAG_VIEW.SECTION_GRID)
end

-- shown draws the view just chosen: the title, the tab selected, and a recalculation of the guild
-- bank with a fresh layout, which draws it.
---@private
---@param ctx Context
function guildProto:shown(ctx)
  self:updateTitle()
  self.tabs:Select(self:GetCurrentTabID(), true)
  self.tabChanged = true
  events:SendMessage(ctx, 'bags/Rederive', { guild = true, resetLayout = true })
end

-- ShowAll shows every tab's items in categories.
---@param ctx Context
function guildProto:ShowAll(ctx)
  self.shownTab = nil
  database:SetShowGuildBankTabs(false)
  self:useView()
  self:shown(ctx)
end

-- ShowTab shows a tab by itself, made the guild bank's current tab (where deposits go, as on
-- Blizzard's frame) and queried again, as Blizzard's tab click does.
---@param ctx Context
---@param container number
function guildProto:ShowTab(ctx, container)
  self.shownTab = container
  database:SetShowGuildBankTabs(true)
  self:useView()
  guildBank:LoadTab(guildBank:TabOf(container))
  self:shown(ctx)
end

-- OnTabClicked runs a click on a tab: "+" buys a tab, a right click renames one, a left click shows
-- All Tabs or a tab by itself.
---@param ctx Context
---@param id number
---@param button string
function guildProto:OnTabClicked(ctx, id, button)
  if id == 0 then
    guildBank:BuyTab()
    return
  end
  if button == "RightButton" then
    if id ~= const.GUILD_BANK_ALL_TAB then
      self:RenameTab(guildBank:TabOf(id))
    end
    return
  end
  if id == self:GetCurrentTabID() then
    return
  end
  if id == const.GUILD_BANK_ALL_TAB then
    self:ShowAll(ctx)
  else
    self:ShowTab(ctx, id)
  end
end

-- RenameTab asks a member who may edit the guild's tabs for a tab's new name, keeping its icon.
---@param tab number
function guildProto:RenameTab(tab)
  local info = guildBank:TabInfo(tab)
  if info == nil or not CanEditGuildBankTabInfo(tab) then
    return
  end
  question:AskForInput(L:G("Rename Tab"), format(L:G("A new name for %s"), info.name), function(text)
    if text ~= nil and text ~= "" then
      SetGuildBankTabInfo(tab, text, info.icon)
    end
  end)
end

-- OnShowing sets the guild bank up as it opens: the tab shown by itself last time (the guild bank's
-- current tab, else the first the player can view) or every tab, the tabs, the header and the gold,
-- and the guild bank's last read data drawn once the panel shows.
---@param ctx Context
function guildProto:OnShowing(ctx)
  local _ = ctx
  self.closeRequested = false
  self.wipeWhenHidden = false
  self.shownTab = nil
  if database:GetShowGuildBankTabs() then
    local container = guildBank:ContainerOf(guildBank:CurrentTab())
    if not viewable(container) then
      container = firstViewable()
    end
    self.shownTab = container
  end
  self:useView()
  self:SetWash("GuildWash")
  self:RefreshTabs()
  self:updateTitle()
  self:UpdateHeader()
  self.moneyFrame:Update()
  self.lastSlotInfo = items:GetAllSlotInfo()[self.kind]
  self.drawPendingOnShow = true
end

-- Hide slides the panel out, ending the visit at once when the panel is what closes.
---@param ctx Context
function guildProto:Hide(ctx)
  nextPanel.proto.Hide(self, ctx)
  if addon.atGuildBank and not self.closeRequested then
    self.closeRequested = true
    guildBank:Close()
  end
end

-- EndVisitLater ends the visit a frame later, when it is still open then: for a hide from Blizzard's
-- own code (Escape, the panel manager hiding its frame), which must not run ours.
function guildProto:EndVisitLater()
  if not addon.atGuildBank or self.closeRequested then
    return
  end
  C_Timer.After(0, function()
    if addon.atGuildBank and not self.closeRequested then
      self.closeRequested = true
      guildBank:Close()
    end
  end)
end

-- OnHidden ends the visit a frame later when the panel hid some other way than closing (Escape), and
-- lets go of its buttons when the visit ended while it slid out.
---@param ctx Context
function guildProto:OnHidden(ctx)
  nextPanel.proto.OnHidden(self, ctx)
  self:EndVisitLater()
  if self.wipeWhenHidden then
    self.wipeWhenHidden = false
    self:Wipe(ctx)
  end
end

-- OnGuildBankClosed runs when the visit ends (guildbank/Closed): Blizzard's guild bank dialogs close,
-- as its frame's OnHide closed them, and the panel slides out, letting go of its buttons once out.
---@param ctx Context
function guildProto:OnGuildBankClosed(ctx)
  self.closeRequested = false
  for _, which in ipairs(DIALOGS) do
    StaticPopup_Hide(which)
  end
  if self.frame:IsShown() and not self.closing then
    self:Hide(ctx)
  end
  if self.closing then
    self.wipeWhenHidden = true
  else
    self:Wipe(ctx)
  end
end

-- WatchKind follows the guild bank: its tabs (names, permissions, a tab bought), its gold, and the end
-- of the visit.
function guildProto:WatchKind()
  events:RegisterMessage('guildbank/TabsChanged', function(ctx)
    self:OnTabsChanged(ctx)
  end)
  events:RegisterMessage('guildbank/MoneyChanged', function()
    self.moneyFrame:Update()
    self:UpdateHeader()
  end)
  events:RegisterMessage('guildbank/Closed', function(ctx)
    self:OnGuildBankClosed(ctx)
  end)
end

-- OnTabsChanged lists the tabs again, going back to every tab when the one shown is gone or closed to
-- the player.
---@param ctx Context
function guildProto:OnTabsChanged(ctx)
  self:RefreshTabs()
  if self.shownTab ~= nil and not viewable(self.shownTab) then
    self:ShowAll(ctx)
    self:RefreshTabs()
    return
  end
  self:updateTitle()
end

-- Refresh recalculates the guild bank from what was last read (nothing while it is closed).
---@param ctx Context
function guildProto:Refresh(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { guild = true })
end

-- DepositTab is the tab a section dropped on the guild bank goes into: the tab shown by itself, else
-- the guild bank's current tab (where Blizzard's frame deposits), when the player may deposit there.
---@return number?
function guildProto:DepositTab()
  local tab = self:ShownTab() or guildBank:CurrentTab()
  local info = tab and guildBank:TabInfo(tab)
  if info == nil or not info.viewable or not info.canDeposit then
    return nil
  end
  return tab
end

-- CanDepositIn says whether a tab's container is a tab the player may deposit in.
---@param container number
---@return boolean
function guildProto:CanDepositIn(container)
  local tab = guildBank:TabOf(container)
  local info = tab and guildBank:TabInfo(tab)
  return info ~= nil and info.viewable and info.canDeposit
end

-- Deposit puts a backpack section into a tab (the one dropped on, else DepositTab): every item and
-- every pile its virtual stack hides (SectionFrame:WithStacks), in the backpack's bags, leaving out
-- bound items, which the guild bank does not take. Into a tab the player cannot withdraw from (those
-- items cannot be taken back) it deposits only once confirmed: unconfirmed it returns "confirm" with
-- what to confirm with, and NextDrag docks the section in the guild bank until a double click. It
-- returns "deposited", "confirm" or "nothing".
---@param ctx Context
---@param list ItemData[]
---@param container? number
---@param confirmed? boolean
---@return string result
---@return NextConfirmation? confirmation
function guildProto:Deposit(ctx, list, container, confirmed)
  local _ = ctx
  local tab
  if container ~= nil then
    tab = self:CanDepositIn(container) and guildBank:TabOf(container) or nil
  else
    tab = self:DepositTab()
  end
  if tab == nil then
    return "nothing"
  end
  local slots, seen = {}, {}
  for _, data in ipairs(sectionFrame:WithStacks(list)) do
    local key = data.bagid .. "_" .. data.slotid
    if not seen[key] and const.BACKPACK_BAGS[data.bagid] ~= nil and not (data.itemInfo and data.itemInfo.isBound) then
      seen[key] = true
      table.insert(slots, { bag = data.bagid, slot = data.slotid })
    end
  end
  if #slots == 0 then
    return "nothing"
  end
  local info = guildBank:TabInfo(tab)
  if info.numWithdrawals == 0 and not confirmed then
    return "confirm", {
      title = format(L:G("Deposit %d items?"), #slots),
      warning = format(L:G("You cannot take them back out of %s."), info.name),
      hint = L:G("Double-click to deposit · Right-click to cancel"),
    }
  end
  guildBank:DepositSlots(slots, tab)
  return "deposited"
end

-- Withdraw moves a guild section into the bags: every item and every pile its virtual stack hides.
---@param list ItemData[]
---@return number
function guildProto:Withdraw(list)
  return guildBank:WithdrawItems(sectionFrame:WithStacks(list))
end

-- OnHeaderClick passes an item clicked onto a header to the guild bank (Shift: to the category), and
-- takes a section out to the bags on a right click (the bank's right click moves it to the open
-- window; the guild bank's open window is the bags).
---@param ctx Context
---@param section NextSection
---@param button string
function guildProto:OnHeaderClick(ctx, section, button)
  if CursorHasItem() or button ~= "RightButton" then
    nextPanel.proto.OnHeaderClick(self, ctx, section, button)
    return
  end
  if section.kind ~= "free" then
    self:Withdraw(nextDrag:SectionItems(section))
  end
end

-- OnHeaderEnter tells what a guild section's header does.
---@param section NextSection
function guildProto:OnHeaderEnter(section)
  if nextDrag:IsActive() then
    return
  end
  GameTooltip:SetOwner(section.header, "ANCHOR_RIGHT")
  GameTooltip:SetText(section.name, 1, 1, 1, 1, true)
  if section.kind == "category" then
    GameTooltip:AddLine(L:G("Drag to reorder, or onto the backpack to take it out."), 0.8, 0.8, 0.8, true)
  end
  if section.kind ~= "free" then
    GameTooltip:AddLine(L:G("Right-click to take it out to your bags."), 0.8, 0.8, 0.8, true)
  end
  GameTooltip:Show()
end

-- PlaceCursorItem puts the item held into the tab shown by itself, else the guild bank's current tab
-- (where Blizzard's frame deposits).
---@return string
function guildProto:PlaceCursorItem()
  return guildBank:PlaceCursorItem(self:ShownTab())
end

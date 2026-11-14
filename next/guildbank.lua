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

---@class NextMenuButtonModule: AceModule
local nextMenuButton = addon:GetModule('NextMenuButton')

---@class NextGuildButton: AceModule
local guildButton = addon:GetModule('NextGuildButton')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class NextDrag: AceModule
local nextDrag = addon:GetModule('NextDrag')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class Render: AceModule
local render = addon:GetModule('Render')

---@class Texels: AceModule
local texels = addon:GetModule('Texels')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

---@class NextVendorButton: AceModule
local vendorButton = addon:GetModule('NextVendorButton')

---@class NextInput: AceModule
local nextInput = addon:GetModule('NextInput')

---@class NextButton: AceModule
local nextButton = addon:GetModule('NextButton')

---@class SearchBox: AceModule
local searchBox = addon:GetModule('SearchBox')

---@class Search: AceModule
local search = addon:GetModule('Search')

-- The footer's gold, 16 tall: its text centered in it by the font's height (docs/next-pixel-perfect.md).
local MONEY_WIDTH, MONEY_HEIGHT = 200, 16

-- The guild bank's views, at its rail's foot (asked: "maybe tabs for this on the bottom of the rail instead of the
-- top?"): its items, and Blizzard's Log, Money Log and Info tabs (GuildBankFrameTabMixin:OnClick).
local VIEW_ITEMS, VIEW_LOG, VIEW_MONEY, VIEW_INFO = -1, -2, -3, -4

-- A tab's info text: as tall as the settings' text areas, and as long as Blizzard's Info tab lets it be
-- (GuildBankTabInfoEditBox, letters="500").
local INFO_HEIGHT, INFO_LETTERS = 120, 500

-- The money log's cards show a coin.
local MONEY_ICON = "Interface\\Icons\\INV_Misc_Coin_01"

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
---@field depositGoldButton Button
---@field withdrawGoldButton Button
---@field shownTab? number The container of the tab shown by itself, nil while every tab shows.
---@field closeRequested boolean It asked the guild bank to close.
---@field wipeWhenHidden boolean The visit ended while the panel slid out: let go of its buttons once hidden.
---@field off? boolean Switched off (Deactivate): it follows no visit, Blizzard's guild bank frame shows the guild bank.
---@field view number The view shown, chosen at the rail's foot: VIEW_ITEMS, VIEW_LOG, VIEW_MONEY or VIEW_INFO.
---@field logCards table<string, NextVendorButtonFrame> The log's cards this draw drew, by key.
---@field infoBlocks table<number, NextGuildInfoBlock> Each tab's info text, made the first time it shows.
---@field logMoney? number The guild's gold when the money log was last asked for.
local guildProto = nextPanel:Extend({}, 'NextGuildBankPanel')

-- A tab's info text in the Info view: the canvas holds it as a section's block (NextCanvasBlock), a text area that a
-- member who may edit it types in and saves, read only for the others.
---@class (exact) NextGuildInfoBlock: NextCanvasBlock
---@field tab number
---@field area NextTextAreaFrame
---@field save NextButtonFrame
---@field loaded string The text last received: Save saves only a change from it, and a text that arrives replaces the box's only while it still holds this.
---@field editable boolean This member may edit it.
---@field forgotten? boolean The visit it was shown in ended: its text stays on screen as the panel slides out, and is replaced whatever it holds the next time it shows.

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
    standIn = "GuildBankFrame",
  })
  g.closeRequested = false
  g.wipeWhenHidden = false
  g.view = VIEW_ITEMS
  g.logCards = {}
  g.infoBlocks = {}
  g.content:SetButtonSource(guildButton)
  g:SetWash("Guild", true)
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
    { key = "closeButton", tooltip = L:G("Close"), onClick = function(ctx) self:Hide(ctx) end },
    { key = "settingsButton", tooltip = L:G("Open Options Screen"), menuLast = true,
      onClick = function(ctx) events:SendMessage(ctx, "config/Open") end },
    { key = "depositGoldButton", tooltip = L:G("Deposit Gold"), onClick = function() guildBank:DepositMoney() end },
    { key = "withdrawGoldButton", tooltipFunc = function() self:WithdrawTooltip() end, label = L:G("Withdraw Gold"),
      menuTooltip = function() return self:WithdrawText() end,
      onClick = function() guildBank:WithdrawMoney() end },
  }
end

-- WithdrawLines tells how much gold the player may take today: what the guild allows them, at most what the guild has
-- (GetGuildBankWithdrawMoney is -1 for the guild leader: the whole balance), or that they may take none; each line
-- { text, r, g, b }.
---@return table[]
function guildProto:WithdrawLines()
  if not CanWithdrawGuildBankMoney() then
    return { { L:G("You may not withdraw gold from this guild bank"), 1, 0.25, 0.25 } }
  end
  local amount, funds = GetGuildBankWithdrawMoney(), GetGuildBankMoney()
  if amount == -1 then
    amount = funds
  else
    amount = math.min(amount, funds)
  end
  return { { L:G("You may withdraw up to ") .. GetMoneyString(amount, true), 0.8, 0.8, 0.8 } }
end

-- WithdrawTooltip is the withdraw gold button's tooltip: its name, then WithdrawLines.
function guildProto:WithdrawTooltip()
  GameTooltip:SetText(L:G("Withdraw Gold"), 1, 1, 1, 1, true)
  for _, line in ipairs(self:WithdrawLines()) do
    GameTooltip:AddLine(line[1], line[2], line[3], line[4], true)
  end
end

-- WithdrawText is WithdrawLines as the bag button's menu entry's tooltip (Header.Buttons.Menu).
---@return string
function guildProto:WithdrawText()
  return nextMenuButton:Text(self:WithdrawLines())
end

-- CreateMoney makes the footer's gold: the guild's.
---@return table
function guildProto:CreateMoney()
  local frame = CreateFrame("Frame")
  local text = style:CreateText(frame, style.Theme.Footer.MoneyFont)
  local money = {
    frame = frame,
    text = text,
    Update = function()
      text:SetText(GetMoneyString(GetGuildBankMoney() or 0, true))
    end,
  }
  -- Placed by its owner (styleFooter, on the panel's grid): by its top left, in whole pixels.
  money.Place = function()
    pixel:Size(frame, MONEY_WIDTH, MONEY_HEIGHT)
    local _, fontHeight = text:GetFont()
    text:ClearAllPoints()
    pixel:Point(text, "TOPLEFT", frame, "TOPLEFT", 0, -pixel:Floor(frame, (frame:GetHeight() - (fontHeight or 0)) / 2))
  end
  return money
end

-- UpdateHeader enables what the player may do: withdrawing gold only for a member who may.
function guildProto:UpdateHeader()
  self:SetHeaderButtonEnabled(self.withdrawGoldButton, CanWithdrawGuildBankMoney() and true or false)
end

---@return number
-- TabOrderKey saves the order of the guild's tabs.
---@return string
function guildProto:TabOrderKey()
  return "guild"
end

-- OnTabsReordered saves the order a tab was moved to, as every panel does; a log or Info lists the tabs in it.
---@param ctx Context
---@param ids number[]
function guildProto:OnTabsReordered(ctx, ids)
  nextPanel.proto.OnTabsReordered(self, ctx, ids)
  if self.view ~= VIEW_ITEMS then
    self:DrawView(ctx)
  end
end

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

-- viewEntries are the views at the rail's foot: Items, then Blizzard's Log, Money Log and Info, in Blizzard's words.
---@return NextTabEntry[]
local function viewEntries()
  return {
    { id = VIEW_ITEMS, name = L:G("Items"), foot = true, fixed = true,
      tooltip = { L:G("Items"), L:G("The guild bank's items") } },
    { id = VIEW_LOG, name = GUILD_BANK_LOG, foot = true, fixed = true,
      tooltip = { GUILD_BANK_LOG, L:G("Who deposited, withdrew and moved items") } },
    { id = VIEW_MONEY, name = GUILD_BANK_MONEY_LOG, foot = true, fixed = true,
      tooltip = { GUILD_BANK_MONEY_LOG, L:G("Who deposited and withdrew the guild's gold") } },
    { id = VIEW_INFO, name = GUILD_BANK_TAB_INFO, foot = true, fixed = true,
      tooltip = { GUILD_BANK_TAB_INFO, L:G("What each tab is for") } },
  }
end

-- isView says whether a tab's id is one of the views at the rail's foot.
---@param id number
---@return boolean
local function isView(id)
  return id == VIEW_ITEMS or id == VIEW_LOG or id == VIEW_MONEY or id == VIEW_INFO
end

-- RefreshTabs lists All Tabs, then every tab the player can view, then "+" while the guild leader can
-- buy one, and the views at the rail's foot, and selects the tab and the view shown.
function guildProto:RefreshTabs()
  local entries = { { id = const.GUILD_BANK_ALL_TAB, name = L:G("All Tabs"), block = "all" } }
  local tabs = {}
  for _, info in ipairs(guildBank:Tabs()) do
    if info.viewable then
      table.insert(tabs, {
        id = info.container,
        name = info.name,
        icon = info.icon,
        accent = "Guild",
        block = "guild",
        tooltip = function()
          self:ShowTabTooltip(info)
        end,
      })
    end
  end
  for i, entry in ipairs(self:OrderedTabs(tabs)) do
    entry.gap = i == 1 and style.TAB_GROUP_GAP or nil
    table.insert(entries, entry)
  end
  if guildBank:CanBuyTab() then
    table.insert(entries, {
      id = 0,
      name = "+",
      fixed = true,
      tooltip = { L:G("Buy a Guild Bank Tab"), L:G("Click to buy the guild's next tab") },
    })
  end
  for _, entry in ipairs(viewEntries()) do
    table.insert(entries, entry)
  end
  self.tabs:SetTabs(entries)
  self.tabs:Select(self:GetCurrentTabID())
  self.tabs:SelectFoot(self.view)
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

-- shown draws the tab just chosen: the title, the tab selected, and a recalculation of the guild
-- bank with a fresh layout, which draws it; in a log or Info, what it shows of the tab, asked of the server again as
-- Blizzard's tab click asks (GuildBankTabMixin:OnClick).
---@private
---@param ctx Context
function guildProto:shown(ctx)
  self:updateTitle()
  self.tabs:Select(self:GetCurrentTabID(), true)
  self.tabChanged = true
  events:SendMessage(ctx, 'bags/Rederive', { guild = true, resetLayout = true })
  if self.view ~= VIEW_ITEMS then
    self:loadView()
    self:DrawView(ctx)
  end
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

-- OnTabClicked runs a click on a tab: a view at the rail's foot shows it, "+" buys a tab, a right click renames one, a
-- left click shows All Tabs or a tab by itself.
---@param ctx Context
---@param id number
---@param button string
function guildProto:OnTabClicked(ctx, id, button)
  if isView(id) then
    if button ~= "RightButton" and id ~= self.view then
      self:ShowView(ctx, id)
    end
    return
  end
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

-- OnShowing sets the guild bank up as it opens: its items, as Blizzard's frame opens on its own (GuildBankFrameMixin:OnShow),
-- the tab shown by itself last time (the guild bank's current tab, else the first the player can view) or every tab, the
-- tabs, the header and the gold, and the guild bank's last read data drawn once the panel shows.
---@param ctx Context
function guildProto:OnShowing(ctx)
  local _ = ctx
  self.closeRequested = false
  self.wipeWhenHidden = false
  if self.view ~= VIEW_ITEMS then
    self.content:BindSections({})
    self:releaseCards()
  end
  self.view = VIEW_ITEMS
  self.content:SetCards(false)
  self.shownTab = nil
  if database:GetShowGuildBankTabs() then
    local container = guildBank:ContainerOf(guildBank:CurrentTab())
    if not viewable(container) then
      container = firstViewable()
    end
    self.shownTab = container
  end
  self:useView()
  self:SetWash("Guild")
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
  -- Now, not once the panel is out (Wipe): the guild bank can open again while it slides out.
  self:forgetInfo()
  if self.frame:IsShown() and not self.closing then
    self:Hide(ctx)
  end
  if self.closing then
    self.wipeWhenHidden = true
  else
    self:Wipe(ctx)
  end
end

-- WatchKind follows the guild bank: its tabs (names, permissions, a tab bought), its gold, its logs and info text, and
-- the end of the visit. Switched off, it neither switches its tabs nor closes Blizzard's dialogs: Blizzard's guild bank
-- frame shows the visit.
function guildProto:WatchKind()
  events:RegisterMessage('guildbank/TabsChanged', function(ctx)
    if not self.off then
      self:OnTabsChanged(ctx)
    end
  end)
  events:RegisterMessage('guildbank/MoneyChanged', function()
    self.moneyFrame:Update()
    self:UpdateHeader()
    -- The money log shown follows the gold (Blizzard's asks only on a click): asked again when the gold changed, not
    -- the member's withdrawal limit (GUILDBANK_UPDATE_WITHDRAWMONEY says the same message).
    if self:shows(VIEW_MONEY) and GetGuildBankMoney() ~= self.logMoney then
      self.logMoney = GetGuildBankMoney()
      guildBank:LoadLogs({ guildBank:MoneyLogID() })
    end
  end)
  events:RegisterMessage('guildbank/LogLoaded', function(ctx, id)
    if self:shows(VIEW_MONEY) and id == guildBank:MoneyLogID() or self:shows(VIEW_LOG) and self:viewsTab(id) then
      self:DrawView(ctx)
    end
  end)
  events:RegisterMessage('guildbank/LogChanged', function(ctx)
    if self:shows(VIEW_LOG) or self:shows(VIEW_MONEY) then
      self:DrawView(ctx)
    end
  end)
  events:RegisterMessage('guildbank/TextLoaded', function(ctx, tab)
    if self:shows(VIEW_INFO) and self:viewsTab(tab) then
      self:DrawView(ctx)
    end
  end)
  events:RegisterMessage('guildbank/Closed', function(ctx)
    if not self.off then
      self:OnGuildBankClosed(ctx)
    end
  end)
end

-- shows says whether the panel, on and shown, shows a view.
---@private
---@param view number
---@return boolean
function guildProto:shows(view)
  return not self.off and self.view == view and self.frame:IsShown()
end

-- Deactivate switches the guild bank off, with BetterBags Next or by itself (Enable Guild Bank Window, next-bagsystem.md §11g): it
-- hides at once and lets go of its buttons, and follows no visit until Activate.
---@param ctx Context
function guildProto:Deactivate(ctx)
  self.off = true
  nextPanel.proto.Deactivate(self, ctx)
end

-- Activate switches the guild bank on again, catching up as every panel does.
---@param ctx Context
function guildProto:Activate(ctx)
  self.off = false
  nextPanel.proto.Activate(self, ctx)
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
  -- A log or Info names the tabs, and shows what the player may do in them; a tab come into view (bought, or opened to
  -- the player's rank) is asked for.
  if self.view ~= VIEW_ITEMS then
    self:loadMissing()
    self:DrawView(ctx)
  end
end

-- Refresh recalculates the guild bank from what was last read (nothing while it is closed).
---@param ctx Context
function guildProto:Refresh(ctx)
  events:SendMessage(ctx, 'bags/Rederive', { guild = true, categoriesUnchanged = true })
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

-- OnHeaderDragStart picks a guild section up, in Items: a log's and Info's sections are no items.
---@param section NextSection
function guildProto:OnHeaderDragStart(section)
  if self.view == VIEW_ITEMS then
    nextPanel.proto.OnHeaderDragStart(self, section)
  end
end

-- OnHeaderReceiveDrag puts an item dropped on a log's or Info's header into the guild bank, as a drop on the panel does.
---@param ctx Context
---@param section NextSection
function guildProto:OnHeaderReceiveDrag(ctx, section)
  if self.view ~= VIEW_ITEMS then
    self:PlaceCursorItem()
    return
  end
  nextPanel.proto.OnHeaderReceiveDrag(self, ctx, section)
end

-- OnHeaderClick passes an item clicked onto a header to the guild bank (Shift: to the category), and
-- takes a section out to the bags on a right click (the bank's right click moves it to the open
-- window; the guild bank's open window is the bags). A log's and Info's sections hold no items: an item
-- clicked onto one goes into the guild bank, as a drop on the panel does.
---@param ctx Context
---@param section NextSection
---@param button string
function guildProto:OnHeaderClick(ctx, section, button)
  if self.view ~= VIEW_ITEMS then
    if CursorHasItem() then
      self:PlaceCursorItem()
    end
    return
  end
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
  if self.view ~= VIEW_ITEMS then
    GameTooltip:Show()
    return
  end
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

-- ShowView shows a view chosen at the rail's foot: the guild bank's items, drawn again from the last read (a read waits
-- while another view shows, Draw), or a log or the tabs' info text, asked of the server as it shows, as Blizzard's tab
-- click asks every time. Nothing travels from one view to the next.
---@param ctx Context
---@param view number
function guildProto:ShowView(ctx, view)
  local was = self.view
  self.view = view
  self.tabs:SelectFoot(view, true)
  self.tabChanged = true
  motion:ForgetShown(self.content)
  if view == VIEW_ITEMS then
    self.content:BindSections({})
    self:releaseCards()
    self.content:SetCards(false)
    self:Draw(ctx, self.lastSlotInfo or {})
    self:searchItems(ctx)
    return
  end
  if was == VIEW_ITEMS then
    self:releaseItems(ctx)
  else
    self:releaseFocus()
  end
  self:loadView()
  self:DrawView(ctx)
end

-- searchItems dims the items drawn by what the search box holds now, as the box does when typed in (SearchBox): they were
-- drawn from the last read, its search as it was then.
---@private
---@param ctx Context
function guildProto:searchItems(ctx)
  local text = searchBox:GetSearchText(self.kind)
  if text == nil or text == "" then
    nextPanel.proto.ResetSearch(self, ctx)
  else
    nextPanel.proto.Search(self, ctx, search:Search(text))
  end
end

-- viewTabs are the tabs a log or Info shows: the tab shown by itself, else every tab the player can view, in the order the
-- rail lists them (the player's).
---@private
---@return number[]
function guildProto:viewTabs()
  local shown = self:ShownTab()
  if shown ~= nil then
    return { shown }
  end
  local tabs = {}
  for _, t in ipairs(self.tabs.tabs) do
    local tab = not t.foot and guildBank:TabOf(t.id) or nil
    if tab ~= nil and viewable(t.id) then
      table.insert(tabs, tab)
    end
  end
  return tabs
end

-- viewsTab says whether a log or Info shows a tab.
---@private
---@param tab? number
---@return boolean
function guildProto:viewsTab(tab)
  for _, t in ipairs(self:viewTabs()) do
    if t == tab then
      return true
    end
  end
  return false
end

-- loadView asks the server for what the view shows: the tabs' item logs (Log), the money log (Money Log), or the tabs'
-- info text (Info).
---@private
function guildProto:loadView()
  if self.view == VIEW_LOG then
    guildBank:LoadLogs(self:viewTabs())
  elseif self.view == VIEW_MONEY then
    self.logMoney = GetGuildBankMoney()
    guildBank:LoadLogs({ guildBank:MoneyLogID() })
  elseif self.view == VIEW_INFO then
    guildBank:LoadTexts(self:viewTabs())
  end
end

-- loadMissing asks for the logs or texts of the tabs shown that this visit has not received: the tabs changed (a tab
-- bought, or opened to the player's rank). What is still being asked for stays asked for (LoadLogs takes the place of
-- what was still to ask, and those are among the missing).
---@private
function guildProto:loadMissing()
  local loaded = self.view == VIEW_LOG and guildBank.IsLogLoaded or self.view == VIEW_INFO and guildBank.IsTextLoaded or nil
  if loaded == nil then
    return
  end
  local missing = {}
  for _, tab in ipairs(self:viewTabs()) do
    if not loaded(guildBank, tab) then
      table.insert(missing, tab)
    end
  end
  if #missing == 0 then
    return
  end
  if self.view == VIEW_LOG then
    guildBank:LoadLogs(missing)
  else
    guildBank:LoadTexts(missing)
  end
end

-- tabName is a tab's name as the guild bank names it.
---@private
---@param tab? number
---@return string
function guildProto:tabName(tab)
  local info = tab and guildBank:TabInfo(tab)
  return info and info.name or format(GUILDBANK_TAB_NUMBER, tab or 0)
end

-- releaseItems lets go of the guild bank's buttons the last draw of its items drew: another view shows.
---@private
---@param ctx Context
function guildProto:releaseItems(ctx)
  self.content:BindSections({})
  for item in pairs(self.drawnButtons) do
    item:Release(ctx)
  end
  self.drawnButtons = {}
end

-- releaseFocus lets go of the focus a tab's info text has: its box is hidden or drawn again.
---@private
function guildProto:releaseFocus()
  for _, block in pairs(self.infoBlocks) do
    block.area.editBox:ClearFocus()
  end
end

-- releaseCards lets go of the log's cards, and of the info text's focus.
---@private
function guildProto:releaseCards()
  for _, c in pairs(self.logCards) do
    c:Release()
  end
  self.logCards = {}
  self:releaseFocus()
end

-- card returns this draw's card for a key: the last draw's when it had one, else a new one.
---@private
---@param key string
---@param previous table<string, NextVendorButtonFrame>
---@return NextVendorButtonFrame
function guildProto:card(key, previous)
  local c = previous[key]
  if c ~= nil then
    previous[key] = nil
  else
    c = vendorButton:Acquire()
  end
  self.logCards[key] = c
  return c
end

-- itemCard is how a card shows an item log entry: the item and its stack, its name, who deposited, withdrew or moved it,
-- and in its tooltip how many, which tab and how long ago.
---@private
---@param entry GuildBankLogEntry
---@param when string
---@return NextLogCard
function guildProto:itemCard(entry, when)
  local who = entry.name or UNKNOWN
  local line, where
  if entry.kind == "deposit" then
    line, where = format(L:G("Deposited by %s"), who), format(L:G("Into %s"), self:tabName(entry.tab))
  elseif entry.kind == "withdraw" then
    line, where = format(L:G("Withdrawn by %s"), who), format(L:G("Out of %s"), self:tabName(entry.tab))
  else
    line = format(L:G("Moved by %s"), who)
    where = format(L:G("From %s to %s"), self:tabName(entry.from), self:tabName(entry.to))
  end
  local lines = { line }
  if (entry.count or 1) > 1 then
    table.insert(lines, format(L:G("Count: %d"), entry.count))
  end
  table.insert(lines, where)
  table.insert(lines, when)
  local icon, quality
  if entry.link ~= nil then
    icon = select(5, C_Item.GetItemInfoInstant(entry.link))
    quality = select(3, C_Item.GetItemInfo(entry.link))
  end
  return { key = "log:" .. entry.tab .. ":" .. entry.index, texture = icon, count = entry.count, quality = quality,
    title = entry.link and entry.link:match("%[(.-)%]") or UNKNOWN, line = line, link = entry.link, lines = lines,
    onDrop = function() self:PlaceCursorItem() end }
end

-- moneyCard is how a card shows a money log entry: a coin, who did what with the gold (each of Blizzard's money log's
-- kinds, GuildBankFrame_UpdateMoneyLog), how much, and in its tooltip how long ago.
---@private
---@param entry GuildBankLogEntry
---@param when string
---@return NextLogCard
function guildProto:moneyCard(entry, when)
  local who, kind = entry.name or UNKNOWN, entry.kind
  local title
  if kind == "deposit" then
    title = format(L:G("%s deposited"), who)
  elseif kind == "withdraw" then
    title = format(L:G("%s withdrew"), who)
  elseif kind == "repair" then
    title = format(L:G("%s repaired"), who)
  elseif kind == "withdrawForTab" then
    title = format(L:G("%s withdrew for a tab"), who)
  elseif kind == "buyTab" and entry.amount > 0 then
    title = format(L:G("%s bought a tab"), who)
  elseif kind == "buyTab" then
    title = format(L:G("%s unlocked a tab"), who)
  elseif kind == "depositSummary" then
    title = L:G("Guild perks deposited")
  elseif kind == "buyRename" then
    title = format(L:G("%s renamed the guild"), who)
  elseif kind == "refundRename" then
    title = format(L:G("%s was refunded a guild rename"), who)
  else
    title = who
  end
  return { key = "money:" .. entry.index, texture = MONEY_ICON, title = title, amount = entry.amount,
    lines = { title .. " " .. GetMoneyString(entry.amount, true), when },
    onDrop = function() self:PlaceCursorItem() end }
end

-- buildLog builds the Log (every tab shown's item log, newest first across them) or the Money Log: a card an entry, in
-- sections by how long ago, in Blizzard's words (TimeUtil.GetRecentTimeDate), and what to say when none shows.
---@private
---@param previous table<string, NextVendorButtonFrame>
---@return NextCanvasSection[] sections, string empty
function guildProto:buildLog(previous)
  local entries, loading = {}, false
  if self.view == VIEW_MONEY then
    loading = not guildBank:IsLogLoaded(guildBank:MoneyLogID())
    if not loading then
      entries = guildBank:MoneyLog()
    end
  else
    local tabs = self:viewTabs()
    if #tabs == 0 then
      return {}, L:G("This guild has no tabs you can view")
    end
    for _, tab in ipairs(tabs) do
      if guildBank:IsLogLoaded(tab) then
        for _, entry in ipairs(guildBank:ItemLog(tab)) do
          table.insert(entries, entry)
        end
      else
        loading = true
      end
    end
    table.sort(entries, function(a, b)
      if a.age ~= b.age then
        return a.age < b.age
      end
      if a.tab ~= b.tab then
        return a.tab < b.tab
      end
      return a.index > b.index
    end)
  end
  local sections, byName = {}, {}
  for _, entry in ipairs(entries) do
    local when = format(L:G("%s ago"), TimeUtil.GetRecentTimeDate(entry.years, entry.months, entry.days, entry.hours))
    local section = byName[when]
    if section == nil then
      section = { name = when, buttons = {} }
      byName[when] = section
      table.insert(sections, section)
    end
    local spec = self.view == VIEW_MONEY and self:moneyCard(entry, when) or self:itemCard(entry, when)
    local c = self:card(spec.key, previous)
    c:SetLog(spec)
    table.insert(section.buttons, c)
  end
  if loading then
    return sections, L:G("Loading...")
  end
  return sections, self.view == VIEW_MONEY and L:G("No gold has moved yet") or L:G("Nothing logged yet")
end

-- infoBlock is a tab's info text as the Info view shows it (made the first time): a text area, as tall as the settings'
-- (INFO_HEIGHT) and as long as Blizzard's lets it be, and for a member who may edit it a Save button under it, as a
-- settings page puts its Primary button under its text area.
---@private
---@param tab number
---@return NextGuildInfoBlock
function guildProto:infoBlock(tab)
  local block = self.infoBlocks[tab]
  if block ~= nil then
    return block
  end
  local frame = CreateFrame("Frame")
  ---@type NextGuildInfoBlock
  block = { tab = tab, frame = frame, loaded = "", editable = false }
  block.area = nextInput:CreateArea(frame, { height = INFO_HEIGHT, maxLetters = INFO_LETTERS,
    help = L:G("Nothing written for this tab yet") })
  block.save = nextButton:Create(frame, { text = L:G("Save"), style = "Primary", onClick = function()
    self:SaveInfo(block)
  end })
  block.Height = function(b)
    if not b.editable then
      return INFO_HEIGHT
    end
    return INFO_HEIGHT + style.GAP + b.save.frame:GetHeight()
  end
  block.Layout = function(b, width)
    frame:SetSize(width, b:Height(width))
    local area, save = b.area.frame, b.save.frame
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    area:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    save:ClearAllPoints()
    pixel:Point(save, "TOPLEFT", area, "BOTTOMLEFT", 0, -style.GAP)
  end
  self.infoBlocks[tab] = block
  return block
end

-- refreshInfo shows a tab's info text as the client last received it, unless the box holds what a member who may edit it
-- typed and did not save, and whether this member may edit it (one who no longer may sees the tab's own text again).
---@private
---@param block NextGuildInfoBlock
function guildProto:refreshInfo(block)
  local text = guildBank:Text(block.tab)
  block.editable = guildBank:CanEditText(block.tab)
  if block.forgotten or block.area:GetText() == block.loaded or not block.editable then
    block.area:SetText(text)
  end
  block.forgotten = nil
  block.loaded = text
  block.area:SetReadOnly(not block.editable)
  block.save.frame:SetShown(block.editable)
end

-- SaveInfo saves what a member who may edit a tab's info text typed, as Blizzard's Info tab's Save button does
-- (SetGuildBankText, only when the text changed).
---@param block NextGuildInfoBlock
function guildProto:SaveInfo(block)
  local text = block.area:GetText()
  block.area.editBox:ClearFocus()
  if not block.editable or text == block.loaded then
    return
  end
  if guildBank:SaveText(block.tab, text) then
    block.loaded = text
  end
end

-- buildInfo builds Info: a section a tab shown, named after it (two tabs named alike told apart by their number: the
-- canvas keeps its sections by name), its text its block, its header saying Loading... until it arrives.
---@private
---@return NextCanvasSection[] sections, string empty
function guildProto:buildInfo()
  local tabs = self:viewTabs()
  if #tabs == 0 then
    return {}, L:G("This guild has no tabs you can view")
  end
  -- A name two tabs share, or one a tab told apart is given, is told apart by the tab's number (each tab's is its own).
  local function count(names)
    local n = {}
    for _, name in pairs(names) do
      n[name] = (n[name] or 0) + 1
    end
    return n
  end
  local names = {}
  for _, tab in ipairs(tabs) do
    names[tab] = self:tabName(tab)
  end
  local raw = count(names)
  for _, tab in ipairs(tabs) do
    if raw[names[tab]] > 1 then
      names[tab] = format(L:G("%s (tab %d)"), self:tabName(tab), tab)
    end
  end
  local told = count(names)
  for _, tab in ipairs(tabs) do
    if told[names[tab]] > 1 and names[tab] == self:tabName(tab) then
      names[tab] = format(L:G("%s (tab %d)"), self:tabName(tab), tab)
    end
  end
  local sections = {}
  for _, tab in ipairs(tabs) do
    local block = self:infoBlock(tab)
    self:refreshInfo(block)
    table.insert(sections, { name = names[tab], block = block,
      count = guildBank:IsTextLoaded(tab) and "" or L:G("Loading...") })
  end
  return sections, ""
end

-- DrawView draws a log (cards, as the vendor's) or Info (each tab's text a section's block), keeping each card drawn
-- again, and the footer counting the log's entries; nothing while hidden (the guild bank opens on its items).
---@param ctx Context
function guildProto:DrawView(ctx)
  if not self.frame:IsShown() or self.view == VIEW_ITEMS then
    return
  end
  local previous = self.logCards
  self.logCards = {}
  local sections, empty, footer
  if self.view == VIEW_INFO then
    sections, empty = self:buildInfo()
    footer = ""
  else
    sections, empty = self:buildLog(previous)
    local n = 0
    for _ in pairs(self.logCards) do
      n = n + 1
    end
    footer = format(L:G("%d entries"), n)
  end
  self.content:SetCards(self.view ~= VIEW_INFO)
  self.content:BindSections(sections)
  for _, c in pairs(previous) do
    c:Release()
  end
  -- Before it is laid out: how narrow a small panel goes keeps room for its footer (MinWidth), and it follows what it
  -- shows first (FollowNames).
  self.freeText:SetText(footer)
  self:FollowNames()
  render:RenderNow(self.root, { ctx = ctx })
  texels:Unsharpen(self.frame)
  self.emptyText:SetText(empty)
  self.emptyText:SetShown(#sections == 0)
  if not self.opening then
    self.content:Cascade(self.tabChanged)
  end
  self.tabChanged = false
  self:applyLogSearch()
end

-- Draw draws the guild bank's items as every panel draws its kind's; while a log or Info shows, the read is kept for
-- when its items show again (ShowView).
---@param ctx Context
---@param slotInfo SlotInfo
---@param callback? fun()
function guildProto:Draw(ctx, slotInfo, callback)
  if self.view ~= VIEW_ITEMS then
    self.lastSlotInfo = slotInfo
    if callback then
      callback()
    end
    return
  end
  nextPanel.proto.Draw(self, ctx, slotInfo, callback)
end

-- Wipe tears the drawing down, the log's cards too, and forgets the tabs' info text.
---@param ctx Context
function guildProto:Wipe(ctx)
  nextPanel.proto.Wipe(self, ctx)
  self:releaseCards()
  self:forgetInfo()
end

-- forgetInfo forgets the tabs' info text, what was typed and not saved too: the next visit shows what the server sends.
-- What shows stays on screen as the panel slides out (refreshInfo replaces it).
---@private
function guildProto:forgetInfo()
  for _, block in pairs(self.infoBlocks) do
    block.area.editBox:ClearFocus()
    block.forgotten = true
  end
end

-- Search dims the guild bank's items the search leaves out; in a log, the cards whose words do not hold what is typed,
-- as the vendor's Buyback and Repair tabs dim theirs by name.
---@param ctx Context
---@param results table<string, boolean>
function guildProto:Search(ctx, results)
  if self.view == VIEW_ITEMS then
    nextPanel.proto.Search(self, ctx, results)
    return
  end
  self:applyLogSearch()
end

---@param ctx Context
function guildProto:ResetSearch(ctx)
  if self.view == VIEW_ITEMS then
    nextPanel.proto.ResetSearch(self, ctx)
    return
  end
  self:applyLogSearch()
end

-- applyLogSearch dims the log's cards whose title and tooltip do not hold the search box's text.
---@private
function guildProto:applyLogSearch()
  local needle = (self.searchBox.textBox:GetText() or ""):lower()
  for _, c in pairs(self.logCards) do
    local log = c.log
    local match = needle == "" or log.title:lower():find(needle, 1, true) ~= nil
    for _, line in ipairs(log.lines) do
      match = match or line:lower():find(needle, 1, true) ~= nil
    end
    c:SetSearchMatch(match)
  end
end

-- SectionColumns lays a log and Info out in one column (a log's cards across it), and the items as the guild bank is set.
---@return number count, string? fill, boolean? span, number? wideRows, boolean? compact
function guildProto:SectionColumns()
  if self.view ~= VIEW_ITEMS then
    return 1
  end
  return nextPanel.proto.SectionColumns(self)
end

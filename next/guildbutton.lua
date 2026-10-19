local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Color: AceModule
local color = addon:GetModule('Color')

---@class GuildBank: AceModule
local guildBank = addon:GetModule('GuildBank')

---@class ItemFrame: AceModule
local itemFrame = addon:GetModule('ItemFrame')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class SonataElements: AceModule
local elements = addon:GetModule('SonataElements')

-- NextGuildButton is a slot of BetterBags Next's guild bank (guild-bank.md §5). A guild bank slot is
-- not a bag slot: the container item buttons made at boot read their bag and slot (cooldowns,
-- new-item flags, junk, Blizzard's clicks), so a guild slot is Blizzard's own guild bank item button
-- instead, made the way Blizzard makes it: the ItemButton intrinsic on retail and WoW: Forever,
-- ItemButtonTemplate on Classic (Blizzard_GuildBankUI Mainline and TBC XML). It is drawn from the
-- data engine's ItemData as a bag button is (icon, count, quality and BetterBags' glow, item level,
-- upgrade arrow, search), and its clicks are Blizzard's guild bank item button's
-- (GuildBankItemButtonMixin) on the item's own tab. Nothing it calls is protected. It has the
-- methods of an item button that BetterBags Next's canvas and panels call (next/content.lua): the
-- canvas takes the guild bank's buttons from this module (GetButton).
---@class NextGuildButton: AceModule
---@field pool NextGuildButtonFrame[] Released buttons.
---@field bySlotkey table<string, NextGuildButtonFrame> The button of each slot, until released.
local guildButton = addon:NewModule('NextGuildButton')

-- Blizzard's art for an empty slot: the combined bags' slot background on retail
-- (ItemSlotBackgroundCombinedBagsTemplate, Mainline ContainerFrame.xml), the backpack's empty slot on
-- Classic (what item buttons draw, item-drawing.md §6).
local SLOT_BACKGROUND = "Interface\\ContainerFrame\\UI-Bag-Components"
local SLOT_BACKGROUND_COORDS = { 0.64453125, 0.7890625, 0.42578125, 0.498046875 }
local CLASSIC_EMPTY_SLOT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

---@class NextGuildButtonFrame
---@field slotkey? string
---@field frame Button What the canvas places: the item button itself.
---@field button Button The item button.
---@field itemLevel FontString
---@field upgrade Texture Blizzard's upgrade arrow (ContainerFrameItemButtonTemplate's UpgradeIcon).
---@field slotBackground Texture The empty slot's art on retail.
---@field data? ItemData The guild item it shows.
---@field free? table The Free Space entry it shows.
---@field isFreeSlot? boolean
---@field tab? number The guild bank tab of what it shows.
local buttonProto = {}
addon:GetModule('Perf'):RegisterPrototype(buttonProto, 'NextGuildButtonFrame')

function guildButton:Init()
  self.pool = {}
  self.bySlotkey = {}
end

guildButton:Init()

-- newButton makes a button the way Blizzard makes its guild bank's, with the parts a bag button
-- shows that the item button has not: the item level text (as frames/item.lua makes it) and the
-- upgrade arrow (as ContainerFrameItemButtonTemplate defines it).
---@return NextGuildButtonFrame
local function newButton()
  local button
  if addon.isRetail then
    button = CreateFrame("ItemButton")
  else
    button = CreateFrame("Button", nil, nil, "ItemButtonTemplate")
  end
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  local itemLevel = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  itemLevel:SetPoint("BOTTOMLEFT", 2, 2)
  itemLevel:Hide()
  local upgrade = button:CreateTexture(nil, "OVERLAY", nil, 1)
  upgrade:SetAtlas("bags-greenarrow", true)
  upgrade:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  upgrade:Hide()
  local slotBackground = button:CreateTexture(nil, "BACKGROUND", nil, -6)
  slotBackground:SetTexture(SLOT_BACKGROUND)
  slotBackground:SetTexCoord(SLOT_BACKGROUND_COORDS[1], SLOT_BACKGROUND_COORDS[2], SLOT_BACKGROUND_COORDS[3],
    SLOT_BACKGROUND_COORDS[4])
  slotBackground:SetAllPoints(button)
  slotBackground:Hide()
  ---@type NextGuildButtonFrame
  local b = setmetatable({ frame = button, button = button, itemLevel = itemLevel, upgrade = upgrade,
    slotBackground = slotBackground }, { __index = buttonProto })
  addon.SetScript(button, "OnClick", function(_, _, mouse) b:OnClick(mouse) end)
  addon.SetScript(button, "OnDragStart", function() b:OnDragStart() end)
  addon.SetScript(button, "OnReceiveDrag", function() b:OnReceiveDrag() end)
  addon.SetScript(button, "OnEnter", function() b:OnEnter() end)
  addon.SetScript(button, "OnLeave", function() b:OnLeave() end)
  addon.SetScript(button, "OnHide", function() b:OnHide() end)
  button.SplitStack = function(_, split)
    b:SplitStack(split)
  end
  button.UpdateTooltip = function()
    b:OnEnter()
  end
  sonata:RegisterElement("ItemButton", button)
  return b
end

-- GetButton returns the button of a guild bank slot: the same one until it is released, else a
-- released one or a new one, announced once (guild/NewButton: Masque adds it to its group).
---@param ctx Context
---@param slotkey string
---@return NextGuildButtonFrame
function guildButton:GetButton(ctx, slotkey)
  local b = self.bySlotkey[slotkey]
  if b ~= nil then
    return b
  end
  b = table.remove(self.pool)
  if b == nil then
    b = newButton()
    events:SendMessage(ctx or context:New('NextGuildButton'), 'guild/NewButton', b)
  end
  b.slotkey = slotkey
  self.bySlotkey[slotkey] = b
  return b
end

-- Release hides the button and pools it.
---@param ctx Context
function buttonProto:Release(ctx)
  local _ = ctx
  if self.slotkey ~= nil and guildButton.bySlotkey[self.slotkey] == self then
    guildButton.bySlotkey[self.slotkey] = nil
  end
  self.frame:Hide()
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.slotkey, self.data, self.free, self.isFreeSlot, self.tab = nil, nil, nil, nil, nil
  table.insert(guildButton.pool, self)
end

---@param ctx Context
---@param width number
---@param height number
function buttonProto:SetSize(ctx, width, height)
  local _ = ctx
  self.button:SetSize(width, height)
  self.button.icon:SetSize(width, height)
  self.button.IconBorder:SetSize(width, height)
end

---@return ItemData?
function buttonProto:GetItemData()
  return self.data
end

-- reset clears what an item draws and an empty slot does not.
---@private
function buttonProto:reset()
  SetItemButtonDesaturated(self.button, false)
  self.button.IconBorder:Hide()
  self.itemLevel:Hide()
  self.upgrade:Hide()
  self:UpdateSearch(nil, true)
end

-- SetItemFromData draws a guild item: its icon, count (a virtual stack's total), quality (Blizzard's
-- SetItemButtonQuality, then the theme's or BetterBags' glow by the guild bank's setting), lock,
-- item level and upgrade arrow, and the search's match.
---@param ctx Context
---@param data ItemData
function buttonProto:SetItemFromData(ctx, data)
  local _ = ctx
  self.data, self.free, self.isFreeSlot = data, nil, nil
  self.tab = data.guildTab or guildBank:TabOf(data.bagid)
  local info = data.itemInfo
  self:reset()
  self.slotBackground:Hide()
  SetItemButtonTexture(self.button, info.itemIcon)
  SetItemButtonCount(self.button, data.stackedCount or info.currentItemCount)
  SetItemButtonDesaturated(self.button, info.isLocked)
  local quality = info.itemQuality
  SetItemButtonQuality(self.button, quality, info.itemLink)
  local qualityColor = quality ~= nil and quality >= const.ITEM_QUALITY.Uncommon and const.ITEM_QUALITY_COLOR[quality] or nil
  if not elements:DrawItemQuality(self.button, qualityColor, quality) then
    itemFrame:DrawQualityGlowFor(const.BAG_KIND.GUILD, self.button, quality)
  end
  self:drawItemLevel(info)
  self.upgrade:SetShown(data.isUpgrade == true)
  if data.isSearchResult ~= nil then
    self:UpdateSearch(nil, data.isSearchResult)
  else
    self:UpdateSearch(nil, not (data.containerInfo and data.containerInfo.isFiltered))
  end
  self.frame:Show()
end

-- drawItemLevel shows the item level of gear as a bag button does (itemProto:DrawItemLevel), by the
-- guild bank's item level settings.
---@private
---@param info ItemInfo
function buttonProto:drawItemLevel(info)
  local options = database:GetItemLevelOptions(const.BAG_KIND.GUILD)
  local level = info.currentItemLevel
  if not options.enabled or (info.classID ~= Enum.ItemClass.Armor and info.classID ~= Enum.ItemClass.Weapon)
    or not level or level < 2 then
    self.itemLevel:Hide()
    return
  end
  self.itemLevel:SetText(tostring(level))
  if options.color then
    local r, g, b = color:GetItemLevelColor(level)
    self.itemLevel:SetTextColor(r, g, b, 1)
  else
    self.itemLevel:SetTextColor(1, 1, 1, 1)
  end
  self.itemLevel:Show()
end

-- SetFreeSlots draws a Free Space entry: an empty slot of a tab shown by itself (nocount), or a tab's
-- free slots with their count in the combined view, in the bags' empty slot art.
---@param ctx Context
---@param data table A Free Space entry (items:Phase10_PartitionIntoTabs).
---@param count number
---@param nocount? boolean
function buttonProto:SetFreeSlots(ctx, data, count, nocount)
  local _ = ctx
  self.data, self.free, self.isFreeSlot = nil, data, true
  self.tab = guildBank:TabOf(data.bagid)
  self:reset()
  SetItemButtonQuality(self.button, nil)
  if addon.isRetail then
    SetItemButtonTexture(self.button, nil)
    self.slotBackground:Show()
  else
    SetItemButtonTexture(self.button, CLASSIC_EMPTY_SLOT)
  end
  SetItemButtonCount(self.button, nocount and 0 or count)
  self.frame:Show()
end

-- UpdateSearch dims the button when a search leaves it out: Blizzard's own (SetMatchesSearch) where
-- the item button has it, else the template's search overlay (Classic).
---@param ctx? Context
---@param match boolean
function buttonProto:UpdateSearch(ctx, match)
  local _ = ctx
  if self.button.SetMatchesSearch then
    self.button:SetMatchesSearch(match and true or false)
  elseif self.button.searchOverlay then
    self.button.searchOverlay:SetShown(not match)
  end
end

---@private
---@return number? tab, number? slot
function buttonProto:location()
  if self.data ~= nil then
    return self.tab, self.data.slotid
  end
  if self.free ~= nil then
    return self.tab, self.free.slotid
  end
  return nil, nil
end

-- holding is whether the cursor holds an item to put in a slot.
---@return boolean
local function holding()
  return GetCursorInfo() == "item"
end

-- placeFree puts the item held into this free slot: the slot itself when it is one slot, the tab's
-- first free slot when it counts a tab's free slots (the combined view).
---@private
function buttonProto:placeFree()
  if not holding() then
    return
  end
  if self.free.isIndividual then
    guildBank:Pickup(self.tab, self.free.slotid)
  else
    guildBank:PlaceCursorItem(self.tab)
  end
end

-- OnClick runs a click as Blizzard's guild bank item button does (GuildBankItemButtonMixin:OnClick):
-- a modified click Blizzard handles (a chat link) goes to it, Shift opens the stack split, gold on
-- the cursor is deposited or put back, a right click withdraws to the bags, a left click picks up
-- (or puts the item held there). A free slot takes the item held.
---@param mouse string
function buttonProto:OnClick(mouse)
  local tab, slot = self:location()
  if tab == nil then
    return
  end
  if self.isFreeSlot then
    if mouse == "LeftButton" then
      self:placeFree()
    end
    return
  end
  if HandleModifiedItemClick(GetGuildBankItemLink(tab, slot)) then
    return
  end
  if IsModifiedClick("SPLITSTACK") then
    if not CursorHasItem() then
      local _, count, locked = GetGuildBankItemInfo(tab, slot)
      if not locked and count and count > 1 then
        if StackSplitFrame.OpenStackSplitFrame then
          StackSplitFrame:OpenStackSplitFrame(count, self.button, "BOTTOMLEFT", "TOPLEFT")
        else
          OpenStackSplitFrame(count, self.button, "BOTTOMLEFT", "TOPLEFT")
        end
      end
    end
    return
  end
  local cursorType, money = GetCursorInfo()
  if cursorType == "money" then
    DepositGuildBankMoney(money)
    ClearCursor()
  elseif cursorType == "guildbankmoney" then
    DropCursorMoney()
    ClearCursor()
  elseif mouse == "RightButton" then
    guildBank:Withdraw(tab, slot)
    self:OnLeave()
  else
    guildBank:Pickup(tab, slot)
  end
end

-- SplitStack takes part of the stack, from the item's tab (Blizzard's stack split calls it).
---@param split number
function buttonProto:SplitStack(split)
  local tab, slot = self:location()
  if tab ~= nil and not self.isFreeSlot then
    guildBank:Split(tab, slot, split)
  end
end

function buttonProto:OnDragStart()
  local tab, slot = self:location()
  if tab ~= nil and not self.isFreeSlot then
    guildBank:Pickup(tab, slot)
  end
end

function buttonProto:OnReceiveDrag()
  local tab, slot = self:location()
  if tab == nil then
    return
  end
  if self.isFreeSlot then
    self:placeFree()
  else
    guildBank:Pickup(tab, slot)
  end
end

-- OnEnter shows Blizzard's tooltip for the slot (a caged battle pet's own, as Blizzard's guild bank
-- does), or for a free slot its tab and what a drop does.
function buttonProto:OnEnter()
  local tab, slot = self:location()
  if tab == nil then
    return
  end
  GameTooltip:SetOwner(self.button, "ANCHOR_RIGHT")
  if self.isFreeSlot then
    local info = guildBank:TabInfo(tab)
    GameTooltip:SetText(info and info.name or format(GUILDBANK_TAB_NUMBER, tab), 1, 1, 1)
    if not self.free.isIndividual then
      GameTooltip:AddLine(format(L:G("%d free slots"), self.free.count or 0), 1, 1, 1)
    end
    GameTooltip:AddLine(L:G("Drop an item here to put it in this tab"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
    return
  end
  local speciesID, level, breedQuality, maxHealth, power, speed, name = GameTooltip:SetGuildBankItem(tab, slot)
  if speciesID and speciesID > 0 then
    BattlePetToolTip_Show(speciesID, level, breedQuality, maxHealth, power, speed, name)
  end
end

function buttonProto:OnLeave()
  GameTooltip:Hide()
  ResetCursor()
end

-- OnHide closes the stack split it opened, as Blizzard's guild bank item button does.
function buttonProto:OnHide()
  if self.button.hasStackSplit and self.button.hasStackSplit == 1 then
    StackSplitFrame:Hide()
  end
end

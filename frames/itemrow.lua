---@diagnostic disable: duplicate-set-field,duplicate-doc-field
local addon = GetBetterBags()

local const = addon:GetConstants()
local events = addon:GetEvents()

local database = addon:GetDatabase()

local L = addon:GetLocalization()

local debug = addon:GetDebug()

local itemFrame = addon:GetItemFrame()

local items = addon:GetItems()

local themes = addon:GetThemes()

---@class Pool: AceModule
local pool = addon:GetModule('Pool')

---@class ItemRowFrame: AceModule
local item = addon:NewModule('ItemRowFrame')


---@class (exact) ItemRow
---@field frame Frame
---@field button Item
---@field rowButton ItemButton|Button
---@field text FontString
---@field slotkey string
item.itemRowProto = {}

function item.itemRowProto:Unlock()
end

function item.itemRowProto:Lock()
end

function item.itemRowProto:GetItemData()
  return self.button:GetItemData()
end

---@param ctx Context
---@param data ItemData
function item.itemRowProto:SetStaticItemFromData(ctx, data)
  self:SetItemFromData(ctx, data, true)
end

---@param ctx Context
---@param slotkey string
function item.itemRowProto:SetItem(ctx, slotkey)
  local data = items:GetItemDataFromSlotKey(slotkey)
  self:SetItemFromData(ctx, data)
end

---@param ctx Context
---@param data ItemData
---@param static? boolean
function item.itemRowProto:SetItemFromData(ctx, data, static)
  self.slotkey = data.slotkey
  self.button:SetSize(ctx, 20, 20)
  if static then
    self.button:SetStaticItemFromData(ctx, data)
  else
    self.button:SetItemFromData(ctx, data)
  end
  self.button.frame:SetParent(self.frame)
  self.button.frame:SetPoint("LEFT", self.frame, "LEFT", 4, 0)

  local bagid, slotid = data.bagid, data.slotid
  if slotid then
    self.rowButton:SetID(slotid)
  end

  if data.isItemEmpty then
    return
  end

  self.rowButton:SetHasItem(data.itemInfo.itemIcon)

  local quality = data.itemInfo.itemQuality
  if quality == nil then
    quality = 0
  end
  self.text:SetVertexColor(unpack(const.ITEM_QUALITY_COLOR[quality]))
  self.rowButton.HighlightTexture:SetGradient("HORIZONTAL", CreateColor(unpack(const.ITEM_QUALITY_COLOR_HIGH[quality])), CreateColor(unpack(const.ITEM_QUALITY_COLOR_LOW[quality])))

  --self.button:SetSize(20, 20)
  --self.button.Count:Hide()
  --self.button.ilvlText:Hide()
  --self.button.LockTexture:Hide()

  if bagid then
    self.frame:SetID(bagid)
  end
  self.text:SetText(data.itemInfo.itemName)
  self.rowButton:SetScript("OnEnter", function(s)
    s.HighlightTexture:Show()
    GameTooltip:SetOwner(self.frame, "ANCHOR_LEFT")
    if bagid and slotid then
      GameTooltip:SetBagItem(bagid, slotid)
    else
      GameTooltip:SetItemByID(data.itemInfo.itemID)
    end
    GameTooltip:Show()
  end)

  if self.slotkey ~= nil then
    events:SendMessage(ctx, 'item/UpdatedRow', self)
  end
  self.frame:Show()
  self.rowButton:Show()
end

function item.itemRowProto:Wipe()
  self.frame:Hide()
  self.frame:SetParent(nil)
  self.frame:ClearAllPoints()
end

---@param ctx Context
function item.itemRowProto:ClearItem(ctx)
  events:SendMessage(ctx, 'item/ClearingRow', self)
  self.button:ClearItem(ctx)

  self.rowButton:SetID(0)
  self.frame:SetID(0)
  self.frame:Hide()
  self.rowButton:Hide()
  self.rowButton:SetScript("OnMouseWheel", nil)
  self.rowButton:SetScript("OnEnter", function(s)
    ---@cast s ItemButton
    s.HighlightTexture:Show()
  end)
  self.slotkey = ""
end

---@return string
function item.itemRowProto:GetCategory()
  return self.button:GetItemData().itemInfo.category
end

---@param ctx Context
---@return boolean
function item.itemRowProto:IsNewItem(ctx)
  return self.button:IsNewItem(ctx)
end

---@return string
function item.itemRowProto:GetGUID()
  return self.button:GetItemData().itemInfo.itemGUID
end

---@param ctx Context
function item.itemRowProto:Release(ctx)
  item._pool:Release(ctx, self)
end

function item.itemRowProto:UpdateSearch(text)
  self.button:UpdateSearch(text)
end

---@param ctx Context
function item.itemRowProto:UpdateCooldown(ctx)
  self.button:UpdateCooldown(ctx)
end

local buttonCount = 0

function item:OnInitialize()
  self._pool = pool:Create(self._DoCreate, self._DoReset)
end

---@param ctx Context
---@param i ItemRow
function item._DoReset(ctx, i)
  i:ClearItem(ctx)
end

---@param ctx Context
---@return ItemRow
function item:_DoCreate(ctx)
  local i = setmetatable({}, { __index = item.itemRowProto })

  -- Backwards compatibility for item data.
  i.data = setmetatable({}, { __index = function(_, key)
    local d = i.button:GetItemData()
    if d == nil then return nil end
    return i.button:GetItemData()[key]
  end})

  -- Generate the item button name. This is needed because item
  -- button textures are named after the button itself.
  local name = format("BetterBagsRowItemButton%d", buttonCount)
  buttonCount = buttonCount + 1

  -- Create a hidden parent to the ItemButton frame to work around
  -- item taint introduced in 10.x
  local p = CreateFrame("Frame")
  i.frame = p
  --TODO(lobato): Create our own template for row buttons.
  ---@class ItemButton
  local rowButton = CreateFrame("ItemButton", name, p, "ContainerFrameItemButtonTemplate")
  rowButton:SetAllPoints(i.frame)
  i.rowButton = rowButton

  -- Button properties are set when setting the item,
  -- and setting them here will have no effect.
  local button = itemFrame:Create(ctx)
  i.button = button

  local text = i.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetParent(i.frame)
  text:SetPoint("LEFT", i.button.frame, "RIGHT", 5, 0)
  text:SetPoint("RIGHT", i.frame, "RIGHT")
  text:SetHeight(16)
  text:SetWidth(310)
  text:SetTextHeight(28)
  text:SetWordWrap(true)
  text:SetJustifyH("LEFT")
  text:SetFont("Fonts\\FRIZQT__.TTF", 14, "THICKOUTLINE")
  text:SetShadowColor(0, 0, 0, 1)
  i.text = text

  local border = i.frame:CreateTexture(nil, "BORDER")
  border:SetColorTexture(0.1, 0.1, 0.1, 1)
  border:SetPoint("BOTTOMLEFT", i.frame)
  border:SetPoint("BOTTOMRIGHT", i.frame)
  border:SetHeight(2)
  border:Hide()
  self.border = border

  --TODO(lobato): Recycle these textures instead of creating new ones.
  rowButton.NormalTexture:Hide()
  rowButton.NormalTexture:SetParent(nil)
  rowButton.NormalTexture = nil
  rowButton.PushedTexture:Hide()
  rowButton.PushedTexture:SetParent(nil)
  rowButton.PushedTexture = nil
  rowButton.NewItemTexture:Hide()
  rowButton.BattlepayItemTexture:Hide()
  rowButton:GetHighlightTexture():Hide()
  rowButton:GetHighlightTexture():SetParent(nil)
  rowButton.HighlightTexture = nil

  local highlight = rowButton:CreateTexture()
  highlight:SetDrawLayer("BACKGROUND")
  highlight:SetBlendMode("ADD")
  highlight:SetAllPoints()
  highlight:SetTexture("Interface/Buttons/WHITE8x8")
  highlight:Hide()
  rowButton.HighlightTexture = highlight
  rowButton:SetScript("OnLeave", function(s)
    s.HighlightTexture:Hide()
    GameTooltip:Hide()
  end)
  i.frame:SetSize(350, 24)

  --debug:DrawBorder(i.button.frame, 0, 0, 1)
  return i
end

---@param ctx Context
---@return ItemRow
function item:Create(ctx)
  return self._pool:Acquire(ctx)
end

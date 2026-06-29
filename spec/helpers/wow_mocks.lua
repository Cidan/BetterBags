-- wow_mocks.lua -- Mock basic World of Warcraft globals required by Ace3 and addon modules.
-- This file is loaded by spec/setup.lua before any libraries or addon code.

-- Core game functions
_G.GetTime = function() return os.clock() end

-- Stateful Widget factory helper
local function CreateMockWidget(widgetType, name, parent)
  local widget = {}
  widget._type = widgetType
  widget._name = name
  widget._parent = parent
  widget._shown = true
  widget._width = 0
  widget._height = 0
  widget._alpha = 1
  widget._text = ""
  widget._scripts = {}
  widget._events = {}
  widget._children = {}
  widget._points = {}
  widget._textures = {}
  widget._fontstrings = {}

  -- Core frame behavior
  function widget:SetScript(scriptName, handler)
    self._scripts[scriptName] = handler
  end
  function widget:GetScript(scriptName)
    return self._scripts[scriptName]
  end
  function widget:Show()
    self._shown = true
  end
  function widget:Hide()
    self._shown = false
  end
  function widget:IsShown()
    return self._shown
  end
  function widget:SetShown(shown)
    self._shown = shown
  end
  function widget:RegisterEvent(event)
    self._events[event] = true
  end
  function widget:UnregisterEvent(event)
    self._events[event] = nil
  end
  function widget:SetOwner(owner, anchor, x, y)
    self._owner = owner
    self._anchor = anchor
    self._ownerX = x
    self._ownerY = y
  end
  function widget:SetParent(parentFrame)
    self._parent = parentFrame
  end
  function widget:GetParent()
    return self._parent
  end
  function widget:SetSize(w, h)
    self._width = w
    self._height = h
  end
  function widget:SetWidth(w)
    self._width = w
  end
  function widget:SetHeight(h)
    self._height = h
  end
  function widget:GetWidth()
    return self._width or 0
  end
  function widget:GetHeight()
    return self._height or 0
  end
  function widget:SetAlpha(alpha)
    self._alpha = alpha
  end
  function widget:GetAlpha()
    return self._alpha or 1
  end
  function widget:SetAllPoints(other)
    self._allPoints = other or true
  end
  function widget:ClearAllPoints()
    self._points = {}
  end
  function widget:SetPoint(point, relativeTo, relativePoint, x, y)
    table.insert(self._points, {
      point = point,
      relativeTo = relativeTo,
      relativePoint = relativePoint,
      x = x,
      y = y
    })
  end
  function widget:EnableMouse(enable)
    self._mouseEnabled = enable
  end
  function widget:EnableMouseWheel(enable)
    self._mouseWheelEnabled = enable
  end
  function widget:RegisterForClicks(...)
    self._registeredClicks = {...}
  end
  function widget:RegisterForDrag(...)
    self._registeredDrags = {...}
  end

  -- Textures and FontStrings
  function widget:CreateTexture(textureName, drawLayer, inherits)
    local tex = CreateMockWidget("Texture", textureName, self)
    tex._drawLayer = drawLayer
    tex._inherits = inherits
    table.insert(self._textures, tex)
    return tex
  end
  function widget:CreateFontString(fontStringName, drawLayer, inherits)
    local fs = CreateMockWidget("FontString", fontStringName, self)
    fs._drawLayer = drawLayer
    fs._inherits = inherits
    table.insert(self._fontstrings, fs)
    return fs
  end
  function widget:SetNormalTexture(texture)
    self.NormalTexture = texture
  end
  function widget:GetNormalTexture()
    if not self.NormalTexture and widgetType ~= "Texture" then
      self.NormalTexture = CreateMockWidget("Texture", nil, self)
    end
    return self.NormalTexture
  end
  function widget:GetPushedTexture()
    if not self.PushedTexture and widgetType ~= "Texture" then
      self.PushedTexture = CreateMockWidget("Texture", nil, self)
    end
    return self.PushedTexture
  end
  function widget:GetHighlightTexture()
    if not self.HighlightTexture and widgetType ~= "Texture" then
      self.HighlightTexture = CreateMockWidget("Texture", nil, self)
    end
    return self.HighlightTexture
  end
  function widget:SetHighlightTexture(texture)
    self._highlightTexture = texture
  end
  function widget:SetBlendMode(mode)
    self._blendMode = mode
  end
  function widget:SetDrawLayer(layer, sublevel)
    self._drawLayer = layer
    self._sublevel = sublevel
  end
  function widget:SetTexture(path)
    self._texturePath = path
  end
  function widget:SetColorTexture(r, g, b, a)
    self._colorTexture = {r = r, g = g, b = b, a = a or 1}
  end
  function widget:SetNormalAtlas(atlas)
    self._normalAtlas = atlas
  end
  function widget:SetNormalFontObject(fontObject)
    self._normalFontObject = fontObject
  end
  function widget:SetFontString(fontString)
    self._fontString = fontString
  end
  function widget:GetFontString()
    if not self._fontString then
      self._fontString = CreateMockWidget("FontString", nil, self)
    end
    return self._fontString
  end

  -- Text and Fonts
  function widget:SetText(text)
    self._text = tostring(text or "")
  end
  function widget:SetTextHeight(height)
    self._textHeight = height
  end
  function widget:SetWordWrap(wrap)
    self._wordWrap = wrap
  end
  function widget:SetShadowColor(r, g, b, a)
    self._shadowColor = {r = r, g = g, b = b, a = a or 1}
  end
  function widget:GetText()
    return self._text
  end
  function widget:GetTextWidth()
    return #self._text * 6
  end
  function widget:GetStringWidth()
    return #self._text * 6
  end
  function widget:SetFont(font, size, flags)
    if flags and flags ~= "" then
      for token in string.gmatch(flags, "[^,%s]+") do
        local upperToken = string.upper(token)
        if upperToken ~= "OUTLINE" and
           upperToken ~= "THICKOUTLINE" and
           upperToken ~= "MONOCHROME" and
           upperToken ~= "FILTER" and
           upperToken ~= "FIXEDHEIGHT" and
           upperToken ~= "NEVERCULL" and
           upperToken ~= "SLUG" then
          error("bad argument #3 to 'SetFont' (supported flags: OUTLINE, THICKOUTLINE, MONOCHROME, FILTER, FIXEDHEIGHT, NEVERCULL, SLUG)", 2)
        end
      end
    end
    self._font = font
    self._fontSize = size
    self._fontFlags = flags
  end
  function widget:SetTextColor(r, g, b, a)
    self._textColor = {r = r, g = g, b = b, a = a or 1}
  end
  function widget:GetTextColor()
    if self._textColor then
      return self._textColor.r, self._textColor.g, self._textColor.b, self._textColor.a
    end
    return 1, 1, 1, 1
  end
  function widget:GetFontObject()
    local fo = {
      GetTextColor = function()
        return 1, 1, 1, 1
      end
    }
    return fo
  end
  function widget:SetVertexColor(r, g, b, a)
    self._vertexColor = {r = r, g = g, b = b, a = a or 1}
  end
  function widget:SetJustifyH(justify)
    self._justifyH = justify
  end
  function widget:GetJustifyH()
    return self._justifyH
  end
  function widget:SetJustifyV(justify)
    self._justifyV = justify
  end
  function widget:GetJustifyV()
    return self._justifyV
  end

  -- Strata / Level / Backdrop
  function widget:SetFrameStrata(strata)
    self._frameStrata = strata
  end
  function widget:SetFrameLevel(level)
    self._frameLevel = level
  end
  function widget:SetBackdrop(backdrop)
    self._backdrop = backdrop
  end
  function widget:SetBackdropColor(r, g, b, a)
    self._backdropColor = {r = r, g = g, b = b, a = a or 1}
  end
  function widget:SetBackdropBorderColor(r, g, b, a)
    self._backdropBorderColor = {r = r, g = g, b = b, a = a or 1}
  end

  -- Grid Frame scroll/mousewheel APIs
  function widget:HideScrollBar()
    self._scrollBarShown = false
  end
  function widget:ShowScrollBar()
    self._scrollBarShown = true
  end
  function widget:EnableMouseWheelScroll(enable)
    self._mouseWheelScrollEnabled = enable
  end
  function widget:GetContainer()
    if not self._container then
      self._container = CreateMockWidget("Frame", nil, self)
    end
    return self._container
  end

  if widgetType ~= "Texture" then
    widget.NormalTexture = widget:GetNormalTexture()
    widget.PushedTexture = widget:GetPushedTexture()
    widget.NewItemTexture = CreateMockWidget("Texture", nil, widget)
    widget.BattlepayItemTexture = CreateMockWidget("Texture", nil, widget)
    widget.HighlightTexture = widget:GetHighlightTexture()
  end

  return widget
end

_G.CreateFrame = function(frameType, name, parent, template)
  local frame = CreateMockWidget(frameType, name, parent)
  if name then
    _G[name] = frame
  end
  return frame
end

_G.hooksecurefunc = function() end
_G.UIParent = CreateMockWidget("Frame", "UIParent")
_G.UIParent:SetSize(1920, 1200)
function _G.UIParent:GetEffectiveScale()
  return 1.0
end

_G.C_Timer = {
  After = function(_, _) end,
  NewTimer = function(_, _)
    return { Cancel = function() end }
  end,
}
_G.IsLoggedIn = function() return true end
_G.SlashCmdList = {}
_G.hash_SlashCmdList = {}
_G.GetLocale = function() return "enUS" end
_G.GetBuildInfo = function() return "10.0.0", "12345", "Jan 1 2024", 100000 end
_G.GetRealmName = function() return "TestRealm" end
_G.UnitName = function() return "TestChar", "TestRealm" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
_G.UnitRace = function() return "Human", "Human" end
_G.GetCurrentRegion = function() return 1 end
_G.GetCurrentRegionName = function() return "US" end

-- Error handling and secure call wrappers
_G.geterrorhandler = function()
  return function(err) return err end
end
_G.securecallfunction = function(fn, ...)
  return pcall(fn, ...)
end
_G.securecall = _G.securecallfunction

-- Table utilities
_G.CopyTable = function(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      copy[k] = _G.CopyTable(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- Combat and gameplay state
_G.InCombatLockdown = function() return false end
_G.GetFramerate = function() return 60 end

-- String utilities (WoW-specific)
_G.format = string.format
_G.strtrim = function(str)
  if not str then return "" end
  return str:match("^%s*(.-)%s*$")
end

-- Item info stubs
_G.C_Item = _G.C_Item or {}
if not _G.C_Item.GetItemInfoInstant then
  _G.C_Item.GetItemInfoInstant = function(id) return id end
end
_G.C_Item.IsBound = _G.C_Item.IsBound or function() return false end
_G.C_Item.GetItemQuality = _G.C_Item.GetItemQuality or function() return 1 end
_G.C_Item.GetDetailedItemLevelInfo = _G.C_Item.GetDetailedItemLevelInfo or function() return 1, false, 1 end
_G.C_Item.GetCurrentItemLevel = _G.C_Item.GetCurrentItemLevel or function() return 1 end
_G.C_Item.GetItemGUID = _G.C_Item.GetItemGUID or function() return "mock-guid" end
_G.C_Item.GetStackCount = _G.C_Item.GetStackCount or function() return 1 end
_G.C_Item.GetItemInfo = _G.C_Item.GetItemInfo or function()
  return "Mock Item", "[Mock Item Link]", 1, 1, 0, "Weapon", "One-Handed Swords", 1, "INVTYPE_WEAPON", 12345, 100, 2, 0, 0, 0, 0
end

-- New item tracking
_G.C_NewItems = _G.C_NewItems or {
  IsNewItem = function() return false end,
  RemoveNewItem = function() end,
  ClearAll = function() end,
}

-- Time function
_G.time = _G.time or os.time

-- string.split (WoW alias for strsplit, available as string method)
string.split = string.split or function(sep, str)
  return _G.strsplit(sep, str)
end

-- strsplittable: like strsplit but returns a table
_G.strsplittable = function(sep, str, max)
  return {_G.strsplit(sep, str, max)}
end

-- Lua 5.1/5.3 compatibility shims
if not _G.unpack and _G.table and _G.table.unpack then
  _G.unpack = _G.table.unpack
end

if not _G.loadstring and _G.load then
  _G.loadstring = _G.load
end

-- String functions (WoW global aliases for string library)
_G.strmatch = string.match
_G.strsub = string.sub
_G.strlen = string.len
_G.strfind = string.find
_G.strlower = string.lower
_G.strupper = string.upper
_G.strbyte = string.byte
_G.strchar = string.char
_G.strrep = string.rep
_G.strjoin = function(sep, ...) return table.concat({...}, sep) end

_G.strsplit = function(sep, str, max)
  if str == nil then return end
  local t = {}
  local start = 1
  local splitStart, splitEnd = string.find(str, sep, start, true)
  while splitStart do
    if max and #t >= max - 1 then break end
    table.insert(t, string.sub(str, start, splitStart - 1))
    start = splitEnd + 1
    splitStart, splitEnd = string.find(str, sep, start, true)
  end
  table.insert(t, string.sub(str, start))
  return unpack(t)
end

-- Table functions (WoW global aliases for table library)
_G.tinsert = table.insert
_G.tremove = table.remove
_G.tconcat = table.concat
_G.wipe = function(t)
  for k in pairs(t) do
    t[k] = nil
  end
  return t
end

-- Equipment set API
_G.C_EquipmentSet = {
  GetEquipmentSetIDs = function() return {} end,
  GetEquipmentSetInfo = function() return "" end,
  GetItemLocations = function() return {} end,
}

-- Equipment location unpack helpers
_G.EquipmentManager_UnpackLocation = function()
  return 0, false, true, false, 1, 0
end

_G.EquipmentManager_GetLocationData = function()
  return { isBank = false, isBags = true, slot = 1, bag = 0 }
end

-- Subsystems and Money APIs
_G._playerMoney = 100000 -- Default to 10 gold (in copper)
_G._depositedMoney = 50000 -- Default to 5 gold (in copper)

_G.GetMoney = function()
  return _G._playerMoney
end

_G.BreakUpLargeNumbers = function(val)
  local left, right = string.match(tostring(val), "^([^%d]*%d+)(.-)$")
  if not left then return tostring(val) end
  return left:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") .. (right or "")
end

_G._lastPopupShown = nil
_G.StaticPopup_Show = function(name, ...)
  _G._lastPopupShown = { name = name, args = {...} }
  return {}
end

_G.PlaySound = function() end
_G.SOUNDKIT = {
  IG_BACKPACK_OPEN = 1,
  IG_BACKPACK_CLOSE = 2,
}

-- GameTooltip Mock
_G.GameTooltip = CreateMockWidget("Frame", "GameTooltip")
_G.GameTooltip.lines = {}
_G.GameTooltip.doubleLines = {}
function _G.GameTooltip:SetOwner(owner, anchor, x, y)
  self._owner = owner
  self._anchor = anchor
  self._ownerX = x
  self._ownerY = y
  self.lines = {}
  self.doubleLines = {}
end
function _G.GameTooltip:AddLine(text, r, g, b)
  table.insert(self.lines, {text = text, r = r, g = g, b = b})
end
function _G.GameTooltip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
  table.insert(self.doubleLines, {left = left, right = right, lr = lr, lg = lg, lb = lb, rr = rr, rg = rg, rb = rb})
end

-- Cursor APIs
_G._cursorHasItem = false
_G._isShiftKeyDown = false
_G._isControlKeyDown = false
_G._isAltKeyDown = false
_G._cursorType = nil
_G._cursorItemID = nil
_G._cursorItemLink = nil
_G._cursorX = 0
_G._cursorY = 0

_G.CursorHasItem = function() return _G._cursorHasItem or false end
_G.IsShiftKeyDown = function() return _G._isShiftKeyDown or false end
_G.IsControlKeyDown = function() return _G._isControlKeyDown or false end
_G.IsAltKeyDown = function() return _G._isAltKeyDown or false end
_G.GetCursorInfo = function() return _G._cursorType, _G._cursorItemID, _G._cursorItemLink end
_G.ClearCursor = function()
  _G._cursorHasItem = false
  _G._cursorType = nil
  _G._cursorItemID = nil
  _G._cursorItemLink = nil
end
_G.GetCursorPosition = function() return _G._cursorX or 0, _G._cursorY or 0 end

-- Enum Setup
_G.Enum = _G.Enum or {}
_G.Enum.BankType = {
  Account = 1,
  Character = 2,
}
_G.Enum.BagIndex = {
  Keyring = -2,
}
_G.Enum.ItemClass = {
  Consumable = 0,
  Container = 1,
  Weapon = 2,
  Gem = 3,
  Armor = 4,
  Tradegoods = 7,
}

-- C_Bank Setup
_G.C_Bank = _G.C_Bank or {}
_G.C_Bank.FetchDepositedMoney = function(bankType)
  return _G._depositedMoney
end

-- C_Container Setup
_G.C_Container = _G.C_Container or {}
_G.C_Container._usedItems = {}
_G.C_Container.GetBagName = function(bagid)
  if bagid == -2 then return "Keyring" end
  return "Mock Bag " .. bagid
end
_G.C_Container.GetContainerNumSlots = function(bagid)
  return 16
end
_G.C_Container.GetContainerItemID = function(bagid, slotid)
  return _G._containerItems and _G._containerItems[bagid] and _G._containerItems[bagid][slotid] or nil
end
_G.C_Container.GetContainerItemLink = function(bagid, slotid)
  local itemID = _G.C_Container.GetContainerItemID(bagid, slotid)
  if itemID then
    return string.format("|cffff8000|Hitem:%d:0:0:0:0:0:0:0|h[Mock Item %d]|h|r", itemID, itemID)
  end
  return nil
end
_G.C_Container.GetContainerNumFreeSlots = function(bagid)
  return 4, nil
end
_G.C_Container.GetContainerItemQuestInfo = _G.C_Container.GetContainerItemQuestInfo or function(bagid, slotid)
  return { isQuestItem = false, questID = nil, isActive = false }
end
_G.C_Container.GetContainerItemInfo = _G.C_Container.GetContainerItemInfo or function(bagid, slotid)
  return { iconFileID = 12345, stackCount = 1, isLocked = false, quality = 1, isReadable = false, hasLoot = false, hyperlink = "[Mock Link]", isFiltered = false, hasNoValue = false, itemID = 123 }
end
_G.C_Container.UseContainerItem = function(bagid, slotid, target, bankType, isReagent)
  table.insert(_G.C_Container._usedItems, {
    bagid = bagid,
    slotid = slotid,
    target = target,
    bankType = bankType,
    isReagent = isReagent
  })
end

-- ItemLocation Setup
_G.ItemLocation = _G.ItemLocation or {}
_G.ItemLocation.CreateFromBagAndSlot = function(_, bagID, slotID)
  local loc = {
    _bagID = bagID,
    _slotID = slotID,
    _isBagAndSlot = true,
    _isEquipmentSlot = false,
  }
  function loc:GetBagAndSlot() return self._bagID, self._slotID end
  function loc:GetEquipmentSlot() return nil end
  function loc:IsEquipmentSlot() return false end
  function loc:IsBagAndSlot() return true end
  function loc:IsValid() return true end
  return loc
end
_G.ItemLocation.CreateFromEquipmentSlot = function(_, slotID)
  local loc = {
    _bagID = nil,
    _slotID = nil,
    _isBagAndSlot = false,
    _isEquipmentSlot = true,
    _equipSlot = slotID,
  }
  function loc:GetBagAndSlot() return nil, nil end
  function loc:GetEquipmentSlot() return self._equipSlot end
  function loc:IsEquipmentSlot() return true end
  function loc:IsBagAndSlot() return false end
  function loc:IsValid() return true end
  return loc
end

-- Item Setup
_G.Item = _G.Item or {}
_G.Item.CreateFromBagAndSlot = function(_, bagID, slotID)
  local loc = _G.ItemLocation:CreateFromBagAndSlot(bagID, slotID)
  local item = {
    _location = loc,
    _bagID = bagID,
    _slotID = slotID,
  }
  function item:GetItemLocation() return self._location end
  function item:GetInventoryType() return 1 end
  function item:IsItemDataLoaded() return true end
  function item:ContinueOnItemLoad(callback) callback() end
  function item:IsItemLocked() return false end
  function item:GetItemName() return "Mock Item" end
  function item:GetItemIcon() return 12345 end
  function item:GetItemLink() return "[Mock Item]" end
  function item:IsItemEmpty() return false end
  return item
end
_G.Item.CreateFromEquipmentSlot = function(_, slotID)
  local loc = _G.ItemLocation:CreateFromEquipmentSlot(slotID)
  local item = {
    _location = loc,
    _equipSlot = slotID,
  }
  function item:GetItemLocation() return self._location end
  function item:GetInventoryType() return 1 end
  function item:IsItemDataLoaded() return true end
  function item:ContinueOnItemLoad(callback) callback() end
  function item:IsItemLocked() return false end
  function item:GetItemName() return "Mock Item" end
  function item:GetItemIcon() return 12345 end
  function item:GetItemLink() return "[Mock Item]" end
  function item:IsItemEmpty() return false end
  return item
end
_G.Item.CreateFromItemLocation = function(_, itemLocation)
  local item = {
    _location = itemLocation,
  }
  function item:GetItemLocation() return self._location end
  function item:GetInventoryType() return 1 end
  function item:IsItemDataLoaded() return true end
  function item:ContinueOnItemLoad(callback) callback() end
  function item:IsItemLocked() return false end
  function item:GetItemName() return "Mock Item" end
  function item:GetItemIcon() return 12345 end
  function item:GetItemLink() return "[Mock Item]" end
  function item:IsItemEmpty() return false end
  return item
end

-- ContinuableContainer Setup
_G.ContinuableContainer = _G.ContinuableContainer or {}
_G.ContinuableContainer.Create = function(_)
  local container = {
    _items = {}
  }
  function container:AddContinuable(itemMixin)
    table.insert(self._items, itemMixin)
  end
  function container:ContinueOnLoad(callback)
    callback()
  end
  return container
end

-- Math aliases
_G.floor = math.floor
_G.ceil = math.ceil
_G.abs = math.abs
_G.max = math.max
_G.min = math.min

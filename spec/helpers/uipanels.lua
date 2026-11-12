-- uipanels.lua -- Blizzard's UI panel manager (Blizzard_UIParentPanelManager: ShowUIPanel, HideUIPanel,
-- UpdateUIPanelPositions, SetUIPanelAttribute, the panels it registers in UIPanelWindows) as a client runs it, loaded
-- from that client's branch of Blizzard's UI source (spec/helpers/ui_source.lua) over the frame mocks, in place of the
-- mocks' own ShowUIPanel and HideUIPanel, which only show and hide. For BetterBags Next's panels beside Blizzard's
-- (next/uipanels.lua, .claude/rules/next-uipanels.md).
local uiSource = dofile("spec/helpers/ui_source.lua")

local M = {}

local DIR = "Interface/AddOns/Blizzard_UIParentPanelManager/"

-- The manager's files, as each family's TOC lists them (Blizzard_UIParentPanelManager.toc on live and forever,
-- Blizzard_UIParentPanelManager_Classic.toc on the classic branches), in its order.
local FILES = {
  mainline = { "Mainline/UIPanelWindows.lua", "Shared/UIPanelLayoutFrame.lua", "Shared/UIParentPanelManager.lua",
    "Mainline/UIParentPanelManagerOverrides.lua", "Shared/UpdateUIPanelPositions.lua" },
  classic = { "Classic/UIPanelWindows.lua", "Shared/UIParentPanelManager.lua", "Classic/UIParentPanelManagerOverrides.lua",
    "Shared/UpdateUIPanelPositions.lua" },
}

-- A classic client keeps its layout in UIParent's attributes, set by its UIParent.xml before the manager loads.
local UIPARENT_XML = "Interface/AddOns/Blizzard_UIParent/Classic/UIParent.xml"

-- What the manager calls that the frame mocks do not model, each as the client answers it while nothing else is going
-- on: no shop open (C_CatalogShop.IsShop2Enabled, CatalogShopDocumentation), the player alive (UnitIsDead), no game pad
-- (CanAutoSetGamePadCursorControl), secure code (issecure: specs model no taint); TableIsEmpty as SharedXML's
-- TableUtil.lua has it; FrameUtil.UpdateScaleForFitSpecific and GetAppropriateTopLevelParent as
-- Blizzard_SharedXMLBase/FrameUtil.lua has them (no alternate top-level parent: UIParent), which scale a panel to fit
-- the screen; the game menu's Escape handlers (Blizzard_GameMenuEsc) and the bags' close (CloseAllBags), which nothing
-- here needs.
local SUPPORT = {
  FrameUtil = {
    UpdateScaleForFitSpecific = function(frame, specificWidth, specificHeight)
      frame:SetScale(1)
      local topLevelParent = GetAppropriateTopLevelParent()
      local horizRatio = topLevelParent:GetWidth() / (specificWidth or frame:GetWidth())
      local vertRatio = topLevelParent:GetHeight() / (specificHeight or frame:GetHeight())
      if horizRatio < 1 or vertRatio < 1 then
        frame:SetScale(math.min(horizRatio, vertRatio))
      end
    end,
  },
  GetAppropriateTopLevelParent = function() return UIParent end,
  C_CatalogShop = { IsShop2Enabled = function() return false end },
  UnitIsDead = function() return false end,
  CanAutoSetGamePadCursorControl = function() return false end,
  SetGamePadCursorControl = function() end,
  issecure = function() return true end,
  TableIsEmpty = function(tbl) return next(tbl) == nil end,
  RegisterGameMenuEscHandler = function() end,
  GameMenuEscPriority = { AddOnPost = 1 },
  CloseAllBags = function() end,
}

-- Each branch's files, read once per spec file.
local cache = {}

---@param client table
---@param paths string[]
---@return table<string, string>
local function read(client, paths)
  local have = cache[client.branch] or {}
  cache[client.branch] = have
  local missing = {}
  for _, path in ipairs(paths) do
    if have[path] == nil then
      table.insert(missing, path)
    end
  end
  if #missing > 0 then
    for path, text in pairs(uiSource.Read(client, missing)) do
      have[path] = text
    end
  end
  return have
end

-- Load runs a client's panel manager (a name of ui_source.CLIENTS: "Retail", "Forever", "Era", "Anniversary",
-- "Mists") over the mocks, and returns what puts back every global it set, UIParent's attributes and its
-- OnAttributeChanged: for an after_each.
---@param name string
---@return fun()
function M.Load(name)
  local client = assert(uiSource.CLIENTS[name], "no client " .. tostring(name))
  local available, why = uiSource.Available()
  assert(available, why)
  local files = FILES[client.family]
  local paths = {}
  for _, file in ipairs(files) do
    table.insert(paths, DIR .. file)
  end
  if client.family == "classic" then
    table.insert(paths, UIPARENT_XML)
  end
  local text = read(client, paths)

  local saved = {}
  for k, v in pairs(_G) do
    saved[k] = v
  end
  local savedScript = UIParent:GetScript("OnAttributeChanged")
  local savedAttributes = {}
  for k, v in pairs(UIParent._attributes) do
    savedAttributes[k] = v
  end

  for k, v in pairs(SUPPORT) do
    if rawget(_G, k) == nil then
      rawset(_G, k, v)
    end
  end
  if client.family == "classic" then
    -- The mainline layout frame is not there: a classic client reads UIParent's attributes.
    rawset(_G, "UIPanelLayoutFrame", nil)
    rawset(_G, "GetUIPanelLayoutAttribute", nil)
    rawset(_G, "SetUIPanelLayoutAttribute", nil)
    local xml = assert(text[UIPARENT_XML], client.branch .. " has no " .. UIPARENT_XML)
    local count = 0
    for attr, value in xml:gmatch('<Attribute name="([%w_]+)" type="number" value="(%-?[%d%.]+)"/>') do
      UIParent:SetAttributeNoHandler(attr, tonumber(value))
      count = count + 1
    end
    assert(count > 0, "no layout attributes in " .. UIPARENT_XML)
  end
  local addonTable = {}
  for _, path in ipairs(paths) do
    if path:match("%.lua$") then
      local source = assert(text[path], client.branch .. " has no " .. path)
      local chunk = assert(loadstring(source, "@" .. client.branch .. ":" .. path))
      chunk("Blizzard_UIParentPanelManager", addonTable)
    end
  end

  return function()
    for k in pairs(_G) do
      if saved[k] == nil then
        rawset(_G, k, nil)
      end
    end
    for k, v in pairs(saved) do
      if rawget(_G, k) ~= v then
        rawset(_G, k, v)
      end
    end
    UIParent:SetScript("OnAttributeChanged", savedScript)
    UIParent._attributes = savedAttributes
  end
end

-- Register registers a panel as the client does outside the manager's files (UIPanelWindows["GuildBankFrame"] in
-- Blizzard_GuildBankUI.lua, a load-on-demand addon), read from path on its branch.
---@param name string A client, as for Load.
---@param path string
---@param frameName string
function M.Register(name, path, frameName)
  local client = assert(uiSource.CLIENTS[name], "no client " .. tostring(name))
  local source = assert(read(client, { path })[path], client.branch .. " has no " .. path)
  local entry = source:match('UIPanelWindows%["' .. frameName .. '"%]%s*=%s*(%b{})')
  assert(entry, path .. " on " .. client.branch .. " registers no " .. frameName)
  UIPanelWindows[frameName] = assert(loadstring("return " .. entry))()
end

-- Left returns where a panel the manager placed sits from the screen's left edge, in UIParent's units: it anchors each
-- one's TOPLEFT to UIParent's at its offset divided by the frame's scale (UpdateUIPanelPositions).
---@param frame Frame
---@return number
function M.Left(frame)
  local point, relativeTo, relativePoint, x = frame:GetPoint(1)
  assert(point == "TOPLEFT" and relativeTo == "UIParent" and relativePoint == "TOPLEFT",
    tostring(frame:GetName()) .. " was not placed by the panel manager")
  return x * frame:GetScale()
end

return M

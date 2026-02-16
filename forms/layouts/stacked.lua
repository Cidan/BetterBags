local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Animations: AceModule
local animations = addon:GetModule('Animations')

---@class (exact) FormLayouts: AceModule
local layouts = addon:GetModule('FormLayouts')

---@class (exact) StackedLayout: FormLayout
---@field nextFrame Frame
---@field nextIndex Frame
---@field baseFrame Frame
---@field indexFrame Frame
---@field underline Frame
---@field sections {point: Frame, button: Button, paneIndex?: number}[]
---@field checkboxes table<FormCheckbox, FormCheckboxOptions>
---@field dropdowns table<FormDropdown, FormDropdownOptions>
---@field sliders table<FormSlider, FormSliderOptions>
---@field buttonGroups table<FormButtons, FormButtonGroupOptions>
---@field textAreas table<FormTextArea, FormTextAreaOptions>
---@field inputBoxes table<FormInputBox, FormInputBoxOptions>
---@field colorPickers table<FormColor, FormColorOptions>
---@field paneLinks table<FormPaneLink, FormPaneLinkOptions>
---@field scrollBox WowScrollBox
---@field height number
---@field index boolean
---@field tabbed boolean
---@field activeTab number
---@field tabContainers Frame[]
---@field tabFadeIns AnimationGroup[]
---@field tabFadeOuts AnimationGroup[]
---@field tabHeights number[]
---@field panes Frame[]
---@field paneFadeIns AnimationGroup[]
---@field paneFadeOuts AnimationGroup[]
---@field activePane number|nil
---@field previousTab number|nil
local stackedLayout = {}

---@param targetFrame Frame
---@param baseFrame Frame
---@param scrollBox WowScrollBox
---@param index boolean
---@param tabbed boolean
---@return FormLayout
function layouts:NewStackedLayout(targetFrame, baseFrame, scrollBox, index, tabbed)
  local l = setmetatable({}, {__index = stackedLayout}) --[[@as StackedLayout]]
  l.targetFrame = targetFrame
  l.nextFrame = targetFrame
  l.height = 0
  l.index = index
  l.baseFrame = baseFrame
  l.scrollBox = scrollBox
  l.tabbed = tabbed or false
  l.activeTab = 1
  l.tabContainers = {}
  l.tabFadeIns = {}
  l.tabFadeOuts = {}
  l.tabHeights = {}
  l.checkboxes = {}
  l.dropdowns = {}
  l.sliders = {}
  l.buttonGroups = {}
  l.textAreas = {}
  l.inputBoxes = {}
  l.colorPickers = {}
  l.paneLinks = {}
  l.sections = {}
  l.panes = {}
  l.paneFadeIns = {}
  l.paneFadeOuts = {}
  l.activePane = nil
  l.previousTab = nil
  if index then
    l:setupIndex()
  end
  return l
end

function stackedLayout:ReloadAllFormElements()
  for container, opts in pairs(self.checkboxes) do
    container.checkbox:SetChecked(opts.getValue(context:New('Checkbox_Reload')))
  end

  if addon.isRetail then
    for container in pairs(self.dropdowns) do
      container.dropdown:Update()
    end
  end

  for container, opts in pairs(self.sliders) do
    container.slider:SetValue(opts.getValue(context:New('Slider_Reload')))
    container.input:SetText(tostring(container.slider:GetValue()))
  end

  for container, opts in pairs(self.textAreas) do
    container.input:SetText(opts.getValue(context:New('TextArea_Reload')))
  end

  for container, opts in pairs(self.inputBoxes) do
    container.input:SetText(opts.getValue(context:New('InputBox_Reload')))
  end

  for container, opts in pairs(self.colorPickers) do
    local color = opts.getValue(context:New('Color_Reload'))
    container.colorTexture:SetVertexColor(color.red, color.green, color.blue, color.alpha)
  end
end

---@package
function stackedLayout:setupIndex()
  self.indexFrame = CreateFrame("Frame", nil, self.baseFrame) --[[@as Frame]]
  self.indexFrame:SetPoint("TOPLEFT", self.baseFrame, "TOPLEFT", 10, -34)
  self.indexFrame:SetPoint("BOTTOM", self.baseFrame, "BOTTOM", 0, 0)
  self.indexFrame:SetWidth(120)

  if not self.tabbed then
    -- Only create underline and scroll tracking for non-tabbed mode
    local underline = self:createDividerLineLeft(self.indexFrame)
    self.underline = underline
    self.scrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
      self:UpdateUnderline()
    end)
  end
  self.nextIndex = self.indexFrame
end

---@private
---@param offset number
function stackedLayout:scrollToOffset(offset)
  local scrollRange = self.scrollBox:GetDerivedScrollRange()
  if scrollRange > 0 then
    local scrollPercentage = offset / scrollRange
    self.scrollBox:SetScrollPercentage(scrollPercentage)
  end
end

---@private
---@param parent Frame
---@return Frame
function stackedLayout:createTextAreaBackground(parent)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate") --[[@as Frame]]
  frame:SetBackdrop({
    bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 4,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
  })
  frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
  frame:SetBackdropBorderColor(0.4, 0.4, 0.4)
  return frame
end

---@package
---@param title string
---@param point Frame
---@param sub? boolean
function stackedLayout:addIndex(title, point, sub)
  if not self.index then return end
  local indexButton = CreateFrame("Button", nil, self.indexFrame) --[[@as Button]]
  indexButton:SetSize(100, 24)
  if sub then
    local font = indexButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    indexButton:SetFontString(font)
  else
    local font = indexButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    indexButton:SetFontString(font)
  end
  indexButton:SetText(sub and "  " .. title or title)
  local fs = indexButton:GetFontString()
  fs:SetTextColor(1, 1, 1)
  fs:ClearAllPoints()
  fs:SetPoint("LEFT", indexButton, "LEFT", 5, 0)
  fs:SetJustifyH("LEFT")

  -- Change OnClick behavior based on mode
  if self.tabbed then
    -- Use tabContainers count, not sections count, because sections includes pane links
    -- which don't have tab containers. This ensures the tab index matches the actual
    -- tabContainers array index.
    local tabIndex = #self.tabContainers
    indexButton.tabIndex = tabIndex -- Store tab index for hover logic

    -- Add hover glow effect
    indexButton:SetScript("OnEnter", function()
      -- Animate the text with a subtle glow
      fs:SetTextColor(1, 0.9, 0.5) -- Warm golden color
      fs:SetShadowColor(1, 0.8, 0.3, 0.8)
      fs:SetShadowOffset(0, 0) -- No offset creates a glow effect
    end)

    indexButton:SetScript("OnLeave", function()
      -- Only keep highlighted if this is the active tab AND no pane is active
      if self.activeTab == tabIndex and not self.activePane then
        -- Keep active tab golden with glow
        fs:SetTextColor(1, 0.82, 0)
        fs:SetShadowColor(1, 0.8, 0.3, 0.8)
        fs:SetShadowOffset(0, 0)
      else
        -- Reset to normal
        fs:SetTextColor(1, 1, 1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
      end
    end)

    indexButton:SetScript("OnClick", function()
      self:SwitchToTab(tabIndex)
    end)
  else
    -- Existing scroll behavior for non-tabbed mode
    indexButton:SetScript("OnClick", function()
      local targetTop = point:GetTop()
      local parentTop = self.targetFrame:GetTop()
      if addon.isRetail then
        self.scrollBox:ScrollToOffset((parentTop - targetTop) - 10)
      else
        self:scrollToOffset((parentTop - targetTop) - 10)
      end
    end)
  end

  if self.nextIndex == self.indexFrame then
    indexButton:SetPoint("TOPLEFT", self.indexFrame, "TOPLEFT", 5, -10)
  else
    indexButton:SetPoint("TOPLEFT", self.nextIndex, "BOTTOMLEFT", 0, -5)
  end
  table.insert(self.sections, {point = point, button = indexButton})
  self:UpdateUnderline()
  self.nextIndex = indexButton
end

function stackedLayout:UpdateUnderline()
  if not self.index or self.tabbed then return end
  for i, section in ipairs(self.sections) do
    local targetTop = section.point:GetTop()
    local parentTop = self.targetFrame:GetTop()
    if parentTop == nil then break end
    if i == #self.sections and self.scrollBox:GetDerivedScrollOffset() + 100 > parentTop - targetTop then
      local uSection = self.sections[i]
      self.underline:SetPoint("TOPLEFT", uSection.button, "BOTTOMLEFT", 0, 0)
      self.underline:SetPoint("TOPRIGHT", uSection.button, "BOTTOMRIGHT", 0, 0)
      break
    end
    if self.scrollBox:GetDerivedScrollOffset() + 100 <= parentTop - targetTop then
      local uSection = i == 1 and section or self.sections[i - 1]
      self.underline:SetPoint("TOPLEFT", uSection.button, "BOTTOMLEFT", 0, 0)
      self.underline:SetPoint("TOPRIGHT", uSection.button, "BOTTOMRIGHT", 0, 0)
      break
    end
  end
  self.underline:Show()
  self.underline:GetTop()
end

---@param tabIndex number
function stackedLayout:SwitchToTab(tabIndex)
  -- If a pane is active, hide it and show the requested tab
  local wasShowingPane = self.activePane ~= nil
  if self.activePane then
    local paneFrame = self.panes[self.activePane]
    if paneFrame and paneFrame:IsShown() then
      local fadeOut = self.paneFadeOuts[self.activePane]
      fadeOut.callback = function()
        paneFrame:Hide()
      end
      fadeOut:Play()
    end
    self.activePane = nil
    self.previousTab = nil
  end

  -- If clicking the same tab we were already on (but coming from a pane),
  -- we need to show the tab container and update highlighting
  if tabIndex == self.activeTab then
    if wasShowingPane then
      -- Tab container was hidden when pane was shown, need to restore it
      local tabContainer = self.tabContainers[tabIndex]
      if tabContainer then
        local tabHeight = self.tabHeights[tabIndex] + 25
        tabContainer:SetHeight(tabHeight)
        self.targetFrame:SetHeight(tabHeight)
        if self.scrollBox and self.scrollBox.FullUpdate then
          local _ = self.targetFrame:GetHeight()
          self.scrollBox:FullUpdate(true)
        end
        tabContainer:Show()
        tabContainer:SetAlpha(0)
        local fadeIn = self.tabFadeIns[tabIndex]
        fadeIn:Play()
      end
      self:UpdateTabHighlighting(tabIndex)
    end
    return
  end

  local currentContainer = self.tabContainers[self.activeTab]
  local newContainer = self.tabContainers[tabIndex]

  if not newContainer then return end

  -- Update the new tab's height before showing
  local newTabHeight = self.tabHeights[tabIndex] + 25
  newContainer:SetHeight(newTabHeight)

  -- Fade out current tab if it exists and is shown
  if currentContainer and currentContainer:IsShown() then
    local fadeOut = self.tabFadeOuts[self.activeTab]
    fadeOut.callback = function()
      currentContainer:Hide()

      -- Update the target frame (inner) height to match the new tab
      self.targetFrame:SetHeight(newTabHeight)

      -- Notify the scroll box that content size has changed
      if self.scrollBox and self.scrollBox.FullUpdate then
        local _ = self.targetFrame:GetHeight() -- Force layout update
        self.scrollBox:FullUpdate(true)
      end

      -- Fade in new tab
      newContainer:Show()
      newContainer:SetAlpha(0)
      local fadeIn = self.tabFadeIns[tabIndex]
      fadeIn:Play()
    end
    fadeOut:Play()
  else
    -- No current container shown (e.g., coming from a pane), just show new tab
    self.targetFrame:SetHeight(newTabHeight)
    if self.scrollBox and self.scrollBox.FullUpdate then
      local _ = self.targetFrame:GetHeight()
      self.scrollBox:FullUpdate(true)
    end
    newContainer:Show()
    newContainer:SetAlpha(0)
    local fadeIn = self.tabFadeIns[tabIndex]
    fadeIn:Play()
  end

  -- Update active tab and button highlighting
  self:UpdateTabHighlighting(tabIndex)
  self.activeTab = tabIndex

  -- Reset scroll to top for new tab
  if self.scrollBox then
    self.scrollBox:SetScrollPercentage(0)
  end
end

---@private
---@param amount number
function stackedLayout:addHeight(amount)
  if self.tabbed then
    -- Find the current tab index by walking up the frame hierarchy
    local frame = self.nextFrame
    while frame and not frame.tabIndex do
      frame = frame:GetParent()
    end
    if frame and frame.tabIndex then
      self.tabHeights[frame.tabIndex] = self.tabHeights[frame.tabIndex] + amount
    end
  else
    self.height = self.height + amount
  end
end

---@param activeTabIndex number
function stackedLayout:UpdateTabHighlighting(activeTabIndex)
  for _, section in ipairs(self.sections) do
    local button = section.button
    local fs = button:GetFontString()
    local isActive = false

    -- Check if this is the active pane or the active tab
    -- Pane links have section.paneIndex, tabs have button.tabIndex
    if self.activePane and section.paneIndex == self.activePane then
      isActive = true
    elseif not self.activePane and button.tabIndex == activeTabIndex then
      isActive = true
    end

    if isActive then
      -- Highlight active tab with golden color and glow
      fs:SetTextColor(1, 0.82, 0)  -- Gold color
      fs:SetShadowColor(1, 0.8, 0.3, 0.8)
      fs:SetShadowOffset(0, 0)  -- No offset creates a glow effect
    else
      -- Normal color for inactive tabs
      fs:SetTextColor(1, 1, 1)
      fs:SetShadowColor(0, 0, 0, 1)
      fs:SetShadowOffset(1, -1)
    end
  end
end

---@private
---@param t Frame
---@param container Frame
---@param indent? number
function stackedLayout:alignFrame(t, container, indent)
  indent = indent or 0
  -- Check if this is the first widget (aligning to targetFrame or a tab container)
  local isFirstWidget = t == self.targetFrame or (self.tabbed and t.tabIndex ~= nil)

  if isFirstWidget then
    if self.index then
      -- In tabbed mode, tab containers are already offset, so widgets inside don't need additional offset
      -- In non-tabbed mode, widgets need to account for index width
      local indexWidth = self.indexFrame and self.indexFrame:GetWidth() or 0
      local leftOffset = (self.tabbed and t.tabIndex and 0 or indexWidth) + 10 + indent
      container:SetPoint("TOPLEFT", t, "TOPLEFT", leftOffset, -10)
    else
      container:SetPoint("TOPLEFT", t, "TOPLEFT", 10 + indent, -10)
    end
    container:SetPoint("TOPRIGHT", t, "TOPRIGHT", -20, -10)
    self:addHeight(10)
  else
    container:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0 + indent, -20)
    container:SetPoint("RIGHT", self.targetFrame, "RIGHT", -20, 0)
    self:addHeight(20)
  end
end

---@private
---@param container Frame
---@param title string
---@param color? table
---@return FontString
function stackedLayout:createTitle(container, title, color)
  local titleFont = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  if color then
    titleFont:SetTextColor(unpack(color))
  else
    titleFont:SetTextColor(1, 1, 1)
  end
  titleFont:SetJustifyH("LEFT")
  titleFont:SetText(title)
  return titleFont
end

---@private
---@param container Frame
---@param description string
---@param color? table
---@return FontString
function stackedLayout:createDescription(container, description, color)
  local descriptionFont = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if color then
    descriptionFont:SetTextColor(unpack(color))
  else
    descriptionFont:SetTextColor(1, 1, 1)
  end
  descriptionFont:SetJustifyH("LEFT")
  descriptionFont:SetText(description)
  descriptionFont:SetWordWrap(true)
  descriptionFont:SetNonSpaceWrap(true)
  return descriptionFont
end

---@private
---@param parent Frame
---@return Frame
function stackedLayout:createDividerLineMiddle(parent)
  local container = CreateFrame("Frame", nil, parent)
  local white = CreateColor(1, 1, 1, 1)
  local faded = CreateColor(1, 1, 1, 0.2)
  local left = container:CreateTexture(nil, "ARTWORK")

  left:SetGradient("HORIZONTAL", faded, white)
  left:SetColorTexture(1, 1, 1, 1)
  left:SetHeight(1)
  left:SetWidth(100)

  local middle = container:CreateTexture(nil, "ARTWORK")
  middle:SetColorTexture(1, 1, 1, 1)
  middle:SetHeight(1)

  local right = container:CreateTexture(nil, "ARTWORK")
  right:SetGradient("HORIZONTAL", white, faded)
  right:SetColorTexture(1, 1, 1, 1)
  right:SetHeight(1)
  right:SetWidth(100)

  left:SetPoint("LEFT", container, "LEFT")
  middle:SetPoint("LEFT", left, "RIGHT")
  middle:SetPoint("RIGHT", right, "LEFT")
  right:SetPoint("RIGHT", container, "RIGHT")
  container:SetHeight(3)
  return container
end

---@private
---@param parent Frame
---@return Frame
function stackedLayout:createDividerLineLeft(parent)
  local container = CreateFrame("Frame", nil, parent)
  local white = CreateColor(1, 1, 1, 1)
  local faded = CreateColor(1, 1, 1, 0.2)

  local left = container:CreateTexture(nil, "ARTWORK")
  left:SetColorTexture(1, 1, 1, 1)
  left:SetHeight(1)

  local right = container:CreateTexture(nil, "ARTWORK")
  right:SetGradient("HORIZONTAL", white, faded)
  right:SetColorTexture(1, 1, 1, 1)
  right:SetHeight(1)
  right:SetWidth(100)

  left:SetPoint("LEFT", container, "LEFT")
  right:SetPoint("LEFT", left, "RIGHT")
  right:SetPoint("RIGHT", container, "RIGHT")

  container:SetHeight(3)
  return container
end

---@param opts FormSectionOptions
function stackedLayout:AddSection(opts)
  if self.tabbed then
    -- Create a new container frame for this tab as a direct child of targetFrame
    -- This ensures proper scrolling behavior
    local tabContainer = CreateFrame("Frame", nil, self.targetFrame)
    -- Position tab container to the right of the index frame
    local leftOffset = (self.indexFrame and self.indexFrame:GetWidth() or 0) + 10
    tabContainer:SetPoint("TOPLEFT", self.targetFrame, "TOPLEFT", leftOffset, -10)
    tabContainer:SetPoint("RIGHT", self.targetFrame, "RIGHT", -20, 0)
    tabContainer:SetHeight(2000)  -- Start with large height, will be updated by Resize()
    tabContainer:Hide()  -- Start hidden

    -- Create fade animations for this tab
    local fadeIn, fadeOut = animations:AttachFadeGroup(tabContainer, true)

    table.insert(self.tabContainers, tabContainer)
    table.insert(self.tabFadeIns, fadeIn)
    table.insert(self.tabFadeOuts, fadeOut)
    table.insert(self.tabHeights, 0)  -- Initialize height tracker for this tab

    -- Store the current tab index for height tracking
    local currentTabIndex = #self.tabContainers

    -- Reset nextFrame to start of this tab's container
    self.nextFrame = tabContainer
    self.nextFrame.tabIndex = currentTabIndex  -- Tag the frame with its tab index for height tracking

    -- Create section header within the tab container
    local container = CreateFrame("Frame", nil, tabContainer) --[[@as FormSection]]
    self:alignFrame(tabContainer, container, 0)

    container.title = self:createTitle(container, opts.title)
    container.title:SetPoint("TOPLEFT", container, "TOPLEFT")

    container.description = self:createDescription(container, opts.description)
    container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
    container.description:SetPoint("RIGHT", container, "RIGHT", -10, 0)

    local div = self:createDividerLineLeft(container)
    div:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
    div:SetPoint("RIGHT", container, "RIGHT", -10, 0)

    container:SetHeight(container.title:GetHeight() + container.description:GetHeight() + 18)

    self:addIndex(opts.title, container, false)
    self.nextFrame = container
    self:addHeight(container:GetHeight())

    -- Show first tab by default (height will be set by Resize() as widgets are added)
    if #self.tabContainers == 1 then
      tabContainer:Show()
      tabContainer:SetAlpha(1)
      self:UpdateTabHighlighting(1)
    end
  else
    -- Existing stacked behavior (unchanged)
    local t = self.nextFrame
    local container = CreateFrame("Frame", nil, t) --[[@as FormSection]]
    self:alignFrame(t, container)

    container.title = self:createTitle(container, opts.title)
    container.title:SetPoint("TOPLEFT", container, "TOPLEFT")

    container.description = self:createDescription(container, opts.description)
    container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
    container.description:SetPoint("RIGHT", container, "RIGHT", -10, 0)

    local div = self:createDividerLineLeft(container)
    div:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
    div:SetPoint("RIGHT", container, "RIGHT", -10, 0)

    container:SetHeight(container.title:GetHeight() + container.description:GetHeight() + 18)

    self:addIndex(opts.title, container)
    self.nextFrame = container
    self:addHeight(container:GetHeight())
  end
end

--- Adds a subsection header inline in the pane content (title, description, divider).
--- Does NOT add to the sidebar index. Use for visual grouping within a tab.
---@param opts FormInlineSubSectionOptions
function stackedLayout:AddInlineSubSection(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormSubSection]]
  self:alignFrame(t, container)

  local titleContainer = CreateFrame("Frame", nil, container)
  titleContainer:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)
  titleContainer:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  container.title = self:createTitle(titleContainer, opts.title)
  container.title:SetPoint("TOPLEFT", titleContainer, "TOPLEFT")
  container.description = self:createDescription(container, opts.description)
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
  container.description:SetPoint("RIGHT", container, "RIGHT", -10, 0)
  local div = self:createDividerLineMiddle(container)
  div:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  div:SetPoint("RIGHT", container, "RIGHT", -10, 0)
  container:SetHeight(container.title:GetLineHeight() + container.description:GetLineHeight() + 33)

  self.nextFrame = container
  self:addHeight(container:GetHeight())
end

--- Adds a navigation entry to the sidebar index only.
--- Does NOT render any content in the pane. Use for sub-navigation items.
---@param opts FormSubIndexOptions
function stackedLayout:AddSubIndex(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormSubSection]]
  self:addIndex(opts.title, container, true)
end

---@param opts FormCheckboxOptions
function stackedLayout:AddCheckbox(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormCheckbox]]
  self:alignFrame(t, container)

  container.checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate") --[[@as CheckButton]]
  container.checkbox:SetPoint("TOPLEFT", container, "TOPLEFT")
  addon.SetScript(container.checkbox, "OnClick", function(ctx)
    opts.setValue(ctx, container.checkbox:GetChecked())
    self:ReloadAllFormElements()
  end)
  container.checkbox:SetChecked(opts.getValue(context:New('Checkbox_Load')))

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("LEFT", container.checkbox, "RIGHT", 5, 0)
  container.title:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
  container.description:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  container:SetHeight(container.title:GetLineHeight() + container.description:GetLineHeight() + 25)
  self.nextFrame = container
  self:addHeight(container:GetHeight())
  self.checkboxes[container] = opts
end

---@private
---@param opts FormDropdownOptions
function stackedLayout:addDropdownRetail(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormDropdown]]
  self:alignFrame(t, container)

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container.dropdown = CreateFrame("DropdownButton", nil, container, "WowStyle1DropdownTemplate") --[[@as DropdownButton]]
  container.dropdown:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  container.dropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  ---@type string[]
  local itemList = {}

  if opts.items then
    itemList = opts.items --[=[@as string[]]=]
  elseif opts.itemsFunction then
    local ctx = context:New('Dropdown_Items')
    itemList = opts.itemsFunction(ctx) --[=[@as string[]]=]
  end

  container.dropdown:SetupMenu(function(_, root)
    root:SetScrollMode(20 * 20)
    for _, item in ipairs(itemList) do
      root:CreateCheckbox(item, function(value)
        local ctx = context:New('Dropdown_Get')
        return opts.getValue(ctx, value)
      end,
      function(value)
        local ctx = context:New('Dropdown_Set')
        opts.setValue(ctx, value)
        self:ReloadAllFormElements()
      end, item)
    end
  end)

  container.dropdown:GenerateMenu()

  container:SetHeight(
    container.title:GetLineHeight() +
    container.description:GetLineHeight() +
    container.dropdown:GetHeight() +
    25
  )
  self.nextFrame = container
  self:addHeight(container:GetHeight())
  self.dropdowns[container] = opts
end

---@private
---@param opts FormDropdownOptions
function stackedLayout:addDropdownClassic(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormDropdown]]
  self:alignFrame(t, container)

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container.classicDropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate") --[[@as Frame]]
  container.classicDropdown:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  container.classicDropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)

  ---@type string[]
  local itemList = {}

  if opts.items then
    itemList = opts.items --[=[@as string[]]=]
  elseif opts.itemsFunction then
    local ctx = context:New('Dropdown_Items')
    itemList = opts.itemsFunction(ctx) --[=[@as string[]]=]
  end

   -- Create and bind the initialization function to the dropdown menu
  UIDropDownMenu_Initialize(container.classicDropdown, function(_, level, _)
   for _, item in ipairs(itemList) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = item
    info.checked = function()
      local ctx = context:New('Dropdown_Get')
      return opts.getValue(ctx, item)
    end
    info.func = function()
      UIDropDownMenu_SetText(container.classicDropdown, item)
      local ctx = context:New('Dropdown_Set')
      opts.setValue(ctx, item)
      self:ReloadAllFormElements()
    end
    UIDropDownMenu_AddButton(info, level)
   end
  end)

  if opts.items ~= nil then
    for _, item in ipairs(opts.items) do
      local ctx = context:New('Dropdown_Load')
      if opts.getValue(ctx, item) then
        UIDropDownMenu_SetText(container.classicDropdown, item)
        break
      end
    end
  end

  container:SetHeight(
    container.title:GetLineHeight() +
    container.description:GetLineHeight() +
    container.classicDropdown:GetHeight() +
    25
  )
  self.nextFrame = container
  self:addHeight(container:GetHeight())
  self.dropdowns[container] = opts
end

---@param opts FormDropdownOptions
function stackedLayout:AddDropdown(opts)
  if addon.isRetail then
    self:addDropdownRetail(opts)
    return
  end
  self:addDropdownClassic(opts)
end

---@param opts FormSliderOptions
function stackedLayout:AddSlider(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormSlider]]
  self:alignFrame(t, container)

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  if addon.isRetail then
    container.slider = CreateFrame("Slider", nil, container, "UISliderTemplate") --[[@as Slider]]
  else
    container.slider = CreateFrame("Slider", nil, container, "HorizontalSliderTemplate") --[[@as Slider]]
  end
  container.slider:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  container.slider:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  container.slider:SetOrientation("HORIZONTAL")
  container.slider:SetHeight(20)
  container.slider:SetMinMaxValues(opts.min, opts.max)
  container.slider:SetValueStep(opts.step)
  container.slider:SetObeyStepOnDrag(true)
  addon.SetScript(container.slider, "OnValueChanged", function(ctx, _, value, user)
    opts.setValue(ctx, value)
    if user then
      container.input:SetText(tostring(value))
      self:ReloadAllFormElements()
    end
  end)

  container.input = CreateFrame("EditBox", nil, container, "InputBoxTemplate") --[[@as EditBox]]
  container.input:SetSize(50, 20)
  container.input:SetPoint("TOP", container.slider, "BOTTOM", 0, -5)
  container.input:SetNumeric(true)
  container.input:SetAutoFocus(false)
  addon.SetScript(container.input, "OnEditFocusLost", function(_)
    local value = tonumber(container.input:GetText())
    if value then
      if value < opts.min then
        value = opts.min
      elseif value > opts.max then
        value = opts.max
      end
      container.slider:SetValue(value)
      container.input:SetText(tostring(value))
    end
    container.input:SetText(tostring(container.slider:GetValue()))
    self:ReloadAllFormElements()
  end)
  addon.SetScript(container.input, "OnTextChanged", function(_, _, user)
    if user then
      local value = tonumber(container.input:GetText())
      if value then
        if value < opts.min then
          value = opts.min
        elseif value > opts.max then
          value = opts.max
        end
        container.slider:SetValue(value)
        container.input:SetText(tostring(value))
      end
    else
      container.input:SetText(tostring(container.slider:GetValue()))
    end
  end)

  container.slider:SetValue(opts.getValue(context:New('Slider_Load')))

  container:SetHeight(
    container.title:GetLineHeight() +
    container.description:GetLineHeight() +
    container.slider:GetHeight() +
    container.input:GetHeight() +
    30
  )
  self.nextFrame = container
  self:addHeight(container:GetHeight())
  self.sliders[container] = opts
end

---@param opts FormButtonGroupOptions
function stackedLayout:AddButtonGroup(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormButtons]]
  self:alignFrame(t, container)
  container.buttons = {}

  for _, buttonData in ipairs(opts.ButtonOptions) do
    local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate") --[[@as Button]]
    button:SetText(buttonData.title)
    local w = button:GetFontString():GetStringWidth()
    button:SetSize(w + 20, 24)
    addon.SetScript(button, "OnClick", function(ctx)
      buttonData.onClick(ctx)
    end)
    if #container.buttons == 0 then
      button:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)
    else
      button:SetPoint("TOPLEFT", container.buttons[#container.buttons], "TOPRIGHT", 10, 0)
    end
    table.insert(container.buttons, button)
  end

  container:SetHeight(container.buttons[1]:GetHeight() + 30)
  self.nextFrame = container
  self:addHeight(container:GetHeight())
  self.buttonGroups[container] = opts
end

---@param opts FormTextAreaOptions
function stackedLayout:AddTextArea(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormTextArea]]
  self:alignFrame(t, container)

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
  container.description:SetPoint("RIGHT", container, "RIGHT", -20, 0)

  local ScrollBox = CreateFrame("Frame", nil, container, "WowScrollBox") --[[@as WowScrollBox]]
  ScrollBox:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
  ScrollBox:SetPoint("RIGHT", container, "RIGHT", -20, 0)
  ScrollBox:SetHeight(100)
  ScrollBox:EnableMouseWheel(false)

  local ScrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar") --[[@as MinimalScrollBar]]
  ScrollBar:SetPoint("TOPLEFT", ScrollBox, "TOPRIGHT", 4, -2)
  ScrollBar:SetPoint("BOTTOMLEFT", ScrollBox, "BOTTOMRIGHT", 2, 0)

  ScrollBar:SetHideIfUnscrollable(true)
  ScrollBox:SetInterpolateScroll(true)
  ScrollBar:SetInterpolateScroll(true)

  local scrollBackground = self:createTextAreaBackground(ScrollBox)
  scrollBackground:SetPoint("TOPLEFT", ScrollBox, "TOPLEFT", 0, 0)
  scrollBackground:SetPoint("BOTTOMRIGHT", ScrollBox, "BOTTOMRIGHT", 0, 0)
  local view = CreateScrollBoxLinearView()
  view:SetPanExtent(10)

  local editBox = CreateFrame("EditBox", nil, ScrollBox) --[[@as EditBox]]
  editBox:SetFontObject("ChatFontNormal")
  editBox:SetMultiLine(true)
  editBox:EnableMouse(true)
  editBox:SetCountInvisibleLetters(false)
  editBox:SetAutoFocus(false)
  editBox.scrollable = true

  addon.SetScript(editBox, "OnEscapePressed", function()
    editBox:ClearFocus()
    ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
  end)

  addon.SetScript(editBox, "OnEditFocusGained", function()
    ScrollBox:EnableMouseWheel(true)
  end)

  addon.SetScript(editBox, "OnEditFocusLost", function()
    if opts.setValue then
      opts.setValue(context:New('InputBox_Set'), editBox:GetText())
    end
    ScrollBox:EnableMouseWheel(false)
  end)

  addon.SetScript(editBox, "OnTextChanged", function(_, _, user)
    ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    ScrollBox:ScrollToEnd()
    if opts.setValue and user then
      opts.setValue(context:New('TextArea_Set'), editBox:GetText())
    end
  end)

  addon.SetScript(ScrollBox, "OnMouseDown", function()
    editBox:SetFocus()
  end)

  container.input = editBox

  container:SetHeight(
    container.title:GetLineHeight() +
    container.description:GetLineHeight() +
    ScrollBox:GetHeight() +
    30
  )

  ScrollUtil.InitScrollBoxWithScrollBar(ScrollBox, ScrollBar, view)
  self.nextFrame = container
  self:addHeight(container:GetHeight())
  self.textAreas[container] = opts
end

---@param opts FormInputBoxOptions
function stackedLayout:AddInputBox(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormInputBox]]
  self:alignFrame(t, container)

  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)

  container.input = CreateFrame("EditBox", nil, container, "InputBoxTemplate") --[[@as EditBox]]
  container.input:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 5, -5)
  container.input:SetPoint("RIGHT", container, "RIGHT", -5, 0)
  container.input:SetHeight(20)
  container.input:SetAutoFocus(false)
  container.input:SetFontObject("GameFontHighlight")
  container.input:SetText(opts.getValue(context:New('InputBox_Load')))
  addon.SetScript(container.input, "OnEditFocusLost", function(_)
    local value = container.input:GetText()
    opts.setValue(context:New('InputBox_Set'), value)
    self:ReloadAllFormElements()
  end)

  addon.SetScript(container.input, "OnTextChanged", function(_, _, user)
    if user then
      local value = container.input:GetText()
      opts.setValue(context:New('InputBox_Set'), value)
    end
  end)

  container:SetHeight(
    container.title:GetLineHeight() +
    container.description:GetLineHeight() +
    container.input:GetHeight() +
    30
  )

  self.nextFrame = container
  self:addHeight(container:GetHeight())
  self.inputBoxes[container] = opts
end

---@param opts FormColorOptions
function stackedLayout:AddColor(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormColor]]
  self:alignFrame(t, container)

  container.colorPicker = CreateFrame("Frame", nil, container) --[[@as Frame]]
  container.colorPicker:SetPoint("TOPLEFT", container, "TOPLEFT")
  container.colorPicker:SetSize(28, 28)

  local tex = container.colorPicker:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture(5014189)
  local mask = container:CreateMaskTexture()
  mask:SetAllPoints(tex)
  mask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  tex:AddMaskTexture(mask)
  local defaultColor = opts.getValue(context:New('Color_Load'))
  tex:SetVertexColor(defaultColor.red, defaultColor.green, defaultColor.blue, defaultColor.alpha)
  container.colorTexture = tex

  local function OnColorChanged()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local a = ColorPickerFrame:GetColorAlpha()
    opts.setValue(context:New('Color_Set'), {
      red = r,
      green = g,
      blue = b,
      alpha = a
    })
    tex:SetVertexColor(r, g, b, a)
    self:ReloadAllFormElements()
  end

  container.colorPicker:SetScript("OnMouseDown", function()
    local color = opts.getValue(context:New('Color_Load'))
    local options = {
      swatchFunc = OnColorChanged,
      opacityFunc = OnColorChanged,
      cancelFunc = function() end,
      hasOpacity = true,
      opacity = color.alpha,
      r = color.red,
      g = color.green,
      b = color.blue,
    }
    ColorPickerFrame:SetupColorPickerAndShow(options)
  end)
  container.title = self:createTitle(container, opts.title, {0.75, 0.75, 0.75})
  container.title:SetPoint("LEFT", container.colorPicker, "RIGHT", 5, 0)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)


  container:SetHeight(
    container.title:GetLineHeight() +
    container.description:GetLineHeight() +
    container.colorPicker:GetHeight() +
    30
  )

  self.nextFrame = container
  self:addHeight(container:GetHeight())
  self.colorPickers[container] = opts
end

---@param opts FormLabelOptions
function stackedLayout:AddLabel(opts)
  local t = self.nextFrame
  local container = CreateFrame("Frame", nil, t) --[[@as FormLabel]]
  self:alignFrame(t, container)

  container.description = self:createDescription(container, opts.description, {0.75, 0.75, 0.75})
  container.description:SetPoint("TOPLEFT", container, "TOPLEFT", 37, 0)
  container.description:SetPoint("RIGHT", container, "RIGHT", -5, 0)

  container:SetHeight(container.description:GetStringHeight() + 10)
  self.nextFrame = container
  self:addHeight(container:GetHeight())
end

---@param paneIndex number
function stackedLayout:ShowPane(paneIndex)
  if self.activePane == paneIndex then return end

  local paneFrame = self.panes[paneIndex]
  if not paneFrame then return end

  -- Store the current tab so we can return to it
  self.previousTab = self.activeTab

  -- Hide all tab containers
  for i, container in ipairs(self.tabContainers) do
    if container:IsShown() then
      local fadeOut = self.tabFadeOuts[i]
      fadeOut.callback = function()
        container:Hide()
      end
      fadeOut:Play()
    end
  end

  -- Hide any currently active pane
  if self.activePane then
    local currentPane = self.panes[self.activePane]
    if currentPane and currentPane:IsShown() then
      local fadeOut = self.paneFadeOuts[self.activePane]
      fadeOut.callback = function()
        currentPane:Hide()
      end
      fadeOut:Play()
    end
  end

  -- Show the new pane
  self.activePane = paneIndex

  -- Set targetFrame height to match the scrollBox's visible area.
  -- This ensures the pane fills exactly the viewport without causing outer scrolling.
  -- Panes are designed to fill available space with their own internal scrolling.
  if self.scrollBox then
    local viewportHeight = self.scrollBox:GetHeight()
    if viewportHeight and viewportHeight > 0 then
      self.targetFrame:SetHeight(viewportHeight)
      self.scrollBox:FullUpdate(true)
    end
  end

  paneFrame:Show()
  paneFrame:SetAlpha(0)
  local fadeIn = self.paneFadeIns[paneIndex]
  fadeIn:Play()

  -- Update tab highlighting to show the pane's index as active
  for i, section in ipairs(self.sections) do
    if section.paneIndex == paneIndex then
      self:UpdateTabHighlighting(i)
      break
    end
  end

  -- Reset scroll to top
  if self.scrollBox then
    self.scrollBox:SetScrollPercentage(0)
  end
end

function stackedLayout:HidePane()
  if not self.activePane then return end

  local paneFrame = self.panes[self.activePane]
  if not paneFrame then return end

  -- Hide the pane
  local fadeOut = self.paneFadeOuts[self.activePane]
  fadeOut.callback = function()
    paneFrame:Hide()
  end
  fadeOut:Play()

  self.activePane = nil

  -- Show the previous tab
  local tabToShow = self.previousTab or 1
  local tabContainer = self.tabContainers[tabToShow]
  if tabContainer then
    tabContainer:Show()
    tabContainer:SetAlpha(0)
    local fadeIn = self.tabFadeIns[tabToShow]
    fadeIn:Play()
    self.activeTab = tabToShow
    self:UpdateTabHighlighting(tabToShow)
  end

  self.previousTab = nil

  -- Reset scroll to top
  if self.scrollBox then
    self.scrollBox:SetScrollPercentage(0)
  end
end

---@return boolean
function stackedLayout:IsPaneActive()
  return self.activePane ~= nil
end

--- Adds a pane link to the sidebar index that navigates to a separate pane.
--- Does NOT render any inline content. Only adds sidebar navigation entry.
---@param opts FormPaneLinkOptions
function stackedLayout:AddPaneLink(opts)
  if not self.tabbed then
    -- PaneLinks only work in tabbed mode
    return
  end

  -- Create the pane frame that will be shown when this link is clicked
  local paneIndex = #self.panes + 1
  local paneFrame = opts.createPane(self.targetFrame, opts.bagKind)
  -- Position pane to the right of the index frame
  local leftOffset = (self.indexFrame and self.indexFrame:GetWidth() or 0) + 10
  paneFrame:SetPoint("TOPLEFT", self.targetFrame, "TOPLEFT", leftOffset, -10)
  paneFrame:SetPoint("BOTTOMRIGHT", self.targetFrame, "BOTTOMRIGHT", 0, 0)
  paneFrame:Hide()

  -- Create fade animations for this pane
  local fadeIn, fadeOut = animations:AttachFadeGroup(paneFrame, true)

  table.insert(self.panes, paneFrame)
  table.insert(self.paneFadeIns, fadeIn)
  table.insert(self.paneFadeOuts, fadeOut)

  -- Add to index with pane navigation (no inline content)
  local indexButton = CreateFrame("Button", nil, self.indexFrame) --[[@as Button]]
  indexButton:SetSize(100, 24)
  local font = indexButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  indexButton:SetFontString(font)
  indexButton:SetText("  " .. opts.title)
  local fs = indexButton:GetFontString()
  fs:SetTextColor(1, 1, 1)
  fs:ClearAllPoints()
  fs:SetPoint("LEFT", indexButton, "LEFT", 5, 0)
  fs:SetJustifyH("LEFT")

  -- Hover effect
  indexButton:SetScript("OnEnter", function()
    fs:SetTextColor(1, 0.9, 0.5)
    fs:SetShadowColor(1, 0.8, 0.3, 0.8)
    fs:SetShadowOffset(0, 0)
  end)

  indexButton:SetScript("OnLeave", function()
    if self.activePane ~= paneIndex then
      fs:SetTextColor(1, 1, 1)
      fs:SetShadowColor(0, 0, 0, 1)
      fs:SetShadowOffset(1, -1)
    else
      fs:SetTextColor(1, 0.82, 0)
      fs:SetShadowColor(1, 0.8, 0.3, 0.8)
      fs:SetShadowOffset(0, 0)
    end
  end)

  indexButton:SetScript("OnClick", function()
    self:ShowPane(paneIndex)
  end)

  if self.nextIndex == self.indexFrame then
    indexButton:SetPoint("TOPLEFT", self.indexFrame, "TOPLEFT", 5, -10)
  else
    indexButton:SetPoint("TOPLEFT", self.nextIndex, "BOTTOMLEFT", 0, -5)
  end

  table.insert(self.sections, {button = indexButton, paneIndex = paneIndex})
  self.nextIndex = indexButton
end

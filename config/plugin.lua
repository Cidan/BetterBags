local addon = GetBetterBags()

local debug = addon:GetDebug()

local config = addon:GetConfig()

---@param c table<string, AceConfig.OptionsTable>
---@param result AceConfig.OptionsTable[]
function config:flattenPluginConfig(c, result)
  for _, t in pairs(c) do
    if t.type == 'group' then
      self:flattenPluginConfig(t.args, result)
    else
      table.insert(result, t)
    end
  end
end

---@param title string
---@param c AceConfig.OptionsTable
function config:AddPluginConfig(title, c)
  if not self.configFrame then
    config:OnEnable()
    self.configFrame:AddSection({
      title = "Plugins",
      description = "Plugins that are enabled can be configured here.",
    })
  end
  local f = self.configFrame
  f:AddSubSection({
    title = title,
    description = "Configuration for the '" .. title .. "' plugin.",
  })
  ---@type AceConfig.OptionsTable[]
  local options = {}
  self:flattenPluginConfig(c, options)
  for _, o in ipairs(options) do
    ---@type string, string
    local subTitle, subDesc
    if type(o.name) == 'function' then
      subTitle = o.name() --[[@as string]]
    else
      subTitle = o.name --[[@as string]]
    end
    if type(o.desc) == 'function' then
      subDesc = o.desc() --[[@as string]]
    else
      subDesc = o.desc --[[@as string]]
    end
    if o.type == 'toggle' then
      f:AddCheckbox({
        title = subTitle,
        description = subDesc,
        getValue = function(_)
          return o.get()
        end,
        setValue = function(_, value)
          o.set(_, value)
        end
      })
    elseif o.type =='execute' then
      f:AddButtonGroup({
        ButtonOptions = {{
          title = subTitle,
          onClick = function(_)
            o.func()
          end
        }}
      })
    elseif o.type == 'select' then
      ---@type string[], function
      local valueList, valueFunc

      if type(o.values) == 'function' then
        valueFunc = function(_)
          local iv = o.values() --[[@as table<any, string>]]
          local result = {}
          for _, v in pairs(iv) do
            table.insert(result, v) --[[@as string]]
          end
          return result
        end
      else
        valueList = o.values --[=[@as string[]]=]
      end

      f:AddDropdown({
        title = subTitle,
        description = subDesc,
        items = valueList,
        itemsFunction = valueFunc,
        getValue = function(_, value)
          return value == o.get()
        end,
        setValue = function(_, value)
          o.set(_, value)
        end
      })
    elseif o.type == 'input' and o.multiline then
      f:AddTextArea({
        title = subTitle,
        description = subDesc,
        getValue = function(_)
          return o.get()
        end,
        setValue = function(_, value)
          if o.set then
            o.set(_, value)
          end
        end
      })
    elseif o.type == 'input' then
      f:AddInputBox({
        title = subTitle,
        description = subDesc,
        getValue = function(_)
          return o.get()
        end,
        setValue = function(_, value)
          if o.set then
            o.set(_, value)
          end
        end
      })
    elseif o.type == 'color' then
      f:AddColor({
        title = subTitle,
        description = subDesc,
        getValue = function(_)
          ---@type number, number, number, number|nil
          local r, g, b, a = o.get()
          if a == nil then a = 1 end
          return {red = r, green = g, blue = b, alpha = a}
        end,
        setValue = function(_, value)
          o.set(_, value.red, value.green, value.blue, value.alpha)
        end
      })
    else
      debug:Log("PluginConfig", "Unsupported option type for plugin config: ", o.type)
    end
  end
end
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Config: AceModule
local config = addon:GetModule('Config')

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
          o.set(value)
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
    else
      print("Unsupported option type for plugin config: " .. o.type)
    end
  end
end
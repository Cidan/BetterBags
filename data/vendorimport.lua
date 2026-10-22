local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class VendorRule: AceModule
local vendorRule = addon:GetModule('VendorRule')

-- VendorImport reads the rules a player wrote in the Vendor addon and makes BetterBags categories of
-- them, each rule converted into a search (VendorRule; docs/vendor-compat.md, search-indexing.md §18).
-- Vendor's saved variables are only there while Vendor is loaded.
---@class VendorImport: AceModule
local VendorImport = addon:NewModule('VendorImport')

---@class VendorImportRule
---@field id string Vendor's ID for the rule.
---@field name string
---@field type? string Keep, Sell or Destroy.
---@field description? string
---@field script? string The rule (Vendor's Script); nil when Vendor saved it as something other than text.
---@field params table<string, any> Its parameters' values: the active Vendor profile's, else their defaults.

---@class VendorImportReport
---@field created {rule: VendorImportRule, query: string, notes: string[]}[] The categories made.
---@field skipped {rule: VendorImportRule, reason: string}[] The rules no category was made for, and why.

-- A Vendor profile's rule lists (vendor/profileimpl.lua).
local PROFILE_LISTS = { "rules:keep", "rules:sell", "rules:destroy" }

-- profileEntry returns the active Vendor profile's entry for a rule that sets its parameters:
-- { rule = id, KEY = value } (rules/ruleconfig.lua). Vendor_ActiveProfile is saved per character.
---@param id string
---@return table?
local function profileEntry(id)
  local profiles, active = _G.Vendor_Profiles, _G.Vendor_ActiveProfile
  local profile = type(profiles) == "table" and type(active) == "string" and profiles[active]
  if type(profile) ~= "table" then
    return nil
  end
  local wanted = string.lower(id)
  for _, list in ipairs(PROFILE_LISTS) do
    for _, entry in ipairs(type(profile[list]) == "table" and profile[list] or {}) do
      if type(entry) == "table" and type(entry.rule) == "string" and string.lower(entry.rule) == wanted then
        return entry
      end
    end
  end
  return nil
end

---@param v any
---@return boolean
local function plain(v)
  return type(v) == "number" or type(v) == "boolean" or type(v) == "string"
end

---@param definition table A custom rule as Vendor saves it (rules/definitions.lua, UpdateDefinition).
---@return VendorImportRule
local function ruleOf(definition)
  local id = tostring(definition.Id)
  local params = {}
  for _, param in ipairs(type(definition.Params) == "table" and definition.Params or {}) do
    if type(param) == "table" and type(param.Key) == "string" and plain(param.Default) then
      params[param.Key] = param.Default
    end
  end
  for key, v in pairs(profileEntry(id) or {}) do
    if key ~= "rule" and plain(v) then
      params[key] = v
    end
  end
  return {
    id = id,
    name = tostring(definition.Name or id),
    type = definition.Type,
    description = definition.Description,
    script = type(definition.Script) == "string" and definition.Script or nil,
    params = params,
  }
end

-- Rules reads the custom rules Vendor saved (Vendor_CustomRuleDefinitions): the list Vendor reads,
-- then the rules an older Vendor saved under their ID, which Vendor no longer reads, by ID. A rule
-- is read once, whatever the case of its ID.
---@return VendorImportRule[]
function VendorImport:Rules()
  local saved = _G.Vendor_CustomRuleDefinitions
  if type(saved) ~= "table" then
    return {}
  end
  local rules, seen = {}, {}
  local function add(definition)
    if type(definition) ~= "table" or definition.Id == nil then
      return
    end
    local key = string.lower(tostring(definition.Id))
    if seen[key] then
      return
    end
    seen[key] = true
    table.insert(rules, ruleOf(definition))
  end
  for _, definition in ipairs(saved) do
    add(definition)
  end
  local older = {}
  for key in pairs(saved) do
    if type(key) == "string" then
      table.insert(older, key)
    end
  end
  table.sort(older)
  for _, key in ipairs(older) do
    add(saved[key])
  end
  return rules
end

-- Convert converts a rule into a search for the client BetterBags runs on (VendorRule:Convert).
---@param rule VendorImportRule
---@return VendorRuleResult
function VendorImport:Convert(rule)
  if rule.script == nil then
    return { problem = L:G("Vendor saved this rule without its text."), notes = {} }
  end
  return vendorRule:Convert(rule.script, { params = rule.params, classic = not addon.isRetail })
end

-- Import makes a saved category for each rule given (or every custom rule, Rules) that converts,
-- named as the rule is, its rule the converted search. A rule whose name a category already has, or
-- that does not convert, is skipped and said why. The bags are recalculated once when anything was
-- made (refresh-scheduler.md §10).
---@param ctx Context
---@param rules? VendorImportRule[]
---@return VendorImportReport
function VendorImport:Import(ctx, rules)
  ---@type VendorImportReport
  local report = { created = {}, skipped = {} }
  for _, rule in ipairs(rules or self:Rules()) do
    local name = (rule.name or ""):match("^%s*(.-)%s*$")
    if name == "" then
      table.insert(report.skipped, { rule = rule, reason = L:G("The rule has no name.") })
    elseif categories:DoesCategoryExist(name) then
      table.insert(report.skipped, { rule = rule, reason = format(L:G("A category named '%s' already exists."), name) })
    else
      local converted = self:Convert(rule)
      if converted.query then
        categories:CreateCategory(ctx, { name = name, itemList = {}, save = true,
          searchCategory = { query = converted.query } })
        table.insert(report.created, { rule = rule, query = converted.query, notes = converted.notes })
      else
        table.insert(report.skipped, { rule = rule, reason = converted.problem })
      end
    end
  end
  if #report.created > 0 then
    events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
  end
  return report
end

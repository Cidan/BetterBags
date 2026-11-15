local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- SonataResolve resolves themes for both of Sonata's registries: the classic bags' themes (Sonata,
-- sonata/engine.lua) and BetterBags Next's (SonataNext, sonata/next.lua). A theme inherits every
-- value it does not set from its Parent (its registry's base when it names none), each level's
-- per-client overrides apply on top of that level, and "$Name" strings take the value of the
-- theme's Variables. Resolving never changes the registered tables.
---@class SonataResolve: AceModule
local resolve = addon:NewModule('SonataResolve')

-- The client override keys a theme may use (ClientKeys).
resolve.CLIENT_KEYS = {
  Retail = true,
  Forever = true,
  Classic = true,
  Era = true,
  TBC = true,
  Mists = true,
  Anniversary = true,
  Cata = true,
}

-- Keys of a theme that describe it rather than style anything.
resolve.META_KEYS = {
  Name = true,
  DisplayName = true,
  Description = true,
  Parent = true,
  Hidden = true,
  Available = true,
  Requires = true,
  Clients = true,
}

-- IsObject reports a table that is an object rather than data (it has a metatable, or is a frame):
-- such values are kept by reference, never copied or merged into.
---@param value any
---@return boolean
function resolve.IsObject(value)
  return type(value) == "table" and (getmetatable(value) ~= nil or type(rawget(value, 0)) == "userdata")
end

---@param value any
---@return any
function resolve.DeepCopy(value)
  if type(value) ~= "table" or resolve.IsObject(value) then
    return value
  end
  local copy = {}
  for k, v in pairs(value) do
    copy[k] = resolve.DeepCopy(v)
  end
  return copy
end

---@param value any
---@return boolean
function resolve.IsList(value)
  return type(value) == "table" and value[1] ~= nil
end

-- Merge folds from into into. Tables merge key by key, lists and references (one value each) replace, and false
-- replacing a table removes it (a theme turns off something it inherited).
---@param into table
---@param from table
function resolve.Merge(into, from)
  local isList, isObject = resolve.IsList, resolve.IsObject
  for k, v in pairs(from) do
    local existing = into[k]
    if v == false and type(existing) == "table" then
      into[k] = nil
    elseif type(v) == "table" and not isList(v) and not isObject(v) and not resolve.IsReference(v)
      and type(existing) == "table" and not isList(existing) and not isObject(existing) then
      resolve.Merge(existing, v)
    else
      into[k] = resolve.DeepCopy(v)
    end
  end
end

-- StyleOf returns a theme's keys that style something (not META_KEYS).
---@param theme table
---@return table
function resolve.StyleOf(theme)
  local style = {}
  for k, v in pairs(theme) do
    if not resolve.META_KEYS[k] then
      style[k] = v
    end
  end
  return style
end

-- Substitute replaces every "$Name" string in value (a whole string, spaces around the name
-- allowed) with a copy of lookup(name).
---@param value any
---@param lookup fun(name: string): any
---@return any
function resolve.Substitute(value, lookup)
  if type(value) == "string" then
    local name = value:match("^%s*%$([%a_][%w_]*)%s*$")
    if name then
      return resolve.DeepCopy(lookup(name))
    end
    return value
  end
  if type(value) == "table" and not resolve.IsObject(value) then
    for k, v in pairs(value) do
      value[k] = resolve.Substitute(v, lookup)
    end
  end
  return value
end

-- IsReference says whether a variable names a value in another addon's tables ({ Global, Path, Fallback, Alpha, Map }:
-- next-themes-references.md §2a), read when the theme resolves (ReadReference): a table with a Global and a Fallback. A
-- theme stays data: nothing of the addon is called. A Global without a Fallback is data, as it always was (a client
-- color a palette names, next/style.lua).
---@param value any
---@return boolean
function resolve.IsReference(value)
  return type(value) == "table" and not resolve.IsObject(value) and value.Global ~= nil and value.Fallback ~= nil
end

-- ReferenceProblem returns what is wrong with a reference, or nil: Global names a global, Path is a list of keys
-- (strings or numbers), Alpha a number and Map a table when given.
---@param ref table
---@return string?
function resolve.ReferenceProblem(ref)
  if type(ref.Global) ~= "string" or ref.Global == "" then
    return "Global names a global"
  end
  if ref.Path ~= nil then
    if type(ref.Path) ~= "table" then
      return "Path is a list of keys"
    end
    for _, key in ipairs(ref.Path) do
      if type(key) ~= "string" and type(key) ~= "number" then
        return "Path is a list of keys"
      end
    end
  end
  if ref.Alpha ~= nil and type(ref.Alpha) ~= "number" then
    return "Alpha is a number"
  end
  if ref.Map ~= nil and type(ref.Map) ~= "table" then
    return "Map is a table"
  end
  return nil
end

-- Walk returns the value at path under the global named name, reading every table raw (no metamethod runs), or nil
-- where a key is missing or a value on the way is not a table.
---@param name string
---@param path? (string|number)[]
---@return any
function resolve.Walk(name, path)
  local value = rawget(_G, name)
  for _, key in ipairs(path or {}) do
    if type(value) ~= "table" then
      return nil
    end
    value = rawget(value, key)
  end
  return value
end

-- isColor says whether a table is a color the way ElvUI and Blizzard keep them: numbers at r, g and b.
---@param value any
---@return boolean
local function isColor(value)
  return type(value) == "table" and type(rawget(value, "r")) == "number" and type(rawget(value, "g")) == "number"
    and type(rawget(value, "b")) == "number"
end

-- ReadReference reads a reference: the value at its Path (Walk), mapped through Map (a value Map does not name is read
-- as it is), taken when it is the Fallback's kind, else the Fallback. A Fallback of three or four numbers takes a color
-- (r, g, b and a, read as { r, g, b, a }, opaque without an a) or a list of as many numbers; any other list of numbers
-- a list of as many; a string, a number or a boolean the same kind; false any string, number or boolean. Alpha replaces
-- a color's alpha, the fallback's too. What is read is a copy. It also returns whether the value was taken.
---@param ref table
---@return any value, boolean read
function resolve.ReadReference(ref)
  local value = resolve.Walk(ref.Global, ref.Path)
  if ref.Map ~= nil and value ~= nil then
    local mapped = ref.Map[value]
    if mapped ~= nil then
      value = mapped
    end
  end
  local fallback = ref.Fallback
  local read
  if type(fallback) == "table" then
    local n = #fallback
    if (n == 3 or n == 4) and isColor(value) then
      local a = rawget(value, "a")
      read = { rawget(value, "r"), rawget(value, "g"), rawget(value, "b"), type(a) == "number" and a or 1 }
    elseif type(value) == "table" then
      read = {}
      for i = 1, n do
        local v = rawget(value, i)
        if type(v) ~= "number" then
          read = nil
          break
        end
        read[i] = v
      end
    end
  elseif fallback == false then
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
      read = value
    end
  elseif type(value) == type(fallback) then
    read = value
  end
  local taken = read ~= nil
  if not taken then
    read = resolve.DeepCopy(fallback)
  end
  if ref.Alpha ~= nil and type(read) == "table" and #read >= 3 then
    read[4] = ref.Alpha
  end
  return read, taken
end

-- ResolveVariables evaluates a theme's variables: functions are called, references read (ReadReference), and variables
-- that refer to other variables are filled in.
---@param raw table<string, any>
---@return table<string, any> vars, fun(name: string): any lookup
function resolve.ResolveVariables(raw)
  local vars, state = {}, {}
  local lookup
  lookup = function(name)
    if state[name] == "done" then
      return vars[name]
    end
    if state[name] == "busy" then
      error("theme variables refer to each other in a cycle: $" .. name)
    end
    local value = raw[name]
    if value == nil then
      error("theme variable $" .. name .. " is not defined")
    end
    state[name] = "busy"
    if type(value) == "function" then
      value = value()
      if value == nil then
        error("theme variable $" .. name .. " returned nothing")
      end
    end
    -- What another addon holds is its own: read, never filled in.
    if resolve.IsReference(value) then
      value = resolve.ReadReference(value)
    else
      value = resolve.Substitute(resolve.DeepCopy(value), lookup)
    end
    vars[name] = value
    state[name] = "done"
    return value
  end
  for name in pairs(raw) do
    lookup(name)
  end
  return vars, lookup
end

-- ClientKeys returns the client override keys for this client, general first.
---@return string[]
function resolve:ClientKeys()
  if addon.isRetail then
    if addon.isForever then
      return { "Retail", "Forever" }
    end
    return { "Retail" }
  end
  local keys = { "Classic" }
  if addon.isAnniversary then
    table.insert(keys, "TBC")
    table.insert(keys, "Anniversary")
  elseif addon.isClassic then
    table.insert(keys, "Era")
  elseif addon.isBCC then
    table.insert(keys, "TBC")
  elseif addon.isMists then
    table.insert(keys, "Mists")
  elseif addon.isCata then
    table.insert(keys, "Cata")
  end
  return keys
end

-- CheckClients errors when a theme has overrides for a client that does not exist.
---@param theme table
function resolve:CheckClients(theme)
  for clientKey in pairs(theme.Clients or {}) do
    if not self.CLIENT_KEYS[clientKey] then
      error("theme " .. theme.Name .. " has overrides for an unknown client: " .. tostring(clientKey))
    end
  end
end

-- Chain returns the chain of themes key inherits from in themes: the theme first, base last. A
-- theme without a Parent inherits from base (unless it is base).
---@param themes table<string, table>
---@param key string
---@param base string
---@return table[]
function resolve:Chain(themes, key, base)
  local chain = {}
  local seen = {}
  local name = key
  while name ~= nil do
    local theme = themes[name]
    if theme == nil then
      error("theme " .. tostring(name) .. " is not registered")
    end
    if seen[name] then
      error("theme " .. key .. " inherits from itself")
    end
    seen[name] = true
    table.insert(chain, theme)
    if theme.Parent ~= nil then
      name = theme.Parent
    elseif name ~= base and themes[base] ~= nil then
      name = base
    else
      name = nil
    end
  end
  return chain
end

-- Resolve returns the complete style of key in themes: a new table, safe to keep, with the leaf's
-- Name, DisplayName, Description and Hidden, and its Variables evaluated.
---@param themes table<string, table>
---@param key string
---@param base string
---@return table
function resolve:Resolve(themes, key, base)
  local chain = self:Chain(themes, key, base)
  local clientKeys = self:ClientKeys()
  local resolved = {}
  for i = #chain, 1, -1 do
    local level = chain[i]
    resolve.Merge(resolved, resolve.StyleOf(level))
    if level.Clients ~= nil then
      for _, clientKey in ipairs(clientKeys) do
        local override = level.Clients[clientKey]
        if override ~= nil then
          resolve.Merge(resolved, resolve.StyleOf(override))
        end
      end
    end
  end

  local vars, lookup = resolve.ResolveVariables(resolved.Variables or {})
  resolved.Variables = nil
  resolve.Substitute(resolved, lookup)
  resolved.Variables = resolve.DeepCopy(vars)

  local leaf = chain[1]
  resolved.Name = leaf.Name
  resolved.DisplayName = leaf.DisplayName or leaf.Name
  resolved.Description = leaf.Description or ""
  resolved.Hidden = leaf.Hidden
  return resolved
end

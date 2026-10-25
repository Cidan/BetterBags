-- ui_source.lua -- the files a WoW client loads from its branch of Blizzard's UI source (.libraries/wow-ui-source, a
-- clone with every branch: install-deps.sh), and which of a list of names that code uses. By warcraft.wiki.gg's TOC
-- format rules: each addon's TOC picked by suffix (game type, then family, then none); its addon-level and per-line
-- AllowLoadGameType and ExcludeLoadGameType; [Family], [Game] and [TextLocale] expanded; glue-only lines skipped; the
-- files XML pulls in with Include and Script; an enUS client's locale. Every game type named in the source is taken as known to every client,
-- the stricter reading (one a client did not know would let a line load anywhere). For the Plain theme's art check
-- (spec/sonata/plain_art_spec.lua, docs/next-plain-theme.md).
local M = {}

M.REPO = ".libraries/wow-ui-source"

-- Each client BetterBags ships a TOC for: its branch, its game type and the names it goes by, its family, the
-- [Game] and [Family] expansions, and the TOC suffixes it looks for first.
M.CLIENTS = {
  Retail = { branch = "origin/live", types = { standard = true }, family = "mainline", game = "Standard",
    familyDir = "Mainline", suffixes = { "Standard" } },
  Forever = { branch = "origin/forever", types = { camelot = true, forever = true }, family = "mainline",
    game = "Camelot", familyDir = "Mainline", suffixes = { "Camelot", "Forever" } },
  Era = { branch = "origin/classic_era", types = { vanilla = true }, family = "classic", game = "Vanilla",
    familyDir = "Classic", suffixes = { "Vanilla" } },
  Anniversary = { branch = "origin/classic_anniversary", types = { tbc = true }, family = "classic", game = "TBC",
    familyDir = "Classic", suffixes = { "TBC" } },
  Mists = { branch = "origin/classic", types = { mists = true }, family = "classic", game = "Mists",
    familyDir = "Classic", suffixes = { "Mists" } },
}

local function run(command)
  local pipe = assert(io.popen(command))
  local out = pipe:read("*a")
  pipe:close()
  return out
end

-- Available says whether the UI source is a clone with every client's branch, and why not when it is not.
---@return boolean, string?
function M.Available()
  local out = run("git -C " .. M.REPO .. " rev-parse --verify --quiet origin/classic_era 2>/dev/null")
  if out == "" then
    return false, M.REPO .. " has no branch origin/classic_era: run install-deps.sh, which clones every branch"
  end
  return true
end

-- readAll returns the contents of paths on branch, by path, with one git cat-file --batch.
local function readAll(branch, paths)
  local list = os.tmpname()
  local f = assert(io.open(list, "w"))
  for _, path in ipairs(paths) do
    f:write(branch, ":", path, "\n")
  end
  f:close()
  local out = run("git -C " .. M.REPO .. " cat-file --batch < " .. list)
  os.remove(list)
  local contents, at = {}, 1
  for _, path in ipairs(paths) do
    local headerEnd = out:find("\n", at, true)
    local header = out:sub(at, headerEnd - 1)
    local size = tonumber(header:match("^%x+ %a+ (%d+)$"))
    if size == nil then
      at = headerEnd + 1
    else
      contents[path] = out:sub(headerEnd + 1, headerEnd + size)
      at = headerEnd + size + 2
    end
  end
  return contents
end

local function tokens(value)
  local set = {}
  for token in value:lower():gmatch("[%w]+") do
    set[token] = true
  end
  return set
end

local function allowed(client, allow, exclude)
  local function named(set)
    if set[client.family] then
      return true
    end
    for name in pairs(client.types) do
      if set[name] then
        return true
      end
    end
    return false
  end
  if next(allow) ~= nil and not named(allow) then
    return false
  end
  if next(exclude) ~= nil and named(exclude) then
    return false
  end
  return true
end

-- lineAllowed reads a line's inline directives ([AllowLoadGameType ...], [ExcludeLoadGameType ...], [AllowLoad Glue]).
local function lineAllowed(client, line)
  local allow, exclude = {}, {}
  for name, value in line:gmatch("%[(%w+)%s*([^%]]*)%]") do
    local key = name:lower()
    if key == "allowloadgametype" then
      for t in pairs(tokens(value)) do allow[t] = true end
    elseif key == "excludeloadgametype" then
      for t in pairs(tokens(value)) do exclude[t] = true end
    elseif key == "allowload" and value:lower():match("^%s*glue%s*$") then
      return false
    elseif key == "allowloadtextlocale" and not tokens(value).enus then
      -- A file for other locales' clients: this one reads enUS.
      return false
    end
  end
  return allowed(client, allow, exclude)
end

local function stripInline(line)
  return (line:gsub("%[%w+[^%]]*%]", ""))
end

-- Loaded returns the files client loads, as a list of paths in its branch.
---@param client table One of M.CLIENTS.
---@return string[]
function M.Loaded(client)
  local branch = client.branch
  local paths = {}
  for path in run("git -C " .. M.REPO .. " ls-tree -r --name-only " .. branch .. " -- Interface"):gmatch("[^\n]+") do
    paths[path:lower()] = path
  end
  local function resolve(base, name)
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/")
    local parts = {}
    for part in ((base ~= "" and (base .. "/") or "") .. name):gmatch("[^/]+") do
      if part == ".." then
        table.remove(parts)
      elseif part ~= "." then
        table.insert(parts, part)
      end
    end
    return paths[table.concat(parts, "/"):lower()]
  end
  local function expand(line)
    return (line:gsub("%[Family%]", client.familyDir):gsub("%[Game%]", client.game)
      :gsub("%[TextLocale%]", "enUS"):gsub("%[RegionalTextLocale%]", "enUS"))
  end

  -- Each addon's TOC, by suffix.
  local addons = {}
  for _, path in pairs(paths) do
    local addon = path:match("^Interface/AddOns/([^/]+)/")
    if addon then
      addons[addon] = true
    end
  end
  local tocs = {}
  for addon in pairs(addons) do
    local dir = "Interface/AddOns/" .. addon
    local candidates = {}
    for _, suffix in ipairs(client.suffixes) do
      table.insert(candidates, addon .. "_" .. suffix .. ".toc")
    end
    table.insert(candidates, addon .. "_" .. client.familyDir .. ".toc")
    table.insert(candidates, addon .. ".toc")
    for _, name in ipairs(candidates) do
      local toc = paths[(dir .. "/" .. name):lower()]
      if toc then
        table.insert(tocs, { dir = dir, path = toc })
        break
      end
    end
  end
  local tocPaths = {}
  for _, toc in ipairs(tocs) do
    table.insert(tocPaths, toc.path)
  end
  local tocText = readAll(branch, tocPaths)

  local loaded, order, xmls = {}, {}, {}
  local function add(path)
    if not loaded[path] then
      loaded[path] = true
      table.insert(order, path)
      if path:lower():match("%.xml$") then
        table.insert(xmls, path)
      end
    end
  end
  for _, toc in ipairs(tocs) do
    local text = tocText[toc.path] or ""
    local allow, exclude, glue = {}, {}, false
    for line in text:gmatch("[^\r\n]+") do
      local key, value = line:match("^##%s*(%w+)%s*:%s*(.*)$")
      if key and lineAllowed(client, line) then
        key, value = key:lower(), stripInline(value)
        if key == "allowloadgametype" then
          for t in pairs(tokens(value)) do allow[t] = true end
        elseif key == "excludeloadgametype" then
          for t in pairs(tokens(value)) do exclude[t] = true end
        elseif key == "allowload" and value:lower():match("^%s*glue%s*$") then
          glue = true
        end
      end
    end
    if not glue and allowed(client, allow, exclude) then
      add(toc.path)
      for line in text:gmatch("[^\r\n]+") do
        if not line:match("^#") and line:match("%S") then
          line = expand(line)
          if lineAllowed(client, line) then
            local path = resolve(toc.dir, stripInline(line))
            if path then
              add(path)
            end
          end
        end
      end
    end
  end

  -- The files XML pulls in, level by level.
  local done = 0
  while done < #xmls do
    local batch = {}
    for i = done + 1, #xmls do
      table.insert(batch, xmls[i])
    end
    done = #xmls
    local text = readAll(branch, batch)
    for _, xml in ipairs(batch) do
      local base = xml:match("^(.*)/[^/]+$") or ""
      for name in (text[xml] or ""):gmatch('<[Ii][Nn][Cc][Ll][Uu][Dd][Ee]%s+[Ff][Ii][Ll][Ee]%s*=%s*"([^"]+)"') do
        local path = resolve(base, name)
        if path then add(path) end
      end
      for name in (text[xml] or ""):gmatch('<[Ss][Cc][Rr][Ii][Pp][Tt]%s+[Ff][Ii][Ll][Ee]%s*=%s*"([^"]+)"') do
        local path = resolve(base, name)
        if path then add(path) end
      end
    end
  end
  return order
end

-- Uses returns which of needles (case-insensitive: the client looks atlases and files up without regard to case)
-- appear in the files client loads, with one git grep over them.
---@param client table
---@param files string[] From Loaded.
---@param needles string[]
---@return table<string, boolean>
function M.Uses(client, files, needles)
  local patterns = os.tmpname()
  local f = assert(io.open(patterns, "w"))
  for _, needle in ipairs(needles) do
    f:write(needle, "\n")
  end
  f:close()
  local found = {}
  -- In slices, so a command line stays well under the system's limit.
  local slice = 400
  for first = 1, #files, slice do
    local args = {}
    for i = first, math.min(first + slice - 1, #files) do
      table.insert(args, "'" .. files[i]:gsub("'", "'\\''") .. "'")
    end
    local command = "git -C " .. M.REPO .. " grep -h -o -i -F -f " .. patterns .. " " .. client.branch .. " -- "
      .. table.concat(args, " ")
    for match in run(command):gmatch("[^\n]+") do
      found[match:lower()] = true
    end
  end
  os.remove(patterns)
  local uses = {}
  for _, needle in ipairs(needles) do
    uses[needle] = found[needle:lower()] == true
  end
  return uses
end

return M

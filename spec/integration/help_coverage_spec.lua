-- help_coverage_spec.lua -- The help on the whole addon (spec/helpers/whole_addon.lua, help.md §1): every setting of the
-- settings catalog and every page and tab of the settings window, for both designs, explained by an article; every link
-- of an article to a settings page and every setting it shows real; every search example one the search reads, its
-- fields ones it knows; and every article shown on the Help page without an error, with each design.
local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("the help on the whole addon", function()
  local handle

  after_each(function()
    if handle then
      handle:Restore()
      handle = nil
    end
  end)

  local function start(opts)
    handle = WholeAddon.Load(opts)
    handle:Start()
    assert.are.same({}, handle.errors, "starting")
    return handle.addon
  end

  -- covered returns what the articles explain: settings by id, pages and "page:tab" by name.
  local function covered(articles)
    local settings, pages = {}, {}
    for _, a in ipairs(articles.list) do
      for _, id in ipairs(a.settings or {}) do
        settings[id] = true
      end
      for _, id in ipairs(a.pages or {}) do
        pages[id] = true
      end
    end
    return settings, pages
  end

  it("explains every setting the catalog has", function()
    local addon = start({ next = true })
    local catalog = addon:GetModule("SettingsCatalog")
    local settings = covered(addon:GetModule("HelpArticles"))
    local missing = {}
    for _, id in ipairs(catalog:Ids()) do
      if not settings[id] then
        table.insert(missing, id)
      end
    end
    assert.are.same({}, missing)
  end)

  for _, design in ipairs({ "next", "classic" }) do
    it("explains every page and tab of the settings window, with " .. design, function()
      local addon = start({ next = design == "next" })
      local pages = addon:GetModule("NextSettingsPages")
      local _, explained = covered(addon:GetModule("HelpArticles"))
      local missing = {}
      for _, page in ipairs(pages:List()) do
        if page.id ~= "help" and not page.id:find("^plugin:") then
          local tabs = {}
          for _, tab in ipairs(page.tabs) do
            if pages:InDesign(tab) then
              table.insert(tabs, tab)
            end
          end
          if #tabs == 1 then
            if not explained[page.id] and not explained[page.id .. ":" .. tabs[1].id] then
              table.insert(missing, page.id)
            end
          else
            for _, tab in ipairs(tabs) do
              if not explained[page.id .. ":" .. tab.id] then
                table.insert(missing, page.id .. ":" .. tab.id)
              end
            end
          end
        end
      end
      assert.are.same({}, missing)
    end)
  end

  it("links only to settings pages, tabs and settings that exist", function()
    local seen = {}
    for _, design in ipairs({ "next", "classic" }) do
      local addon = start({ next = design == "next" })
      local pages = addon:GetModule("NextSettingsPages")
      local catalog = addon:GetModule("SettingsCatalog")
      local bags = {}
      for _, bag in ipairs(catalog:Bags()) do
        bags[bag.name] = bag
      end
      for _, a in ipairs(addon:GetModule("HelpArticles").list) do
        for _, block in ipairs(a.body) do
          if block.open then
            local page = pages:Get(block.open.page)
            local key = a.id .. " opens " .. block.open.page .. ":" .. tostring(block.open.tab)
            if page ~= nil then
              local found = block.open.tab == nil
              for _, tab in ipairs(page.tabs) do
                found = found or tab.id == block.open.tab
              end
              seen[key] = seen[key] or found
            else
              seen[key] = seen[key] or false
            end
          end
          if block.setting then
            local key = a.id .. " shows " .. block.setting .. " " .. tostring(block.bag)
            local bag = block.bag and bags[block.bag]
            -- What the Help page reads to draw it: the setting, for its bag (a bag's setting needs one).
            local ok = (block.bag == nil or bag ~= nil) and catalog:Has(block.setting, bag)
              and pcall(catalog.Get, catalog, block.setting, bag)
            seen[key] = seen[key] or ok
          end
        end
      end
      handle:Restore()
      handle = nil
    end
    local broken = {}
    for key, ok in pairs(seen) do
      if not ok then
        table.insert(broken, key)
      end
    end
    table.sort(broken)
    assert.are.same({}, broken)
  end)

  it("gives search examples the search reads, with fields it knows", function()
    local addon = start({ next = true })
    local parser = addon:GetModule("QueryParser")
    local search = addon:GetModule("Search")
    local ALIASES = { ah = "auctionable", ilvl = "level", count = "stackcount", exp = "expansion",
      slot = "equipmentlocation", bag = "bagname" }
    local problems = {}
    local function field(name, where)
      local key = name:lower()
      key = ALIASES[key] or key
      if key:find("^player%.") == nil and search:GetIndex(key) == nil then
        table.insert(problems, where .. ": no field named " .. name)
      end
    end
    local function walk(node, where)
      if type(node) ~= "table" then
        return
      end
      if node.type == "comparison" then
        field(node.field, where)
      elseif node.type == "compare" and node.left and node.left.type == "word" then
        field(node.left.value, where)
      end
      for _, key in ipairs({ "left", "right", "expression" }) do
        walk(node[key], where)
      end
    end
    for _, a in ipairs(addon:GetModule("HelpArticles").list) do
      for _, block in ipairs(a.body) do
        if block.example then
          local where = a.id .. " " .. block.example
          local ast = parser:Query(block.example)
          if ast == nil then
            table.insert(problems, where .. ": does not parse")
          else
            walk(ast, where)
          end
        end
      end
    end
    assert.are.same({}, problems)
  end)

  for _, design in ipairs({ "next", "classic" }) do
    it("shows every article on the Help page without an error, with " .. design, function()
      local addon = start({ next = design == "next" })
      local articles = addon:GetModule("HelpArticles")
      local help = addon:GetModule("NextSettingsHelp")
      local settings = addon:GetModule("NextSettings")
      local ctx = addon:GetModule("Context"):New("spec")
      local shown = 0
      for _, a in ipairs(articles:Shown()) do
        help:OpenArticle(ctx, a.id)
        assert.are.same({}, handle.errors, a.id)
        assert.are.equal(a.title, settings.title:GetText(), a.id)
        shown = shown + 1
      end
      assert.is_true(shown > 40, "articles shown: " .. shown)
      help:Open(ctx, "auto sell")
      assert.are.same({}, handle.errors, "a search")
      assert.are.equal("auto-sell", help.views[#help.views].shownCards[1].article.id)
    end)
  end
end)

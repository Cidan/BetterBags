-- toc_spec.lua -- Every TOC loads the render pipeline and Sonata before anything that draws
-- with them, and core/init.lua initializes them first.

local function readToc(path)
  local lines = {}
  local f = assert(io.open(path, "r"))
  for line in f:lines() do
    local entry = line:gsub("\r$", "")
    if entry ~= "" and not entry:match("^#") then
      table.insert(lines, entry)
    end
  end
  f:close()
  return lines
end

local function indexOf(lines, entry)
  for i, line in ipairs(lines) do
    if line == entry then return i end
  end
  return nil
end

describe("render pipeline and Sonata load order", function()
  it("lists the render modules in every TOC, in dependency order, before the frames", function()
    local pipe = io.popen("ls *.toc")
    local count = 0
    for path in pipe:lines() do
      count = count + 1
      local lines = readToc(path)
      local engine = indexOf(lines, "debug\\perf\\engine.lua")
      local renderModule = indexOf(lines, "render\\render.lua")
      local drawableModule = indexOf(lines, "render\\drawable.lua")
      local scrollboxModule = indexOf(lines, "render\\scrollbox.lua")
      local gridModule = indexOf(lines, "frames\\grid.lua")
      assert.is_not_nil(renderModule, path .. " lists render\\render.lua")
      assert.is_not_nil(drawableModule, path .. " lists render\\drawable.lua")
      assert.is_not_nil(scrollboxModule, path .. " lists render\\scrollbox.lua")
      assert.is_true(engine < renderModule, path)
      assert.is_true(renderModule < drawableModule, path)
      assert.is_true(drawableModule < scrollboxModule, path)
      assert.is_true(scrollboxModule < gridModule, path)
      local flowModule = indexOf(lines, "render\\flow.lua")
      local motionModule = indexOf(lines, "render\\motion.lua")
      assert.is_not_nil(motionModule, path .. " lists render\\motion.lua")
      assert.is_true(flowModule < motionModule, path)
      assert.is_true(motionModule < gridModule, path)
      assert.is_true(motionModule < indexOf(lines, "frames\\section.lua"), path)
      local sonataModule = indexOf(lines, "sonata\\engine.lua")
      assert.is_not_nil(sonataModule, path .. " lists sonata\\engine.lua")
      assert.is_true(scrollboxModule < sonataModule, path)
      assert.is_true(sonataModule < gridModule, path)
      local applyModule = indexOf(lines, "sonata\\apply.lua")
      local decorationModule = indexOf(lines, "sonata\\decoration.lua")
      assert.is_not_nil(applyModule, path .. " lists sonata\\apply.lua")
      assert.is_not_nil(decorationModule, path .. " lists sonata\\decoration.lua")
      assert.is_true(sonataModule < applyModule, path)
      assert.is_true(applyModule < decorationModule, path)
      assert.is_true(decorationModule < gridModule, path)
      local elementsModule = indexOf(lines, "sonata\\elements.lua")
      assert.is_not_nil(elementsModule, path .. " lists sonata\\elements.lua")
      assert.is_true(decorationModule < elementsModule, path)
      assert.is_true(elementsModule < gridModule, path)
      local windowModule = indexOf(lines, "window\\window.lua")
      local libWindow = indexOf(lines, "libs\\LibWindow-1.1\\LibWindow-1.1.lua")
      assert.is_not_nil(windowModule, path .. " lists window\\window.lua")
      assert.is_true(libWindow < windowModule, path)
      assert.is_true(elementsModule < windowModule, path)
      assert.is_true(windowModule < gridModule, path)
    end
    pipe:close()
    assert.are.equal(5, count)
  end)

  -- Every TOC loads for every player, whatever they turned on: a file that looks up a module (at
  -- load, "local x = addon:GetModule('X')") before the file that makes it would error for all of
  -- them. Each lookup must name a module an earlier file of the same TOC made, or the file itself.
  it("loads every module a file looks up at load before that file, in every TOC", function()
    local pipe = io.popen("ls *.toc")
    local count = 0
    for path in pipe:lines() do
      local defined, unresolved, lookups = {}, {}, 0
      for _, entry in ipairs(readToc(path)) do
        local file = entry:gsub("\\", "/")
        local f = file:match("%.lua$") and not file:match("^libs/") and io.open(file, "r")
        if f then
          local source = f:read("*a")
          f:close()
          local here = {}
          for name in source:gmatch("NewModule%(%s*['\"]([^'\"]+)['\"]") do here[name] = true end
          for line in (source .. "\n"):gmatch("([^\n]*)\n") do
            local name = line:match("^local%s+[%w_]+%s*=%s*addon:GetModule%(%s*['\"]([^'\"]+)['\"]%s*%)")
            if name then
              lookups = lookups + 1
              if not defined[name] and not here[name] then
                table.insert(unresolved, file .. " looks up " .. name)
              end
            end
          end
          for name in pairs(here) do defined[name] = true end
        end
      end
      assert.are.same({}, unresolved, path)
      assert.is_true(lookups > 400, path .. " checked " .. lookups .. " lookups")
      count = count + 1
    end
    pipe:close()
    assert.are.equal(5, count)
  end)

  -- BetterBagsNext (next.md): its files load after what they use (the bag frame, the search
  -- box, the money frame, the backpack behavior) and before core/init.lua, in dependency order.
  it("lists BetterBags Next's files in every TOC, in order, after the bag frames and before init", function()
    local files = { "next\\style.lua", "next\\tween.lua", "next\\sparkles.lua", "next\\tabs.lua",
      "next\\content.lua", "next\\drag.lua", "next\\panel.lua", "next\\bag.lua", "next\\bank.lua",
      "next\\merchant.lua", "next\\vendorbutton.lua", "next\\vendor.lua" }
    local pipe = io.popen("ls *.toc")
    for path in pipe:lines() do
      local lines = readToc(path)
      local previous = indexOf(lines, "frames\\bag.lua")
      assert.is_not_nil(previous, path)
      for _, file in ipairs(files) do
        local at = indexOf(lines, file)
        assert.is_not_nil(at, path .. " lists " .. file)
        assert.is_true(previous < at, path .. " " .. file)
        previous = at
      end
      assert.is_true(previous < indexOf(lines, "core\\init.lua"), path)
    end
    pipe:close()
  end)

  it("lists every Sonata theme file in every TOC, after Base and before the frames", function()
    local themes = {}
    local list = io.popen("ls sonata/themes/*.lua")
    for file in list:lines() do
      table.insert(themes, (file:gsub("/", "\\")))
    end
    list:close()
    assert.is_true(#themes >= 4)
    local pipe = io.popen("ls *.toc")
    for path in pipe:lines() do
      local lines = readToc(path)
      local base = indexOf(lines, "sonata\\themes\\base.lua")
      local grid = indexOf(lines, "frames\\grid.lua")
      assert.is_not_nil(base, path)
      for _, theme in ipairs(themes) do
        local at = indexOf(lines, theme)
        assert.is_not_nil(at, path .. " lists " .. theme)
        assert.is_true(base <= at and at < grid, path .. " " .. theme)
      end
    end
    pipe:close()
  end)

  it("initializes the render module, then Sonata and the tab bars, before the frames", function()
    local f = assert(io.open("core/init.lua", "r"))
    local source = f:read("*a")
    f:close()
    local renderInit = source:find("GetModule%('Render'%):Init%(%)")
    local itemFrameInit = source:find("itemFrame:Init%(%)")
    assert.is_not_nil(renderInit)
    assert.is_true(renderInit < itemFrameInit)
    local motionInit = source:find("GetModule%('Motion'%):Init%(%)")
    assert.is_not_nil(motionInit)
    assert.is_true(renderInit < motionInit)
    assert.is_true(motionInit < itemFrameInit)
    local sonataInit = source:find("GetModule%('Sonata'%):Init%(%)")
    assert.is_not_nil(sonataInit)
    assert.is_true(renderInit < sonataInit)
    assert.is_true(sonataInit < itemFrameInit)
    local tabsInit = source:find("GetModule%('Tabs'%):Init%(%)")
    assert.is_not_nil(tabsInit)
    assert.is_true(sonataInit < tabsInit)
    -- The old theme module is gone: nothing initializes or enables it.
    assert.is_nil(source:find("themes:Init%(%)"))
    assert.is_nil(source:find("themes:Enable%(%)"))
  end)
end)

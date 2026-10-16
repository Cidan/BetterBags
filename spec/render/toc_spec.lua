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

  it("initializes the render module before the themes and frames", function()
    local f = assert(io.open("core/init.lua", "r"))
    local source = f:read("*a")
    f:close()
    local renderInit = source:find("GetModule%('Render'%):Init%(%)")
    local itemFrameInit = source:find("itemFrame:Init%(%)")
    local themesInit = source:find("themes:Init%(%)")
    assert.is_not_nil(renderInit)
    assert.is_true(renderInit < themesInit)
    assert.is_true(renderInit < itemFrameInit)
    local sonataInit = source:find("GetModule%('Sonata'%):Init%(%)")
    assert.is_not_nil(sonataInit)
    assert.is_true(renderInit < sonataInit)
    assert.is_true(sonataInit < itemFrameInit)
  end)
end)

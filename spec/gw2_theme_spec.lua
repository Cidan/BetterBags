describe("GW2 theme compatibility", function()
  local function readFile(path)
    local file = assert(io.open(path, "r"))
    local contents = file:read("*a")
    file:close()
    return contents
  end

  it("lists GW2 UI variants as optional dependencies in every BetterBags TOC", function()
    local tocFiles = {
      "BetterBags.toc",
      "BetterBags_Mists.toc",
      "BetterBags_TBC.toc",
      "BetterBags_Vanilla.toc",
    }

    local gw2Ids = {
      "GW2_UI",
      "GW2_UI_Mainline",
      "GW2_UI_Mists",
      "GW2_UI_TBC",
      "GW2_UI_Vanilla",
      "GW2_UI_Classic",
      "GW2_UI_Wrath",
    }

    for _, tocFile in ipairs(tocFiles) do
      local toc = readFile(tocFile)
      for _, gw2Id in ipairs(gw2Ids) do
        assert.truthy(toc:find(gw2Id, 1, true), tocFile .. " should list " .. gw2Id)
      end
    end
  end)

  it("does not hardcode the base GW2_UI texture folder", function()
    local gw2Theme = readFile("themes/gw2.lua")

    assert.falsy(
      gw2Theme:find("Interface/AddOns/GW2_UI/", 1, true),
      "GW2 theme textures should use the detected GW2 UI addon folder"
    )
  end)
end)

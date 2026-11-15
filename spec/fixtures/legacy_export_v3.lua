-- legacy_export_v3.lua -- A string the "!BB" exporter wrote (DB:ExportSettings before #1317, version 3), captured
-- from it, and the profile tables it was exported from. Returns { text = the string, data = what it holds }.

return {
  text = table.concat({
    "!BBewogIFsiY3VzdG9tQ2F0ZWdvcnlGaWx0ZXJzIl0gPSB7CiAgICBbIk1hdHMgXCImXCIgSGVyYnMiXSA9IHsKICAgICAgWyJlb",
    "mFibGVkIl0gPSB7CiAgICAgICAgWzFdID0gZmFsc2UsCiAgICAgICAgWzJdID0gdHJ1ZSwKICAgICAgICBbMF0gPSB0cnVlLAogI",
    "CAgICB9LAogICAgICBbIm5vdGUiXSA9ICJsaW5lMVwKbGluZTJcXCBlbmRcciIsCiAgICAgIFsibmFtZSJdID0gIk1hdHMgXCImX",
    "CIgSGVyYnMiLAogICAgICBbInByaW9yaXR5Il0gPSAzLAogICAgICBbImNvbG9yIl0gPSB7CiAgICAgICAgWzFdID0gMC4yNSwKI",
    "CAgICAgICBbMl0gPSAwLjUsCiAgICAgICAgWzNdID0gMSwKICAgICAgfSwKICAgICAgWyJzYXZlIl0gPSB0cnVlLAogICAgICBbI",
    "nNlYXJjaENhdGVnb3J5Il0gPSB7CiAgICAgICAgWyJxdWVyeSJdID0gInR5cGUgPSBcIlRyYWRlc2tpbGxcIiBBTkQgaWx2bCA+I",
    "DEuNWUtMDciLAogICAgICB9LAogICAgICBbIml0ZW1MaXN0Il0gPSB7CiAgICAgICAgWzI0NDddID0gdHJ1ZSwKICAgICAgICBbN",
    "zY1XSA9IHRydWUsCiAgICAgIH0sCiAgICB9LAogIH0sCiAgWyJ2ZXJzaW9uIl0gPSAzLAogIFsiY3VzdG9tQ2F0ZWdvcnlJbmRle",
    "CJdID0gewogICAgWzI0NDddID0gIk1hdHMgXCImXCIgSGVyYnMiLAogICAgWzc2NV0gPSAiTWF0cyBcIiZcIiBIZXJicyIsCiAgf",
    "SwKICBbImNhdGVnb3J5RmlsdGVycyJdID0gewogICAgWyJSZWNlbnRJdGVtcyJdID0gdHJ1ZSwKICAgIFsiR2VhclNldCJdID0gZ",
    "mFsc2UsCiAgfSwKICBbImN1c3RvbVNlY3Rpb25Tb3J0Il0gPSB7CiAgICBbMV0gPSB7CiAgICB9LAogICAgWzBdID0gewogICAgI",
    "CBbIk1hdHMgXCImXCIgSGVyYnMiXSA9IDEsCiAgICB9LAogIH0sCiAgWyJlcGhlbWVyYWxDYXRlZ29yeUZpbHRlcnMiXSA9IHsKI",
    "CAgIFsiUGx1Z2luIENhdCJdID0gewogICAgICBbImVuYWJsZWQiXSA9IHsKICAgICAgICBbMF0gPSB0cnVlLAogICAgICB9LAogI",
    "CAgICBbIml0ZW1MaXN0Il0gPSB7CiAgICAgIH0sCiAgICAgIFsibmFtZSJdID0gIlBsdWdpbiBDYXQiLAogICAgICBbImR5bmFta",
    "WMiXSA9IHRydWUsCiAgICAgIFsicHJpb3JpdHkiXSA9IC0yLAogICAgfSwKICB9LAp9",
  }),
  data = {
    version = 3,
    customCategoryFilters = {
      ['Mats "&" Herbs'] = {
        name = 'Mats "&" Herbs', save = true, itemList = { [2447] = true, [765] = true },
        enabled = { [0] = true, [1] = false, [2] = true }, color = { 0.25, 0.5, 1 }, priority = 3,
        searchCategory = { query = 'type = "Tradeskill" AND ilvl > 1.5e-07' }, note = "line1\nline2\\ end\r",
      },
    },
    customCategoryIndex = { [2447] = 'Mats "&" Herbs', [765] = 'Mats "&" Herbs' },
    ephemeralCategoryFilters = {
      ["Plugin Cat"] = { name = "Plugin Cat", enabled = { [0] = true }, dynamic = true, itemList = {}, priority = -2 },
    },
    categoryFilters = { RecentItems = true, GearSet = false },
    customSectionSort = { [0] = { ['Mats "&" Herbs'] = 1 }, [1] = {} },
  },
}

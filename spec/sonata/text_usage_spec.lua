-- text_usage_spec.lua -- BetterBags' own window and bag text is drawn with Sonata's text roles
-- (sonata/engine.lua, Sonata:CreateText), so a theme restyles it. Text that sets its own color
-- or shadow, or is made with a fixed font, does not follow the theme: on a light theme
-- (Parchment) such text was white on parchment. This scans the files that draw that text.
local FILES = {
  "forms/layouts/stacked.lua",
  "frames/question.lua",
  "frames/groupdialog.lua",
  "frames/debug.lua",
  "frames/perfpane.lua",
  "frames/simulatepane.lua",
  "frames/money.lua",
  "frames/currency.lua",
  "views/gridview.lua",
}

-- What text styled outside its role looks like. Input boxes keep their own fonts (they sit
-- on their own field art), so SetFontObject with a font name is allowed.
local PATTERNS = {
  { ":SetTextColor%(", "sets its own text color" },
  { ":SetShadowColor%(", "sets its own shadow" },
  { ":SetShadowOffset%(", "sets its own shadow" },
  { "CreateFontString%([^,)]*,[^,)]*,", "is made with a fixed font" },
  { "SetFontObject%(fonts%.", "uses a fixed BetterBags font" },
  { "Set%a*FontObject%([\"']Number", "uses a fixed number font" },
}

describe("text drawn with Sonata's text roles", function()
  it("is never styled outside its role in the files that draw window and bag text", function()
    local found = {}
    for _, path in ipairs(FILES) do
      local f = assert(io.open(path), "cannot read " .. path)
      local n = 0
      for line in f:lines() do
        n = n + 1
        if not line:match("^%s*%-%-") then
          for _, pattern in ipairs(PATTERNS) do
            if line:find(pattern[1]) then
              table.insert(found, string.format("%s:%d %s", path, n, pattern[2]))
            end
          end
        end
      end
      f:close()
    end
    assert.are.same({}, found)
  end)
end)

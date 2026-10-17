-- changelog_data_spec.lua -- The changelog data the generator writes (tools/changelog, Go) read by
-- the addon (data/changelog.lua): its golden output, its empty output and the copy committed in the
-- repository must load as the ChangelogData module the changelog reads.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local db = trackStub("Database")
local savedDB = {
  GetChangelogLastSeen = rawget(db, "GetChangelogLastSeen"),
  GetChangelogAutoOpen = rawget(db, "GetChangelogAutoOpen"),
}

describe("Changelog data written by tools/changelog", function()
  local flavor

  before_each(function()
    db.GetChangelogLastSeen = function() return 0 end
    db.GetChangelogAutoOpen = function() return true end
    flavor = { isRetail = addon.isRetail, isForever = addon.isForever }
    addon.isRetail, addon.isForever = true, false
  end)

  after_each(function()
    addon.isRetail, addon.isForever = flavor.isRetail, flavor.isForever
  end)

  teardown(function()
    for k, v in pairs(savedDB) do db[k] = v end
    ResetModuleStub("Changelog", "data/changelog.lua")
    ResetModuleStub("ChangelogData")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  -- load runs a data file the way the client does (with the addon's name) and loads the
  -- changelog over it.
  local function load(file)
    ResetModuleStub("ChangelogData")
    assert(loadfile(file))("BetterBags")
    ResetModuleStub("Changelog", "data/changelog.lua")
    LoadBetterBagsModule("data/changelog.lua")
    return addon:GetModule("ChangelogData"), addon:GetModule("Changelog")
  end

  it("reads the golden output as the changelog's releases", function()
    local data, changelog = load("tools/changelog/testdata/changelogdata.golden.lua")
    assert.are.equal(2, #data.releases)
    local first = data.releases[1]
    assert.are.equal(1792281600, first.id)
    assert.are.equal('Tabs "for" every theme.', first.headline)
    assert.are.equal("Tabs match the theme.\\ A backslash.", first.entries[1].details)
    assert.are.same({ "Forever" }, first.entries[2].clients)
    local releases = changelog:GetReleases()
    assert.are.equal("v0.5.17", releases[1].version)
    assert.are.equal(1, #releases[1].entries)
    assert.are.equal("Themed tabs", releases[1].entries[1].title)
    assert.are.equal("v0.5.16", releases[2].version)
    assert.is_true(changelog:ShouldOpenOnLogin())
  end)

  it("reads the empty output as no releases", function()
    local data, changelog = load("tools/changelog/testdata/changelogdata.empty.lua")
    assert.are.same({}, data.releases)
    assert.is_false(changelog:HasUnseen())
  end)

  it("reads the copy in the repository, every entry with a known category and clients", function()
    local data, changelog = load("data/changelogdata.lua")
    assert.is_true(#data.releases > 0)
    local categories = { New = true, Improved = true, Fixed = true, Changed = true }
    local clients = { Retail = true, Classic = true, Forever = true }
    for _, release in ipairs(data.releases) do
      assert.are.equal("number", type(release.id))
      for _, key in ipairs({ "version", "channel", "date", "headline" }) do
        assert.are.equal("string", type(release[key]), key)
      end
      for _, entry in ipairs(release.entries) do
        assert.is_true(categories[entry.category], entry.title)
        assert.are.equal("string", type(entry.details))
        for _, client in ipairs(entry.clients) do
          assert.is_true(clients[client], entry.title)
        end
      end
    end
    assert.is_true(#changelog:GetReleases() > 0)
  end)
end)

teardown(function()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
end)

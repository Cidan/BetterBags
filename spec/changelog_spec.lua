-- changelog_spec.lua -- The changelog (data/changelog.lua): the releases bundled in
-- data/changelogdata.lua (written by tools/changelog in CI), filtered to the player's client,
-- newest first, and which of them the player has not seen. The seen state is account wide
-- (Database, AceDB global).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local db = trackStub("Database")
local data = trackStub("ChangelogData")
local saved = {
  GetChangelogLastSeen = rawget(db, "GetChangelogLastSeen"),
  SetChangelogLastSeen = rawget(db, "SetChangelogLastSeen"),
  GetChangelogAutoOpen = rawget(db, "GetChangelogAutoOpen"),
  SetChangelogAutoOpen = rawget(db, "SetChangelogAutoOpen"),
  releases = rawget(data, "releases"),
}
local state = { lastSeen = 0, autoOpen = true }
db.GetChangelogLastSeen = function() return state.lastSeen end
db.SetChangelogLastSeen = function(_, id) state.lastSeen = id end
db.GetChangelogAutoOpen = function() return state.autoOpen end
db.SetChangelogAutoOpen = function(_, value) state.autoOpen = value end

ResetModuleStub("Changelog", "data/changelog.lua")
LoadBetterBagsModule("data/changelog.lua")
local changelog = addon:GetModule("Changelog")

local function entry(title, clients)
  return { category = "Fixed", title = title, details = title .. " details", clients = clients }
end

describe("Changelog", function()
  local flavor

  before_each(function()
    state.lastSeen, state.autoOpen = 0, true
    flavor = { isRetail = addon.isRetail, isForever = addon.isForever }
    addon.isRetail, addon.isForever = true, false
    data.releases = {
      { id = 100, version = "v0.5.16", channel = "release", date = "2026-10-01", headline = "Older",
        entries = { entry("everywhere", {}), entry("classic only", { "Classic" }) } },
      { id = 300, version = "v0.5.17-2-gabcdef0", channel = "alpha", date = "2026-10-17", headline = "Newest",
        entries = { entry("forever only", { "Forever" }) } },
      { id = 200, version = "v0.5.17", channel = "release", date = "2026-10-10", headline = "Middle",
        entries = { entry("retail and forever", { "Retail", "Forever" }), entry("no clients listed") } },
    }
  end)

  after_each(function()
    addon.isRetail, addon.isForever = flavor.isRetail, flavor.isForever
  end)

  teardown(function()
    for k, v in pairs(saved) do
      if k == "releases" then data.releases = v else db[k] = v end
    end
    ResetModuleStub("Changelog", "data/changelog.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function titles(release)
    local out = {}
    for _, e in ipairs(release.entries) do table.insert(out, e.title) end
    return out
  end

  it("names the player's client the way the generator tags entries", function()
    assert.are.equal("Retail", changelog:GetClient())
    addon.isForever = true
    assert.are.equal("Forever", changelog:GetClient())
    addon.isRetail, addon.isForever = false, false
    assert.are.equal("Classic", changelog:GetClient())
  end)

  it("lists the releases newest first, each with only the entries for the player's client", function()
    local releases = changelog:GetReleases()
    assert.are.equal(2, #releases)
    assert.are.equal("v0.5.17", releases[1].version)
    assert.are.same({ "retail and forever", "no clients listed" }, titles(releases[1]))
    assert.are.equal("v0.5.16", releases[2].version)
    assert.are.same({ "everywhere" }, titles(releases[2]))

    addon.isForever = true
    releases = changelog:GetReleases()
    assert.are.same({ "v0.5.17-2-gabcdef0", "v0.5.17", "v0.5.16" }, { releases[1].version, releases[2].version, releases[3].version })

    addon.isRetail, addon.isForever = false, false
    releases = changelog:GetReleases()
    assert.are.same({ "no clients listed" }, titles(releases[1]))
    assert.are.same({ "everywhere", "classic only" }, titles(releases[2]))
  end)

  it("leaves the bundled data untouched", function()
    changelog:GetReleases()
    assert.are.equal(2, #data.releases[1].entries)
  end)

  it("says which releases the player has not seen", function()
    state.lastSeen = 100
    local releases = changelog:GetReleases()
    assert.is_true(changelog:IsUnseen(releases[1]))
    assert.is_false(changelog:IsUnseen(releases[2]))
    assert.is_true(changelog:HasUnseen())
    state.lastSeen = 200
    assert.is_false(changelog:HasUnseen())
  end)

  -- A release with nothing for this client (the Forever-only alpha on retail) is not shown, but
  -- once the player has seen the changelog it is seen too, so it never opens the window later.
  it("marks every bundled release seen, including ones with nothing for this client", function()
    changelog:MarkAllSeen()
    assert.are.equal(300, state.lastSeen)
    state.lastSeen = 500
    changelog:MarkAllSeen()
    assert.are.equal(500, state.lastSeen)
  end)

  it("opens on login only when allowed and something is unseen", function()
    assert.is_true(changelog:ShouldOpenOnLogin())
    state.autoOpen = false
    assert.is_false(changelog:ShouldOpenOnLogin())
    state.autoOpen = true
    state.lastSeen = 200
    assert.is_false(changelog:ShouldOpenOnLogin())
  end)

  it("lets the player turn off opening on login", function()
    changelog:SetAutoOpen(false)
    assert.is_false(state.autoOpen)
    assert.is_false(changelog:GetAutoOpen())
    changelog:SetAutoOpen(true)
    assert.is_true(changelog:GetAutoOpen())
  end)

  it("copes with no bundled releases", function()
    data.releases = {}
    assert.are.same({}, changelog:GetReleases())
    assert.is_false(changelog:HasUnseen())
    changelog:MarkAllSeen()
    assert.are.equal(0, state.lastSeen)
  end)
end)

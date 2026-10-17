local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class ChangelogData: AceModule
local changelogData = addon:GetModule('ChangelogData')

-- Changelog reads the releases bundled in data/changelogdata.lua (written in CI by
-- tools/changelog, a summary of every change in a release) and keeps the account-wide state of
-- what the player has seen. The window (frames/changelog.lua) shows them.
---@class Changelog: AceModule
local changelog = addon:NewModule('Changelog')

---@class (exact) ChangelogEntry
---@field category string "New", "Improved", "Fixed", or "Changed" (a summary written without Gemini).
---@field title string
---@field details string
---@field clients? string[] The clients it applies to ("Retail", "Classic", "Forever"); every client when empty.

---@class (exact) ChangelogRelease
---@field id number Orders releases; the seen state compares it. The time the release's notes were first written.
---@field version string
---@field channel string "release" or "alpha".
---@field date string
---@field headline string
---@field entries ChangelogEntry[]

-- GetClient returns the name the changelog's entries use for the player's client.
---@return string
function changelog:GetClient()
  if addon.isForever then
    return "Forever"
  end
  if addon.isRetail then
    return "Retail"
  end
  return "Classic"
end

---@param entry ChangelogEntry
---@param client string
---@return boolean
local function appliesTo(entry, client)
  if entry.clients == nil or #entry.clients == 0 then
    return true
  end
  for _, name in ipairs(entry.clients) do
    if name == client then
      return true
    end
  end
  return false
end

-- GetReleases returns the bundled releases, newest first, each holding only the entries for the
-- player's client. A release left with none is not returned.
---@return ChangelogRelease[]
function changelog:GetReleases()
  local client = self:GetClient()
  local releases = {}
  for _, release in ipairs(changelogData.releases or {}) do
    local entries = {}
    for _, entry in ipairs(release.entries or {}) do
      if appliesTo(entry, client) then
        table.insert(entries, entry)
      end
    end
    if #entries > 0 then
      table.insert(releases, {
        id = release.id,
        version = release.version,
        channel = release.channel,
        date = release.date,
        headline = release.headline,
        entries = entries,
      })
    end
  end
  table.sort(releases, function(a, b) return a.id > b.id end)
  return releases
end

---@param release ChangelogRelease
---@return boolean
function changelog:IsUnseen(release)
  return release.id > (database:GetChangelogLastSeen() or 0)
end

-- HasUnseen returns whether a release with entries for the player's client is unseen.
---@return boolean
function changelog:HasUnseen()
  for _, release in ipairs(self:GetReleases()) do
    if self:IsUnseen(release) then
      return true
    end
  end
  return false
end

-- MarkAllSeen marks every bundled release seen, including those with nothing for this client.
function changelog:MarkAllSeen()
  local newest = database:GetChangelogLastSeen() or 0
  for _, release in ipairs(changelogData.releases or {}) do
    if release.id > newest then
      newest = release.id
    end
  end
  database:SetChangelogLastSeen(newest)
end

-- ShouldOpenOnLogin returns whether the changelog opens by itself: the player has not turned
-- that off, and there is a release they have not seen.
---@return boolean
function changelog:ShouldOpenOnLogin()
  return database:GetChangelogAutoOpen() == true and self:HasUnseen()
end

---@return boolean
function changelog:GetAutoOpen()
  return database:GetChangelogAutoOpen() == true
end

---@param value boolean
function changelog:SetAutoOpen(value)
  database:SetChangelogAutoOpen(value)
end

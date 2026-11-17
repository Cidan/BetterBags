local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "profiles", title = L:G("Profiles and Settings") })

articles:Define({
  id = "profiles", group = "profiles",
  title = L:G("Profiles"),
  summary = L:G("Saving your settings under a name and sharing them between characters."),
  keywords = { L:G("profile"), L:G("profiles"), L:G("character"), L:G("alt"), L:G("copy settings"), L:G("new profile"),
    L:G("reset to defaults"), L:G("default profile"), L:G("per character"),
    L:G("share settings alts"), L:G("copy profile"), L:G("account wide settings")
  },
  questions = { L:G("How do I use the same settings on my alts?"), L:G("How do I give a character its own settings?"),
    L:G("How do I copy my settings to another character?"), L:G("How do I reset everything?"),
    L:G("How do I copy my bag settings to my alts?"), L:G("How do I create a new profile for a specific character?"),
    L:G("Can all my characters share the same BetterBags layout and categories?"),
    L:G("Where is the Profiles page to save or switch profiles?"),
    L:G("How do I reset my profile without losing everything on other characters?"),
    L:G("Why did my alt start with different bag settings from my main?")
  },
  pages = { "profiles", "profiles:profiles" },
  related = { "category-share", "category-gearsets" },
  body = {
    { text = L:G("A profile holds all your settings: your categories, their order, your groups, your theme, your anchors, and everything else. Every character starts on the Default profile, so they all share it until you switch a character to another profile.") },
    { heading = L:G("Profiles Page") },
    { list = {
      L:G("Active Profile sets the profile this character uses. Switching profiles reloads the UI."),
      L:G("Below Active Profile, you can see the characters on each profile."),
      L:G("New Profile, Copy Profile, Rename Profile, and Delete Profile manage your profiles. Default can't be renamed or deleted."),
      L:G("Reset to Defaults puts every setting of the active profile back as it was when BetterBags was new."),
    } },
    { open = { page = "profiles", text = L:G("Open the Profiles page") } },
  },
})

articles:Define({
  id = "reload-settings", group = "profiles",
  title = L:G("Reload Required"),
  summary = L:G("The few changes that take effect only after the UI reloads."),
  keywords = { L:G("reload"), L:G("reloadui"), L:G("restart"), L:G("not working"), L:G("didn't change"),
    L:G("reload UI"), L:G("settings need reload"), L:G("changes not applying"), L:G("restart UI")
  },
  questions = { L:G("Why didn't my setting change anything?"), L:G("Do I need to reload after changing a setting?"),
    L:G("Why didn't a setting I changed take effect right away?"),
    L:G("Which BetterBags settings require a UI reload?"),
    L:G("Do I need to type /reload after changing certain options?"),
    L:G("Why is BetterBags asking me to reload my UI?"),
    L:G("I toggled an option and nothing changed yet, what do I do?"),
    L:G("Which settings only apply after reloading?"),
    L:G("Settings That Need a Reload")
  },
  related = { "bank-basics", "profiles", "designs" },
  body = {
    { text = L:G("Almost every setting takes effect right away. A few take effect only after the UI reloads. For a setting or an import, BetterBags asks first: choose Later to keep playing, or Reload to reload now.") },
    { list = {
      L:G("Changing Enable Bank Bags on the Bank page."),
      L:G("Switching the active profile: choosing Switch reloads the UI right away."),
      L:G("Importing all your categories."),
    } },
  },
})

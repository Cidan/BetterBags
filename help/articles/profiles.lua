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
  summary = L:G("Profile management, shared settings, and character assignments"),
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
    { text = L:G("BetterBags stores your settings, categories, bag layouts, and appearance choices in named profiles so characters can share one setup or keep separate setups. Manage them on the Profiles page under the Profiles tab.") },
    { heading = L:G("Profile Contents") },
    { text = L:G("A profile stores every BetterBags setting, custom category, equipment set category configuration, and bag option except two settings.") },
    { list = {
      L:G("Show What's New on Login is saved for your entire account across all profiles."),
      L:G("Include Tradeable Reagents is the game's own setting and is saved per character."),
    } },
    { heading = L:G("Default Profile") },
    { text = L:G("Every character starts on the built-in Default profile. You can switch to Default, copy its settings with Copy Profile, or wipe it back to factory state with Reset to Defaults, but you cannot rename or delete Default.") },
    { heading = L:G("Profile Management") },
    { text = L:G("The Active Profile dropdown on Profiles > Profiles switches this character to another profile after you confirm, which reloads the UI. Below the dropdown, the Characters line shows how many characters currently use each active profile.") },
    { list = {
      L:G("New Profile creates a profile up to 48 characters long and switches your character to it immediately, then displays a prompt to reload the UI. Clicking Cancel skips the reload and leaves your character on the new profile."),
      L:G("Copy Profile creates a new profile, switches your character to it, copies all settings from your previous profile, and displays a prompt to reload now with Reload or Later. Your character stays on the copied profile regardless of which button you click."),
      L:G("Rename Profile renames the active profile and reloads the UI right away. It cannot rename Default or reuse an existing profile name."),
      L:G("Delete Profile requires confirmation, switches your character back to Default, deletes the previously active profile, and reloads the UI. It cannot delete Default."),
      L:G("Reset to Defaults requires confirmation, erases all settings and categories in the active profile (including Default), and reloads the UI."),
    } },
    { open = { page = "profiles", tab = "profiles", text = L:G("Open Profiles Tab") } },
    { see = "category-share" },
    { see = "category-gearsets" },
  },
})

articles:Define({
  id = "reload-settings", group = "profiles",
  title = L:G("Reloading Settings"),
  summary = L:G("Changes that require a UI reload"),
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
    { text = L:G("Most BetterBags settings apply immediately. A small set of changes require reloading the user interface before the change takes effect.") },
    { heading = L:G("Later or Reload") },
    { text = L:G("For changes that offer Later or Reload, clicking Later preserves your saved change so you can finish other edits and run /reload when ready, while clicking Reload reloads the UI right away.") },
    { list = {
      L:G("Enable Bank Bags under Bank > General switches between BetterBags and the default Blizzard bank window after the UI reloads."),
      L:G("Copy Profile under Profiles > Profiles switches your character to the new copy first and then offers Later or Reload; whichever button you choose, your character is already using the copied profile."),
      L:G("Import Categories under Profiles > Import / Export offers Later or Reload after replacing all categories from a full category export string; importing a single category string applies immediately without displaying a reload prompt."),
    } },
    { heading = L:G("Immediate Reloads") },
    { text = L:G("Profile operations that replace or remove active data reload as soon as you confirm them.") },
    { list = {
      L:G("Selecting a profile in Active Profile under Profiles > Profiles reloads immediately when you click Switch."),
      L:G("Confirming Rename Profile, Delete Profile, or Reset to Defaults reloads immediately."),
      L:G("New Profile makes the new profile active before displaying the switch prompt; clicking Switch reloads immediately, while clicking Cancel leaves your character on the new profile without a reload."),
    } },
    { open = { page = "profiles", tab = "profiles", text = L:G("Open Profiles Settings") } },
  },
})

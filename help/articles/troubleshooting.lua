local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "troubleshooting", title = L:G("Troubleshooting") })

articles:Define({
  id = "wrong-category", group = "troubleshooting", featured = true,
  title = L:G("Wrong Category"),
  summary = L:G("Why an item shows in a category you didn't expect, and how to move it."),
  keywords = { L:G("wrong category"), L:G("missing item"), L:G("not showing"), L:G("item missing"), L:G("wrong section"),
    L:G("can't find item"), L:G("category not working"),
    L:G("misplaced item"), L:G("item wrong section"), L:G("fix item category"),
    L:G("wrong place"), L:G("unexpected section"),
    L:G("reassign an item")
  },
  questions = { L:G("Why is my item not in my category?"), L:G("Why are some of my items missing from my custom category?"),
    L:G("Where did my item go?"), L:G("Why doesn't my search category show anything?"),
    L:G("Why is an item in the wrong category?"), L:G("How do I move an item out of a category it shouldn't be in?"),
    L:G("Why did my gear or crafting mat go into the wrong section?"),
    L:G("How do I find out what put an item into a specific category?"),
    L:G("An item keeps landing in the wrong group, how do I fix it?"),
    L:G("Why isn't my custom category catching an item that is in another section?"),
    L:G("Why is my item in the wrong place?"),
    L:G("landing in the wrong section"),
    L:G("An Item Is in the Wrong Category")
  },
  related = { "categories-intro", "category-ignored", "category-settings", "category-rule" },
  body = {
    { text = L:G("An item shows in one category only. When it seems to be in the wrong one, check these in order:") },
    { steps = {
      L:G("Is it in Recent Items? New items go there first. Sort your bags to clear Recent Items, or turn on Skip Recent Items for the category."),
      L:G("Does it match another category too? The category higher in the list on the Categories page wins. Drag your category above the other."),
      L:G("Was it added to another category by hand? Items added by hand stay where you put them. Remove the item from that category's Added Items tab."),
      L:G("Is it on your category's Ignored Items tab?"),
      L:G("Is your category used in this bag? Check Used In and Hide In on its Settings tab."),
      L:G("Does your search rule match it? Open the Search Rule tab: the items it matches show under the rule as you type."),
    } },
    { tip = L:G("In a search rule, category means the category an item has without any search rule, so one search category never matches another.") },
  },
})

articles:Define({
  id = "category-deleted-returns", group = "troubleshooting",
  title = L:G("Deleted Categories"),
  summary = L:G("Why a category you deleted reappears after a reload."),
  keywords = { L:G("deleted category"), L:G("comes back"), L:G("reappears"), L:G("can't delete"), L:G("plugin category"),
    L:G("deleted category returns"), L:G("category keeps returning"), L:G("can't delete category"),
    L:G("reappearing section"),
    L:G("keeps coming back")
  },
  questions = { L:G("Why does a category reappear after I delete it?"), L:G("How do I get rid of a plugin's category?"),
    L:G("Why does a category I deleted keep coming back after I reload?"),
    L:G("How do I permanently stop a deleted category from reappearing?"),
    L:G("I deleted a section and now it is back again, why?"),
    L:G("Why can't I permanently remove a plugin or Blizzard category?"),
    L:G("How do I get rid of an unwanted category if deleting it doesn't stick?"),
    L:G("Why did a deleted category recreate itself when I logged back in?"),
    L:G("A Deleted Category Comes Back")
  },
  related = { "category-plugins", "plugins" },
  body = {
    { text = L:G("A category created by a plugin or another addon is recreated each time you log in or reload. To remove it permanently, turn off the addon that creates it, then delete the category.") },
  },
})

articles:Define({
  id = "bags-not-opening", group = "troubleshooting",
  title = L:G("Default Bags"),
  summary = L:G("Why the game's own bags or bank show instead of BetterBags."),
  keywords = { L:G("blizzard bags"), L:G("default bags"), L:G("not working"), L:G("old bags"), L:G("bank not working"),
    L:G("vendor window"), L:G("guild bank window"),
    L:G("bags not opening"), L:G("Blizzard bags showing"), L:G("BetterBags not working"), L:G("default bags open"),
    L:G("still default")
  },
  questions = { L:G("Why do I see Blizzard's bags?"), L:G("Why is my bank the default one?"),
    L:G("Why is the vendor window Blizzard's?"),
    L:G("Why do Blizzard's default bags open instead of BetterBags?"),
    L:G("BetterBags stopped opening when I press B, how do I fix it?"),
    L:G("Why is my bank showing the standard game window instead of BetterBags?"),
    L:G("Could another addon like ElvUI or Bagnon be overriding BetterBags?"),
    L:G("How do I get BetterBags to open again when I click my bag bar?"),
    L:G("Why do my bags look like the normal WoW bags?"),
    L:G("default bags still show"),
    L:G("My Bags Look Like Blizzard's")
  },
  related = { "bank-basics", "next-vendor", "next-guildbank", "show-bags" },
  body = {
    { list = {
      L:G("Blizzard's bank shows when Enable Bank Bags is off on the Bank page."),
      L:G("With BetterBags Next, Blizzard's vendor and guild bank show when Enable Vendor Window or Enable Guild Bank Window is off."),
      L:G("In the classic bags, Show Bags displays your bags one by one like Blizzard's bags: choose it again in the bag menu to see your categories. In BetterBags Next, click Show Blizzard Bags again."),
    } },
  },
})

articles:Define({
  id = "performance", group = "troubleshooting",
  title = L:G("Reporting Lag"),
  summary = L:G("Recording what BetterBags was doing when your game stuttered to send with a report."),
  keywords = { L:G("lag"), L:G("stutter"), L:G("slow"), L:G("fps"), L:G("performance"), L:G("freeze"), L:G("bbdb"),
    L:G("profiler"), L:G("capture"), L:G("bug report"),
    L:G("lag spikes"), L:G("FPS drop"), L:G("stutter report"), L:G("profiler capture")
  },
  questions = { L:G("Why does my game stutter when I open my bags?"), L:G("How do I report a performance problem?"),
    L:G("How do I record what BetterBags is doing?"),
    L:G("How do I record a lag spike or FPS drop to send in a bug report?"),
    L:G("My game stutters when I open my bags or loot items, how do I report it?"),
    L:G("How do I capture performance data when BetterBags slows down?"),
    L:G("Where is the profiler tool to record a slowdown?"),
    L:G("What should I attach when reporting a BetterBags freeze or hitch?"),
    L:G("How do I check what BetterBags was doing during a frame drop?"),
    L:G("Reporting Stutters and Slowdowns")
  },
  related = { "slash-commands", "effects" },
  body = {
    { steps = {
      L:G("Type /bbdb to open the debug window and choose its Performance tab."),
      L:G("Click Start Capture, do whatever causes the stutter (open your bags, loot, or use abilities that lag), and then click Stop Capture. To record logging in, check Capture next reload and type /reload instead."),
      L:G("The capture is saved in the list on the left. Choose it to see where the time went."),
      L:G("Log out or type /reload so the game writes the capture to WTF/Account/YOUR ACCOUNT/SavedVariables/BetterBags.lua, then attach that file to your report."),
    } },
    { text = L:G("Recording is always off unless you start it and never keeps running across a reload. You can delete saved captures from the same tab.") },
    { tip = L:G("You can turn off BetterBags Next's animation effects on the Appearance page's Animation tab.") },
  },
})

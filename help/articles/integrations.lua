local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "integrations", title = L:G("Other Addons") })

articles:Define({
  id = "quickfind", group = "integrations",
  title = L:G("QuickFind"),
  summary = L:G("Finding items in your bags and bank with the QuickFind addon."),
  keywords = { L:G("QuickFind"), L:G("quick find"), L:G("spotlight"), L:G("launcher"),
    L:G("QuickFind search"), L:G("QuickFind integration"), L:G("search bags QuickFind"),
    L:G("item finder"), L:G("finder addon")
  },
  questions = { L:G("How do I find my items with QuickFind?"), L:G("How do I turn off the QuickFind integration?"),
    L:G("How does QuickFind work with BetterBags?"), L:G("Can I use the QuickFind addon to search my bags and bank?"),
    L:G("Why aren't BetterBags items showing up in QuickFind?"),
    L:G("How do I find items across my bags using QuickFind?"),
    L:G("Does BetterBags support QuickFind out of the box?"),
    L:G("Can QuickFind highlight or locate items inside BetterBags?")
  },
  settings = { "quickFind" },
  pages = { "quickfind", "quickfind:main" },
  related = { "search-basics" },
  body = {
    { text = L:G("With the QuickFind addon installed, you can find items from your backpack and bank in QuickFind, tagged with their type, category, and where they are.") },
    { text = L:G("Press Enter on an item in QuickFind, and BetterBags opens the bag and tab that hold it and searches for its name. In-Bag Search must be on for BetterBags to search for it.") },
    { setting = "quickFind" },
  },
})

articles:Define({
  id = "pawn", group = "integrations",
  title = L:G("Upgrade Addons"),
  summary = L:G("Using Pawn or SimpleItemLevel to decide which gear gets an upgrade arrow."),
  keywords = { L:G("Pawn"), L:G("SimpleItemLevel"), L:G("Simple Item Level"), L:G("stat weights"), L:G("scales"),
    L:G("upgrade arrow"),
    L:G("gear upgrade icon"),
    L:G("gear advisor"), L:G("stat weight addon"),
    L:G("Pawn and SimpleItemLevel")
  },
  questions = { L:G("How do I use Pawn with BetterBags?"), L:G("Why doesn't Pawn's arrow show right away?"),
    L:G("How do I make BetterBags use Pawn for upgrade arrows on gear?"),
    L:G("Why is there a green upgrade arrow on an item in my bags?"),
    L:G("How do I switch upgrade arrows between Pawn and SimpleItemLevel?"),
    L:G("Can BetterBags show Pawn upgrades in my bags?"), L:G("Why is Pawn not marking upgrades on my items?"),
    L:G("How do I pick which addon decides item upgrade arrows?")
  },
  related = { "upgrades" },
  body = {
    { text = L:G("Choose Pawn or SimpleItemLevel as the Upgrade Icon Provider on the General page to let that addon decide which gear gets the green arrow. Until you choose one yourself, BetterBags uses Pawn if it is installed, or else SimpleItemLevel if that is installed.") },
    { list = {
      L:G("Pawn weighs an item's stats using your Pawn scales. An item gets no arrow until Pawn provides an answer for it, and automation leaves it alone."),
      L:G("SimpleItemLevel marks upgrades in your backpack."),
    } },
    { see = "upgrades" },
  },
})

articles:Define({
  id = "tsm", group = "integrations", design = "next",
  title = L:G("TradeSkillMaster"),
  summary = L:G("Switching between the BetterBags Next and TradeSkillMaster vendor windows."),
  keywords = { L:G("TradeSkillMaster"), L:G("TSM"), L:G("vendoring"), L:G("WoW UI"),
    L:G("TSM vendor"), L:G("TSM window"), L:G("merchant UI conflict")
  },
  questions = { L:G("How do I open TradeSkillMaster's vendor window?"), L:G("How do I get back to the BetterBags vendor from TSM?"),
    L:G("How do I use the TradeSkillMaster vendor window instead of BetterBags Next?"),
    L:G("Why did BetterBags Next replace my TSM merchant screen?"),
    L:G("How do I switch between TSM and BetterBags at a vendor?"),
    L:G("Can I use TradeSkillMaster alongside BetterBags Next?"),
    L:G("Where did my TSM vendor tab go when I talk to a merchant?"),
    L:G("How do I bring back the TradeSkillMaster vendor UI?")
  },
  related = { "next-vendor" },
  body = {
    { text = L:G("With TradeSkillMaster installed, only one vendor window shows at a time, and you can switch between BetterBags Next's window and TradeSkillMaster's.") },
    { list = {
      L:G("The TradeSkillMaster button at the top of the vendor window opens TradeSkillMaster's window, and BetterBags Next's vendor window slides away."),
      L:G("TradeSkillMaster's WoW UI button brings BetterBags Next's vendor window back."),
      L:G("The next vendor you visit opens in whichever window you used last."),
      L:G("Closing TradeSkillMaster's window closes the vendor."),
    } },
  },
})

articles:Define({
  id = "shopping-list", group = "integrations", design = "next",
  title = L:G("Shopping List"),
  summary = L:G("Buying what your Profession Shopping List needs from a vendor all at once."),
  keywords = { L:G("Profession Shopping List"), L:G("shopping list"), L:G("buy reagents"), L:G("crafting"), L:G("recipes"),
    L:G("buy shopping list"), L:G("vendor auto buy"), L:G("craft mats vendor")
  },
  questions = { L:G("How do I buy everything on my shopping list?"), L:G("What is the green card at the vendor?"),
    L:G("How do I buy everything on my Profession Shopping List at a vendor in one go?"),
    L:G("Does BetterBags work with the Profession Shopping List addon?"),
    L:G("Where is the button to buy my Profession Shopping List materials?"),
    L:G("Can BetterBags auto buy crafting supplies from my shopping list?"),
    L:G("Why isn't the Profession Shopping List vendor button showing up?"),
    L:G("How do I bulk buy vendor reagents for a tracked recipe?")
  },
  related = { "next-vendor", "confirm-sale" },
  body = {
    { text = L:G("With the Profession Shopping List addon installed, any vendor that sells items on your list shows a Shopping List section at the top of its goods, listing the items to buy, their quantities, and their costs.") },
    { text = L:G("A green card shows how many items you will buy and their total price. Double-click the card to buy them all.") },
  },
})

articles:Define({
  id = "masque", group = "integrations",
  title = L:G("Masque"),
  summary = L:G("Skinning BetterBags' item buttons with the Masque addon."),
  keywords = { L:G("Masque"), L:G("button skin"), L:G("skins"), L:G("borders"),
    L:G("skin item buttons"), L:G("button borders"), L:G("Masque support")
  },
  questions = { L:G("How do I skin my bag buttons with Masque?"), L:G("Why doesn't my Masque skin show?"),
    L:G("How do I skin BetterBags item slots with Masque?"), L:G("Does Masque work with BetterBags item buttons?"),
    L:G("Why aren't my Masque icon borders applying to BetterBags?"),
    L:G("Where do I find BetterBags inside Masque's settings?"),
    L:G("Can I change the shape and border of bag item icons using Masque?"),
    L:G("Why do my bag icons look different from my action bars in Masque?")
  },
  related = { "themes", "item-buttons" },
  body = {
    { text = L:G("With Masque installed, BetterBags' item buttons can use a Masque skin. Choose skins in Masque's options under BetterBags, with a separate group for the backpack, the bank, and BetterBags Next's vendor, guild bank, and Food & Drink bar.") },
    { text = L:G("A theme can choose not to use Masque; when it does, its buttons keep the theme's own look.") },
  },
})

articles:Define({
  id = "gamepad", group = "integrations",
  title = L:G("Controllers"),
  summary = L:G("Using your bags with ConsolePort or WoW: Forever's own gamepad interface."),
  keywords = { L:G("controller"), L:G("gamepad"), L:G("ConsolePort"), L:G("console"), L:G("joystick"), L:G("Steam Deck"),
    L:G("d-pad"),
    L:G("controller support"), L:G("Steam Deck bags")
  },
  questions = { L:G("Can I use BetterBags with a controller?"), L:G("Does BetterBags work with ConsolePort?"),
    L:G("How do I use BetterBags with a controller or Steam Deck?"),
    L:G("How do I navigate my bags using WoW: Forever's gamepad interface?"),
    L:G("Why can't I move my cursor over bag items with my controller?"),
    L:G("How do I set up BetterBags for gamepad play?"),
    L:G("What controller buttons work inside BetterBags with ConsolePort?"),
    L:G("Playing With a Controller")
  },
  related = { "next-panels" },
  body = {
    { heading = L:G("ConsolePort") },
    { text = L:G("With the ConsolePort addon installed, BetterBags' backpack, bank, and menus work with ConsolePort's cursor so you can move through them with your controller.") },
    { heading = L:G("WoW: Forever") },
    { text = L:G("In WoW: Forever's gamepad interface, every open bag window joins the game's window list: use the d-pad to move over buttons, and use the triggers to move between windows. A presses a button, X right-clicks the selected item to use, sell, or move it, and B puts back what you hold or closes the window (the legend under the window shows which). You can't navigate your bags with the gamepad during combat.") },
  },
})

articles:Define({
  id = "elvui-gw2", group = "integrations",
  title = L:G("ElvUI and GW2"),
  summary = L:G("Themes that match your ElvUI or GW2 UI look."),
  keywords = { L:G("ElvUI"), L:G("GW2 UI"), L:G("GW2_UI"), L:G("Guild Wars 2"), L:G("UI pack"), L:G("match my UI"),
    L:G("ElvUI theme"), L:G("GW2 UI theme"), L:G("match UI skin"), L:G("ElvUI bags"),
    L:G("ui overhaul"), L:G("blend in")
  },
  questions = { L:G("How do I make BetterBags match ElvUI?"), L:G("Does BetterBags have a GW2 UI theme?"),
    L:G("How do I make BetterBags look like ElvUI?"), L:G("Is there a theme that matches GW2 UI?"),
    L:G("Why don't my bags match my ElvUI fonts and colors?"),
    L:G("How do I turn on the ElvUI or GW2 UI theme in BetterBags?"),
    L:G("Can I use BetterBags instead of ElvUI bags and keep the same look?"),
    L:G("Where do I find the ElvUI and GW2 UI skins?"),
    L:G("ElvUI and GW2 UI")
  },
  related = { "themes" },
  body = {
    { text = L:G("When ElvUI or GW2 UI is installed, BetterBags offers a matching theme. Pick it on the Appearance page's Theme tab.") },
    { text = L:G("BetterBags Next's ElvUI theme uses your ElvUI colors, textures, and font, and redraws when you change them in ElvUI's options.") },
  },
})

articles:Define({
  id = "plugins", group = "integrations",
  title = L:G("Plugins"),
  summary = L:G("Addons that add categories, settings, and themes to BetterBags."),
  keywords = { L:G("plugin"), L:G("plugins"), L:G("addon"), L:G("extension"), L:G("BetterBags plugin"), L:G("third party"),
    L:G("BetterBags plugins"), L:G("addon extensions"), L:G("extra modules"), L:G("plugin settings"),
    L:G("curseforge"), L:G("companion addons"), L:G("addon packs")
  },
  questions = { L:G("What are BetterBags plugins?"), L:G("Where are a plugin's settings?"),
    L:G("What are BetterBags plugins and where do I see them?"),
    L:G("How do I install or use extra category addons for BetterBags?"),
    L:G("Where do plugin settings appear inside BetterBags?"),
    L:G("Can third-party plugins add new themes or categories?"),
    L:G("Why do I have extra options from another addon in my bag settings?"),
    L:G("How do plugins work with BetterBags?")
  },
  related = { "category-plugins" },
  body = {
    { text = L:G("Plugins are addons made for BetterBags. They can add their own categories, settings, and themes.") },
    { text = L:G("A plugin's settings appear on their own page under Integrations in the settings window.") },
    { see = "category-plugins" },
  },
})

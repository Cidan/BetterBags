local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class HelpArticles: AceModule
local articles = addon:GetModule('HelpArticles')

articles:Group({ id = "appearance", title = L:G("Appearance") })

articles:Define({
  id = "themes", group = "appearance", featured = true,
  title = L:G("Themes"),
  summary = L:G("Themes for BetterBags Next and classic bags"),
  keywords = { L:G("theme"), L:G("skin"), L:G("look"), L:G("style"), L:G("appearance"), L:G("dark"), L:G("ElvUI"),
    L:G("GW2"), L:G("Guild Wars 2"), L:G("parchment"), L:G("apply theme"),
    L:G("bag themes"), L:G("change skin"), L:G("preview theme"), L:G("bag appearance")
  },
  questions = { L:G("How do I change the theme?"), L:G("How do I make my bags look like ElvUI?"),
    L:G("How do I make my bags dark?"), L:G("Why did my theme go back?"),
    L:G("How do I change the theme or look of my bags?"), L:G("Can I preview a theme before saving it?"),
    L:G("What is the difference between BetterBags Next themes and classic themes?"),
    L:G("How do I switch back to the default bag skin?"), L:G("Where do I pick a different style for my bag window?"),
    L:G("Why do some themes only show up in Next or classic mode?")
  },
  pages = { "appearance", "appearance:theme" },
  related = { "effects", "glass", "elvui-gw2" },
  body = {
    { text = L:G("You choose themes on the Appearance page under its Theme tab. BetterBags shows a separate list of themes for whichever bag design you use, plus a theme picker for the Settings Window when you use the classic bags.") },
    { open = { page = "appearance", text = L:G("Open Appearance Settings") } },
    { heading = L:G("Previewing and Applying") },
    { steps = {
      L:G("Open Appearance > Theme in the Settings Window."),
      L:G("Click any available theme card to preview it at once without saving; its card status changes to Previewing."),
      L:G("Click Apply Theme to save the previewed theme as Active."),
    } },
    { text = L:G("If you switch to another settings page or close the Settings Window without clicking Apply Theme, BetterBags restores your previously saved theme. A card marked Unavailable requires another addon that is not currently loaded.") },
    { open = { page = "appearance", tab = "theme", text = L:G("Open Theme Settings") } },
    { heading = L:G("BetterBags Next Themes") },
    { text = L:G("While BetterBags Next is in use, Appearance > Theme shows themes that style the bags, dialogs, and the Settings Window together.") },
    { list = {
      L:G("Built-in themes are Default, Ember, Frost, Glitch, Halloween, Make It So, Papercraft, Parchment, Plain, Quiet, and Rainy Window."),
      L:G("Addon themes are ElvUI, which requires the ElvUI addon, and Guild Wars 2, which requires the GW2 UI addon."),
    } },
    { heading = L:G("Classic Bag Themes") },
    { text = L:G("While the classic bags are in use, Appearance > Theme has two sections: Bag Theme for the classic bag windows and Settings Window for the Settings Window itself, which is always drawn by a BetterBags Next theme.") },
    { list = {
      L:G("Built-in classic bag themes are Dark, Default, Parchment, Simple Dark, and Slate."),
      L:G("Addon classic bag themes are ElvUI, which requires the ElvUI addon, and Guild Wars 2, which requires the GW2 UI addon."),
    } },
    { see = "effects" },
    { see = "glass" },
    { see = "elvui-gw2" },
  },
})

articles:Define({
  id = "effects", group = "appearance", design = "next",
  title = L:G("Effects"),
  summary = L:G("Animation switches for BetterBags Next themes"),
  keywords = { L:G("animation"), L:G("effects"), L:G("sparkles"), L:G("shimmer"), L:G("snow"), L:G("bats"), L:G("smoke"),
    L:G("glitch"), L:G("disable animations"), L:G("motion"), L:G("distracting"), L:G("performance"),
    L:G("animation effects"), L:G("disable sparkles"), L:G("turn off snow"), L:G("theme animations")
  },
  questions = { L:G("How do I turn off the sparkles?"), L:G("How do I stop the snow?"), L:G("How do I turn off animations?"),
    L:G("The effects are distracting, how do I disable them?"),
    L:G("How do I turn off the sparkles and animations on my bag window?"),
    L:G("Can I disable snow, smoke, or particles in BetterBags Next themes?"),
    L:G("How do I make my theme stop moving or shimmering?"),
    L:G("Are the theme animation effects causing lag or distracting me?"),
    L:G("Where is the setting to disable animated theme effects?"),
    L:G("How do I keep a theme's colors without the extra particles?")
  },
  settings = { "nextSparkles", "nextShimmer", "nextTitleCloud", "nextTitleRibbon", "nextBraid", "nextOrnamentMotion",
    "nextGlitch", "nextRain", "nextShatter", "nextSnow", "nextSmoke", "nextBats", "nextBeam", "nextPaper",
    "nextStopMotion" },
  pages = { "appearance:animation" },
  related = { "themes", "glass" },
  body = {
    { text = L:G("In BetterBags Next, the Effects section on the Animation tab of Appearance lets you disable individual visual effects on any theme without changing themes. All switches default to on and take effect immediately on open bags without a reload.") },
    { text = L:G("Quiet, Plain, Guild Wars 2, and ElvUI have none of these effects. The Animation tab also lists Rain on Glass, Lightning, and Glass Sheen for Rainy Window.") },
    { open = { page = "appearance", tab = "animation", text = L:G("Open Animation Settings") } },
    { heading = L:G("Shared Effects") },
    { text = L:G("These switches control effects shared across multiple themes.") },
    { setting = "nextSparkles" },
    { text = L:G("Sparkles disables every sparkle emitter across titles, feathered edges, coupled bag knots, currency gains, and tracker pops on Default, Ember, Frost, Glitch, Halloween, Make It So, and Papercraft. On Papercraft, only burst sparkles exist to disable.") },
    { setting = "nextShimmer" },
    { text = L:G("Title Shimmer disables the spark, snowflake, bat, or light fleck that glides along the ribbon into the bag title on Default, Ember, Frost, Halloween, and Make It So.") },
    { setting = "nextTitleCloud" },
    { text = L:G("Title Cloud disables the breathing glow puffs behind the bag title on Default, Ember, Frost, and Halloween.") },
    { setting = "nextTitleRibbon" },
    { text = L:G("Title Ribbon disables the line extending from the bag title past the window edge on Default, Ember, Frost, Glitch, Halloween, Make It So, and Parchment. If Title Shimmer remains on, the shimmer still appears and flares at the title where the ribbon begins.") },
    { setting = "nextBraid" },
    { text = L:G("Braid disables the twisting ribbons between two coupled bags on Default, Ember, Frost, Glitch, Halloween, Make It So, Papercraft, Parchment, and Rainy Window. Quiet, Plain, Guild Wars 2, and ElvUI have no braid.") },
    { setting = "nextOrnamentMotion" },
    { text = L:G("Moving Ornaments stops animated ornaments and threads on Frost, Glitch, Halloween, Make It So, and Papercraft while keeping their art, except ornaments that only flash (such as the comm badge glint on Make It So), which are hidden instead. On Frost, the gold threads keep their art and opening draw-in but stop swaying and glinting; on Glitch, the corner brackets stop twitching when either Moving Ornaments or Glitch Effects is off.") },
    { heading = L:G("Theme Effects") },
    { text = L:G("These switches control effects specific to individual themes.") },
    { setting = "nextGlitch" },
    { text = L:G("Glitch Effects disables opening and closing flicker and tearing, periodic glitch bursts, and corner bracket twitches on Glitch. When off, Glitch bags slide in and out instead.") },
    { setting = "nextRain" },
    { text = L:G("Data Rain disables the falling columns of glyphs down the feathered edge and behind items on Glitch.") },
    { setting = "nextShatter" },
    { text = L:G("Ice Shatter disables freezing together from ice shards on open and shattering on close in Frost. When off, Frost bags slide in and out instead.") },
    { setting = "nextSnow" },
    { text = L:G("Snow, Leaves and Stars disables falling snow, wind gusts, and shooting stars on Frost, falling autumn leaves and wind gusts on Halloween, and streaking stars and warp gusts on Make It So.") },
    { setting = "nextSmoke" },
    { text = L:G("Smoke Puff disables rising smoke on open in Halloween. When off, Halloween bags slide in instead.") },
    { setting = "nextBats" },
    { text = L:G("Bats disables breaking into bats on close and fluttering header bats in Halloween. When off, Halloween bags slide out instead.") },
    { setting = "nextBeam" },
    { text = L:G("Transporter disables the beaming-in and beaming-out light column in Make It So. When off, Make It So bags slide in and out instead.") },
    { setting = "nextPaper" },
    { text = L:G("Paper Folding disables unfolding from a folded note on open and crumpling into a ball on close in Papercraft. When off, Papercraft bags slide in and out instead.") },
    { setting = "nextStopMotion" },
    { text = L:G("Stop Motion disables stepped pose timing and frame-to-frame wobble in Papercraft so its animations run smoothly every frame.") },
    { see = "themes" },
    { see = "glass" },
  },
})

articles:Define({
  id = "glass", group = "appearance", design = "next",
  title = L:G("Glass Themes"),
  summary = L:G("Smoked glass tint and weather effects"),
  keywords = { L:G("glass"), L:G("glass tint"), L:G("rainy window"), L:G("rain"), L:G("lightning"), L:G("sheen"), L:G("dark"),
    L:G("transparent"), L:G("see through"), L:G("flash"),
    L:G("glass theme"), L:G("glass opacity"), L:G("rain lightning sheen"), L:G("transparent bags"),
    L:G("translucent"), L:G("opaque glass")
  },
  questions = { L:G("How do I make the glass darker?"), L:G("How do I turn off the lightning?"),
    L:G("How do I stop the rain on my bags?"),
    L:G("How do I make the glass theme darker so items are easier to see?"),
    L:G("How do I turn off the rain or lightning in a glass theme?"),
    L:G("Can I adjust the transparency or background darkness of glass bags?"),
    L:G("How do I change the sheen effect on glass themes?"),
    L:G("Why are my bags see-through and how do I tweak them?"),
    L:G("Where are the settings for glass theme brightness and weather?")
  },
  settings = { "nextGlassTint", "nextGlassRain", "nextLightning", "nextSheen" },
  related = { "themes", "effects" },
  body = {
    { text = L:G("In BetterBags Next, glass themes such as Rainy Window replace solid bag backgrounds with smoked glass, surface reflections, edge glints, and a warm light centered on your pointer. The Settings Window uses solid smoke instead so text stays readable.") },
    { heading = L:G("Glass Tint") },
    { text = L:G("When a glass theme is active or previewed, a Glass section appears on the Appearance page under the Theme tab. Adjust Glass Tint from 0 for clear glass to 100 for nearly black smoked glass. The default value is 60, and higher values keep items readable over bright areas of the game world. Moving the slider updates every open glass panel immediately.") },
    { setting = "nextGlassTint" },
    { heading = L:G("Rain and Lightning") },
    { text = L:G("Rain on Glass and Lightning live on the Appearance page under the Animation tab. Turning off Rain on Glass removes beading drops, sliding runners, and drying beads while keeping the smoked glass, reflections, and pointer light. Turning off Lightning stops periodic double flashes across the glass, drops, and edges. No new lightning flash starts while you are in combat, though a flash already in progress finishes.") },
    { warning = L:G("Lightning flashes can be hard on some players' eyes. Turn off Lightning to disable them.") },
    { setting = "nextGlassRain" },
    { setting = "nextLightning" },
    { heading = L:G("Opening and Closing") },
    { text = L:G("Glass Sheen on the Animation tab controls the fade and sweeping light band that play across the glass when bags open and close. When Glass Sheen is turned off, glass bags slide in and out instead.") },
    { setting = "nextSheen" },
    { open = { page = "appearance", tab = "theme", text = L:G("Open Theme Settings") } },
    { open = { page = "appearance", tab = "animation", text = L:G("Open Animation Settings") } },
  },
})

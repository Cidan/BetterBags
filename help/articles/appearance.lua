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
  summary = L:G("Changing how your bags look, and trying a theme before you keep it."),
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
    { text = L:G("Pick a theme on the Appearance page's Theme tab. Click a card to preview it right away on your bags and this window, then click Apply Theme to keep it. If you leave the page without applying, your theme goes back to the one you kept.") },
    { heading = L:G("Next Themes") },
    { list = {
      L:G("Default: deep indigo, moonlit lavender, and starlight gold, with sparkles."),
      L:G("Plain: the game's own look for the version of the game you play."),
      L:G("Quiet: calm and compact, with smaller icons and no sparkles."),
      L:G("Parchment: paper and ink. Ember: charcoal and amber."),
      L:G("Rainy Window: smoked glass with rain running down it."),
      L:G("Frost, Glitch, Halloween, Make It So, and Papercraft: each with its own way of opening and closing."),
      L:G("ElvUI and Guild Wars 2: the look of those addons when they are installed."),
    } },
    { heading = L:G("Classic Themes") },
    { text = L:G("The classic bags support Default and Simple Dark, plus Dark, Parchment, and Slate from Moonlight, as well as ElvUI and Guild Wars 2 when those addons are installed. With the classic bags, the Theme tab also lets you pick the look of this settings window from BetterBags Next's themes.") },
    { open = { page = "appearance", tab = "theme", text = L:G("Open the Theme tab") } },
  },
})

articles:Define({
  id = "effects", group = "appearance", design = "next",
  title = L:G("Animation Effects"),
  summary = L:G("Turning off sparkles, snow, smoke, and the other effects in BetterBags Next's themes."),
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
    { text = L:G("The Appearance page's Animation tab has a switch for each effect. Turning an effect off disables it on every theme, and any bag that would open or close with that effect slides in and out instead.") },
    { list = {
      L:G("Sparkles, Title Shimmer, Title Cloud, Title Ribbon, and Braid: the sparkles and glows around titles, and the ribbons between chained bags."),
      L:G("Moving Ornaments: a theme's swaying, spinning, or pulsing pieces."),
      L:G("Glitch Effects and Data Rain: the Glitch theme's flicker and falling glyphs."),
      L:G("Ice Shatter and Snow, Leaves and Stars: Frost's ice, and the snow, leaves, or stars of Frost, Halloween, and Make It So."),
      L:G("Smoke Puff and Bats: Halloween's smoke and bats."),
      L:G("Transporter: Make It So's beaming in and out."),
      L:G("Paper Folding and Stop Motion: Papercraft's folding, and animations that run one pose at a time."),
    } },
    { setting = "nextSparkles" },
    { open = { page = "appearance", tab = "animation", text = L:G("Open the Animation tab") } },
  },
})

articles:Define({
  id = "glass", group = "appearance", design = "next",
  title = L:G("Glass Themes"),
  summary = L:G("Controlling how dark a glass theme is, along with its rain, lightning, and sheen."),
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
    { text = L:G("Glass themes, such as Rainy Window, draw your bags as a pane of glass.") },
    { list = {
      L:G("Glass Tint, on the Theme tab, sets how dark the glass is, from 0 for clear to 100 for nearly black smoked glass. Darker glass is easier to read over a bright world."),
      L:G("Rain on Glass: raindrops on the glass, with some running down now and then."),
      L:G("Lightning: a flash lighting up the glass now and then."),
      L:G("Glass Sheen: bags fading in and out as a band of light sweeps across them."),
    } },
    { warning = L:G("Flashes of lightning can be hard on some players' eyes. Turn off Lightning on the Animation tab if they bother you.") },
    { setting = "nextGlassTint" },
    { setting = "nextLightning" },
  },
})

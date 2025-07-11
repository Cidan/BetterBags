-- boot.lua handles the initialisation of the addon and the creation of the root module.

local addonName, root = ... --[[@type string, table]]

-- BetterBags is the root module of the addon.
---@class BetterBags: AceModule, AceHook-3.0, AceEvent-3.0
---@field isRetail boolean
---@field isClassic boolean
---@field isBCC boolean
---@field isCata boolean
---@field atBank boolean
---@field atWarbank boolean
---@field backpackShouldOpen boolean
---@field backpackShouldClose boolean
---@field atInteracting boolean
---@field Bags BagFrames
---@field _buttons CheckButton[]|MainMenuBagButton[]
---@field _bindingFrame Frame
---@field SetScript fun(obj: any, script: string, func: fun(ctx: Context, ...))
---@field HookScript fun(obj: any, script: string, func: fun(ctx: Context, ...))
---@field ForceHideBlizzardBags fun()
---@field ForceShowBlizzardBags fun()
---@field OnUpdate fun(ctx: Context)
---@field OpenInteractionWindow fun(ctx: Context, _: any, interactionType: Enum.PlayerInteractionType)
---@field CloseInteractionWindow fun(ctx: Context, _: any, interactionType: Enum.PlayerInteractionType)
---@field CloseBank fun(ctx: Context, _: any, interactingFrame: Frame)
---@field ToggleAllBags fun(self: BetterBags, ctx: Context, interactingFrame?: Frame)
---@field CloseSpecialWindows fun(self: BetterBags, interactingFrame: Frame)
---@field OnInitialize fun(self: BetterBags)
---@field GetBagFromBagID fun(self: BetterBags, bagid: number): Bag
---@field GetBagFromKind fun(self: BetterBags, kind: BagKind): Bag
---@field HideBlizzardBags fun(self: BetterBags)
---@field UpdateButtonHighlight fun(self: BetterBags)
---@field OnEnable fun(self: BetterBags)
local addon = LibStub("AceAddon-3.0"):NewAddon(root, addonName, 'AceHook-3.0')

addon:SetDefaultModuleState(false)

BINDING_NAME_BETTERBAGS_TOGGLESEARCH = "Search Bags"
BINDING_NAME_BETTERBAGS_TOGGLEBAGS = "Toggle Bags"

---@return BetterBags
function GetBetterBags()
  return LibStub('AceAddon-3.0'):GetAddon(addonName) --[[@as BetterBags]]
end

---@return Animations
function addon:GetAnimations()
  return self:GetModule('Animations') --[[@as Animations]]
end

---@return SectionFrame
function addon:GetSectionFrame()
  return self:GetModule('SectionFrame') --[[@as SectionFrame]]
end

---@return Constants
function addon:GetConstants()
  return self:GetModule('Constants') --[[@as Constants]]
end

---@return Database
function addon:GetDatabase()
  return self:GetModule('Database') --[[@as Database]]
end

---@return ItemFrame
function addon:GetItemFrame()
  return self:GetModule('ItemFrame') --[[@as ItemFrame]]
end

---@return Items
function addon:GetItems()
  return self:GetModule('Items') --[[@as Items]]
end

---@return Categories
function addon:GetCategories()
  return self:GetModule('Categories') --[[@as Categories]]
end

---@return Debug
function addon:GetDebug()
  return self:GetModule('Debug') --[[@as Debug]]
end

---@return Grid
function addon:GetGrid()
  return self:GetModule('Grid') --[[@as Grid]]
end

---@return Views
function addon:GetViews()
  return self:GetModule('Views') --[[@as Views]]
end

---@return Sort
function addon:GetSort()
  return self:GetModule('Sort') --[[@as Sort]]
end

---@return Localization
function addon:GetLocalization()
  return self:GetModule('Localization') --[[@as Localization]]
end

---@return Async
function addon:GetAsync()
  return self:GetModule('Async') --[[@as Async]]
end

---@return Trees
function addon:GetTrees()
  return self:GetModule('Trees') --[[@as Trees]]
end

---@return Events
function addon:GetEvents()
  return self:GetModule('Events') --[[@as Events]]
end

---@return Context
function addon:GetContext()
  return self:GetModule('Context') --[[@as Context]]
end

---@return ContextMenu
function addon:GetContextMenu()
  return self:GetModule('ContextMenu') --[[@as ContextMenu]]
end

---@return SearchBox
function addon:GetSearchBox()
  return self:GetModule('SearchBox') --[[@as SearchBox]]
end

---@return Themes
function addon:GetThemes()
  return self:GetModule('Themes') --[[@as Themes]]
end

---@return Fonts
function addon:GetFonts()
  return self:GetModule('Fonts') --[[@as Fonts]]
end

---@return Config
function addon:GetConfig()
  return self:GetModule('Config') --[[@as Config]]
end

---@return Pool
function addon:GetPool()
  return self:GetModule('Pool') --[[@as Pool]]
end

---@return EquipmentSets
function addon:GetEquipmentSets()
  return self:GetModule('EquipmentSets') --[[@as EquipmentSets]]
end

---@return Color
function addon:GetColor()
  return self:GetModule('Color') --[[@as Color]]
end

---@return Search
function addon:GetSearch()
  return self:GetModule('Search') --[[@as Search]]
end

---@return MoneyFrame
function addon:GetMoneyFrame()
  return self:GetModule('MoneyFrame') --[[@as MoneyFrame]]
end

---@return Slider
function addon:GetSlider()
  return self:GetModule('Slider') --[[@as Slider]]
end

---@return BagSlots
function addon:GetBagSlots()
  return self:GetModule('BagSlots') --[[@as BagSlots]]
end

---@return BagButton
function addon:GetBagButton()
  return self:GetModule('BagButton') --[[@as BagButton]]
end

---@return BagFrame
function addon:GetBagFrame()
  return self:GetModule('BagFrame') --[[@as BagFrame]]
end

---@return Resize
function addon:GetResize()
  return self:GetModule('Resize') --[[@as Resize]]
end

---@return Currency
function addon:GetCurrency()
  return self:GetModule('Currency') --[[@as Currency]]
end

---@return SectionConfig
function addon:GetSectionConfig()
  return self:GetModule('SectionConfig') --[[@as SectionConfig]]
end

---@return ThemeConfig
function addon:GetThemeConfig()
  return self:GetModule('ThemeConfig') --[[@as ThemeConfig]]
end

---@return WindowGroup
function addon:GetWindowGroup()
  return self:GetModule('WindowGroup') --[[@as WindowGroup]]
end

---@return Anchor
function addon:GetAnchor()
  return self:GetModule('Anchor') --[[@as Anchor]]
end

---@return List
function addon:GetList()
  return self:GetModule('List') --[[@as List]]
end

---@return ItemBrowser
function addon:GetItemBrowser()
  return self:GetModule('ItemBrowser') --[[@as ItemBrowser]]
end

---@return Tabs
function addon:GetTabs()
  return self:GetModule('Tabs') --[[@as Tabs]]
end

---@return Question
function addon:GetQuestion()
  return self:GetModule('Question') --[[@as Question]]
end

---@return SectionItemList
function addon:GetSectionItemList()
  return self:GetModule('SectionItemList') --[[@as SectionItemList]]
end

---@return SearchCategoryConfig
function addon:GetSearchCategoryConfig()
  return self:GetModule('SearchCategoryConfig') --[[@as SearchCategoryConfig]]
end

---@return NewSectionC
function addon:GetNewSectionC()
  return self:GetModule('NewSectionC') --[[@as NewSectionC]]
end

---@return ItemRowFrame
function addon:GetItemRowFrame()
  return self:GetModule('ItemRowFrame') --[[@as ItemRowFrame]]
end

---@return MovementFlow
function addon:GetMovementFlow()
  return self:GetModule('MovementFlow') --[[@as MovementFlow]]
end

---@return QueryParser
function addon:GetQueryParser()
  return self:GetModule('QueryParser') --[[@as QueryParser]]
end

---@return Binding
function addon:GetBinding()
  return self:GetModule('Binding') --[[@as Binding]]
end

---@return Stacks
function addon:GetStacks()
  return self:GetModule('Stacks') --[[@as Stacks]]
end

---@return Masque
function addon:GetMasque()
  return self:GetModule('Masque') --[[@as Masque]]
end

---@return ConsolePort
function addon:GetConsolePort()
  return self:GetModule('ConsolePort') --[[@as ConsolePort]]
end

---@return Pawn
function addon:GetPawn()
  return self:GetModule('Pawn') --[[@as Pawn]]
end

---@return SimpleItemLevel
function addon:GetSimpleItemLevel()
  return self:GetModule('SimpleItemLevel') --[[@as SimpleItemLevel]]
end

---@return Refresh
function addon:GetRefresh()
  return self:GetModule('Refresh') --[[@as Refresh]]
end

---@return DebugWindow
function addon:GetDebugWindow()
  return self:GetModule('DebugWindow') --[[@as DebugWindow]]
end

---@return Bucket
function addon:GetBucket()
  return self:GetModule('Bucket') --[[@as Bucket]]
end

---@return FormLayouts
function addon:GetFormLayouts()
  return self:GetModule('FormLayouts') --[[@as FormLayouts]]
end

---@return Form
function addon:GetForm()
  return self:GetModule('Form') --[[@as Form]]
end
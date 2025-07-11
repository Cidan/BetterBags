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
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
---@field data table<string, string>
local L = addon:NewModule('Localization')

-- Data is set outside of the initialization function so that
-- it loads when the file is read.
L.data = {}
local locale = GetLocale()
if locale == 'frFR' then
L.data["Backpack"] = "Sac à dos"
L.data["Left Click"] = "Clic Gauche"
L.data["Open Menu"] = "Ouvre le Menu"
L.data["Close Menu"] = "Ferme le Menu"
L.data["Bank"] = "banque"
L.data["Shift Left Click"] = "Shift clic gauche"
L.data["Show Bags"] = "Afficher les sacs"
L.data["Show Currencies"] = "Afficher les devises"
L.data["Welcome to Better Bags! Please select a help item from the left menu for FAQ's and other information."] = "Bienvenue chez Better Bags ! Veuillez sélectionner un élément d'aide dans le menu de gauche pour accéder aux FAQ et à d'autres informations."

L.data["Click to toggle the display of the bag slots."] = "Cliquez pour basculer l’affichage des emplacements de sacs."
L.data["Click to toggle the display of the currencies side panel."] = "Cliquez pour basculer l’affichage du panneau latéral des devises."

L.data["Open Options Screen"] = "Ouvrir l'écran des options"
L.data["Click to open the options screen."] = "Cliquez pour ouvrir l'écran des options"


-- Help
L.data["Custom Categories"] = "Catégories personnalisées"
L.data["Categories"]="Catégories"
L.data["Select which categories to show in this bag. If an option is checked, items that belong to the checked category will be put into a section for that category."]="Sélectionnez les catégories à afficher dans ce sac. Si une option est cochée, les éléments appartenant à la catégorie cochée seront placés dans une section pour cette catégorie."




L.data["How do I delete an item from a custom category?"] = "Comment supprimer un élément d'une catégorie personnalisée ?"
L.data["When viewing a custom category configuration, you can right click on an item to open it's menu and select 'delete' to delete it from the category."] = "Lors de l'affichage d'une configuration de catégorie personnalisée, vous pouvez cliquer avec le bouton droit sur un élément pour ouvrir son menu et sélectionner « supprimer » pour le supprimer de la catégorie."
L.data["Why are some of my items not showing up in my custom categories?"] = "Pourquoi certains de mes articles n'apparaissent-ils pas dans mes catégories personnalisées ?"
L.data["Items can only be in one category at a time. If you have a category that is missing items, it is likely that the items in that category are already in another category."] = "Les éléments ne peuvent appartenir qu’à une seule catégorie à la fois. Si vous avez une catégorie dans laquelle il manque des éléments, il est probable que les éléments de cette catégorie se trouvent déjà dans une autre."
L.data["Why does a custom category reappear after I delete it?"] = "Pourquoi une catégorie personnalisée réapparaît-elle après l'avoir supprimée ?"



L.data["If you delete a custom category that was created by another addon/plugin, it will reappear the next time you log in/reload. To permanently delete a custom category created by a plugin/another addon, you must disable the addon creating the category and then delete the category in the UI."] = "Si vous supprimez une catégorie personnalisée créée par un autre module complémentaire/plugin, elle réapparaîtra la prochaine fois que vous vous connecterez/rechargerez. Pour supprimer définitivement une catégorie personnalisée créée par un plugin/un autre module complémentaire, vous devez désactiver le module complémentaire créant la catégorie, puis supprimer la catégorie dans l'interface utilisateur."

L.data["Custom categories allow you to create your own categories for items. Type the name of the category you want to create in the box below and press enter to create an empty category."] = "Les catégories personnalisées vous permettent de créer vos propres catégories d'articles. Tapez le nom de la catégorie que vous souhaitez créer dans la case ci-dessous et appuyez sur Entrée pour créer une catégorie vide."

L.data["New Category Name"]= "Nom de la nouvelle Catégorie"
L.data["Create Category"]= "Création de Catégorie"

L.data["Search Bags"] = "Recherche dans les Sacs"
L.data["Search"] = "Recherche"
L.data["How do I search for items?"] = "Comment rechercher des articles ?"
L.data["Search Backpack"] = "Recherche dans les Sacs"
L.data["Enabled In-Bag Search"] = "Recherche dans les sacs activés"
L.data["Free Space"] = "Espaces Libres"
L.data["Recent Items"] = "items Récents"
L.data["New Item Duration"] = "Durée des nouveaux Items"
L.data["The time, in minutes, to consider an item a new item."] = "Le laps de temps, en minutes, nécessaire pour considérer un élément comme un nouvel élément."


L.data["Junk"] = "Trash"
L.data["View"] = "Vue"
L.data["Select which view to use for this bag."] = "Sélectionnez la vue à utiliser pour ce sac."
L.data["Section Grid"] = "Grille de Section"
L.data["List"] = "Liste"
L.data["One Bag"] = "Un seul Sac"
L.data["Display"] = "Affichage"
L.data["Items Per Row"] = "Item par Ligne "
L.data["Set the number of items per row in this bag."] = "Définissez le nombre d'articles par ligne dans ce sac."
L.data["Opacity"] = "Opacité"
L.data["Set the opacity of this bag."] = "Définissez l'opacité de ce sac."
L.data["Columns"] = "Colonne"
L.data["Set the number of columns sections will fit into."] = "Définissez le nombre de colonnes dans lesquelles les sections pourront tenir."
L.data["Scale"] = "Echelle"
L.data["Set the scale of this bag."] = "Définissez l'échelle de ce sac."
L.data["Help"] = "Aide"

L.data["Bienvenue chez Better Bags ! Veuillez sélectionner un élément d'aide dans le menu de gauche pour accéder aux FAQ et à d'autres informations."] = ""
L.data["Plugins"] = "Plugins"

L.data["Plugin configuration options can be accessed on the left by expanding the 'Plugins' menu option."] = "Les options de configuration du plugin sont accessibles sur la gauche en développant l'option de menu « Plugins »."
L.data["Size Descending"] = "Taille décroissante"
L.data["Size Ascending"] = "Taille croissante"
L.data["Item Sorting"] = "Tri des éléments"
L.data["Select how items should be sorted."] = "Sélectionnez la façon dont les éléments doivent être triés."
L.data["Quality, then Alphabetically"] = "Qualité, puis par ordre alphabétique"
L.data["Alphabetically, then Quality"] = "Par ordre alphabétique, puis Qualité"
L.data["Stacking"] = "Empilage"
L.data["Merge Stacks"] = "Fusionner les piles"
L.data["Merge stacks of the same item into a single stack."] = "Fusionnez les piles du même élément en une seule pile."
L.data["Merge Unstackable"] = "Fusionner non empilable"
L.data["Merge unstackable items of the same kind into a single stack, such as armors, bags, etc."] = "Fusionnez des objets non empilables du même type en une seule pile, comme des armures, des sacs, etc."
L.data["Unmerge at Shop"] = "Annuler la fusion dans la boutique"
L.data["Unmerge all items when visiting a vendor."] = "Annulez la fusion de tous les articles lors de la visite d'un fournisseur."
L.data["Don't Merge Partial"] = "Ne pas fusionner partiellement"
L.data["Don't merge stacks of items that aren't full stacks."] = "Ne fusionnez pas des piles d'éléments qui ne sont pas des piles complètes.erge Partial"
L.data["Item Level"] = "Niveau d'objet"
L.data["Enabled"] = "Activé"
L.data["Show the item level of items in this bag."] = "Afficher le niveau d'objet des objets contenus dans ce sac."
L.data["Color"] = "Couleur"
L.data["Color the item level text based on the item's quality."] = "Colorez le texte au niveau de l'objet en fonction de la qualité de l'objet."
L.data["Type"] = "Type"
L.data["Trade Skill"] = "Compétence commerciale"
L.data["Gear Set"] = "Ensemble d'equipement "
L.data["Equipment Location"] = "Emplacement de l'équipement"
L.data["Custom Categories"] = "Catégories personnalisées"
L.data["Select which custom categories to show in this bag. If an option is checked, items that belong to the checked category will be put into a section for that category."] = "Sélectionnez les catégories personnalisées à afficher dans ce sac. Si une option est cochée, les éléments appartenant à la catégorie cochée seront placés dans une section pour cette catégorie."
L.data["Item Compaction"] = "Compactage de l'article"
L.data["If Simple is selected, item sections will be sorted from left to right, however if a section can fit in the same row as the section above it, the section will move up."] = "Si Simple est sélectionné, les sections d'éléments seront triées de gauche à droite. Toutefois, si une section peut tenir dans la même rangée que la section située au-dessus, elle se déplacera vers le haut."
L.data["None"] = "Aucun"
L.data["Simple"] = "Simple"
L.data["Section Sorting"] = "Tri des sections"
L.data["Select how sections should be sorted."] = "Sélectionnez la façon dont les sections doivent être triées."
L.data["Alphabetically"] = "Alphabétiquement"
end

-- G returns the localized string for the given key.
-- If no localized string is found, the key is returned.
---@param key string
---@return string
function L:G(key)




  return self.data[key] or key

end






-- S sets the localized string for the given key.
---@param key string
---@param value string
---@return nil
function L:S(key, value)
  self.data[key] = value
end

L:Enable()

-- A saved profile from before bank categories were scoped by bank type: the bank's categoryToGroup is flat, and nothing marks it
-- migrated. The Warbank and the Character Bank each have an ARMOR WEAPONS and a CRAFTING tab, and each category is assigned to one
-- tab of one bank type, so items of that category in the other bank type have to land in that bank type's default tab.
return {
  profiles = {
    Default = {
      __groupsScopedByKind = true,
      __bankDefaultTabsFixed = true,
      groupCounter = { [1] = 10 },
      groups = {
        [1] = {
          [1] = { id = 1, name = "Bank", kind = 1, bankType = 0, isDefault = true, order = 1 },
          [2] = { id = 2, name = "Warbank", kind = 1, bankType = 2, isDefault = true, order = 2 },
          [4] = { id = 4, name = "ARMOR WEAPONS", kind = 1, bankType = 2, order = 4 },
          [6] = { id = 6, name = "CRAFTING", kind = 1, bankType = 2, order = 6 },
          [9] = { id = 9, name = "ARMOR WEAPONS", kind = 1, bankType = 0, order = 9 },
          [10] = { id = 10, name = "CRAFTING", kind = 1, bankType = 0, order = 10 },
        },
      },
      categoryToGroup = {
        [1] = {
          ["Head"] = 4,
          ["Mining - Midnight"] = 6,
          ["Mining - The War Within"] = 10,
        },
      },
    },
  },
}

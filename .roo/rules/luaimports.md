# WoW Lua Imports

When using other modules that are a part of the addon, you must remember to import the module at the top of the file like. For example, if you want to access the 'database' module, you must ensure the following is at the top of the file:

```lua
---@type Database
local database = addon:GetModule('Database') --[[@as Database]]
```
# Libraries

* Never, ever edit the files in .libraries/ and libs/, as they are externally generated.

* Use ./libraries/vscode-wow-api as documentation for the World of Warcraft API.

* Always scan ./libs for any Ace related function calls or functionality.

* If you can't find what you're looking for, the full source code reference for base World of Warcraft Lua addons is in ./libraries/wow-ui-source. Note, this does not include the source for client API calls, just the Lua that is part of the base game (and thus accessible to this addon).
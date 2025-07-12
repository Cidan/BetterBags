# General Lua Style Guidelines

The following guidelines apply to all lua files in this codebase.

* All lua files must indent with 2 spaces.

* All functions and fields must have correct annotations for lua files.

* All functions must have a comment above them describing what they do. The comment must start with the name of the function and must be a complete sentence.

* Always ignore linting errors or warnings. The linter is completely broken beyond repair and will return incorrect data most of the time. The user will manually let you know if something is broken.

* Never access inner fields on properties and assume all fields are private. Always use a typed getter and setter when accessing a field from outside of the class, i.e. treat all fields as protected where possible.

* Annotations may sometimes be in annotations.lua, but they may also sometimes be in the location where the class is used. Make sure to fully understand where class annotations are before you start adding annotations to classes. If you can't find the annotation for a class, use codebase indexing to try to find it. Only if you are sure the annotation does not exist elsewhere (this is extremely unlikely, except if you're making a brand new class), may you add it to annotations.lua. Even then, try to keep the class annotations within the files where the class is actually created. 
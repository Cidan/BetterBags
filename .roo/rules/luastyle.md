# General Lua Style Guidelines

The following guidelines apply to all lua files in this codebase.

* All lua files must indent with 2 spaces.

* All functions and fields must have correct annotations for lua files.

* All functions must have a comment above them describing what they do. The comment must start with the name of the function and must be a complete sentence.

* Never ignore linting errors or warnings. Always keep the codebase clean, and always properly annotate all fields.

* Never access inner fields on properties and assume all fields are private. Always use a typed getter and setter when accessing a field from outside of the class, i.e. treat all fields as protected where possible.
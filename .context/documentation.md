# Documentation

A package and/or module is a top level directory that contains files that end in .lua, except for "libs" and ".libraries"

Every time you are working in a package, you are always to look for a README.md in the directory containing the package. If it exists, you are to read it every time and use it's context to help guide you.

If you are editing, updating, or creating a new package and a README.md does not exist, you are to create a README.md file explaining the package and it's functionality, putting that README.md in the package's folder. This means when creating a new README.md, you must read all the files in the package to understand how everything fits together, and possibly read other packages to document functionality correctly.

If you are updating a package that does have a README.md already, you are to update the README.md any time you change the code in such a way, that the README.md should document the nuance of what was changed, not as a changelog, but as a full updated revision that includes your new changes.

All of the above must happen automatically without prompting the user, for every single task you do.
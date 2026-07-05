Version 2.10 (2026-05-13)
============

Changes since version 2.9:
  *  Fix regression in the pure-Lua decoder introduced in 2.9:
     This is a security vulnerability enabling denial-of-service attacks
     (unterminated loop) with a well-crafted (invalid JSON) input string.

Version 2.9 (2026-04-29)
===========

Changes since version 2.8:
  *  Performance improvements for the pure-Lua decoder.

Version 2.8 (2024-06-17)
===========

Changes since version 2.7:
  *  Fix handling of decoding errors when Lua is compiled with LUA_NOCVTN2S.

Version 1.4 (2024-06-17)
===========

Changes since version 1.3:
  *  Fix handling of decoding errors when Lua is compiled with LUA_NOCVTN2S.

Version 2.7 (2024-02-20)
===========

Changes since version 2.6:

  *  Enable working with newer versions of LPeg where the "version" field
     is no longer a function.
  *  Fix error messages when an encoding error happens in an ordered
     dictionary.

Version 2.6 (2021-12-19)
===========

Changes since version 2.5:

  *  The decode function is no longer automatically replaced by the version
     implemented using LPeg, but an LPeg-enabled copy of the module has to
     be requested explicitly with the function use_lpeg.
     This was changed to improve the predictability of the code and make
     audits more reliable.
  *  The LPeg-version of the decode function now reports unterminated
     strings, arrays and objects with the position where they started
     rather than where parsing failed which was usually at the end of the
     input string.  This was already the behavior of the
     pure-Lua-implementation.
  *  Fixed a bug where entries in a dictionary were not put in the desired
     order when their value was the boolean false.

Version 2.5 (2014-04-28)
===========

Changes since version 2.4:

  *  Added customizable exception handling.
  *  Decode input that contains JavaScript comments.

Version 2.4 (2013-09-28)
===========

Changes since version 2.3:

  *  Fixed encoding and decoding of numbers in different numeric locales.
  *  Prevent using version 0.11 of LPeg (causes segmentation faults on
     some systems).

Version 1.3 (2013-09-28)
===========

Changes since version 1.2:

  *  Fixed encoding and decoding of numbers in different numeric locales.

Version 2.3 (2013-04-14)
===========

Changes since version 2.2:

  *  Corrected the range of escaped characters.  Among other characters
     U+2029 was missing, which would cause trouble when parsed by a
     JavaScript interpreter.
  *  Added options to register the module table in a global variable.
     This is useful in environments where functions similar to require are
     not available.

Version 1.2 (2013-04-14)
===========

Changes since version 1.1:

  *  Corrected the range of escaped characters.  Among other characters
     U+2029 was missing, which would cause trouble when parsed by a
     JavaScript interpreter.
  *  Locations for error messages were off by one in the first line.

Version 2.2 (2012-04-28)
===========

Changes since version 2.1:

  *  __jsontype is only used for empty tables.
  *  It is possible to decode tables without assigning metatables.
  *  Locations for error messages were off by one in the first line.
  *  There is no LPeg version of json.quotestring anymore.

Version 2.1 (2011-07-08)
===========

Changes since version 2.0:

  *  Changed the documentation to Markdown format.
  *  LPeg is now parsing only a single value at a time to avoid running
     out of Lua stack for big arrays and objects.
  *  Read __tojson, __jsontype and __jsonorder even from blocked metatables
     through the debug module.
  *  Fixed decoding single numbers (only affected the non-LPeg mode).
  *  Corrected the range of escaped Unicode control characters.

Version 1.1 (2011-07-08)
===========

Changes since version 1.0:

  *  The values NaN/+Inf/-Inf are recognised and encoded as "null" like in
     the original JavaScript implementation.
  *  Read __tojson even from blocked metatables through the debug module.
  *  Fixed decoding single numbers.
  *  Corrected the range of escaped Unicode control characters.

Version 2.0 (2011-05-31)
===========

Changes since version 1.0:

  *  Optional LPeg support.
  *  Invalid input data for encoding raises errors instead of returning nil
     and the error message. (Invalid data for encoding is usually a
     programming error. Raising an error removes the work of explicitly
     checking the result).
  *  The metatable field __jsontype can control whether a Lua table is
     encoded as a JSON array or object. (Mainly useful for empty tables).
  *  When decoding, two metatables are created. One is used to mark the arrays
     while the other one is used for the objects. (The metatables are
     created once for each decoding operation to make sandboxing possible.
     However, you can specify your own metatables as arguments).
  *  There are no spaces added any longer when encoding.
  *  It is possible to explicitly sort keys for encoding by providing an array with key
     names to the option "keyorder" or the metatable field __jsonorder.
  *  The values NaN/+Inf/-Inf are recognised and encoded as "null" like in
     the original JavaScript implementation.

Version 1.0
===========

Initial version, released 2010-08-28.


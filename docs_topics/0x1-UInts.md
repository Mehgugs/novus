## UInts?

This library uses unsigned integers to represent snowflakes, discord's ID type,
yet Lua does not have an unsigned integer type?

### The Lua integer subtype

Lua 5.3 introduced support for signed 64 bit integer numbers, as a subtype of
the normal number type. You can check the subtype with `math.type`.
This means when we write `1` it is interpreted as an integer subtype.
There are some rules about when are where numerals are treated as integers.
For example `1.0` is a float/double subtype number.

### What is an unsigned integer

To put it simply, a regular lua integer is 63 bits with 1 sign bit. This means
we can represent numbers in the range [-2^63 + 1, 2^63 -1]. An unsigned integer with
64 bits would be in the range [0, 2^64 -1].


This at first seems like the unsigned type is incompatible with Lua but: *we can just pretend signed integers are unsigned*.
Lua provides us the `"%u"` format option to print numbers as unsigned integers, and
`math.ult` to compare them. This allows us to skip using strings to contain snowflakes,
which is nice. When in the documentation **encoded uint64** is used, it just means that
the *actual* type is an int64 but we're pretending it's unsigned.

### It's probably a waste of time
I think that the snowflakes will flow into the unsigned range in around 2081,
which is quite a long way away.

### Using them in code

Novus internally uses the encoded uint64 for all snowflakes and will convert the
strings sent by discord. You should use the @{novus.util.uint|uint} module to write down literals.

```lua

local uint = require"novus.util.uint"

local my_id = uint"92271879783469056"

```


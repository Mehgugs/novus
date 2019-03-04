## Novus
[![Build Status](https://travis-ci.org/Mehgugs/novus.svg?branch=master)](https://travis-ci.org/Mehgugs/novus)
[![CircleCI](https://circleci.com/gh/Mehgugs/novus/tree/master.svg?style=svg)](https://circleci.com/gh/Mehgugs/novus/tree/master)


**A [Discord API][discord] library written in lua 5.3, for lua 5.3.**

### WIP
This project is currently a work in progress. Do not expect a fully working
library with `version < 1.0.0`.

### About
Novus is a wrapper for the official Discord API.
It uses [cqueues][cqueues] and [lua-http][lua_http] to provide a minimal, yet featureful,
interface for developing lightweight discord bot applications.

### Installation
- You need a [lua 5.3 distribution installed][lua],
- You need [luarocks][luarocks],
- To install the packages from luarocks you need:
  - C compiler toolchain compatible with luarocks (gcc),
  - `m4` and `awk` for `cqueues`,
  - `libssl-dev` for `luaossl`,
  - `libz-dev` for `lua-zlib`,
  - To run the tests you need `busted` and `luacov` from luarocks.
- To install from github:
  - `$ git clone https://github.com/Mehgugs/novus.git`,
  - `$ cd novus && luarocks make`.
- To install the luarocks release directly (not published yet):
  - `$ luarocks install novus`.

### Examples

Currently the client and top-level have not been finished,
you can test current functionality with the following:
```lua
local client = require"novus.client"

local myclient = client.create{
  token = "Bot "..os.getenv"TOKEN"
}

myclient:run()
```

### Documentation

Documentation and more involved examples can be found in the [User Manual](https://mehgugs.github.io/novus/manual/01-Introduction.md.html).

### Contributing

TODO

[discord]: https://discordapp.com/developers/docs/intro
[lua]: https://www.lua.org/manual/5.3/

[luarocks]: https://github.com/luarocks/luarocks/wiki/Download
[cqueues]: https://github.com/wahern/cqueues
[lua_http]: https://github.com/daurnimator/lua-http

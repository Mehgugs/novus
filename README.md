# Novus #
[![Build Status](https://travis-ci.org/Mehgugs/novus.svg?branch=master)](https://travis-ci.org/Mehgugs/novus)


**A [Discord API][discord] library written in lua 5.3, for lua 5.3.**

### WIP ###
This project is currently a work in progress. Do not expect a fully working 
library with `version < 1.0.0`. 

### About ###
Novus is a wrapper for the official Discord API.
It uses [cqueues] and [lua-http][lua_http] to provide a minimal, yet featureful,
interface for developing lightweight discord bot applications. 

### Installation ###
- You need a [lua 5.3 distribution installed][lua],
- You need [luarocks],
- To install the packages from luarocks you need:
    - C compiler toolchain compatible with luarocks (gcc),
    - `m4` and `awk` for `cqueues`,
    - `libssl-dev` for `luaossl`,
    - `libz-dev` for `lua-zlib`,
    - To run the tests you need `busted` and `luacov` from luarocks (see `.travis.yml` for using lua and this library in CI).
- To install from github:
    - `$ git clone https://github.com/Mehgugs/novus.git`,
    - `$ cd novus && luarocks make`.
- To install the luarocks release directly (not published yet):
    - `$ luarocks install novus`.

### Examples ###

Currently the client and top-level have not been finished,
you can test current functionality with the following:
```lua
local util = require"novus.util"
local client = require"novus.client"
local cqueues = require"cqueues"
local json = require"rapidjson"

local myclient = client.create{
     token = "Bot "..os.getenv"TOKEN"
    ,compress = false
    ,large_threshold = 100 
    ,driver = "default" 
}

client.run(myclient)
```

### Documentation ###

Documentation and more involved examples can be found in the [User Manual](). 

### Contributing ###

TODO

[discord]: https://discordapp.com/developers/docs/intro
[lua]: https://www.lua.org/manual/5.3/

[luarocks]: https://github.com/luarocks/luarocks/wiki/Download
[cqueues]: https://github.com/wahern/cqueues
[lua_http]: https://github.com/daurnimator/lua-http 

[discord]: https://discordapp.com/developers/docs/intro
[lua]: https://www.lua.org/manual/5.3/

[luarocks]: https://github.com/luarocks/luarocks/wiki/Download
[cqueues]: https://github.com/wahern/cqueues
[lua_http]: https://github.com/daurnimator/lua-http 

# Novus #
**A [Discord API](discord) library written in lua 5.3, for lua 5.3.**

### About ###
Novus is a wrapper for the official Discord API.
It uses [cqueues](cqueues) and [lua-http](lua_http) to provide a minimal, yet featureful,
interface for developing lightweight discord bot applications. 

### Installation ###
- You need a [lua 5.3 distribution installed](lua),
- You need [luarocks](luarocks),
- To install from github:
    - `$ git clone https://github.com/Mehgugs/novus.git`
    - `$ cd novus && luarocks make`
- To install the luarocks release directly:
    - `$ luarocks install novus`

### Examples ###

#### I: Using `novus.environ` ####

```lua
local novus = require"novus"
local _ENV = require"novus.environ"

token = os.getenv"TOKEN"

function ready(ctx)
    novus.util.info("Bot %s online", ctx.me.tag)
end

function message_create(ctx)
    novus.util.info("%s> %q", ctx.author.tag, ctx.message.content)
end 

novus.run()
```

#### II: More conventional ####

```lua
local novus = require"novus"

local client = novus.new()

client.token = os.getenv"TOKEN"

client.events.ready = function(ctx) 
    novus.util.info("Bot %s online", ctx.me.tag)
end

client.events.message_create = function(ctx)
    novus.util.info("%s> %q", ctx.author.tag, ctx.message.content)
end 

novus.run(client)
```

### Documentation ###

Documentation and more involved can be found in the [User Manual](). 

### Contributing ###

TODO
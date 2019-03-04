## The First Example

Using the client level we can write a nice example of a command bot.
We will use the `emission` api to write an simple, but fancy, command parser.
Although perhaps a tad overkill for the introductory example, I think it's good to
dive in deep and get a feel for what's happening.

### Importing Modules

To use the client level we simply import it from `novus.client`, we also need `novus.client.emission` to deal with `emitters` and it doesn't hurt to loads `novus.util` (the second biggest section of the library 😔)

We need the `novus.util.relabel` module to write our command's syntax grammar (I promise it's not as scary as it sounds!) so we can check a message does indeed contain commands.


```lua
local util = require"novus.util" -- Our utilities
local client = require"novus.client" -- Client level API
local emission = require"novus.client.emission" -- Emitter API
local re = require"novus.util.relabel" -- Parsing / LPeg API
```


### Making a Client

Since the client level api isn't designed to be too complex, we just call `client.create` with our
options and get back a `client` state which is just a table bundling all the bits we need to run a bot.


```lua
local myclient = client.create{
  token = "Bot "..os.getenv"TOKEN"
}
```


### Emitters and Events

Novus uses an emitter pattern to communicate events to your code. Inside `client.events` you will
find a collection of @{client.emission.emitter|emitter} objects, indexed by their event name. Let's make our bot log when it's `READY`.


```lua
-- An emitter exposes a emitter:listen method to add callbacks.
myclient.events.READY:listen(function(ctx)
  util.info ("Bot %s online!", myclient:me().tag)
end)
```

The argument we receive in the callback is the @{client.context.context|context} of the event, it will contain all the relevant discord objects involved in the event.


### What if I'm morally against callbacks?

If this style doesn't take your fancy there are other ways to receive events:

You can wait for the next event using a condition style API:


```lua
myclient :wrap(function()
  -- this is async so we need to wrap it.
  local ctx = myclient.events.READY:wait()
  util.info("[Await] Bot %s online!", myclient:me().tag)
end)
```


You can wrap everything in a promise and get a stateful object that can be itself awaited
or passed around:


```lua
-- creates a new promise from the given async function.
local has_readied = myclient:promised(function()
-- :promised grabs a promise for then next event.
  local ready = myclient.events.READY:promised()
  local ctx = ready() -- awaits the promise
  util.info ("[Promise] Bot %s online!", myclient:me().tag)
  return true
end)
```

You can iterate over all events asynchronously using `pairs`:


```lua
myclient:wrap(function()
-- this is async so we need to wrap it.
  for i, ctx in pairs(myclient.events.READY) do
    util.info ("[Async Iterator] Bot %s online!", myclient:me().tag)
  end
end
```


Not all of these styles of receiving events are sensible for this use case, I think a callback or await would be sufficient, but it's to showcase how useful the emitters are for communication.

### Recap
We've seen: what modules we'll need; how to create a client state; and how to listen to events from discord. Putting that all together and running requires one more function, `client.run` which will start our bot.

```lua
local util = require"novus.util"
local client = require"novus.client"
local emission = require"novus.client.emission"
local re = require"novus.util.relabel"

local myclient = client.create{token = "Bot "..os.getenv"TOKEN"}

myclient.events.READY :listen (function(ctx)
  util.info ("Bot %s online!", myclient:me().tag)
end)

myclient:run() --NB this blocks.
```

>To run this make sure you've read the installation guide!

Running this you should get something like the following:

```
Sat Feb  9 16:55:38 2019 INF  Creating Client-fd33b1b6
Sat Feb  9 16:55:38 2019 INF  Initialized API-da255785 with TOKEN-5bc85d0e
Sat Feb  9 16:55:38 2019 INF  Client-fd33b1b6 is starting using TOKEN-1539857678.
Sat Feb  9 16:55:39 2019 INF  TOKEN-1539857678 has used 12/1000 sessions.
Sat Feb  9 16:55:39 2019 INF  Client-fd33b1b6 is launching 1 shards
Sat Feb  9 16:55:39 2019 INF  Initialized Shard-0 with TOKEN-5bc85d0e
Sat Feb  9 16:55:39 2019 INF  Shard-0 is connecting to wss://gateway.discord.gg?etc
Sat Feb  9 16:55:39 2019 INF  Shard-0 has connected.
Sat Feb  9 16:55:39 2019 INF  discord said hello to Shard-0 trace="gateway-prd-main-ncd7"
Sat Feb  9 16:55:39 2019 INF  Shard-0 has a heartrate of 41 sec .
Sat Feb  9 16:55:39 2019 WRN  Outgoing heart beating
Sat Feb  9 16:55:39 2019 INF  Bot Maria 🌚#1477 online!
```

Okay so our bot is online, but it doesn't do do anything right now. Let's change that.

### Listening for incoming messages

Using what we know about @{client.emission.emitter|emitters} we can add a listener to the `MESSAGE_CREATE`
event:

```lua
myclient.events.MESSAGE_CREATE:listen(function(ctx)
-- Looking at the @{client.context.context|context} docs we see that it has a `msg` field.
  if ctx.msg.content == "!ping" then
    ctx.msg:reply"Pong!"
  end
end)
```

If you add this **before your client:run() call** and restart the bot you'll be able to type `!ping` and get a
`Pong!` back from the bot.

### Parsing and propagating

We'd like something more general for this simple example, so let's make a new event
which is fired when the bot receives a command.

```lua
local function parse_command()
  --TODO
end

local command_parsed = emission.new()
myclient.events.MESSAGE_CREATE:listen(function(ctx)
  local nxt, success = parse_command(ctx)
  if success then
    command_parsed:emit(ntx)
  end
end
```

This will be how the listen looks when we add our new event, when the function `parse_command` returns `true`
we will emit an event to `command_parsed`. The concept of chaining events together with a transforming function is quite nice so there's a built in syntax for it in the emission API:

```lua
local function parse_command()
  --TODO
end

local command_parsed =  myclient.events.MESSAGE_CREATE
  >> parse_command
  >> emission.new()
```

Using the `>>` notation is better because we can chain multiple transforming functions
as we will see in later examples.

Now onto `parse_command`. I'm just going to give you the grammar we're going to use and not explain it in detail; you should read the @{0x-LPeg.md|LPeg Cookbook} for information.

```lua
-- All you need to know about grammar
-- is that we call grammar:match("")
-- and either get nil or a {prefix = "", name = "", args = {""}}
local grammar = re.compile[[
  command <- {|prefix %s? name %s* args|}
  args <- {:args: {|(arg %s*)*|}:}
  arg <- string / {%S+}
  name <- {:name: %S+ :}
  prefix <- {:prefix: . :}
  string <- '"' sbody '"'
  sbody <- {~ (('\"' -> '"') / (!'"' .))* ~}
]]

local function parse_command(ctx)
  local result = grammar:match(ctx.msg.content)
  if result then
    return ctx
    :add_extra('cmd', result.prefix .. result.name)
    :add_extra('command', result)
    ,true
  else
    return false
  end
end
```

So this function will use the grammar to parse a string: returning `true`
and our updated context on success; or false on failure.

### Adding it all together

Let's use our new event and parse some new commands.

```lua
local util = require"novus.util"
local client = require"novus.client"
local emission = require"novus.client.emission"
local re = require"novus.util.relabel"

local myclient = client.create{token = "Bot "..os.getenv"TOKEN"}

myclient.events.READY :listen (function(ctx)
  util.info ("Bot %s online!", myclient:me().tag)
end)

local grammar = re.compile[[
  command <- {|prefix %s? name %s* args|}
  args <- {:args: {|(arg %s*)*|}:}
  arg <- string / {%S+}
  name <- {:name: %S+ :}
  prefix <- {:prefix: . :}
  string <- '"' sbody '"'
  sbody <- {~ (('\"' -> '"') / (!'"' .))* ~}
]]

local function parse_command(ctx)
  local result = grammar:match(ctx.msg.content)
  if result then
    return ctx
    :add_extra('cmd', result.prefix .. result.name)
    :add_extra('command', result)
    ,true
  else
    return false
  end
end

local command_parsed =  myclient.events.MESSAGE_CREATE
  >> parse_command
  >> emission.new()

command_parsed:listen(function(ctx)
  if ctx.cmd == "!ping" then ctx.msg:reply"Pong!" end
end)

myclient:run()
```

Okay so we've got a parser, but we've kept the same if statement to check if we have a command. Let's add
a table of commands:

```lua
local commands = {}
command_parsed:listen(function(ctx)
  local handler = commands[ctx.cmd]
  if handler then
    local reply = table.pack(handler(ctx))
    if reply.n > 0 then ctx.msg:reply(table.unpack(reply, 1, reply.n))
  end
end)
```

This will lookup the function in `commands` and call it with the context.
If we return values from the handler we pass them to reply, useful.

Now our ping command looks like this:

```lua
commands["!ping"] = function() return "Pong!" end
```

And our script so far should look like:

```lua
local util = require"novus.util"
local client = require"novus.client"
local emission = require"novus.client.emission"
local re = require"novus.util.relabel"

local myclient = client.create{token = "Bot "..os.getenv"TOKEN"}

myclient.events.READY :listen (function(ctx)
  util.info ("Bot %s online!", myclient:me().tag)
end)

local grammar = re.compile[[
  command <- {|prefix %s? name %s* args|}
  args <- {:args: {|(arg %s*)*|}:}
  arg <- string / {%S+}
  name <- {:name: %S+ :}
  prefix <- {:prefix: . :}
  string <- '"' sbody '"'
  sbody <- {~ (('\"' -> '"') / (!'"' .))* ~}
]]

local function parse_command(ctx)
  local result = grammar:match(ctx.msg.content)
  if result then
    return ctx
    :add_extra('cmd', result.prefix .. result.name)
    :add_extra('command', result)
    ,true
  else
    return false
  end
end

local command_parsed =  myclient.events.MESSAGE_CREATE
  >> parse_command
  >> emission.new()

local commands = {}
command_parsed:listen(function(ctx)
  local handler = commands[ctx.cmd]
  if handler then
    local reply = table.pack(handler(ctx))
    if reply.n > 0 then ctx.msg:reply(table.unpack(reply, 1, reply.n)) end
  end
end)

commands["!ping"] = function(ctx) return "Pong!" end

myclient:run()
```

Please feel free to play around and add some more commands!
You will get a list of arguments in `ctx.command.args`.

```
!ping foo bar "a full string of text"
{prefix = "!", name = "ping", args = {"foo", "bar", "a full string of text"}}
```

You can add this to the client to make it feel official if you like.

```lua
client.events.COMMAND = command_parsed
```

#### @{01-Introduction.md|What to do next?}

## Introduction

### What

Novus is a client library for the discord API for bot clients. It's designed to provide
high level abstractions to make writing bots painless, but also provide a minimal core
client which can be used for sugar-free applications.

Another feature of novus is its usage of [cqueues][cqueues] and [lua-http][lua-http]. Both of these libraries
provide an excellent networking toolbox which is fully asynchronous. Leveraging cqueues,
novus is naturally async and multi-threading ready via the **cqueues.thread** module.

### About these docs

The documentation produced by LDoc aims to be a technical reference of the API exposed by novus and not contain too much waffle. The accompanying Manual pages will tell you
*how* to write bots in novus, with full examples and explanation.

### Where Do I start?

#### @{02-DiveIn.md|The First Example}


[discord]: https://discordapp.com/developers/docs/intro
[lua]: https://www.lua.org/manual/5.3/

[luarocks]: https://github.com/luarocks/luarocks/wiki/Download
[cqueues]: https://github.com/wahern/cqueues
[lua-http]: https://github.com/daurnimator/lua-http
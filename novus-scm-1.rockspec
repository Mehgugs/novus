package = 'novus'
version = 'scm-1'

source  = {
    url = 'git://github.com/Mehgugs/novus.git'
}

description = {
     summary = 'A Discord API library written in lua 5.3, for lua 5.3.'
    ,homepage = source.url
    ,license = 'MIT'
    ,maintainer = 'm4gicks@gmail.com'
    ,detailed = 
"Novus is a wrapper for the official Discord API.\
It uses cqueues and lua-http to provide a minimal, yet featureful,\
interface for developing lightweight discord bot applications."
}

dependencies = {
     'lua >= 5.3'
    ,'cqueues'
    ,'http'
    ,'lua-zlib'
    ,'lpeglabel >= 1.0'
}

build = {
     type = "builtin"
    ,modules = {}
}
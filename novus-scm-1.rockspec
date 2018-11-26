package = 'novus'
version = 'scm-1'

source  = {
    url = 'git://github.com/Mehgugs/novus.git'
}

description = {
     summary = 'A completely modular discord library powered by lua-http.'
    ,homepage = source.url
    ,license = 'MIT'
    ,maintainer = 'm4gicks@gmail.com'
    ,detailed = ''
}

dependencies = {
     'lua >= 5.3'
    ,'cqueues'
    ,'http'
    ,'lua-zlib'
    ,'penlight'
}

build = {
    type = "builtin"
}
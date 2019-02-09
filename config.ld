project = 'Novus'
description = 'For creating lightweight discord bots in lua.'
full_description = 'The documentation is available @{01-Introduction.md|here}.'
title = 'Novus Documentation'
dir = 'docs'
pretty = 'lxsh'
--prettify_files=true
not_luadoc=true
convert_opt=true
use_markdown_titles = true
topics = {'docs_topics/01-Introduction.md', 'docs_topics/02-DiveIn.md'}
examples = {'./examples'}
package = 'novus'
format = 'discount'
sort_modules=true
file = {
    'lua/novus'
}
style = 'docs_style'
template = 'docs_style'
kind_names={topic='Manual',module='Libraries'}
tparam_alias('pattern','lpeg-pattern')
tparam_alias('int', 'integer')
tparam_alias('tab', 'table')
tparam_alias('func', 'function')
tparam_alias('view', 'view')
alias('ret',{'return',modifiers={type="$1"}})
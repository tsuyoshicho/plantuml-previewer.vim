scriptencoding utf-8

if exists('g:loaded_plantuml_previewer')
  finish
endif
let g:loaded_plantuml_previewer = 1

let s:save_cpo = &cpo
set cpo&vim

command! PlantumlStart call plantuml_previewer#start()
command! PlantumlOpen call plantuml_previewer#open()
command! PlantumlStop call plantuml_previewer#stop()
command! -nargs=* -complete=file PlantumlSave call plantuml_previewer#save_as(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

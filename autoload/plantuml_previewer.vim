scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:Process  = vital#plantuml_previewer#import('System.Process')
let s:Job      = vital#plantuml_previewer#import('System.Job')
let s:Filepath = vital#plantuml_previewer#import('System.Filepath')

let s:is_win = has('win32') || has('win64') || has('win95')

let s:base_path = s:Filepath.abspath(expand("<sfile>:p:h:h"))

let s:default_jar_path = s:Filepath.realpath(
      \ s:base_path . s:Filepath.separator() .
      \ 'lib' .  s:Filepath.separator() .
      \ 'plantuml.jar')

let s:tmp_path = s:Filepath.realpath(
      \ s:base_path . s:Filepath.separator() .
      \ 'tmp')

let s:save_as_script_path = s:Filepath.realpath(
      \ s:base_path . s:Filepath.separator() .
      \ 'script' .  s:Filepath.separator() .
      \ 'save-as' . (s:is_win ? '.cmd' : '.sh'))
let s:save_as_tmp_puml_path = s:Filepath.realpath(
      \ s:tmp_path . s:Filepath.separator() .
      \ 'tmp.puml')

let s:update_viewer_script_path = s:Filepath.realpath(
      \ s:base_path . s:Filepath.separator() .
      \ 'script' .  s:Filepath.separator() .
      \ 'update-viewer' . (s:is_win ? '.cmd' : '.sh'))

let s:watched_bufnr = 0

function! plantuml_previewer#start() "{{{
  if !executable('java')
    echoerr 'require java command'
    return
  endif
  let viewer_path = s:viewer_path()
  if !isdirectory(viewer_path) && !filereadable(viewer_path)
    call plantuml_previewer#copy_viewer_directory()
  endif
  call delete(s:viewer_tmp_puml_path())
  call delete(s:viewer_tmp_svg_path())
  let s:watched_bufnr = bufnr('%')
  call plantuml_previewer#refresh(s:watched_bufnr)
  augroup plantuml_previewer
    autocmd!
    autocmd BufWritePost * if bufnr('%') == s:watched_bufnr | call plantuml_previewer#refresh(s:watched_bufnr) | endif
  augroup END
endfunction "}}}

function! plantuml_previewer#open() "{{{
  if !exists('*OpenBrowser')
    echoerr 'require open-browser.vim'
    return
  endif
  call plantuml_previewer#start()
  call OpenBrowser(s:viewer_html_path())
endfunction }}}

function! plantuml_previewer#stop() "{{{
  augroup plantuml_previewer
    autocmd!
  augroup END
endfunction "}}}

function! s:is_zero(val) "{{{
  return type(a:val) == type(0) && a:val == 0
endfunction "}}}

function! plantuml_previewer#copy_viewer_directory() "{{{
  let viewer_path = s:viewer_path()
  let default_viewer_path = plantuml_previewer#default_viewer_path()
  if viewer_path != default_viewer_path
    if s:is_win
      call system('xcopy ' . default_viewer_path . ' ' . viewer_path . ' /O /X /E /H /K')
    else
      call system('cp -r ' . default_viewer_path . ' ' . viewer_path)
    endif
    echom 'copy ' . default_viewer_path . ' -> ' . viewer_path
  endif
endfunction "}}}

function! plantuml_previewer#default_viewer_path() "{{{
  return s:Filepath.realpath(s:base_path . s:Filepath.separator() . 'viewer')
endfunction "}}}

function! s:viewer_path() "{{{
  let path = get(g:, 'plantuml_previewer#viewer_path', 0)
  return s:is_zero(path) ? plantuml_previewer#default_viewer_path() : path
endfunction "}}}

function! s:viewer_tmp_puml_path() "{{{
  return s:Filepath.realpath(s:viewer_path() . s:Filepath.separator() . 'tmp.puml')
endfunction "}}}

function! s:viewer_tmp_svg_path() "{{{
  return s:Filepath.realpath(s:viewer_path() . s:Filepath.separator() . 'tmp.svg')
endfunction "}}}

function! s:viewer_tmp_js_path() "{{{
  return s:Filepath.realpath(s:viewer_path() . s:Filepath.separator() . 'tmp.js')
endfunction "}}}

function! s:viewer_html_path() "{{{
  return s:Filepath.realpath(s:viewer_path() . s:Filepath.separator() . 'index.html')
endfunction "}}}

function! s:jar_path() "{{{
  let path = get(g:, 'plantuml_previewer#plantuml_jar_path', 0)
  return s:is_zero(path) ? s:default_jar_path : path
endfunction "}}}

function! s:save_format() "{{{
  return get(g:, 'plantuml_previewer#save_format', 'png')
endfunction "}}}

function! s:ext_to_fmt(ext) "{{{
  return a:ext == 'tex' ? 'latex' : a:ext
endfunction "}}}

function! s:fmt_to_ext(fmt) "{{{
  return a:fmt == 'latex' ? 'tex' : a:fmt
endfunction "}}}

function! s:run_in_background(cmd) "{{{
  if s:Job.is_available()
    call s:Job.start(a:cmd)
  else
    try
      call s:Process.execute(a:cmd, {
            \ 'background': 1,
            \})
    catch
      call s:Process.execute(a:cmd)
    endtry
  endif
endfunction "}}}

function! plantuml_previewer#refresh(bufnr) "{{{
  let puml_src_path = s:Filepath.abspath(bufname(a:bufnr))
  let puml_filename = fnamemodify(puml_src_path, ':t:r')
  let image_type = 'svg'
  let image_ext = s:fmt_to_ext(image_type)
  let output_dir_path = s:tmp_path
  let output_path = output_dir_path . s:Filepath.separator() . puml_filename . '.' . image_ext
  let finial_path = s:viewer_path() . s:Filepath.separator() . 'tmp.' . image_ext
  let cmd = [
       \ s:update_viewer_script_path,
       \ s:jar_path(),
       \ puml_src_path,
       \ output_dir_path,
       \ output_path,
       \ finial_path,
       \ image_type,
       \ localtime(),
       \ s:viewer_tmp_js_path(),
       \ ]
  call s:run_in_background(cmd)
endfunction "}}}

function! plantuml_previewer#save_as(...) "{{{
  if !executable('java')
    echoerr 'require java command'
    return
  endif

  let save_path = get(a:000, 0, 0)
  let image_type = get(a:000, 1, 0)
  if s:is_zero(save_path)
    let source_name = s:Filepath.abspath(expand('%:t:r'))
    let save_path = printf("%s.%s", source_name, s:fmt_to_ext(s:save_format()))
  else
    let save_path = s:Filepath.abspath(save_path)
  endif
  if s:is_zero(image_type)
    let ext = fnamemodify(save_path, ':e')
    let image_type = ext == '' ? s:save_format() : s:ext_to_fmt(ext)
  endif

  let puml_src_path = s:Filepath.abspath(bufname('%'))
  let puml_filename = fnamemodify(puml_src_path, ':t:r')
  let image_ext = s:fmt_to_ext(image_type)
  let output_dir_path = s:tmp_path
  let output_path = output_dir_path . s:Filepath.separator() . puml_filename . '.' . image_ext
  call mkdir(fnamemodify(save_path, ':p:h'), 'p')
  let cmd = [
        \ s:save_as_script_path,
        \ s:jar_path(),
        \ puml_src_path,
        \ output_dir_path,
        \ output_path,
        \ save_path,
        \ image_type,
        \ ]
  call s:run_in_background(cmd)
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo

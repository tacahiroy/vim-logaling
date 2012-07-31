" plugin/loga.vim
" A logaling-command wrapper
" Maintainer: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: The MIT License
" Version: 0.4.8-017
" supported logaling-command version 0.1.7

if exists('g:loaded_loga') || &cp
  finish
endif
let g:loaded_loga = 1

let s:saved_cpo = &cpo
set cpo&vim

let s:loga = loga#new()

let s:loga_tasks = ['add',
                  \ 'config',
                  \ 'delete',
                  \ 'help',
                  \ 'import',
                  \ 'list',
                  \ 'lookup',
                  \ 'new',
                  \ 'register',
                  \ 'show',
                  \ 'unregister',
                  \ 'update',
                  \ 'version']

let s:gflags = ['-g', '-S', '-T', '-h',
              \ '--glossary=', '--source-language=',
              \ '--target-language=', '--logaling-home=']

" Completion related " {{{
function! s:is_task_given(line)
  let parts = split(a:line, '\s\+')
  return (0 <= index(s:loga_tasks, get(parts, 1, '')))
endfunction

function! s:get_source_terms(word)
  " TODO: implement caching
  let res = ''
  let err = 0

  if a:word == ''
    let [res, err] = s:loga.Run('show')
  else
    let [res, err] = s:loga.Run('lookup', a:word)
  endif

  let terms = []
  for e in split(res, '\n')
    let term = substitute(e, '\m\s\{11,}[^\t]\+\(\t#\s.*\)\?', '', '')
    let term = substitute(term, '\m^\s\s', '', '')
    call add(terms, '"'.term.'"')
  endfor
  return terms
endfunction

function! s:get_target_terms(word)
  " TODO: implement caching
  let [res, err] = s:loga.Run('lookup', a:word)
  let terms = []
  for e in split(res, '\n')
    let term = substitute(e, '\m^\s\s.\+\s\{11,}\([^\t]\+\)\(\t#\s.*\)\?$', '\1', '')
    call add(terms, '"'.term.'"')
  endfor
  return terms
endfunction

function! s:get_tasks(L)
  if empty(a:L)
    return s:loga_tasks
  else
    return filter(copy(s:loga_tasks), "v:val =~# '^'.a:L")
  endif
endfunction

" complete functions " {{{
function! s:complete_loga(A, L, P)
  if s:is_task_given(a:A)
    " TODO: each task completion
  else
    return s:get_tasks(a:A)
  endif
endfunction

function! s:complete_show(A, L, P)
  " only global flags
endfunction

function! s:complete_help(A, L, P)
  return s:get_tasks(a:A)
endfunction

function! s:complete_lookup(A, L, P)
  if len(a:L) != a:P
    return
  endif

  let level = len(split(substitute(a:L, '^Loga\s\+', 'Loga', ''), '\s\+'))
  let alead = substitute(a:A, '^[\"'']\([^\"'']*\)$', '"\1"', '')

  if level == 1
    " :Llookup
    " :Loga lookup
    return s:get_source_terms(alead)
  elseif 2 <= level
    " TODO: global flags completion
  endif
endfunction

function! s:complete_delete(A, L, P)
  if len(a:L) != a:P
    return
  endif

  let level = len(split(substitute(a:L, '^Loga\s\+', 'Loga', ''), '\s\+'))
  let alead = substitute(a:A, '^["'']\([^"'']*\)$', '"\1"', '')

  let is_completed = (a:L =~# '\s$')

  if level == 1 || (level == 2 && !is_completed)
    " :Llookup
    " :Loga lookup
    return s:get_source_terms(alead)
  elseif level == 2
    " TODO: target term completion
  elseif 3 <= level
    " TODO: global flags completion
  endif
endfunction

function! s:complete_update(A, L, P)
  return s:complete_delete(a:A, a:L, a:P)
endfunction

function! s:complete_buffer_exec(A, L, P)
  return ['--test']
endfunction
" }}}
" }}}

" commands " {{{
command! -nargs=+ -complete=customlist,s:complete_loga
      \ Loga call s:loga.Loga(<f-args>)

command! -nargs=+ Ladd call s:loga.Add(<f-args>)
command! -nargs=+ -complete=customlist,s:complete_delete
      \ Ldelete call s:loga.Delete(<f-args>)

command! -nargs=1 -complete=customlist,s:complete_help
      \ Lhelp call s:loga.Help(<f-args>)

command! -nargs=+ -complete=customlist,s:complete_lookup
      \ Llookup call s:loga.Lookup(<f-args>)
command! -nargs=+ -complete=customlist,s:complete_lookup
      \ Llookupd call s:loga.Lookup('--dict', <f-args>)

command! -nargs=* -complete=customlist,s:complete_show
      \ Lshow call s:loga.Show(<f-args>)

command! -nargs=+ -complete=customlist,s:complete_delete
      \ Lupdate call s:loga.Update(<f-args>)

command! -range LBopen <line1>,<line2>call s:loga.buffer.open(1)

command! -nargs=0 LenableAutoLookUp  call <SID>enable_auto_lookup()
command! -nargs=0 LdisableAutoLookUp call <SID>disable_auto_lookup()
command! -nargs=0 LtoggleAutoLookUp  call <SID>toggle_auto_lookup()
" }}}

" mappings " {{{
nnoremap <silent> <Plug>(loga-lookup) :<C-u>execute 'Llookup ' . expand("<cword>")<Cr>
if !hasmapto('<Plug>(loga-lookup)', 'n')
  silent! nmap <unique> <Leader>f <Plug>(loga-lookup)
endif

vnoremap <silent> <Plug>(loga-lookup) :<C-u>execute 'Llookup ' . <SID>get_visualed()<Cr>
if !hasmapto('<Plug>(loga-lookup)', 'v')
  silent! vmap <unique> <Leader>f <Plug>(loga-lookup)
endif

function! s:get_visualed()
  let regun = getreg('"')
  try
    normal! gvy
    return getreg('"')
  finally
    call setreg('"', regun)
  endtry
endfunction
" }}}

augroup Loga
  autocmd!

  autocmd CursorHold * call s:loga.AutoLookup(expand('<cword>'))

  execute 'inoremap <silent> <Plug>(loga-insert-delimiter) ' . g:loga_delimiter
  if !hasmapto('<Plug>(loga-insert-delimiter)', 'i')
    autocmd FileType logaling
          \ silent! imap <unique> <Leader>v <Plug>(loga-insert-delimiter)
  endif

  autocmd FileType logaling
        \ command! -nargs=? -buffer -range -complete=customlist,s:complete_buffer_exec
        \ LBadd    <line1>,<line2>:call s:loga.buffer.execute('add', <f-args>)
  autocmd FileType logaling
        \ command! -nargs=? -buffer -range -complete=customlist,s:complete_buffer_exec
        \ LBupdate <line1>,<line2>:call s:loga.buffer.execute('update', <f-args>)
  autocmd FileType logaling
        \ command! -nargs=? -buffer -range -complete=customlist,s:complete_buffer_exec
        \ LBdelete <line1>,<line2>:call s:loga.buffer.execute('delete', <f-args>)
augroup END

let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:

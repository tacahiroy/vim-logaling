" loga.vim - A logaling-command wrapper
" Maintainer: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: MIT License
" Version: 0.4.0
" supported logaling-command version 0.1.2

if exists('g:loaded_loga') || &cp
  finish
endif
let g:loaded_loga = 1

let s:V = vital#of('loga').import('Data.List')


let s:loga_executable = get(g:, 'loga_executable', 'loga')

" behaviour settings
let g:loga_result_window_hsplit = get(g:, 'loga_result_window_hsplit', 1)
let g:loga_result_window_size   = get(g:, 'loga_result_window_size', 5)

" auto lookup
let s:loga_enable_auto_lookup = get(g:, 'loga_enable_auto_lookup', 0)

let s:loga_delimiter = get(g:, 'loga_delimiter', '(//)')

" Utilities "{{{
function! s:debug(...)
  let g:debug = get(g:, 'debug', [])
  call add(g:debug, a:000)
endfunction
"}}}

function! s:enable_auto_lookup()
  let s:loga_enable_auto_lookup = 1
endfunction
function! s:disable_auto_lookup()
  let s:loga_enable_auto_lookup = 0
endfunction
function! s:toggle_auto_lookup()
  let s:loga_enable_auto_lookup = !s:loga_enable_auto_lookup
endfunction

"""
" argument parser
" @arg: opts(List) - command option like this ['-i', '-t', 'TITLE']
" @return: List[[]]
function! s:parse_argument(opts)
  let i = 0
  let args = []
  let opts = a:opts

  while i < len(opts)
    let name = get(opts, i, '')
    let rval = get(opts, i + 1, '')
    let value = (s:is_options_value(rval) ? rval : '')

    call add(args, [name, value])

    let i += (s:is_options_value(rval) ? 2 : 1)
  endwhile

  return args
endfunction

function! s:output(data)
  if empty(a:data)
    return
  endif

  let cur_bufnr = bufnr('%')

  call s:loga.buffer.open(1)
  call s:loga.buffer.focus()

  silent 0 put = a:data

  call cursor(1, 1)
  execute bufwinnr(cur_bufnr). 'wincmd w'

  redraw!
endfunction


"""
" returns whether v is an option(e.g. '-s' of '-s ja') or not
" @arg: v(string)
" @return: 1 if v is value, 0 if not
function! s:is_options_value(v)
  return a:v !~# '^-'
endfunction

" objects " {{{
let s:loga = {'executable': '',
            \ 'subcommand': '',
            \ 'lookupword': '',
            \ 'args': [],
            \ 'buffer': {},
            \ }

let s:loga.buffer = {'DELIMITER': s:loga_delimiter,
                   \ 'NAME': '[logaling]',
                   \ 'sp': '',
                   \ 'number': -1,
                   \ 'filter': {}}

let s:loga.buffer.sp = g:loga_result_window_size .
                     \ (g:loga_result_window_hsplit ? 'split' : 'vsplit')

function! s:loga.buffer.exists() dict
  return bufexists(self.number)
endfunction

function! s:loga.buffer.is_open() dict
  return bufwinnr(self.number) != -1
endfunction

function! s:loga.buffer.open(clear) dict
  let cur_bufwinnr = bufwinnr('%')

  if !self.is_open()
    silent execute self.sp
    silent edit `=self.NAME`

    let self.number = bufnr('%')

    setlocal buftype=nofile syntax=loga bufhidden=hide
    setlocal filetype=logaing
    setlocal noswapfile nobuflisted
    call s:loga.buffer.enable_syntax()

    execute cur_bufwinnr . 'wincmd w'
  endif

  if a:clear
    call self.clear(cur_bufwinnr)
  endif
endfunction

function! s:loga.buffer.clear(bufwinnr) dict
  call self.focus()
  execute '%delete _'
  execute a:bufwinnr . 'wincmd w'
endfunction

function! s:loga.buffer.focus() dict
  if self.is_open()
    let mybufwinnr = bufwinnr(self.number)
    if mybufwinnr != bufwinnr('%')
      execute mybufwinnr . 'wincmd w'
    endif
  endif
endfunction

function! s:loga.buffer.execute(subcmd, ...) dict
  let is_test = (0 < a:0 && a:1 == '--test' ? 1 : 0)
  let line = line('.')

  " range is temporary unavailabled
  for lnum in range(line, line)
    let line = get(getbufline(self.number, lnum), 0)

    if empty(line)
      continue
    endif

    if has_key(self.filter, a:subcmd)
      let line = self.filter[a:subcmd](line)
    endif

    let line = substitute(line, '^\s\+', '', '')
    let line = substitute(line, '\(\s\{11,}\|\t#\)', self.DELIMITER, 'g')

    let args = map(split(line, self.DELIMITER), 'escape(v:val, "\\ ")')

    if is_test
      echohl Statement
      echomsg a:subcmd . ' ' . join(args, ' ')
      echohl None

      continue
    endif

    let [res, err] = s:loga.Run(a:subcmd, args)
  endfor
endfunction

function! s:loga.buffer.filter.delete(line)
  " remove NOTE
  return substitute(a:line, '\t#.*$', '', '')
endfunction

" Highlight " {{{
function! s:loga.buffer.enable_syntax()
  if exists('g:syntax_on')
    syntax case ignore
    syntax match LogaGlossary '\t\zs(.\+)$'
    syntax match LogaTargetTerm '\s\{11,}\zs[^#]\+\ze\(\t#\)\?'
    syntax match LogaNote '#\s[^#]\+$'
    execute 'syntax match LogaDelimiter "' . s:loga_delimiter . '"'
    execute 'syntax match LogaLookupWord "' . s:loga.lookupword . '"'

    highlight link LogaGlossary Type
    highlight link LogaTargetTerm Function
    highlight link LogaNote Comment
    highlight link LogaDelimiter Delimiter
    highlight LogaLookupWord gui=bold ctermbg=11
  endif
endf
" }}}


" methods
function! s:loga.initialize(subcmd, args) dict
  call self.clear()

  let self.executable = s:loga_executable
  let self.subcommand = a:subcmd
  if a:subcmd == 'lookup'
    call s:debug(get(a:args, 0, ''))
    let self.lookupword = get(a:args, 0, '')[0]
  endif

  if 0 < len(a:args)
    let self.args = a:args
  endif
endfunction

function! s:loga.build_command() dict
  let cmd = printf('%s %s', self.executable, self.subcommand)
  let args = join(s:V.flatten(self.args), ' ')

  return cmd . ' ' . args
endfunction

function! s:loga.execute() dict
  let cmd = self.build_command()
  let result = system(cmd)
  return [result, self.is_error(result)]
endfunction

function! s:loga.is_error(result)
  return a:result =~# '"\(\w\+\)" was called incorrectly\. Call as "loga \1'
endfunction

function! s:loga.clear() dict
  let self.executable = ''
  let self.subcommand = ''
  let self.lookupword = ''
  let self.args = []
endfunction
" }}}

" commands "{{{
function! s:loga.Run(...) dict abort
  let subcmd = get(a:000, 0)

  call self.initialize(subcmd, s:parse_argument(s:V.flatten(a:000[1:])))
  return self.execute()
endfunction

" loga
function! s:loga.Loga(task, ...) dict abort
  let [res, err] = self.Run(a:task, a:000)
  call s:output(res)
endfunction

" loga add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]
function! s:loga.Add(src, target, ...) dict abort
  let [res, err] = self.Run('add', a:src, a:target, a:000)
  call s:output(res)
endfunction

" loga delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]
function! s:loga.Delete(term, ...) dict abort
  let [res, err] = self.Run('delete', a:term, a:000)
  call s:output(res)
endfunction

" loga help [TASK]
function! s:loga.Help(command) dict abort
  let [res, err] = self.Run('help', a:command)
  call s:output(res)
endfunction

" loga lookup [TERM]
function! s:loga.Lookup(word, ...) dict abort
  let [res, err] = self.Run('lookup', a:word, a:000)
  call s:output(res)
endfunction

function! s:loga.AutoLookup(term) dict abort
  " do not lookup yourself
  if s:loga.buffer.number == bufnr('%')
    return
  endif

  if s:loga_enable_auto_lookup && !empty(a:term)
    let [res, err] = self.Run('lookup', a:term)
    call s:output(res)
  endif
endfunction

" loga show
function! s:loga.Show(...) dict abort
  let [res, err] = self.Run('show', a:000)
  call s:output(res)
endfunction

" loga update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]
function! s:loga.Update(opt) dict abort
  let [res, err] = self.Run('update', a:opt)
  call s:output(res)
endfunction
"}}}

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

vnoremap <silent> <Plug>(loga-lookup) :<C-u>execute 'Llookup ' . <SID>get_visual_strs()<Cr>
if !hasmapto('<Plug>(loga-lookup)', 'v')
  silent! vmap <unique> <Leader>f <Plug>(loga-lookup)
endif

function! s:get_visual_strs()
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

  execute 'inoremap <silent> <Plug>(loga-insert-delimiter) ' . s:loga_delimiter
  if !hasmapto('<Plug>(loga-insert-delimiter)', 'i')
    autocmd FileType logaling
          \ silent! imap <unique> <Leader>v <Plug>(loga-insert-delimiter)
  endif

  autocmd FileType logaing
        \ command! -nargs=? -buffer -complete=customlist,s:complete_buffer_exec
        \ LBadd    call s:loga.buffer.execute('add', <f-args>)
  autocmd FileType logaing
        \ command! -nargs=? -buffer -complete=customlist,s:complete_buffer_exec
        \ LBupdate call s:loga.buffer.execute('update', <f-args>)
  autocmd FileType logaing
        \ command! -nargs=? -buffer -complete=customlist,s:complete_buffer_exec
        \ LBdelete call s:loga.buffer.execute('delete', <f-args>)
augroup END

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:

" loga.vim - A logaling-command wrapper
" Maintainer: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: MIT License
" Version: 0.2.2
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

  setlocal buftype=nofile syntax=loga bufhidden=hide
  setlocal filetype=loga
  setlocal noswapfile nobuflisted
  call s:enable_syntax()

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
            \ 'args': [],
            \ 'buffer': {},
            \ }

let s:loga.buffer = {'DELIMITER': get(g:, 'loga_delimiter', '//'),
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

function! s:loga.buffer.execute(subcmd) range dict
  for lnum in range(a:firstline, a:lastline)
    let line = get(getbufline(self.number, lnum), 0)

    if empty(line)
      continue
    endif

    if has_key(self.filter, a:subcmd)
      let line = self.filter[a:subcmd](line)
    endif

    let line = substitute(line, '\s\{2,}', '  ', 'g')
    let line = substitute(line, '# \ze.\+$', '  ', '')

    let args = split(line, '\s\{2,}')
    let [res, err] = s:loga.Run(a:subcmd, args)
  endfor
endfunction

function! s:loga.buffer.filter.delete(line)
  " remove NOTE
  return substitute(a:line, '\s\+#.*$', '', '')
endfunction

command! -range LBopen   <line1>,<line2>call s:loga.buffer.open(1)


" methods
function! s:loga.initialize(subcmd, args) dict
  call self.clear()

  let self.executable = s:loga_executable
  let self.subcommand = a:subcmd

  if 0 < len(a:args)
    let self.args = a:args
  endif
endfunction

function! s:loga.build_command() dict
  let cmd = printf('%s %s', self.executable, self.subcommand)
  let args = join(s:V.flatten(self.args), ' ')

  call s:debug(cmd . ' ' . args)
  return cmd . ' ' . args
endfunction

function! s:loga.execute() dict
  let cmd = self.build_command()
  let result = substitute(system(cmd), '\t# ', '  # ', 'g')
  return [result, self.is_error(result)]
endfunction

function! s:loga.is_error(result)
  return a:result =~# '"\(\w\+\)" was called incorrectly\. Call as "loga \1'
endfunction

function! s:loga.clear() dict
  let self.executable = ''
  let self.subcommand = ''
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

" Highlight " {{{
function! s:enable_syntax()
  if exists('g:syntax_on')
    syntax match LogaGlossary '\t\zs(.\+)$'
    syntax match LogaTargetTerm '\s\{11,}\zs[^#]\+\ze\s\s#'
    syntax match LogaNote '#\s[^#]\+$'

    highlight link LogaGlossary Type
    highlight link LogaTargetTerm Constant
    highlight link LogaNote Comment
  endif
endf
" }}}

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

command! -nargs=0 LenableAutoLookUp  call <SID>enable_auto_lookup()
command! -nargs=0 LdisableAutoLookUp call <SID>disable_auto_lookup()
command! -nargs=0 LtoggleAutoLookUp  call <SID>toggle_auto_lookup()
" }}}

" mappings " {{{
nnoremap <silent> <Plug>(loga-lookup) :<C-u>execute "Llookup ". expand("<cword>")<Cr>

if !hasmapto("<Plug>(loga-lookup)")
  silent! map <unique> <Leader>f <Plug>(loga-lookup)
endif
" }}}

augroup Loga
  autocmd!
  autocmd CursorHold * call s:loga.AutoLookup(expand("<cword>"))

  autocmd FileType loga command! -range -nargs=0 -buffer
        \ LBadd    <line1>,<line2>call s:loga.buffer.execute('add')
  autocmd FileType loga command! -range -nargs=0 -buffer
        \ LBupdate <line1>,<line2>call s:loga.buffer.execute('update')
  autocmd FileType loga command! -range -nargs=0 -buffer
        \ LBdelete <line1>,<line2>call s:loga.buffer.execute('delete')
augroup END

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:

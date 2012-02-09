" loga.vim - A logaling-command wrapper
" Maintainer: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: MIT License
" Version: 0.2.0
" supported logaling-command version 0.1.2

if exists("g:loaded_loga") || &cp
  finish
endif
let g:loaded_loga = 1

let s:V = vital#of("loga").import("Data.List")


let g:loga_executable = get(g:, "loga_executable", "loga")

" behaviour settings
let g:loga_result_window_hsplit = get(g:, "loga_result_window_hsplit", 1)
let g:loga_result_window_size   = get(g:, "loga_result_window_size", 5)

" auto lookup
let s:loga_enable_auto_lookup = get(g:, "loga_enable_auto_lookup", 0)

" Utilities "{{{
"""
" like Ruby's String#gsub
function! s:gsub(s, p, r) abort
  return substitute(a:s, "\v\C".a:p, a:r, "g")
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
" @arg: opts(List) - command option like this ["-i", "-t", "TITLE"]
" @return: List[[]]
function! s:parse_argument(opts)
  let i = 0
  let args = []
  let opts = a:opts

  while i < len(opts)
    let name = get(opts, i, "")
    let rval = get(opts, i + 1, "")
    let value = (s:is_options_value(rval) ? rval : "")

    call add(args, [name, value])

    let i += (s:is_options_value(rval) ? 2 : 1)
  endwhile

  return args
endfunction

function! s:output(data)
  if empty(a:data)
    return
  endif

  let cur_bufnr = bufnr("%")

  if !s:output_buffer.is_open()
    let split = (g:loga_result_window_hsplit ? "split" : "vsplit")
    silent execute g:loga_result_window_size . split
    silent edit `=s:output_buffer.BUFNAME`

    let s:output_buffer.bufnr = bufnr("%")
  endif

  let bufwinnr = bufwinnr(s:output_buffer.bufnr)

  execute bufwinnr . "wincmd w"
  silent execute "%delete _"

  setlocal buftype=nofile syntax=loga bufhidden=hide
  setlocal noswapfile nobuflisted
  call s:enable_syntax()

  silent 0 put = a:data

  call cursor(1, 1)
  execute bufwinnr(cur_bufnr). "wincmd w"

  redraw!
endfunction

"""
" judge v is an option(e.g. "-s" of "-s ja") or
" option's value(e.g. "ja" of "-s ja")
" @arg: v(string)
" @return: 1 if v is value, 0 if not
function! s:is_options_value(v)
  return a:v !~# "^-"
endfunction

" objects
let s:output_buffer = {"bufnr": -1,
      \ "BUFNAME": "[loga output]"}

function! s:output_buffer.exists() dict
  return bufexists(self.bufnr)
endfunction

function! s:output_buffer.is_open() dict
  return bufwinnr(self.bufnr) != -1
endfunction

" s:loga " {{{
let s:loga = {"executable": "",
            \ "subcommand": "",
            \ "args": [],
            \ }

" methods
function! s:loga.initialize(subcmd, args) dict
  call self.clear()

  let self.executable = g:loga_executable
  let self.subcommand = a:subcmd

  if 0 < len(a:args)
    let self.args = a:args
  endif
endfunction

function! s:loga.build_command() dict
  let cmd = printf("%s %s", self.executable, self.subcommand)
  let arg = ""

  for [k, v] in self.args
    let arg .= k . " " . v
  endfor
  return cmd . " " . arg
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
  let self.executable = ""
  let self.subcommand = ""
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
function! s:loga.Add(opt) dict abort
  let [res, err] = self.Run("add", a:opt)
  call s:output(res)
endfunction

" loga delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]
function! s:loga.Delete(opt) dict abort
  let [res, err] = self.Run("delete", a:opt)
  call s:output(res)
endfunction

" loga help [TASK]
function! s:loga.Help(command) dict abort
  let [res, err] = self.Run("help", a:command)
  call s:output(res)
endfunction

" loga lookup [TERM]
function! s:loga.Lookup(word, ...) dict abort
  let [res, err] = self.Run("lookup", a:word, a:000)
  call s:output(res)
endfunction
function! s:loga.AutoLookup(term) dict abort
  " do not lookup yourself
  if s:output_buffer.bufnr == bufnr("%")
    return
  endif

  if s:loga_enable_auto_lookup && !empty(a:term)
    let [res, err] = self.Run("lookup", a:term)
    call s:output(res)
  endif
endfunction

" loga show
function! s:loga.Show(...) dict abort
  let [res, err] = self.Run("show", a:000)
  call s:output(res)
endfunction

" loga update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]
function! s:loga.Update(opt) dict abort
  let [res, err] = self.Run("update", a:opt)
  call s:output(res)
endfunction
"}}}

" Highlight " {{{
function! s:enable_syntax()
  syntax match LogaTargetTerm '\s\{11,}\zs[^\t]\+\ze'
  syntax match LogaGlossary '\t\zs(.\+)$'

  highlight link LogaTargetTerm Constant
  highlight link LogaGlossary Type
endf
" }}}

let s:loga_tasks = ["add",
                  \ "config",
                  \ "delete",
                  \ "help",
                  \ "import",
                  \ "list",
                  \ "lookup",
                  \ "new",
                  \ "register",
                  \ "show",
                  \ "unregister",
                  \ "update",
                  \ "version"]

let s:gflags = ["-g", "-S", "-T", "-h",
              \ "--glossary=", "--source-language=",
              \ "--target-language=", "--logaling-home="]

function! s:is_task_given(line)
  let parts = split(a:line, '\s\+')
  return (0 <= index(s:loga_tasks, get(parts, 1, "")))
endfunction

function! s:get_source_terms(word)
  " TODO: implement caching
  let res = ""
  let err = 0

  if a:word == ""
    let [res, err] = s:loga.Run("show")
  else
    let [res, err] = s:loga.Run("lookup", a:word)
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
  let [res, err] = s:loga.Run("lookup", a:word)
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
  else
    return s:get_tasks(a:A)
  endif
endfunction

function! s:complete_show(A, L, P)

endfunction

function! s:complete_help(A, L, P)
  return s:get_tasks(a:A)
endfunction

function! s:complete_lookup(A, L, P)
  let level = len(split(substitute(a:L, '^Loga\s\+', 'Loga', ''), '\s\+'))
  let alead = substitute(a:A, '^[\"'']\([^\"'']*\)$', '"\1"', '')

  if level == 1 || len(a:L) == a:P
    " :Llookup
    " :Loga lookup
    return s:get_source_terms(alead)
  elseif level == 2
    " :Llookup "source"
    " :Loga lookup "source"
    " TODO: global flags completion
  endif
endfunction
" }}}

" commands " {{{
command! -nargs=+ -complete=customlist,s:complete_loga
      \ Loga call s:loga.Loga(<f-args>)

command! -nargs=+ Ladd    call s:loga.Add(<f-args>)
command! -nargs=+ Ldelete call s:loga.Delete(<f-args>)

command! -nargs=1 -complete=customlist,s:complete_help
      \ Lhelp call s:loga.Help(<f-args>)

command! -nargs=+ -complete=customlist,s:complete_lookup
      \ Llookup call s:loga.Lookup(<f-args>)

command! -nargs=* -complete=customlist,s:complete_show
      \ Lshow call s:loga.Show(<f-args>)

command! -nargs=+ Lupdate call s:loga.Update(<f-args>)

command! -nargs=0 LenableAutoLookUp  call <SID>enable_auto_lookup()
command! -nargs=0 LdisableAutoLookUp call <SID>disable_auto_lookup()
command! -nargs=0 LtoggleAutoLookUp  call <SID>toggle_auto_lookup()
" }}}

" mappings " {{{
nnoremap <silent> <Plug>(loga-lookup) :<C-u>execute "Llookup " . expand("<cword>")<Cr>

if !hasmapto("<Plug>(loga-lookup)")
  silent! map <unique> <Leader>f <Plug>(loga-lookup)
endif
" }}}

augroup Loga
  autocmd! CursorHold * call s:loga.AutoLookup(expand("<cword>"))
augroup END

"__END__
" vim:set ft=vim ts=2 sw=2 sts=2:

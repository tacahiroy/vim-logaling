" loga.vim - A logaling-command wrapper
" Maintainer: tacahiroy <tacahiroy```AT```gmail.com>
" License: MIT License
" Version: 0.2.0

if exists("g:loaded_loga") || &cp
  finish
endif
let g:loaded_loga = 1

let g:loga_executable = get(g:, "loga_executable", "loga")

" behaviour settings
let g:loga_result_window_hsplit = get(g:, "loga_result_window_hsplit", 1)
let g:loga_result_window_size   = get(g:, "loga_result_window_size", 5)

" auto lookup
let g:loga_enable_auto_lookup = get(g:, "loga_enable_auto_lookup", 0)
let g:loga_auto_lookup_line   = get(g:, "loga_auto_lookup_line", 0)

" Utilities "{{{
"""
" like Ruby's String#gsub
function! s:gsub(s, p, r) abort
  return substitute(a:s, "\v\C".a:p, a:r, "g")
endfunction
"}}}

"""
" argument parser
" @arg: opt(string) - command option like this "-i -t TITLE"
" @return: List[[]]
function! s:parse_argument(opt)
  let opts = split(s:gsub(a:opt, "\s\s\+", " "), " ")

  let i = 0
  let args = []

  while i < len(opts)
    let name = get(opts, i, "")
    let rval = get(opts, i + 1, "")
    let value = (s:is_options_value(rval) ? rval : "")

    call add(args, [name, value])

    let i += (s:is_options_value(rval) ? 2 : 1)
  endwhile

  return args
endfunction

"""
" judge v is option(e.g. '-s' of '-s ja') or
" option's value(e.g. 'ja' of '-s ja')
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
  return system(cmd)
endfunction

function! s:loga.output(data)
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

  setlocal buftype=nofile syntax=none bufhidden=hide
  setlocal noswapfile nobuflisted

  silent 0 put = a:data

  call cursor(1, 1)
  execute bufwinnr(cur_bufnr). "wincmd w"

  redraw!
endfunction

function! s:loga.clear() dict
  let self.executable = ""
  let self.subcommand = ""
  let self.args = []
endfunction
" }}}

" commands "{{{
command! -nargs=+ Loga call <SID>Loga(<q-args>)
function! s:Loga(...) abort
  let args = a:000
  let subcmd = get(args, 0)
  let arg = get(args, 1, "")


  call s:loga.initialize(subcmd, s:parse_argument(arg))
  let res = s:loga.execute()
  if 0 < len(res)
    call s:loga.output(res)
  else
    echo "No results"
  endif
endfunction

" loga add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]
" loga delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]
" loga help [TASK]
command! -nargs=1 Lhelp call <SID>Help(<q-args>)
function! s:Help(command) abort
  call s:Loga("help", a:command)
endfunction

" loga list
command! -nargs=* Llist call <SID>List()
function! s:List() abort
  call s:Loga("list")
endfunction

" loga lookup [TERM]
command! -nargs=+ Llookup call <SID>Lookup(<q-args>)
function! s:Lookup(opt) abort
  call s:Loga("lookup", a:opt)
endfunction

" loga show
command! -nargs=* Lshow call <SID>Show(<q-args>)
function! s:Show(opt) abort
  call s:Loga("show", a:opt)
endfunction

" loga update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]
command! -nargs=+ Lupdate call <SID>Update(<q-args>)
function! s:Update(opt) abort
  call s:Loga("update", a:opt)
endfunction

"}}}

" mappings " {{{
nnoremap <silent> <Plug>(loga-lookup) :<C-u>execute "Llookup " . expand("<cword>")<Cr>

if !hasmapto("<Plug>(loga-lookup)")
  silent! map <unique> <Leader>f <Plug>(loga-lookup)
endif
" }}}

if g:loga_enable_auto_lookup
  if g:loga_auto_lookup_line
  else
    augroup Loga
      autocmd! CursorHold * call s:Lookup(expand("<cword>"))
    augroup END
  endif
endif

"__END__
" vim:set ft=vim ts=2 sw=2 sts=2:

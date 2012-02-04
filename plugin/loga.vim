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

  setlocal buftype=nofile syntax=none bufhidden=hide
  setlocal noswapfile nobuflisted

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
  return system(cmd)
endfunction

function! s:loga.clear() dict
  let self.executable = ""
  let self.subcommand = ""
  let self.args = []
endfunction
" }}}

" commands "{{{
function! s:loga.Run(...) dict abort
  let args = a:000
  let subcmd = get(args, 0)
  let arg = get(args, 1, "")

  call self.initialize(subcmd, s:parse_argument(arg))
  let res = self.execute()
  call s:output(res)
endfunction

" loga add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]
function! s:loga.Add(opt) dict abort
  call self.Run("add", a:opt)
endfunction

" loga delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]
function! s:loga.Delete(opt) dict abort
  call self.Run("delete", a:opt)
endfunction

" loga help [TASK]
function! s:loga.Help(command) dict abort
  call self.Run("help", a:command)
endfunction

" loga lookup [TERM]
function! s:loga.Lookup(opt) dict abort
  call self.Run("lookup", a:opt)
endfunction
function! s:loga.AutoLookup(term) dict abort
  if s:loga_enable_auto_lookup && !empty(a:term)
    call self.Run("lookup", a:term)
  endif
endfunction

" loga show
function! s:loga.Show(opt) dict abort
  call self.Run("show", a:opt)
endfunction

" loga update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]
function! s:loga.Update(opt) dict abort
  call self.Run("update", a:opt)
endfunction
"}}}

" Highlight " {{{
function! s:syntax()
  syntax match LogaGlossary '\t\zs(.\+)$'
  highlight link LogaGlossary Constant
  " if hlexists('Normal')
  "   sil! exe 'hi CtrlPLinePre '.( has("gui_running") ? 'gui' : 'cterm' ).'fg=bg'
  " en
endf

fu! s:highlight(pat, grp)
  cal clearmatches()
  if !empty(a:pat) && s:ispathitem()
    let pat = s:regexp ? substitute(a:pat, '\\\@<!\^', '^> \\zs', 'g') : a:pat
    " Match only filename
    if s:byfname
      let pat = substitute(pat, '\[\^\(.\{-}\)\]\\{-}', '[^\\/\1]\\{-}', 'g')
      let pat = substitute(pat, '$', '\\ze[^\\/]*$', 'g')
    en
    cal matchadd(a:grp, '\c'.pat)
    cal matchadd('CtrlPLinePre', '^>')
  en
endfunction
" }}}

" commands " {{{
command! -nargs=+ Loga    call <SID>loga.Run(<q-args>)
command! -nargs=+ Ladd    call <SID>loga.Add(<q-args>)
command! -nargs=+ Ldelete call <SID>loga.Delete(<q-args>)
command! -nargs=1 Lhelp   call <SID>loga.Help(<q-args>)
command! -nargs=+ Llookup call <SID>loga.Lookup(<q-args>)
command! -nargs=* Lshow   call <SID>loga.Show(<q-args>)
command! -nargs=+ Lupdate call <SID>loga.Update(<q-args>)

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

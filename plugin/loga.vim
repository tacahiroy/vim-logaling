" loga.vim - A logaling-command wrapper
" Maintainer: tacahiroy <tacahiroy```AT```gmail.com>
" License: MIT License
" Version: 0.2.2

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
function! s:loga.Run(subcmd, ...) dict abort
  call self.initialize(a:subcmd, s:parse_argument(s:V.flatten(a:000[:])))
  let res = self.execute()
  call s:output(res)
endfunction

" loga add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]
function! s:loga.Add(src, target, ...) dict abort
  call self.Run("add", a:src, a:target, a:000)
endfunction

" loga delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]
function! s:loga.Delete(src, target, ...) dict abort
  call self.Run("delete", a:src, a:target, a:000)
endfunction

" loga help [TASK]
function! s:loga.Help(command) dict abort
  call self.Run("help", a:command)
endfunction

" loga lookup [TERM]
function! s:loga.Lookup(word, ...) dict abort
  call self.Run("lookup", a:word, a:000)
endfunction
function! s:loga.AutoLookup(term) dict abort
  if s:output_buffer.bufnr == bufnr("%")
    return
  endif

  if s:loga_enable_auto_lookup && !empty(a:term)
    call self.Run("lookup", a:term)
  endif
endfunction

" loga show
function! s:loga.Show(...) dict abort
  call self.Run("show", a:000)
endfunction

" loga update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]
function! s:loga.Update(src, target, new_target, ...) dict abort
  call self.Run("update", a:src, a:target, a:new_target, a:000)
endfunction
"}}}

" Highlight " {{{
function! g:syntax()
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

function! s:complete_tasks(lead, cline, cpos)
  if empty(a:lead)
    return s:loga_tasks
  else
    return filter(copy(s:loga_tasks), "v:val =~# '^'.a:lead")
  endif
endfunction

" commands " {{{
command! -nargs=+ -complete=customlist,s:complete_tasks
      \ Loga call s:loga.Run(<f-args>)
command! -nargs=+ Ladd    call s:loga.Add(<f-args>)
command! -nargs=+ Ldelete call s:loga.Delete(<f-args>)
command! -nargs=1 Lhelp   call s:loga.Help(<f-args>)
command! -nargs=+ Llookup call s:loga.Lookup(<f-args>)
command! -nargs=* Lshow   call s:loga.Show(<f-args>)
command! -nargs=+ Lupdate call s:loga.Update(<f-args>)

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
  autocmd! CursorHold * call s:loga.AutoLookup(expand("<cword>"))
augroup END

"__END__
" vim:set ft=vim ts=2 sw=2 sts=2:

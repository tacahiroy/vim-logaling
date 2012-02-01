" loga.vim - A logaling-command wrapper
" Maintainer:   tacahiroy <tacahiroy```AT```gmail.com>
" License: MIT License " {{{
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
" 
" The above copyright notice and this permission notice shall be included in all
" copies or substantial portions of the Software.
" 
" The software is provided "as is", without warranty of any kind, express or
" implied, including but not limited to the warranties of merchantability,
" fitness for a particular purpose and noninfringement. In no event shall the
" authors or copyright holders be liable for any claim, damages or other
" liability, whether in an action of contract, tort or otherwise, arising from,
" out of or in connection with the software or the use or other dealings in the
" software. " }}}
" Version:      0.1.0

if exists('g:loaded_loga') || &cp
  finish
endif
let g:loaded_loga = 1

" vim-users.jp/2011/10/hack239/
let g:loga_executable = get(g:, "loga_executable", "loga")
" loga global options(-g, -S, -T, -h)
let g:loga_option = get(g:, "loga_option", {})
let g:loga_= get(g:, "loga_behave", {})

" Utilities "{{{
"""
" like Ruby's String#gsub
function! s:gsub(s, p, r) abort
  return substitute(a:s, "\v\C".a:p, a:r, "g")
endfunction
"}}}

"""
" command argument parser
" @arg: opt(string) - command option like this '-i -t TITLE'
function! s:parse_argument(opt)
  let opt = s:gsub(a:opt, "\s\s\+", " ")

  let opts = split(opt, " ")
  let i = 0
  let args = {}

  for [k, v] in items(g:loga_config)
    if v != ""
      let args[k] = v
    endif
  endfor

  while i < len(opts)
    let [o, v] = [get(opts, i), get(opts, i + 1)]
    let dic = {}
    let dic[o] = (s:is_options_value(v) ? v : "")

    " global config is overwritten if it's set
    call extend(args, dic)
    let i += (s:is_options_value(v) ? 2 : 1)
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

let s:loga = {"subcommand": "",
      \ "args": ""}

function! s:loga.build_args() dict
  let args = ""
  for [opt, val] in items(self.args)
    let args .= printf("%s %s ", opt, val)
  endfor
  return args
endfunction

function! s:loga.execute() dict
  let args = self.build_args()
  let temp = tempname()

  silent execute printf(":!%s %s %s > %s", g:loga_executable, self.subcommand, args, temp)
  let result = join(readfile(temp, "b"), "\n")

  call self.output(result)

  call delete(temp)
endfunction

function! s:loga.output(data)
  let cur_bufname = bufname('%')

  let bufwinnr = bufwinnr(s:output_buffer.bufnr)
  if bufwinnr == -1
    silent split
    silent edit `=s:output_buffer.BUFNAME`
    if !s:output_buffer.exists()
      let s:output_buffer.bufnr = bufnr('%')
    endif
    let bufwinnr = bufwinnr(s:output_buffer.bufnr)
  endif

  execute bufwinnr . "wincmd w"
  execute "%delete"

  setlocal buftype=nofile syntax=none bufhidden=hide
  setlocal noswapfile nobuflisted

  silent 0 put = a:data
  call cursor(1, 1)
endfunction

function! s:loga.clear() dict
  let self.subcommand = ""
  let self.args = {}
endfunction

function! s:loga.initialize(subcmd, args) dict
  call self.clear()
  let self.subcommand = a:subcmd

  if 0 < len(a:args)
    let self.args = a:args
  endif
endfunction

" commands "{{{
command! -nargs=+ Loga call <SID>Loga(<q-args>)
function! s:Loga(...) abort
  let args = a:000
  let subcmd = get(args, 0)
  let arg = get(args, 1, "")
  call s:loga.initialize(subcmd, s:parse_argument(arg))
  call s:loga.execute()
endfunction

" loga add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]
" loga config [KEY] [VALUE] [--global(optional)]
" loga delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]
" loga help [TASK]
command! -nargs=1 Lhelp call <SID>Help(<q-args>)
function! s:Help(command) abort
  call s:Loga("help", a:command)
endfunction

" loga import
" loga list
command! -nargs=* Llist call <SID>List()
function! s:List() abort
  call s:Loga("list")
endfunction

" loga lookup [TERM]
" loga new [PROJECT NAME] [SOURCE LANGUAGE] [TARGET LANGUAGE(optional)]
" loga register
" loga show
command! -nargs=* Lshow call <SID>Show(<q-args>)
function! s:Show(opt) abort
  call s:Loga("show", a:opt)
endfunction

" loga unregister
" loga update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]
" loga version
command! -nargs=* Lversion call <SID>Version()
function! s:Version() abort
  call s:Loga("version")
endfunction

" Options:
"   -g, [--glossary=GLOSSARY]
"   -S, [--source-language=SOURCE-LANGUAGE]
"   -T, [--target-language=TARGET-LANGUAGE]
"   -h, [--logaling-home=LOGALING-HOME]

"}}}

" vim:set ft=vim ts=2 sw=2 sts=2:

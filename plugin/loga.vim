" loga.vim - A logaling-command wrapper
" Maintainer: tacahiroy <tacahiroy```AT```gmail.com>
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
" Version: 0.2.0

if exists("g:loaded_loga") || &cp
  finish
endif
let g:loaded_loga = 1

" vim-users.jp/2011/10/hack239/
let g:loga_executable = get(g:, "loga_executable", "loga")

" TODO: long name option support
" loga global options
" Options:
"   -g, [--glossary=GLOSSARY]
"   -S, [--source-language=SOURCE-LANGUAGE]
"   -T, [--target-language=TARGET-LANGUAGE]
"   -h, [--logaling-home=LOGALING-HOME]
let g:loga_command_option = get(g:, "loga_command_option", {})

" behaviour settings
" open: split[default]|vsplit(string)
" size: width/height(integer)
let g:loga_result_buffer = get(g:, "loga_result_buffer", {"open": "split",
      \ "size": 10,})


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
            \ "options": {}}

" methods
function! s:loga.initialize(subcmd, args) dict
  call self.clear()

  let self.executable = g:loga_executable
  let self.subcommand = a:subcmd
  let self.options = deepcopy(g:loga_command_option)

  if 0 < len(a:args)
    let self.args = a:args
  endif
  call self.merge_arguments()
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

  call self.output(result)
endfunction

function! s:loga.output(data)
  if !s:output_buffer.is_open()
    silent execute g:loga_result_buffer.size . g:loga_result_buffer.open
    silent edit `=s:output_buffer.BUFNAME`

    let s:output_buffer.bufnr = bufnr(s:output_buffer.BUFNAME)
  endif

  let bufwinnr = bufwinnr(s:output_buffer.bufnr)

  execute bufwinnr . "wincmd w"
  execute "%delete _"

  setlocal buftype=nofile syntax=none bufhidden=hide
  setlocal noswapfile nobuflisted

  silent 0 put = a:data

  call cursor(1, 1)
  redraw!
endfunction

function! s:loga.clear() dict
  let self.executable = ""
  let self.subcommand = ""
  let self.args = []
  let self.options = {}
endfunction

function! s:loga.merge_arguments() dict
  " overwrite global option with argument if the same option was specified
  for [name, val] in items(self.options)
    let is_specified = 0
    for [c1, c2] in self.args
      if c1 == name
        let is_specified = 1
        break
      endif
    endfor
    if !is_specified
      call add(self.args, [name, val])
    endif
  endfor
endfunction
" }}}

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

" vim:set ft=vim ts=2 sw=2 sts=2:

" autoload/loga.vim
" Maintainer: Takahiro YOSHIHARA <tacahiroy```AT```gmail.com>
" License: The MIT License
" Version: 0.4.7-017
" supported logaling-command version 0.1.7

let s:saved_cpo = &cpo
set cpo&vim

let s:V = vital#of('loga').import('Data.List')

let s:loga_executable = substitute(get(g:, 'loga_executable', 'loga'), '\n', '', '')

" behaviour settings
let g:loga_result_window_hsplit = get(g:, 'loga_result_window_hsplit', 1)
let g:loga_result_window_size = get(g:, 'loga_result_window_size', 5)
let s:loga_enable_auto_lookup = get(g:, 'loga_enable_auto_lookup', 0)

let s:loga_delimiter = get(g:, 'loga_delimiter', '(//)')

" Utilities "{{{
function! s:debug(...)
  let g:debug = get(g:, 'debug', [])
  call add(g:debug, a:000)
endfunction
"}}}

" private " {{{
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

  call s:Loga.buffer.open(1)
  call s:Loga.buffer.focus()

  silent 0 put = a:data

  call cursor(1, 1)
  execute bufwinnr(cur_bufnr) . 'wincmd w'

  redraw!
endfunction


"""
" returns whether v is an option(e.g. '-s' of '-s ja') or not
" @arg: v(string)
" @return: 1 if v is value, 0 if not
function! s:is_options_value(v)
  return a:v !~# '^-'
endfunction

function! s:def_syntax(kind, name, pat)
  execute printf('syntax %s %s /%s/', a:kind, a:name, a:pat)
endfunction

" public " {{{
function! loga#new()
  return deepcopy(s:Loga)
endfunction
" }}}

" objects " {{{
let s:Loga = {'executable': '',
            \ 'subcommand': '',
            \ 'lookupword': '',
            \ 'args': [],
            \ 'buffer': {},
            \ }

let s:Loga.buffer = {'DELIMITER': s:loga_delimiter,
                   \ 'NAME': '[logaling]',
                   \ 'sp': '',
                   \ 'number': -1,
                   \ 'filter': {}}

let s:Loga.buffer.sp = g:loga_result_window_size .
                     \ (g:loga_result_window_hsplit ? 'split' : 'vsplit')

function! s:Loga.buffer.exists() dict
  return bufexists(self.number)
endfunction

function! s:Loga.buffer.is_open() dict
  return bufwinnr(self.number) != -1
endfunction

function! s:Loga.buffer.open(clear) dict
  let cur_bufwinnr = bufwinnr('%')

  if !self.is_open()
    silent execute self.sp
    silent edit `=self.NAME`

    let self.number = bufnr('%')

    setlocal buftype=nofile syntax=logaling bufhidden=hide
    setlocal filetype=logaling
    setlocal noswapfile nobuflisted
  endif

  call self.focus()
  call s:Loga.buffer.enable_syntax()
  execute cur_bufwinnr . 'wincmd w'

  if a:clear
    call self.clear(cur_bufwinnr)
  endif
endfunction

function! s:Loga.buffer.clear(bufwinnr) dict
  call self.focus()
  execute '%delete _'
  execute a:bufwinnr . 'wincmd w'
endfunction

function! s:Loga.buffer.focus() dict
  if self.is_open()
    let mybufwinnr = bufwinnr(self.number)
    if mybufwinnr != bufwinnr('%')
      execute mybufwinnr . 'wincmd w'
    endif
  endif
endfunction

function! s:Loga.buffer.execute(subcmd, ...) range dict
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
    let line = substitute(line, '\(\s*\t\|\t#\)', self.DELIMITER, 'g')

    " FIXME: escape is not perfect
    let args = map(split(line, self.DELIMITER), 'escape(v:val, "\\ (){}<>")')

    if is_test
      echohl Statement
      echomsg a:subcmd . ' ' . join(args, ' ')
      echohl None

      continue
    endif

    let [res, err] = s:Loga.Run(a:subcmd, args)
  endfor
endfunction

function! s:Loga.buffer.filter.delete(line)
  " remove NOTE
  return substitute(a:line, '\t#.*$', '', '')
endfunction

function! s:Loga.target_term_syntax_pattern() dict
  return '\s*\t\zs[^#]\+\ze\t#\?'
endfunction

" Highlight " {{{
function! s:Loga.buffer.enable_syntax()
  if exists('g:syntax_on')
    syntax clear
    syntax case ignore

    call s:def_syntax('match', 'LogaTargetTerm', s:Loga.target_term_syntax_pattern())
    call s:def_syntax('match', 'LogaNote', '#\s[^#]\+[\t$]')
    call s:def_syntax('keyword', 'LogaGlossary', join(map(s:Loga.glossaries(), '"\\t" . v:val') , ' '))
    call s:def_syntax('match', 'LogaDelimiter', s:loga_delimiter)

    if !empty(s:Loga.lookupword)
      call s:def_syntax('match', 'LogaLookupWord', s:Loga.lookupword)
    endif

    highlight link LogaGlossary Type
    highlight link LogaTargetTerm Function
    highlight link LogaNote Comment
    highlight link LogaDelimiter Delimiter
    highlight link LogaLookupWord IncSearch
  endif
endf
" }}}


" methods
function! s:Loga.initialize(subcmd, args) dict
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

function! s:Loga.build_command() dict
  let cmd = printf('%s %s', self.executable, self.subcommand)
  let args = join(s:V.flatten(self.args), ' ')

  return cmd . ' ' . args
endfunction

function! s:Loga.execute() dict
  let cmd = self.build_command()
  let result = system(cmd)
  return [result, self.is_error(result)]
endfunction

function! s:Loga.is_error(result)
  return a:result =~# '"\(\w\+\)" was called incorrectly\. Call as "loga \1'
endfunction

function! s:Loga.clear() dict
  let self.executable = ''
  let self.subcommand = ''
  let self.lookupword = ''
  let self.args = []
endfunction

function! s:Loga.glossaries() dict
  let [res, err] = self.Run('list', ['--no-pager', '--no-color'])
  return split(res, '\n')
endfunction
" }}}

" commands "{{{
function! s:Loga.Run(...) dict abort
  if !executable(s:loga_executable)
    echoerr printf('cannot execute "%s".', s:loga_executable)
    return
  endif

  let subcmd = get(a:000, 0)

  call self.initialize(subcmd, s:parse_argument(s:V.flatten(a:000[1:])))
  return self.execute()
endfunction

" loga
function! s:Loga.Loga(task, ...) dict abort
  let [res, err] = self.Run(a:task, a:000)
  call s:output(res)
endfunction

" loga add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]
function! s:Loga.Add(src, target, ...) dict abort
  let [res, err] = self.Run('add', a:src, a:target, a:000)
  call s:output(res)
endfunction

" loga delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]
function! s:Loga.Delete(term, ...) dict abort
  let [res, err] = self.Run('delete', a:term, a:000)
  call s:output(res)
endfunction

" loga help [TASK]
function! s:Loga.Help(command) dict abort
  let [res, err] = self.Run('help', a:command)
  call s:output(res)
endfunction

" loga lookup [TERM]
function! s:Loga.Lookup(word, ...) dict abort
  let [res, err] = self.Run('lookup', a:word, a:000)
  call s:output(res)
endfunction

function! s:Loga.AutoLookup(term) dict abort
  " do not lookup yourself
  if s:Loga.buffer.number == bufnr('%')
    return
  endif

  if s:loga_enable_auto_lookup && !empty(a:term)
    let [res, err] = self.Run('lookup', a:term)
    call s:output(res)
  endif
endfunction

" loga show
function! s:Loga.Show(...) dict abort
  let [res, err] = self.Run('show', a:000)
  call s:output(res)
endfunction

" loga update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]
function! s:Loga.Update(opt) dict abort
  let [res, err] = self.Run('update', a:opt)
  call s:output(res)
endfunction
"}}}

let &cpo = s:saved_cpo
unlet s:saved_cpo

"__END__
" vim: fen fdm=marker ft=vim ts=2 sw=2 sts=2:

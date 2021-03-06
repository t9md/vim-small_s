let s:ensure  = smalls#util#import("ensure")
let s:getchar = smalls#util#import("getchar")

let s:jump = {}
function! s:jump.setlines(lines) "{{{1
  silent! undojoin
  for [lnum, content] in items(a:lines)
    call setline(lnum, content)
  endfor
endfunction

function! s:jump.preserve_lines(pos2jumpk) "{{{1
  let r = {}
  for pos in keys(a:pos2jumpk)
    let lnum = str2nr(split(pos, ',')[0])
    if ! has_key(r, lnum)
      let r[lnum] = getline(lnum)
    endif
  endfor
  return r
endfunction

function! s:jump.gen_jump_lines(lines_org, pos2jumpk) "{{{1
  let r = copy(a:lines_org)
  for pos in sort(keys(a:pos2jumpk))
    let jump_key = a:pos2jumpk[pos]
    let [lnum_s, col_s] = split(pos, ',')
    let lnum = str2nr(lnum_s)
    let col  = str2nr(col_s)

    let dest_char = matchstr(r[lnum], '\%'. col .'c.')
    " FIXME padding for multibyte char is possibly not appropriate for
    " UTF8(2col displaywidth but 3byte)
    let padding = repeat(' ', 
          \ strdisplaywidth(dest_char) - strdisplaywidth(jump_key))

    let r[lnum] = !empty(r[lnum])
          \ ? substitute(r[lnum], '\%'. col .'c.', jump_key . padding, '')
          \ : jump_key
  endfor
  return r
endfunction

function! s:jump.gen_pos2jumpk(jumpk2pos, ...) "{{{1
  " * jumpk2pos       * pos2jumpk
  " --------------    ----------------------
  " jumpk : pos        pos         : jumpk    
  "  a    : [1,2] -->  00001,00002 : a      
  "  b    : [2,3]      00002,00003 : b      
  
  let pos2jumpk = {}
  let jumpk_nested = a:0 == 1 ? a:1 : ''

  for [jumpk, pos] in items(a:jumpk2pos)
    let jumpk = !empty(jumpk_nested) ? jumpk_nested : jumpk
    if type(pos) == type([])
      let pos2jumpk[printf('%05d,%05d', pos[0], pos[1])] = jumpk
    elseif type(pos) == type({})
      call extend(pos2jumpk, self.gen_pos2jumpk(pos, jumpk))
    else
      throw 'FATAL'
    endif
    unlet pos
  endfor
  return pos2jumpk
endfunction

function! s:jump.get_pos() "{{{1
  let jumpk2pos = smalls#grouping#SCTree(self.poslist, split(self.conf.jump_keys, '\zs'))
  return self._get_pos(jumpk2pos)
endfunction

function! s:jump._get_pos(jumpk2pos) "{{{1
  let pos = values(a:jumpk2pos)
  if len(pos) ==# 1
    return pos[0]
  endif

  let pos2jumpk = self.gen_pos2jumpk(a:jumpk2pos)
  let poslist   = map(sort(keys(pos2jumpk)), 'split(v:val, ",")')
  let lines_org = self.preserve_lines(pos2jumpk)
  let lines_jmp = self.gen_jump_lines(lines_org, pos2jumpk)

  try
    execute 'wundo' self.undofile
    call self.hl.jump_target(poslist)
    call self.setlines(lines_jmp)
    redraw
    let jumpk = s:getchar()
    if jumpk ==# "\<Esc>"
      throw 'JUMP_CANCELED'
    endif
    let jumpk = toupper(jumpk)
    call s:ensure(has_key(a:jumpk2pos, jumpk), 'Invalid target' )
  finally
    call self.setlines(lines_org)
    if filereadable(self.undofile)
      silent execute 'rundo' self.undofile
    endif
    call self.hl.clear('SmallsJumpTarget')
  endtry

  let dest = a:jumpk2pos[jumpk]
  return type(dest) == type([])
        \ ? dest
        \ : self._get_pos(dest)
endfunction

function! s:jump.new(owner) "{{{1
  if !exists('self.undofile')
    let self.undofile = tempname()
  endif
  let self.poslist = a:owner.poslist
  let self.conf    = a:owner.conf
  let self.env     = a:owner.env
  let self.hl      = a:owner.hl
  return self
endfunction

function! smalls#jump#new(owner) "{{{1
  return  s:jump.new(a:owner)
endfunction "}}}
" vim: foldmethod=marker

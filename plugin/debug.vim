if exists("g:loaded_debug") || &cp | finish | endif

let g:loaded_debug = 1

sign define debug_break text=🔴

function! s:RunDebugger(commandOrFunc)
  let origBuf = bufnr('%')
  let file = s:GetFile(a:commandOrFunc)
  let file = substitute(file, '\~', $HOME, '')

  if filereadable(file)
    if bufexists('[Debugger]')
      let command = 'split'
    else
      let command = 'new'
    endif

    exec "keepjumps hide" command file
    let lines = readfile(file)
    setlocal modifiable
    normal! gg"_dG
    call setline(1, lines)
    call s:ConfigureDebugBuffer()
    call s:AddLocalCommands()
    let b:debug_term = a:commandOrFunc
    call search(a:commandOrFunc)

    call s:CaptureDebugOutput(a:commandOrFunc)
  endif
endfunction

function! s:ConfigureDebugBuffer()
  setlocal foldcolumn=0
  setlocal nospell
  setlocal nobuflisted
  setlocal filetype=vim
  setlocal buftype=nofile
  setlocal nomodifiable
  setlocal noswapfile
  setlocal nowrap
endfunction

function! s:AddLocalCommands()
  command! -buffer -nargs=1 Break call s:AddBreakpoint(<f-args>)
  nnoremap <buffer> <LeftMouse> <LeftMouse>:call <SID>MouseWrapper()<CR>
endfunction

function! s:MouseWrapper(...)
  call s:AddBreakpoint(getpos('.')[1])
endfunction

function! s:AddBreakpoint(line)
  exec "sign place" a:line "line=" . a:line "name=debug_break file=" . expand("%:p")
  exec "breakadd file" a:line expand("%:p")
endfunction

function! s:GetFile(commandOrFunc)
  try
    if a:commandOrFunc !~ '#'
      redir => out
      exec "silent! verbose command" a:commandOrFunc
      redir END
    endif

    if !exists('out') || out =~ 'No user-defined commands found'
      redir => out
      exec "silent! verbose function" a:commandOrFunc
      redir END
    endif

    let fname = matchstr(out, 'Last set from \zs\f\+\ze')
    return fname
  catch *
    echo 'Exception is' v:exception
    echo 'No command or function found matching' a:commandOrFunc
    return ''
  endtry
endfunction

function! s:CaptureDebugOutput(commandOrFunc)
  let b:job = job_start(['vim'], {
    \   'callback': 'DebugVimOutCb',
    \   'mode': 'json'
    \ })
endfunction

function! DebugVimOutCb(channel, msg)
  echo 'Out:' a:msg
endfunction

function! s:ProcessCommand(index, cmd)
  return matchstr(a:cmd, '[! ][" ][b ] \zs\k\+\ze.*')
endfunction

function! CompletionForCommandsAndFunctions(...)
  redir => commands
  silent! command
  redir END

  let commands = split(commands, '\n')[1:]
  let commands = map(commands, function('s:ProcessCommand'))

  redir => functions
  silent! function
  redir END

  let functions = split(functions, '\n')
  let functions = map(functions, 'split(split(v:val, " ")[1], "(")[0]')

  return join(commands + functions, "\n")
endfunction

command! -nargs=* -complete=custom,CompletionForCommandsAndFunctions Debug call s:RunDebugger(<f-args>)

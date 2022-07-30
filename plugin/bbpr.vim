if exists('g:loaded_bbpr') | finish | endif

let s:save_cpo = &cpo 
set cpo&vim 

command! Bbpr lua require'bbpr'.bbpr()

let &cpo = s:save_cpo 
unlet s:save_cpo

let g:loaded_bbpr = 1

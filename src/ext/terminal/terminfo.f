\ terminfo.f    - terminfo handling words
\ -------------------------------------------------------------------------

  .( terminfo.f )

\ ------------------------------------------------------------------------
\ create format string stack of 5 cells

  <headers

  5 stack: fstack

\ ------------------------------------------------------------------------

\ this code interprets terminfo format strings within a terminfo file
\ for a given escape sequence and compiles said escape sequence into
\ the output buffer. it can then conditionally write that buffer to
\ stdout or continue compiling more (up to 16k's worth) of format strings
\ into the same buffer.

\ ------------------------------------------------------------------------
\ compile char c1 to output sequence string buffer

  headers>

: c>$           ( c1 --- )
  $buffer #$buffer [c]!     \ append to $buffer
  incr> #$buffer ;          \ increment compiled string length

\ ------------------------------------------------------------------------
\ fetch next character of terminfo format string

  <headers

: f$@           ( --- c1 )
  f$ c@ incr> f$ ;

\ ------------------------------------------------------------------------

: >fsp          ( n1 --- ) fstack [].push ;
: fsp>          ( --- n1 ) fstack [].pop ;
: 2fsp>         ( --- n1 n2 ) fsp> fsp> ;

\ ------------------------------------------------------------------------
\ various format string token handlers

: %%  '%' c>$ ;
: %c  fsp> c>$ ;
: %&  2fsp> and >fsp ;
: %|  2fsp> or >fsp ;
' %&  alias %A
' %|  alias %O
: %!  fsp> 0= >fsp ;
: %~  fsp> not >fsp ;
: %^  2fsp> xor >fsp ;
: %+  2fsp> + >fsp ;
: %-  2fsp> swap - >fsp ;
: %*  2fsp> * >fsp ;
: %/  2fsp> swap / >fsp ;
: %m  2fsp> swap mod >fsp ;
: %=  2fsp> = >fsp ;
: %>  2fsp> swap > >fsp ;
: %<  2fsp> swap < >fsp ;
: %'  f$@ c>$ f$@ drop ;

\ ------------------------------------------------------------------------
\ increment first 2 parameters for ansi terminals

: %i
  params dup incr
  cell+ incr ;

\ ------------------------------------------------------------------------
\ not too sure about these two (did i get them right ?)

: %s fsp> count bounds do i c@ c>$ loop ;
: %l fsp> c@ >fsp ;

\ ------------------------------------------------------------------------
\ point to specific variable (static or dynamic)

: ?a-z      ( --- a1 )
  f$@ 'a' 'z' between       \ is next char in format lower case alpha?
  if
    'a' - a-z               \ yes - set dynamic variable
  else
    'A' - A-Z               \ no - set static variable
  then
  swap [] ;

\ ------------------------------------------------------------------------
\ fetch and store variables

: %P        ( --- )  fsp> ?a-z ! ;
: %g        ( --- )  ?a-z @ >fsp ;

\ ------------------------------------------------------------------------
\ parse number from format string and push to format stack

: %{
  0
  begin
    f$@ dup '}' <>
  while
    swap 10 * +
  repeat
  >fsp ;

\ ------------------------------------------------------------------------
\ these are both noops

  ' noop alias %?           \ start a conditional
  ' noop alias %;           \ end a conditional

\ ------------------------------------------------------------------------
\ scan format string to next % character

: >%
  begin
    f$@ '%' =
  until ;

\ ------------------------------------------------------------------------
\ this is where we actually test and act on the condition

: %t                        \ we are currently pointing to the true part
  fsp> ?exit                \ if true parse true part
  begin                     \ else skip to end of true part
    >%
    f$@ 'e' ';' either      \ 'else' and 'endif' can both end an 'if'
  until ;

\ ------------------------------------------------------------------------
\ executing this means we have just executed a true part

: %e
  begin                     \ skip past else part and elseif part to endif
    >% f$@ ';' =
  until ;

\ ------------------------------------------------------------------------
\ fetch parameter from format string parameter buffer

: %p
  params f$@ $f and 1-
  []@ >fsp ;

\ ------------------------------------------------------------------------

  0 var #d                  \ 2 or 3 digits required (see below)

: (%d)      ( n1 --- )
  #d 0=
  if
    0 <# #s #>
  else
    0 <# #d rep # #>
  then ;

\ ------------------------------------------------------------------------
\ write number to output sequence

: %d
  base decimal              \ make sure we're in decimal
  fsp> (%d)                 \ get number to asciify
  dup>r                     \ remember string length
  $buffer #$buffer +        \ point to $buffer current position
  swap cmove                \ append asciified number
  r> +!> #$buffer           \ add string length to $buffer length
  !> base ;                 \ restore base

\ ------------------------------------------------------------------------

: ?digit        ( c1 --- c1 | c2 )
  dup '2' '3' either
  if
    $f and !> #d
    f$@                     \ this better be a 'd' :)
  then ;

\ ------------------------------------------------------------------------
\ we parsed a % char from the format string.

: (%)       ( ... '%' --- )
  drop f$@                  \ get % command char from format string
  ?digit

  case:                     \ execute command
    '%' opt %%  'p' opt %p
    'd' opt %d  'c' opt %c
    'i' opt %i  '&' opt %&
    '|' opt %|  '^' opt %^
    '+' opt %+  '-' opt %-
    '*' opt %*  '/' opt %/
    'm' opt %m  '=' opt %=
    '>' opt %>  '<' opt %<
    'A' opt %A  'O' opt %O
    $27 opt %'  '{' opt %{
    'P' opt %P  'g' opt %g
    't' opt %t  'e' opt %e
    ';' opt %;
  ;case ;

\ ------------------------------------------------------------------------
\ compile a sequence string to the string buffer

: (>format)     ( --- )
  begin
    f$@ ?dup                \ get next char of format string
  while
    dup '%' =               \ if its a % (a command)
    ?:
      (%)                   \ ...execute command
      c>$                   \ otherwise add this char to output string
  repeat ;

\ ------------------------------------------------------------------------

  ' (>format) is >format    \ resolve evil forward reference

\ ------------------------------------------------------------------------
\ write compiled escape sequence to stdout

  headers>

: (.$buffer)    ( --- )
  #$buffer $buffer          \ count address
  1 <write> drop            \ stdout
  0$buffer ;

\ ------------------------------------------------------------------------

  ' (.$buffer) is .$buffer

\ ========================================================================
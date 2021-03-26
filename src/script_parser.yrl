% testing stuff:
%  {:ok, comma_tokens, _}=:script_lexer.string '#BECOME one, 2'
%  {:ok, kwarg_tokens, _}=:script_lexer.string '#BECOME one: 2'
%  :script_parser.parse kwarg_tokens
%

Nonterminals script lines line list_args list_arg kwargs kwarg expression maybe_space.
Terminals '#' ':' ',' '\n' assignment comparison integer float operator space word.
Rootsymbol script.

script   -> lines      : {'$1'}.

lines -> line '\n' lines : ['$1'|'$3'].
lines -> line '\n'       : ['$1'].
lines -> line            : ['$1'].

% commands

line -> '#' word space kwargs    : {extract_line('$2'), [extract_command_token('$2'), '$4']}.
line -> '#' word space list_args : {extract_line('$2'), [extract_command_token('$2'), '$4']}.

line -> '#' word       : {extract_line('$2'), [extract_command_token('$2')]}.

list_args -> list_arg ',' maybe_space list_args : ['$1'|'$4'].
list_args -> list_arg                           : ['$1'].
list_arg  -> expression                         : '$1'.

kwargs    -> kwarg ',' maybe_space kwargs                : ['$1'|'$4'].
kwargs    -> kwarg                                       : ['$1'].
kwarg     -> word ':' maybe_space expression maybe_space : {extract_token('$1'),'$4'}.
kwarg     -> word ':' space                              : {extract_token('$1'),' '}.

expression -> integer             : extract_token('$1').
expression -> float               : extract_token('$1').
expression -> word                : extract_token('$1').


maybe_space -> space      : nil.
maybe_space -> '$empty'   : nil.

Erlang code.

extract_command_token({_Token, _Line, Value}) -> list_to_atom(string:lowercase(Value)).
extract_token({_Token, _Line, Value}) -> Value.
extract_line({_Token, Line, _Value}) -> Line.

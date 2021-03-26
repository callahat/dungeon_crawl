Nonterminals command kwargs kwarg thing.
Terminals '#' ',' ':' '\n' word.
Rootsymbol command.

command -> '#' thing            : {'$2'}.
command -> '#' thing kwargs     : {'$2','$3'}.
command -> '#' thing '\n'       : {'$2'}.
command -> '#' thing kwargs '\n' : {'$2','$3'}.

kwargs -> kwarg          : ['$1'].
kwargs -> kwarg ',' kwargs  : ['$1'|'$3'].

% Causes a warning, but needed for a kwarg that was intended as
% the space character that would have been dropped by the lexer
kwarg -> thing ':' thing   : [{'$1','$3'}].

thing -> ','               : ','.
thing -> word              : extract_token('$1').

Erlang code.

extract_token({_Token, _Line, Value}) -> Value.
% extract_token({Token, _Line}) -> Token.

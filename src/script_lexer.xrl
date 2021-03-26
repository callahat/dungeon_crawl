Definitions.


INT        = [0-9]+
OP         = [+-]
WHITESPACE    = [\s\t\n\r]

Rules.

{INT}         : {token, {integer, TokenLine, TokenChars}}.
{OP}          : {token, {operator, TokenLine, TokenChars}}.
{WHITESPACE}+ : {token, {whitespace, TokenLine, TokenChars}}.

Erlang code.


Definitions.

INT        = [0-9]+
FLOAT      = [0-9]+\.[0-9]+
OP         = [!+\-*\/]
ASSIGNMENT = [+\-*\/]?=
COMPARISON = [!<>=]?=
WORD       = [A-Za-z_]+
SPECIAL    = [#:@\/?,]
SPACE      = [\s]
TAB        = [\t]
NEWLINE    = [\n\r]

Rules.

{INT}         : {token, {integer, TokenLine, list_to_integer(TokenChars)}}.
{FLOAT}       : {token, {float, TokenLine, list_to_float(TokenChars)}}.
{OP}          : {token, {operator, TokenLine, TokenChars}}.
{ASSIGNMENT}  : {token, {assignment, TokenLine, TokenChars}}.
{COMPARISON}  : {token, {comparison, TokenLine, TokenChars}}.
{WORD}        : {token, {word, TokenLine, TokenChars}}.
{SPECIAL}     : {token, {list_to_atom(TokenChars), TokenLine}}.
{SPACE}+      : {token, {space, TokenLine, TokenChars}}.
{NEWLINE}     : {token, {'\n', TokenLine}}.
{TAB}+        : skip_token.

Erlang code.


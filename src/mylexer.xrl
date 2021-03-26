Definitions.

INT        = [0-9]+
WORD       = [a-zA-Z_0-9]+
NEWLINE    = [\n\r]
WHITESPACE = [\s\t]

Rules.

#             : {token, {'#', TokenLine}}.
\:            : {token, {':', TokenLine}}.
,             : {token, {',', TokenLine}}.
\\\s          : {token, {word, TokenLine, ' '}}.
{WORD}        : {token, {word, TokenLine, TokenChars}}.
{NEWLINE}     : {token, {'\n', TokenLine}}.
{WHITESPACE}+ : skip_token.

Erlang code.


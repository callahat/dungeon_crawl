Nonterminals expression maybe_whitespace.
Terminals integer operator whitespace.
Rootsymbol expression.

expression -> integer maybe_whitespace operator maybe_whitespace integer : {extract_token('$1'),
                                                                            extract_token('$3'),
                                                                            extract_token('$5')}.

maybe_whitespace -> whitespace : nil.
maybe_whitespace -> '$empty'   : nil.

Erlang code.

extract_token({_Token, _Line, Value}) -> Value.

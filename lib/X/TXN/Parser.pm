use v6;
unit class X::TXN::Parser;

# X::TXN::Parser::Entry::MultipleEntities {{{

class Entry::MultipleEntities is Exception
{
    has Str $.entry-text is required;
    has UInt $.number-entities is required;

    method message() returns Str
    {
        my Str $message = qq:to/EOF/;
        Sorry, only one entity per journal entry allowed, but found
        $.number-entities entities.

        In entry:

        「$.entry-text」
        EOF
        $message.trim;
    }
}

# end X::TXN::Parser::Entry::MultipleEntities }}}

# X::TXN::Parser::Extends {{{

class Extends is Exception
{
    has Str $.filename is required;

    method message() returns Str
    {
        my Str $message = qq:to/EOF/;
        Sorry, could not locate transaction journal to extend

            「$.filename」
        EOF
        $message.trim;
    }
}

# end X::TXN::Parser::Extends }}}

# X::TXN::Parser::Include {{{

class Include is Exception
{
    has Str $.filename is required;

    method message() returns Str
    {
        my Str $message = qq:to/EOF/;
        Sorry, could not load transaction journal to include at

            「$.filename」

        Transaction journal not found or not readable.
        EOF
        $message.trim;
    }
}

# end X::TXN::Parser::Include }}}

# X::TXN::Parser::ParseFailed {{{

class ParseFailed is Exception
{
    method message() returns Str
    {
        my Str $message = 'Sorry, parse failed';
    }
}

# end X::TXN::Parser::ParseFailed }}}

# X::TXN::Parser::ParsefileFailed {{{

class ParsefileFailed is Exception
{
    method message() returns Str
    {
        my Str $message = 'Sorry, parsefile failed';
    }
}

# end X::TXN::Parser::ParsefileFailed }}}

# X::TXN::Parser::String::EscapeSequence {{{

class String::EscapeSequence is Exception
{
    has Str $.esc is required;

    method message() returns Str
    {
        my Str $message = "Sorry, found bad string escape sequence 「$.esc」";
    }
}

# end X::TXN::Parser::String::EscapeSequence }}}

# vim: ft=perl6 fdm=marker fdl=0
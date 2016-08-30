use v6;
use TXN::Parser::Types;
use X::TXN::Parser;
unit class TXN::Parser::AST;

# TXN::Parser::AST::Entry::ID {{{

class Entry::ID
{
    has UInt @.number is required;
    has XXHash $.xxhash is required;

    # causal text from accounting ledger
    has Str $.text is required;

    method canonical(::?CLASS:D:) returns Str
    {
        $.number ~ ':' ~ $.xxhash;
    }
}

# end TXN::Parser::AST::Entry::ID }}}
# TXN::Parser::AST::Entry::Header {{{

class Entry::Header
{
    has Dateish $.date is required;
    has Str $.description;
    has UInt $.important = 0;
    has VarName @.tag;
}

# end TXN::Parser::AST::Entry::Header }}}
# TXN::Parser::AST::Entry::Posting::Account {{{

class Entry::Posting::Account
{
    has Silo $.silo is required;
    has VarName $.entity is required;
    has VarName @.path;
}

# end TXN::Parser::AST::Entry::Posting::Account }}}
# TXN::Parser::AST::Entry::Posting::Amount {{{

class Entry::Posting::Amount
{
    has AssetCode $.asset-code is required;
    has Quantity $.asset-quantity is required;
    has AssetSymbol $.asset-symbol;
    has PlusMinus $.plus-or-minus;
}

# end TXN::Parser::AST::Entry::Posting::Amount }}}
# TXN::Parser::AST::Entry::Posting::Annot::XE {{{

class Entry::Posting::Annot::XE
{
    has AssetCode $.asset-code is required;
    has Quantity $.asset-quantity is required;
    has AssetSymbol $.asset-symbol;
}

# end TXN::Parser::AST::Entry::Posting::Annot::XE }}}
# TXN::Parser::AST::Entry::Posting::Annot::Inherit {{{

class Entry::Posting::Annot::Inherit is Entry::Posting::Annot::XE { * }

# end TXN::Parser::AST::Entry::Posting::Annot::Inherit }}}
# TXN::Parser::AST::Entry::Posting::Annot::Lot {{{

class Entry::Posting::Annot::Lot
{
    has VarName $.name is required;

    # is this lot being drawn down or filled up?
    has DecInc $.decinc is required;
}

# end TXN::Parser::AST::Entry::Posting::Annot::Lot }}}
# TXN::Parser::AST::Entry::Posting::Annot {{{

class Entry::Posting::Annot
{
    has Entry::Posting::Annot::Inherit $.inherit;
    has Entry::Posting::Annot::Lot $.lot;
    has Entry::Posting::Annot::XE $.xe;
}

# end TXN::Parser::AST::Entry::Posting::Annot }}}
# TXN::Parser::AST::Entry::Posting::ID {{{

class Entry::Posting::ID
{
    # parent
    has Entry::ID $.entry-id is required;

    # scalar, because C<include>'d postings are forbidden
    has UInt $.number is required;

    has XXHash $.xxhash is required;

    # causal text from accounting ledger
    has Str $.text is required;

    method canonical(::?CLASS:D:) returns Str
    {
        $.number ~ ':' ~ $.xxhash;
    }
}

# end TXN::Parser::AST::Entry::Posting::ID }}}
# TXN::Parser::AST::Entry::Posting {{{

class Entry::Posting
{
    has Entry::Posting::ID $.id is required;
    has Entry::Posting::Account $.account is required;
    has Entry::Posting::Amount $.amount is required;
    has DecInc $.decinc is required;
    has DrCr $.drcr is required;

    has Entry::Posting::Annot $.annot;

    # submethod BUILD {{{

    submethod BUILD(
        Entry::Posting::Account :$!account!,
        Entry::Posting::Amount :$!amount!,
        Entry::Posting::ID :$!id!,
        DecInc :$!decinc!,
        Entry::Posting::Annot :$annot,
    )
    {
        $!annot = $annot if $annot;
        $!drcr = determine-debit-or-credit($!account.silo, $!decinc);
    }

    # end submethod BUILD }}}
    # method new {{{

    method new(
        *%opts (
            Entry::Posting::Account :$account!,
            Entry::Posting::Amount :$amount!,
            Entry::Posting::ID :$id!,
            DecInc :$decinc!,
            Entry::Posting::Annot :$annot
        )
    )
    {
        self.bless(|%opts);
    }

    # end method new }}}
    # sub determine-debit-or-credit {{{

    # assets and expenses increase on the debit side

    # +assets/expenses
    multi sub determine-debit-or-credit(ASSETS, INC) returns DrCr { DEBIT }
    multi sub determine-debit-or-credit(EXPENSES, INC) returns DrCr { DEBIT }
    # -assets/expenses
    multi sub determine-debit-or-credit(ASSETS, DEC) returns DrCr { CREDIT }
    multi sub determine-debit-or-credit(EXPENSES, DEC) returns DrCr { CREDIT }

    # income, liabilities and equity increase on the credit side

    # +income/liabilities/equity
    multi sub determine-debit-or-credit(INCOME, INC) returns DrCr { CREDIT }
    multi sub determine-debit-or-credit(LIABILITIES, INC) returns DrCr { CREDIT }
    multi sub determine-debit-or-credit(EQUITY, INC) returns DrCr { CREDIT }
    # -income/liabilities/equity
    multi sub determine-debit-or-credit(INCOME, DEC) returns DrCr { DEBIT }
    multi sub determine-debit-or-credit(LIABILITIES, DEC) returns DrCr { DEBIT }
    multi sub determine-debit-or-credit(EQUITY, DEC) returns DrCr { DEBIT }

    # end sub determine-debit-or-credit }}}
}

# end TXN::Parser::AST::Entry::Posting }}}
# TXN::Parser::AST::Entry {{{

class Entry
{

    has Entry::ID $.id is required;
    has Entry::Header $.header is required;
    has Entry::Posting @.posting is required;

    # submethod BUILD {{{

    submethod BUILD(
        Entry::ID :$!id!,
        Entry::Header :$!header!,
        Entry::Posting :@!posting!
    )
    {

    }

    # end submethod BUILD }}}
    # method new {{{

    method new(
        *%opts (
            Entry::ID :$id!,
            Entry::Header :$header!,
            Entry::Posting :@posting!
        )
    )
    {
        # verify entry is limited to one entity
        my UInt $number-entities =
            @posting.map({ .account.entity }).unique.elems;
        unless $number-entities == 1
        {
            die X::TXN::Parser::Entry::MultipleEntities.new(
                :$number-entities,
                :entry-text($id.text)
            );
        }

        self.bless(|%opts);
    }

    # end method new }}}
}

# end TXN::Parser::AST::Entry }}}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0:
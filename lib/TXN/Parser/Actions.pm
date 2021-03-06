use v6;
use Digest::xxHash;
use TXN::Parser::AST;
use TXN::Parser::Grammar;
use TXN::Parser::Types;
use X::TXN::Parser;
unit class TXN::Parser::Actions;

# public attributes {{{

# base path for <include> directives
has Str:D $.txn-dir = "$*HOME/.config/mktxn/txn";

# DateTime offset for when the local offset is omitted in dates. if
# not passed as a parameter during instantiation, use UTC (0)
has Int:D $.date-local-offset = 0;

# increments on each entry (0+)
# each element in list represents an include level deep (0+)
has UInt:D @.entry-number = 0;

# the file currently being parsed
has Str:D $.file = '.';

# end public attributes }}}
# private types {{{

# to aid with building exchange rates (@ and @@, « and ««)
enum XERateType <PER-UNIT IN-TOTAL>;

# end private types }}}

# string grammar-actions {{{

# --- string basic grammar-actions {{{

method string-basic-char:common ($/)
{
    make ~$/;
}

method string-basic-char:tab ($/)
{
    make ~$/;
}

method escape:sym<b>($/)
{
    make "\b";
}

method escape:sym<t>($/)
{
    make "\t";
}

method escape:sym<n>($/)
{
    make "\n";
}

method escape:sym<f>($/)
{
    make "\f";
}

method escape:sym<r>($/)
{
    make "\r";
}

method escape:sym<quote>($/)
{
    make "\"";
}

method escape:sym<backslash>($/)
{
    make '\\';
}

method escape:sym<u>($/)
{
    make chr(:16(@<hex>.join));
}

method escape:sym<U>($/)
{
    make chr(:16(@<hex>.join));
}

method string-basic-char:escape-sequence ($/)
{
    make $<escape>.made;
}

method string-basic-text($/)
{
    make @<string-basic-char>».made.join;
}

method string-basic($/)
{
    make $<string-basic-text> ?? $<string-basic-text>.made !! "";
}

method string-basic-multiline-char:common ($/)
{
    make ~$/;
}

method string-basic-multiline-char:tab ($/)
{
    make ~$/;
}

method string-basic-multiline-char:newline ($/)
{
    make ~$/;
}

method string-basic-multiline-char:escape-sequence ($/)
{
    if $<escape>
    {
        make $<escape>.made;
    }
    elsif $<ws-remover>
    {
        make "";
    }
}

method string-basic-multiline-text($/)
{
    make @<string-basic-multiline-char>».made.join;
}

method string-basic-multiline($/)
{
    make $<string-basic-multiline-text>
        ?? $<string-basic-multiline-text>.made
        !! "";
}

# --- end string basic grammar-actions }}}
# --- string literal grammar-actions {{{

method string-literal-char:common ($/)
{
    make ~$/;
}

method string-literal-char:backslash ($/)
{
    make '\\';
}

method string-literal-text($/)
{
    make @<string-literal-char>».made.join;
}

method string-literal($/)
{
    make $<string-literal-text> ?? $<string-literal-text>.made !! "";
}

method string-literal-multiline-char:common ($/)
{
    make ~$/;
}

method string-literal-multiline-char:backslash ($/)
{
    make '\\';
}

method string-literal-multiline-text($/)
{
    make @<string-literal-multiline-char>».made.join;
}

method string-literal-multiline($/)
{
    make $<string-literal-multiline-text>
        ?? $<string-literal-multiline-text>.made
        !! "";
}

# --- end string literal grammar-actions }}}
# --- var-name string grammar-actions {{{

method var-name-string:basic ($/)
{
    make $<string-basic-text>.made;
}

method var-name-string:literal ($/)
{
    make $<string-literal-text>.made;
}

# --- end var-name string grammar-actions }}}
# --- txnlib string grammar-actions {{{

method txnlib-string-delimiter-right($/)
{
    make ~$/;
}

method txnlib-string-path-divisor($/)
{
    make ~$/;
}

method txnlib-escape:sym<backslash>($/)
{
    make '\\';
}

method txnlib-escape:sym<delimiter-right>($/)
{
    make $<txnlib-string-delimiter-right>.made;
}

method txnlib-escape:sym<horizontal-ws>($/)
{
    make ~$/;
}

method txnlib-escape:sym<path-divisor>($/)
{
    make $<txnlib-string-path-divisor>.made;
}

method txnlib-string-char:common ($/)
{
    make ~$/;
}

method txnlib-string-char:escape-sequence ($/)
{
    make $<txnlib-escape>.made;
}

method txnlib-string-char:path-divisor ($/)
{
    make $<txnlib-string-path-divisor>.made;
}

method txnlib-string-text($/)
{
    make @<txnlib-string-char>».made.join;
}

method txnlib-string($/)
{
    make $<txnlib-string-text>.made;
}

# --- end txnlib string grammar-actions }}}

method string:basic ($/)
{
    make $<string-basic>.made;
}

method string:basic-multi ($/)
{
    make $<string-basic-multiline>.made;
}

method string:literal ($/)
{
    make $<string-literal>.made;
}

method string:literal-multi ($/)
{
    make $<string-literal-multiline>.made;
}

# end string grammar-actions }}}
# number grammar-actions {{{

method integer-unsigned($/)
{
    # ensure integers are coerced to type FatRat
    make FatRat(+$/);
}

method float-unsigned($/)
{
    make FatRat(+$/);
}

method plus-or-minus:sym<+>($/)
{
    make ~$/;
}

method plus-or-minus:sym<->($/)
{
    make ~$/;
}

# end number grammar-actions }}}
# datetime grammar-actions {{{

method date-fullyear($/)
{
    make Int(+$/);
}

method date-month($/)
{
    make Int(+$/);
}

method date-mday($/)
{
    make Int(+$/);
}

method time-hour($/)
{
    make Int(+$/);
}

method time-minute($/)
{
    make Int(+$/);
}

method time-second($/)
{
    make Rat(+$/);
}

method time-secfrac($/)
{
    make Rat(+$/);
}

method time-numoffset($/)
{
    my Int:D $multiplier = $<plus-or-minus>.made eq '+' ?? 1 !! -1;
    make Int(
        (
            ($multiplier * $<time-hour>.made * 60) + $<time-minute>.made
        )
        * 60
    );
}

method time-offset($/)
{
    make $<time-numoffset> ?? Int($<time-numoffset>.made) !! 0;
}

method partial-time($/)
{
    my Rat:D $second = Rat($<time-second>.made);
    $second += Rat($<time-secfrac>.made) if $<time-secfrac>;
    make %(
        :hour(Int($<time-hour>.made)),
        :minute(Int($<time-minute>.made)),
        :$second
    );
}

method full-date($/)
{
    make %(
        :year(Int($<date-fullyear>.made)),
        :month(Int($<date-month>.made)),
        :day(Int($<date-mday>.made))
    );
}

method full-time($/)
{
    make %(
        :hour(Int($<partial-time>.made<hour>)),
        :minute(Int($<partial-time>.made<minute>)),
        :second(Rat($<partial-time>.made<second>)),
        :timezone(Int($<time-offset>.made))
    );
}

method date-time-omit-local-offset($/)
{
    make %(
        :year(Int($<full-date>.made<year>)),
        :month(Int($<full-date>.made<month>)),
        :day(Int($<full-date>.made<day>)),
        :hour(Int($<partial-time>.made<hour>)),
        :minute(Int($<partial-time>.made<minute>)),
        :second(Rat($<partial-time>.made<second>)),
        :timezone($.date-local-offset)
    );
}

method date-time($/)
{
    make %(
        :year(Int($<full-date>.made<year>)),
        :month(Int($<full-date>.made<month>)),
        :day(Int($<full-date>.made<day>)),
        :hour(Int($<full-time>.made<hour>)),
        :minute(Int($<full-time>.made<minute>)),
        :second(Rat($<full-time>.made<second>)),
        :timezone(Int($<full-time>.made<timezone>))
    );
}

method date:full-date ($/)
{
    make Date.new(|$<full-date>.made);
}

method date:date-time-omit-local-offset ($/)
{
    make DateTime.new(|$<date-time-omit-local-offset>.made);
}

method date:date-time ($/)
{
    make DateTime.new(|$<date-time>.made);
}

# end datetime grammar-actions }}}
# variable name grammar-actions {{{

method var-name:bare ($/)
{
    make ~$/;
}

method var-name:quoted ($/)
{
    make $<var-name-string>.made;
}

# end variable name grammar-actions }}}
# header grammar-actions {{{

method important($/)
{
    # make important the quantity of exclamation marks
    make $/.chars;
}

method tag($/)
{
    # make tag (with leading # stripped)
    make $<var-name>.made;
}

method meta:important ($/)
{
    make %(:important($<important>.made));
}

method meta:tag ($/)
{
    make %(:tag($<tag>.made));
}

method metainfo($/)
{
    make @<meta>».made;
}

method description($/)
{
    make $<string>.made;
}

method header($/)
{
    my %header;

    my Dateish:D $date = $<date>.made;
    my Str:D $description = $<description>.made if $<description>;
    my UInt:D $important = 0;
    my VarName:D @tag;

    for @<metainfo>».made -> @metainfo
    {
        $important += [+] @metainfo.grep(*.keys eq 'important')».values.flat;
        push @tag, |@metainfo.grep(*.keys eq 'tag')».values.flat.unique;
    }

    %header<date> = $date;
    %header<description> = $description if $description;
    %header<important> = $important if $important;

    make TXN::Parser::AST::Entry::Header.new(|%header, :@tag);
}

# end header grammar-actions }}}
# posting grammar-actions {{{

# --- posting account grammar-actions {{{

method account-name($/)
{
    make @<var-name>».made;
}

method silo:assets ($/)
{
    make ASSETS;
}

method silo:expenses ($/)
{
    make EXPENSES;
}

method silo:income ($/)
{
    make INCOME;
}

method silo:liabilities ($/)
{
    make LIABILITIES;
}

method silo:equity ($/)
{
    make EQUITY;
}

method account($/)
{
    my %account;

    my Silo:D $silo = $<silo>.made;
    my VarName:D $entity = $<entity>.made;
    my VarName:D @path = $<account-path>.made if $<account-path>;

    %account<silo> = $silo;
    %account<entity> = $entity;

    make TXN::Parser::AST::Entry::Posting::Account.new(|%account, :@path);
}

# --- end posting account grammar-actions }}}
# --- posting amount grammar-actions {{{

method asset-code:bare ($/)
{
    make ~$/;
}

method asset-code:quoted ($/)
{
    make $<var-name-string>.made;
}

method asset-symbol($/)
{
    make ~$/;
}

method asset-quantity:integer ($/)
{
    make $<integer-unsigned>.made;
}

method asset-quantity:float ($/)
{
    make $<float-unsigned>.made;
}

method asset-price:integer ($/)
{
    make $<integer-unsigned>.made;
}

method asset-price:float ($/)
{
    make $<float-unsigned>.made;
}

method amount($/)
{
    my %amount;

    my AssetCode:D $asset-code = $<asset-code>.made;
    my Quantity:D $asset-quantity = $<asset-quantity>.made;
    my AssetSymbol:D $asset-symbol = $<asset-symbol>.made if $<asset-symbol>;
    my PlusMinus:D $plus-or-minus = $<plus-or-minus>.made if $<plus-or-minus>;

    %amount<asset-code> = $asset-code;
    %amount<asset-quantity> = $asset-quantity;
    %amount<asset-symbol> = $asset-symbol if $asset-symbol;
    %amount<plus-or-minus> = $plus-or-minus if $plus-or-minus;

    make TXN::Parser::AST::Entry::Posting::Amount.new(|%amount);
}

# --- end posting amount grammar-actions }}}
# --- posting annotation grammar-actions {{{

# --- --- xe grammar-actions {{{

method xe-symbol:per-unit ($/)
{
    make PER-UNIT;
}

method xe-symbol:in-total ($/)
{
    make IN-TOTAL;
}

method xe-rate($/)
{
    my %xe-rate;

    my AssetCode:D $asset-code = $<asset-code>.made;
    my Price:D $asset-price = $<asset-price>.made;
    my AssetSymbol:D $asset-symbol = $<asset-symbol>.made if $<asset-symbol>;

    %xe-rate<asset-code> = $asset-code;
    %xe-rate<asset-price> = $asset-price;
    %xe-rate<asset-symbol> = $asset-symbol if $asset-symbol;

    make %xe-rate;
}

method xe($/)
{
    my %xe-rate = $<xe-rate>.made;
    my XERateType:D $rate-type = $<xe-symbol>.made;
    %xe-rate<rate-type> = $rate-type;
    make %xe-rate;
}

# --- --- end xe grammar-actions }}}
# --- --- inherit grammar-actions {{{

method inherit-symbol:per-unit ($/)
{
    make PER-UNIT;
}

method inherit-symbol:in-total ($/)
{
    make IN-TOTAL;
}

method inherit($/)
{
    # a grammar alias, C<$<inherit-rate> comes from C<xe-rate>
    my %inherit-rate = $<inherit-rate>.made;
    my XERateType:D $rate-type = $<inherit-symbol>.made;
    %inherit-rate<rate-type> = $rate-type;
    make %inherit-rate;
}

# --- --- end inherit grammar-actions }}}
# --- --- lot grammar-actions {{{

method lot-name($/)
{
    make $<var-name>.made;
}

method lot:acquisition ($/)
{
    my %lot;

    my VarName:D $name = $<lot-name>.made;
    my DecInc:D $decinc = INC;

    %lot<name> = $name;
    %lot<decinc> = $decinc;

    make TXN::Parser::AST::Entry::Posting::Annot::Lot.new(|%lot);
}

method lot:disposition ($/)
{
    my %lot;

    my VarName:D $name = $<lot-name>.made;
    my DecInc:D $decinc = DEC;

    %lot<name> = $name;
    %lot<decinc> = $decinc;

    make TXN::Parser::AST::Entry::Posting::Annot::Lot.new(|%lot);
}

# --- --- end lot grammar-actions }}}

method annot($/)
{
    my %annot;

    my %xe = $<xe>.made if $<xe>;
    my %inherit = $<inherit>.made if $<inherit>;
    my TXN::Parser::AST::Entry::Posting::Annot::Lot:D $lot =
        $<lot>.made if $<lot>;

    %annot<xe> = %xe if %xe;
    %annot<inherit> = %inherit if %inherit;
    %annot<lot> = $lot if $lot;

    make %annot;
}

# --- end posting annotation grammar-actions }}}

method posting($/)
{
    my Str:D $text = ~$/;
    my XXHash:D $xxhash = xxHash32($text);

    my TXN::Parser::AST::Entry::Posting::Account:D $account = $<account>.made;
    my TXN::Parser::AST::Entry::Posting::Amount:D $amount = $<amount>.made;
    my TXN::Parser::AST::Entry::Posting::Annot:D $annot = gen-annot(
        $amount.asset-quantity,
        $<annot>.made
    ) if $<annot>;

    my PlusMinus:D $plus-or-minus = $amount.plus-or-minus
        if $amount.plus-or-minus;
    my DecInc:D $decinc = $plus-or-minus.defined && $plus-or-minus eq '-'
        ?? DEC
        !! INC;

    make %(:$account, :$amount, :$annot, :$decinc, :$text, :$xxhash);
}

method posting-line($/)
{
    make $<posting>.made;
}

method postings($/)
{
    make @<posting-line>».made.grep(Hash:D);
}

# end posting grammar-actions }}}
# entry grammar-actions {{{

method entry($/)
{
    my Str:D $text = ~$/;
    my Hash:D @postings = $<postings>.made;

    # Entry::ID
    my XXHash:D $xxhash = xxHash32($text);
    my TXN::Parser::AST::Entry::ID:D $entry-id =
        TXN::Parser::AST::Entry::ID.new(
            :number(@.entry-number.deepmap(*.clone)),
            :$xxhash,
            :$text
        );

    # insert Posting::ID derived from Entry::ID
    my UInt:D $posting-number = 0;
    my TXN::Parser::AST::Entry::Posting:D @posting = @postings.map({
        my TXN::Parser::AST::Entry::Posting::ID:D $posting-id =
            TXN::Parser::AST::Entry::Posting::ID.new(
                :$entry-id,
                :number($posting-number++),
                :xxhash($_<xxhash>),
                :text($_<text>)
            );
        TXN::Parser::AST::Entry::Posting.new(
            :account($_<account>),
            :amount($_<amount>),
            :annot($_<annot>),
            :decinc($_<decinc>),
            :id($posting-id)
        );
    });

    @!entry-number[*-1]++;

    make TXN::Parser::AST::Entry.new(
        :id($entry-id),
        :header($<header>.made),
        :@posting
    );
}

# end entry grammar-actions }}}
# include grammar-actions {{{

method filename($/)
{
    make $<var-name-string>.made;
}

method txnlib($/)
{
    make $<txnlib-string>.made;
}

method include:filename ($match)
{
    my Str:D $filename = $match<filename>.made.IO.is-relative
        # if relative path given, resolve path relative to current txn
        # file being parsed and append '.txn' extension
        ?? join('/', $.file.IO.dirname, $match<filename>.made) ~ '.txn'
        # if absolute path given, use it directly (don't append extension)
        !! $match<filename>.made;

    unless $filename.IO.e && $filename.IO.r && $filename.IO.f
    {
        die X::TXN::Parser::Include.new(:$filename);
    }

    my UInt:D @entry-number = |@.entry-number.deepmap(*.clone), 0;
    my TXN::Parser::Actions:D $actions = TXN::Parser::Actions.new(
        :@entry-number,
        :$.date-local-offset,
        :file($filename),
        :$.txn-dir
    );
    my TXN::Parser::AST::Entry:D @entry =
        TXN::Parser::Grammar.parsefile($filename, :$actions).made;
    @!entry-number[*-1]++;

    $match.make(@entry);
}

method include:txnlib ($match)
{
    unless $match<txnlib>.made.IO.is-relative
    {
        die X::TXN::Parser::TXNLibAbsolute(:lib($match<txnlib>.made));
    }

    my Str:D $filename = join('/', $.txn-dir, $match<txnlib>.made) ~ '.txn';

    unless $filename.IO.e && $filename.IO.r && $filename.IO.f
    {
        die X::TXN::Parser::Include.new(:$filename);
    }

    my UInt:D @entry-number = |@.entry-number.deepmap(*.clone), 0;
    my TXN::Parser::Actions:D $actions = TXN::Parser::Actions.new(
        :@entry-number,
        :$.date-local-offset,
        :file($filename),
        :$.txn-dir
    );
    my TXN::Parser::AST::Entry:D @entry =
        TXN::Parser::Grammar.parsefile($filename, :$actions).made;
    @!entry-number[*-1]++;

    $match.make(@entry);
}

method include-line($/)
{
    make $<include>.made;
}

# end include grammar-actions }}}
# ledger grammar-actions {{{

method segment:entry ($/)
{
    make $<entry>.made;
}

method segment:include ($/)
{
    make $<include-line>.made;
}

method ledger($/)
{
    my TXN::Parser::AST::Entry:D @entry =
        @<segment>».made.flatmap(*.grep(TXN::Parser::AST::Entry:D));
    make @entry;
}

method TOP($/)
{
    make $<ledger>.made;
}

# end ledger grammar-actions }}}

# helper functions {{{

sub gen-annot(
    Quantity $asset-quantity,
    % (
        :%xe,
        :%inherit,
        TXN::Parser::AST::Entry::Posting::Annot::Lot :$lot
    )
) returns TXN::Parser::AST::Entry::Posting::Annot:D
{
    my %annot;

    my TXN::Parser::AST::Entry::Posting::Annot::XE:D $xe =
        gen-xe($asset-quantity, :%xe) if %xe;
    my TXN::Parser::AST::Entry::Posting::Annot::Inherit:D $inherit =
        gen-xe($asset-quantity, :%inherit) if %inherit;

    %annot<xe> = $xe if $xe;
    %annot<inherit> = $inherit if $inherit;
    %annot<lot> = $lot if $lot;

    my TXN::Parser::AST::Entry::Posting::Annot:D $annot =
        TXN::Parser::AST::Entry::Posting::Annot.new(|%annot);
}

multi sub gen-xe(
    Quantity:D $amount-asset-quantity,
    :%xe! (
        AssetCode:D :$asset-code!,
        Price:D :$asset-price!,
        XERateType:D :$rate-type!,
        Str :$asset-symbol
    )
) returns TXN::Parser::AST::Entry::Posting::Annot::XE:D
{
    my %xe-rate;

    %xe-rate<asset-code> = $asset-code;
    %xe-rate<asset-price> = $rate-type ~~ IN-TOTAL
        ?? ($asset-price / $amount-asset-quantity)
        !! $asset-price;
    %xe-rate<asset-symbol> = $asset-symbol if $asset-symbol;

    my TXN::Parser::AST::Entry::Posting::Annot::XE:D $xe =
        TXN::Parser::AST::Entry::Posting::Annot::XE.new(|%xe-rate);
}

multi sub gen-xe(
    Quantity:D $amount-asset-quantity,
    :%inherit! (
        AssetCode:D :$asset-code!,
        Price:D :$asset-price!,
        XERateType:D :$rate-type!,
        Str :$asset-symbol
    )
) returns TXN::Parser::AST::Entry::Posting::Annot::Inherit:D
{
    my %inherit-rate;

    %inherit-rate<asset-code> = $asset-code;
    %inherit-rate<asset-price> = $rate-type ~~ IN-TOTAL
        ?? ($asset-price / $amount-asset-quantity)
        !! $asset-price;
    %inherit-rate<asset-symbol> = $asset-symbol if $asset-symbol;

    my TXN::Parser::AST::Entry::Posting::Annot::Inherit:D $inherit =
        TXN::Parser::AST::Entry::Posting::Annot::Inherit.new(|%inherit-rate);
}

# end helper functions }}}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0:

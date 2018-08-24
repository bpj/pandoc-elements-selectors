#!/usr/bin/env perl

# Proposed Pandoc::Elements extended selector expression syntax
#
# VERSION 201805021600
#
# The latest version of this script can be found at
# <https://github.com/bpj/pandoc-elements-selectors>
#
# You can test the syntax by running this script and typing selectors to STDIN.
# The selector will be compiled and the compiled subroutine or any error message
# will be printed to STDOUT.

# use utf8;
use utf8::all;
use autodie 2.26;
use 5.010001;
use strict;
use warnings;
use warnings  qw(FATAL utf8);
# use open      qw(:std :utf8);
# use charnames qw(:full :short);

use Carp                qw[ carp croak confess cluck     ];
use Text::Glob          qw[ glob_to_regex ];

use Data::Printer deparse => 1, alias => 'ddp', output => 'stdout';

my %oppos = qw| ( ) { } [ ] < > |;
@oppos{ values %oppos } = keys %oppos;

my $unescaped_re = qr{ (?<unescaped> (?<! \\ ) (?: \\ \\ )*  ) }msx;
my $balanced_braces_re = qr{
    (?<balanced_braces>
        \{ (?: [^\{\}\\]*+ (?: \\. [^\{\}\\]*+ )*+ | (?&balanced_braces) )* \}
    )
}msx;

my $unbalanced_braces_re = qr{
    (?&unescaped)
    (?:
        (?<ok>
            (?&balanced_braces)
        |   \\ [\{\}]
        )
    |   (?<unbalanced> [\{\}] )
    )
    (?(DEFINE)
        $unescaped_re
        $balanced_braces_re
    )
}msx;

my $string_re = qr{
    (?<string_re_match>
        (?<quote> '   ) (?<string>  (?&SINGLE_QUOTED) ) '
    |   (?<quote> "   ) (?<string>  (?&DOUBLE_QUOTED) ) "
    |   (?<quote> \[  ) (?<glob>    (?&GLOB)          ) \] # (?<mod> \w* )
    |   (?<quote> [{] ) (?<regex>   (?&REGEX)         ) [}] (?<mod> \w* )
    |   (?<quote>     ) (?<string>  (?&WORD)          )
    )
    (?(DEFINE)
        (?<SINGLE_QUOTED>  [^']*   (?: ''  [^']*   )* )
        (?<DOUBLE_QUOTED>  [^"]*   (?: ""  [^"]*   )* )
        (?<WORD>           \b(?=\w)[-\w]*\w\b         )
        (?<CHARCLASS> 
            \[ \]? (?: \[:\^?\w+:\] | [^\[\]\\]*+ | \\. [^\[\]\\]*+ | \[ )* \]
        )
        (?<GLOB> (?: [^\]\[\\]*+ | \\. [^\]\[\\]*+ | \[ (?&GLOB) \] )* )
        (?<REGEX>
            (?:
                [^\{\}\[\]\\]*+         # 'normal' characters
            |   \\. [^\{\}\[\]\\]*+     # or backslash escapes
            |   (?&CHARCLASS)           # or character classes
            |   [{] (?&REGEX) [}]       # or nested balanced braces
            )*
        )
    )
}msx;

my $word_re = qr{^$string_re$};

my $expression_re = qr{
    (?<not> \!? )
    (?:
        (?<sigil> \: ) (?<type> document|block|inline|meta )
    |   (?<sigil> \& )                  (?<method> (?&ID)  ) (?: (?<cmp> (?&CMP) ) (?<num>   (?&NUM)    )
                                                             |   (?<cmp> (?&OP)  ) (?<value> (?&STRING) )
                                                             )?
    |   (?<sigil> \% ) (?<op> (?&OP)? ) (?<key> (?&STRING) ) (?: (?<cmp> (?&CMP) ) (?<num>   (?&NUM)    )
                                                             |   (?<cmp> (?&OP)  ) (?<value> (?&STRING) )
                                                             )?
    |   (?<sigil> [.#]? )                                                          (?<value> (?&STRING) )
    )
    \s*
    (?(DEFINE)
        (?<ID> (?!\d) \w+ )
        (?<NUM> -? \b (?: [0-9]* \. [0-9]+ | [0-9]+ ) \b )
        (?<CMP> [\!\=]?\= | [\<\>]\=? )
        (?<OP>  [\!\=]?\~ )
        (?<STRING> $string_re )
    )
}msx;

my $selector_re = qr{
    \s* (?<selector> (?&EXPRESSION)+ ) (?: \z | \s* \| \s* | \s+ ) | (?<invalid> \S+ )
    (?(DEFINE) (?<EXPRESSION> $expression_re ) )
}msx;

my $compile_quoted = sub {
    my($match) = @_;
    my $quote  = $match->{quote};
    (my $string = $match->{string}) =~ s/[$quote]{2}/$quote/g;
    return qr{^\Q$string\E$};
};

my %compile_word = (
    q[']    => $compile_quoted,
    q["]    => $compile_quoted,
    q[]     => sub { qr{^\Q$_[0]{string}\E$} },
    q[{]    => sub {
        my($match) = @_;
        my $regex = _validate_regex( $match->{regex}, $match->{string_re_match} );
        my $mod = $match->{mod};
        my $ret;
        eval { $ret = qr/(?$mod:$regex)/; 1; } or do{
            my $e = $@;
            croak "Error compiling regex pattern $match->{string_re_match} in selector:\n$e";
        };
        return $ret;
    },
    q{[} => sub {
        my ( $match ) = @_;
        my $glob  = _validate_glob( $match->{glob}, $match->{string_re_match} );
        my $regex;
        eval {
            # we are not matching paths so we don't need these!
            local $Text::Glob::strict_leading_dot    = 0;
            local $Text::Glob::strict_wildcard_slash = 0;
            # compile the regex
            $regex = glob_to_regex($glob);
            # make sure we return true if we didn't already die
            1;
        }
        or do {
            my $e = $@;
            croak "Error compiling glob pattern $match->{string_re_match} in selector:\n$e";
        };
        return $regex;
      },
);

my $compile_method_check = sub {
    state $method_for_sigil = +{
        q{#} => q/id/,
    };
    my ( $match ) = @_;
    my ( $m, $n, $c, $v) = map {; $_ // "" } @{$match}{qw[method not cmp value]};
    $c ||= '=~';
    $m ||= $method_for_sigil->{$match->{sigil}};
    if ( length $v ) {
        return qq{ ( $n( \$e->can('$m') and (\$e->$m $c $v) ) ) };
    }
    else {
        return qq{ ( $n\$e->can('$m') ) };
    }
};

my $compile_kv_check = sub {
    state $key_for_sigil = +{
        q{.} => q{/^class$/},
    };
    my($match) = @_;
    $match->{check_keyvals} = 1;
    $match->{key} //= $key_for_sigil->{$match->{sigil}};
    my($k, $v, $n, $c, $o) = map {; $_ // "" } @{$match}{qw[key value not cmp op]};
    for my $x ( [ \$k, \$o ], [ \$v, \$c ] ) {
        ${$x->[1]} ||= '=~';
        if ( length ${$x->[0]} ) {
            ${$x->[0]} = qq{ \$_ ${$x->[1]} ${$x->[0]} };
        }
    }
    if ( length $v ) {
        return qq{
            (   $n(
                    do {
                        my \$hits = 0;
                        for my \$key ( grep { $k } \@keys ) {
                            \$hits += ( grep { $v } \$kv->get_all( \$key ) );
                        }
                        !!\$hits;
                    }
                )
            )
        };
    }
    else {
        return qq{
            ( $n(!!(grep { $k } \@keys )))
        };
    }
};

my %compile_expression = (
    q{:} => sub {
        my ( $match ) = @_;
        my $t         = "is_$match->{type}";
        my $n         = $match->{not};
        return qq{ ( $n(\$e->$t) ) };
    },
    q{} => sub {
        my ( $match ) = @_;
        my ( $n, $v ) = @{$match}{qw[not value]};
        return qq{ ( $n(\$e->name =~ $v) ) };
    },
    q{&} => $compile_method_check,
    q{#} => $compile_method_check,
    q{.} => $compile_kv_check,
    q{%} => $compile_kv_check,
);

sub _compile_selector {
    my($string) = @_;
    my(@selectors, $check_keyvals);
    while ( $string =~ /\G$selector_re/gc ) {
        my %match = %+;
        my @pos = @-;
        if ( length $match{invalid} ) {
            my $fill = substr $string, 0, $pos[2];
            $fill =~ s{ \X }{ }gx;
            chomp $string;
            croak "Invalid expression in selector marked by '^':\n\n$string\n$fill^\n";
        }
        push @selectors, $match{selector}
    }
    for my $selector ( @selectors ) {
        my $_check_kvs;
        ($selector, $_check_kvs) = _compile_expressions($selector);
        $check_keyvals ||= $_check_kvs;
    }
    my $selectors_code = join qq{ )\nor( }, @selectors;
    (my $keyvals_code = $check_keyvals ?
        q{
        ;;;        $e->can('keyvals') or return !!0;
        ;;;        my $kv = $e->keyvals;
        ;;;        my @keys = $kv->keys;
        ;;;}
        : "") =~ s/^\s*;;;//gm;
    my $code = qq{ \$sub = sub {
        no warnings qw[ uninitialized numeric ];
        my(\$e) = \@_;
        $keyvals_code
        return( ( $selectors_code ) ); };
        1;
    };
    my $sub;
    local $@;
    eval($code) || do {
        my $e = $@;
        croak "Error compiling selector:\n$string\n\n$code\n\n$e\n";
    };
    return $sub;
}

sub _compile_expressions {
    my( $selector ) = @_;
    my( @expressions, $check_keyvals );
    while( $selector =~ /\G$expression_re/gc ) {
        my $match = +{ %+ };
        for my $key ( qw[ key value ] ) {
            next unless defined $match->{$key};
            next unless $match->{$key} =~ /$word_re/;
            $match->{$key} = $compile_word{$+{quote}}->(+{ %+ });
            $match->{$key} = "m/$match->{$key}/"
        }
        for my $cmp ( qw[ cmp op ] ) {
            $match->{$cmp} // next;
            $match->{$cmp} ||= '=~';
            $match->{$cmp} =~ s/^\~/=~/;
            $match->{$cmp} =~ s/^=(?![=~])/==/;
        }
        if ( $match->{num} ) {
            ## Ensure decimal interpretation!
            $match->{num} =~ s/^\-?\K0+(?=\d)//;
        }
        $match->{value} ||= $match->{num};
        push @expressions, $compile_expression{ $match->{sigil} }->($match);
        $check_keyvals //= $match->{check_keyvals};
    }
    return _crunch( join q{ and }, @expressions), $check_keyvals;
}

sub _crunch {
  my($text) = @_;
  $text =~ s{\s+}{ }g; # crunch ws
  $text =~ s{\A\s+}{}; # trim ws before
  $text =~ s{\s+\z}{}; # trim ws after
  return $text;
}

sub _check_unbalanced_braces {
    my($string, $ctx, $pattern) = @_;
    $ctx //= $string;
    $pattern //= 'pattern';
    $string =~ m{$unbalanced_braces_re} or return;
    exists $+{unbalanced} and croak _crunch(
        qq{Unbalanced unescaped "$+{unbalanced}" in selector $pattern "$ctx".
            Please check that you didn't omit a "$oppos{$+{unbalanced}}"
            or use escaped "\\$+{unbalanced}" instead!});
}

sub _validate_regex {
    state $interpol_re = qr{
        (?&unescaped)
        (?<interp> (?<sigil> [\@\$] ) (?: (?&maybe) | \w+ ) )
        (?(DEFINE)
            $unescaped_re
            $balanced_braces_re
            (?<maybe> # maybe balanced braces
                \{ (?: (?: [^\{\}\\]*+ (?: \\. [^\{\}\\]*+ )*+ | (?&balanced_braces) )* \} )?
            )
        )
    }msx;
    _check_unbalanced_braces(@_, 'regex');
    my($regex, $ctx) = @_;
    $ctx //= $regex;
    # don't allow interpolation in regexes!
    $regex =~ m{$interpol_re} and croak _crunch(
        qq{Interpolation of $+{interp} not supported in selector regex "$ctx".
            If you meant to match "$+{sigil}" please use "\\$+{sigil}"!});
    # escape slashes so we can eval /$regex/ safely!
    $regex =~ s{(?<!\\)(?:\\\\)*\K/}{\\/}g;
    return $regex;
}

sub _validate_glob {
    _check_unbalanced_braces(@_, 'glob pattern');
    return $_[0];
}

use Try::Tiny;

while ( <> ) {
    chomp;
    ddp my $sub = try { _compile_selector($_) } catch { $_ };
}

#!/usr/bin/env perl

# Proposed Pandoc::Elements extended selector expression syntax
#
# VERSION 201804171405
#
# You can test the syntax by running this script and typing selectors to STDIN.
# The selector will be compiled and the compiled subroutine or any error message
# will be printed to STDOUT.

# use utf8;      
use utf8::all;
use autodie 2.26;
use 0.510001;     
use strict;    
use warnings;  
use warnings  qw(FATAL utf8);    
# use open      qw(:std :utf8);    
# use charnames qw(:full :short);  

use Carp               qw[ carp croak confess cluck     ];

use Data::Printer deparse => 1, alias => 'ddp', output => 'stdout';

my $string_re = qr{
    (?:
        (?<quote> '   ) (?<string>  [^']*   (?: ''  [^']*   )* ) '
    |   (?<quote> "   ) (?<string>  [^"]*   (?: ""  [^"]*   )* ) "
    |   (?<quote> [{] ) (?<regex>   (?&REGEX)                  ) [}] (?<mod> \w* )
    |   (?<quote>     ) (?<string>  \b\w+\b )
    )
    (?(DEFINE)
        (?<REGEX>
            (?:
                [^\{\}\[\]\\]+                      # 'normal' characters
            |   \\.                                 # or backslash escapes
            |   \[ \]? [^\]]* (?: \\. [^\]]* )* \]  # or character classes
            |   [{] (?&REGEX) [}]                   # or nested balanced braces
            )*
        )
    )
}msx;

my $expression_re = qr{^$string_re$};

my $clause_re = qr{
    (?<not> \!? )
    (?:
        (?<sigil> \: )                                  (?<type>  document|block|inline|meta)
    |   (?<sigil> \& )  (?<method> (?&ID)  )     (?<cmp> (?&CMP) ) (?<num>   (?&NUM)    )
    |   (?<sigil> \& )  (?<method> (?&ID)  ) (?: (?<cmp> (?&OP)  ) (?<value> (?&STRING) ) )?
    |   (?<sigil> \% )  (?<key> (?&STRING) )     (?<cmp> (?&CMP) ) (?<num>   (?&NUM)    )
    |   (?<sigil> \% )  (?<key> (?&STRING) ) (?: (?<cmp> (?&OP)  ) (?<value> (?&STRING) ) )?
    |   (?<sigil> \# )                                             (?<value> (?&STRING) )
    |   (?<sigil> \. )                                             (?<value> (?&STRING) )
    |   (?<sigil>    )                                             (?<value> (?&STRING) )
    )
    \s* 
    (?(DEFINE)
        (?<ID> (?!\d) \w+ )
        (?<STRING> $string_re )
        (?<NUM> -?\b[0-9]+(?: \. [0-9]+\b )? )
        (?<CMP> [\!\=]?\= | [\<\>]\=? )
        (?<OP>  [\!\=]?\~ )
    )
}msx;

my $selector_re = qr{
    \s* (?<selector> (?&CLAUSE)+ ) \s* (?: \| \s* | \z ) | (?<invalid> \S+ )
    (?(DEFINE) (?<CLAUSE> $clause_re ) )
}msx;

my $compile_quoted = sub {
    my($match) = @_;
    my $quote  = $match->{quote};
    (my $string = $match->{string}) =~ s/[$quote]{2}/$quote/g;
    # ddp $string;
    return qr{^\Q$string\E$};
};

my %compile_expression = (
    q[']    => $compile_quoted,
    q["]    => $compile_quoted,
    q[]     => sub { qr{^\Q$_[0]{string}\E$} },
    q[{]    => sub {
        my($match) = @_;
        my $regex = $match->{regex};
        my $mod = $match->{mod};
        my $ret;
        $regex =~ s{\\(.)|([\$\@\/])}{\\$+}g;
        eval { $ret = qr/(?$mod:$regex)/; 1; } or do{
            my $e = $@;
            croak "Error compiling regex in selector:\n$e";
        };
        return $ret;
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
        q{.} => q/^class$/,
    };
    my($match) = @_;
    $match->{key} //= $key_for_sigil->{$match->{sigil}};
    my($k, $v, $n, $c) = map {; $_ // "" } @{$match}{qw[key value not cmp]};
    $c ||= '=~';
    if ( length $v ) {
        $v = qq{ \$_ $c $v };
    }
    if ( length $v ) {
        return qq{
            (   $n(
                    \$e->can( 'keyvals' ) and do {
                        my \$kv   = \$e->keyvals;
                        my \$hits = 0;
                        for my \$key ( grep { /$k/ } \$kv->keys ) {
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
            ( $n( \$e->can( 'keyvals' ) and !!(grep { /$k/ } \$e->keyvals->keys)))
        };
    }
};

my %compile_clause = (
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
    my @selectors;
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
        $selector = _compile_clauses($selector);
    }
    my $selectors_code = join qq{ )\nor( }, @selectors;
    my $code = qq{ \$sub = sub { my(\$e) = \@_; return( ( $selectors_code ) ); }; 1; };
    my $sub;
    local $@;
    eval($code) || do {
        my $e = $@;
        croak "Error compiling selector:\n$string\n\n$code\n\n$e\n";
    };
    return $sub;
}

sub _compile_clauses {
    my( $selector ) = @_;
    my @clauses;
    while( $selector =~ /\G$clause_re/gc ) {
        my $match = +{ %+ };
        for my $key ( qw[ key value ] ) {
            next unless defined $match->{$key};
            next unless $match->{$key} =~ /$expression_re/;
            $match->{$key} = $compile_expression{$+{quote}}->(+{ %+ });
        }
        if ( $match->{cmp} ) {
            $match->{cmp} =~ s/^\~/=~/;
            $match->{cmp} =~ s/^=(?![=~])/==/;
        }
        if ( $match->{num} ) {
            ## Ensure decimal interpretation!
            $match->{num} =~ s/^0+(?=\d)//;
        }
        $match->{value} &&= "/$match->{value}/";
        $match->{value} ||= $match->{num};
        push @clauses, $compile_clause{ $match->{sigil} }->($match);
    }
    return join 'and', @clauses;
}

 
use Try::Tiny;

while ( <> ) {
    chomp;
    ddp my $sub = try { _compile_selector($_) } catch { $_ };
}

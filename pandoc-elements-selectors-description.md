---
title: 'Proposed Pandoc::Elements extended selector expression syntax'
abstract: |
    Proposed Pandoc::Elements extended selector expression syntax, with
    parser and compiler in Perl
author: 'Benct Philip Jonsson \<bpjonsson\@gmail.com\>'
copyright: '\(c) 2017- Benct Philip Jonsson'
date: '2018-04-17'
script_name: 'pandoc-elements-selectors-parser.pl'
monofontoptions:
- 'Scale=0.7'
style: BPJ
---


# NAME

Proposed Pandoc::Elements extended selector expression syntax

# VERSION

201804181800

# DESCRIPTION

Proposed Pandoc::Elements extended selector expression syntax

# PREREQUISITES

  - perl v5.10.1

# SELECTOR EXPRESSIONS

Selectors are strings which contain one or more *subselectors*, each of
which contains one or more *selector expressions*. Selector expressions
are a small,declarative domain-specific language (DSL).

Subselectors are separated by pipes (`|`). Selector expressions are
separated by whitespace, which is optional except as it is needed to
separate tokens.

Each expression has one of the forms described below, where words
enclosed in angle brackets (`<...>`) are placeholders and square
brackets (`[...]`) enclose parts which are optional; these brackets
themselves should not appear in the actual expressions, unlike the curly
brackets (`{...}`) enclosing regular expressions, which *are* part of
the actual selector syntax.

## Sigils and operators

The characters `: # . & %` are used at the beginning of selector
expressions to indicate which kind of element property to match against.
They are described below.

With some properties you can specify a value to compare to the property
value, along with an operator specifying the kind of comparison to
perform. These comparison operators are:

``` 
   Operator  True if a property value...
  ---------- ----------------------------------------------------------
   ~ or =~   ...matches a regex or equals a string.
      !~     ...does not match a regex or is different from a string.
   = or ==   ...is equal to a number.
      !=     ...is not equal to a number.
      <      ...is less than a number.
      <=     ...is less than or equal to a number.
      >      ...is greater than a number.
      >=     ...is greater than or equal to a number.
```

Those operators which compare to a number must be followed by a
[`<number>`](#number).

## Negation

In addition to negated operators `!~` and `!=` you can prefix an entire
selector expression with a `!`. This reverses the truth value of the
expression:

``` 
  Example        True if the element...
  -------------- ----------------------------------------------------------------------------
  .foo           ...has a class "foo".
  !.foo          ...does not have a class "foo".
  %foo~bar       ...has an attribute "foo" with the value "bar".
  !%foo~bar      ...does not have an attribute "foo" with the value "bar".
  &url~{^ftp}    ...has a method url() which returns a value starting with "ftp".
  !&url~{^ftp}   ...does not have a method url() which returns a value starting with "ftp".
```

Note that in the last two negated expressions it doesn’t make a
difference whether the element lacks those properties or has them with
another value.

## Placeholders

The following placeholders which occur repeatedly require some
explanation:

### `<number>`

A decimal (base 10) number, possibly with a leading minus (`-`) and
possibly with a fractional part.

These are all valid:

    0
    1
    23
    123
    0.1
    0.12
    1.23
    1.0
    123.45
    123.0
    0.0
    -23
    -123
    -0.1
    -0.12
    -1.23

### `<string>`

### `<key>`

### `<value>`

An arbitrary string delimited by single (`'...'`) or double (`"..."`)
quotes. The string inside the quotes must match literally in its
context.

To include a quote of the same type you should escape it by doubling.
This escaping mechanism is orthogonal to, and should be used in addition
to, Perl’s escaping with backslashes. Thus to select an element with an
attribute `foo` which has the value `don't` you may type either of the
following:

``` perl
"%foo~'don''t'"

"%foo~\"don't\""

'%foo~"don\'t"'

'%foo~\'don\'\'t\''
```

### `{<regex>}`

### `{<regex>}<modifiers>`

`<regex>` is a Perl regular expression, and `<modifiers>` are any
modifiers which are valid with the Perl `qr//` operator.

#### Regex gotchas

  - Note that any interpolation of variables or double-quotish escapes
    must be handled through an ‘outer’ Perl doublequoted string (`"..."`
    or `qq{...}`) enclosing the entire selector:
    
    ``` perl
    "%foo~{$bar\N{DOLLAR SIGN}$baz}"    # RIGHT
    
    qq{%foo~{$bar\x{24}$baz}}           # RIGHT
    
    '%foo~{$bar\N{DOLLAR SIGN}$baz}'    # WRONG
    
    q{%foo~{$bar\x{24}$baz}}            # WRONG
    ```

  - Note the distinction between double-quoted string escapes like
    these:
    
    ``` perl
    "\t \n \r \f \a \e \cK \x{0} \x00 \N{name} \N{U+263D} \o{0} \000 \l \u \L \U \Q \E"
    ```
    
    and regex escapes like these which must be typed with a double
    backslash as shown when used in a selector in a double quoted
    string:
    
    ``` perl
    qr{  \w   \W   \s   \S   \d   \D   \pL   \PL   \X   \1   etc.  \g{1}   }
    qq{  \\w  \\W  \\s  \\S  \\d  \\D  \\pL  \\PL  \\X  \\1  etc.  \\g{1}  }
    
    qr{  \k<name>   \K   \N   \v   \V   \h   \H   \R   \b   \B   \A   \Z   \z   }
    qq{  \\k<name>  \\K  \\N  \\v  \\V  \\h  \\H  \\R  \\b  \\B  \\A  \\Z  \\z  }
    
    "%foo~{$foo\\s+$bar}"   # RIGHT
    
    "%foo~{$foo\s+$bar}"    # WRONG == qr/${foo}s+$bar/ !
    ```
    
    Note also the distinction between `\N{name} \N{U+263D}` on the one
    hand and `\N` without a following charname in curly brackets: the
    latter is the regex escape which matches the complement of `\n`\!

### `<num-op>`

One of the numeric comparison operators `=` or `==`, `!=`, `<`, `<=`,
`>`, or `>=` as described under [Sigils and
operators](#sigils-and-operators) above.

### `<match-op>`

One of the match operators `~` or `=~` or `!~` as described under
[Sigils and operators](#sigils-and-operators) above.

## Selector types

### Select by element name

#### `[!]<string>`

#### `[!]{<regex>}[<modifiers>]`

This is the simplest expression, matching an element type name like
`Para`, `Code`, `CodeBlock` or `Span`.

For a match the `<string>` must be equal to the `name` property of an
element literally.

For a match the `<regex>` must match the `name` property of an element.
For example `{^Code}` will match both `Code` and `CodeBlock` elements.

### Select by element type

#### `[!]:document|block|inline|meta`

True if the element is a document object, a block element, an inline
element or a metadata element respectively, as determined by the return
value of calling the is\_document(), is\_block(), is\_inline() or
is\_meta() method on it respectively.

Examples:

    ':document'
    ':block'
    ':inline'
    ':meta'

### Select by element id

#### `[!]#<string>`

#### `[!]#{<regex>}[<modifiers>]`

True if the element has an id() method and the value returned by that
method is equal to `<string>` or matches the `<regex>`.

Examples:

    '#myid'
    '#"my-id"'
    '#{^diagram-}'

### Select by class

#### `[!].<string>`

#### `[!].{<regex>}[<modifiers>]`

True if the element has a class() attribute and one or more of the
classes is equal to `<string>` or matches the `<regex>`.

### Select by element method

#### `[!]&<method>`

True if the element object has a method `<method>`, as determined with
`$e->can($method)`.

Examples:

    '&url'      # same as 'Link|Image'
    '&format'   # same as 'RawBlock|RawInline'
    '&attr'     # same as a rather long list...

#### `[!]&<method><match-op><string>`

#### `[!]&<method><match-op>{<regex>}[<modifiers>]`

True if the element has a method `<method>`, and the return value is
equal to `<string>` or matches `<regex>`.

Note that you probably don’t want to use this with methods which don’t
return strings\!

Examples:

    '&format~latex'
    '&title!~{Wikipedia}'

#### `[!]&<method><num-op><number>`

Compares the return value of `<method>` against `<number>` using the
numeric operator `<num-op>`.

Examples:

    '&level==4'
    '&level!=4'
    '&level<4'
    '&level<=4'
    '&level>4'
    '&level>=4'

### Select by element attribute

#### `[!]%<attr-name>`

True if the element has an attribute `<attr-name>` accessible through
`$e->keyvals->{$attribute}`; in other words it includes `id` and `class`
but not e.g. `title` (unless you have said `[foo](bar
"baz"){title="quux"}` which will be rendered by Pandoc as `<p><a
href="bar" title="quux" title="baz">foo</a></p>` and probably confuse
your browser).

Examples:

    '%width'
    '%height'
    '%lang'

#### `[!]%<attr-name><match-op><value-string>`

#### `[!]%<attr-name><match-op>{<value-regex>}[<modifiers>]`

True if the element has an attribute `<attr-name>`, the value of which
is equal to `<value-string>` or matches `<value-regex>`.

Examples:

    '%lang~sv'
    '%width!~{cm$}'
    '%"custom-style"!~Foo'

#### `[!]%<name-match-op><name-string>`

#### `[!]%<name-match-op><name-string><value-match-op><value-string>`

#### `[!]%<name-match-op><name-string><value-match-op>{<value-regex>}[<modifiers>]`

Similar to the above, except that you can specify a match operator
indicating how the `<name-string>` shall be compared to attribute names.

Examples:

  - `'%!~class'`

Selects elements which have one or more attributes which do *not* have
the name `class`.

  - `'%=~class !%id'`

Selects elements which have at least one class and no id attribute.

  - `'%!~class %class!~{^foo}'`

Selects elements which have at least one non-`class` attribute and no
class which starts with `foo`.

Note that this is most useful with the `!~` (no-match) operator.
`%<attr-name>` and `%~<attr-name>` are just shorthand for
`%=~<attr-string>` so there is no real reason not to use the shortest
form.

The difference between `!%<attr-name>` and `&!~<attr-name>` is that the
former is true both when the element doesn’t have any attributes and
when it has one or more attributes with other names, while the latter is
true when the element has one or more attributes with other names, but
false if the element doesn’t have any
attributes.

#### `[!]%[<name-match-op>]{<name-regex>}[<modifiers>]`

#### `[!]%[<name-match-op>]{<name-regex>}[<modifiers>]<value-match-op><value-string>`

#### `[!]%[<name-match-op>]{<name-regex>}[<modifiers>]<value-match-op>{<value-regex>}[<modifiers>]`

Similar to the above but the *attribute names* are matched against a
regex. A match operator may optionally be inserted between the `%` and
the name regex, but again the absence of a match operator and the `~`
operator are just shorthand for the `=~` operator, and the same
difference between `!%{<name-regex>}` and `%!~{<name-regex>}` applies,
namely that the latter requires there to be at least one attribute with
a name which doesn’t match the regex.

Examples:

    '%{^data-}'
    '%!~{width|height}=~{^[0-9]}'

#### `[!]%[<name-match-op>]<attr-name><num-op><number>`

#### `[!]%[<name-match-op>]{<name-regex>}[<modifiers>]<num-op><number>`

Compares the value of attributes with matching names against `<number>`
using the numeric operator `<num-op>`.

Examples:

    '%width==192'
    '%width!=192'
    '%width<192'
    '%{^data-}>1'
    '%{width|height}>=500

# AUTHOR

Benct Philip Jonsson (bpjonsson@gmail.com, <https://github.com/bpj>)

# COPYRIGHT

Copyright 2017- Benct Philip Jonsson

# LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself. See
<http://dev.perl.org/licenses/>.

# SEE ALSO

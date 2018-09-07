---
title: 'Proposed Pandoc::Elements extended selector expression syntax'
abstract: |
    Proposed Pandoc::Elements extended selector expression syntax, with
    parser and compiler in Perl
author: 'Benct Philip Jonsson \<bpjonsson\@gmail.com\>'
copyright: '\(c) 2017- Benct Philip Jonsson'
version: 201809072000
date: '2018-09-07'
monofontoptions:
- 'Scale=0.7'
script_name: 'pandoc-elements-selectors-parser.pl'
style: POD
---

# NAME

Proposed Pandoc::Elements extended selector expression syntax

# VERSION

201809072000

# DESCRIPTION

Proposed Pandoc::Elements extended selector expression syntax

# PREREQUISITES

-   perl v5.10.1

# DESIGN PRINCIPLES

-   Stay backwards compatible with the existing selector syntax of
    Pandoc::Elements.

-   Since in the existing Pandoc::Elements selector syntax the
    difference between selection by element name and selection by
    element type (document, block, inline or meta) is indicated by
    prefixing the selector expression for the latter with a colon, new
    selector expression types have been indicated by punctuation
    character prefixes (hereafter "sigils") as well.
-   Since in the existing Pandoc::Elements selector syntax the
    difference between selection by element name and selection by
    element type (document, block, inline or meta) is indicated by
    prefixing the selector expression for the latter with a colon, new
    selector expression types have been indicated by punctuation
    character prefixes (hereafter "sigils") as well.

-   Base extended syntax on well-known models where possible. Thus
    operators and sigils have been borrowed from other languages like
    Pandoc's own element attribute syntax (which in turn is based on
    CSS), Bash and Perl.

-   Use distinct meta characters for distinct purposes.

-   Since the extended selector syntax supports embedded regular
    expressions (hereafter "regexes") and glob patterns (hereafter
    "globs") an attempt has been made to avoid confusion between
    extended selector syntax meta characters and regex or glob meta
    characters. Thus punctuation characters which are not regex or glob
    meta characters or at least less commonly used in regexes and globs
    have been preferred as meta characters in the extended selector
    syntax.

    Note that curly brackets (braces) `{...}` have been chosen to
    delimit regexes because brace quantifiers are probably less common
    in regexes than character classes, especially in the current
    context: something like `[Cc]ontainer` is probably more likely to
    occur than something like `x{,3}large` when looking for attribute
    values.[^1]

    In the same vein square brackets `[...]` have been chosen to delimit
    glob patterns because glob character classes (which in the absence
    of quantifier operators are a good deal less useful than regex
    character classes) are probably less common than alternations
    (`{...,...}`) in glob patterns.

    The use of `.` as a sigil for class names was retained despite the
    importance of the dot as regex meta character because the precedence
    of CSS and in particular Pandoc itself was deemed more important in
    this case.

[^1]: For the record slashes (`/.../`) were rejected as regex delimiters
    because it is probably easier to forget to backslash-escape a slash
    inside a regex than to forget a closing bracket-type delimiter, and
    braces are probably more uncommon than slashes (which are used in
    dates and fractions for example} so that backslashes can usually be
    avoided entirely, even though the possibility to choose custom
    delimiters like in Perl isn't available.

# SELECTOR EXPRESSIONS

Selectors are strings which contain one or more *subselectors*, each of
which contains one or more *selector expressions*. Selector expressions
are a small, declarative, domain-specific language (DSL).

Subselectors are separated by pipes (`|`). Selector expressions are
separated by whitespace. (Such whitespace used to be optional except as
it was needed to separate tokens, but it was found that this would cause
faulty parses more often than had been expected, so whitespace between
selec tor expressions within a subselector is *not* optional anymore!)

Subselectors stand in an `OR` relation to each other, so that a selector
selects the union of elements selected by its subselectors, while
selector expressions stand in an `AND` relation to each other, so that a
subselector selects the intersection of the elements selected by its
constituent selector expressions. Thus

-   `.foo &url` is a selector with one subselector with two selector
    expressions which matches elements which have a class `foo` *and*
    have a property `url`.

-   `.foo|&url` is a selector with two subselectors with one selector
    expression each, which matches elements which have a class `foo`
    *or* a property `url` (or both).

-   `Code .perl|Link &url~{perldoc}` is a selector with two subselectors
    with two selector expressions each, which matches Code elements with
    a class `perl` or Link elements whose `url` property has a value
    containing `perldoc`.

Each expression has one of the forms described below, where words
enclosed in angle brackets (`<...>`) are placeholders and parentheses
(`(...)` "round brackets") enclose parts which are optional; these
brackets themselves should not appear in the actual expressions, unlike
the curly brackets (`{...}`) enclosing regular expressions and the
square brackets (`[...]`) enclosing glob patterns, which *are* part of
the actual selector syntax.

## Sigils and operators

The characters `: # . & %` are used at the beginning of selector
expressions to indicate which kind of element property or attribute to
match against. They are described below.

With some properties you can specify a value to compare to the property
value, along with an operator specifying the kind of comparison to
perform. These comparison operators are:

       Operator  True if a property value...
      ---------- -------------------------------------------------------------
       ~ or =~   ...matches a regex or glob or equals a string.

          !~     ...does not match a regex/glob or is different from a string.

       = or ==   ...is equal to a number.

          !=     ...is not equal to a number.

          <      ...is less than a number.

          <=     ...is less than or equal to a number.

          >      ...is greater than a number.

          >=     ...is greater than or equal to a number.
      ------------------------------------------------------------------------

Those operators which compare to a number must be followed by a
[`<number>`][].

  [`<number>`]: #number

## Negation

In addition to negated operators `!~` and `!=` you can prefix an entire
selector expression with a `!`. This reverses the truth value of the
expression:

      Example        True if the element...
      -------------- -----------------------------------------------------------
      .foo           ...has a class "foo".

      !.foo          ...does not have a class "foo".

      %foo~bar       ...has an attribute "foo" with the value "bar".

      !%foo~bar      ...does not have an attribute "foo" with the value "bar".

      &url~[ftp*]    ...has a property `url`
                            which has a value starting with "ftp".

      !&url~[ftp*]   ...does not have a property `url`
                            which has a value starting with "ftp".

      &url~{^ftp}    ...has a property `url`
                            which has a value starting with "ftp".

      !&url~{^ftp}   ...does not have a property `url`
                            which has a value starting with "ftp".
      --------------------------------------------------------------------------

Note that in the last two negated expressions it doesn't make a
difference whether the element lacks those attributes or properties or
has them with another value.

## Placeholders

The following placeholders which occur repeatedly in the syntax
description below require some explanation:

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

No number will ever be treated as an octal integer no matter how many
leading zero characters it has, since "excess" leading zeroes will be
removed before making calculations based on the number. The exception is
the number 0 itself which perl theoretically treats as octal, but which
practically coincides with decimal 0.

### `<string>`, `<key>`, `<value>`, `<name>`

An arbitrary string, either unquoted and consisting of word (`\w`)
characters (alphanumerics -- possibly in the Unicode sense -- plus the
underscore (`_` U+005F) --, possibly with internal hyphens (`-` U+002D),
or quoted, i.e.delimited by single (`'...'` U+0027) or double (`"..."`
U+0022) quotes. The unquoted "word" or string inside the quotes must
match literally in its context.

To include a quote of the same type you should escape it by doubling.
This escaping mechanism is orthogonal to, and should be used in addition
to, Perl's escaping with backslashes. Thus to select an element with an
attribute `foo` which has the value `don't` you may type either of the
following:

```perl
"%foo~'don''t'"

"%foo~\"don't\""

'%foo~"don\'t"'

'%foo~\'don\'\'t\''
```

### `[<glob>]`

Here `<glob>` is a [glob pattern][] which will be converted into a Perl
regular expression with [Text::Glob][], [which see][] for the exact
syntax supported, and then matched against a string. Glob syntax may be
easier to use than regular expressions, especially where selectors are
supplied by filter users who may not be programmers themselves and thus
don't know regex syntax but may know glob syntax from using the command
line.

  [glob pattern]: https://en.wikipedia.org/wiki/Glob_(programming)
  [Text::Glob]: https://metacpan.org/pod/Text::Glob {pod="Text::Glob"}
  [which see]: https://metacpan.org/pod/Text::Glob#SYNTAX
  {pod="Text::Glob/SYNTAX"}

Even though glob patterns are converted into regexes no modifiers are
currently supported; however I'm considering to support the `i` (case
insensitive) modifier for globs. Upvotes, downvotes or comments are
welcome [at the GitHub issue for this feature][].

  [at the GitHub issue for this feature]: https://github.com/bpj/pandoc-elements-selectors/issues/4

#### Glob gotchas

-   Since the strings matched against in a selector context are usually
    *not* Unix file system paths leading periods (`.`) and forward
    slashes (`/`) are *not* treated specially. (I.e. the [Text::Glob][]
    configuration variables `$Text::Glob::strict_leading_dot`
    `$Text::Glob::strict_wildcard_slash` are both set to a false value
    while compiling globs into regexes.

-   There is one situation where direct regex matching may be preferable
    even for non-technical users, namely where one wants to match an
    alphanumeric literal anywhere in a string: `{bar}` will match e.g.
    `foobar`, `barbaz` and `foobarbaz` as well as `bar`. By comparison
    glob patterns are implicitly anchored at the beginning and end of
    the string: `[bar]` will match only the exact string `bar`; to also
    match `foobar` one will have to use `[*bar]`, to also match `barbaz`
    one will have to use `[bar*]`, and to match all three plus
    `foobarbaz` one will have to use `[*bar*]`.

-   The wildcards `*` and `?` match any characters whatever. Sometimes
    this is just what you want: `%[data-*]` will match any HTML 5 custom
    data attribute name, but when you want to restrict the possible
    matches you will have to use comma-separated alternatives in curly
    brackets. To return to the example above `[*bar*]` will match
    *anything* with `bar` in the front, middle or end! To only match
    `bar`, `foobar`, `barbaz` or `foobarbaz` you have to use
    `[{foo,}bar{baz,}]` where `{foo,}` will match only `foo` or nothing
    and `{baz,}` will match only `baz` or nothing. Here note especially
    that "nothing" (technically an empty substring) is a valid
    alternative. A more practical example might be where you want to
    match either an inline code element or a code block: the subselector
    `[Code{Block,}] .perl` will match all Code or CodeBlock elements
    with a class `perl`. In practice `[Code*] .perl` is probably safe
    enough, as it is unlikely that Pandoc will introduce another element
    type with a name starting with "Code", but it never hurts to be as
    safe as possible! Another example:
    `[Raw{Block,Inline}] &format~[{la,}tex]` will match block and inline
    raw markup elements with the format `tex` or `latex` and nothing
    else (and since Pandoc's Markdown reader chooses seemingly randomly
    between `tex` and `latex` as format name when parsing raw LaTeX this
    is what you usually want to use!)

-   Unlike real shell glob patterns [Text::Glob][] does support
    backslash escaping to some extent. You can for example use `\{` to
    match a literal `{`. It does however not *output* all backslash
    escaped inputs as backslash escaped. I haven't probed the
    particulars and/or limits of this.

-   As of [Text::Glob][] version 0.11 a pattern with an unbalanced,
    unescaped `{` or `}` as for example `[{foo]` will be compiled into
    an invalid regex pattern. Since the error message caused by this may
    be cryptic to non-technical users the selector parser checks for
    unbalanced unescaped braces in glob patterns and throws a hopefully
    more informative error message, including suggesting to escape the
    brace with a backslash, if it finds any. If you run into problems
    with this please open an issue on the [GitHub issue tracker][]!

  [Text::Glob]: https://metacpan.org/pod/Text::Glob {pod="Text::Glob"}
  [GitHub issue tracker]: https://github.com/bpj/pandoc-elements-selectors/issues/

### `{<regex>}`

### `{<regex>}<modifiers>`

`<regex>` is a Perl regular expression, and `<modifiers>` are any
(optional) modifiers which are valid with the Perl `qr//` operator.

Non-technical users who are unfamiliar with regular expressions may want
to read the Perl regular expressions quick-start [perlrequick][], and
perhaps also the Perl regular expressions tutorial [perlretut][].

  [perlrequick]: https://metacpan.org/pod/perlrequick
  {pod="perlrequick"}
  [perlretut]: https://metacpan.org/pod/perlretut {pod="perlretut"}

#### Regex gotchas

-   Note that any interpolation of variables or double-quotish escapes
    must be handled through an 'outer' Perl doublequoted string (`"..."`
    or `qq{...}`) enclosing the entire selector:

    ```perl
    "%foo~{$bar\N{DOLLAR SIGN}$baz}"    # RIGHT

    qq{%foo~{$bar\x{24}$baz}}           # RIGHT

    '%foo~{$bar\N{DOLLAR SIGN}$baz}'    # WRONG

    q{%foo~{$bar\x{24}$baz}}            # WRONG
    ```

-   Note the distinction between double-quoted string escapes like
    these:

    ```perl
    "\t \n \r \f \a \e \cK \x{0} \x00 \N{name} \N{U+263D} \o{0} \000 \l \u \L \U \Q \E"
    ```

    and regex escapes like these which must be typed with a double
    backslash as shown when used in a selector in a double quoted
    string:

    ```perl
    qr{  \w   \W   \s   \S   \d   \D   \pL   \PL   \X   \1   etc.  \g{1}   }
    qq{  \\w  \\W  \\s  \\S  \\d  \\D  \\pL  \\PL  \\X  \\1  etc.  \\g{1}  }

    qr{  \k<name>   \K   \N   \v   \V   \h   \H   \R   \b   \B   \A   \Z   \z   }
    qq{  \\k<name>  \\K  \\N  \\v  \\V  \\h  \\H  \\R  \\b  \\B  \\A  \\Z  \\z  }

    "%foo~{$foo\\s+$bar}"   # RIGHT

    "%foo~{$foo\s+$bar}"    # WRONG == qr/${foo}s+$bar/ !
    ```

    Note also the distinction between `\N{name} \N{U+263D}` on the one
    hand and `\N` without a following charname in curly brackets: the
    latter is the regex escape which matches the complement of `\n`!

### `<num-op>`

One of the numeric comparison operators `=` or `==`, `!=`, `<`, `<=`,
`>`, or `>=` as described under [Sigils and operators][] above.

  [Sigils and operators]: #sigils-and-operators

### `<match-op>`

One of the match operators `~` or `=~` or `!~` as described under
[Sigils and operators][] above.

  [Sigils and operators]: #sigils-and-operators

## Selector types

### Select by element name

#### `(!)<string>`

#### `(!)[<glob>]`

#### `(!){<regex>}(<modifiers>)`

This is the simplest expression, matching an element type name like
`Para`, `Code`, `CodeBlock` or `Span`.

For a match the `<string>` must be equal to the `name` property of an
element literally.

For a match the `<glob>` must match the `name` property of an element.
For example `[Code{Block,}]` will match both `Code` and `CodeBlock`
elements.

For a match the `<regex>` must match the `name` property of an element.
For example `{^Code}` will match both `Code` and `CodeBlock` elements.

### Select by element type

#### `(!):document|(!):block|(!):inline|(!):meta`

True if the element is a document object, a block element, an inline
element or a metadata element respectively, as determined by the value
of the `is_document`, `is_block`, `is_inline` or `is_meta` property of
the element respectively.

Examples:

    ':document'
    ':block'
    ':inline'
    ':meta'

(The `:` character is already used in this way in the existing
Pandoc::Elements selector syntax.)

### Select by element id

#### `(!)#<string>`

#### `(!)#[<glob>]`

#### `(!)#{<regex>}(<modifiers>)`

True if the element has an `id` property and the value of that property
is equal to `<string>` or matches the `<glob>` or `<regex>`.

Examples:

    '#myid'
    '#"my-id"'
    '#{^diagram-}'

(The `#` character is already used as a prefix for element ids in
Pandoc's attribute syntax and CSS selector syntax.)

### Select by class

#### `(!).<string>`

#### `(!).[<glob>]`

#### `(!).{<regex>}(<modifiers>)`

True if the element has a `class` attribute and one or more of the
classes is equal to `<string>` or matches the `<glob>` or `<regex>`.

**Note:** to access the entire HTML-style whitespace-separated `class`
attribute value you should use the `&class` property. However it is
rather tricky to match a single class in the string which is the value
of the `&class` property: you must use a regex like
`{(?<!\S)class-name(?!\S)}`, i.e. the name of the class with negative
lookbehind and lookahead to ensure that it is not preceded or followed
by any non-whitespace character. Note that positive lookaround for
whitespace won't do, since that won't match at the beginning or end of
the string.

(The `.` character is already used as a prefix for class names in
Pandoc's attribute syntax and CSS selector syntax.)

### Select by element property

#### `(!)&<property>`

True if the element object has a property `<property>`.

(Currently determined with `$element->can(PROPERTY)` in the proposed
Perl/Pandoc::Elements implementation).

Examples:

    '&url'      # same as 'Link|Image'
    '&format'   # same as 'RawBlock|RawInline'
    '&attr'     # same as a rather long list...

(The `&` character was chosen as a prefix for properties because in
Pandoc::Elements properties are accessed through accessor methods and
`&` is used as the sigil for subroutines in Perl.)

#### `(!)&<property><match-op><string>`

#### `(!)&<property><match-op>[<glob>]`

#### `(!)&<property><match-op>{<regex>}(<modifiers>)`

True if the element has a property `<property>`, and the value of that
property is equal to `<string>` or matches the `<glob>` or `<regex>`.

Note that you probably don't want to use this with properties whose
values aren't strings! You can always match (most of) the *text* of an
element through the `&string` property which returns a (very plain)
stringification of the element, but think twice before querying the
`&string` property of a whole document, since this will stringify the
whole document, which will consume a great deal of time and resources on
all but the smallest documents.

Examples:

    '&format~latex'
    '&title!~[*Wikipedia*]'
    '&string~{keyword}'

#### `(!)&<property><num-op><number>`

Compares the value of `<property>` against `<number>` using the numeric
operator `<num-op>`.

Examples:

    '&level==4'
    '&level!=4'
    '&level<4'
    '&level<=4'
    '&level>4'
    '&level>=4'

### Select by element attribute

#### `(!)%<attr-name>`

True if the element has an attribute `<attr-name>`.

(Currently determined with `exists $element->keyvals->{$attribute}` in
the proposed Perl/Pandoc::Elements implementation; in other words it
includes `id` and `class` but not e.g. `title` --- unless you have said
`[foo](bar "baz"){title="quux"}` which will be rendered by Pandoc as
`<a href="bar" title="quux" title="baz">foo</a>` and probably confuse
your browser).

Examples:

    '%width'
    '%height'
    '%lang'

(The `%` character was chosen as a prefix for attribute names because it
is used as the sigil for hashes/associative arrays in Perl and thus is
already associated with the concept of key--value pairs.)

#### `(!)%<attr-name><match-op><value-string>`

#### `(!)%<attr-name><match-op>[<value-glob>]`

#### `(!)%<attr-name><match-op>{<value-regex>}(<modifiers>)`

True if the element has an attribute `<attr-name>`, the value of which
is equal to `<value-string>` or matches `<value-regex>`.

Examples:

    '%lang~sv'
    '%width!~{cm$}'
    '%"custom-style"!~Foo'

#### `(!)%<name-match-op><name-string>`

#### `(!)%<name-match-op><name-string><value-match-op><value-string>`

#### `(!)%<name-match-op><name-string><value-match-op>[<value-glob>]`

#### `(!)%<name-match-op><name-string><value-match-op>{<value-regex>}(<modifiers>)`

Similar to the above, except that you can specify a match operator
indicating how the `<name-string>` shall be compared to attribute names.

Examples:

-   `'%!~class'`

    Selects elements which have one or more attributes which do *not*
    have the name `class`.

-   `'%=~class !%id'`

    Selects elements which have at least one class and no id attribute.

-   `'%!~class %class!~{^foo}'`

    Selects elements which have at least one non-`class` attribute and
    no class which starts with `foo`.

Note that this is most useful with the `!~` (no-match) operator.
`%<attr-name>` and `%~<attr-name>` are just shorthand for
`%=~<attr-string>` so there is no real reason not to use the shortest
form.

The difference between `!%<attr-name>` and `&!~<attr-name>` is that the
former is true both when the element doesn't have any attributes and
when it has one or more attributes with other names, while the latter is
true when the element has one or more attributes with other names, but
false if the element doesn't have any attributes.

#### `(!)%(<name-match-op>)[<name-glob>]`

#### `(!)%(<name-match-op>){<name-regex>}(<modifiers>)`

#### `(!)%(<name-match-op>)[<name-glob>]<value-match-op><value-string>`

#### `(!)%(<name-match-op>){<name-regex>}(<modifiers>)<value-match-op><value-string>`

#### `(!)%(<name-match-op>)[<name-glob>]<value-match-op>[<value-glob>]`

#### `(!)%(<name-match-op>){<name-regex>}(<modifiers>)<value-match-op>{<value-regex>}(<modifiers>)`

Similar to the above but the *attribute names* are matched against a
glob or regex. A match operator may optionally be inserted between the
`%` and the name regex, but again the absence of a match operator and
the `~` operator are just shorthand for the `=~` operator, and the same
difference between `!%{<name-regex>}` and `%!~{<name-regex>}` applies,
namely that the latter requires there to be at least one attribute with
a name which doesn't match the regex.

Examples:

    '%{^data-}'
    '%!~[{width,height}]=~{^[0-9]}'

#### `(!)%(<name-match-op>)<attr-name><num-op><number>`

#### `(!)%(<name-match-op>)[<name-glob>]<num-op><number>`

#### `(!)%(<name-match-op>){<name-regex>}(<modifiers>)<num-op><number>`

Compares the value of attributes with matching names against `<number>`
using the numeric operator `<num-op>`.

Examples:

    '%width==192'
    '%width!=192'
    '%width<192'
    '%{^data-}>1'
    '%{width|height}>=500

## Shortcuts

Note that some parts of the expression syntax above are shortcuts for
longer (sub)expressions. In particular

    (Sub)expression    Example            Equivalent longer expression
    ------------------ ------------------ ------------------------------
    <name>~<value>     %foo~bar           %foo=~bar

    <name>=<number     &level=2           &level==2

    <word_or-hyphen>   foo_bar, foo-bar   'foo_bar', 'foo-bar'

    <ElementName>      CodeBlock          &name=~CodeBlock

    :<type>            :block             &is_block==1

    #<id>              #foo               &id=~foo

    .<class>           .foo               %class=~foo

    %<attr-name>       %data-foo          %=~data-foo

    %~<attr-name>      %~data-foo         %=~data-foo

    %[<glob>]          %[data-*]          %=~[data-*]

    %~[<glob>]         %~[data-*]         %=~[data-*]

    %{<regex>}         %{^data-}          %=~{^data-}

    %~{<regex>}        %~{^data-}         %=~{^data-}
    --------------------------------------------------------------------

On the one hand it can be argued that these shortcuts are unnecessary
since the longer equivalents (which they are often 'translated into' by
the parser) exist, but it can also be argued that it is an advantage to
have shorter expressions for common cases, using a syntax which in most
cases is familiar from elsewhere. Also most of the 'shortcuts' are
easier on the human eye than their 'full' equivalents.

# WEB SITE

<https://github.com/bpj/pandoc-elements-selectors>

# AUTHOR

Benct Philip Jonsson (<bpjonsson@gmail.com>, <https://github.com/bpj>)

# COPYRIGHT

Copyright 2017- Benct Philip Jonsson

# LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself. See
<http://dev.perl.org/licenses/>.

# SEE ALSO

[Pandoc::Elements][]

  [Pandoc::Elements]: https://metacpan.org/pod/Pandoc::Elements
  {pod="Pandoc::Elements"}

<!--
VIM: let $PDC_POD_EXTRA='+W +smart' $PDC_MD_EXTRA=' +W +smart --wrap=auto --columns=72 --reference-links --reference-location=block'
-->

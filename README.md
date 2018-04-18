# Proposed Pandoc::Elements extended selector expression syntax

This repository is the home for a **proposed** extended elements selector syntax for Pandoc::Elements
([on GitHub][PEonGH] and [on MetaCPAN][PEonMCPAN]).

**Please note that neither this syntax proposal nor the associated code has been adopted or endorsed by Pandoc::Elements or anybody else!**

In this repository you will find

*   [A description of the syntax proposal][description] as a Markdown file.

*   [Perl code which can parse selectors using this syntax][parser]
    as well as compile checker subroutines.

    You can test the syntax by running this script and typing selectors to STDIN.
    The selector will be compiled and the compiled subroutine or any error message
    will be printed to STDOUT.

Related discussion can be found
[here](https://github.com/jgm/pandoc/issues/4541)
and [here](https://github.com/nichtich/Pandoc-Elements/issues/18).

Feel free to open an [issue in this repository][issue] if you have any suggestion for an improvement *of this proposal*.  At the moment it is not likely that any new features will be added, but the wording and organization of the description can certainly be improved!  Please remember that the description must be valid GitHub Flavored Markdown *and* valid Pandoc Markdown!


[PEonGH]: https://github.com/nichtich/Pandoc-Elements
[PEonMCPAN]: https://metacpan.org/release/Pandoc-Elements
[description]: pandoc-elements-selectors-description.md
[parser]: pandoc-elements-selectors-parser.pl
[issue]: https://github.com/bpj/pandoc-elements-selectors/issues





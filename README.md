[![Actions Status](https://github.com/raku-community-modules/Grammar-Debugger/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-Debugger/actions) [![Actions Status](https://github.com/raku-community-modules/Grammar-Debugger/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-Debugger/actions) [![Actions Status](https://github.com/raku-community-modules/Grammar-Debugger/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-Debugger/actions)

NAME
====

Grammer::Debugger - Interactive debugger for Raku grammars

SYNOPSIS
========

In the file that has your grammar definition, merely load the module in the same lexical scope:

```raku
use Grammar::Debugger;

grammar Some::Grammar { ... }
```

DESCRIPTION
===========

[Grammar::Debugger](Grammar::Debugger) is an interactive debugger for Raku grammars. It applies to all grammars in its lexical scope. When you run your program and start to parse a grammar, you should get an interactive prompt. Type `h` to get a list of commands:

    $ raku my-grammar-program.raku
    TOP
    > h
        r              run (until breakpoint, if any)
        <enter>        single step
        rf             run until a match fails
        r <name>       run until rule <name> is reached
        bp add <name>  add a rule name breakpoint
        bp list        list all active rule name breakpoints
        bp rm <name>   remove a rule name breakpoint
        bp rm          removes all breakpoints
        q              quit
    >

If you are debugging a grammar and want to set up breakpoints in code rather than entering them manually at the debug prompt, you can apply the breakpoint trait to any rule:

```raku
token name is breakpoint {
    \w+ [\h+ \w+]*
}
```

If you want to conditionally break, you can also do something like:

```raku
token name will break { $_ eq 'Raku' } {
    \w+ [\h+ \w+]*
}
```

Which will only break after the `name` token has matched "Raku".

AUTHOR
======

Jonathan Worthington

COPYRIGHT AND LICENSE
=====================

Copyright 2011 - 2017 Jonathan Worthington

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.


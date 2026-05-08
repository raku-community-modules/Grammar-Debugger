use Grammar::Debugger::WrapCache;
use Terminal::ANSIColor;

my enum InterventionPoint <EnterRule ExitRule>;

multi trait_mod:<is>(Method $m, :$breakpoint!) is export {
    $m does role { method breakpoint { True } }
}
multi trait_mod:<will>(Method $m, $cond, :$break!) is export {
    $m does role {
        has $.breakpoint-condition is rw;
        method breakpoint { True }
    }
    $m.breakpoint-condition = $cond;
}

my class DebuggedGrammarHOW is Metamodel::GrammarHOW does Grammar::Debugger::WrapCache {

    # Workaround for Rakudo* 2014.03.01 on Win (and maybe somewhere else, too):
    # trying to change the attributes in &intervene ...
    # ... yields # "Cannot modify an immutable value"
    # So we rather use the attribute $!state *the contents of which* we'll
    # modify instead.
    # Not as bad as it might look at first - maybe factor it out sometime.
    has $!state = (
        auto-continue   => False,
        indent           => 0,
        stop-at-fail     => False,
        stop-at-name     => '',
        breakpoints      => [],
        cond-breakpoints => ().hash,
    ).hash;

    method add_method(Mu $obj, $name, $code) {
        callsame;
        if $code.?breakpoint {
            if $code.?breakpoint-condition {
                $!state{'cond-breakpoints'}{$code.name} = $code.breakpoint-condition;
            }
            else {
                $!state{'breakpoints'}.push($code.name);
            }
        }
    }

    method find_method($obj, $name) {
        my \cached = %!cache{$name};
        return cached if cached.DEFINITE;
        my $meth := callsame;
        if $meth.^name eq 'NQPRoutine' || $meth !~~ Any || $meth !~~ Regex {
            self!cache-unwrapped: $name, $meth;
        }
        else {
            self!cache-wrapped: $name, $meth, -> $c, |args {
                # Issue the rule's/token's/regex's name
                say ('|  ' x $!state{'indent'}) ~ BOLD() ~ $name ~ RESET();

                # Announce that we're about to enter the rule/token/regex
                self.intervene(EnterRule, $name);

                $!state{'indent'}++;
                # Actually call the rule/token/regex
                my $result := $meth($c, |args);
                $!state{'indent'}--;

                # Dump result.
                my $match := $result.MATCH;

                say ('|  ' x $!state{'indent'}) ~ '* ' ~
                        (?$match ??
                            colored('MATCH', 'white on_green') ~ self.summary($match) !!
                            colored('FAIL', 'white on_red'));

                # Announce that we're about to leave the rule/token/regex
                self.intervene(ExitRule, $name, :$match);
                $result
            }
        }
    }

    method intervene(InterventionPoint $point, $name, :$match) {
        # Any reason to stop?
        my $stop =
            !$!state{'auto-continue'} ||
            $point == EnterRule && $name eq $!state{'stop-at-name'} ||
            $point == ExitRule && !$match && $!state{'stop-at-fail'} ||
            $point == EnterRule && $name eq any($!state{'breakpoints'}) ||
            $point == ExitRule && $name eq any($!state{'cond-breakpoints'}.keys)
                && $!state{'cond-breakpoints'}{$name}.ACCEPTS($match);
        if $stop {
            my $done;
            repeat {
                my @parts = split /\s+/, prompt("> ");
                $done = True;
                given @parts[0] {
                    when '' {
                        $!state{'auto-continue'} = False;
                        $!state{'stop-at-fail'} = False;
                        $!state{'stop-at-name'} = '';
                    }
                    when 'r' {
                        given +@parts {
                            when 1 {
                                $!state{'auto-continue'} = True;
                                $!state{'stop-at-fail'} = False;
                                $!state{'stop-at-name'} = '';
                            }
                            when 2 {
                                $!state{'auto-continue'} = True;
                                $!state{'stop-at-fail'} = False;
                                $!state{'stop-at-name'} = @parts[1];
                            }
                            default {
                                usage();
                                $done = False;
                            }
                       }
                    }
                    when 'rf' {
                        $!state{'auto-continue'} = True;
                        $!state{'stop-at-fail'} = True;
                        $!state{'stop-at-name'} = '';
                    }
                    when 'bp' {
                        if +@parts == 2 && @parts[1] eq 'list' {
                            say "Current Breakpoints:\n" ~
                                $!state{'breakpoints'}.map({ "    $_" }).join("\n");
                        }
                        elsif +@parts == 3 && @parts[1] eq 'add' {
                            unless $!state{'breakpoints'}.grep({ $_ eq @parts[2] }) {
                                $!state{'breakpoints'}.push(@parts[2]);
                            }
                        }
                        elsif +@parts == 3 && @parts[1] eq 'rm' {
                            my @rm'd = $!state{'breakpoints'}.grep({ $_ ne @parts[2] });
                            if +@rm'd == +$!state{'breakpoints'} {
                                say "No breakpoint '@parts[2]'";
                            }
                            else {
                                $!state{'breakpoints'} = @rm'd;
                            }
                        }
                        elsif +@parts == 2 && @parts[1] eq 'rm' {
                            $!state{'breakpoints'} = [];
                        }
                        else {
                            usage();
                        }
                        $done = False;
                    }
                    when 'q' {
                        exit(0);
                    }
                    default {
                        usage();
                        $done = False;
                    }
                }
            } until $done;
        }
    }

    method summary($match) {
        my $snippet = $match.Str;
        my $sniplen = 60 - (3 * $!state{'indent'});
        $sniplen > 0 ??
            colored(' ' ~ $snippet.substr(0, $sniplen).raku, 'white') !!
            ''
    }

    sub usage() {
        say
            "    r              run (until breakpoint, if any)\n" ~
            "    <enter>        single step\n" ~
            "    rf             run until a match fails\n" ~
            "    r <name>       run until rule <name> is reached\n" ~
            "    bp add <name>  add a rule name breakpoint\n" ~
            "    bp list        list all active rule name breakpoints\n" ~
            "    bp rm <name>   remove a rule name breakpoint\n" ~
            "    bp rm          removes all breakpoints\n" ~
            "    q              quit"
    }

    method publish_method_cache($obj) {
        # Suppress this, so we always hit find_method.
    }
}

# Export this as the meta-class for the "grammar" package declarator.
my module EXPORTHOW {
    constant grammar = DebuggedGrammarHOW;
}

# vim: expandtab shiftwidth=4

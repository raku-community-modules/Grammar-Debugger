use Grammar::Debugger::WrapCache;
use Terminal::ANSIColor;

=begin pod

=head1 NAME

Grammer::Tracer - non-interactive debugger for Perl 6 grammars

=head1 SYNOPSIS

In the file that has your grammar definition, merely load the module
in the same lexical scope:

	use Grammar::Tracer;

	grammar Some::Grammar { ... }

=head1 DESCRIPTION

L<Grammar::Tracer> is the non-interactive version of L<Grammar::Debugger>.
It runs through the entire grammar without stopping.

=head1 AUTHOR

Jonathan Worthington, C<< <jnthn@jnthn.net> >>

=end pod

my class TracedGrammarHOW is Metamodel::GrammarHOW does Grammar::Debugger::WrapCache {
    my $indent = 0;

    method find_method($obj, $name) {
        my \cached = %!cache{$name};
        return cached if cached.DEFINITE;
        my $meth := callsame;
        if $meth.^name eq 'NQPRoutine' || $meth !~~ Any || $meth !~~ Regex {
            self!cache-unwrapped: $name, $meth;
        }
        else {
            self!cache-wrapped: $name, $meth, -> $c, |args {
                # Method name.
                say ('|  ' x $indent) ~ BOLD() ~ $name ~ RESET();

                # Call rule.
                $indent++;
                my $result;
                try {
                    $result := $meth($c, |args);
                    CATCH {
                        $indent--;
                    }
                }
                $indent--;

                # Dump result.
                my $match := $result.MATCH;
                say ('|  ' x $indent) ~ '* ' ~
                    ($result.MATCH ??
                        colored('MATCH', 'white on_green') ~ summary($match) !!
                        colored('FAIL', 'white on_red'));
                $result
            }
        }
    }

    sub summary($match) {
        my $snippet = $match.Str;
        my $sniplen = 60 - (3 * $indent);
        $sniplen > 0 ??
            colored(' ' ~ $snippet.substr(0, $sniplen).perl, 'white') !!
            ''
    }

    method publish_method_cache($obj) {
        # Suppress this, so we always hit find_method.
    }
}

# Export this as the meta-class for the "grammar" package declarator.
my module EXPORTHOW {
    constant grammar = TracedGrammarHOW;
}

use NQPHLL;

grammar Rubyish::Grammar is HLL::Grammar {
    token TOP {
        <statementlist>
    }
    
    rule statementlist {
        [ <statement> \n+ ]*
    }
    
    proto token statement {*}
    token statement:sym<puts> {
        <sym> <.ws> <?["]> <quote_EXPR: ':q'>
    }
    
    # Whitespace required between alphanumeric tokens
    token ws { <!ww> \h* || \h+ }
}

class Rubyish::Actions is HLL::Actions {
    method TOP($/) {
        make QAST::Block.new( $<statementlist>.ast );
    }
    
    method statementlist($/) {
        my $stmts := QAST::Stmts.new( :node($/) );
        for $<statement> {
            $stmts.push($_.ast)
        }
        make $stmts;
    }
    
    method statement:sym<puts>($/) {
        make QAST::Op.new(
            :op('say'),
            $<quote_EXPR>.ast
        );
    }
}

class Rubyish::Compiler is HLL::Compiler {
    method eval($code, *@_args, *%adverbs) {
        my $output := self.compile($code, :compunit_ok(1), |%adverbs);

        if %adverbs<target> eq '' {
            my $outer_ctx := %adverbs<outer_ctx>;
            $output := self.backend.compunit_mainline($output);
            if nqp::defined($outer_ctx) {
                nqp::forceouterctx($output, $outer_ctx);
            }

            $output := $output();
        }

        $output;
    }
}

sub MAIN(*@ARGS) {
    my $comp := Rubyish::Compiler.new();
    $comp.language('rubyish');
    $comp.parsegrammar(Rubyish::Grammar);
    $comp.parseactions(Rubyish::Actions);
    $comp.command_line(@ARGS, :encoding('utf8'));
}

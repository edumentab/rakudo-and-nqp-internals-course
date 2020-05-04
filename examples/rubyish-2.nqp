use NQPHLL;

grammar Rubyish::Grammar is HLL::Grammar {
    token TOP {
        <statementlist>
        [ $ || <.panic('Syntax error')> ]
    }
    
    rule statementlist {
        [ <statement> \n+ ]*
    }
    
    proto token statement {*}
    token statement:sym<puts> {
        <sym> <.ws> <EXPR>
    }
    
    token term:sym<value> { <value> }
    
    proto token value {*}
    token value:sym<string>  { <?["]> <quote_EXPR: ':q'> }
    token value:sym<integer> { '-'? \d+ }
    token value:sym<float>   { '-'? \d+ '.' \d+ }
    
    # Whitespace required between alphanumeric tokens
    token ws { <!ww> \h* || \h+ }
    
    # Operator precedence levels
    my %multiplicative := nqp::hash('prec', 'u=', 'assoc', 'left');
    my %additive := nqp::hash('prec', 't=', 'assoc', 'left');
    
    # Operators
    token infix:sym<*> { <sym> <O(|%multiplicative, :op<mul_n>)> }
    token infix:sym</> { <sym> <O(|%multiplicative, :op<div_n>)> }
    token infix:sym<+> { <sym> <O(|%additive, :op<add_n>)> }
    token infix:sym<-> { <sym> <O(|%additive, :op<sub_n>)> }
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
    
    method term:sym<value>($/) { make $<value>.ast; }
    
    method statement:sym<puts>($/) {
        make QAST::Op.new(
            :op('say'),
            $<EXPR>.ast
        );
    }
    
    method value:sym<string>($/) {
        make $<quote_EXPR>.ast;
    }
    method value:sym<integer>($/) {
        make QAST::IVal.new( :value(+$/.Str) )
    }
    method value:sym<float>($/) {
        make QAST::NVal.new( :value(nqp::numify($/.Str)) )
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

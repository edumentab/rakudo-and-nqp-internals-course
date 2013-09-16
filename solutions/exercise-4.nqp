use NQPHLL;

grammar PHPish::Grammar is HLL::Grammar {
    token TOP {
        <statementlist>
        [ $ || <.panic('Syntax error')> ]
    }
    
    rule statementlist {
        [<statement> ]* %% [ ';' ]
    }
    
    proto token statement {*}
    token statement:sym<echo> {
        <sym>
        [
        | <.ws> <?["]> <quote_EXPR: ':q', ':b'>
        | '(' ~ ')' [ <.ws> <?["]> <quote_EXPR: ':q', ':b'> <.ws> ]
        ]
    }
}

class PHPish::Actions is HLL::Actions {
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
    
    method statement:sym<echo>($/) {
        make QAST::Op.new(
            :op('print'),
            $<quote_EXPR>.ast
        );
    }
}

class PHPish::Compiler is HLL::Compiler {
}

sub MAIN(*@ARGS) {
    my $comp := PHPish::Compiler.new();
    $comp.language('phpish');
    $comp.parsegrammar(PHPish::Grammar);
    $comp.parseactions(PHPish::Actions);
    $comp.command_line(@ARGS, :encoding('utf8'));
}

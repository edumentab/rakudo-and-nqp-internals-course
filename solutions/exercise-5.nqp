use NQPHLL;

grammar PHPish::Grammar is HLL::Grammar {
    token TOP {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        <statementlist>
        [ $ || <.panic('Syntax error')> ]
    }
    
    rule statementlist {
        [<statement> ]*
    }
    
    proto token statement {*}
    token statement:sym<echo> {
        <sym>
        [
        | <.ws> <EXPR>
        | '(' ~ ')' [ <.ws> <EXPR> <.ws> ]
        ]
        <semi>
    }
    
    token statement:sym<function> {
        'function' \h+ <funcbody> <semi>?
    }
    rule funcbody {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        <ident> <signature>?
        '{' ~ '}' <statementlist>
    }
    rule signature {
        '(' <param>* % [ ',' ] ')'
    }
    token param { <varname> }
    
    token statement:sym<EXPR> { <EXPR> <semi> }
    
    token term:sym<variable> {
        :my $*MAYBE_DECL := 0;
        <varname>
        [ <?before \s* '=' \s* <value> { $*MAYBE_DECL := 1 }> || <?> ]
    }
    
    token term:sym<call> {
        <ident> '(' :s <EXPR>* % [ ',' ] ')'
    }
    
    token term:sym<value> { <value> }
    
    proto token value {*}
    token value:sym<string>  { <?["]> <quote_EXPR: ':q', ':b'> }
    token value:sym<integer> { '-'? \d+ }
    token value:sym<float>   { '-'? \d+ '.' \d+ }
    
    token varname { '$' <[A..Za..z_]> <[A..Za..z0..9_]>* }
    token semi    { <.ws> [ ';' || $ ] }

    # Operator precedence levels
    my %multiplicative := nqp::hash('prec', 'u=', 'assoc', 'left');
    my %additive := nqp::hash('prec', 't=', 'assoc', 'left');
    my %assignment := nqp::hash('prec', 'i=', 'assoc', 'right');
    
    # Operators
    token infix:sym<*> { <sym>  <O(|%multiplicative, :op<mul_n>)> }
    token infix:sym</> { <sym>  <O(|%multiplicative, :op<div_n>)> }
    token infix:sym<+> { <sym>  <O(|%additive, :op<add_n>)> }
    token infix:sym<-> { <sym>  <O(|%additive, :op<sub_n>)> }
    token infix:sym<.> { <sym>  <O(|%additive, :op<concat>)> }
    token infix:sym<=> { <sym> <O(|%assignment, :op<bind>)> }
}

class PHPish::Actions is HLL::Actions {
    method TOP($/) {
        $*CUR_BLOCK.push($<statementlist>.ast);
        make $*CUR_BLOCK;
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
            $<EXPR>.ast
        );
    }
    
    method statement:sym<function>($/) {
        my $install := $<funcbody>.ast;
        $*CUR_BLOCK[0].push(QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :name($install.name), :scope('lexical'), :decl('var') ),
            $install
        ));
        make QAST::Op.new( :op('null') );
    }
    method funcbody($/) {
        $*CUR_BLOCK.name(~$<ident>);
        $*CUR_BLOCK.push($<statementlist>.ast);
        make $*CUR_BLOCK;
    }
    method param($/) {
        $*CUR_BLOCK[0].push(QAST::Var.new(
            :name(~$<varname>), :scope('lexical'), :decl('param')
        ));
        $*CUR_BLOCK.symbol(~$<varname>, :declared(1));
    }
    
    method statement:sym<EXPR>($/) { make $<EXPR>.ast; }
    
    method term:sym<variable>($/) {
        my $name := ~$<varname>;
        my %sym  := $*CUR_BLOCK.symbol($name);
        if $*MAYBE_DECL && !%sym<declared> {
            $*CUR_BLOCK.symbol($name, :declared(1));
            make QAST::Var.new( :name($name), :scope('lexical'),
                                :decl('var') );
        }
        else {
            make QAST::Var.new( :name($name), :scope('lexical') );
        }
    }
    
    method term:sym<call>($/) {
        my $call := QAST::Op.new( :op('call'), :name(~$<ident>) );
        for $<EXPR> {
            $call.push($_.ast);
        }
        make $call;
    }
    
    method term:sym<value>($/) { make $<value>.ast; }
    
    method value:sym<string>($/) {
        make $<quote_EXPR>.ast;
    }
    method value:sym<integer>($/) {
        make QAST::IVal.new( :value(+$/.Str) )
    }
    method value:sym<float>($/) {
        make QAST::NVal.new( :value(+$/.Str) )
    }
}

class PHPish::Compiler is HLL::Compiler {
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
    my $comp := PHPish::Compiler.new();
    $comp.language('phpish');
    $comp.parsegrammar(PHPish::Grammar);
    $comp.parseactions(PHPish::Actions);
    $comp.command_line(@ARGS, :encoding('utf8'));
}

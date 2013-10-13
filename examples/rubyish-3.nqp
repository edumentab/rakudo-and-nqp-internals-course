use NQPHLL;

grammar Rubyish::Grammar is HLL::Grammar {
    token TOP {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
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
    
    token statement:sym<def> {
        'def' \h+ <defbody>
    }
    rule defbody {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        <ident> <signature>? \n
        <statementlist>
        'end'
    }
    rule signature {
        '(' <param>* % [ ',' ] ')'
    }
    token param { <ident> }
    
    token statement:sym<EXPR> { <EXPR> }
    
    token term:sym<call> {
        <!keyword>
        <ident> '(' :s <EXPR>* % [ ',' ] ')'
    }
    
    token term:sym<ident> {
        :my $*MAYBE_DECL := 0;
        <!keyword>
        <ident>
        [ <?before \h* '=' [\w | \h+] { $*MAYBE_DECL := 1 }> || <?> ]
    }
    
    token term:sym<value> { <value> }
    
    proto token value {*}
    token value:sym<string>  { <?["]> <quote_EXPR: ':q'> }
    token value:sym<integer> { '-'? \d+ }
    token value:sym<float>   { '-'? \d+ '.' \d+ }
    
    # Reserved words.
    token keyword {
        [ BEGIN     | class     | ensure    | nil       | self      | when
        | END       | def       | false     | not       | super     | while
        | alias     | defined   | for       | or        | then      | yield
        | and       | do        | if        | redo      | true
        | begin     | else      | in        | rescue    | undef
        | break     | elsif     | module    | retry     | unless
        | case      | end       | next      | return    | until
        ] <!ww>
    }
    
    # Whitespace required between alphanumeric tokens
    token ws { <!ww> \h* || \h+ }
    
    # Operator precedence levels
    INIT {
        Rubyish::Grammar.O(':prec<u=>, :assoc<left>',  '%multiplicative');
        Rubyish::Grammar.O(':prec<t=>, :assoc<left>',  '%additive');
        Rubyish::Grammar.O(':prec<j=>, :assoc<right>',  '%assignment');
    }
    
    # Operators
    token infix:sym<*> { <sym> <O('%multiplicative, :op<mul_n>')> }
    token infix:sym</> { <sym> <O('%multiplicative, :op<div_n>')> }
    token infix:sym<+> { <sym> <O('%additive, :op<add_n>')> }
    token infix:sym<-> { <sym> <O('%additive, :op<sub_n>')> }
    token infix:sym<=> { <sym> <O('%assignment, :op<bind>')> }
}

class Rubyish::Actions is HLL::Actions {
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
    
    method term:sym<value>($/) { make $<value>.ast; }
    
    method term:sym<call>($/) {
        my $call := QAST::Op.new( :op('call'), :name(~$<ident>) );
        for $<EXPR> {
            $call.push($_.ast);
        }
        make $call;
    }
    
    method term:sym<ident>($/) {
        my $name := ~$<ident>;
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
    
    method statement:sym<puts>($/) {
        make QAST::Op.new(
            :op('say'),
            $<EXPR>.ast
        );
    }
    
    method statement:sym<def>($/) {
        my $install := $<defbody>.ast;
        $*CUR_BLOCK[0].push(QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :name($install.name), :scope('lexical'), :decl('var') ),
            $install
        ));
        make QAST::Op.new( :op('null') );
    }
    method defbody($/) {
        $*CUR_BLOCK.name(~$<ident>);
        $*CUR_BLOCK.push($<statementlist>.ast);
        make $*CUR_BLOCK;
    }
    method param($/) {
        $*CUR_BLOCK[0].push(QAST::Var.new(
            :name(~$<ident>), :scope('lexical'), :decl('param')
        ));
        $*CUR_BLOCK.symbol(~$<ident>, :declared(1));
    }
    
    method statement:sym<EXPR>($/) { make $<EXPR>.ast; }
    
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

class Rubyish::Compiler is HLL::Compiler {
}

sub MAIN(*@ARGS) {
    my $comp := Rubyish::Compiler.new();
    $comp.language('rubyish');
    $comp.parsegrammar(Rubyish::Grammar);
    $comp.parseactions(Rubyish::Actions);
    $comp.command_line(@ARGS, :encoding('utf8'));
}

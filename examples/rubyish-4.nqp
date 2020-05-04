use NQPHLL;

class RubyishClassHOW {
    has $!name;
    has %!methods;
    
    method new_type(:$name!) {
        nqp::newtype(self.new(:$name), 'HashAttrStore')
    }
    
    method add_method($obj, $name, $code) {
        %!methods{$name} := $code;
    }
    
    method find_method($obj, $name) {
        %!methods{$name} // nqp::null();
    }
}

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
    
    token statement:sym<class> {
        :my $*IN_CLASS := 1;
        :my @*METHODS;
        'class' \h+ <classbody>
    }
    rule classbody {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        <ident> \n
        <statementlist>
        'end'
    }
    
    token statement:sym<EXPR> { <EXPR> }
    
    token term:sym<call> {
        <!keyword>
        <ident> '(' :s <EXPR>* % [ ',' ] ')'
    }
    
    token term:sym<new> {
        'new' \h+ :s <ident> '(' ')'
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
    my %methodop := nqp::hash('prec', 'y=', 'assoc', 'unary');
    my %multiplicative := nqp::hash('prec', 'u=', 'assoc', 'left');
    my %additive := nqp::hash('prec', 't=', 'assoc', 'left');
    my %assignment := nqp::hash('prec', 'j=', 'assoc', 'right');
    
    # Operators
    token infix:sym<*> { <sym> <O(|%multiplicative, :op<mul_n>)> }
    token infix:sym</> { <sym> <O(|%multiplicative, :op<div_n>)> }
    token infix:sym<+> { <sym> <O(|%additive, :op<add_n>)> }
    token infix:sym<-> { <sym> <O(|%additive, :op<sub_n>)> }
    token infix:sym<=> { <sym> <O(|%assignment, :op<bind>)> }
    
    # Method call
    token postfix:sym<.>  {
        '.' <ident> '(' :s <EXPR>* % [ ',' ] ')'
        <O(|%methodop)>
    }
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
    
    method term:sym<new>($/) {
        make QAST::Op.new(
            :op('create'),
            QAST::Var.new( :name('::' ~ ~$<ident>), :scope('lexical') )
        );
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
        if $*IN_CLASS {
            @*METHODS.push($install);
        }
        make QAST::Op.new( :op('null') );
    }
    method defbody($/) {
        $*CUR_BLOCK.name(~$<ident>);
        $*CUR_BLOCK.push($<statementlist>.ast);
        if $*IN_CLASS {
            # it's a method, self will be automatically passed
            $*CUR_BLOCK[0].unshift(QAST::Var.new(
                :name('self'), :scope('lexical'), :decl('param')
            ));
            $*CUR_BLOCK.symbol('self', :declared(1));
        }

        make $*CUR_BLOCK;
    }
    method param($/) {
        $*CUR_BLOCK[0].push(QAST::Var.new(
            :name(~$<ident>), :scope('lexical'), :decl('param')
        ));
        $*CUR_BLOCK.symbol(~$<ident>, :declared(1));
    }
    
    method statement:sym<class>($/) {
        my $body_block := $<classbody>.ast;
        
        # Generate code to create the class.
        my $class_stmts := QAST::Stmts.new( $body_block );
        my $ins_name    := '::' ~ $<classbody><ident>;
        $class_stmts.push(QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :name($ins_name), :scope('lexical'), :decl('var') ),
            QAST::Op.new(
                :op('callmethod'), :name('new_type'),
                QAST::WVal.new( :value(RubyishClassHOW) ),
                QAST::SVal.new( :value(~$<classbody><ident>), :named('name') ) )
            ));

        # Add methods.
        my $class_var := QAST::Var.new( :name($ins_name), :scope('lexical') );
        for @*METHODS {
            $class_stmts.push(QAST::Op.new(
                :op('callmethod'), :name('add_method'),
                QAST::Op.new( :op('how'), $class_var ),
                $class_var,
                QAST::SVal.new( :value($_.name) ),
                QAST::BVal.new( :value($_) )));
        }
        
        make $class_stmts;
    }
    method classbody($/) {
        $*CUR_BLOCK.push($<statementlist>.ast);
        $*CUR_BLOCK.blocktype('immediate');
        make $*CUR_BLOCK;
    }
    
    method statement:sym<EXPR>($/) { make $<EXPR>.ast; }
    
    method value:sym<string>($/) {
        make $<quote_EXPR>.ast;
    }
    method value:sym<integer>($/) {
        make QAST::IVal.new( :value(+$/.Str) )
    }
    method value:sym<float>($/) {
        make QAST::NVal.new( :value(nqp::numify($/.Str)) )
    }
    
    method postfix:sym<.>($/) {
        my $meth_call := QAST::Op.new( :op('callmethod'), :name(~$<ident>) );
        for $<EXPR> {
            $meth_call.push($_.ast);
        }
        make $meth_call;
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

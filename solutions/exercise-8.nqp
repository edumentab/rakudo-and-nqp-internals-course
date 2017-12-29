use NQPHLL;

class PHPClassHOW {
    has $!name;
    has %!methods;
    has @!parents;
    
    method new_type(:$name!) {
        nqp::newtype(self.new(:$name), 'HashAttrStore')
    }
    
    method add_parent($obj, $parent) {
        if @!parents {
            nqp::die("Parent classes are like the highlander: there can only be one");
        }
        @!parents[0] := $parent;
    }
    
    method add_method($obj, $name, $code) {
        %!methods{$name} := $code;
    }
    
    method find_method($obj, $name) {
        if nqp::existskey(%!methods, $name) {
            %!methods{$name}
        }
        else {
            for self.parents($obj) -> $p {
                my %pmt := $p.HOW.method_table($p);
                if nqp::existskey(%pmt, $name) {
                    return %pmt{$name};
                }
            }
            NQPMu
        }
    }
    
    method method_table($obj) {
        %!methods
    }
    
    method parents($obj, :$local) {
        if $local {
            @!parents
        }
        else {
            my $cur_class := $obj;
            my @all_parents;
            while 1 {
                if $cur_class.HOW.parents($cur_class, :local) -> @p {
                    $cur_class := @p[0];
                    nqp::push(@all_parents, $cur_class);
                }
                else {
                    last;
                }
            }
            @all_parents
        }
    }
    
    method compose($obj) {
        my %cache := nqp::clone(%!methods);
        for self.parents($obj) {
            for $_.HOW.method_table($_) -> $meth {
                unless nqp::existskey(%cache, $meth.key) {
                    %cache{$meth.key} := $meth.value;
                }
            }
        }
        nqp::setmethcache($obj, %cache)
    }
}

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
    
    token statement:sym<class> {
        :my $*IN_CLASS := 1;
        :my @*METHODS;
        'class' <.ws> <classbody> <semi>?
    }
    rule classbody {
        :my $*CUR_BLOCK := QAST::Block.new(QAST::Stmts.new());
        <ident>
        [ 'extends' <extends=.ident> ]?
        '{' ~ '}' <statementlist>
    }
    
    token statement:sym<EXPR> { <EXPR> <semi> }
    
    token term:sym<variable> {
        :my $*MAYBE_DECL := 0;
        <varname>
        [ <?before \s* '=' \s* [ <value> || <new> ] { $*MAYBE_DECL := 1 }> || <?> ]
    }
    
    token term:sym<new> {
        'new' \s+ :s <ident> '(' ')'
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
    INIT {
        PHPish::Grammar.O(':prec<y=>, :assoc<unary>', '%methodop');
        PHPish::Grammar.O(':prec<u=>, :assoc<left>', '%multiplicative');
        PHPish::Grammar.O(':prec<t=>, :assoc<left>', '%additive');
        PHPish::Grammar.O(':prec<j=>, :assoc<right>',  '%assignment');
    }
    
    # Operators
    token infix:sym<*> { <sym>  <O('%multiplicative, :op<mul_n>')> }
    token infix:sym</> { <sym>  <O('%multiplicative, :op<div_n>')> }
    token infix:sym<+> { <sym>  <O('%additive, :op<add_n>')> }
    token infix:sym<-> { <sym>  <O('%additive, :op<sub_n>')> }
    token infix:sym<.> { <sym>  <O('%additive, :op<concat>')> }
    token infix:sym<=> { <sym> <O('%assignment, :op<bind>')> }
    
    token postfix:sym<methcall>  {
        '->' <ident> '(' :s <EXPR>* % [ ',' ] ')'
        <O('%methodop')>
    }
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
        if $*IN_CLASS {
            $install[0].unshift(QAST::Var.new(
                :name('$this'), :scope('lexical'), :decl('param') ));
            @*METHODS.push($install);
        }
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
    
    method statement:sym<class>($/) {
        my $body_block := $<classbody>.ast;
        
        # Generate code to create the class.
        my $class_stmts := QAST::Stmts.new( $body_block );
        my $ins_name    := $<classbody><ident>;
        $class_stmts.push(QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :name($ins_name), :scope('lexical'), :decl('var') ),
            QAST::Op.new(
                :op('callmethod'), :name('new_type'),
                QAST::WVal.new( :value(PHPClassHOW) ),
                QAST::SVal.new( :value(~$<classbody><ident>), :named('name') ) )
            ));

        # Handle inheritance.
        my $class_var := QAST::Var.new( :name($ins_name), :scope('lexical') );
        if $<classbody><extends> -> $ex {
            $class_stmts.push(QAST::Op.new(
                :op('callmethod'), :name('add_parent'),
                QAST::Op.new( :op('how'), $class_var ),
                $class_var,
                QAST::Var.new( :name(~$ex), :scope('lexical') )));
        }
        
        # Add methods.
        for @*METHODS {
            $class_stmts.push(QAST::Op.new(
                :op('callmethod'), :name('add_method'),
                QAST::Op.new( :op('how'), $class_var ),
                $class_var,
                QAST::SVal.new( :value($_.name) ),
                QAST::BVal.new( :value($_) )));
        }
        
        # Compose.
        $class_stmts.push(QAST::Op.new(
            :op('callmethod'), :name('compose'),
            QAST::Op.new( :op('how'), $class_var ),
            $class_var));

        make $class_stmts;
    }
    method classbody($/) {
        $*CUR_BLOCK.push($<statementlist>.ast);
        $*CUR_BLOCK.blocktype('immediate');
        make $*CUR_BLOCK;
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
    
    method term:sym<new>($/) {
        make QAST::Op.new(
            :op('create'),
            QAST::Var.new( :name(~$<ident>), :scope('lexical') )
        );
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
    
    method postfix:sym<methcall>($/) {
        my $meth_call := QAST::Op.new( :op('callmethod'), :name(~$<ident>) );
        for $<EXPR> {
            $meth_call.push($_.ast);
        }
        make $meth_call;
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

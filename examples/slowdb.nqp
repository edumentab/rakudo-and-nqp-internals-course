grammar QueryParser {
    token TOP { ^ <query> $ }
    
    proto token query {*}
    token query:sym<insert> {
        'INSERT' \s <pairlist>
    }
    token query:sym<select> {
        'SELECT' \s <keylist>
        [ 'WHERE' \s <pairlist> ]?
    }
    
    rule pairlist { <pair>+ % [ ',' ] }
    rule pair     { <key> '=' <value>  }
    rule keylist  { <key>+ % [ ',' ] }
    token key     { \w+ }
    
    proto token value {*}
    token value:sym<integer> { \d+ }
    token value:sym<string>  { \' <( <-[']>+ )> \' }
}

class QueryActions {
    method TOP($/) {
        make $<query>.ast;
    }
    
    method query:sym<insert>($/) {
        my %to_insert := $<pairlist>.ast;
        make -> @db {
            nqp::push(@db, %to_insert);
            [nqp::hash('result', 'Inserted 1 row' )]
        };
    }
    
    method query:sym<select>($/) {
        my @fields  := $<keylist>.ast;
        my %filters := $<pairlist> ?? $<pairlist>.ast !! {};
        make -> @db {
            my @results;
            for @db -> %row {
                my $match := 1;
                for %filters {
                    if %row{$_.key} ne $_.value {
                        $match := 0;
                        last;
                    }
                }
                if $match {
                    my %selected;
                    for @fields {
                        %selected{$_} := %row{$_};
                    }
                    nqp::push(@results, %selected);
                }
            }
            @results
        }
    }
    
    method pairlist($/) {
        my %pairs;
        for $<pair> -> $p {
            %pairs{$p<key>} := $p<value>.ast;
        }
        make %pairs;
    }

    method keylist($/) {
        my @keys;
        for $<key> -> $k {
            nqp::push(@keys, ~$k)
        }
        make @keys;
    }
    
    method value:sym<integer>($/) { make ~$/ }
    method value:sym<string>($/)  { make ~$/ }
}

class SlowDB {
    has @!data;
    
    method execute($query) {
        if QueryParser.parse($query, :actions(QueryActions)) -> $parsed {
            my $evaluator := $parsed.ast;
            if $evaluator(@!data) -> @results {
                for @results -> %data {
                    say("[");
                    say("    {$_.key}: {$_.value}") for %data;
                    say("]");
                }
            } else {
                say("Nothing found");
            }
        } else {
            say('Syntax error in query');
        }
    }
}

# Uncomment to enable tracing.
# QueryParser.HOW.trace-on(QueryParser);

my $db := SlowDB.new();
while (my $query := nqp::readlinefh(nqp::getstdin())) ne 'quit' {
    $db.execute($query);
}

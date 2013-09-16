grammar INIFile {
    token TOP {
        ^
        <entries>
        <section>+
        $
    }
    
    token section {
        '[' ~ ']' <key> \n
        <entries>
    }
    
    token entries {
        [
        | <entry> \n
        | \n
        ]+
    }

    rule entry { <key> '=' <value> }
    
    token key   { \w+ }
    token value { \N+ }
    
    token ws { \h* }
}

class INIFileActions {
    method TOP($/) {
        my %result;
        %result<_> := $<entries>.ast;
        for $<section> -> $sec {
            %result{$sec<key>} := $sec<entries>.ast;
        }
        make %result;
    }
    
    method entries($/) {
        my %entries;
        for $<entry> -> $e {
            %entries{$e<key>} := ~$e<value>;
        }
        make %entries;
    }
}

# Uncomment to enable tracing.
#INIFile.HOW.trace-on(INIFile);

my $m1 := INIFile.parse(Q{
name = Animal Facts
author = jnthn
});
for $m1<entries><entry> -> $e {
    say("Key: {$e<key>}, Value: {$e<value>}");
}

my $m2 := INIFile.parse(:actions(INIFileActions), Q{
name = Animal Facts
author = jnthn

[cat]
desc = The smartest and cutest
cuteness = 100000

[dugong]
desc = The cow of the sea
cuteness = -10
});
my %ini := $m2.ast;
for %ini -> $sec {
    say("Section {$sec.key}");
    for $sec.value -> $entry {
        say("    {$entry.key}: {$entry.value}");
    }
}

#! /usr/bin/perl -w
use strict;
use autodie qw/open/;

my $body = join "", <>;
open my $TEMPLATE, "<", "src/template-exercises.tex";

for (join "", <$TEMPLATE>) {
    s/\{\{\{BODY\}\}\}/$body/;
    print;
}

close $TEMPLATE;

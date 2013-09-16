#! /usr/bin/perl -w
use strict;

while (<>) {
    if (/^\\begin\{Huge\}([^:]+): ([^\\]+)\\end\{Huge\}$/) {
        $_ = <<"EOT";
\\begin{Huge}$1\\end{Huge}

\\textit{$2}
EOT
    }

    print;
}

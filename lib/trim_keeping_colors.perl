#!/usr/bin/env perl
use warnings;
use strict;

my $i = 0;
my $j = 0;

while (<>) {
    chomp;
    my $content = $_;
    $j = 0;
    while ( $content =~
        m/^(?:\h*|(?<color>(?:[[:cntrl:]]\[\d{1,3}(?:[;]\d{1,3})*[mGK])*))*\h+/g
      )
    {
        # print "Content $i:$j: |$content|\n";
        # print "Matched $i:$j: |$`<$&>$'|\n";
        if ( defined( $+{color} ) ) {
            $content = $+{color} . $';
        }
        else {
            $content = $';
        }
        $j++;
    }
    while ( $content =~
        m/\h+(?:\h*|(?<color>(?:[[:cntrl:]]\[\d{1,3}(?:[;]\d{1,3})*[mGK])*))*$/g
      )
    {
        # print "Content $i:$j: |$content|\n";
        # print "Matched $i:$j: |$`<$&>$'|\n";
        if ( defined( $+{color} ) ) {
            $content = $` . $+{color};
        }
        else {
            $content = $`;
        }
        $j++;
    }

    # Remove the spaces around standalone colors codes
    $content =~
      s/\h(?<color>(?:[[:cntrl:]]\[\d{1,3}(?:[;]\d{1,3})*[mGK])+)\h/$1/g;

    # print "Content $i:$j: |$content|\n";
    # print "Matched $i:$j: |$`<$&>$'|\n";

    print $content."\n";
    $i++;
}

#!/usr/bin/env perl
use warnings;
use strict;

my $cmd_delimiter_string = "::";
my $excaped_return       = "%0A";
my $CI                   = 0;
if ( defined( $ENV{'GITHUB_ACTIONS'} ) ) {
    $CI = 1;
}

# ::info file=.elasticbeanstalk/logs/201018_143457/i-067484093c664c68d/var/log/eb-engine.log,line=54::2020/10/18
my $skip_pattern = qr/^[:]{2}\w[-\w]+\s+.*[:]{2}.*$/;

sub tidy_line {
    my @list      = @_;
    my @tidy_list = ();
    foreach my $msg (@list) {
        if ( defined($msg) ) {

            # Remove lines that are just delimiters
            $msg =~
              s/^(?:\s+)?([+]{30,}|[-]{30,}|[=]{30,}|[*]{30,})(?:\s+)?$//g;

            # Remove empty lines
            $msg =~ s/^\s+$//;
            push @tidy_list, $msg;
        }
    }
    return join( '', @tidy_list );
}

sub escape_data {
    my @list         = @_;
    my @escaped_list = ();
    foreach my $msg (@list) {
        if ( defined($msg) ) {
            if ($CI) {

                # Escape the GitHub string variable character to %25
                $msg =~ s/%/%25/g;

                # Convert any carrage returns to %0D
                $msg =~ s/\r/%0D/g;

                # Convert any remaining newlines to %0A
                $msg =~ s/\n/%0A/g;
            }
            push @escaped_list, $msg;
        }
    }
    return @escaped_list;
}

sub escape_properties {
    my (%hash) = @_;
    foreach my $key ( keys %hash ) {
        if ( exists( $hash{$key} ) && defined( $hash{$key} ) ) {
            my $msg = $hash{$key};
            if ($CI) {

                # Escape the GitHub string variable character to %25
                $msg =~ s/%/%25/g;

                # Convert any carrage returns to %0D
                $msg =~ s/\r/%0D/g;

                # Convert any remaining newlines to %0A
                $msg =~ s/\n/%0A/g;

                # Convert the colons to %3A
                $msg =~ s/:/%3A/g;

                # Convert the commas to %2C
                $msg =~ s/,/%2C/g;
            }
            $hash{$key} = $msg;
        }
    }
    return %hash;
}

my @valid_starting_patterns = (

# Oct 18 01:32:38 cloud-init[2740]: main.py[DEBUG]: No kernel command line url found. (?:ip-[-\d]+\h)?(?:[\w_\[\]\d]+:\h)?(?:[\w.]+\[(?<level>[\w+])\]\ )?
qr/(?<date>^[A-Z][\w]+\h\d{1,2}(?:\h\d+)?)\h(?<time>[\d]{2}:[\d]{2}:[\d]{2})\h?(?<message>(?:ip-[-\d]+\h)?(?:[\w_\[\]\d]+:\h)?(?:[\w.]+\[(?<level>[\w+])\]\ )?.*)/,

    # qr/^\d{4}(.\d{2}){2}(\s|T)(\d{2}.){2}\d{2}/

    # qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}([.]\d{1,3})?(Z|[-+]\d{2}:\d{2})/

    # [2020-10-18T01:32:45.319Z]
qr/^\[(?<date>\d{4}-\d{2}-\d{2})T(?<time>\d{2}:\d{2}:\d{2}([.]\d{1,3})?(Z|[-+]\d{2}:\d{2}))\]\h?(?<message>.*)/,

    # 2020-10-18 01:33:43,021 P6044 [INFO]
    # or
    # 2020/10/18 01:32:49.489691 [INFO]
    # or
    # 2022-06-22 11:52:29.078 ERROR 49294 ---
qr/(?<date>^(?:\d{1,2}|\d{4})[-\/]\d{1,2}[-\/](?:\d{1,2}|\d{4}))\ (?<time>\d{2}:\d{2}:\d{2}(?:[.,]\d{3,6})?)\h+(?:P\d+\h)?(?:\[(?<level>\w+)\]|(?<level>\w+) \d{2,}\ ---\ )\h?(?<message>.*)/

);

my @lines;

# Get all the lines in the log file into an array
while (<>) {
    chomp;
    push @lines, $_;
}

my $starting_line;
if ( $#lines > 300 ) {
    print "Too many lines in the log file.\n only reading the last 300 lines";
    $starting_line = $#lines - 300;
}
else {
    $starting_line = 0;
}

# Loop through the lines and parse the log messages
for ( my $i = $starting_line ; $i <= $#lines ; $i++ ) {
  PARSELINE:
    my $command;
    my $title;
    my $end_line;
    my $start_line     = $i + 1;
    my $pattern_found  = 0;
    my $message        = $lines[$i];
    my %log_details    = ( 'message' => $message );
    my %log_properties = ( 'file'    => $ARGV, 'line' => $start_line );

    if ( $lines[$i] =~ $skip_pattern ) {
        print "$lines[$i]\n";
    }
    else {
        foreach my $pattern (@valid_starting_patterns) {
            if ( $lines[$i] =~ /$pattern/m ) {
                my $time  = $+{time};
                my $level = $+{level};
                my $date  = $+{date};
                if ( defined($level) ) {
                    $command = lc($level);
                }
                $title   = $+{title};
                $message = $+{message};

                # Remove all newlines from the message
                $message =~ s/\v+//gm;

                # Remove all duplicated whitespace from the message
                $message =~ s/(?<= ) | +$//g;

                if ( $i != $#lines && $lines[ $i + 1 ] !~ $pattern ) {
                    $message = "👇\n$message";
                }
                $message = tidy_line($message);

                # Collect all the lines until the end of the log message
                while ( $i != $#lines && $lines[ $i + 1 ] !~ $pattern ) {
                    my $next_line = tidy_line( $lines[ $i + 1 ] );
                    $message .= $next_line . "\n";
                    $i++;
                    $end_line = $i + 1;
                }

                if ( !defined($message) or $message eq "" ) {
                    $i += 1;
                    goto PARSELINE;
                }

                # Get the log details
                %log_details = (
                    'date'    => $date,
                    'time'    => $time,
                    'level'   => $level,
                    'message' => $message
                );

                # Get the log properties
                $log_properties{'title'}    = $title;
                $log_properties{'end_line'} = $end_line;

                last;
            }
        }

        # If we didn't find a log level from a known regex pattern,
        # do a generic check of the log message for a level indicator.
        if ( !defined($command) ) {
            my $fullmessage = $log_details{'message'};
            if ( $fullmessage =~ /(error|severe)/i ) {
                $command = 'error';
            }
            elsif ( $fullmessage =~ /(warning|warn)/i ) {
                $command = 'warning';
            }
            elsif ( $fullmessage =~ /(debug)/i ) {
                $command = 'debug';
            }
            else {
                $command = 'info';
            }
        }

        my $command_string           = $cmd_delimiter_string . $command . ' ';
        my @command_properties_array = ();
        %log_properties = escape_properties(%log_properties);

        foreach my $key ( keys %log_properties ) {
            if ( exists( $log_properties{$key} )
                && defined( $log_properties{$key} ) )
            {
                push @command_properties_array,
                  $key . "=" . $log_properties{$key};
            }
        }

        $command_string .= ( join ",", ( sort @command_properties_array ) );
        $command_string .= $cmd_delimiter_string;
        my $log_message_string    = '';
        my @command_details_order = ( 'date', 'time', 'level', 'message' );
        foreach my $key (@command_details_order) {
            if (   exists( $log_details{$key} )
                && defined( $log_details{$key} )
                && $log_details{$key} ne '' )
            {
                if ( $key ne 'message' ) {
                    $log_message_string .= "[" . $log_details{$key} . "] ";
                }
                else {
                    $log_message_string .= $log_details{$key};
                }
            }
        }
        $log_message_string = ( join '', escape_data($log_message_string) );

        print $command_string . $log_message_string . "\n";
    }
}

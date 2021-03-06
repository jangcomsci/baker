#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use utf8;
use Carp qw(croak);
use DateTime;
use feature qw(say);
use File::Basename qw(basename);
use File::Copy qw(copy);
use constant ARRAY => ref [];
use constant HASH  => ref {};


our $VERSION = '1.04';
our $LAST    = '2019-10-23';
our $FIRST   = '2017-01-02';


#----------------------------------My::Toolset----------------------------------
sub show_front_matter {
    # """Display the front matter."""
    
    my $prog_info_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be a hash ref!"
        unless ref $prog_info_href eq HASH;
    
    # Subroutine optional arguments
    my(
        $is_prog,
        $is_auth,
        $is_usage,
        $is_timestamp,
        $is_no_trailing_blkline,
        $is_no_newline,
        $is_copy,
    );
    my $lead_symb = '';
    foreach (@_) {
        $is_prog                = 1  if /prog/i;
        $is_auth                = 1  if /auth/i;
        $is_usage               = 1  if /usage/i;
        $is_timestamp           = 1  if /timestamp/i;
        $is_no_trailing_blkline = 1  if /no_trailing_blkline/i;
        $is_no_newline          = 1  if /no_newline/i;
        $is_copy                = 1  if /copy/i;
        # A single non-alphanumeric character
        $lead_symb              = $_ if /^[^a-zA-Z0-9]$/;
    }
    my $newline = $is_no_newline ? "" : "\n";
    
    #
    # Fill in the front matter array.
    #
    my @fm;
    my $k = 0;
    my $border_len = $lead_symb ? 69 : 70;
    my %borders = (
        '+' => $lead_symb.('+' x $border_len).$newline,
        '*' => $lead_symb.('*' x $border_len).$newline,
    );
    
    # Top rule
    if ($is_prog or $is_auth) {
        $fm[$k++] = $borders{'+'};
    }
    
    # Program info, except the usage
    if ($is_prog) {
        $fm[$k++] = sprintf(
            "%s%s - %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{titl},
            $prog_info_href->{expl},
            $newline,
        );
        $fm[$k++] = sprintf(
            "%s%s v%s (%s)%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{titl},
            $prog_info_href->{vers},
            $prog_info_href->{date_last},
            $newline,
        );
        $fm[$k++] = sprintf(
            "%sPerl %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $^V,
            $newline,
        );
    }
    
    # Timestamp
    if ($is_timestamp) {
        my %datetimes = construct_timestamps('-');
        $fm[$k++] = sprintf(
            "%sCurrent time: %s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $datetimes{ymdhms},
            $newline,
        );
    }
    
    # Author info
    if ($is_auth) {
        $fm[$k++] = $lead_symb.$newline if $is_prog;
        $fm[$k++] = sprintf(
            "%s%s%s",
            ($lead_symb ? $lead_symb.' ' : $lead_symb),
            $prog_info_href->{auth}{$_},
            $newline,
        ) for (
            'name',
#            'posi',
#            'affi',
            'mail',
        );
    }
    
    # Bottom rule
    if ($is_prog or $is_auth) {
        $fm[$k++] = $borders{'+'};
    }
    
    # Program usage: Leading symbols are not used.
    if ($is_usage) {
        $fm[$k++] = $newline if $is_prog or $is_auth;
        $fm[$k++] = $prog_info_href->{usage};
    }
    
    # Feed a blank line at the end of the front matter.
    if (not $is_no_trailing_blkline) {
        $fm[$k++] = $newline;
    }
    
    #
    # Print the front matter.
    #
    if ($is_copy) {
        return @fm;
    }
    else {
        print for @fm;
        return;
    }
}


sub validate_argv {
    # """Validate @ARGV against %cmd_opts."""
    
    my $argv_aref     = shift;
    my $cmd_opts_href = shift;
    my $sub_name = join('::', (caller(0))[0, 3]);
    croak "The 1st arg of [$sub_name] must be an array ref!"
        unless ref $argv_aref eq ARRAY;
    croak "The 2nd arg of [$sub_name] must be a hash ref!"
        unless ref $cmd_opts_href eq HASH;
    
    # For yn prompts
    my $the_prog = (caller(0))[1];
    my $yn;
    my $yn_msg = "    | Want to see the usage of $the_prog? [y/n]> ";
    
    #
    # Terminate the program if the number of required arguments passed
    # is not sufficient.
    #
    my $argv_req_num = shift; # (OPTIONAL) Number of required args
    if (defined $argv_req_num) {
        my $argv_req_num_passed = grep $_ !~ /-/, @$argv_aref;
        if ($argv_req_num_passed < $argv_req_num) {
            printf(
                "\n    | You have input %s nondash args,".
                " but we need %s nondash args.\n",
                $argv_req_num_passed,
                $argv_req_num,
            );
            print $yn_msg;
            while ($yn = <STDIN>) {
                system "perldoc $the_prog" if $yn =~ /\by\b/i;
                exit if $yn =~ /\b[yn]\b/i;
                print $yn_msg;
            }
        }
    }
    
    #
    # Count the number of correctly passed command-line options.
    #
    
    # Non-fnames
    my $num_corr_cmd_opts = 0;
    foreach my $arg (@$argv_aref) {
        foreach my $v (values %$cmd_opts_href) {
            if ($arg =~ /$v/i) {
                $num_corr_cmd_opts++;
                next;
            }
        }
    }
    
    # Fname-likes
    my $num_corr_fnames = 0;
    $num_corr_fnames = grep $_ !~ /^-/, @$argv_aref;
    $num_corr_cmd_opts += $num_corr_fnames;
    
    # Warn if "no" correct command-line options have been passed.
    if (not $num_corr_cmd_opts) {
        print "\n    | None of the command-line options was correct.\n";
        print $yn_msg;
        while ($yn = <STDIN>) {
            system "perldoc $the_prog" if $yn =~ /\by\b/i;
            exit if $yn =~ /\b[yn]\b/i;
            print $yn_msg;
        }
    }
    
    return;
}


sub show_elapsed_real_time {
    # """Show the elapsed real time."""
    
    my @opts = @_ if @_;
    
    # Parse optional arguments.
    my $is_return_copy = 0;
    my @del; # Garbage can
    foreach (@opts) {
        if (/copy/i) {
            $is_return_copy = 1;
            # Discard the 'copy' string to exclude it from
            # the optional strings that are to be printed.
            push @del, $_;
        }
    }
    my %dels = map { $_ => 1 } @del;
    @opts = grep !$dels{$_}, @opts;
    
    # Optional strings printing
    print for @opts;
    
    # Elapsed real time printing
    my $elapsed_real_time = sprintf("Elapsed real time: [%s s]", time - $^T);
    
    # Return values
    if ($is_return_copy) {
        return $elapsed_real_time;
    }
    else {
        say $elapsed_real_time;
        return;
    }
}


sub pause_shell {
    # """Pause the shell."""
    
    my $notif = $_[0] ? $_[0] : "Press enter to exit...";
    
    print $notif;
    while (<STDIN>) { last; }
    
    return;
}


sub construct_timestamps {
    # """Construct timestamps."""
    
    # Optional setting for the date component separator
    my $date_sep  = '';
    
    # Terminate the program if the argument passed
    # is not allowed to be a delimiter.
    my @delims = ('-', '_');
    if ($_[0]) {
        $date_sep = $_[0];
        my $is_correct_delim = grep $date_sep eq $_, @delims;
        croak "The date delimiter must be one of: [".join(', ', @delims)."]"
            unless $is_correct_delim;
    }
    
    # Construct and return a datetime hash.
    my $dt  = DateTime->now(time_zone => 'local');
    my $ymd = $dt->ymd($date_sep);
    my $hms = $dt->hms($date_sep ? ':' : '');
    (my $hm = $hms) =~ s/[0-9]{2}$//;
    
    my %datetimes = (
        none   => '', # Used for timestamp suppressing
        ymd    => $ymd,
        hms    => $hms,
        hm     => $hm,
        ymdhms => sprintf("%s%s%s", $ymd, ($date_sep ? ' ' : '_'), $hms),
        ymdhm  => sprintf("%s%s%s", $ymd, ($date_sep ? ' ' : '_'), $hm),
    );
    
    return %datetimes;
}
#-------------------------------------------------------------------------------


sub parse_argv {
    # """@ARGV parser"""
    
    my(
        $argv_aref,
        $cmd_opts_href,
        $run_opts_href,
    ) = @_;
    my %cmd_opts = %$cmd_opts_href; # For regexes
    
    foreach (@$argv_aref) {
        # Files to be backed up
        if (-e and not -d) {
            push @{$run_opts_href->{backup_fnames}}, $_;
        }
        
        # Timestamp level
        if (/$cmd_opts{timestamp}/) {
            s/$cmd_opts{timestamp}//i;
            $run_opts_href->{timestamp} = $_;
        }
        
        # Timestamp position
        if (/$cmd_opts{timestamp_pos}/) {
            s/$cmd_opts{timestamp_pos}//i;
            $run_opts_href->{timestamp_pos} = $_;
        }
        
        # The front matter won't be displayed at the beginning of the program.
        if (/$cmd_opts{nofm}/) {
            $run_opts_href->{is_nofm} = 1;
        }
        
        # The shell won't be paused at the end of the program.
        if (/$cmd_opts{nopause}/) {
            $run_opts_href->{is_nopause} = 1;
        }
    }
    
    return;
}


sub baker {
    # """Back up the designated files."""
    
    my $run_opts_href = shift;
    my %datetimes = construct_timestamps();
    my $timestamp_of_int =
        $run_opts_href->{timestamp} =~ /\bdt\b/i   ? $datetimes{ymdhm} :
        $run_opts_href->{timestamp} =~ /\bnone\b/i ? '' :
                                                     $datetimes{ymd};
    my $timestamp_pos = $run_opts_href->{timestamp_pos};
    
    # Define filename elements.
    my($bname, $ext, $fname_new, $subdir);
    my %fname_old_and_new;
    my $lengthiest  = '';
    my $path_delim  = $^O =~ /MSWin/i ? '\\' : '/';
    my $path_of_int = '.';
    my $backup_flag = 'bak_'; # Used as the prefix of backup dirs
    
    foreach my $fname_old (@{$run_opts_href->{backup_fnames}}) {
        # Find the lengthiest filename to construct a conversion.
        $lengthiest = $fname_old if length($fname_old) > length($lengthiest);
        
        # Dissociate a filename and define a backup filename.
        ($bname = $fname_old) =~ s/(.*)([.]\w+)$/$1/;
        ($ext   = $fname_old) =~ s/(.*)([.]\w+)$/$2/;
        $fname_new = sprintf(
            "%s%s%s",
            $timestamp_pos =~ /front/i ? $timestamp_of_int : $bname,
            ($timestamp_of_int ? '_' : ''),
            $timestamp_pos =~ /front/i ? $bname : $timestamp_of_int,
        );
        $fname_new = $fname_new.$ext if $ext ne $fname_old;
        
        # Buffer the old and new fnames as key-val pairs.
        $subdir = $path_of_int.$path_delim.$backup_flag.$fname_old;
        $fname_old_and_new{$fname_old} = [
            $subdir,
            $subdir.$path_delim.$fname_new,
        ];
    }
    
    # Back up the designated files following displaying.
    if (%fname_old_and_new) {
        say '-' x 70;
        my $conv = '%-'.length($lengthiest).'s';
        while (my($k, $v) = each %fname_old_and_new) {
            printf("$conv => %s\n", $k, $v->[1]);
            mkdir $v->[0] if not -e $v->[0];
            copy($k, $v->[1]);
        }
        say '-' x 70;
    }
    print %fname_old_and_new ?
        "Backing up completed. " :
        "None of the designated files found in [$path_of_int$path_delim].\n";
    
    return;
}


sub outer_baker {
    if (@ARGV) {
        my %prog_info = (
            titl       => basename($0, '.pl'),
            expl       => 'File backup assistant',
            vers       => $VERSION,
            date_last  => $LAST,
            date_first => $FIRST,
            auth       => {
                name => 'Jaewoong Jang',
#                posi => '',
#                affi => '',
                mail => 'jangj@korea.ac.kr',
            },
        );
        my %cmd_opts = ( # Command-line opts
            timestamp     => qr/-?-(?:timestamp|ts|dt)\s*=\s*/i, # dt: legacy
            timestamp_pos => qr/-?-(?:timestamp_)?pos\s*=\s*/i,
            nofm          => qr/-?-nofm\b/i,
            nopause       => qr/-?-nopause\b/i,
        );
        my %run_opts = ( # Program run opts
            backup_fnames => [],
            timestamp     => 'd',    # d, dt, none
            timestamp_pos => 'rear', # front, rear
            is_nofm       => 0,
            is_nopause    => 0,
        );
        
        # ARGV validation and parsing
        validate_argv(\@ARGV, \%cmd_opts);
        parse_argv(\@ARGV, \%cmd_opts, \%run_opts);
        
        # Notification - beginning
        show_front_matter(\%prog_info, 'prog', 'auth', 'no_trailing_blkline')
            unless $run_opts{is_nofm};
        
        # Main
        baker(\%run_opts);
        
        # Notification - end
        $run_opts{is_nopause} ? print "\n" : pause_shell();
    }
    
    system("perldoc \"$0\"") if not @ARGV;
    
    return;
}


outer_baker();
__END__

=head1 NAME

baker - File backup assistant

=head1 SYNOPSIS

    perl baker.pl [file ...] [-timestamp=key] [-timestamp_pos=front|rear]
                  [-nofm] [-nopause]

=head1 DESCRIPTION

Back up files into respective subdirectories prefixed by 'bak_'.

=head1 OPTIONS

    -timestamp=key (short term: -ts)
        d (default)
            Timestamp up to yyyymmdd
        dt
            Timestamp up to yyyymmdd_hhmm
        none
            No timestamp

    -timestamp_pos=front|rear (short term: -pos, default: rear)
        front
            Timestamping before the filename
        rear
            Timestamping after the filename

    -nofm
        The front matter will not be displayed at the beginning of the program.

    -nopause
        The shell will not be paused at the end of the program.
        Use it for a batch run.

=head1 EXAMPLES

    perl baker.pl oliver.eps heaviside.dat
    perl baker.pl bateman.ps -ts=d
    perl baker.pl harry_bateman.ps -ts=none

=head1 REQUIREMENTS

Perl 5

=head1 SEE ALSO

L<baker on GitHub|https://github.com/jangcom/baker>

=head1 AUTHOR

Jaewoong Jang <jangj@korea.ac.kr>

=head1 COPYRIGHT

Copyright (c) 2017-2019 Jaewoong Jang

=head1 LICENSE

This software is available under the MIT license;
the license information is found in 'LICENSE'.

=cut

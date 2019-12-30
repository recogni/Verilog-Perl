#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2000-2019 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

use IO::File;
use strict;
use Test::More;

BEGIN { plan tests => 6 }
BEGIN { require "./t/test_utils.pl"; }

print "Checking vpassert...\n";

# Preprocess the files
mkdir "test_dir/.vpassert", 0777;
mkdir "test_dir/.vpassertcall", 0777;
system ("/bin/rm -rf test_dir/verilog");
symlink ("../verilog", "test_dir/verilog");  # So `line files are found; ok if fails
run_system ("${PERL} ./vpassert --minimum --nostop --date --axiom --verilator --vcs --synthcov"
	    ." -o test_dir/.vpassert -y verilog/");
ok(1, "vpassert ran");
ok(-r 'test_dir/.vpassert/pli.v', "pli.v created");

ok(compare('lines', [glob("test_dir/.vpassert/*.v")]), "lines output");
ok(compare('diff',  [glob("test_dir/.vpassert/*.v")]), "diff output");

# Preprocess with custom outputters
run_system ("${PERL} ./vpassert --date --verilator --vcs"
	    .q{ --call-error '$callError'}
	    .q{ --call-info '$callInfo'}
	    .q{ --call-warn '$callWarn'}
	    ." -o test_dir/.vpassertcall -y verilog/");
ok(files_identical("test_dir/.vpassertcall/example.v", "t/60_vpassert.out"), "diff");

# Build the model
unlink "simv";
chdir 'test_dir';
SKIP: {
    skip("author only test (harmless)",1)
	if (!$ENV{VERILATOR_AUTHOR_SITE});

    if ($ENV{VCS_HOME} && -r "$ENV{VCS_HOME}/bin/vcs") {
	run_system (# We use VCS, insert your simulator here
		    "$ENV{VCS_HOME}/bin/vcs"
		    # check line coverage
		    ." -cm line+assert"
		    # vpassert optionally uses SystemVerilog coverage for $ucover_clk
		    ." -sverilog"
		    # vpassert uses `pli to point to the hierarchy of the pli module
		    ." +define+pli=pli"
		    # vpassert uses `__message_on to point to the message on variable
		    ." +define+__message_on=pli.message_on"
		    # vpassert --minimum uses `__message_minimum to optimize away some messages
		    ." +define+__message_minimum=1"
		    # Read files from .vpassert BEFORE reading from other directories
		    ." +librescan +libext+.v -y .vpassert"
		    # Finally, read the needed top level file
		    ." .vpassert/example.v"
	    );
	# Execute the model (VCS is a compiled simulator)
	run_system ("./simv");
	unlink ("./simv");
	ok(1, "vcs sim");
    }
    elsif ($ENV{NC_ROOT} && -d "$ENV{NC_ROOT}/tools") {
	run_system ("ncverilog"
		    ." -q"
		    # vpassert optionally uses SystemVerilog coverage for $ucover_clk
		    ." +sv"
		    # vpassert uses `pli to point to the hierarchy of the pli module
		    ." +define+pli=pli"
		    # vpassert uses `__message_on to point to the message on variable
		    ." +define+__message_on=pli.message_on"
		    # vpassert --minimum uses `__message_minimum to optimize away some messages
		    ." +define+__message_minimum=1"
		    # Read files from .vpassert BEFORE reading from other directories
		    ." +librescan +libext+.v -y .vpassert"
		    # Finally, read the needed top level file
		    ." .vpassert/example.v"
	    );
	ok(1, "ncv sim");
    }
    else {
	warn "\n";
	warn "*** You do not seem to have VCS or NC-Verilog installed, not running rest of test.\n";
	warn "*** (If you do not license VCS/NC-Verilog, ignore this warning).\n";
	skip("No simulator found",1);
    }
}
chdir '..';

sub lines_in {
    my $filename = shift;
    my $fh = IO::File->new($filename) or die "%Error: $! $filename";
    my @lines = $fh->getlines();
    @lines = grep (!/\`line/, @lines);
    return $#lines;
}

sub compare {
    my $mode = shift;
    my $files = shift;
    my $ok = 1;
  file:
    foreach my $file (@{$files}) {
	$file =~ s!.*/!!;
	# SPECIAL FILES we processed!
	next if $file eq 'example.v';
	next if $file eq 'pli.v';


	my $fn1 = "verilog/$file";
	my $fn2 = "test_dir/.vpassert/$file";
	if ($mode eq 'lines') {
	    my $orig_lines = lines_in($fn1);
	    my $new_lines = lines_in($fn2);
	    if ($orig_lines!=$new_lines)  { $ok=0; print "%Error: "; }
	    print "Line count: $file: $orig_lines =? $new_lines\n";
	}
	elsif ($mode eq 'diff') {
	    my $f1 = IO::File->new ($fn1) or die "%Error: $! $fn1,";
	    my $f2 = IO::File->new ($fn2) or die "%Error: $! $fn2,";
	    my @l1 = $f1->getlines();
	    my @l2 = $f2->getlines();
	    @l1 = grep (!/`line/, @l1);
	    @l2 = grep (!/`line/, @l2);
	    my $nl = $#l1;  $nl = $#l2 if ($#l2 > $nl);
	    for (my $l=0; $l<=$nl; $l++) {
		next if $l2[$l] =~ /vpassert/;
		if (($l1[$l]||"") ne ($l2[$l]||"")) {
		    warn ("%Warning: Line ".($l+1)." mismatches; diff $fn1 $fn2\n"
			  ."F1: ".($l1[$l]||"*EOF*\n")
			  ."F2: ".($l2[$l]||"*EOF*\n"));
		    $ok = 0;
		    next file;
		}
	    }
	}
	else { die; }
    }
    return $ok;
}

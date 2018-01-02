#!/usr/bin/env perl

package my_formatter;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/deps/lib/perl5";

use Test::Builder;
use Test2::API qw(intercept test2_stack);
use File::Basename qw();
use File::Slurp;

#banner();

foreach my $file (@ARGV) {
	run($file);
}

sub run {
	my ($file) = @_;
	my $stack = test2_stack();

	my $formatter = my_formatter->new(
		file => $file,
		verbose => 1,
	);

	my $hub = $stack->new_hub(
		formatter => $formatter,
	);

	do $file;

	print "$@" if $@;

	$formatter->wrapup();

	$stack->pop($hub);
}

sub new {
	my ($class, %args) = @_;
	my $file = $args{file};

	return bless {
		basename => File::Basename::basename($file),
		file     => $file,
		parents  => [],
		verbose  => $args{verbose},
		current_failure => undef,
	}, $class;
}

sub color {
	my ($bg, $fg, @m) = @_;
	return "\x1b["
		. join(
			';',
			( $fg ? sprintf("38;5;%s", $fg) : ()),
			( $bg ? sprintf("48;5;%s", $bg) : ()),
		) . 'm'
		. join('', map { s/\t/  /gr } @m )
		. "\x1b[0m"
}


sub write {
	my ($self, $event, $assert_num) = @_;
	my $trace = $event->trace;
	eval {
		if($event->isa('Test2::Event::Ok')) {
			my $is_subtest = $event->isa('Test2::Event::Subtest');
			my $pass = $event->effective_pass;
			my $f = $event->facets;
			my $test_name = $event->name || '[anon]';
			$self->{current_failure} = $pass ? undef : $event;

			$self->{tests}++;
			if($pass) {
				$self->{passed}++;
			}
			else {
				$self->{fail}++;
			}

			if($is_subtest) {
				pop(@{$self->{parents}});
			}

			if($pass) {
				if($self->{verbose}) {
					print "  ",
						color(0, 28, "✔"),
						" ",
						join(
							color(0, 238,  " ≻ "),
							$self->{basename},
							@{$self->{parents}},
							$test_name,
						),
						"\n";
				}
			}
			else {
				print "  ",
					color(0, 125, "✕"),
					" ",
					join(
						color(0, 238,  " ≻ "),
						$self->{basename},
						@{$self->{parents}},
						$test_name,
					),
					"\n";

				my $fail_line = $event->trace->frame->[2];
				my $fail_file = $event->trace->frame->[1];
				my @fail_lines = splice(
					[File::Slurp::read_file($fail_file)],
					$fail_line - 2,
					3
				);

				print "    ",
					color(
						0, 238,
						File::Basename::basename($fail_file),
						':',
						$fail_line,
					), "\n\n";

				my $line_n = $fail_line - 2;
				foreach my $line (@fail_lines) {
					my $bg = $fail_line == $line_n + 3 ? 161 : 0;
					chomp($line);
					print "    ";
					print color($bg, 238, " ", $fail_line++, ": ");
					print color($bg, 0, $line), "\n";
				}
				print "\n";
			}
		}
		elsif($event->isa('Test2::Event::Note')) {
			if(my ($subtest) = $event->message =~ /Subtest: (.*)/) {
				push(@{$self->{parents}}, $subtest);
			}
		}
		elsif($event->isa('Test2::Event::Diag')) {
			# TODO: Hack these are meaningless diag :(
			if($event->message !~ /Failed test/) {
				print "    Message:\n\n";

				print map { "      " . $_ . "\n" } split(/\n/, $event->message);
				print "\n";
			}
		}
	};


	print "$@" if $@;
}

sub banner {
print color(0, 120, "
         #
         #      ######
      ########  #    #
       #        ######
       #        #    #
       #       #######
       #       #    #
        ##### #     #
             #   ###
      
       ###############
              #
              #
        #############
              #
              #
      #################\n");
}

sub new_root {}
sub terminate {}

sub finalize {}

sub wrapup {
	my ($self) = @_;

	printf "\n  %s (passed %d of %d)\n",
		File::Basename::basename($self->{file}),
		$self->{passed},
		$self->{tests};
}


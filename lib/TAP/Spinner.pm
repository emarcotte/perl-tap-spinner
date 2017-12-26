package TAP::Spinner;

use strict;
use warnings;

our $VERSION = '1.0';

use AnyEvent::Util;
use AnyEvent;
use Curses::UI::AnyEvent;
use Data::Dumper;
use File::Basename;
use File::Hotfolder;
use JSON;
use TAP::Harness::Spinner;
use Term::ANSIColor qw();

use utf8;

my $spinner_chars = '⣾⣽⣻⢿⡿⣟⣯⣷';

sub new {
	return bless {
		current_message => '',
		current_spinner => 0,
		running_test    => 0,
	}, __PACKAGE__;
}

sub run_test {
	my ($self, $test) = @_;

	my $file = File::Basename::basename($test);

	$self->{current_message} = "Test $file ...";

	my ($r, $w) = portable_pipe;

	my $spinner_updater; $spinner_updater = AE::timer 0, .25, sub {
		$self->{current_spinner} = ($self->{current_spinner} + 1)
			% length($spinner_chars);
		$self->show_header();
	};

	my $test_updates; $test_updates = AE::io $r, 0, sub {
		my $msg = <$r>;
		if(!defined $msg) {
			undef $test_updates;
		}
		elsif($msg) {
			eval {
				my $msg = JSON::decode_json($msg);
				if($msg->{type} eq 'status') {
					my ($pass, $skip, $fail) = @{$msg->{data}};
					$self->{current_message} = "Test $file (pass: $pass, fail: $fail, skip: $skip)";
				}
				else {
					$self->update_buffer($msg->{data} . "\n", 1);
				}
			};
			if($@) {
				$self->update_buffer($@, 1);
			}
		}
	};

	$self->{running_test} = 1;

	fork_call {
		my $watcher = TAP::Harness::Spinner->new({
			writer => $w,
		});
		$watcher->runtests($test);
		0;
	} sub {
		if(my $error = $! || $@) {
			$self->update_buffer($error, 1);
		}
		$self->{running_test} = 0;
		undef $spinner_updater;
		$self->show_header;
	}
}

sub show_header {
	my ($self) = @_;
	my $textviewer = $self->{status_line};
	my $current_spinner = $self->{current_spinner};
	my $current_message = $self->{current_message} || "";
	my $prefix = $self->{running_test} ?
		substr($spinner_chars, $current_spinner, 1)
		: '✔';
	$textviewer->{-text} =  "$prefix $current_message";
	$textviewer->draw;
}

sub update_buffer {
	my ($self, $dump, $append) = @_;
	my $textviewer = $self->{test_text};
	if($append) {
		$textviewer->{-text} .= $dump;
	}
	else {
		$textviewer->{-text} = $dump;
	}
	$textviewer->draw;
}

sub go {
	my ($self, @paths) = @_;

	my $inotify_cb = sub {
		my $path = shift;
		if($path =~ /[.]t$/) {
			$self->update_buffer("");
			$self->run_test($path);
		}
	};

	my @hot_folders = map {
		File::Hotfolder->new(
			watch => $_,
			callback => $inotify_cb,
		)->anyevent;
	} @paths;

	my $cui = $self->{cui} = Curses::UI::AnyEvent->new(
		-color_support => 1,
		-clear_on_exit => 1,
	);

	$cui->set_binding(sub { exit; }, "\cC");

	my $win = $self->{window} = $cui->add('window_id', 'Window');

	my $status_line = $self->{status_line} = $win->add(
		'label',       => 'Label',
		-text          => 'A bit of text',
		-width         => -1,
	);

	my $textviewer = $self->{test_text} = $win->add(
		'mytextviewer', 'TextViewer',
		-padtop => 1,
		-text   => "",
	);

	$textviewer->focus();

	# start the event loop
	eval {
		$cui->startAsync;
		AE::cv->recv;
	};
	undef $cui;
	print "Error $@\n";
}

1;

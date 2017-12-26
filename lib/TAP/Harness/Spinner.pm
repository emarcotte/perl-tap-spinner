package TAP::Harness::Spinner;

use strict;
use warnings;

use parent qw(TAP::Harness);

use JSON;

sub new {
	my ($class, $args) = @_;

	my $self = $class->SUPER::new({
		verbosity => -3,
	});

	$self->{writer} = $args->{writer};
	$self->{total} = 0;
	$self->{pass} = 0;
	$self->{fail} = 0;
	$self->{skip} = 0;
	$self->{results} = {};
	$self->{parserjobs} = {};
	return $self;
}

sub make_parser {
	my ($self, $job) = @_;
	my ($parser, $session) = $self->SUPER::make_parser($job);
	$self->{parserjobs}{$parser} = $job->filename;

	$parser->callback(
		plan => sub {
			my ($plan) = @_;
			$self->{total} += $plan->tests_planned;
			$self->update_status();
		}
	);

	$parser->callback(
		test => sub {
			my ($result) = @_;

			if($result->has_skip) {
				$self->{skip}++;
			}
			elsif($result->is_ok) {
				$self->{pass}++;
			}
			else {
				$self->{fail}++;
			}

			$self->update_status();

		},
	);

	$parser->callback(
		ALL => sub {
			my ($result) = @_;
			$self->output($result->raw());
		}
	);

	$parser->callback(
		unknown => sub {
			my ($result) = @_;
		},
	);
	return ($parser, $session);
}

sub _get_parser_args {
	my ($self, $job) = @_;
	my $args = $self->SUPER::_get_parser_args($job);
	$args->{merge} = 1;
	return $args;
}

sub summary {
	my ($self, @args) = @_;
	$self->{finished} = [@args];
}

sub output {
	my ($self, $output) = @_;
	$self->send({
		type => 'output',
		data => $output,
	});
}

sub send {
	my ($self, $data) = @_;
	$self->{writer}->printflush(JSON::encode_json($data), "\n");
}

sub update_status {
	my ($self) = @_;

	my $nr = $self->{total};
	my $pass = $self->{pass};
	my $skip = $self->{skip};
	my $fail = $self->{fail};

	$self->send({
		type => 'status',
		data => [$pass, $skip, $fail],
	});
}

1;

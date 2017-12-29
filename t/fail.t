#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 3;

ok(1, "This test failed");

subtest A_sub => sub {
	is(0, 1, 'Subtest');
	subtest B_sub => sub {
		ok(1, "inner inner");
	};
};

subtest C_sub => sub {
	ok(1, "The end");
};

#!/usr/bin/env perl

use Module::Build;

my $build = Module::Build->new(
	module_name   => 'TAP::Spinner',
	dist_author   => 'Eugene Marcotte <emarcotte@gmail.com>',
	license       => 'perl',
	dist_abstract => 'A TAP Harness/script that does things similar to avajs.',
	requires      => {
		'AnyEvent' => '7.04',
		'Curses::UI::AnyEvent' => '0.101',
		'File::Hotfolder' => '0.04',
		'JSON' => '2.53',
		'TAP::Harness' => '3.33',
	},
);

$build->create_build_script;

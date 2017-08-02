#!/usr/bin/perl -w
package HL7view;
require Exporter;
@ISA = qw(Exporter);

use strict;
use warnings;

my $ww_status = 0;

my $txt;
my $hl7_txt_box;
my $error_txt_box;
my $hl7_pretty_txt_box;
my $nc_txt_box;

sub display
{
	my @msg		= @_;

	our $mw = MainWindow->new;
	$mw->geometry("800x600");
	$mw->title("TXT View");

	#Declare that there is a menu
	my $mbar = $mw -> Menu();
	my $frame_top = $mw->Frame
	(
		-height => 1,
	)->pack
	(
		-side => "top",
		-expand=> 0,
		-fill => "x",
		-anchor => 'n'
	);
	my $frame_bottom = $mw->Frame
	(
		-height => 1,
	)->pack
	(
		-side => "bottom",
		-expand=> 1,
		-fill => "both",
		-anchor => 's'
	);
	$frame_top->Button
	(
		-text    => 'Word Wrap',
		-command => sub
		{
			&main::pl("toggle word wrap\n");
			&set_word_wrap($ww_status);
		}
	)->pack
	(
		-side => "left",
		-expand=> 1,
		-fill => "x",
	# 	-anchor => 'w'
	);
	$frame_top->Button
	(
		-text    => 'Close',
		-command => sub
		{
			&main::pl("close info\n");
			$mw->destroy;
		}
	)->pack
	(
		-side => "left",
		-expand=> 1,
		-fill => "x",
	# 	-anchor => 'w'
	);

	my $msg_txt_box = make_text_box('msg', $frame_bottom, 8, 1);
	$msg_txt_box->Contents(@msg);
	$msg_txt_box->configure(-wrap=>"none");
}

sub make_text_box
{
	my $name = shift;
	my $parent = shift;
	my $height = shift;

	my $expand = shift;
	my $fill = 'both';

	$expand = 0 if ! defined $expand;
	$fill = 'x' if !$expand;

# 	&main::pl("view: $name\n");

	my $t = $parent->Scrolled
	(
		'Text',
		-scrollbars => 'se',
		-background => 'black',
		-foreground => 'cyan',
		-wrap => 'none',
		-height => $height,
	)->pack
	(
		-side => "bottom",
		-expand=> $expand,
		-fill => $fill,
	);

 	if(defined $main::ini->{appearance}{'font1'})
	{
		my $f = $main::ini->{appearance}{'font1'};
# 		&main::pl("setting view box font to $f\n");
		$t->configure(-font => $f);
	}
	return $t;
}

1;
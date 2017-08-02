#!/usr/bin/perl

use warnings;
use strict;
use Tk;
use Tk::HListbox;
use FindBin qw($Bin);

my %options = ( ReturnType => "index" );

my $MW = MainWindow->new();
my $licon=$MW->Photo();  #ICON IMAGE
my $wicon=$MW->Photo();  #ICON IMAGE
my $lbox = $MW->Scrolled
(
	'HListbox',
	-scrollbars => 'se',
	-selectmode => 'extended',
	-itemtype => 'imagetext',
	-indicator => 1,
	-indicatorcmd => sub
	{
		print STDERR "---indicator clicked---(".join('|',@_).")\n";
	},
	-browsecmd => sub
	{
		print STDERR "---browsecmd!---(".join('|',@_).")\n";
	},
)->pack(-fill => 'y', -expand => 1);

#MAIN WINDOW BUTTON TO QUIT.
$MW->Button
(
	-text => 'Quit',
	-underline => 0,
	-command => sub { print "ok 5\n..done: 5 tests completed.\n"; exit(0) }
)->pack(
	-side => 'bottom'
);

#ADD SOME ITEMS (IMAGE+TEXT) TO OUR LISTBOX THE TRADITIONAL WAY:
my @list =
(
	{-image => $licon, -text => 'a' },
	{-image => $wicon, -text => 'bbbbbbbbbbbbbbbbbbbB', -foreground => '#0000FF' },
	{-text => 'c', -image => $licon },
	{-text => 'd:image & indicator!', -image => $licon, -indicatoritemtype, 'image', -indicatorimage => $wicon },
	{-image => $licon, -text => 'e' },
	{-image => $licon, -text => 'f:Switch sides!', -textanchor => 'w' },
	{-image => $licon, -text => 'z:Next is Image Only!' },
	$licon
);
$lbox->insert('end', @list );
@list = ();

MainLoop;
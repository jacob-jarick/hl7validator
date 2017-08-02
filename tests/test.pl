#!/usr/bin/perl -w

## THIS IS ONE OF THE TEST SCRIPTS THAT HANS PROVIDED WITH MLISTBOX
## It IS STILL UNDERGOING EDITS BY ME - RCS

## MListbox demonstration application. This is a simple directory browser
## Original Author: Hans J. Helgesen, December 1999.
## Modified by: Rob Seegel, to work in Win32 as well
## Use and abuse this code. I did - RCS

use File::stat;
use Tk;
use Tk::MListbox;

## Create main perl/tk window.
my $mw = MainWindow->new;

## Create the MListbox widget.
## Specify alternative comparison routine for integers and date.
## frame, but since the "Show All" button references $ml, we have to create
## it now.

my %red   = qw(-bg red -fg white);
my %green = qw(-bg green -fg white);
my %white = qw(-fg black);

my $ml = $mw->Scrolled(
  'MListbox',
  -scrollbars         => 'osoe',
  -background         => 'white',
  -foreground         => 'blue',
  -textwidth          => 10,
  -highlightthickness => 2,
  -width              => 0,
  -selectmode         => 'browse',
  -bd                 => 2,
  -relief             => 'sunken',
  -columns            => [
    [ qw/-text Line_Number -textwidth 10/,	%white,  -comparecmd => sub { $_[0] <=> $_[1] }],
    [ qw/-text Type -textwidth 5/,		%white, -comparecmd => sub { $_[0] <=> $_[1] } ],
    [ qw/-text UID/,                		%white ],
    [ qw/-text Length/,               		%white,   -comparecmd => sub { $_[0] <=> $_[1] } ],
  ]
);

## Put the exit button and the "Show All" button in
## a separate frame.
my $f = $mw->Frame
(
  -bd     => 2,
  -relief => 'groove'
)->pack(qw/-anchor w -expand 0 -fill x/);

$f->Button
(
	-text    => 'Refresh',
	-command => sub
	{

	}
)->pack
(
	qw/-side left -anchor w/
);

$f->Button
(
	-text    => 'Show All',
	-command => sub
	{
		foreach ( $ml->columnGet( 0, 'end' ) )
		{
			$ml->columnShow($_);
		}
	}
)->pack
(
	qw/-side left -anchor w/
);

# Put the MListbox widget on the bottom of the main window.
$ml->pack
(
	-expand => 1,
	-fill => 'both',
	-anchor => 'w'
);

# Double clicking any of the data rows calls openFileOrDir()
# (But only directories are handled for now...)
$ml->bindRows( "<Double-Button-1>", \&todo );

# Right-clicking the column heading creates the hide/show popup menu.
$ml->bindColumns( "<Button-3>", [ \&columnPopup ] );

$ml->bindRows
(
	'<ButtonRelease-1>',
	sub
	{
		my ( $w, $infoHR ) = @_;
		print "You selected row: " . $infoHR->{-row} . " in column: " . $infoHR->{-column} . "\n";
	}
);

MainLoop;

#----------------------------------------------------------
#

sub todo
{
	print "TODO: implement this. ARGS: @_";
}

sub update_mlist
{
	$ml->delete( 0, 'end' );

	my %hash_stub = ();

	foreach my $k (keys %hash_stub  )	# TODO sort through hash
	{
		my $line_number = 0;
		my $uid = '';
		my $type = '';
		my $flags = 'PASS';

		$ml->insert( 'end', [ $line_number, $flags, $uid, $type ] );
	}
}


# This callback is called if the user right-clicks the column heading.
# Create a popupmenu with hide/show options.
sub columnPopup
{
	my ( $w, $infoHR ) = @_;

	# Create popup menu.
	my $menu = $w->Menu( -tearoff => 0 );
	my $index = $infoHR->{'-column'};

	# First item is "Hide (this column)".
	#
	$menu->add
	(
		'command',
		-label   => "Hide " . $w->columnGet($index)->cget( -text ),
		-command => sub
		{
			$w->columnHide($index);
		}
	);
	$menu->add('separator');

	# Create a "Show" entry for each column that is not currently visible.
	#
	foreach ( $w->columnGet( 0, 'end' ) ) # Get all columns from $w.
	{
		unless ( $_->ismapped )
		{
			$menu->add
			(
				'command',
				-label   => "Show " . $_->cget( -text ),
				-command => [ $w => 'columnShow', $_, -before => $index ],
			);
		}
	}
	$menu->Popup( -popover => 'cursor' );
}


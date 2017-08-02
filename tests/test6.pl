#!/usr/bin/perl
use Tk;
use Tk::Balloon;

# the scrolled canvas causes problems with balloon
# unless you use the subwidget

my $mw = MainWindow->new;

my $canvas = $mw->Scrolled('Canvas', -takefocus => 0)->pack(
    -expand => 1,
    -fill   => 'both',
);

my $id = $canvas->createText(
    5, 5,
    -text   => 'hello',
    -anchor => 'nw',
);
my %messages = ();
$messages{$id} = "there";

my $balloon = $canvas->Balloon();
$balloon->attach($canvas->Subwidget('canvas'),
    -balloonposition => 'mouse',
    -msg             => \%messages,
);

MainLoop();
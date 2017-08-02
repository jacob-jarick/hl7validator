#! /usr/local/bin/perl -w

require 5.005;

use strict;
use English;

use Tk;

# Create main window with button and text widget in it...
my $top = MainWindow->new;
my $btn = $top->Button(-text=>'High Selected Range')->pack;
my $start = 1;
my $end = 6;
my $e = $top->Entry(-textvariable => \$start)->pack(-expand => 1, -fill => 'x');
my $e2 = $top->Entry(-textvariable => \$end)->pack(-expand => 1, -fill => 'x');

my $txt = $top->Scrolled('Text', -relief=>'sunken', -borderwidth=>'2', -setgrid=>'true', -height=>'30', -scrollbars=>'e');
$txt->pack(-expand=>'yes', -fill=>'both');
$btn->configure
(
	-command=>sub
	{
		$txt->Contents([]);
		&fill_text($txt, $start, $end);
# 		&GetText($txt);
	}
);

# Populate text widget with lines tagged odd and even...
my $lno;
my $oddeven;

my $txt_str = 'aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ';

&fill_text($txt, $start, $end);

# Do the main processing loop...
MainLoop();

sub fill_text
{
	my $txtobj = shift;
	my $start = shift;
	my $end = shift;

	my @arr = split(//, $txt_str);
	for my $i(0 .. $#arr)
	{
		print "$arr[$i]\n";
		if($i >= $start && $i <= $end)
		{
			$txtobj->insert ('end', $arr[$i], 'odd');
		}
		else
		{
			$txtobj->insert ('end', $arr[$i], 'even');
		}
	}
	$txtobj->tag('configure', 'odd', -background=>'lightblue');
	$txtobj->tag('configure', 'even', -background=>'lightgreen');
}


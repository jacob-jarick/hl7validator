#!/usr/bin/perl -w
package list;
require Exporter;
@ISA = qw(Exporter);

use strict;
use warnings;

use File::stat;
use Tk;
use Data::Dumper::Concise;
use Tk::HList;

my %red   = qw(-bg red -fg white);
my %green = qw(-bg green -fg white);
my %white = qw(-fg black);
my $ml;

our $hlist2;

our $rc_menu;

my $hlist_selection;
my $hl_counter = 0;

sub update_hlist
{
	my $ref = shift;
	$hlist2->delete('all');
	$hl_counter = 0;

	my %hash = %$ref;

	$main::percent_done = 0;
	my $total_keys = scalar keys %hash;
	my $count = 0;
	foreach my $k (sort {$hash{$a}{line_number}  <=> $hash{$b}{line_number} }  keys %hash  )
	{
		$count++;
		$main::percent_done = int(($count/$total_keys) * 100);

		my @tmp = ();

		my $log_line = '';
		if(defined $hash{$k}{nc_log})
		{
			$log_line = $hash{$k}{nc_log};
			$log_line =~ s/\n|\r|\015/ /g;
		}

		push @tmp,
		$hash{$k}{line_number},

		$hash{$k}{flags},
		$hash{$k}{type},
		$log_line,
		$hash{$k}{uid},
		$hash{$k}{length},
		$hash{$k}{line_numbers}
		;
		hlist_print(@tmp);
		&main::pl(".");
	}
	&main::pl("\nList Updated, $count entries\n");
}

sub make_rc_menu
{
        $rc_menu = $hlist2->Menu(-tearoff=>0);
        $rc_menu -> command
        (
		-label=>"Hide",
		-underline=> 1,
		-command=> sub
		{
			my ($uid) = $hlist2->info("data", $hlist_selection);
			$hlist2->delete('entry', $hlist_selection);
			&main::pl("Hide $hlist_selection, $uid\n");



       		}
	);
        $rc_menu -> command
        (
		-label=>"View",
		-underline=> 1,
		-command=> sub
		{
			my ($uid) = $hlist2->info("data", $hlist_selection);

# 			HL7view::display(Dumper($HL7::pos_hash{$uid}));
			HL7tree::display($uid);

			&main::pl("Inspecting $uid\n");
       		}
	);

        $hlist2->bind('<Any-ButtonPress-3>', \&show_rc_menu);
        $hlist2->bind('<Any-ButtonPress-1>',[\&hide_rc_menu, $rc_menu]);
        $hlist2->bind('<Any-ButtonPress-2>',[\&hide_rc_menu, $rc_menu]);
}

sub show_rc_menu
{
# 	&main::pl("sub show_rc_menu\n");
	my ($x, $y) = $main::mw->pointerxy;

	my $s = $hlist2->nearest($y - $hlist2->rooty);
	$hlist2->selectionClear();
	$hlist2->selectionSet($s);
	$hlist_selection = $s;
	$rc_menu->post($x,$y);
}

sub hide_rc_menu
{
# 	&main::pl("sub hide_rc_menu ");
	my ($l,$m)=@_;
	$m->unpost();
}


sub draw_hlist
{
	my $parent = shift;

# 	&main::pl("sub draw_list\n");
	my $columns = 10;

	if($hlist2)
	{
		$hlist2->destroy;
	}

        our $hlist2 = $parent->Scrolled
        (
		"HList",
		-scrollbars=>"osoe",
		-header => 1,
		-columns=>$columns,
		-selectbackground => 'Cyan',
		-font=>$main::font,
		-browsecmd => sub
		{
                	# when user clicks on an entry update global variables
               		$hlist_selection = shift;
#                	my ($uid) = $hlist2->info("data", $hlist_selection);
#                	&main::pl("Selected uid: $uid\n");

               	},
		-command=> sub
		{
               		$hlist_selection = shift;
               		my ($uid) = $hlist2->info("data", $hlist_selection);
               		&main::pl("Selected uid: $uid\n");
#                	print Dumper($HL7::mhash{$uid}{hl7_hash});
		}

	)
	->pack
	(
        	-side=>'bottom',
		-expand=>1,
		-fill=>'both'
	);
	my $i = 0;
	$hlist2->header('create', $i++, -text =>' ');			# icon
	$hlist2->header('create', $i++, -text =>'First Line');
	$hlist2->header('create', $i++, -text =>'Flags');
	$hlist2->header('create', $i++, -text =>'Type');
	$hlist2->header('create', $i++, -text =>'Log Line');
	$hlist2->header('create', $i++, -text =>'UID');
	$hlist2->header('create', $i++, -text =>'Length');
	$hlist2->header('create', $i++, -text =>'line number(s)');

 	&make_rc_menu;

}

sub hlist_print
{
	my @print_arr = @_;

	$hlist2->add
	(
		$hl_counter,
		-data=>[$print_arr[4]]
	);

	$hlist2->itemCreate
	(
		$hl_counter,
		0,
		-itemtype=>'imagetext',
		-image=>$main::folderimage
	);

	my $index = 0;
	for(@print_arr)
	{
		$index++;
		$hlist2->itemCreate($hl_counter, $index, -text => $_);
	}

	$hl_counter++;
}


1;

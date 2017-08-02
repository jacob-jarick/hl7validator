#!/usr/bin/perl -w
package HL7tree;
require Exporter;
@ISA = qw(Exporter);

use strict;
use warnings;
use Tk;
use Tk::Tree;
use Data::Dumper::Concise;
use Tk::Toplevel;

my %tree_added	= ();
my %info_hash	= ();

my $info;
my $tree;

sub display
{
	%tree_added = ();
	my $uid		= shift;
	my $main = $main::mw -> Toplevel(-title => "HL7 Tree View" );

	$main->protocol('WM_DELETE_WINDOW',
	sub
	{
		$main->destroy;
		return;
	});

	my $frame_top = $main->Frame
	(
		-height => 10,
	)->pack
	(
		-side => "top",
		-expand=> 1,
		-fill => "both",
		-anchor => 'n'
	);
	my $frame_bottom = $main->Frame
	(
		-height => 10,
	)->pack
	(
		-side => "bottom",
		-expand=> 0,
		-fill => "x",
		-anchor => 's'
	);

	# HL7 raw message txt box
	my $msg_txt = $frame_bottom->Scrolled
	(
		'Text',
		-font		=> $main::font,
		-scrollbars	=> 'se',
		-background	=> 'black',
		-foreground	=> 'white',
		-wrap		=> 'none',
		-height		=> 10,
	# 	-insertmode	=> "insert",
		-wrap		=> 'char',
	)->pack
	(
		-side => "bottom",
		-expand=> 1,
		-fill => "x",
	#  	-anchor => 's'
	);
	&fill_text($msg_txt, $HL7::mhash{$uid}{value}, 0, 0);

	print "MSG:\n$HL7::mhash{$uid}{value}\n";

	# log box
	$info = $frame_bottom->Scrolled
	(
		'Text',
		-font       => $main::font,
		-scrollbars => 'se',
		-background => 'black',
		-foreground => 'white',
		-wrap => 'none',
		-height => 10,
	)->pack
	(
		-side => "bottom",
		-expand=> 1,
		-fill => "x",
	);

	$info->Contents($HL7::mhash{$uid}{error_txt});

	$tree = $frame_top->ScrlTree(
	-font       => $main::font,
	-itemtype   => 'text',
	-separator  => '/',
	-scrollbars => "se",
	-selectmode => 'single',
	-browsecmd => sub
	{
		my $path = shift;
# 		print Dumper(\%info_hash);
# 		my  = &path2name($hlist_selection);

 		my @t = split(/\//, $path);
 		my $name = HL7::get_name(@t);
 		print "Selected path $path, name $name\n";
		if($name eq 'MSH')
		{
			$info->Contents($HL7::mhash{$uid}{error_txt});
		}
		else
		{
			$info->Contents($info_hash{$name});
		}

		print Dumper($HL7::mhash{$uid}{hl7_hash}{$name});

 		&fill_text
 		(
			$msg_txt,
			$HL7::mhash{$uid}{value},
			$HL7::mhash{$uid}{hl7_hash}{$name}{start},
			$HL7::mhash{$uid}{hl7_hash}{$name}{stop}
		);
	}
	);

	$tree->pack( -fill => 'both', -expand => 1 );
	build_tree_v3($HL7::mhash{$uid}{hl7_hash});
}


sub path2name
{
	my $n = shift;

# 	$n =~ s/\//_/;
	$n =~ s/\//./g;

	return $n;
}

sub build_tree_v3
{
	my $ref = shift;
	my %h = %$ref;

	my $name = '';
	my $index = 0;

	my $tmp_text = '';
	my $path = '';

	foreach my $k (keys %h )
	{
		if(! defined $h{$k}{position})
		{
# 			print Dumper ($h{$k});
			$h{$k}{position} = 0;
		}
	}

	foreach my $k ( sort {$h{$a}{position} <=> $h{$b}{position}} keys %h )
	{
		$path = $k;
		$path =~ s/(_|\.)/\//g;
		$info_hash{$k} = $h{$k}{info_txt};

		add_to_tree_v2($path, $k, $h{$k}{value});
	}
}

sub add_to_tree_v2
{
	my $loc = shift;
	my $name = shift;
	my $val = shift;

	return if defined $tree_added{$loc};

# 	print "Adding '$loc' to tree\n";

	return if(!defined $val || $val eq '');

	$tree->add
	(
		$loc,
		-text => "$name = $val",
		-state => 'normal',
# 		-data=>[$name]
	);
}

sub fill_text
{
	my $txtobj = shift;
	my $txt_str = shift;
	my $start = shift;
	my $end = shift;

	# this is a little hack to fix selection offset
# 	$start--;
	$end--;

	if($start <=2)
	{
		$start = 0;
		$end = 2;
	}

# 	print "fill_text: Start '$start', Stop '$end'\n";

	$txtobj->Contents([]);

	my @arr = split(//, $txt_str);
	for my $i(0 .. $#arr)
	{
# 		$arr[$i] =~ s/\015/\n/g;
		if($i >= $start && $i <= $end)
		{
# 			print "_";
 			$txtobj->insert ('end', $arr[$i], 'highlight');
# 			$txtobj->insert ('end', '_');
		}
		else
		{
# 			print "$arr[$i]";
 			$txtobj->insert ('end', $arr[$i], 'normal');
		}
	}
	$txtobj->tag('configure', 'highlight', -background=>'lightblue');
 	$txtobj->tag('configure', 'normal');
}


1;
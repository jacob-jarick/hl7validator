#!/usr/bin/perl -w
package hl7_tree;
require Exporter;
@ISA = qw(Exporter);

use strict;
use warnings;
use Tk;
use Tk::Tree;

sub display
{
	my $uid = shift;
	my $ref = shift;
	my %h = %$ref;

	my $main = MainWindow->new(-title => "Demo" );
	my $tree = $main->ScrlTree(
	-font       => 'FixedSys 8',
	-itemtype   => 'text',
	-separator  => '/',
	-scrollbars => "se",
	-selectmode => 'single',
	);

	$tree->pack( -fill => 'both', -expand => 1 );

	$tree->add ('root', -text => 'root of all ...', -state => 'normal' );
	$tree->add ('root/top 1', -text => 'first top level node', -state => 'normal' );
	$tree->add ('root/top 2', -text => 'second top level node', -state => 'normal' );
	$tree->add ('root/top 2/nested 1', -text => 'first nested node', -state => 'normal' );
	$tree->add ('root/top 2/nested 2', -text => 'second nested node', -state => 'normal' );

	$tree->add ("$uid", -text => "$uid", -state => 'normal' );
	foreach  my $k (keys %h)
	{

		$tree->add ("$uid/$k", -text => "$h{$k}", -state => 'normal' );
	}


	openTree ($tree);

}

# MainLoop;

sub openTree {
    my $tree = shift;
    my ( $entryPath, $openChildren ) = @_;
    my @children = $tree->info( children => $entryPath );

    return if !@children;

    for (@children) {
        openTree( $tree, $_, 1 );
        $tree->show( 'entry' => $_ ) if $openChildren;
    }
    $tree->setmode( $entryPath, 'close' ) if length $entryPath;
}

sub closeTree {
    my $tree = shift;
    my ( $entryPath, $hideChildren ) = @_;
    my @children = $tree->info( children => $entryPath );

    return if !@children;

    for (@children) {
        closeTree( $tree, $_, 1 );
        $tree->hide( 'entry' => $_ ) if $hideChildren;
    }
    $tree->setmode( $entryPath, 'open' ) if length $entryPath;
}


1;
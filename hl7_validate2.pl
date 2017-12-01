f#!/usr/bin/perl
use strict;
use warnings;

use FindBin qw($Bin);
use Data::Dumper::Concise;
use Tk;
use Tk::FontDialog;
use Tk::DynaTabFrame;
use Tk::Text::SuperText;
use Tk::ProgressBar;
use Tk::Balloon;

use Tie::Tk::Text;

use Config::IniHash;
use Config::INI::Simple;


use lib		"$Bin/libs/";

use list;
use HL7;
use HL7view;
use HL7tree;
use rules;
# exit;

our $version = "0.008";

our $validate_all = 0;

our $percent_done = 0;
my $CONSOLE_OUT = 0;
my $tk_update_every = 10;
my $tk_update_count = 0;

our $font = '';

our $ini_file = "$Bin/configfile.ini";
# my $ini = Config::INI::Simple->new("test.ini");
# print $ini->{_}->{test}, "\n";

our $ini = ReadINI $ini_file;
if($ini->{appearance}{'font1'} ne '')
{
	$font = '{Courier New} -21';
}

my @output = ();
my @txt_box_contents = ();

our $dt_file = "$Bin/data/datatypes.txt";
our $filter = 0;
our $filter_txt = '';

my $help_txt = "TODO";

&HL7::load_dt_hash;

# ============================================================================
# begin gui shit

my $ww_status = 0;

our $mw = MainWindow->new;
our $balloon = $mw->Balloon();
$mw->geometry("800x600");
$mw->title("nc.log viewer and HL7 Validator Version: $version");

my $mbar = $mw -> Menu();

my $frame_top = $mw->Frame
(
	-height => 100,
)->pack
(
 	-side => "top",
	-expand=> 1,
	-fill => "both",
 	-anchor => 'n'

);

my $frame_bottom = $mw->Frame
(
	-height => 1,
)->pack
(
 	-side => "bottom",
	-expand=> 0,
	-fill => "x",
  	-anchor => 's'
);
my $progress = $frame_bottom->ProgressBar
(
        -width => 20,
        -from => 0,
        -to => 100,
        -blocks => 50,
        -colors => [0, 'green', 50, 'yellow' , 80, 'red'],
        -variable => \$percent_done
)->pack
(
 	-side => "bottom",
	-expand=> 1,
	-fill => "x",
#  	-anchor => 's'
);
# log box
my $log = $frame_bottom->Scrolled
(
	'Text',
	-scrollbars => 'se',
	-background => 'black',
	-foreground => 'white',
	-wrap => 'none',
	-height => 8,
# 	-insertmode => "insert",
)->pack
(
 	-side => "bottom",
	-expand=> 1,
	-fill => "x",
#  	-anchor => 's'
);


my $TabbedFrame = $frame_top->DynaTabFrame()->pack
(
	-side => 'top',
	-expand => 1,
	-fill => 'both'
);
my $tab2 = $TabbedFrame->add
(
	-caption => 'HL7 Messages',
	-tabcolor => 'cyan',
	-hidden => 0
);

list::draw_hlist($tab2);

my $tab1 = $TabbedFrame->add
(
	-caption => 'Log View',
	-tabcolor => 'yellow',
	-hidden => 0
);

my $tab1_button_frame = $tab1->Frame
->pack
(
 	-side => "top",
	-expand=> 0,
	-fill => "x",
# 	-anchor => 'w'
);
$tab1_button_frame->Button
(
	-text    => 'Exit',
	-command => sub
	{
		Tk::exit 0;
	}
)->pack
(
 	-side => "left",
	-expand=> 1,
	-fill => "x",
# 	-anchor => 'w'
);

$tab1_button_frame->Button
(
	-text    => 'Open Logfile',
	-command => sub
	{
		&open_log_file;
		&process();
	}
)->pack
(
 	-side => "left",
	-expand=> 1,
	-fill => "x",
# 	-anchor => 'w'
);

$tab1_button_frame->Button
(
	-text    => 'Process',
	-command => sub
	{
		&process();
	}
)->pack
(
 	-side => "left",
	-expand=> 1,
	-fill => "x",
# 	-anchor => 'w'
);


$tab1_button_frame->Button
(
	-text    => 'Clear',
	-command => sub
	{
		&pl("Cleared info\n");
		@txt_box_contents = ();
		$filter_txt = '';
# 		list::update_mlist(\%HL7::list_hash);
	}
)->pack
(
 	-side => "left",
	-expand=> 1,
	-fill => "x",
# 	-anchor => 'w'
);

my $checkbox_1 = $tab1_button_frame->Checkbutton
(
	-text => 'Validation Warnings',
	-onvalue => 1,
	-offvalue => 0,
	-variable => \$validate_all,
	-command => sub
	{
		print "Validation Warnings: $validate_all\n";
	}
)->pack
(
 	-side => "left",
# 	-expand=> 1,
	-fill => "x",
);

$tab1_button_frame->Checkbutton
(
	-text => 'Filter',
	-onvalue => 1,
	-offvalue => 0,
	-variable => \$filter,
	-command => sub
	{
		print "Filter: $filter - $filter_txt\n";
	}
)->pack
(
 	-side => "left",
# 	-expand=> 1,
	-fill => "x",
);

my $in = $tab1_button_frame->Entry
(
	-textvariable=>\$filter_txt,
)->pack
(
 	-side => "left",
# 	-expand=> 1,
	-fill => "x",
);


# my $txt = $mw->Text
my $txt = $tab1->Scrolled
(
	'SuperText',
	-scrollbars => 'se',
	-background => 'black',
	-foreground => 'white',
	-wrap => 'none',
	-spacing1 => 5,
)->pack
(
 	-side => "bottom",
	-expand=> 1,
	-fill => "both",

);

tie @txt_box_contents, 'Tie::Tk::Text', $txt;

# menu bar

$mw -> configure(-menu => $mbar);

#The Main Buttons
my $file = $mbar -> cascade(-label=>"File", -underline=>0, -tearoff => 0);
my $viewm = $mbar -> cascade(-label=>"View", -underline=>0, -tearoff => 0);
my $help = $mbar -> cascade(-label =>"Help", -underline=>0, -tearoff => 0);

## File Menu ##
$file->command
(
	-label =>"Open",
	-underline => 0,
	-command => sub
	{
		&open_log_file;
	}
);

sub process
{
		HL7::process_log(\@txt_box_contents);
		list::update_hlist(\%HL7::mhash);
}

sub open_log_file
{
	my $file = $mw->getOpenFile( );
	open(FILE, $file) or warn "WARNING couldnt open file '$file', $!\n";
	my @tmp = <FILE>;
	$txt->Contents(@tmp);
	close(FILE);
	&pl("Opened $file\n");
}

$file->separator();
$file->command
(
	-label =>"Exit",
	-underline => 1,
	-command => sub { Tk::exit 0; }
);

## View Menu

$viewm->command
(
	-label =>"Change Font",
	-command => sub
	{
		my $old_font = $font;
		$font = $mw->FontDialog(-initfont => $font)->Show;
		if (defined $font)
		{
			$font = $mw->GetDescriptiveFontName($font);
		}
		else
		{
			$font = $old_font;
		}
		$ini->{appearance}->{'font1'} = $font;
		&pl("Setting font to '$font'\n");
		$txt->configure(-font => $font);
		$log->configure(-font => $font);
		$list::hlist2->configure(-font => $font);
		WriteINI($ini_file, $ini);
	}
);
$viewm->command
(
	-label =>"Word Wrap Toggle",
	-command => sub
	{

		&set_word_wrap($ww_status);
		$ini->{appearance}->{'word wrap'} = $ww_status;
		WriteINI($ini_file, $ini);
	}
);
sub set_word_wrap
{
	my $w = shift;

	if($w)
	{
		$ww_status = 0;
		$txt->configure(-wrap=>"none");
		$log->configure(-wrap=>"none");
	}
	else
	{
		$ww_status = 1;
		$txt->configure(-wrap=>"char");
		$log->configure(-wrap=>"char");
	}
}

## Help ##
$help->command
(
	-label =>"About",
	-command => sub
	{
		&pl("TODO: Help txt\n");
	}
);

if($ini->{appearance}{'font1'} ne '')
{
	$font = $ini->{appearance}->{font1};
	$txt->configure(-font => $font);
	$log->configure(-font => $font);
	$list::hlist2->configure(-font => $font);
	&pl("Setting font to $font\n");
}

if($ini->{appearance}{'word wrap'} ne '')
{
	my $ww_status = $ini->{appearance}->{'word wrap'};
	&set_word_wrap($ww_status);
	&pl("Setting word wrap to $ww_status\n");
}

MainLoop;

sub menuClicked
{
	my ($opt) = @_;
	$mw->messageBox(-message=>"You have clicked $opt. This function is not implanted yet.");
}

sub pl
{
	my @out = shift;
	push @output, @out;
	print @out if $CONSOLE_OUT;
	if(scalar @output > 200)
	{
		@output = @output[scalar @output - 50 .. scalar @output];
	}
	$log->Contents(@output);
	$log->GotoLineNumber(scalar @output);

	$tk_update_count++;
 	return if($tk_update_count < $tk_update_every);
 	$tk_update_count = 0;
	$mw->update;
}

exit;


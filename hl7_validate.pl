#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use Data::Dumper::Concise;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use JSON::XS;
use FindBin qw($Bin);

$|++;

my $seg_index		= 0;
my $field_index		= 0;
my $comp_index		= 0;


my $JSON		= 0;
my $ERRORS		= 0;
my %hash		= ();
# my $dict		= "$Bin/dict/all.txt";
my $segments_file	= "$Bin/json/segments.json";
my $fields_file		= "$Bin/json/fields.json";

my $segment_name	= '';
my $spacing1		= 10;
my $spacing2		= 20;
my $pid  		= undef;
my $visitid  		= undef;
my $type		= undef;
my $msg_type		= '';
my $uid_lookup		= undef;
my $text		= '';
my %md5_hash		= ();

my $type_lookup		= undef;

my $ALL			= 0;
my $VID_MATCH		= 0;
my $PID_MATCH		= 0;
my $TYPE_MATCH		= 0;
my $RAW			= 0;
my $PAUSE		= 0;
my $UID_SUM		= 0;

my $errors		= '';

my $current_line	= '';

my $help_txt =
"
HL7 Validator version: 0.01b

formats the awful hl7 pipe seperated format into human readable and or json.

useage: cat file | hl7view.pl

notes:
default behaviour is to show messages with warnings and errors.

options:

	--help		this text
	--errors	only show errors (on show messags with errors, ignore warnings)
	--json		turn on json output (turns off human readable)
	--pid=PID	filter by patient ID
	--visitid=ID	filter by patient visitorid by ID
	--type=TYPE	only display messages containing TYPE (eg A03)
	--uid=UID	display HL7 message with specific UID
	--raw		display raw HL7 message
	--all		display all hl7 messages (valid and invalid messages shown)
	--uid-sum	Display a summary of all messages found via UID
	--pause		pause on errors
";

for(@ARGV)
{
	if ($_ eq '--help')
	{
		print "$help_txt\n";
		exit;
	}
	elsif($_ eq '--json')
	{
		$JSON = 1;
	}
	elsif($_ eq '--errors')
	{
		$ERRORS = 1;
	}
	elsif($_ eq '--raw')
	{
		$RAW = 1;
	}
	elsif($_ eq '--pause')
	{
		$PAUSE = 1;
	}
	elsif($_ eq '--all')
	{
		$ALL = 1;
	}
	elsif($_ =~ /--pid=(\d+)/)
	{
		$pid = $1;
	}
	# visitid
	elsif($_ =~ /--visitid=(\S+)/)
	{
		$visitid = $1;
	}
	elsif($_ =~ /--type=(\S+)/)
	{
		$type_lookup = $1;
	}
	elsif($_ =~ /--uid=(\S+)/)
	{
		$uid_lookup = $1;
	}
	elsif($_ =~ /--uid-sum/)
	{
		$UID_SUM = 1;
	}
	else
	{
		die "unrecognized command line argument '$_'\n";
	}
}

my %dict_hash = ();


for my $f(($segments_file, $fields_file))
{
	my $json = '';
	open(FILE, $f) or die "ERROR: couldnt open JSON file '$f' for parsing. $!\n";
	while(<FILE>)
	{
		$json .= $_;
	}
	close(FILE);

	my $ref		= decode_json($json);
	my %hash	= %$ref;
	%dict_hash	= (%dict_hash, %hash);
}


# print Dumper(\%dict_hash);
# exit;

my $line_number = 0;
while(<STDIN>)
{
	$line_number++;
	next if $_ !~ /^MSH/;

	my $md5 =  md5_hex($_);

	$md5_hash{$md5}++;

	my $uid = $md5."_".$md5_hash{$md5};

	#s/\015/\&/g;

	$PID_MATCH	= 0;
	$TYPE_MATCH	= 0;
	$VID_MATCH	= 0;
	$msg_type	= '';

	my $raw_msg	= $_;
	$current_line	=	$raw_msg	=~ s/\015/\n/g;

	$errors		= '';

	$text		= "--------------------------------------------------------------------------------------\n";
	$text		.= "RAW HL7 MESSAGE:\n$raw_msg\n" if($RAW);
	$text		.= pad("UID", $spacing1) . "= $uid\n";

	if($UID_SUM)
	{
		print_uid_summary($line_number, $uid);
		next;
	}

	my @stmp = split(/\015|\\n/);

	$seg_index = 0;
	my $seg_index_old = -1;

	%hash = ();	# reset hash

	$segment_name = '';
	for my $seg(@stmp)
	{
		my @tmp = split(/\|/, $seg);

		if($tmp[0] eq 'MSH')
		{
			my @tmp2 = shift @tmp;
			push @tmp2, '|';
			push @tmp2, @tmp;

			@tmp = @tmp2;
		}

		$field_index = 0;
		for my $field(@tmp)
		{
			$field =~ s/\n$//;
			if($seg_index != $seg_index_old)
			{
				$seg_index_old = $seg_index;
				$segment_name = $field;
			}
			# COMPONENT_SEPARATOR
			if(!($seg_index == 0 && $field_index == 2) && $field =~ /\^/)
			{
				my @comps = split(/\^/, $field);

				$comp_index = 0;

				for my $comp(@comps)
				{
					my $key = $segment_name . '.' . $field_index.".".$comp_index;
					print_info($key, $comp);
					$comp_index++;
				}
			}
			else
			{
				my $key = $segment_name . '.' . $field_index;
				print_info($key, $field);
			}
			$field_index++;
		}
		$seg_index++;
	}

	next if(defined $uid_lookup && $uid ne $uid_lookup);

	if(lc $msg_type eq lc 'ADT_A03' && (! defined $hash{'PV1.45'} || $hash{'PV1.45'} !~ /^\d{14}$/))
	{
		$errors .= "Invalid discharge date for ADT_A03 message type\n";
	}

	if
	(
		(lc $msg_type eq lc 'ADT_A01' && lc $msg_type eq lc 'ADT_A02') &&
		(defined $hash{'PV1.45'})
	)
	{
		$errors .= "ADT_A01 & ADT_A02 should not have PV1.45 defined\n";
	}

	my $print_info = 1;

	if($ERRORS && $errors eq '')
	{
		$print_info = 0;
	}

	if(defined $pid && !$PID_MATCH)
	{
		$print_info = 0;
	}

	if(defined $visitid && !$VID_MATCH)
	{
		$print_info = 0;
	}


	if(defined $type_lookup && !$TYPE_MATCH)
	{
		$print_info = 0;
	}

	if($ALL)
	{
		$print_info = 1;
	}

	if
	($print_info)
	{
		print "\n$text";

		if($errors ne '')
		{
			print "\nERRORS FOUND !!!!!!\n$errors\n";

			sleep 2 if $PAUSE;
		}
	}
	else
	{
		print ".";
	}

	if($JSON)
	{
		my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
		$coder->canonical([1]);
		my $pretty = $coder->encode (\%hash);

		$pretty =~ s/"\\"\\""/null/g;

		while(1)
		{
			if($pretty =~ /(.*)(\[\n+.*?\])(.*)/s)
			{
				my $a = $1;
				my $b = $2;
				my $c = $3;

				$b =~ s/\n/ /g;
				$b =~ s/\s+/ /g;

				$pretty = $a.$b.$c;
			}
			else
			{
				last;
			}
		}

		print $pretty;
	}
}
print "\n\n";
exit;

# REPETITION_SEPARATOR

sub print_info
{
	my $key		= shift;
	my $field	= shift;

	return if ! defined $key  || $key eq '';

	$key =~ s/\.0$//;

	my $key_desc	= get_desc($key);
	my $dtype	= get_field($key, 'datatype');

	my $length = get_field($key, 'len');


	return if $field eq '';

	if(lc $key eq lc 'MSH.9')
	{
		$msg_type = $field;
	}
	if(lc $key eq lc 'MSH.9.1')
	{
		$msg_type .= "_$field";
	}

	$text .=  pad("$key", $spacing1) . "= ". pad(to_array($key, $field), $spacing2) . pad($dtype, 10) . pad($length, 10) .  $key_desc . "\n" if !$JSON;

	if($length =~ /\d+/ && length $field > $length)
	{
		$errors .=  "WARNING: field value '$field' exceeds max length $length for field $key\n" if !$ERRORS;
	}

	# validate date
	if(lc $dtype eq 'dt')
	{
		if(length $field != 12)
		{
			$errors .=  "ERROR: name $key, datatype $dtype with field value '$field' is not a valid date\n";
		}
	}

	if(defined $pid && lc $key eq 'pid.2' && $field eq $pid)
	{
		$PID_MATCH = 1;
	}

	if(defined $visitid && lc $key eq lc 'PV1.19' && $field eq $visitid)
	{
		$VID_MATCH = 1;
	}

	if(defined $type_lookup && lc $field eq lc $type_lookup)
	{
		$TYPE_MATCH = 1;
	}

	add_to_hash($key, $field);
}

sub to_array
{
	my $key = shift;
	my $string = shift;

	return $string if ($seg_index == 0 && $field_index == 2) || $string !~ /\~/;

	my @tmp = split(/\~/, $string);

	my $arr_txt = 'Array [ ';

	for(@tmp)
	{
		$arr_txt .= "$_ , ";
	}
	$arr_txt =~ s/,\s+$//;
	$arr_txt .= "]";

	return $arr_txt;
}

sub add_to_hash
{
	my $k = shift;
	my $value = shift;

	$value =~ s/\n+$//;
	return if $value eq '';

	if(!($seg_index == 0 && $field_index == 1) && $value =~ /\~/)
	{
		my @tmp = split(/\~/, $value);
		@{$hash{$k}} = @tmp;
		return;
	}
	if($value eq '""')
	{
		$hash{$k} = undef;
		return;
	}

	$hash{$k} = $value;
}


sub pad
{
	my $string = shift;
	my $size = shift;

	my $l = length $string;

	return $string if $l > $size;

	my $diff = $size - $l;

	for(my $i = 0; $i <= $diff; $i++)
	{
		$string .= ' ';
	}

	return $string;
}

sub get_field
{
	my $name = shift;
	my $fname = shift;
	my $ref = get_json_hash($name);
	my %h = %$ref;

	return '' if(! defined $h{$fname});

	return $h{$fname};
}

sub get_desc
{
	my $name = shift;
	my $ref = get_json_hash($name);
	my %h = %$ref;

	if(! defined $h{'desc'})
	{
# 		print Dumper(\%h);
# 		warn "didnt get desc for \'$name\'. HL7 msg:\n$current_line\n\n";
		return '';
	}
	return $h{'desc'};
}

sub get_json_hash
{
	my $name = shift;
# 	print "name = $name\n";
	my %htmp = ();
	return \%htmp if $name eq '';
	my $tmp_name = $name;
	$tmp_name =~ s/\..*$//;

	if(! defined $dict_hash{$tmp_name})
	{
		die "\'$name\' - \'$tmp_name\' not found in json\n";
	}

	if($name !~ /\.\d+/)
	{
		%htmp = %{$dict_hash{$name}};
		return \%htmp;
	}

	if($name =~ /\.(\d+)\.(\d+)$/ || $name =~ /\.(\d+)$/)
	{
		my $index = $1 - 1;
		if(defined $dict_hash{$tmp_name}{subfields})
		{
			%htmp = %{@{$dict_hash{$tmp_name}{subfields}}[$index]};
			return \%htmp;
		}
		elsif(defined $dict_hash{$tmp_name}{fields})
		{
			%htmp = %{@{$dict_hash{$tmp_name}{fields}}[$index]};
			return \%htmp;
		}

		die "failed to lookup.\n";
	}
}

sub print_uid_summary
{
	my $line_number = shift;
	my $uid = shift;

	print "Line Number: $line_number, UID: $uid\n";
}

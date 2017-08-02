#!/usr/bin/perl -w
package HL7;
require Exporter;
@ISA = qw(Exporter);

use strict;
use warnings;

use FindBin qw($Bin);
use Data::Dumper::Concise;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use JSON::XS;

my $segments_file	= "$Bin/json/segments.json";
my $fields_file		= "$Bin/json/fields.json";

my $seg_index		= 0;
my $field_index		= 0;

my $JSON		= 0;
my $ERRORS		= 0;
my %hash		= ();

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
my $UID_SUM		= 0;

my $errors		= '';

my %dict_hash = ();

our %dt_hash = ();

our %mhash = ();

our %pos_hash = ();

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


sub process_log
{
	my $txt_ref = shift;
	my @txt_arr = @$txt_ref;

	my $line_number = 0;
	my $total_lines = scalar @txt_arr;

	$main::percent_done = 0;

	my $filter_quoted = '';

	if($main::filter && $main::filter_txt ne '')
	{
		$filter_quoted = quotemeta $main::filter_txt;
	}


	%mhash = ();

	for my $line_txt (@txt_arr)
	{
		$line_number++;
		$main::percent_done = int(($line_number/$total_lines) * 100);

		if($filter_quoted ne '' && $line_txt !~ /$filter_quoted/)
		{
			next;
		}

		next if $line_txt !~ /^MSH(.{1})/;

 		$line_txt =~ s/\n+$//;

		my $seperator = $1;

		my $position	= 0;
		my $md5		=  md5_hex($line_txt);

		$md5_hash{$md5}++;

		$mhash{$md5}{line_number} = $line_number;
		$mhash{$md5}{value} = $line_txt;

		my $uid = $md5."_".$md5_hash{$md5};

		$msg_type	= '';
		$errors		= '';

		%hash		= ();	# reset hash
		%pos_hash	= ();

		my $tmp		= $line_txt;
		$tmp		=~ s/\015/\n/g;

		$text		= "--------------------------------------------------------------------------------------\n";
		$text		.= "RAW HL7 MESSAGE:\n$tmp\n" if($RAW);
		$text		.= pad("UID", $spacing1) . "= $uid\n";

		my $msg_pos_start = 0;
		my @segs_arr = split(/\015|\\n/, $line_txt);

		################################
		# SEGEMENTS
		################################
		for my $seg_index(0 .. scalar(@segs_arr) -1 )
		{
			my $seg = $segs_arr[$seg_index];
			my @tmp = split(/\|/, $seg);
			my $segment_name = $tmp[0];

			my $n = $segment_name;

			$pos_hash{$md5}{$n}{start} = $msg_pos_start;
			$pos_hash{$md5}{$n}{stop} = $msg_pos_start + length $segs_arr[$seg_index];

			$mhash{$md5}{segments}{$seg_index}{value} = $segs_arr[$seg_index];

			if($seg_index == 0)	# add seperator field to MSH segment
			{
				splice @tmp, 1, 0, $seperator;
			}

			######################
			# FIELDS
			######################
			for $field_index (0 .. scalar(@tmp) - 1)
			{
				next if ! defined $tmp[$field_index];

				$mhash{$md5}{segments}{$seg_index}{fields}{$field_index}{value} = $tmp[$field_index];

				$n = &get_name($segment_name, $field_index);
				$pos_hash{$md5}{$n}{start} = $msg_pos_start;
				$pos_hash{$md5}{$n}{stop} = $msg_pos_start + length $tmp[$field_index];

				my $field = $tmp[$field_index];
				$field =~ s/\n$//;

				# check for components in field

				if(!($seg_index == 0 && $field_index == 2) && $field =~ /\^/)
				{
					##############################
					# COMPONENTS
					##############################

					my @comps = split(/\^/, $field);

					for my $index3(0 .. scalar(@comps) - 1)
					{
						my $comp = $comps[$index3];

						$mhash{$md5}{segments}{$seg_index}{fields}{$field_index}{components}{$index3}{value} = $comp;

						$n = &get_name($segment_name, $field_index, $index3);

						$pos_hash{$md5}{$n}{start} = $msg_pos_start;
						$pos_hash{$md5}{$n}{stop} = $msg_pos_start + length $comp;

						$msg_pos_start += (length $comp);

						$msg_pos_start++ if $index3 != $#comps; # add 1 for ^ seperator
					}
				}
				else
				{
					$n = &get_name($segment_name, $field_index);

					$pos_hash{$md5}{$n}{start} = $msg_pos_start;
					$pos_hash{$md5}{$n}{stop} = $msg_pos_start + length $field;
					$msg_pos_start += (length $field) if(lc $n ne 'msh_1');
				}
				$msg_pos_start++ if $field_index != $#tmp;	# add 1 for | seperator
			}
			$msg_pos_start++ if $seg_index != $#segs_arr;	# add 1 for \015 CR
		}


 		$msg_type = $mhash{$md5}{segments}{0}{fields}{9}{value};
 		$msg_type =~ s/\^/_/;

#------------------------------------------------------------------------------------------------------------

		# make a HL7 hash
		my %hl7h = ();
		my $p = 0;
		foreach my $s (sort {$a <=> $b}  keys %{$mhash{$md5}{segments}})
		{
			my $s_name = $mhash{$md5}{segments}{$s}{fields}{0}{value};
			my $n = "$s_name";
			$hl7h{$n}{value} = $mhash{$md5}{segments}{$s}{value};
			$hl7h{$n}{start} = $pos_hash{$n}{start};
			$hl7h{$n}{position} = $p++;

			foreach my $f (sort {$a <=> $b} keys %{$mhash{$md5}{segments}{$s}{fields}})
			{
				my $n = &get_name($s_name, $f, undef);
				$hl7h{$n}{value} = $mhash{$md5}{segments}{$s}{fields}{$f}{value};
				$hl7h{$n}{start} = $pos_hash{$n}{start};
				$hl7h{$n}{position} = $p++;
# 				print "$n = $hl7h{$n}{value}\n" if defined $hl7h{$n}{value};

				if (defined $mhash{$md5}{segments}{$s}{fields}{$f}{components})
				{
					foreach my $c (sort {$a <=> $b}  keys %{$mhash{$md5}{segments}{$s}{fields}{$f}{components}})
					{
						$p++;
						my $n = &get_name($s_name, $f, $c);
						$hl7h{$n}{value} = $mhash{$md5}{segments}{$s}{fields}{$f}{components}{$c}{value};
						$hl7h{$n}{start} = $pos_hash{$n}{start};
						$hl7h{$n}{position} = $p++;
# 						print "$n = $hl7h{$n}{value}\n" if defined $hl7h{$n}{value};
					}
				}
			}
		}

		my $validated_all = 0;

		%hl7h = %{rules::hash_check	($md5, \%hl7h)};
		%hl7h = %{&add_positions	($md5, \%hl7h)};
		%hl7h = %{&add_info_to_fields	($md5, \%hl7h)};


		if($main::validate_all)
		{
			%hl7h = %{&validate_data	($md5, \%hl7h)};
			$validated_all = 1;
		}

		%{$mhash{$md5}{hl7_hash}} = %hl7h;



#------------------------------------------------------------------------------------------------------------
#
		my $PRINT = 0;

		$PRINT = 1 if(defined $mhash{$md5}{ERROR}	&& $mhash{$md5}{ERROR} > 0);
		$PRINT = 1 if(defined $mhash{$md5}{WARNING}	&& $mhash{$md5}{WARNING} > 0);

		if(!$PRINT)
		{
			delete $mhash{$md5};
			&main::pl( ".");
			next;
		}

		# attach all all warnings to message now that it will be displayed
		if(!$validated_all)
		{
			%hl7h = %{&validate_data	($md5, \%hl7h)};
		}

		&main::pl("\n$text");

		if (defined $mhash{$md5}{line_number})
		{
			$mhash{$md5}{line_numbers} .= ", $line_number";
			$mhash{$md5}{line_numbers} =~ s/^,\s*//;
		}
		else
		{
			$mhash{$md5}{line_number}	= $line_number;
			$mhash{$md5}{line_numbers}	= $line_number;
		}

		$mhash{$md5}{uid}	= $md5;
		$mhash{$md5}{length}	= length $line_txt;
		$mhash{$md5}{type}	= $msg_type;
		$mhash{$md5}{hl7_msg}	= $line_txt;


		$mhash{$md5}{warn_txt}	= $errors;
		$mhash{$md5}{pretty}	= "Pretty Text: \n\n" . $text;
		$mhash{$md5}{nc_log}	= $txt_arr[$line_number - 2];

		my %th = %{$mhash{$md5}{hl7_hash}};
		foreach my $k (sort {$a cmp $b} keys %th)
		{
			if (defined $th{$k}{error_txt} && $th{$k}{error_txt} ne '')
			{
				$mhash{$md5}{error_txt} .= $th{$k}{error_txt} . "\n";
			}
		}
		$mhash{$md5}{error_txt}	.= $errors;

		$mhash{$md5}{flags}	= 'PASS';
		$mhash{$md5}{flags}	= 'WARNING'	if defined $mhash{$md5}{WARNING}	&& $mhash{$md5}{WARNING} > 0;
		$mhash{$md5}{flags}	= 'ERROR' 	if defined $mhash{$md5}{ERROR}		&& $mhash{$md5}{ERROR} > 0;


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
			&main::pl($pretty);
		}
	}
}

sub add_positions
{
	my $md5 	= shift;
	my $ref		= shift;
	my %hl7h	= %$ref;

	foreach my $key (keys %hl7h)
	{
		if(! defined $hl7h{$key}{start})
		{
			if(defined $pos_hash{$md5}{$key}{start})
			{
				$hl7h{$key}{start} = $pos_hash{$md5}{$key}{start};
			}
			else
			{
				$hl7h{$key}{start} = 0;
			}
		}
		if(! defined $hl7h{$key}{stop})
		{
			if(defined $pos_hash{$md5}{$key}{stop})
			{
				$hl7h{$key}{stop} = $pos_hash{$md5}{$key}{stop};
			}
			else
			{
				$hl7h{$key}{stop} = 0;
			}
		}
	}
	return \%hl7h;
}

# used so hash keys are always the same
# returns hl7 section name
sub get_name
{
	my $seg = shift;
	my $field = shift;
	my $comp = shift;

	if(defined $seg && defined $field && defined $comp)
	{
		return "$seg\_$field.$comp";
	}
	if(defined $seg && defined $field)
	{
		return "$seg\_$field";
	}
	return $seg;

}

sub add_info_to_fields
{
	my $md5 = shift;
	my $ref	= shift;
	my %h	= %$ref;

	foreach my $key( sort {$a cmp $b} keys %h)
	{
		next if ! defined $h{$key}{value};

		my $nice_key = $key;
		$nice_key =~ s/_0$//;
		my $key_desc	= get_field($key, 'desc');
		my $dtype	= get_field($key, 'datatype');
		my $opt		= get_field($key, 'opt');
		my $rep		= get_field($key, 'rep');

		my $dtype_desc	= '';
		$dtype_desc	= $HL7::dt_hash{lc $dtype} if defined $HL7::dt_hash{lc $dtype};
		my $length	= get_field(uc $key, 'len');

my $info_txt =
"Key:		$nice_key - $key_desc
Value:		$h{$key}{value}\n";

$info_txt .=
"Data Type:	$dtype - $dtype_desc\n" if $dtype ne '';

$info_txt .=
"Value Length:	" . (length $h{$key}{value}) . "\n";

$info_txt .=
"Begin Position:	$h{$key}{start}\n";

$info_txt .=
"Max Length:	$length" if $length ne '';

		if
		(
			defined $opt &&
			$opt ne '' &&
			$key ne 'MSH_1' &&
			$key ne 'MSH_2'
			&& $key !~ /_\d+\./
		)
		{
$info_txt .= "
opt:		$opt
rep:		$rep
";
		}

		if(defined $h{$key}{error_txt})
		{
			print "Error Hash info:\n" .  Dumper($h{$key}{error_txt}) . "\n";
			$info_txt .= $h{$key}{error_txt};
		}
		else
		{
# 			print "no error text for $key.\n";
		}

		$h{$key}{info_txt} = $info_txt;
	}

	return \%h;
}

sub validate_data
{
	my $md5 = shift;
	my $ref	= shift;
	my %h	= %$ref;

	foreach my $key(keys %h)
	{
		next if ! defined $h{$key}{value};

		my $nice_key = $key;
		$nice_key =~ s/_0$//;
		my $key_desc	= get_field($key, 'desc');
		my $dtype	= get_field($key, 'datatype');
		my $opt		= get_field($key, 'opt');
		my $rep		= get_field($key, 'rep');

		my $dtype_desc	= '';
		$dtype_desc	= $HL7::dt_hash{lc $dtype} if defined $HL7::dt_hash{lc $dtype};
		my $length	= get_field(uc $key, 'len');

		# validate length
		if($length =~ /^\d+$/ && length $h{$key}{value} > $length)
		{
			my $l = length $h{$key}{value};
			my $s = "WARNING: '$key' value length $l > max $length. Value = '$h{$key}{value}'\n";
			$errors .=  $s if !$ERRORS;

			$h{$key}{info_txt} .= $s;

			$mhash{$md5}{WARNING}++;
		}

		# validate date
		if(lc $dtype eq 'dt' && $h{$key}{value} ne '')
		{
			if(length $h{$key}{value} != 12)
			{
				my $s = "ERROR: '$key' datatype $dtype length ne 12, not a valid date. Value = '$h{$key}{value}'\n";
				$errors .=  $s;
				$h{$key}{info_txt} .= $s;
				$mhash{$md5}{ERROR}++;
			}
		}
	}

	return \%h;
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

sub get_json_hash
{
	my $name = shift;
	my $ref = shift;

	$name =~ s/\.0$//;
#    	print "get_json_hash name = $name\n";
	my %htmp = ();
	return \%htmp if $name eq '';

	my $tmp_name = $name;
	$tmp_name =~ s/(\.|_).*$//;

	if($name !~ /(_|\.)\d+$/)
	{
		%htmp = %{$dict_hash{$name}};
		return \%htmp;
	}

	if(! defined $dict_hash{$tmp_name})
	{
		die "\'$name\' - \'$tmp_name\' not found in json\n";
	}

	if($name =~ /\_(\d+)\.(\d+)$/ || $name =~ /\_(\d+)$/)
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

	&main::pl("Line Number: $line_number, UID: $uid\n");
}


sub load_dt_hash
{
	open(FILE, $main::dt_file);
	my @tmp = <FILE>;
	close(FILE);

	for(@tmp)
	{
		if(/(\S+)\s+-\s+(.*)/)
		{
			$dt_hash{lc $1} = $2;
		}
	}
# 	print Dumper(\%dt_hash);
}

1;
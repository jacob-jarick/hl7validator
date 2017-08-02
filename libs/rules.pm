#!/usr/bin/perl -w

package rules;

require Exporter;
@ISA = qw(Exporter);

use strict;
use warnings;

use FindBin qw($Bin);
use Data::Dumper::Concise;

use Config::IniHash;

my %rule_hash = ();


my %defaults_hash = ();

# [ID]

$defaults_hash{id}{regex}		= '';		# not implemented yet
$defaults_hash{id}{msg_types}		= '';		# csv, is split into array
$defaults_hash{id}{sections}		= '';		# csv, is split into array

# [rule]

$defaults_hash{rule}{pass}		= 'all';	# how many sections to pass for rule to be valid

$defaults_hash{rule}{must_be_defined}	= 'false';
$defaults_hash{rule}{blank_allow}	= 'true';

$defaults_hash{rule}{length_min}	= undef;
$defaults_hash{rule}{length_max}	= undef;

$defaults_hash{rule}{flag}		= 'warn';	# options warn, error
$defaults_hash{rule}{numeric_only}	= 'false';


&load_rules;

# print Dumper(\%rule_hash);


sub hash_check
{
	my $md5 = shift;
	my $ref = shift;
	my %hash = %$ref;

	my $full_error_txt = '';

	my $msg_type;
	if(!defined $hash{'MSH_9'} || !defined $hash{'MSH_9'}{value})
	{
		print "error no message type\n";
		print Dumper (\%hash);
	}
	else
	{
		$msg_type = $hash{'MSH_9'}{value};
		$msg_type =~ s/\^/_/;
	}


	# sort through each rule alphanumerically
	foreach my $rk1(sort {$a cmp  $b} keys %rule_hash)
	{
# 		print "Checking rule $rk1\n";
		# confirm message matches 1 of the types listed in msg_types
		my $matched = 0;
		for my $r_msg_type(@{$rule_hash{$rk1}{id}{msg_types}})
		{
# 			print "$msg_type - $r_msg_type\n";
			if($r_msg_type eq $msg_type)
			{
				$matched = 1;
				last;
			}
		}
		next if !$matched;

		my $flag		= $rule_hash{$rk1}{rule}{flag};
		my $sections_count	= scalar @{$rule_hash{$rk1}{id}{sections}};
		my $fail_count		= 0;

		# check each ini defined section against current rule
		for my $s(@{$rule_hash{$rk1}{id}{sections}})
		{
# 			print "section: $s\n";

			# must_be_defined
			if
			(
				(!defined $hash{$s} || !defined $hash{$s}{value} ) &&
				$rule_hash{$rk1}{rule}{must_be_defined} eq 'true'
			)
			{
				$hash{$s}{error_txt} .= "$flag: $rk1: section $s is undefined\n";
				$fail_count++;
				next;	# next either way - because if not def and not required we still have nothing to check against
			}

			my $fail_inc = 0;

			# blank_allow
			if($hash{$s}{value} eq '')
			{
				if($rule_hash{$rk1}{rule}{blank_allow} eq 'false')
				{
					$hash{$s}{error_txt} .= "$flag: $rk1: section $s blank not allowed''\n";
					$fail_inc = 1;
				}
			}

			# length_min
			if
			(
				defined $rule_hash{$rk1}{rule}{length_min} &&
				$rule_hash{$rk1}{rule}{length_min} &&
				length $hash{$s}{value} < $rule_hash{$rk1}{rule}{length_min}
			)
			{
				$hash{$s}{error_txt} .=  "$flag: $rk1: section $s less than min length $rule_hash{$rk1}{rule}{length_min}\n";
				$fail_inc = 1;
			}

			# length_max
			if
			(
				defined $rule_hash{$rk1}{rule}{length_max} &&
				$rule_hash{$rk1}{rule}{length_max} &&
				length $hash{$s}{value} > $rule_hash{$rk1}{rule}{length_max}
			)
			{
				$hash{$s}{error_txt} .=  "$flag: $rk1: section $s greater than max length $rule_hash{$rk1}{rule}{length_min}\n";
				$fail_inc = 1;
			}

			# numeric_only
			if(lc $rule_hash{$rk1}{rule}{numeric_only} eq 'true' && $hash{$s}{value} !~ /^\d+$/)
			{
				$hash{$s}{error_txt} .=  "$flag: $rk1: section $s is not numeric_only\n";
				$fail_inc = 1;
			}

			$fail_count+=$fail_inc;
		}
		if($rule_hash{$rk1}{rule}{pass} eq 'all')
		{
			if($fail_count > 0)
			{
				$HL7::mhash{$md5}{$flag}++;
			}
		}
		else
		{
			my $pass_count = $sections_count - $fail_count;
			if($pass_count >= $rule_hash{$rk1}{rule}{pass})
			{
				# met minimum requirements, dont flag this message
			}
			else
			{
				$HL7::mhash{$md5}{$flag}++;
			}
		}
	}

	if (defined $HL7::mhash{$md5}{WARNING} && $HL7::mhash{$md5}{WARNING} > 0)
	{
		$HL7::mhash{$md5}{flag} = 'WARNING';
	}
	if (defined $hash{ERROR} && $hash{ERROR} > 0)
	{
		$HL7::mhash{$md5}{flag} = 'ERROR';
	}

	return \%hash;
}

sub load_rules
{
	%rule_hash = ();

	my $ini_dir = "$Bin/rules";
	opendir(my $dh, $ini_dir) || die "Can't opendir $ini_dir: $!";
	my @dir = readdir $dh;
	closedir $dh;

# 	print @dir;

	for my $file(@dir)
	{
		next if $file eq '.' || $file eq '..';

		next if $file !~ /\.ini$/i;

		my $ini = ReadINI "$Bin/rules/$file";

		my %used_rules = ();

		# ini file section headers
		foreach my $kd1 (keys %defaults_hash)
		{
			# ini file section options
			foreach my $kd2 (keys %{$defaults_hash{$kd1}})
			{
				my $tmp = $defaults_hash{$kd1}{$kd2};
				if (defined $ini->{$kd1}{$kd2} && $ini->{$kd1}{$kd2} ne '')
				{
					$tmp = $ini->{$kd1}{$kd2};
				}

								# split msg_types into array
				if($kd2 eq 'msg_types')
				{
					my @tmpa = split(/,/, $tmp);
					@tmpa = map { uc } @tmpa;	# message types are always upper case
					@{$rule_hash{$file}{$kd1}{$kd2}} = @tmpa;
				}

				# split message sections into array
				if($kd2 eq 'sections')
				{
					my @tmpa = split(/,/, $tmp);
					@tmpa = map { uc } @tmpa;	# message sections are always upper case
					@{$rule_hash{$file}{$kd1}{$kd2}} = @tmpa;
				}

				if($kd2 eq 'flag')
				{
					if(lc $tmp ne 'warning' && lc $tmp ne 'error' )
					{
						print "rule $file: flag must be either WARNING or ERROR, not '$tmp', setting flag to WARNING\n";
						$rule_hash{$file}{$kd1}{$kd2} = 'WARNING';
					}
					else
					{
						$rule_hash{$file}{$kd1}{$kd2} = uc $tmp;
					}
				}

				$rule_hash{$file}{$kd1}{$kd2} = $tmp if ! defined $rule_hash{$file}{$kd1}{$kd2};
				$used_rules{$kd1}{$kd2} = 1;
			}
		}

		# warn about ignored ini keys
		foreach my $kd1 (keys %$ini)
		{
			my %h = %{$ini->{$kd1}};
			foreach my $kd2 (keys %h)
			{
				if (! defined $used_rules{$kd1}{$kd2})
				{
					print "WARNING: $file: section $kd1, key $kd2: $h{$kd2} not used.\n";
				}
			}
		}
	}
}


1;
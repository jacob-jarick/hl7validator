use strict;
print "1: to STDOUT.\n";
my $output = '';
open TOOUTPUT, '>', \$output or die "Can't open TOOUTPUT: $!";
print "2: to STDOUT.\n";
print TOOUTPUT "3: to TOOUTPUT.\n";
select TOOUTPUT;
print "4: To STDOUT, (really TOOUTPUT though).\n";
select STDOUT;
print "5: To STDOUT again\n";
print TOOUTPUT "6: To TOOUTPUT.\n";
print "----\n".$output."-----\n";
print "Now we're done.\n";
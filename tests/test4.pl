use Tk;
use Tk::ProgressBar;

my $mw = MainWindow->new(-title => 'ProgressBar example');

my $progress = $mw->ProgressBar
(
        -width => 20,
        -from => 0,
        -to => 100,
        -blocks => 50,
        -colors => [0, 'green', 50, 'yellow' , 80, 'red'],
        -variable => \$percent_done
    )->pack(-fill => 'x');

$mw->Button(-text => 'Go!', -command=> sub {
   for ($i = 0; $i < 1000; $i++) {
     $percent_done = ($i/10) + 1;
     print "$i\n";
     $mw->update;  # otherwise we don't see how far we are.
  }
 })->pack(-side => 'bottom');

MainLoop;
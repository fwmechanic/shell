package poll_webcam;
use Exporter;
@ISA = ( 'Exporter' );
@EXPORT = qw(
   &poll_webcam
   );

use warnings;
use strict;
use Carp;   # to confess
use LWP;

sub getFile { my($url) = @_;
   my $agent    = LWP::UserAgent->new( timeout => 80 );
   my $request  = HTTP::Request->new(GET => $url);
   print "[$url]";
   my $sleepTm = 10;
   while(1) {
      my $response = $agent->request($request);
      if( $response->is_success ) {
         my $len = length $response->content;
         if( $len > 10*1024 ) {
            print " RdOk";
            return $response->content;
            }
         print "^";
         }
      printf "+%d", $sleepTm;
      sleep( $sleepTm );
      $sleepTm += 4 if $sleepTm < 40;
      }
   }

sub poll_webcam { my($url,$nmPrefix,$pollRate,$dmd) = @_;
   $dmd ||= 'm';
   my $lastJPG = "";
   while(1) {
      my $fdata = getFile( $url );
      my ($ofnm,$odir);
      { # create potential output filename BEFORE we make the request, since it may take a few seconds...
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
      $mon++;
      $year %= 100;
      if( $dmd eq 'm' ) {
         $odir = sprintf       "${nmPrefix}_%02d_%X"                      , $year,$mon;
         }
      elsif( $dmd eq 'w' ) {
         $odir = sprintf       "${nmPrefix}_%02d_w%02d"                   , $year,int($yday/7);
         }
      $ofnm = sprintf "$odir/${nmPrefix}_%02d_%X_%02d_%02d%02d%02d.jpg", $year,$mon,$mday,$hour,$min,$sec;
      }
      if( $lastJPG ne $fdata ) {
         if( not (-d $odir) ) {
            mkdir $odir or die "mkdir $odir failed: $!";
            }
         open my $ofh, '>', $ofnm or confess "couldn't open $ofnm for writing: $!\n";
         binmode( $ofh );
         print $ofh $fdata;
         $lastJPG = $fdata;
         print " saved $ofnm";
         }
      print "\n";
      sleep( $pollRate );
      }
   }

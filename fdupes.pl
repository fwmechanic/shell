#!/usr/bin/perl -w
# genesis: https://www.perlmonks.org/?node_id=49198 post by sarabob
# Usage: ./fdupes.pl <start directory>

use strict;
use warnings;

use English;

BEGIN { $| = 1;
   STDOUT->autoflush(1);
   }

use File::Find;

my $testing = 1;    # 0 for interactive mode, 1 to skip all deletion etc

use if ! $testing, "Term::ReadKey", qw( ReadKey ReadMode ) ;

my $minsize = 100;  # skip files smaller than $minsize bytes. Set to zero if you like...

sub usage {
  print "Usage: $0 <start directory>\n";
  exit;
  }
usage() unless (@ARGV);

my %files;
my ($filecount,$bytecount) = (0,0);
sub wanted {
  return unless -f;
  my $filesize = (stat($_))[7];
  $bytecount += $filesize;
  return if $filesize < $minsize;  # skip small files
  $filecount++;
  push @{$files{$filesize}}, $File::Find::name;
  }
find(\&wanted, $ARGV[0] || ".");

my ($fileschecked, $wasted) = (0,0);
# update progress display 1000 times maximum
#  $update_period = int($filecount/1000)+1;
my $update_period = 1;
sub progress {
  if( (++$fileschecked % $update_period) == 0 ) {
  # print "Progress: $fileschecked/$filecount\r";  # \r does carriage return, but NO LINE FEED for progress display
    printf "Progress: $fileschecked/$filecount\n";
    select()->flush();
    }
  }
progress();

my @dupesets;  # list of lists - @{$dupesets[0]} = (file1, file2), where file1 and file2 are dupes
foreach my $size (keys %files) {
  my @entries = @{$files{$size}};
  my $samesizecount = scalar @entries;
  if (@{$files{$size}} == 1) {  # unique size
    progress();
    next;
    }
  # duplicates by file size.. Check if files are the same
  while (my $base = shift @entries) {
    # get first entry in list under filesize
    my @dupes = ();
    my $count = 0;
    while ($count <= $#entries) {
      # go through all @entries
      my $compare = $entries[$count];
      if (&same($base, $compare)) {
        # remove "compare" from list so it can't be used on next run
        splice(@entries, $count,1);
        progress();
        if (@dupes) {
          # already have some dupes - just add duplicate #n to list
          push @dupes, $compare;
          $wasted += $size;
          }
        else {
          # no dupes yet - include base file and duplicate
          # #1 in list
          push @dupes, ($base, $compare);
          $wasted += $size;
          }
        }
      else {
        $count++;
        # only increase counter if not a dupe - note splice
        # will break $array[$position] loop otherwise
        }
      }
    if (@dupes) {
      push @dupesets, \@dupes;
      }
    # "base" file removed from list of files to check - update
    # progress meter
    progress();
    }
  }

sub GetAKey {
  # use ReadKey to get user input
  ReadMode( 4 ); # Turn off controls keys
  my $key = '';
  while (not defined ($key = ReadKey(-1))) {
    # No key yet
    }
  ReadMode( 0 ); # Reset tty mode before exiting
  return $key;
  }

print("\n");
if (@dupesets) {       # at least one set of duplicates exists
  my @deletelist;
  my $dupesetcount = scalar(@dupesets);   # number of sets of duplicates
  print "$dupesetcount duplicates found\n";
  my $dupesetcounter = 0;
  foreach my $setref (@dupesets) {
    if ($testing) {
      local $LIST_SEPARATOR = "\n   ";
      print $LIST_SEPARATOR, "@$setref", "\n";
      next;
      }
    $dupesetcounter++;
    my @dupes = @$setref;
    die "there are >10 dups; program cannot handle" if scalar @dupes > 10;  # single digit limit hit...
    my $numPendingDelete = scalar @deletelist;
    print "this dup is $dupesetcounter of $dupesetcount ($numPendingDelete pending deletes); should I:\n";
    print "x: eXit immediately with no actions taken\n";
    print "d: keep All this dup, Delete no-KEEP dups chosen so far & exit\n";
    print "a: keep All this dup\n";

    my $count = 0;
    # print up list of options of which file to keep
    while ($count <= $#dupes) {     # go through all @entries
      my $entry = $dupes[$count];
      print ++$count, ": keep ONLY $entry\n";
      }

    my $key = GetAKey();
    print "you chose: '$key' => ";
    if ($key =~ /^\d+$/) {
      $key = $key - 1;  # user selection chars are 1-based, @dupes uses 0-based indexing
      if (defined $dupes[$key]) {
        print "KEEPing ", $dupes[$key], "\n";
        splice(@dupes, $key, 1);    # remove file to keep from list
        push @deletelist, @dupes;   # add rest to deletelist
        }
      else {
        print "invalid number; KEEPing ALL\n";
        }
      }
    elsif ($key eq 'd') {  print "early Q&A exit; deleting no-KEEPs chosen so far\n";
      last;
      }
    elsif ($key eq 'a') {  print "KEEPing ALL\n";
      }
    elsif ($key eq 'x') {  print "exiting with no actions taken\n";
      exit(0);
      }
    else {
      print "invalid input; KEEPing ALL\n";
      }
    print "\n";
    }

  # confirm deletion if any files are needing deleting
  if (@deletelist) {
    print "\n------------------------\n";
    print "list of files to delete:\n";
    foreach (sort @deletelist) {
      print "$_\n";
      }
    print "\nAre you *sure* you want to delete all these files?"," (Y/N)\n";
    my $key = GetAKey();
    if (lc($key) eq 'y') {
      print "deleting\n";
      unlink @deletelist;
      }
    else {
      print "wussing out\n";
      }
    }

  1 while $wasted =~ s/^([-+]?\d+)(\d{3})/$1,$2/;
  print "$wasted bytes in duplicated files\n";
  }


# routine to check equivalence in files. pass 1 checks first
# "line" of file (up to \n char), rest of file checked if 1st
# line matches
sub same { my($a, $b) = @_;
  { # open and read first line only
  open my $ifha, '<', $a or die "abend cannot open $a for reading: $!\n";
  open my $ifhb, '<', $b or die "abend cannot open $b for reading: $!\n";
  return 0 if <$ifha> ne <$ifhb>;  # first lines differ?  not duplicates
    # first lines eq; cannot call binmode (for Windows efficiency) on fh from which read has already been performed,
  } # so close and reopen
  local $INPUT_RECORD_SEPARATOR = undef;
  my ($da,$db);
  { open my $ifh, '<', $a or die "abend cannot open $a for reading: $!\n"; binmode $ifh; $da = <$ifh>; }
  { open my $ifh, '<', $b or die "abend cannot open $b for reading: $!\n"; binmode $ifh; $db = <$ifh>; }
  return $da eq $db;
  }
